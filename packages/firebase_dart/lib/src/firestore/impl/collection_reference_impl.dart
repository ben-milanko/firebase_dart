import 'dart:async';

import 'package:firebase_dart/firestore.dart';
import 'package:uuid/uuid.dart';

import 'document_reference_impl.dart';
import 'query_impl.dart';

class CollectionReferenceImpl extends QueryImpl implements CollectionReference {
  CollectionReferenceImpl({
    required super.firestore,
    required String path,
  }) : super(path: path);

  @override
  String get id => path.split('/').last;

  @override
  String get path => super.path!;

  @override
  DocumentReference? get parent {
    final segments = path.split('/');
    if (segments.length < 2) {
      return null; // Root collection has no parent
    }
    final parentPath = segments.sublist(0, segments.length - 1).join('/');
    return DocumentReferenceImpl(
      firestore: firestore,
      path: parentPath,
    );
  }

  @override
  DocumentReference doc([String? docPath]) {
    final docId = docPath ?? const Uuid().v4();

    if (docId.isEmpty) {
      throw ArgumentError('Document ID must not be empty');
    }
    if (docId.contains('/')) {
      throw ArgumentError('Document ID must not contain "/"');
    }

    return DocumentReferenceImpl(
      firestore: firestore,
      path: '$path/$docId',
    );
  }

  @override
  Future<DocumentReference> add(Map<String, dynamic> data) async {
    final docRef = doc();
    await docRef.set(data);
    return docRef;
  }

  @override
  String toString() => 'CollectionReference($path)';
}
