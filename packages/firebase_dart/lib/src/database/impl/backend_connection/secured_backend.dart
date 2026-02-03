part of '../backend_connection.dart';

class SecuredBackend extends Backend {
  final BehaviorSubject<SecurityTree> _securityTree = BehaviorSubject.seeded(
      SecurityTree.fromJson({'.read': 'true', '.write': 'true'}));

  final Backend unsecuredBackend;

  final List<_ListenerRegistration> _registrations = [];

  SecuredBackend.from(this.unsecuredBackend);

  SecurityTree get securityTree => _securityTree.value;

  set securityRules(Map<String, dynamic> rules) {
    _securityTree.add(SecurityTree.fromJson(rules));
  }

  @override
  Future<void> auth(Auth? auth) async {
    await super.auth(auth);
    _securityTree.add(securityTree);
  }

  @override
  Future<List<String>> listen(String path, EventListener listener,
      {QueryFilter query = const QueryFilter(), String? hash}) async {
    var completer = Completer();

    var root = RuleDataSnapshotFromBackend.root(unsecuredBackend);
    var subscription = _securityTree
        .switchMap((v) =>
            v.canRead(auth: currentAuth, path: path, root: root, query: query))
        .listen((canRead) {
      if (!canRead) {
        if (completer.isCompleted) {
          listener(CancelEvent(FirebaseDatabaseException.permissionDenied(),
              StackTrace.current));
          unlisten(path, listener, query: query);
        } else {
          completer.completeError(
              FirebaseDatabaseException.permissionDenied(), StackTrace.current);
        }
      } else {
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    });
    _registrations
        .add(_ListenerRegistration(path, query, listener, subscription));
    await completer.future;

    var warnings = <String>[];
    if (!query.orderBy.startsWith('.')) {
      var indexed = securityTree.isIndexed(path: path, child: query.orderBy);
      if (!indexed) {
        query = const QueryFilter();
        listener(UpgradeEvent());
        warnings.add('no_index');
      }
    }
    return [
      ...warnings,
      ...await unsecuredBackend.listen(path, listener,
          query: query, hash: hash),
    ];
  }

  @override
  Future<void> unlisten(String path, EventListener? listener,
      {QueryFilter query = const QueryFilter()}) async {
    if (!query.orderBy.startsWith('.')) {
      var indexed = securityTree.isIndexed(path: path, child: query.orderBy);
      if (!indexed) {
        query = const QueryFilter();
      }
    }

    _registrations.removeWhere((reg) {
      if (reg.path == path &&
          reg.query == query &&
          (listener == null || reg.listener == listener)) {
        reg.subscription.cancel();
        return true;
      }
      return false;
    });

    await unsecuredBackend.unlisten(path, listener, query: query);
  }

  @override
  Future<void> merge(String path, Map<String, dynamic> children) async {
    // Check write rules and validate rules for merge operation
    var root = RuleDataSnapshotFromBackend.root(unsecuredBackend);
    var newDataRoot = RuleDataSnapshotFromBackend.root(unsecuredBackend);
    
    // Check write permissions for the path being merged
    var canWrite = await securityTree
        .canWrite(
            root: root,
            path: path,
            auth: currentAuth,
            newData: newDataRoot)
        .first;
    
    if (!canWrite) {
      throw FirebaseDatabaseException.permissionDenied();
    }
    
    // Check validation rules for each child being merged
    for (var childPath in children.keys) {
      var fullPath = path.isEmpty ? childPath : '$path/$childPath';
      var isValid = await securityTree
          .validate(
              root: root,
              path: fullPath,
              auth: currentAuth,
              newData: newDataRoot,
              data: root)
          .first;
      
      if (!isValid) {
        throw FirebaseDatabaseException.permissionDenied()
            .replace(message: 'Validation failed for path: $fullPath');
      }
    }
    
    await unsecuredBackend.merge(path, children);
  }

  @override
  Future<void> put(String path, value, {String? hash}) async {
    // Check write rules and validate rules for put operation
    var root = RuleDataSnapshotFromBackend.root(unsecuredBackend);
    var newDataRoot = RuleDataSnapshotFromBackend.root(unsecuredBackend);
    
    // Check write permissions
    var canWrite = await securityTree
        .canWrite(
            root: root,
            path: path,
            auth: currentAuth,
            newData: newDataRoot)
        .first;
    
    if (!canWrite) {
      throw FirebaseDatabaseException.permissionDenied();
    }
    
    // Check validation rules
    var isValid = await securityTree
        .validate(
            root: root,
            path: path,
            auth: currentAuth,
            newData: newDataRoot,
            data: root)
        .first;
    
    if (!isValid) {
      throw FirebaseDatabaseException.permissionDenied()
          .replace(message: 'Validation failed for path: $path');
    }
    
    await unsecuredBackend.put(path, value, hash: hash);
  }
}

class UpgradeEvent extends Event {
  UpgradeEvent() : super('upgrade');
}

class _ListenerRegistration {
  final String path;
  final QueryFilter query;
  final EventListener listener;
  final StreamSubscription subscription;

  _ListenerRegistration(this.path, this.query, this.listener, this.subscription);
}
