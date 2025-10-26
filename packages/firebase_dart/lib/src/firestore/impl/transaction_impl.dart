import 'dart:async';

import 'package:firebase_dart/firestore.dart';

import 'document_snapshot_impl.dart';
import 'firestore_impl.dart';
import 'mutation.dart';

class TransactionImpl extends Transaction {
  final FirestoreImpl firestore;
  final Duration timeout;
  final List<Mutation> _mutations = [];
  final Set<String> _readPaths = {};
  bool _committed = false;

  TransactionImpl({
    required this.firestore,
    required this.timeout,
  });

  void _verifyNotCommitted() {
    if (_committed) {
      throw FirestoreException(
        code: 'failed-precondition',
        message: 'Transaction has already been committed or aborted.',
      );
    }
  }

  @override
  Future<DocumentSnapshot> get(DocumentReference documentReference) async {
    _verifyNotCommitted();
    _readPaths.add(documentReference.path);

    final document = await firestore.syncEngine.getDocument(
      documentReference.path,
      source: Source.server, // Transactions must read from server
    );

    return DocumentSnapshotImpl(
      reference: documentReference,
      document: document,
    );
  }

  @override
  Transaction set(DocumentReference documentReference, Map<String, dynamic> data,
      [SetOptions? options]) {
    _verifyNotCommitted();

    final mutation = options?.merge == true
        ? MergeSetMutation(
            path: documentReference.path,
            data: data,
            mergeFields: options?.mergeFields,
          )
        : SetMutation(
            path: documentReference.path,
            data: data,
          );

    _mutations.add(mutation);
    return this;
  }

  @override
  Transaction update(
      DocumentReference documentReference, Map<String, dynamic> data) {
    _verifyNotCommitted();

    if (data.isEmpty) {
      throw ArgumentError('Data must not be empty');
    }

    _mutations.add(UpdateMutation(
      path: documentReference.path,
      data: data,
    ));
    return this;
  }

  @override
  Transaction delete(DocumentReference documentReference) {
    _verifyNotCommitted();
    _mutations.add(DeleteMutation(path: documentReference.path));
    return this;
  }

  Future<void> commitInternal() async {
    _verifyNotCommitted();
    _committed = true;

    if (_mutations.isEmpty) {
      return;
    }

    await firestore.syncEngine.writeInTransaction(_mutations, _readPaths);
  }
}

