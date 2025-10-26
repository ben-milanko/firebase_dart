import 'dart:async';

import 'package:firebase_dart/core.dart';
import 'package:firebase_dart/firestore.dart';
import 'package:firebase_dart/src/core/impl/app.dart';
import 'package:firebase_dart/src/implementation.dart';

import 'backend/rest_backend.dart';
import 'collection_reference_impl.dart';
import 'document_reference_impl.dart';
import 'local_store.dart';
import 'persistence/memory_persistence.dart';
import 'query_impl.dart';
import 'remote_store.dart';
import 'sync_engine.dart';
import 'transaction_impl.dart';
import 'write_batch_impl.dart';

class FirestoreImpl extends FirebaseService implements FirebaseFirestore {
  final String databaseId;

  Settings _settings;

  final SyncEngine _syncEngine;
  final LocalStore _localStore;
  final RemoteStore _remoteStore;

  bool _terminated = false;

  FirestoreImpl({
    required FirebaseApp app,
    required this.databaseId,
    Settings? settings,
    AuthTokenProvider? authTokenProvider,
  })  : _settings = settings ?? const Settings(),
        _localStore = LocalStore(
          persistence: MemoryPersistence(),
        ),
        _remoteStore = RemoteStore(
          backend: RestBackend(
            projectId: app.options.projectId,
            databaseId: databaseId,
            authTokenProvider: authTokenProvider,
          ),
        ),
        _syncEngine = SyncEngine(),
        super(app) {
    _syncEngine.initialize(_localStore, _remoteStore);
  }

  @override
  Settings get settings => _settings;

  void _verifyNotTerminated() {
    if (_terminated) {
      throw FirestoreException(
        code: 'failed-precondition',
        message: 'The client has already been terminated.',
      );
    }
  }

  @override
  CollectionReference collection(String collectionPath) {
    _verifyNotTerminated();
    if (collectionPath.isEmpty) {
      throw ArgumentError('Collection path must not be empty');
    }
    if (collectionPath.contains('//')) {
      throw ArgumentError('Collection path must not contain "//"');
    }
    if (collectionPath.startsWith('/') || collectionPath.endsWith('/')) {
      throw ArgumentError('Collection path must not start or end with "/"');
    }

    final segments = collectionPath.split('/');
    if (segments.length.isEven) {
      throw ArgumentError(
          'Collection path must have an odd number of segments');
    }

    return CollectionReferenceImpl(
      firestore: this,
      path: collectionPath,
    );
  }

  @override
  DocumentReference doc(String documentPath) {
    _verifyNotTerminated();
    if (documentPath.isEmpty) {
      throw ArgumentError('Document path must not be empty');
    }
    if (documentPath.contains('//')) {
      throw ArgumentError('Document path must not contain "//"');
    }
    if (documentPath.startsWith('/') || documentPath.endsWith('/')) {
      throw ArgumentError('Document path must not start or end with "/"');
    }

    final segments = documentPath.split('/');
    if (segments.length.isOdd) {
      throw ArgumentError('Document path must have an even number of segments');
    }

    return DocumentReferenceImpl(
      firestore: this,
      path: documentPath,
    );
  }

  @override
  Query collectionGroup(String collectionId) {
    _verifyNotTerminated();
    if (collectionId.isEmpty) {
      throw ArgumentError('Collection ID must not be empty');
    }
    if (collectionId.contains('/')) {
      throw ArgumentError('Collection ID must not contain "/"');
    }

    return QueryImpl(
      firestore: this,
      path: null, // null path indicates collection group
      collectionId: collectionId,
      isCollectionGroup: true,
    );
  }

  @override
  WriteBatch batch() {
    _verifyNotTerminated();
    return WriteBatchImpl(firestore: this);
  }

  @override
  Future<T> runTransaction<T>(
    Future<T> Function(Transaction transaction) transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    _verifyNotTerminated();

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        final transaction = TransactionImpl(
          firestore: this,
          timeout: timeout,
        );

        final result = await transactionHandler(transaction);
        await transaction.commitInternal();
        return result;
      } on FirestoreException catch (e) {
        if (e.code == FirestoreException.codeAborted &&
            attempt < maxAttempts - 1) {
          // Retry on abort
          await Future.delayed(Duration(milliseconds: 100 * (attempt + 1)));
          continue;
        }
        rethrow;
      }
    }

    throw FirestoreException(
      code: FirestoreException.codeAborted,
      message: 'Transaction failed after $maxAttempts attempts',
    );
  }

  @override
  Future<void> clearPersistence() async {
    if (!_terminated) {
      throw FirestoreException(
        code: 'failed-precondition',
        message: 'Persistence cannot be cleared while the app is running.',
      );
    }
    await _localStore.clearPersistence();
  }

  @override
  Future<void> enableNetwork() async {
    _verifyNotTerminated();
    await _remoteStore.enableNetwork();
  }

  @override
  Future<void> disableNetwork() async {
    _verifyNotTerminated();
    await _remoteStore.disableNetwork();
  }

  @override
  Future<void> waitForPendingWrites() async {
    _verifyNotTerminated();
    await _syncEngine.waitForPendingWrites();
  }

  @override
  Future<void> terminate() async {
    if (_terminated) return;

    _terminated = true;
    await _syncEngine.terminate();
    await _localStore.terminate();
    await _remoteStore.terminate();
  }

  @override
  Future<void> initializeApp() async {
    if (!_terminated) {
      throw FirestoreException(
        code: 'failed-precondition',
        message: 'Cannot initialize an already-active Firestore instance.',
      );
    }

    _terminated = false;
    _syncEngine.initialize(_localStore, _remoteStore);
  }

  @override
  void useEmulator(String host, int port) {
    _verifyNotTerminated();
    _settings = _settings.copyWith(
      host: '$host:$port',
      sslEnabled: false,
    );
    // Update backend with new settings
    if (_remoteStore.backend is RestBackend) {
      (_remoteStore.backend as RestBackend).updateSettings(_settings);
    }
  }

  // Internal methods for implementation classes
  SyncEngine get syncEngine => _syncEngine;
  LocalStore get localStore => _localStore;
  RemoteStore get remoteStore => _remoteStore;
}
