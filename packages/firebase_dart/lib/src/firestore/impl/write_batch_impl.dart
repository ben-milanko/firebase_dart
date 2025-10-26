import 'dart:async';

import 'package:firebase_dart/firestore.dart';

import 'firestore_impl.dart';
import 'mutation.dart';

class WriteBatchImpl extends WriteBatch {
  final FirestoreImpl firestore;
  final List<Mutation> _mutations = [];
  bool _committed = false;

  WriteBatchImpl({required this.firestore});

  void _verifyNotCommitted() {
    if (_committed) {
      throw FirestoreException(
        code: 'failed-precondition',
        message: 'Cannot modify a WriteBatch that has already been committed.',
      );
    }
  }

  @override
  void set(DocumentReference document, Map<String, dynamic> data,
      [SetOptions? options]) {
    _verifyNotCommitted();

    final mutation = options?.merge == true
        ? MergeSetMutation(
            path: document.path,
            data: data,
            mergeFields: options?.mergeFields,
          )
        : SetMutation(
            path: document.path,
            data: data,
          );

    _mutations.add(mutation);
  }

  @override
  void update(DocumentReference document, Map<String, dynamic> data) {
    _verifyNotCommitted();

    if (data.isEmpty) {
      throw ArgumentError('Data must not be empty');
    }

    _mutations.add(UpdateMutation(
      path: document.path,
      data: data,
    ));
  }

  @override
  void delete(DocumentReference document) {
    _verifyNotCommitted();
    _mutations.add(DeleteMutation(path: document.path));
  }

  @override
  Future<void> commit() async {
    _verifyNotCommitted();
    _committed = true;

    if (_mutations.isEmpty) {
      return;
    }

    await firestore.syncEngine.write(_mutations);
  }
}
