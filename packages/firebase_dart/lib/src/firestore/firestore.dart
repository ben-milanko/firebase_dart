part of '../firestore.dart';

/// The entry point for accessing a Cloud Firestore database.
///
/// You can get an instance by calling [FirebaseFirestore.instance].
abstract class FirebaseFirestore {
  /// Returns the [FirebaseApp] instance to which this [FirebaseFirestore] belongs.
  FirebaseApp get app;

  /// Returns the settings used by this [FirebaseFirestore] instance.
  Settings get settings;

  /// Gets an instance of [FirebaseFirestore] for the default [FirebaseApp].
  static FirebaseFirestore get instance =>
      FirebaseFirestore.instanceFor(app: Firebase.app());

  /// Gets an instance of [FirebaseFirestore] for the specified [FirebaseApp].
  ///
  /// If [app] is not specified, the default [FirebaseApp] is used.
  /// If [databaseId] is not specified, the default database is used.
  factory FirebaseFirestore({FirebaseApp? app, String? databaseId}) {
    return FirebaseImplementation.installation
        .createFirestore(app ?? Firebase.app(), databaseId: databaseId);
  }

  /// Gets an instance of [FirebaseFirestore] for a specific [FirebaseApp] and
  /// database ID.
  static FirebaseFirestore instanceFor({
    required FirebaseApp app,
    String? databaseId,
  }) {
    return FirebaseImplementation.installation
        .createFirestore(app, databaseId: databaseId);
  }

  /// Gets a [CollectionReference] for the specified collection path.
  CollectionReference collection(String collectionPath);

  /// Gets a [DocumentReference] for the specified document path.
  DocumentReference doc(String documentPath);

  /// Gets a [Query] for the specified collection group.
  ///
  /// A collection group consists of all collections in the database with the
  /// same ID.
  Query collectionGroup(String collectionId);

  /// Creates a write batch, used for performing multiple writes as a single
  /// atomic operation.
  WriteBatch batch();

  /// Executes the given [transactionHandler] as a transaction.
  ///
  /// Transactions are atomic, meaning that any reads must happen before any
  /// writes, and all writes will either succeed or fail together.
  ///
  /// The [transactionHandler] may be executed multiple times. It should be
  /// able to handle multiple executions and should not have side effects.
  Future<T> runTransaction<T>(
    Future<T> Function(Transaction transaction) transactionHandler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  });

  /// Clears the persistent storage. This includes pending writes and cached
  /// documents.
  ///
  /// Must be called while the [FirebaseFirestore] instance is not started
  /// (after the app is terminated and before it is first used).
  Future<void> clearPersistence();

  /// Enables network usage for this instance.
  Future<void> enableNetwork();

  /// Disables network usage for this instance. It can be re-enabled via
  /// [enableNetwork].
  ///
  /// While the network is disabled, any snapshot listeners or get calls will
  /// return results from cache, and any write operations will be queued until
  /// the network is restored.
  Future<void> disableNetwork();

  /// Waits until all currently pending writes for the active user have been
  /// acknowledged by the backend.
  ///
  /// The returned [Future] completes immediately if there are no outstanding
  /// writes. Otherwise, the [Future] waits for all previously issued writes
  /// (including those written in a previous app session), but it does not wait
  /// for writes that were added after the method is called.
  Future<void> waitForPendingWrites();

  /// Terminates this [FirebaseFirestore] instance.
  ///
  /// After calling [terminate], only the [clearPersistence] method may be used.
  /// Calling any other method will result in an error.
  Future<void> terminate();

  /// Re-enables usage of this [FirebaseFirestore] instance after termination.
  Future<void> initializeApp();

  /// Configures Firestore to use the specified settings.
  ///
  /// Note: This must be set before any other operations are performed on this
  /// [FirebaseFirestore] instance.
  void useEmulator(String host, int port);
}
