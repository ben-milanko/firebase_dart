import 'package:firebase_dart/src/database/impl/operations/tree.dart';
import 'package:firebase_dart/src/database/impl/query_spec.dart';
import 'package:firebase_dart/src/database/impl/tree.dart';

import '../data_observer.dart';
import '../treestructureddata.dart';

abstract class PersistenceManager {
  /// Save a user operation
  void saveUserOperation(TreeOperation operation, int writeId);

  /// Remove a user operation with the given write id.
  void removeUserOperation(int writeId);

  /// Returns any cached node or children as a [IncompleteData].
  ///
  /// The query is *not* used to filter the node but rather to determine if it
  /// can be considered complete.
  IncompleteData serverCache(QuerySpec query);

  /// Overwrite the server cache with the given node for a given query.
  ///
  /// The query is considered to be complete after saving this node.
  void updateServerCache(QuerySpec query, TreeOperation operation);

  void setQueryActive(QuerySpec query);

  void setQueryInactive(QuerySpec query);

  void setQueryComplete(QuerySpec query);

  T runInTransaction<T>(T Function() callable);

  /// Loads all persisted user operations.
  ///
  /// Returns an empty map if user operations cannot be loaded (e.g., for NoopPersistenceManager).
  Map<int, TreeOperation> loadUserOperations();

  Future<void> close();

  bool get isEnabled;
}

class FakePersistenceManager extends NoopPersistenceManager {
  final IncompleteData Function(Path<Name> path, QueryFilter filter)
      serverCacheFunction;

  FakePersistenceManager(this.serverCacheFunction);

  @override
  IncompleteData serverCache(QuerySpec query) {
    return serverCacheFunction(query.path, query.params);
  }

  @override
  bool get isEnabled => true;
}

class NoopPersistenceManager implements PersistenceManager {
  int _transactionDepth = 0;

  @override
  bool get isEnabled => false;

  @override
  void saveUserOperation(TreeOperation operation, int writeId) {
    _verifyInsideTransaction();
  }

  @override
  void removeUserOperation(int writeId) {
    _verifyInsideTransaction();
  }

  @override
  IncompleteData serverCache(QuerySpec query) {
    return IncompleteData.empty(query.params);
  }

  @override
  void updateServerCache(QuerySpec query, TreeOperation operation) {
    _verifyInsideTransaction();
  }

  @override
  void setQueryActive(QuerySpec query) {
    _verifyInsideTransaction();
  }

  @override
  void setQueryInactive(QuerySpec query) {
    _verifyInsideTransaction();
  }

  @override
  void setQueryComplete(QuerySpec query) {
    _verifyInsideTransaction();
  }

  @override
  Map<int, TreeOperation> loadUserOperations() {
    return {};
  }

  @override
  T runInTransaction<T>(T Function() callable) {
    _transactionDepth++;
    try {
      return callable();
    } finally {
      _transactionDepth--;
    }
  }

  void _verifyInsideTransaction() {
    assert(_transactionDepth > 0,
        'Transaction expected to already be in progress.');
  }

  @override
  Future<void> close() async {}
}

class DelegatingPersistenceManager implements PersistenceManager {
  final PersistenceManager Function() factory;

  DelegatingPersistenceManager(this.factory);

  late PersistenceManager delegateTo = factory();

  @override
  void removeUserOperation(int writeId) {
    delegateTo.removeUserOperation(writeId);
  }

  @override
  T runInTransaction<T>(T Function() callable) {
    return delegateTo.runInTransaction(callable);
  }

  @override
  void saveUserOperation(TreeOperation operation, int writeId) {
    return delegateTo.saveUserOperation(operation, writeId);
  }

  @override
  IncompleteData serverCache(QuerySpec query) {
    return delegateTo.serverCache(query);
  }

  @override
  void setQueryActive(QuerySpec query) {
    return delegateTo.setQueryActive(query);
  }

  @override
  void setQueryComplete(QuerySpec query) {
    return delegateTo.setQueryComplete(query);
  }

  @override
  void setQueryInactive(QuerySpec query) {
    return delegateTo.setQueryInactive(query);
  }

  @override
  Map<int, TreeOperation> loadUserOperations() {
    return delegateTo.loadUserOperations();
  }

  @override
  void updateServerCache(QuerySpec query, TreeOperation operation) {
    return delegateTo.updateServerCache(query, operation);
  }

  @override
  Future<void> close() {
    return delegateTo.close();
  }

  @override
  bool get isEnabled => delegateTo.isEnabled;
}
