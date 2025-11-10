import 'dart:async';

import 'package:firebase_dart/core.dart';
import 'package:firebase_dart/firestore.dart';
import 'package:firebase_dart/src/firestore/impl/document.dart';
import 'package:firebase_dart/src/firestore/impl/document_snapshot_impl.dart';
import 'package:firebase_dart/src/firestore/impl/filter.dart';
import 'package:firebase_dart/src/firestore/impl/firestore_impl.dart';
import 'package:firebase_dart/src/firestore/impl/mutation.dart';
import 'package:firebase_dart/src/firestore/impl/query_impl.dart';
import 'package:firebase_dart/src/firestore/impl/query_snapshot_impl.dart';
import 'package:uuid/uuid.dart';

import '../isolate.dart';
import 'util.dart';

// ============================================================================
// Serializable Query Structure
// ============================================================================

/// Serializable representation of query parameters for isolate transfer.
class SerializableQuery {
  final String? path;
  final String? collectionId;
  final bool isCollectionGroup;
  final List<SerializableFilter> filters;
  final List<SerializableOrder> orders;
  final int? limitValue;
  final int? limitToLastValue;
  final SerializableBoundary? startAtBoundary;
  final SerializableBoundary? endAtBoundary;

  SerializableQuery({
    this.path,
    this.collectionId,
    this.isCollectionGroup = false,
    this.filters = const [],
    this.orders = const [],
    this.limitValue,
    this.limitToLastValue,
    this.startAtBoundary,
    this.endAtBoundary,
  });

  Map<String, dynamic> toJson() => {
        if (path != null) 'path': path,
        if (collectionId != null) 'collectionId': collectionId,
        'isCollectionGroup': isCollectionGroup,
        'filters': filters.map((f) => f.toJson()).toList(),
        'orders': orders.map((o) => o.toJson()).toList(),
        if (limitValue != null) 'limitValue': limitValue,
        if (limitToLastValue != null) 'limitToLastValue': limitToLastValue,
        if (startAtBoundary != null)
          'startAtBoundary': startAtBoundary!.toJson(),
        if (endAtBoundary != null) 'endAtBoundary': endAtBoundary!.toJson(),
      };

  factory SerializableQuery.fromJson(Map<String, dynamic> json) =>
      SerializableQuery(
        path: json['path'] as String?,
        collectionId: json['collectionId'] as String?,
        isCollectionGroup: json['isCollectionGroup'] as bool? ?? false,
        filters: (json['filters'] as List?)
                ?.map((f) =>
                    SerializableFilter.fromJson(f as Map<String, dynamic>))
                .toList() ??
            const [],
        orders: (json['orders'] as List?)
                ?.map((o) =>
                    SerializableOrder.fromJson(o as Map<String, dynamic>))
                .toList() ??
            const [],
        limitValue: json['limitValue'] as int?,
        limitToLastValue: json['limitToLastValue'] as int?,
        startAtBoundary: json['startAtBoundary'] != null
            ? SerializableBoundary.fromJson(
                json['startAtBoundary'] as Map<String, dynamic>)
            : null,
        endAtBoundary: json['endAtBoundary'] != null
            ? SerializableBoundary.fromJson(
                json['endAtBoundary'] as Map<String, dynamic>)
            : null,
      );

  QueryImpl toQueryImpl(FirestoreImpl firestore) {
    return QueryImpl(
      firestore: firestore,
      path: path,
      collectionId: collectionId,
      isCollectionGroup: isCollectionGroup,
      filters: filters.map((f) => f.toQueryFilter()).toList(),
      orders: orders.map((o) => o.toQueryOrder()).toList(),
      limitValue: limitValue,
      limitToLastValue: limitToLastValue,
      startAtBoundary: startAtBoundary?.toQueryBoundary(),
      endAtBoundary: endAtBoundary?.toQueryBoundary(),
    );
  }

  static SerializableQuery fromQueryImpl(QueryImpl query) {
    return SerializableQuery(
      path: query.path,
      collectionId: query.collectionId,
      isCollectionGroup: query.isCollectionGroup,
      filters: query.filters
          .map((f) => SerializableFilter.fromQueryFilter(f))
          .toList(),
      orders:
          query.orders.map((o) => SerializableOrder.fromQueryOrder(o)).toList(),
      limitValue: query.limitValue,
      limitToLastValue: query.limitToLastValue,
      startAtBoundary: query.startAtBoundary != null
          ? SerializableBoundary.fromQueryBoundary(query.startAtBoundary!)
          : null,
      endAtBoundary: query.endAtBoundary != null
          ? SerializableBoundary.fromQueryBoundary(query.endAtBoundary!)
          : null,
    );
  }
}

class SerializableFilter {
  final List<String> fieldPathComponents;
  final String operator;
  final dynamic value;

  SerializableFilter({
    required this.fieldPathComponents,
    required this.operator,
    this.value,
  });

  Map<String, dynamic> toJson() => {
        'fieldPathComponents': fieldPathComponents,
        'operator': operator,
        'value': value,
      };

  factory SerializableFilter.fromJson(Map<String, dynamic> json) =>
      SerializableFilter(
        fieldPathComponents:
            (json['fieldPathComponents'] as List).cast<String>(),
        operator: json['operator'] as String,
        value: json['value'],
      );

  QueryFilter toQueryFilter() {
    return QueryFilter(
      FieldPath(fieldPathComponents),
      FilterOperator.values
          .firstWhere((op) => op.toString().split('.').last == operator),
      value,
    );
  }

  static SerializableFilter fromQueryFilter(QueryFilter filter) {
    return SerializableFilter(
      fieldPathComponents: filter.fieldPath.components,
      operator: filter.operator.toString().split('.').last,
      value: filter.value,
    );
  }
}

class SerializableOrder {
  final List<String> fieldPathComponents;
  final bool descending;

  SerializableOrder({
    required this.fieldPathComponents,
    this.descending = false,
  });

  Map<String, dynamic> toJson() => {
        'fieldPathComponents': fieldPathComponents,
        'descending': descending,
      };

  factory SerializableOrder.fromJson(Map<String, dynamic> json) =>
      SerializableOrder(
        fieldPathComponents:
            (json['fieldPathComponents'] as List).cast<String>(),
        descending: json['descending'] as bool? ?? false,
      );

  QueryOrder toQueryOrder() {
    return QueryOrder(FieldPath(fieldPathComponents), descending);
  }

  static SerializableOrder fromQueryOrder(QueryOrder order) {
    return SerializableOrder(
      fieldPathComponents: order.fieldPath.components,
      descending: order.descending,
    );
  }
}

class SerializableBoundary {
  final List<dynamic> values;
  final bool inclusive;

  SerializableBoundary({
    required this.values,
    required this.inclusive,
  });

  Map<String, dynamic> toJson() => {
        'values': values,
        'inclusive': inclusive,
      };

  factory SerializableBoundary.fromJson(Map<String, dynamic> json) =>
      SerializableBoundary(
        values: json['values'] as List,
        inclusive: json['inclusive'] as bool? ?? true,
      );

  QueryBoundary toQueryBoundary() {
    return QueryBoundary(values: values, inclusive: inclusive);
  }

  static SerializableBoundary fromQueryBoundary(QueryBoundary boundary) {
    return SerializableBoundary(
      values: boundary.values,
      inclusive: boundary.inclusive,
    );
  }
}

// ============================================================================
// Encoding/Decoding Helpers
// ============================================================================

Map<String, dynamic> encodeDocument(Document doc) => {
      'path': doc.path,
      'data': doc.data,
      'metadata': {
        'hasPendingWrites': doc.metadata.hasPendingWrites,
        'isFromCache': doc.metadata.isFromCache,
      },
      'exists': doc.exists,
      if (doc.version != null) 'version': doc.version,
    };

Document decodeDocument(Map<String, dynamic> json) {
  final metadata = SnapshotMetadata(
    hasPendingWrites: json['metadata']['hasPendingWrites'] as bool,
    isFromCache: json['metadata']['isFromCache'] as bool,
  );

  if (json['exists'] == false) {
    return Document.nonExistent(json['path'] as String);
  }

  return Document(
    path: json['path'] as String,
    data: Map<String, dynamic>.from(json['data'] as Map),
    metadata: metadata,
    exists: json['exists'] as bool,
    version: json['version'] as int?,
  );
}

Map<String, dynamic> encodeDocumentSnapshot(DocumentSnapshot snapshot) => {
      'reference': {
        'path': snapshot.reference.path,
      },
      'document': snapshot is DocumentSnapshotImpl && snapshot.document != null
          ? encodeDocument(snapshot.document!)
          : null,
    };

DocumentSnapshot decodeDocumentSnapshot(
    Map<String, dynamic> json, IsolateFirebaseFirestore firestore) {
  final path = json['reference']['path'] as String;
  final docRef = IsolateDocumentReference(firestore: firestore, path: path);
  final docJson = json['document'] as Map<String, dynamic>?;

  if (docJson == null) {
    return DocumentSnapshotImpl(reference: docRef, document: null);
  }

  final document = decodeDocument(docJson);
  return DocumentSnapshotImpl(reference: docRef, document: document);
}

Map<String, dynamic> encodeQuerySnapshot(QuerySnapshot snapshot) {
  final queryImpl = (snapshot as QuerySnapshotImpl);
  return {
    'query': SerializableQuery.fromQueryImpl(queryImpl.query).toJson(),
    'documents': queryImpl.documents.map(encodeDocument).toList(),
  };
}

QuerySnapshot decodeQuerySnapshot(
    Map<String, dynamic> json, IsolateFirebaseFirestore firestore) {
  final queryJson = json['query'] as Map<String, dynamic>;
  final serializableQuery = SerializableQuery.fromJson(queryJson);
  final firestoreImpl = FirestoreImpl(
    app: Firebase.app(firestore.app.name),
    databaseId: firestore.databaseId ?? '(default)',
  );
  final query = serializableQuery.toQueryImpl(firestoreImpl);
  final documents = (json['documents'] as List)
      .map((d) => decodeDocument(d as Map<String, dynamic>))
      .toList();

  return QuerySnapshotImpl(query: query, documents: documents);
}

// ============================================================================
// FirestoreFunctionCall
// ============================================================================

class FirestoreFunctionCall<T> extends BaseFunctionCall<T> {
  final String appName;
  final String? databaseId;
  final Symbol functionName;

  FirestoreFunctionCall(
    this.functionName,
    this.appName,
    this.databaseId, [
    List<dynamic>? positionalArguments,
    Map<Symbol, dynamic>? namedArguments,
  ]) : super(positionalArguments, namedArguments);

  FirestoreImpl get firestore {
    return FirestoreImpl(
      app: Firebase.app(appName),
      databaseId: databaseId ?? '(default)',
    );
  }

  @override
  Function? get function {
    switch (functionName) {
      case #clearPersistence:
        return firestore.clearPersistence;
      case #enableNetwork:
        return firestore.enableNetwork;
      case #disableNetwork:
        return firestore.disableNetwork;
      case #waitForPendingWrites:
        return firestore.waitForPendingWrites;
      case #terminate:
        return firestore.terminate;
      case #initializeApp:
        return firestore.initializeApp;
      case #getDocument:
        return (String path, String source) async {
          final sourceEnum = Source.values.firstWhere(
            (s) => s.toString().split('.').last == source,
            orElse: () => Source.defaultSource,
          );
          return encodeDocument(await firestore.syncEngine.getDocument(
            path,
            source: sourceEnum,
          ));
        };
      case #listenToDocument:
        return (String path, bool includeMetadataChanges) {
          return firestore.syncEngine
              .listenToDocument(
                path,
                includeMetadataChanges: includeMetadataChanges,
              )
              .map(encodeDocument);
        };
      case #writeMutations:
        return (List<Map<String, dynamic>> mutationsJson) async {
          final mutations =
              mutationsJson.map((m) => _decodeMutation(m)).toList();
          await firestore.syncEngine.write(mutations);
        };
      case #executeQuery:
        return (Map<String, dynamic> queryJson, String source) async {
          final serializableQuery = SerializableQuery.fromJson(queryJson);
          final query = serializableQuery.toQueryImpl(firestore);
          final sourceEnum = Source.values.firstWhere(
            (s) => s.toString().split('.').last == source,
            orElse: () => Source.defaultSource,
          );
          final documents = await firestore.syncEngine
              .executeQuery(query, source: sourceEnum);
          return documents.map(encodeDocument).toList();
        };
      case #listenToQuery:
        return (Map<String, dynamic> queryJson, bool includeMetadataChanges) {
          final serializableQuery = SerializableQuery.fromJson(queryJson);
          final query = serializableQuery.toQueryImpl(firestore);
          return firestore.syncEngine
              .listenToQuery(query,
                  includeMetadataChanges: includeMetadataChanges)
              .map((documents) => documents.map(encodeDocument).toList());
        };
      case #writeBatch:
        return (List<Map<String, dynamic>> mutationsJson) async {
          final mutations =
              mutationsJson.map((m) => _decodeMutation(m)).toList();
          await firestore.syncEngine.write(mutations);
        };
      case #runTransaction:
        return (IsolateCommander commander, Symbol handlerSymbol,
            List<String> readPaths, Duration timeout) async {
          // Note: This is a simplified transaction implementation
          // Real implementation would need proper transaction handling
          return null;
        };
      case #countQuery:
        return (Map<String, dynamic> queryJson) async {
          final serializableQuery = SerializableQuery.fromJson(queryJson);
          final query = serializableQuery.toQueryImpl(firestore);
          final documents = await firestore.syncEngine.executeQuery(query);
          return documents.length;
        };
    }
    return null;
  }

  Mutation _decodeMutation(Map<String, dynamic> json) {
    final type = json['type'] as String;
    final path = json['path'] as String;
    final data = json['data'] as Map<String, dynamic>?;

    switch (type) {
      case 'set':
        return SetMutation(path: path, data: data ?? {});
      case 'mergeSet':
        return MergeSetMutation(
          path: path,
          data: data ?? {},
          mergeFields: json['mergeFields'] != null
              ? (json['mergeFields'] as List).cast<Object>()
              : null,
        );
      case 'update':
        return UpdateMutation(path: path, data: data ?? {});
      case 'delete':
        return DeleteMutation(path: path);
      default:
        throw ArgumentError('Unknown mutation type: $type');
    }
  }
}

// ============================================================================
// IsolateFirebaseFirestore
// ============================================================================

class IsolateFirebaseFirestore extends IsolateFirebaseService
    implements FirebaseFirestore {
  final String? databaseId;

  Settings _settings = const Settings();

  IsolateFirebaseFirestore({
    required IsolateFirebaseApp app,
    this.databaseId,
  }) : super(app);

  @override
  Settings get settings => _settings;

  Future<T> invoke<T>(Symbol method,
      [List<dynamic>? positionalArguments,
      Map<Symbol, dynamic>? namedArguments]) {
    return app.commander.execute(FirestoreFunctionCall<FutureOr<T>>(
        method, app.name, databaseId, positionalArguments, namedArguments));
  }

  Stream<T> subscribe<T>(Symbol method,
      [List<dynamic>? positionalArguments,
      Map<Symbol, dynamic>? namedArguments]) {
    return app.commander.subscribe(FirestoreFunctionCall<Stream<T>>(
        method, app.name, databaseId, positionalArguments, namedArguments));
  }

  @override
  CollectionReference collection(String collectionPath) {
    if (collectionPath.isEmpty) {
      throw ArgumentError('Collection path must not be empty');
    }
    if (collectionPath.contains('//')) {
      throw ArgumentError('Collection path must not contain "//"');
    }
    if (collectionPath.startsWith('/') || collectionPath.endsWith('/')) {
      throw ArgumentError('Collection path must not start or end with "/"');
    }

    final segments = collectionPath.split('/');
    if (segments.length.isEven) {
      throw ArgumentError(
          'Collection path must have an odd number of segments');
    }

    return IsolateCollectionReference(firestore: this, path: collectionPath);
  }

  @override
  DocumentReference doc(String documentPath) {
    if (documentPath.isEmpty) {
      throw ArgumentError('Document path must not be empty');
    }
    if (documentPath.contains('//')) {
      throw ArgumentError('Document path must not contain "//"');
    }
    if (documentPath.startsWith('/') || documentPath.endsWith('/')) {
      throw ArgumentError('Document path must not start or end with "/"');
    }

    final segments = documentPath.split('/');
    if (segments.length.isOdd) {
      throw ArgumentError('Document path must have an even number of segments');
    }

    return IsolateDocumentReference(firestore: this, path: documentPath);
  }

  @override
  Query collectionGroup(String collectionId) {
    if (collectionId.isEmpty) {
      throw ArgumentError('Collection ID must not be empty');
    }
    if (collectionId.contains('/')) {
      throw ArgumentError('Collection ID must not contain "/"');
    }

    return IsolateQuery(
      firestore: this,
      path: null,
      collectionId: collectionId,
      isCollectionGroup: true,
    );
  }

  @override
  WriteBatch batch() {
    return IsolateWriteBatch(firestore: this);
  }

  @override
  Future<T> runTransaction<T>(
    Future<T> Function(Transaction transaction) transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final transaction =
            IsolateTransaction(firestore: this, timeout: timeout);
        final result = await transactionHandler(transaction);
        await transaction.commitInternal();
        return result;
      } on FirestoreException catch (e) {
        if (e.code == FirestoreException.codeAborted &&
            attempt < maxAttempts - 1) {
          await Future.delayed(Duration(milliseconds: 100 * (attempt + 1)));
          continue;
        }
        rethrow;
      }
    }

    throw FirestoreException(
      code: FirestoreException.codeAborted,
      message: 'Transaction failed after $maxAttempts attempts',
    );
  }

  @override
  Future<void> clearPersistence() async {
    await invoke(#clearPersistence);
  }

  @override
  Future<void> enableNetwork() async {
    await invoke(#enableNetwork);
  }

  @override
  Future<void> disableNetwork() async {
    await invoke(#disableNetwork);
  }

  @override
  Future<void> waitForPendingWrites() async {
    await invoke(#waitForPendingWrites);
  }

  @override
  Future<void> terminate() async {
    await invoke(#terminate);
  }

  @override
  Future<void> initializeApp() async {
    await invoke(#initializeApp);
  }

  @override
  void useEmulator(String host, int port) {
    _settings = _settings.copyWith(
      host: '$host:$port',
      sslEnabled: false,
    );
  }
}

// ============================================================================
// IsolateDocumentReference
// ============================================================================

class IsolateDocumentReference extends DocumentReference {
  @override
  final IsolateFirebaseFirestore firestore;

  @override
  final String path;

  IsolateDocumentReference({
    required this.firestore,
    required this.path,
  });

  @override
  String get id => path.split('/').last;

  @override
  CollectionReference get parent {
    final segments = path.split('/');
    if (segments.length < 2) {
      throw StateError('Document has no parent collection');
    }
    final parentPath = segments.sublist(0, segments.length - 1).join('/');
    return IsolateCollectionReference(firestore: firestore, path: parentPath);
  }

  @override
  CollectionReference collection(String collectionPath) {
    if (collectionPath.isEmpty) {
      throw ArgumentError('Collection path must not be empty');
    }
    return IsolateCollectionReference(
      firestore: firestore,
      path: '$path/$collectionPath',
    );
  }

  Future<T> invoke<T>(Symbol method,
      [List<dynamic>? positionalArguments,
      Map<Symbol, dynamic>? namedArguments]) {
    return firestore.app.commander.execute(FirestoreFunctionCall<FutureOr<T>>(
        method,
        firestore.app.name,
        firestore.databaseId,
        positionalArguments,
        namedArguments));
  }

  Stream<T> subscribe<T>(Symbol method,
      [List<dynamic>? positionalArguments,
      Map<Symbol, dynamic>? namedArguments]) {
    return firestore.app.commander.subscribe(FirestoreFunctionCall<Stream<T>>(
        method,
        firestore.app.name,
        firestore.databaseId,
        positionalArguments,
        namedArguments));
  }

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    if (data.isEmpty && options?.merge != true) {
      throw ArgumentError('Data must not be empty');
    }

    final mutationJson = {
      'type': options?.merge == true ? 'mergeSet' : 'set',
      'path': path,
      'data': data,
      if (options?.mergeFields != null) 'mergeFields': options!.mergeFields,
    };

    await invoke(#writeMutations, [
      [mutationJson]
    ]);
  }

  @override
  Future<void> update(Map<String, dynamic> data) async {
    if (data.isEmpty) {
      throw ArgumentError('Data must not be empty');
    }

    final mutationJson = {
      'type': 'update',
      'path': path,
      'data': data,
    };

    await invoke(#writeMutations, [
      [mutationJson]
    ]);
  }

  @override
  Future<void> delete() async {
    final mutationJson = {
      'type': 'delete',
      'path': path,
    };

    await invoke(#writeMutations, [
      [mutationJson]
    ]);
  }

  @override
  Future<DocumentSnapshot> get([GetOptions? options]) async {
    final source = options?.source ?? Source.defaultSource;
    final sourceString = source.toString().split('.').last;

    final docJson =
        await invoke<Map<String, dynamic>>(#getDocument, [path, sourceString]);

    return decodeDocumentSnapshot(docJson, firestore);
  }

  @override
  Stream<DocumentSnapshot> snapshots({bool includeMetadataChanges = false}) {
    return subscribe<Map<String, dynamic>>(
            #listenToDocument, [path, includeMetadataChanges])
        .map((docJson) => decodeDocument(docJson))
        .map((doc) => DocumentSnapshotImpl(
              reference: this,
              document: doc,
            ));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IsolateDocumentReference &&
          runtimeType == other.runtimeType &&
          firestore == other.firestore &&
          path == other.path;

  @override
  int get hashCode => firestore.hashCode ^ path.hashCode;

  @override
  String toString() => 'DocumentReference($path)';
}

// ============================================================================
// IsolateQuery
// ============================================================================

class IsolateQuery extends Query {
  @override
  final IsolateFirebaseFirestore firestore;

  final String? path;
  final String? collectionId;
  final bool isCollectionGroup;
  final List<SerializableFilter> filters;
  final List<SerializableOrder> orders;
  final int? limitValue;
  final int? limitToLastValue;
  final SerializableBoundary? startAtBoundary;
  final SerializableBoundary? endAtBoundary;

  IsolateQuery({
    required this.firestore,
    this.path,
    this.collectionId,
    this.isCollectionGroup = false,
    this.filters = const [],
    this.orders = const [],
    this.limitValue,
    this.limitToLastValue,
    this.startAtBoundary,
    this.endAtBoundary,
  });

  IsolateQuery _copyWith({
    List<SerializableFilter>? filters,
    List<SerializableOrder>? orders,
    int? limitValue,
    int? limitToLastValue,
    SerializableBoundary? startAtBoundary,
    SerializableBoundary? endAtBoundary,
    bool clearLimit = false,
    bool clearLimitToLast = false,
    bool clearStartAt = false,
    bool clearEndAt = false,
  }) {
    return IsolateQuery(
      firestore: firestore,
      path: path,
      collectionId: collectionId,
      isCollectionGroup: isCollectionGroup,
      filters: filters ?? this.filters,
      orders: orders ?? this.orders,
      limitValue: clearLimit ? null : (limitValue ?? this.limitValue),
      limitToLastValue:
          clearLimitToLast ? null : (limitToLastValue ?? this.limitToLastValue),
      startAtBoundary:
          clearStartAt ? null : (startAtBoundary ?? this.startAtBoundary),
      endAtBoundary: clearEndAt ? null : (endAtBoundary ?? this.endAtBoundary),
    );
  }

  SerializableQuery _toSerializableQuery() {
    return SerializableQuery(
      path: path,
      collectionId: collectionId,
      isCollectionGroup: isCollectionGroup,
      filters: filters,
      orders: orders,
      limitValue: limitValue,
      limitToLastValue: limitToLastValue,
      startAtBoundary: startAtBoundary,
      endAtBoundary: endAtBoundary,
    );
  }

  FieldPath _parseFieldPath(Object field) {
    if (field is String) {
      return FieldPath.fromString(field);
    } else if (field is FieldPath) {
      return field;
    } else {
      throw ArgumentError('Field must be a String or FieldPath');
    }
  }

  Future<T> invoke<T>(Symbol method,
      [List<dynamic>? positionalArguments,
      Map<Symbol, dynamic>? namedArguments]) {
    return firestore.app.commander.execute(FirestoreFunctionCall<FutureOr<T>>(
        method,
        firestore.app.name,
        firestore.databaseId,
        positionalArguments,
        namedArguments));
  }

  Stream<T> subscribe<T>(Symbol method,
      [List<dynamic>? positionalArguments,
      Map<Symbol, dynamic>? namedArguments]) {
    return firestore.app.commander.subscribe(FirestoreFunctionCall<Stream<T>>(
        method,
        firestore.app.name,
        firestore.databaseId,
        positionalArguments,
        namedArguments));
  }

  @override
  Query where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    List<Object?>? arrayContainsAny,
    List<Object?>? whereIn,
    List<Object?>? whereNotIn,
    bool? isNull,
  }) {
    final fieldPath = _parseFieldPath(field);
    final newFilters = List<SerializableFilter>.from(filters);

    if (isEqualTo != null) {
      newFilters.add(SerializableFilter(
        fieldPathComponents: fieldPath.components,
        operator: 'equal',
        value: isEqualTo,
      ));
    }
    if (isNotEqualTo != null) {
      newFilters.add(SerializableFilter(
        fieldPathComponents: fieldPath.components,
        operator: 'notEqual',
        value: isNotEqualTo,
      ));
    }
    if (isLessThan != null) {
      newFilters.add(SerializableFilter(
        fieldPathComponents: fieldPath.components,
        operator: 'lessThan',
        value: isLessThan,
      ));
    }
    if (isLessThanOrEqualTo != null) {
      newFilters.add(SerializableFilter(
        fieldPathComponents: fieldPath.components,
        operator: 'lessThanOrEqual',
        value: isLessThanOrEqualTo,
      ));
    }
    if (isGreaterThan != null) {
      newFilters.add(SerializableFilter(
        fieldPathComponents: fieldPath.components,
        operator: 'greaterThan',
        value: isGreaterThan,
      ));
    }
    if (isGreaterThanOrEqualTo != null) {
      newFilters.add(SerializableFilter(
        fieldPathComponents: fieldPath.components,
        operator: 'greaterThanOrEqual',
        value: isGreaterThanOrEqualTo,
      ));
    }
    if (arrayContains != null) {
      newFilters.add(SerializableFilter(
        fieldPathComponents: fieldPath.components,
        operator: 'arrayContains',
        value: arrayContains,
      ));
    }
    if (arrayContainsAny != null) {
      newFilters.add(SerializableFilter(
        fieldPathComponents: fieldPath.components,
        operator: 'arrayContainsAny',
        value: arrayContainsAny,
      ));
    }
    if (whereIn != null) {
      newFilters.add(SerializableFilter(
        fieldPathComponents: fieldPath.components,
        operator: 'in_',
        value: whereIn,
      ));
    }
    if (whereNotIn != null) {
      newFilters.add(SerializableFilter(
        fieldPathComponents: fieldPath.components,
        operator: 'notIn',
        value: whereNotIn,
      ));
    }
    if (isNull == true) {
      newFilters.add(SerializableFilter(
        fieldPathComponents: fieldPath.components,
        operator: 'equal',
        value: null,
      ));
    }

    return _copyWith(filters: newFilters);
  }

  @override
  Query orderBy(Object field, {bool descending = false}) {
    final fieldPath = _parseFieldPath(field);
    final newOrders = List<SerializableOrder>.from(orders)
      ..add(SerializableOrder(
        fieldPathComponents: fieldPath.components,
        descending: descending,
      ));
    return _copyWith(orders: newOrders);
  }

  @override
  Query limit(int limit) {
    if (limit <= 0) {
      throw ArgumentError('Limit must be positive');
    }
    return _copyWith(limitValue: limit, clearLimitToLast: true);
  }

  @override
  Query limitToLast(int limit) {
    if (limit <= 0) {
      throw ArgumentError('Limit must be positive');
    }
    return _copyWith(limitToLastValue: limit, clearLimit: true);
  }

  @override
  Query startAtDocument(DocumentSnapshot documentSnapshot) {
    final values = _extractBoundaryValues(documentSnapshot);
    return _copyWith(
      startAtBoundary: SerializableBoundary(values: values, inclusive: true),
    );
  }

  @override
  Query startAt(List<Object?> values) {
    return _copyWith(
      startAtBoundary: SerializableBoundary(values: values, inclusive: true),
    );
  }

  @override
  Query startAfterDocument(DocumentSnapshot documentSnapshot) {
    final values = _extractBoundaryValues(documentSnapshot);
    return _copyWith(
      startAtBoundary: SerializableBoundary(values: values, inclusive: false),
    );
  }

  @override
  Query startAfter(List<Object?> values) {
    return _copyWith(
      startAtBoundary: SerializableBoundary(values: values, inclusive: false),
    );
  }

  @override
  Query endBeforeDocument(DocumentSnapshot documentSnapshot) {
    final values = _extractBoundaryValues(documentSnapshot);
    return _copyWith(
      endAtBoundary: SerializableBoundary(values: values, inclusive: false),
    );
  }

  @override
  Query endBefore(List<Object?> values) {
    return _copyWith(
      endAtBoundary: SerializableBoundary(values: values, inclusive: false),
    );
  }

  @override
  Query endAtDocument(DocumentSnapshot documentSnapshot) {
    final values = _extractBoundaryValues(documentSnapshot);
    return _copyWith(
      endAtBoundary: SerializableBoundary(values: values, inclusive: true),
    );
  }

  @override
  Query endAt(List<Object?> values) {
    return _copyWith(
      endAtBoundary: SerializableBoundary(values: values, inclusive: true),
    );
  }

  List<Object?> _extractBoundaryValues(DocumentSnapshot snapshot) {
    final values = <Object?>[];
    for (final order in orders) {
      final fieldPath = FieldPath(order.fieldPathComponents);
      final value = _getNestedValue(snapshot.data(), fieldPath);
      values.add(value);
    }
    if (values.isEmpty) {
      values.add(snapshot.reference.path);
    }
    return values;
  }

  Object? _getNestedValue(Map<String, dynamic>? data, FieldPath fieldPath) {
    if (data == null) return null;

    dynamic current = data;
    for (final component in fieldPath.components) {
      if (current is! Map) return null;
      current = current[component];
    }
    return current;
  }

  @override
  Future<QuerySnapshot> get([GetOptions? options]) async {
    final source = options?.source ?? Source.defaultSource;
    final sourceString = source.toString().split('.').last;
    final queryJson = _toSerializableQuery().toJson();

    final result = await invoke<List<Map<String, dynamic>>>(
        #executeQuery, [queryJson, sourceString]);

    // Reconstruct QuerySnapshot
    final firestoreImpl = FirestoreImpl(
      app: Firebase.app(firestore.app.name),
      databaseId: firestore.databaseId ?? '(default)',
    );
    final query = _toSerializableQuery().toQueryImpl(firestoreImpl);
    final documents = result.map((d) => decodeDocument(d)).toList();

    return QuerySnapshotImpl(query: query, documents: documents);
  }

  @override
  Stream<QuerySnapshot> snapshots({bool includeMetadataChanges = false}) {
    final queryJson = _toSerializableQuery().toJson();
    return subscribe<List<Map<String, dynamic>>>(
            #listenToQuery, [queryJson, includeMetadataChanges])
        .map((documentsJson) {
      final documents = documentsJson.map((d) => decodeDocument(d)).toList();
      final firestoreImpl = FirestoreImpl(
        app: Firebase.app(firestore.app.name),
        databaseId: firestore.databaseId ?? '(default)',
      );
      final query = _toSerializableQuery().toQueryImpl(firestoreImpl);
      return QuerySnapshotImpl(query: query, documents: documents);
    });
  }

  @override
  Future<AggregateQuerySnapshot> count() async {
    final queryJson = _toSerializableQuery().toJson();
    final count = await invoke<int>(#countQuery, [queryJson]);
    return AggregateQuerySnapshot(count: count);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IsolateQuery &&
          runtimeType == other.runtimeType &&
          firestore == other.firestore &&
          path == other.path &&
          isCollectionGroup == other.isCollectionGroup &&
          _listEquals(filters, other.filters) &&
          _listEquals(orders, other.orders) &&
          limitValue == other.limitValue &&
          limitToLastValue == other.limitToLastValue;

  @override
  int get hashCode =>
      firestore.hashCode ^
      path.hashCode ^
      isCollectionGroup.hashCode ^
      filters.hashCode ^
      orders.hashCode;

  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

// ============================================================================
// IsolateCollectionReference
// ============================================================================

class IsolateCollectionReference extends IsolateQuery
    implements CollectionReference {
  IsolateCollectionReference({
    required super.firestore,
    required String super.path,
  });

  @override
  String get id {
    final p = super.path;
    if (p == null) throw StateError('Collection path is null');
    return p.split('/').last;
  }

  @override
  String get path {
    final p = super.path;
    if (p == null) throw StateError('Collection path is null');
    return p;
  }

  @override
  DocumentReference? get parent {
    final segments = path.split('/');
    if (segments.length < 2) {
      return null; // Root collection has no parent
    }
    final parentPath = segments.sublist(0, segments.length - 1).join('/');
    return IsolateDocumentReference(firestore: firestore, path: parentPath);
  }

  @override
  DocumentReference doc([String? docPath]) {
    final docId = docPath ?? const Uuid().v4();

    if (docId.isEmpty) {
      throw ArgumentError('Document ID must not be empty');
    }
    if (docId.contains('/')) {
      throw ArgumentError('Document ID must not contain "/"');
    }

    return IsolateDocumentReference(
      firestore: firestore,
      path: '$path/$docId',
    );
  }

  @override
  Future<DocumentReference> add(Map<String, dynamic> data) async {
    final docRef = doc();
    await docRef.set(data);
    return docRef;
  }

  @override
  String toString() => 'CollectionReference($path)';
}

// ============================================================================
// IsolateWriteBatch
// ============================================================================

class IsolateWriteBatch extends WriteBatch {
  final IsolateFirebaseFirestore firestore;
  final List<Map<String, dynamic>> _mutations = [];
  bool _committed = false;

  IsolateWriteBatch({required this.firestore});

  void _verifyNotCommitted() {
    if (_committed) {
      throw FirestoreException(
        code: 'failed-precondition',
        message: 'Cannot modify a WriteBatch that has already been committed.',
      );
    }
  }

  @override
  void set(DocumentReference document, Map<String, dynamic> data,
      [SetOptions? options]) {
    _verifyNotCommitted();

    _mutations.add({
      'type': options?.merge == true ? 'mergeSet' : 'set',
      'path': document.path,
      'data': data,
      if (options?.mergeFields != null) 'mergeFields': options!.mergeFields,
    });
  }

  @override
  void update(DocumentReference document, Map<String, dynamic> data) {
    _verifyNotCommitted();

    if (data.isEmpty) {
      throw ArgumentError('Data must not be empty');
    }

    _mutations.add({
      'type': 'update',
      'path': document.path,
      'data': data,
    });
  }

  @override
  void delete(DocumentReference document) {
    _verifyNotCommitted();
    _mutations.add({
      'type': 'delete',
      'path': document.path,
    });
  }

  @override
  Future<void> commit() async {
    _verifyNotCommitted();
    _committed = true;

    if (_mutations.isEmpty) {
      return;
    }

    await firestore.invoke(#writeBatch, [_mutations]);
  }
}

// ============================================================================
// IsolateTransaction
// ============================================================================

class IsolateTransaction extends Transaction {
  final IsolateFirebaseFirestore firestore;
  final Duration timeout;
  final List<Map<String, dynamic>> _mutations = [];
  final Set<String> _readPaths = {};
  bool _committed = false;

  IsolateTransaction({
    required this.firestore,
    required this.timeout,
  });

  void _verifyNotCommitted() {
    if (_committed) {
      throw FirestoreException(
        code: 'failed-precondition',
        message: 'Transaction has already been committed or aborted.',
      );
    }
  }

  @override
  Future<DocumentSnapshot> get(DocumentReference documentReference) async {
    _verifyNotCommitted();
    _readPaths.add(documentReference.path);

    final sourceString = Source.server.toString().split('.').last;
    final docJson = await firestore.invoke<Map<String, dynamic>>(
        #getDocument, [documentReference.path, sourceString]);

    return decodeDocumentSnapshot(docJson, firestore);
  }

  @override
  Transaction set(
      DocumentReference documentReference, Map<String, dynamic> data,
      [SetOptions? options]) {
    _verifyNotCommitted();

    _mutations.add({
      'type': options?.merge == true ? 'mergeSet' : 'set',
      'path': documentReference.path,
      'data': data,
      if (options?.mergeFields != null) 'mergeFields': options!.mergeFields,
    });
    return this;
  }

  @override
  Transaction update(
      DocumentReference documentReference, Map<String, dynamic> data) {
    _verifyNotCommitted();

    if (data.isEmpty) {
      throw ArgumentError('Data must not be empty');
    }

    _mutations.add({
      'type': 'update',
      'path': documentReference.path,
      'data': data,
    });
    return this;
  }

  @override
  Transaction delete(DocumentReference documentReference) {
    _verifyNotCommitted();
    _mutations.add({
      'type': 'delete',
      'path': documentReference.path,
    });
    return this;
  }

  Future<void> commitInternal() async {
    _verifyNotCommitted();
    _committed = true;

    if (_mutations.isEmpty) {
      return;
    }

    // Note: Real transaction implementation would need proper transaction handling
    // For now, we'll use regular write
    await firestore.invoke(#writeMutations, [_mutations]);
  }
}
