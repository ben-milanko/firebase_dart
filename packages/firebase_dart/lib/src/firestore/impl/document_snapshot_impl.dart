import 'package:firebase_dart/firestore.dart';

import 'document.dart';

class DocumentSnapshotImpl extends DocumentSnapshot {
  @override
  final DocumentReference reference;

  final Document? document;

  DocumentSnapshotImpl({
    required this.reference,
    this.document,
  });

  @override
  String get id => reference.id;

  @override
  SnapshotMetadata get metadata =>
      document?.metadata ??
      const SnapshotMetadata(hasPendingWrites: false, isFromCache: true);

  @override
  bool get exists => document != null && document!.exists;

  @override
  Map<String, dynamic>? data() {
    if (!exists) return null;
    return Map<String, dynamic>.from(document!.data);
  }

  @override
  dynamic get(Object field) {
    if (!exists) return null;

    final fieldPath =
        field is String ? FieldPath.fromString(field) : field as FieldPath;
    return _getNestedValue(document!.data, fieldPath);
  }

  @override
  dynamic operator [](Object field) {
    return get(field);
  }

  dynamic _getNestedValue(Map<String, dynamic> data, FieldPath fieldPath) {
    dynamic current = data;
    for (final component in fieldPath.components) {
      if (current is! Map) return null;
      current = current[component];
    }
    return current;
  }

  @override
  String toString() => 'DocumentSnapshot(${reference.path}, exists: $exists)';
}
