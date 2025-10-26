import 'dart:async';

import '../document.dart';
import '../mutation.dart';
import '../query_impl.dart';

/// Abstract backend interface for Firestore operations.
abstract class FirestoreBackend {
  /// Gets a single document from the backend.
  Future<Document> getDocument(String path);

  /// Executes a query on the backend.
  Future<List<Document>> executeQuery(QueryImpl query);

  /// Commits a list of mutations to the backend.
  Future<void> commit(List<Mutation> mutations);

  /// Commits mutations within a transaction.
  Future<void> commitTransaction(
      List<Mutation> mutations, Set<String> readPaths);

  /// Listens to document changes.
  Stream<Document> listenToDocument(String path);

  /// Listens to query changes.
  Stream<List<Document>> listenToQuery(QueryImpl query);

  /// Enables network connectivity.
  Future<void> enableNetwork();

  /// Disables network connectivity.
  Future<void> disableNetwork();

  /// Terminates the backend connection.
  Future<void> terminate();
}
