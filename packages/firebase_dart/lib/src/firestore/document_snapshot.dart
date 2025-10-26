part of '../firestore.dart';

/// A [DocumentSnapshot] contains data read from a document in your Firestore
/// database.
///
/// The data can be extracted with the [data] or [get] methods.
abstract class DocumentSnapshot {
  /// The [DocumentReference] for the location that this snapshot came from.
  DocumentReference get reference;

  /// The ID of the document.
  String get id;

  /// Metadata about this document snapshot.
  SnapshotMetadata get metadata;

  /// Returns `true` if the document exists.
  bool get exists;

  /// Contains all the data of this document snapshot as a [Map].
  ///
  /// Returns `null` if the document doesn't exist.
  Map<String, dynamic>? data();

  /// Gets a nested field by [String] or [FieldPath] from this document.
  ///
  /// Returns `null` if the field doesn't exist.
  dynamic get(Object field);

  /// Gets a nested field by [String] or [FieldPath] from this document.
  ///
  /// Returns the provided [defaultValue] if the field doesn't exist.
  dynamic operator [](Object field);
}

/// Metadata about a snapshot, describing the state of the snapshot.
class SnapshotMetadata {
  /// Whether the snapshot contains the result of local writes that have not yet
  /// been committed to the backend.
  final bool hasPendingWrites;

  /// Whether the snapshot was created from cached data rather than guaranteed
  /// up-to-date server data.
  final bool isFromCache;

  const SnapshotMetadata({
    required this.hasPendingWrites,
    required this.isFromCache,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SnapshotMetadata &&
          runtimeType == other.runtimeType &&
          hasPendingWrites == other.hasPendingWrites &&
          isFromCache == other.isFromCache;

  @override
  int get hashCode => hasPendingWrites.hashCode ^ isFromCache.hashCode;
}
