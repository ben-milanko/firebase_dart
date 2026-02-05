part of '../firestore.dart';

/// Settings used to configure a [FirebaseFirestore] instance.
class Settings {
  /// The hostname to connect to.
  final String? host;

  /// Whether to use SSL when connecting.
  final bool sslEnabled;

  /// Enables or disables local persistent storage.
  final bool persistenceEnabled;

  /// An approximate cache size threshold for the on-disk data. If the cache
  /// grows beyond this size, Firestore will start removing data that hasn't
  /// been recently used.
  ///
  /// The size is not a guarantee that the cache will stay below that size, only
  /// that if the cache exceeds the given size, cleanup will be attempted.
  final int? cacheSizeBytes;

  /// Constant to use with [cacheSizeBytes] to disable garbage collection.
  static const int cacheSizeUnlimited = -1;

  /// The interval between polls for realtime updates when using the REST backend.
  ///
  /// Defaults to 1 second.
  final Duration pollingInterval;

  /// Whether to use the gRPC backend instead of REST polling.
  final bool useGrpc;

  const Settings({
    this.host,
    this.sslEnabled = true,
    this.persistenceEnabled = true,
    this.cacheSizeBytes,
    this.pollingInterval = const Duration(seconds: 1),
    this.useGrpc = true,
  });

  Settings copyWith({
    String? host,
    bool? sslEnabled,
    bool? persistenceEnabled,
    int? cacheSizeBytes,
    Duration? pollingInterval,
    bool? useGrpc,
  }) {
    return Settings(
      host: host ?? this.host,
      sslEnabled: sslEnabled ?? this.sslEnabled,
      persistenceEnabled: persistenceEnabled ?? this.persistenceEnabled,
      cacheSizeBytes: cacheSizeBytes ?? this.cacheSizeBytes,
      pollingInterval: pollingInterval ?? this.pollingInterval,
      useGrpc: useGrpc ?? this.useGrpc,
    );
  }
}
