part of '../firestore.dart';

/// Sentinel values that can be used when writing document fields with set() or
/// update().
abstract class FieldValue {
  const FieldValue._();

  /// Returns a sentinel used with set() or update() to include a server-
  /// generated timestamp in the written data.
  static ServerTimestampFieldValue serverTimestamp() =>
      const ServerTimestampFieldValue._();

  /// Returns a special value that can be used with set() or update() that tells
  /// the server to remove the given elements from any array value that already
  /// exists on the server.
  static ArrayRemoveFieldValue arrayRemove(List<Object?> elements) =>
      ArrayRemoveFieldValue._(elements);

  /// Returns a special value that can be used with set() or update() that tells
  /// the server to union the given elements with any array value that already
  /// exists on the server.
  static ArrayUnionFieldValue arrayUnion(List<Object?> elements) =>
      ArrayUnionFieldValue._(elements);

  /// Returns a sentinel used with update() to mark a field for deletion.
  static DeleteFieldValue delete() => const DeleteFieldValue._();

  /// Returns a special value that can be used with set() or update() that tells
  /// the server to increment the field's current value by the given value.
  static IncrementFieldValue increment(num value) =>
      IncrementFieldValue._(value);
}

/// A [FieldValue] that represents a server timestamp.
class ServerTimestampFieldValue extends FieldValue {
  const ServerTimestampFieldValue._() : super._();

  @override
  String toString() => 'FieldValue.serverTimestamp()';
}

/// A [FieldValue] that represents an array union operation.
class ArrayUnionFieldValue extends FieldValue {
  final List<Object?> elements;

  const ArrayUnionFieldValue._(this.elements) : super._();

  @override
  String toString() => 'FieldValue.arrayUnion($elements)';
}

/// A [FieldValue] that represents an array remove operation.
class ArrayRemoveFieldValue extends FieldValue {
  final List<Object?> elements;

  const ArrayRemoveFieldValue._(this.elements) : super._();

  @override
  String toString() => 'FieldValue.arrayRemove($elements)';
}

/// A [FieldValue] that represents a delete operation.
class DeleteFieldValue extends FieldValue {
  const DeleteFieldValue._() : super._();

  @override
  String toString() => 'FieldValue.delete()';
}

/// A [FieldValue] that represents an increment operation.
class IncrementFieldValue extends FieldValue {
  final num value;

  const IncrementFieldValue._(this.value) : super._();

  @override
  String toString() => 'FieldValue.increment($value)';
}
