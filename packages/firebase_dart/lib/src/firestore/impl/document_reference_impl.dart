import 'dart:async';

import 'package:firebase_dart/firestore.dart';

import 'firestore_impl.dart';
import 'collection_reference_impl.dart';
import 'document_snapshot_impl.dart';
import 'mutation.dart';

class DocumentReferenceImpl extends DocumentReference {
  @override
  final FirestoreImpl firestore;

  @override
  final String path;

  DocumentReferenceImpl({
    required this.firestore,
    required this.path,
  });

  @override
  String get id => path.split('/').last;

  @override
  CollectionReference get parent {
    final segments = path.split('/');
    if (segments.length < 2) {
      throw StateError('Document has no parent collection');
    }
    final parentPath = segments.sublist(0, segments.length - 1).join('/');
    return CollectionReferenceImpl(
      firestore: firestore,
      path: parentPath,
    );
  }

  @override
  CollectionReference collection(String collectionPath) {
    if (collectionPath.isEmpty) {
      throw ArgumentError('Collection path must not be empty');
    }
    return CollectionReferenceImpl(
      firestore: firestore,
      path: '$path/$collectionPath',
    );
  }

  @override
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]) async {
    if (data.isEmpty && options?.merge != true) {
      throw ArgumentError('Data must not be empty');
    }

    final mutation = options?.merge == true
        ? MergeSetMutation(
            path: path,
            data: data,
            mergeFields: options?.mergeFields,
          )
        : SetMutation(
            path: path,
            data: data,
          );

    await firestore.syncEngine.write([mutation]);
  }

  @override
  Future<void> update(Map<String, dynamic> data) async {
    if (data.isEmpty) {
      throw ArgumentError('Data must not be empty');
    }

    final mutation = UpdateMutation(
      path: path,
      data: data,
    );

    await firestore.syncEngine.write([mutation]);
  }

  @override
  Future<void> delete() async {
    final mutation = DeleteMutation(path: path);
    await firestore.syncEngine.write([mutation]);
  }

  @override
  Future<DocumentSnapshot> get([GetOptions? options]) async {
    final source = options?.source ?? Source.defaultSource;

    final document = await firestore.syncEngine.getDocument(
      path,
      source: source,
    );

    return DocumentSnapshotImpl(
      reference: this,
      document: document,
    );
  }

  @override
  Stream<DocumentSnapshot> snapshots({bool includeMetadataChanges = false}) {
    return firestore.syncEngine
        .listenToDocument(path, includeMetadataChanges: includeMetadataChanges)
        .map((document) => DocumentSnapshotImpl(
              reference: this,
              document: document,
            ));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentReferenceImpl &&
          runtimeType == other.runtimeType &&
          firestore == other.firestore &&
          path == other.path;

  @override
  int get hashCode => firestore.hashCode ^ path.hashCode;

  @override
  String toString() => 'DocumentReference($path)';
}
