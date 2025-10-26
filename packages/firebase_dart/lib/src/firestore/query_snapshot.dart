part of '../firestore.dart';

/// A [QuerySnapshot] contains zero or more [DocumentSnapshot] objects
/// representing the results of a query.
///
/// The documents can be accessed as a list via the [docs] property or
/// enumerated using the [forEach] method.
abstract class QuerySnapshot {
  /// An list of all the documents in this snapshot.
  List<DocumentSnapshot> get docs;

  /// The number of documents in this snapshot.
  int get size;

  /// Metadata about this snapshot concerning its source and if it has local
  /// modifications.
  SnapshotMetadata get metadata;

  /// Returns the list of documents that changed since the last snapshot.
  List<DocumentChange> get docChanges;

  /// Returns true if there are no documents.
  bool get isEmpty;

  /// Iterates over the documents in this snapshot.
  void forEach(void Function(DocumentSnapshot doc) action);
}

/// A [DocumentChange] represents a change to the documents matching a query.
///
/// It contains the document affected and the type of change that occurred
/// (added, modified, or removed).
class DocumentChange {
  /// The type of change that occurred (added, modified, or removed).
  final DocumentChangeType type;

  /// The document affected by this change.
  final DocumentSnapshot doc;

  /// The index of the changed document in the result set immediately prior to
  /// this [DocumentChange].
  final int oldIndex;

  /// The index of the changed document in the result set immediately after
  /// this [DocumentChange].
  final int newIndex;

  const DocumentChange({
    required this.type,
    required this.doc,
    required this.oldIndex,
    required this.newIndex,
  });
}

/// The type of a [DocumentChange].
enum DocumentChangeType {
  /// Indicates a new document was added to the set of documents matching the
  /// query.
  added,

  /// Indicates a document within the query was modified.
  modified,

  /// Indicates a document within the query was removed (either deleted or no
  /// longer matches the query).
  removed,
}
