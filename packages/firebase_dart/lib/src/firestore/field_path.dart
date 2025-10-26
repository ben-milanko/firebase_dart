part of '../firestore.dart';

/// A [FieldPath] refers to a field in a document.
///
/// The path may consist of a single field name (referring to a top-level field
/// in the document), or a list of field names (referring to a nested field in
/// the document).
class FieldPath {
  /// The components of this field path.
  final List<String> components;

  /// Creates a [FieldPath] from the provided field names.
  ///
  /// If more than one field name is provided, the path points to a nested field
  /// in a document.
  FieldPath(List<String> fieldNames)
      : components = List.unmodifiable(fieldNames) {
    if (fieldNames.isEmpty) {
      throw ArgumentError('FieldPath must have at least one component');
    }
    for (var name in fieldNames) {
      if (name.isEmpty) {
        throw ArgumentError('FieldPath components must not be empty');
      }
    }
  }

  /// Creates a [FieldPath] from a dot-separated string.
  ///
  /// This is a convenience method for creating a [FieldPath] from a string like
  /// "address.city".
  factory FieldPath.fromString(String path) {
    if (path.isEmpty) {
      throw ArgumentError('FieldPath string must not be empty');
    }
    return FieldPath(path.split('.'));
  }

  /// Returns a special sentinel [FieldPath] to refer to the ID of a document.
  static FieldPath documentId() => FieldPath(['__name__']);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FieldPath &&
          runtimeType == other.runtimeType &&
          _listEquals(components, other.components);

  @override
  int get hashCode =>
      components.fold(0, (prev, element) => prev ^ element.hashCode);

  @override
  String toString() => components.join('.');

  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
