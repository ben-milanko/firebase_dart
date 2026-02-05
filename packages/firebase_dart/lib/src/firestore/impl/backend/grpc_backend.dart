import 'dart:async';

import 'package:firebase_dart/firestore.dart';
import 'package:firebase_dart/src/implementation.dart';
import 'package:fixnum/fixnum.dart' as fixnum;
import 'package:grpc/grpc.dart';

import '../document.dart';
import '../filter.dart';
import '../mutation.dart';
import '../query_impl.dart';
import '../comparator.dart';
import 'backend.dart';
import '../grpc_generated/google/firestore/v1/firestore.pbgrpc.dart';
import '../grpc_generated/google/firestore/v1/document.pb.dart' as proto;
import '../grpc_generated/google/firestore/v1/common.pb.dart' as common;
import '../grpc_generated/google/firestore/v1/query.pb.dart' as query;
import '../grpc_generated/google/firestore/v1/write.pb.dart' as write;
import '../grpc_generated/google/protobuf/struct.pbenum.dart' as protobuf_struct;
import '../grpc_generated/google/protobuf/timestamp.pb.dart' as timestamp;
import '../grpc_generated/google/protobuf/wrappers.pb.dart' as wrappers;

/// gRPC API backend implementation for Firestore.
class GrpcBackend implements FirestoreBackend {
  final String projectId;
  final String databaseId;
  final AuthTokenProvider? authTokenProvider;
  
  late FirestoreClient _client;
  late ClientChannel _channel;
  
  bool _networkEnabled = true;

  GrpcBackend({
    required this.projectId,
    required this.databaseId,
    this.authTokenProvider,
    String host = 'firestore.googleapis.com',
    int? port,
    bool sslEnabled = true,
  }) {
    final resolved = _resolveHostPort(host, port);
    _channel = ClientChannel(
      resolved.host,
      port: resolved.port,
      options: ChannelOptions(
        credentials:
            sslEnabled ? ChannelCredentials.secure() : ChannelCredentials.insecure(),
      ),
    );
    _client = FirestoreClient(_channel);
  }

  String get _databasePath => 'projects/$projectId/databases/$databaseId';

  Future<CallOptions> _getOptions() async {
    final metadata = <String, String>{};
    if (authTokenProvider != null) {
      final token = await authTokenProvider!.getToken();
      if (token != null && token.isNotEmpty) {
        metadata['authorization'] = 'Bearer $token';
      }
    }
    return CallOptions(metadata: metadata);
  }

  void _verifyNetworkEnabled() {
    if (!_networkEnabled) {
      throw FirestoreException(
        code: FirestoreException.codeUnavailable,
        message: 'Network is disabled',
      );
    }
  }

  @override
  Future<Document> getDocument(String path) async {
    _verifyNetworkEnabled();
    final request = GetDocumentRequest()..name = '$_databasePath/documents/$path';
    try {
      final response = await _client.getDocument(request, options: await _getOptions());
      return _documentFromProto(response);
    } on GrpcError catch (e) {
      if (e.code == StatusCode.notFound) {
        return Document.nonExistent(path);
      }
      throw _parseGrpcError(e);
    }
  }

  @override
  Future<List<Document>> executeQuery(QueryImpl queryImpl) async {
    _verifyNetworkEnabled();

    // Check if we need to reverse orders for limitToLast
    final isLimitToLast = queryImpl.limitToLastValue != null;

    final request = RunQueryRequest()
      ..parent = _queryParent(queryImpl)
      ..structuredQuery =
          _queryToStructuredQuery(queryImpl, reverseOrder: isLimitToLast);

    try {
      final responseStream =
          _client.runQuery(request, options: await _getOptions());
      final documents = <Document>[];

      await for (final response in responseStream) {
        if (response.hasDocument()) {
          documents.add(_documentFromProto(response.document));
        }
      }

      // Sort documents based on original query order
      final comparator = DocumentComparator(queryImpl.orders);
      documents.sort(comparator.compare);

      return documents;
    } on GrpcError catch (e) {
      throw _parseGrpcError(e);
    }
  }

  @override
  Future<void> commit(List<Mutation> mutations) async {
    _verifyNetworkEnabled();
    final request = CommitRequest()
      ..database = _databasePath
      ..writes.addAll(mutations.map((m) => _mutationToProto(m)));
    
    try {
      await _client.commit(request, options: await _getOptions());
    } on GrpcError catch (e) {
      throw _parseGrpcError(e);
    }
  }

  @override
  Future<void> commitTransaction(
      List<Mutation> mutations, Set<String> readPaths) async {
    _verifyNetworkEnabled();
    
    try {
      // 1. Begin Transaction
      final beginRequest = BeginTransactionRequest()..database = _databasePath;
      final beginResponse = await _client.beginTransaction(beginRequest,
          options: await _getOptions());
      final transactionId = beginResponse.transaction;

      // 2. Commit with Transaction ID
      final commitRequest = CommitRequest()
        ..database = _databasePath
        ..transaction = transactionId
        ..writes.addAll(mutations.map((m) => _mutationToProto(m)));

      await _client.commit(commitRequest, options: await _getOptions());
    } on GrpcError catch (e) {
      throw _parseGrpcError(e);
    }
  }

  @override
  Stream<Document> listenToDocument(String path) {
    _verifyNetworkEnabled();
    
    final controller = StreamController<Document>();
    
    final requestStream = StreamController<ListenRequest>();
    late ResponseStream<ListenResponse> responseStream;

    _getOptions().then((options) {
      responseStream = _client.listen(requestStream.stream, options: options);
      
      final request = ListenRequest()
        ..database = _databasePath
        ..addTarget = (Target()
          ..documents = (Target_DocumentsTarget()..documents.add('$_databasePath/documents/$path'))
          ..targetId = 1);
      
      requestStream.add(request);
      
      responseStream.listen((response) {
        if (response.hasDocumentChange()) {
          controller.add(_documentFromProto(response.documentChange.document));
        } else if (response.hasDocumentDelete()) {
          controller.add(Document.nonExistent(path));
        }
      }, onError: controller.addError, onDone: () {
        requestStream.close();
        controller.close();
      });
    }).catchError((e) {
      controller.addError(e);
      controller.close();
    });

    return controller.stream;
  }

  @override
  Stream<List<Document>> listenToQuery(QueryImpl queryImpl) {
    _verifyNetworkEnabled();

    final controller = StreamController<List<Document>>();
    final requestStream = StreamController<ListenRequest>();
    late ResponseStream<ListenResponse> responseStream;

    final documentsByPath = <String, Document>{};
    const targetId = 1;

    // Check if we need to reverse orders for limitToLast
    final isLimitToLast = queryImpl.limitToLastValue != null;
    final comparator = DocumentComparator(queryImpl.orders);

    _getOptions().then((options) {
      responseStream = _client.listen(requestStream.stream, options: options);

      final request = ListenRequest()
        ..database = _databasePath
        ..addTarget = (Target()
          ..query = (Target_QueryTarget()
            ..parent = _queryParent(queryImpl)
            ..structuredQuery =
                _queryToStructuredQuery(queryImpl, reverseOrder: isLimitToLast))
          ..targetId = targetId);

      requestStream.add(request);

      responseStream.listen((response) {
        bool changed = false;
        if (response.hasDocumentChange()) {
          final doc = _documentFromProto(response.documentChange.document);
          documentsByPath[doc.path] = doc;
          changed = true;
        } else if (response.hasDocumentDelete()) {
          final path = _extractPathFromName(response.documentDelete.document);
          documentsByPath.remove(path);
          changed = true;
        } else if (response.hasDocumentRemove()) {
          final path = _extractPathFromName(response.documentRemove.document);
          documentsByPath.remove(path);
          changed = true;
        }

        if (changed) {
          final sortedDocs = documentsByPath.values.toList()
            ..sort(comparator.compare);
          controller.add(sortedDocs);
        }
      }, onError: controller.addError, onDone: () {
        requestStream.close();
        controller.close();
      });
    }).catchError((e) {
      controller.addError(e);
      controller.close();
    });

    return controller.stream;
  }

  @override
  Future<void> enableNetwork() async {
    _networkEnabled = true;
  }

  @override
  Future<void> disableNetwork() async {
    _networkEnabled = false;
  }

  @override
  Future<void> terminate() async {
    await _channel.shutdown();
  }

  Document _documentFromProto(proto.Document doc) {
    final path = _extractPathFromName(doc.name);
    final data = _fieldsToData(doc.fields);
    return Document.fromServerData(
      path: path,
      data: data,
      version: doc.updateTime.seconds.toInt() * 1000 + (doc.updateTime.nanos ~/ 1000000),
    );
  }

  Map<String, dynamic> _fieldsToData(Map<String, proto.Value> fields) {
    return fields.map((key, value) => MapEntry(key, _fieldToValue(value)));
  }

  dynamic _fieldToValue(proto.Value value) {
    if (value.hasNullValue()) return null;
    if (value.hasBooleanValue()) return value.booleanValue;
    if (value.hasIntegerValue()) return value.integerValue.toInt();
    if (value.hasDoubleValue()) return value.doubleValue;
    if (value.hasStringValue()) return value.stringValue;
    if (value.hasTimestampValue()) {
      return DateTime.fromMillisecondsSinceEpoch(
        value.timestampValue.seconds.toInt() * 1000 + (value.timestampValue.nanos ~/ 1000000),
      );
    }
    if (value.hasArrayValue()) {
      return value.arrayValue.values.map(_fieldToValue).toList();
    }
    if (value.hasMapValue()) {
      return _fieldsToData(value.mapValue.fields);
    }
    return null;
  }

  write.Write _mutationToProto(Mutation mutation) {
    if (mutation is SetMutation) {
      return write.Write()
        ..update = (proto.Document()
          ..name = '$_databasePath/documents/${mutation.path}'
          ..fields.addAll(_dataToFields(mutation.data)));
    } else if (mutation is MergeSetMutation) {
      final writeOp = write.Write()
        ..update = (proto.Document()
          ..name = '$_databasePath/documents/${mutation.path}'
          ..fields.addAll(_dataToFields(mutation.data)));

      if (mutation.mergeFields != null) {
        writeOp.updateMask = common.DocumentMask()
          ..fieldPaths.addAll(mutation.mergeFields!.map((f) {
            if (f is String) return f;
            if (f is FieldPath) return f.toString();
            throw ArgumentError('Invalid merge field type');
          }));
      }

      return writeOp;
    } else if (mutation is UpdateMutation) {
      return write.Write()
        ..update = (proto.Document()
          ..name = '$_databasePath/documents/${mutation.path}'
          ..fields.addAll(_dataToFields(mutation.data)))
        ..updateMask = (common.DocumentMask()
          ..fieldPaths.addAll(mutation.data.keys))
        ..currentDocument = (common.Precondition()..exists = true);
    } else if (mutation is DeleteMutation) {
      return write.Write()
        ..delete = '$_databasePath/documents/${mutation.path}';
    }

    throw ArgumentError('Unknown mutation type');
  }

  query.StructuredQuery _queryToStructuredQuery(QueryImpl queryImpl,
      {bool reverseOrder = false}) {
    final structured = query.StructuredQuery();

    if (queryImpl.isCollectionGroup) {
      structured.from.add(query.StructuredQuery_CollectionSelector()
        ..collectionId = queryImpl.collectionId ?? ''
        ..allDescendants = true);
    } else if (queryImpl.path != null) {
      final collectionId = queryImpl.path!.split('/').last;
      structured.from.add(query.StructuredQuery_CollectionSelector()
        ..collectionId = collectionId);
    }

    if (queryImpl.filters.isNotEmpty) {
      structured.where = _filtersToStructured(queryImpl.filters);
    }

    if (queryImpl.orders.isNotEmpty) {
      structured.orderBy.addAll(queryImpl.orders.map((order) {
        final descending = reverseOrder ? !order.descending : order.descending;
        return query.StructuredQuery_Order()
          ..field_1 = (query.StructuredQuery_FieldReference()
            ..fieldPath = order.fieldPath.toString())
          ..direction = descending
              ? query.StructuredQuery_Direction.DESCENDING
              : query.StructuredQuery_Direction.ASCENDING;
      }));
    } else if (reverseOrder) {
      // If no explicit order, we need to order by __name__ to support limitToLast reversal
      structured.orderBy.add(query.StructuredQuery_Order()
        ..field_1 = (query.StructuredQuery_FieldReference()
          ..fieldPath = FieldPath.documentId().toString())
        ..direction = query.StructuredQuery_Direction.DESCENDING);
    }

    if (queryImpl.limitValue != null) {
      structured.limit = wrappers.Int32Value()..value = queryImpl.limitValue!;
    } else if (queryImpl.limitToLastValue != null) {
      structured.limit =
          wrappers.Int32Value()..value = queryImpl.limitToLastValue!;
    }

    final startAtBoundary =
        reverseOrder ? queryImpl.endAtBoundary : queryImpl.startAtBoundary;
    final endAtBoundary =
        reverseOrder ? queryImpl.startAtBoundary : queryImpl.endAtBoundary;

    if (startAtBoundary != null) {
      structured.startAt = _boundaryToCursor(startAtBoundary, isStart: true);
    }
    if (endAtBoundary != null) {
      structured.endAt = _boundaryToCursor(endAtBoundary, isStart: false);
    }

    return structured;
  }

  query.Cursor _boundaryToCursor(QueryBoundary boundary,
      {required bool isStart}) {
    final cursor = query.Cursor();
    // For startAt: inclusive -> before=true
    // For endAt: inclusive -> before=false
    cursor.before = isStart ? boundary.inclusive : !boundary.inclusive;
    cursor.values.addAll(boundary.values.map(_valueToProtoValue));
    return cursor;
  }

  query.StructuredQuery_Filter _filtersToStructured(
      List<QueryFilter> filters) {
    if (filters.length == 1) {
      return _filterToStructured(filters.first);
    }

    return query.StructuredQuery_Filter(
      compositeFilter: query.StructuredQuery_CompositeFilter()
        ..op = query.StructuredQuery_CompositeFilter_Operator.AND
        ..filters.addAll(filters.map(_filterToStructured)),
    );
  }

  query.StructuredQuery_Filter _filterToStructured(QueryFilter filter) {
    final fieldRef = query.StructuredQuery_FieldReference()
      ..fieldPath = filter.fieldPath.toString();

    if (filter.value == null) {
      final op = filter.operator == FilterOperator.notEqual
          ? query.StructuredQuery_UnaryFilter_Operator.IS_NOT_NULL
          : query.StructuredQuery_UnaryFilter_Operator.IS_NULL;
      return query.StructuredQuery_Filter(
        unaryFilter: query.StructuredQuery_UnaryFilter()
          ..op = op
          ..field_2 = fieldRef,
      );
    }

    return query.StructuredQuery_Filter(
      fieldFilter: query.StructuredQuery_FieldFilter()
        ..field_1 = fieldRef
        ..op = _mapFilterOperator(filter.operator)
        ..value = _valueToProtoValue(filter.value),
    );
  }

  query.StructuredQuery_FieldFilter_Operator _mapFilterOperator(
      FilterOperator operator) {
    switch (operator) {
      case FilterOperator.equal:
        return query.StructuredQuery_FieldFilter_Operator.EQUAL;
      case FilterOperator.notEqual:
        return query.StructuredQuery_FieldFilter_Operator.NOT_EQUAL;
      case FilterOperator.lessThan:
        return query.StructuredQuery_FieldFilter_Operator.LESS_THAN;
      case FilterOperator.lessThanOrEqual:
        return query.StructuredQuery_FieldFilter_Operator.LESS_THAN_OR_EQUAL;
      case FilterOperator.greaterThan:
        return query.StructuredQuery_FieldFilter_Operator.GREATER_THAN;
      case FilterOperator.greaterThanOrEqual:
        return query.StructuredQuery_FieldFilter_Operator.GREATER_THAN_OR_EQUAL;
      case FilterOperator.arrayContains:
        return query.StructuredQuery_FieldFilter_Operator.ARRAY_CONTAINS;
      case FilterOperator.in_:
        return query.StructuredQuery_FieldFilter_Operator.IN;
      case FilterOperator.arrayContainsAny:
        return query.StructuredQuery_FieldFilter_Operator.ARRAY_CONTAINS_ANY;
      case FilterOperator.notIn:
        return query.StructuredQuery_FieldFilter_Operator.NOT_IN;
    }
    throw ArgumentError('Unsupported filter operator: $operator');
  }

  String _queryParent(QueryImpl queryImpl) {
    if (queryImpl.isCollectionGroup || queryImpl.path == null) {
      return '$_databasePath/documents';
    }

    final segments = queryImpl.path!.split('/');
    if (segments.length <= 1) {
      return '$_databasePath/documents';
    }

    final parentPath = segments.sublist(0, segments.length - 1).join('/');
    return '$_databasePath/documents/$parentPath';
  }

  Map<String, proto.Value> _dataToFields(Map<String, dynamic> data) {
    final fields = <String, proto.Value>{};
    data.forEach((key, value) {
      fields[key] = _valueToProtoValue(value);
    });
    return fields;
  }

  proto.Value _valueToProtoValue(dynamic value) {
    if (value == null) {
      return proto.Value()..nullValue = protobuf_struct.NullValue.NULL_VALUE;
    }
    if (value is bool) {
      return proto.Value()..booleanValue = value;
    }
    if (value is int) {
      return proto.Value()..integerValue = fixnum.Int64(value);
    }
    if (value is double) {
      return proto.Value()..doubleValue = value;
    }
    if (value is String) {
      return proto.Value()..stringValue = value;
    }
    if (value is DateTime) {
      final utc = value.toUtc();
      final micros = utc.microsecondsSinceEpoch;
      final seconds = micros ~/ 1000000;
      final nanos = (micros % 1000000) * 1000;
      return proto.Value()
        ..timestampValue = (timestamp.Timestamp()
          ..seconds = fixnum.Int64(seconds)
          ..nanos = nanos);
    }
    if (value is List) {
      return proto.Value()
        ..arrayValue = (proto.ArrayValue()
          ..values.addAll(value.map(_valueToProtoValue)));
    }
    if (value is Map) {
      return proto.Value()
        ..mapValue = (proto.MapValue()
          ..fields.addAll(_dataToFields(value as Map<String, dynamic>)));
    }

    throw ArgumentError('Unsupported value type: ${value.runtimeType}');
  }

  _HostPort _resolveHostPort(String host, int? port) {
    if (host.contains(':')) {
      final parts = host.split(':');
      final parsedPort = int.tryParse(parts.last);
      if (parsedPort != null) {
        return _HostPort(parts.first, parsedPort);
      }
    }
    return _HostPort(host, port ?? 443);
  }

  String _extractPathFromName(String name) {
    final prefix = 'projects/$projectId/databases/$databaseId/documents/';
    if (name.startsWith(prefix)) {
      return name.substring(prefix.length);
    }
    return name;
  }

  FirestoreException _parseGrpcError(GrpcError e) {
    return FirestoreException(
      code: _mapGrpcCodeToFirestoreCode(e.code),
      message: e.message ?? 'gRPC error',
    );
  }

  String _mapGrpcCodeToFirestoreCode(int code) {
    switch (code) {
      case StatusCode.invalidArgument:
        return FirestoreException.codeInvalidArgument;
      case StatusCode.unauthenticated:
        return FirestoreException.codeUnauthenticated;
      case StatusCode.permissionDenied:
        return FirestoreException.codePermissionDenied;
      case StatusCode.notFound:
        return FirestoreException.codeNotFound;
      case StatusCode.aborted:
        return FirestoreException.codeAborted;
      case StatusCode.resourceExhausted:
        return FirestoreException.codeResourceExhausted;
      case StatusCode.cancelled:
        return FirestoreException.codeCancelled;
      case StatusCode.internal:
        return FirestoreException.codeInternal;
      case StatusCode.unavailable:
        return FirestoreException.codeUnavailable;
      case StatusCode.deadlineExceeded:
        return FirestoreException.codeDeadlineExceeded;
      default:
        return FirestoreException.codeUnknown;
    }
  }
}

class _HostPort {
  final String host;
  final int port;

  const _HostPort(this.host, this.port);
}
