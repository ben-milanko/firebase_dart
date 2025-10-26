import 'dart:async';

import 'package:firebase_dart/firestore.dart';

import 'document.dart';
import 'mutation.dart';
import 'query_impl.dart';
import 'local_store.dart';
import 'remote_store.dart';

/// Coordinates synchronization between local and remote stores.
class SyncEngine {
  LocalStore? _localStore;
  RemoteStore? _remoteStore;
  bool _initialized = false;

  final _pendingWrites = <Completer<void>>[];
  final _documentListeners = <String, StreamController<Document>>{};
  final _queryListeners = <QueryImpl, StreamController<List<Document>>>{};

  void initialize(LocalStore localStore, RemoteStore remoteStore) {
    _localStore = localStore;
    _remoteStore = remoteStore;
    _initialized = true;
  }

  void _verifyInitialized() {
    if (!_initialized) {
      throw FirestoreException(
        code: 'failed-precondition',
        message: 'SyncEngine not initialized',
      );
    }
  }

  /// Writes mutations to both local and remote stores.
  Future<void> write(List<Mutation> mutations) async {
    _verifyInitialized();

    // Apply mutations locally immediately (optimistic update)
    for (final mutation in mutations) {
      await _localStore!.applyMutation(mutation);
    }

    // Notify document listeners
    for (final mutation in mutations) {
      final controller = _documentListeners[mutation.path];
      if (controller != null) {
        final doc = await _localStore!.getDocument(mutation.path);
        controller.add(doc);
      }
    }

    // Queue for remote sync
    final completer = Completer<void>();
    _pendingWrites.add(completer);

    try {
      await _remoteStore!.writeMutations(mutations);

      // Update local store with server-confirmed data
      for (final mutation in mutations) {
        final doc = await _remoteStore!.getDocument(mutation.path);
        await _localStore!.updateDocument(doc);

        // Notify listeners of server update
        final controller = _documentListeners[mutation.path];
        if (controller != null) {
          controller.add(doc);
        }
      }

      completer.complete();
    } catch (e) {
      completer.completeError(e);
    } finally {
      _pendingWrites.remove(completer);
    }
  }

  /// Writes mutations within a transaction.
  Future<void> writeInTransaction(
      List<Mutation> mutations, Set<String> readPaths) async {
    _verifyInitialized();

    // Transactions must go to server immediately
    await _remoteStore!.writeMutationsInTransaction(mutations, readPaths);

    // Update local cache
    for (final mutation in mutations) {
      await _localStore!.applyMutation(mutation);
      final doc = await _remoteStore!.getDocument(mutation.path);
      await _localStore!.updateDocument(doc);

      // Notify listeners
      final controller = _documentListeners[mutation.path];
      if (controller != null) {
        controller.add(doc);
      }
    }
  }

  /// Gets a document from the appropriate source.
  Future<Document> getDocument(String path,
      {Source source = Source.defaultSource}) async {
    _verifyInitialized();

    switch (source) {
      case Source.cache:
        return await _localStore!.getDocument(path);

      case Source.server:
        try {
          final doc = await _remoteStore!.getDocument(path);
          await _localStore!.updateDocument(doc);
          return doc;
        } catch (e) {
          if (e is FirestoreException &&
              e.code == FirestoreException.codeUnavailable) {
            // Fallback to cache if server unavailable
            return await _localStore!.getDocument(path);
          }
          rethrow;
        }

      case Source.defaultSource:
        // Try server first, fallback to cache
        try {
          final doc = await _remoteStore!.getDocument(path);
          await _localStore!.updateDocument(doc);
          return doc;
        } catch (e) {
          return await _localStore!.getDocument(path);
        }
    }
  }

  /// Executes a query from the appropriate source.
  Future<List<Document>> executeQuery(QueryImpl query,
      {Source source = Source.defaultSource}) async {
    _verifyInitialized();

    switch (source) {
      case Source.cache:
        return await _localStore!.executeQuery(query);

      case Source.server:
        try {
          final docs = await _remoteStore!.executeQuery(query);
          for (final doc in docs) {
            await _localStore!.updateDocument(doc);
          }
          return docs;
        } catch (e) {
          if (e is FirestoreException &&
              e.code == FirestoreException.codeUnavailable) {
            return await _localStore!.executeQuery(query);
          }
          rethrow;
        }

      case Source.defaultSource:
        try {
          final docs = await _remoteStore!.executeQuery(query);
          for (final doc in docs) {
            await _localStore!.updateDocument(doc);
          }
          return docs;
        } catch (e) {
          return await _localStore!.executeQuery(query);
        }
    }
  }

  /// Listens to document changes.
  Stream<Document> listenToDocument(String path,
      {bool includeMetadataChanges = false}) {
    _verifyInitialized();

    if (_documentListeners.containsKey(path)) {
      return _documentListeners[path]!.stream;
    }

    final controller = StreamController<Document>.broadcast();
    _documentListeners[path] = controller;

    // Start listening to remote changes
    _remoteStore!.listenToDocument(path).listen(
      (doc) async {
        await _localStore!.updateDocument(doc);
        if (!controller.isClosed) {
          controller.add(doc);
        }
      },
      onError: (error) {
        if (!controller.isClosed) {
          controller.addError(error);
        }
      },
    );

    // Emit initial value from cache
    _localStore!.getDocument(path).then((doc) {
      if (!controller.isClosed) {
        controller.add(doc);
      }
    });

    controller.onCancel = () {
      _documentListeners.remove(path);
    };

    return controller.stream;
  }

  /// Listens to query changes.
  Stream<List<Document>> listenToQuery(QueryImpl query,
      {bool includeMetadataChanges = false}) {
    _verifyInitialized();

    if (_queryListeners.containsKey(query)) {
      return _queryListeners[query]!.stream;
    }

    final controller = StreamController<List<Document>>.broadcast();
    _queryListeners[query] = controller;

    // Start listening to remote changes
    _remoteStore!.listenToQuery(query).listen(
      (docs) async {
        for (final doc in docs) {
          await _localStore!.updateDocument(doc);
        }
        if (!controller.isClosed) {
          controller.add(docs);
        }
      },
      onError: (error) {
        if (!controller.isClosed) {
          controller.addError(error);
        }
      },
    );

    // Emit initial value from cache
    _localStore!.executeQuery(query).then((docs) {
      if (!controller.isClosed) {
        controller.add(docs);
      }
    });

    controller.onCancel = () {
      _queryListeners.remove(query);
    };

    return controller.stream;
  }

  /// Waits for all pending writes to complete.
  Future<void> waitForPendingWrites() async {
    _verifyInitialized();
    await Future.wait(_pendingWrites.map((c) => c.future));
  }

  /// Terminates the sync engine.
  Future<void> terminate() async {
    _initialized = false;

    for (final controller in _documentListeners.values) {
      await controller.close();
    }
    _documentListeners.clear();

    for (final controller in _queryListeners.values) {
      await controller.close();
    }
    _queryListeners.clear();

    _pendingWrites.clear();
  }
}
