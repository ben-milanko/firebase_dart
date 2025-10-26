part of '../firestore.dart';

/// A [CollectionReference] object can be used for adding documents, getting
/// document references, and querying for documents.
abstract class CollectionReference extends Query {
  /// The ID of the collection.
  String get id;

  /// A string representing the path of the referenced collection (relative to
  /// the root of the database).
  String get path;

  /// The parent [DocumentReference] of this collection, or null if this
  /// collection is a root collection.
  DocumentReference? get parent;

  /// Returns a [DocumentReference] with the provided path.
  ///
  /// If no [path] is provided, an auto-generated ID will be used.
  DocumentReference doc([String? path]);

  /// Adds a new document to this collection with the specified data, assigning
  /// it a document ID automatically.
  Future<DocumentReference> add(Map<String, dynamic> data);
}
