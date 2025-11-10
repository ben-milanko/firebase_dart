import 'package:firebase_dart/firestore.dart';

import '../isolate.dart';

/// Basic Firestore implementation for isolate mode.
///
/// Note: Full isolate support for Firestore requires implementing
/// isolate communication for all Firestore operations. This is a
/// placeholder implementation that allows Firestore to be created
/// in isolate mode, but operations will throw UnimplementedError
/// until fully implemented.
class IsolateFirebaseFirestore extends IsolateFirebaseService
    implements FirebaseFirestore {
  final String? databaseId;

  Settings _settings = const Settings();

  IsolateFirebaseFirestore({
    required IsolateFirebaseApp app,
    this.databaseId,
  }) : super(app);

  @override
  Settings get settings => _settings;

  @override
  CollectionReference collection(String collectionPath) {
    // TODO: Implement full isolate support for Firestore collections
    throw UnimplementedError(
        'Firestore collection operations are not yet fully implemented in isolate mode.');
  }

  @override
  DocumentReference doc(String documentPath) {
    // TODO: Implement full isolate support for Firestore documents
    throw UnimplementedError(
        'Firestore document operations are not yet fully implemented in isolate mode.');
  }

  @override
  Query collectionGroup(String collectionId) {
    // TODO: Implement full isolate support for Firestore collection groups
    throw UnimplementedError(
        'Firestore collection group operations are not yet fully implemented in isolate mode.');
  }

  @override
  WriteBatch batch() {
    // TODO: Implement full isolate support for Firestore write batches
    throw UnimplementedError(
        'Firestore write batch operations are not yet fully implemented in isolate mode.');
  }

  @override
  Future<T> runTransaction<T>(
    Future<T> Function(Transaction transaction) transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) async {
    // TODO: Implement full isolate support for Firestore transactions
    throw UnimplementedError(
        'Firestore transaction operations are not yet fully implemented in isolate mode.');
  }

  @override
  Future<void> clearPersistence() async {
    // TODO: Implement clearPersistence in isolate mode
    throw UnimplementedError(
        'clearPersistence is not yet implemented in isolate mode.');
  }

  @override
  Future<void> enableNetwork() async {
    // TODO: Implement enableNetwork in isolate mode
    throw UnimplementedError(
        'enableNetwork is not yet implemented in isolate mode.');
  }

  @override
  Future<void> disableNetwork() async {
    // TODO: Implement disableNetwork in isolate mode
    throw UnimplementedError(
        'disableNetwork is not yet implemented in isolate mode.');
  }

  @override
  Future<void> waitForPendingWrites() async {
    // TODO: Implement waitForPendingWrites in isolate mode
    throw UnimplementedError(
        'waitForPendingWrites is not yet implemented in isolate mode.');
  }

  @override
  Future<void> terminate() async {
    // TODO: Implement terminate in isolate mode
    throw UnimplementedError(
        'terminate is not yet implemented in isolate mode.');
  }

  @override
  Future<void> initializeApp() async {
    // TODO: Implement initializeApp in isolate mode
    throw UnimplementedError(
        'initializeApp is not yet implemented in isolate mode.');
  }

  @override
  void useEmulator(String host, int port) {
    _settings = _settings.copyWith(
      host: '$host:$port',
      sslEnabled: false,
    );
  }
}
