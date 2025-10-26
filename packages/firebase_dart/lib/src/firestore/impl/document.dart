import 'package:firebase_dart/firestore.dart';

/// Internal representation of a Firestore document.
class Document {
  final String path;
  final Map<String, dynamic> data;
  final SnapshotMetadata metadata;
  final bool exists;
  final int? version;

  const Document({
    required this.path,
    required this.data,
    required this.metadata,
    this.exists = true,
    this.version,
  });

  /// Creates a non-existent document.
  factory Document.nonExistent(String path) {
    return Document(
      path: path,
      data: const {},
      metadata: const SnapshotMetadata(
        hasPendingWrites: false,
        isFromCache: true,
      ),
      exists: false,
    );
  }

  /// Creates a document from server data.
  factory Document.fromServerData({
    required String path,
    required Map<String, dynamic> data,
    int? version,
  }) {
    return Document(
      path: path,
      data: data,
      metadata: const SnapshotMetadata(
        hasPendingWrites: false,
        isFromCache: false,
      ),
      exists: true,
      version: version,
    );
  }

  /// Creates a document from cached data.
  Document withCached() {
    return Document(
      path: path,
      data: data,
      metadata: SnapshotMetadata(
        hasPendingWrites: metadata.hasPendingWrites,
        isFromCache: true,
      ),
      exists: exists,
      version: version,
    );
  }

  /// Creates a document with pending writes.
  Document withPendingWrites() {
    return Document(
      path: path,
      data: data,
      metadata: SnapshotMetadata(
        hasPendingWrites: true,
        isFromCache: metadata.isFromCache,
      ),
      exists: exists,
      version: version,
    );
  }

  @override
  String toString() => 'Document($path, exists: $exists, version: $version)';
}
