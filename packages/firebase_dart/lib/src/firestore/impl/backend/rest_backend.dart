import 'dart:async';
import 'dart:convert';

import 'package:firebase_dart/firestore.dart';
import 'package:firebase_dart/src/implementation.dart';
import 'package:http/http.dart' as http;

import '../document.dart';
import '../filter.dart';
import '../mutation.dart';
import '../query_impl.dart';
import 'backend.dart';

/// REST API backend implementation for Firestore.
class RestBackend implements FirestoreBackend {
  final String projectId;
  final String databaseId;
  final AuthTokenProvider? authTokenProvider;
  final http.Client httpClient;

  String _host = 'firestore.googleapis.com';
  bool _sslEnabled = true;
  bool _networkEnabled = true;

  RestBackend({
    required this.projectId,
    required this.databaseId,
    this.authTokenProvider,
    http.Client? httpClient,
  }) : httpClient = httpClient ?? http.Client();

  String get _baseUrl {
    final scheme = _sslEnabled ? 'https' : 'http';
    return '$scheme://$_host/v1/projects/$projectId/databases/$databaseId/documents';
  }

  void updateSettings(Settings settings) {
    if (settings.host != null) {
      _host = settings.host!;
    }
    _sslEnabled = settings.sslEnabled;
  }

  Future<Map<String, String>> _getHeaders() async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    if (authTokenProvider != null) {
      final token = await authTokenProvider!.getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
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

    final url = Uri.parse('$_baseUrl/$path');
    final headers = await _getHeaders();

    try {
      final response = await httpClient.get(url, headers: headers);

      if (response.statusCode == 404) {
        return Document.nonExistent(path);
      }

      if (response.statusCode != 200) {
        throw _parseError(response);
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return _documentFromJson(path, json);
    } catch (e) {
      if (e is FirestoreException) rethrow;
      throw FirestoreException(
        code: FirestoreException.codeUnavailable,
        message: 'Failed to get document: $e',
      );
    }
  }

  @override
  Future<List<Document>> executeQuery(QueryImpl query) async {
    _verifyNetworkEnabled();

    final queryJson = _queryToJson(query);
    final url = Uri.parse('$_baseUrl:runQuery');
    final headers = await _getHeaders();

    try {
      final response = await httpClient.post(
        url,
        headers: headers,
        body: jsonEncode(queryJson),
      );

      if (response.statusCode != 200) {
        throw _parseError(response);
      }

      final results = jsonDecode(response.body) as List;
      final documents = <Document>[];

      for (final result in results) {
        if (result is Map<String, dynamic> && result.containsKey('document')) {
          final docJson = result['document'] as Map<String, dynamic>;
          final docPath = _extractPathFromName(docJson['name'] as String);
          documents.add(_documentFromJson(docPath, docJson));
        }
      }

      return documents;
    } catch (e) {
      if (e is FirestoreException) rethrow;
      throw FirestoreException(
        code: FirestoreException.codeUnavailable,
        message: 'Failed to execute query: $e',
      );
    }
  }

  @override
  Future<void> commit(List<Mutation> mutations) async {
    _verifyNetworkEnabled();

    if (mutations.isEmpty) return;

    final url = Uri.parse(
      'https://$_host/v1/projects/$projectId/databases/$databaseId/documents:commit',
    );
    final headers = await _getHeaders();

    final writes = mutations.map((m) => _mutationToWrite(m)).toList();

    try {
      final response = await httpClient.post(
        url,
        headers: headers,
        body: jsonEncode({'writes': writes}),
      );

      if (response.statusCode != 200) {
        throw _parseError(response);
      }
    } catch (e) {
      if (e is FirestoreException) rethrow;
      throw FirestoreException(
        code: FirestoreException.codeUnavailable,
        message: 'Failed to commit mutations: $e',
      );
    }
  }

  @override
  Future<void> commitTransaction(
      List<Mutation> mutations, Set<String> readPaths) async {
    _verifyNetworkEnabled();

    final url = Uri.parse(
      'https://$_host/v1/projects/$projectId/databases/$databaseId/documents:commit',
    );
    final headers = await _getHeaders();

    // Begin transaction
    final beginUrl = Uri.parse(
      'https://$_host/v1/projects/$projectId/databases/$databaseId/documents:beginTransaction',
    );

    final beginResponse = await httpClient.post(
      beginUrl,
      headers: headers,
      body: jsonEncode({}),
    );

    if (beginResponse.statusCode != 200) {
      throw _parseError(beginResponse);
    }

    final beginJson = jsonDecode(beginResponse.body) as Map<String, dynamic>;
    final transaction = beginJson['transaction'] as String;

    // Commit with transaction
    final writes = mutations.map((m) => _mutationToWrite(m)).toList();

    try {
      final response = await httpClient.post(
        url,
        headers: headers,
        body: jsonEncode({
          'writes': writes,
          'transaction': transaction,
        }),
      );

      if (response.statusCode != 200) {
        throw _parseError(response);
      }
    } catch (e) {
      if (e is FirestoreException) rethrow;
      throw FirestoreException(
        code: FirestoreException.codeAborted,
        message: 'Transaction failed: $e',
      );
    }
  }

  @override
  Stream<Document> listenToDocument(String path) {
    // For now, implement polling. Real implementation would use gRPC streaming
    final controller = StreamController<Document>();

    Timer? timer;
    timer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!_networkEnabled) return;

      try {
        final doc = await getDocument(path);
        controller.add(doc);
      } catch (e) {
        controller.addError(e);
      }
    });

    controller.onCancel = () {
      timer?.cancel();
    };

    return controller.stream;
  }

  @override
  Stream<List<Document>> listenToQuery(QueryImpl query) {
    // For now, implement polling. Real implementation would use gRPC streaming
    final controller = StreamController<List<Document>>();

    Timer? timer;
    timer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!_networkEnabled) return;

      try {
        final docs = await executeQuery(query);
        controller.add(docs);
      } catch (e) {
        controller.addError(e);
      }
    });

    controller.onCancel = () {
      timer?.cancel();
    };

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
    httpClient.close();
  }

  Document _documentFromJson(String path, Map<String, dynamic> json) {
    final fields = json['fields'] as Map<String, dynamic>?;
    final data = fields != null ? _fieldsToData(fields) : <String, dynamic>{};

    return Document.fromServerData(
      path: path,
      data: data,
      version: json['updateTime'] != null
          ? DateTime.parse(json['updateTime'] as String).millisecondsSinceEpoch
          : null,
    );
  }

  Map<String, dynamic> _fieldsToData(Map<String, dynamic> fields) {
    final data = <String, dynamic>{};
    fields.forEach((key, value) {
      data[key] = _fieldToValue(value as Map<String, dynamic>);
    });
    return data;
  }

  dynamic _fieldToValue(Map<String, dynamic> field) {
    if (field.containsKey('nullValue')) return null;
    if (field.containsKey('booleanValue')) return field['booleanValue'];
    if (field.containsKey('integerValue')) {
      return int.parse(field['integerValue'] as String);
    }
    if (field.containsKey('doubleValue')) return field['doubleValue'];
    if (field.containsKey('stringValue')) return field['stringValue'];
    if (field.containsKey('timestampValue')) {
      return DateTime.parse(field['timestampValue'] as String);
    }
    if (field.containsKey('arrayValue')) {
      final array = field['arrayValue'] as Map<String, dynamic>;
      final values = array['values'] as List?;
      return values
              ?.map((v) => _fieldToValue(v as Map<String, dynamic>))
              .toList() ??
          [];
    }
    if (field.containsKey('mapValue')) {
      final map = field['mapValue'] as Map<String, dynamic>;
      final fields = map['fields'] as Map<String, dynamic>?;
      return fields != null ? _fieldsToData(fields) : {};
    }
    return null;
  }

  Map<String, dynamic> _queryToJson(QueryImpl query) {
    final structuredQuery = <String, dynamic>{};

    // Add collection selector
    if (query.isCollectionGroup) {
      structuredQuery['from'] = [
        {
          'collectionId': query.collectionId,
          'allDescendants': true,
        }
      ];
    } else if (query.path != null) {
      final collectionId = query.path!.split('/').last;
      structuredQuery['from'] = [
        {'collectionId': collectionId}
      ];
    }

    // Add filters
    if (query.filters.isNotEmpty) {
      structuredQuery['where'] = _filtersToJson(query.filters);
    }

    // Add order by
    if (query.orders.isNotEmpty) {
      structuredQuery['orderBy'] = query.orders.map((order) {
        return {
          'field': {'fieldPath': order.fieldPath.toString()},
          'direction': order.descending ? 'DESCENDING' : 'ASCENDING',
        };
      }).toList();
    }

    // Add limit
    if (query.limitValue != null) {
      structuredQuery['limit'] = query.limitValue;
    }

    return {
      'structuredQuery': structuredQuery,
    };
  }

  Map<String, dynamic> _filtersToJson(List<QueryFilter> filters) {
    if (filters.length == 1) {
      return _filterToJson(filters.first);
    }

    return {
      'compositeFilter': {
        'op': 'AND',
        'filters': filters.map(_filterToJson).toList(),
      }
    };
  }

  Map<String, dynamic> _filterToJson(QueryFilter filter) {
    String op;
    switch (filter.operator) {
      case FilterOperator.equal:
        op = 'EQUAL';
        break;
      case FilterOperator.notEqual:
        op = 'NOT_EQUAL';
        break;
      case FilterOperator.lessThan:
        op = 'LESS_THAN';
        break;
      case FilterOperator.lessThanOrEqual:
        op = 'LESS_THAN_OR_EQUAL';
        break;
      case FilterOperator.greaterThan:
        op = 'GREATER_THAN';
        break;
      case FilterOperator.greaterThanOrEqual:
        op = 'GREATER_THAN_OR_EQUAL';
        break;
      case FilterOperator.arrayContains:
        op = 'ARRAY_CONTAINS';
        break;
      case FilterOperator.in_:
        op = 'IN';
        break;
      case FilterOperator.arrayContainsAny:
        op = 'ARRAY_CONTAINS_ANY';
        break;
      case FilterOperator.notIn:
        op = 'NOT_IN';
        break;
    }

    return {
      'fieldFilter': {
        'field': {'fieldPath': filter.fieldPath.toString()},
        'op': op,
        'value': _valueToField(filter.value),
      }
    };
  }

  Map<String, dynamic> _valueToField(dynamic value) {
    if (value == null) return {'nullValue': null};
    if (value is bool) return {'booleanValue': value};
    if (value is int) return {'integerValue': value.toString()};
    if (value is double) return {'doubleValue': value};
    if (value is String) return {'stringValue': value};
    if (value is DateTime) {
      return {'timestampValue': value.toUtc().toIso8601String()};
    }
    if (value is List) {
      return {
        'arrayValue': {
          'values': value.map(_valueToField).toList(),
        }
      };
    }
    if (value is Map) {
      return {
        'mapValue': {
          'fields': _dataToFields(value as Map<String, dynamic>),
        }
      };
    }
    throw ArgumentError('Unsupported value type: ${value.runtimeType}');
  }

  Map<String, dynamic> _dataToFields(Map<String, dynamic> data) {
    final fields = <String, dynamic>{};
    data.forEach((key, value) {
      fields[key] = _valueToField(value);
    });
    return fields;
  }

  Map<String, dynamic> _mutationToWrite(Mutation mutation) {
    if (mutation is SetMutation) {
      return {
        'update': {
          'name': '$_baseUrl/${mutation.path}',
          'fields': _dataToFields(mutation.data),
        }
      };
    } else if (mutation is MergeSetMutation) {
      final write = {
        'update': {
          'name': '$_baseUrl/${mutation.path}',
          'fields': _dataToFields(mutation.data),
        }
      };
      if (mutation.mergeFields != null) {
        write['updateMask'] = {
          'fieldPaths': mutation.mergeFields!.map((f) {
            if (f is String) return f;
            if (f is FieldPath) return f.toString();
            throw ArgumentError('Invalid merge field type');
          }).toList(),
        };
      }
      return write;
    } else if (mutation is UpdateMutation) {
      return {
        'update': {
          'name': '$_baseUrl/${mutation.path}',
          'fields': _dataToFields(mutation.data),
        },
        'updateMask': {
          'fieldPaths': mutation.data.keys.toList(),
        },
        'currentDocument': {'exists': true},
      };
    } else if (mutation is DeleteMutation) {
      return {
        'delete': '$_baseUrl/${mutation.path}',
      };
    }
    throw ArgumentError('Unknown mutation type');
  }

  String _extractPathFromName(String name) {
    // Extract path from full resource name
    // Format: projects/{project}/databases/{database}/documents/{path}
    final prefix = 'projects/$projectId/databases/$databaseId/documents/';
    if (name.startsWith(prefix)) {
      return name.substring(prefix.length);
    }
    return name;
  }

  FirestoreException _parseError(http.Response response) {
    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final error = json['error'] as Map<String, dynamic>?;

      if (error != null) {
        return FirestoreException(
          code: _mapHttpStatusToCode(response.statusCode),
          message: error['message'] as String? ?? 'Unknown error',
        );
      }
    } catch (_) {
      // Ignore parse errors
    }

    return FirestoreException(
      code: _mapHttpStatusToCode(response.statusCode),
      message: 'Request failed with status ${response.statusCode}',
    );
  }

  String _mapHttpStatusToCode(int statusCode) {
    switch (statusCode) {
      case 400:
        return FirestoreException.codeInvalidArgument;
      case 401:
        return FirestoreException.codeUnauthenticated;
      case 403:
        return FirestoreException.codePermissionDenied;
      case 404:
        return FirestoreException.codeNotFound;
      case 409:
        return FirestoreException.codeAborted;
      case 429:
        return FirestoreException.codeResourceExhausted;
      case 499:
        return FirestoreException.codeCancelled;
      case 500:
        return FirestoreException.codeInternal;
      case 503:
        return FirestoreException.codeUnavailable;
      case 504:
        return FirestoreException.codeDeadlineExceeded;
      default:
        return FirestoreException.codeUnknown;
    }
  }
}
