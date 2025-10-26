part of '../firestore.dart';

/// A reference to a transaction.
///
/// The [Transaction] object passed to a transaction's updateFunction provides
/// the methods to read and write data within the transaction context. See
/// [FirebaseFirestore.runTransaction].
abstract class Transaction {
  /// Reads the document referenced by the provided [DocumentReference].
  ///
  /// Returns a [Future] that resolves with the document snapshot.
  Future<DocumentSnapshot> get(DocumentReference documentReference);

  /// Writes to the document referred to by the provided [DocumentReference].
  ///
  /// If the document does not yet exist, it will be created. If you pass
  /// [SetOptions], the provided data can be merged into an existing document.
  Transaction set(
      DocumentReference documentReference, Map<String, dynamic> data,
      [SetOptions? options]);

  /// Updates fields in the document referred to by the provided
  /// [DocumentReference].
  ///
  /// The update will fail if applied to a document that does not exist.
  Transaction update(
      DocumentReference documentReference, Map<String, dynamic> data);

  /// Deletes the document referred to by the provided [DocumentReference].
  Transaction delete(DocumentReference documentReference);
}
