import 'package:firebase_dart/firestore.dart';
import 'document.dart';

/// Base class for all mutations.
abstract class Mutation {
  final String path;

  const Mutation({required this.path});

  /// Applies this mutation to a document.
  Document apply(Document? document);

  /// Converts this mutation to a JSON representation for the server.
  Map<String, dynamic> toJson();
}

/// Represents a set operation.
class SetMutation extends Mutation {
  final Map<String, dynamic> data;

  const SetMutation({
    required super.path,
    required this.data,
  });

  @override
  Document apply(Document? document) {
    return Document(
      path: path,
      data: Map<String, dynamic>.from(data),
      metadata: const SnapshotMetadata(
        hasPendingWrites: true,
        isFromCache: true,
      ),
      exists: true,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'update': {
        'name': _getDocumentName(path),
        'fields': _dataToFields(data),
      },
    };
  }

  Map<String, dynamic> _dataToFields(Map<String, dynamic> data) {
    final fields = <String, dynamic>{};
    data.forEach((key, value) {
      fields[key] = _valueToField(value);
    });
    return fields;
  }

  dynamic _valueToField(dynamic value) {
    if (value == null) {
      return {'nullValue': null};
    } else if (value is bool) {
      return {'booleanValue': value};
    } else if (value is int) {
      return {'integerValue': value.toString()};
    } else if (value is double) {
      return {'doubleValue': value};
    } else if (value is String) {
      return {'stringValue': value};
    } else if (value is DateTime) {
      return {'timestampValue': value.toUtc().toIso8601String()};
    } else if (value is List) {
      return {
        'arrayValue': {
          'values': value.map(_valueToField).toList(),
        }
      };
    } else if (value is Map) {
      return {
        'mapValue': {
          'fields': _dataToFields(value as Map<String, dynamic>),
        }
      };
    } else if (value is FieldValue) {
      return _fieldValueToJson(value);
    }
    throw ArgumentError('Unsupported value type: ${value.runtimeType}');
  }

  Map<String, dynamic> _fieldValueToJson(FieldValue value) {
    if (value is ServerTimestampFieldValue) {
      return {'timestampValue': 'REQUEST_TIME'};
    } else if (value is IncrementFieldValue) {
      return _valueToField(value.value);
    }
    throw ArgumentError('Unsupported FieldValue type: ${value.runtimeType}');
  }

  String _getDocumentName(String path) {
    // This will be completed with proper project/database path
    return 'projects/{project}/databases/{database}/documents/$path';
  }
}

/// Represents a merge set operation.
class MergeSetMutation extends Mutation {
  final Map<String, dynamic> data;
  final List<Object>? mergeFields;

  const MergeSetMutation({
    required super.path,
    required this.data,
    this.mergeFields,
  });

  @override
  Document apply(Document? document) {
    final existingData =
        document?.exists == true ? document!.data : <String, dynamic>{};
    final mergedData = Map<String, dynamic>.from(existingData);

    if (mergeFields != null) {
      // Merge only specified fields
      for (final field in mergeFields!) {
        final fieldPath =
            field is String ? FieldPath.fromString(field) : field as FieldPath;
        _setNestedValue(
            mergedData, fieldPath, _getNestedValue(data, fieldPath));
      }
    } else {
      // Merge all fields
      _deepMerge(mergedData, data);
    }

    return Document(
      path: path,
      data: mergedData,
      metadata: const SnapshotMetadata(
        hasPendingWrites: true,
        isFromCache: true,
      ),
      exists: true,
    );
  }

  void _deepMerge(Map<String, dynamic> target, Map<String, dynamic> source) {
    source.forEach((key, value) {
      if (value is Map<String, dynamic> &&
          target[key] is Map<String, dynamic>) {
        _deepMerge(target[key] as Map<String, dynamic>, value);
      } else {
        target[key] = value;
      }
    });
  }

  dynamic _getNestedValue(Map<String, dynamic> data, FieldPath fieldPath) {
    dynamic current = data;
    for (final component in fieldPath.components) {
      if (current is! Map) return null;
      current = current[component];
    }
    return current;
  }

  void _setNestedValue(
      Map<String, dynamic> data, FieldPath fieldPath, dynamic value) {
    Map<String, dynamic> current = data;
    for (var i = 0; i < fieldPath.components.length - 1; i++) {
      final component = fieldPath.components[i];
      if (!current.containsKey(component) || current[component] is! Map) {
        current[component] = <String, dynamic>{};
      }
      current = current[component] as Map<String, dynamic>;
    }
    current[fieldPath.components.last] = value;
  }

  @override
  Map<String, dynamic> toJson() {
    // Similar to SetMutation but with updateMask
    final setMutation = SetMutation(path: path, data: data);
    final json = setMutation.toJson();

    if (mergeFields != null) {
      json['updateMask'] = {
        'fieldPaths': mergeFields!.map((f) {
          if (f is String) return f;
          if (f is FieldPath) return f.toString();
          throw ArgumentError('Invalid merge field type');
        }).toList(),
      };
    }

    return json;
  }
}

/// Represents an update operation.
class UpdateMutation extends Mutation {
  final Map<String, dynamic> data;

  const UpdateMutation({
    required super.path,
    required this.data,
  });

  @override
  Document apply(Document? document) {
    if (document == null || !document.exists) {
      throw FirestoreException(
        code: FirestoreException.codeNotFound,
        message: 'Document does not exist',
      );
    }

    final updatedData = Map<String, dynamic>.from(document.data);
    data.forEach((key, value) {
      if (value is DeleteFieldValue) {
        updatedData.remove(key);
      } else {
        updatedData[key] = value;
      }
    });

    return Document(
      path: path,
      data: updatedData,
      metadata: const SnapshotMetadata(
        hasPendingWrites: true,
        isFromCache: true,
      ),
      exists: true,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final setMutation = SetMutation(path: path, data: data);
    final json = setMutation.toJson();

    json['updateMask'] = {
      'fieldPaths': data.keys.toList(),
    };
    json['currentDocument'] = {'exists': true};

    return json;
  }
}

/// Represents a delete operation.
class DeleteMutation extends Mutation {
  const DeleteMutation({required super.path});

  @override
  Document apply(Document? document) {
    return Document.nonExistent(path);
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'delete': 'projects/{project}/databases/{database}/documents/$path',
    };
  }
}
