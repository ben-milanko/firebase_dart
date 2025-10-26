import 'dart:async';

import 'package:firebase_dart/firestore.dart';

import 'document.dart';
import 'mutation.dart';
import 'query_impl.dart';
import 'backend/backend.dart';

/// Manages remote backend communication.
class RemoteStore {
  final FirestoreBackend backend;

  RemoteStore({required this.backend});

  /// Gets a document from the remote backend.
  Future<Document> getDocument(String path) async {
    return await backend.getDocument(path);
  }

  /// Executes a query on the remote backend.
  Future<List<Document>> executeQuery(QueryImpl query) async {
    return await backend.executeQuery(query);
  }

  /// Writes mutations to the remote backend.
  Future<void> writeMutations(List<Mutation> mutations) async {
    await backend.commit(mutations);
  }

  /// Writes mutations within a transaction.
  Future<void> writeMutationsInTransaction(
      List<Mutation> mutations, Set<String> readPaths) async {
    await backend.commitTransaction(mutations, readPaths);
  }

  /// Listens to document changes from the remote backend.
  Stream<Document> listenToDocument(String path) {
    return backend.listenToDocument(path);
  }

  /// Listens to query changes from the remote backend.
  Stream<List<Document>> listenToQuery(QueryImpl query) {
    return backend.listenToQuery(query);
  }

  /// Updates settings (e.g., for emulator).
  void updateSettings(Settings settings) {
    // Delegate to backend if it supports settings
    // The backend should handle this if needed
  }

  /// Enables network connectivity.
  Future<void> enableNetwork() async {
    await backend.enableNetwork();
  }

  /// Disables network connectivity.
  Future<void> disableNetwork() async {
    await backend.disableNetwork();
  }

  /// Terminates the remote store.
  Future<void> terminate() async {
    await backend.terminate();
  }
}
