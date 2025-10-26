part of '../firestore.dart';

/// A write batch, used to perform multiple writes as a single atomic unit.
///
/// A [WriteBatch] object can be acquired by calling [FirebaseFirestore.batch].
///
/// It provides methods for adding writes to the write batch. None of the writes
/// will be committed (or visible locally) until [commit] is called.
abstract class WriteBatch {
  /// Writes to the document referred to by the provided [DocumentReference].
  ///
  /// If the document does not yet exist, it will be created. If you pass
  /// [SetOptions], the provided data can be merged into an existing document.
  void set(DocumentReference document, Map<String, dynamic> data,
      [SetOptions? options]);

  /// Updates fields in the document referred to by the provided
  /// [DocumentReference].
  ///
  /// The update will fail if applied to a document that does not exist.
  void update(DocumentReference document, Map<String, dynamic> data);

  /// Deletes the document referred to by the provided [DocumentReference].
  void delete(DocumentReference document);

  /// Commits all of the writes in this write batch as a single atomic unit.
  ///
  /// Returns a [Future] that resolves when all of the writes in the batch have
  /// been successfully written to the backend as an atomic unit.
  Future<void> commit();
}
