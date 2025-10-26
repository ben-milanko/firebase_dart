import 'package:hive/hive.dart';

import '../document.dart';
import 'package:firebase_dart/firestore.dart';
import 'persistence_manager.dart';

/// Hive-based implementation of persistence (disk storage).
class HivePersistence implements PersistenceManager {
  final String storagePath;
  Box<Map>? _box;

  HivePersistence(this.storagePath);

  Future<void> _ensureInitialized() async {
    if (_box == null || !_box!.isOpen) {
      Hive.init(storagePath);
      _box = await Hive.openBox<Map>('firestore_documents');
    }
  }

  @override
  Future<Document?> getDocument(String path) async {
    await _ensureInitialized();

    final data = _box!.get(path);
    if (data == null) return null;

    return _deserializeDocument(path, data);
  }

  @override
  Future<void> saveDocument(Document document) async {
    await _ensureInitialized();

    if (document.exists) {
      await _box!.put(document.path, _serializeDocument(document));
    } else {
      await _box!.delete(document.path);
    }
  }

  @override
  Future<Map<String, Document>> getAllDocuments() async {
    await _ensureInitialized();

    final documents = <String, Document>{};
    for (final key in _box!.keys) {
      final data = _box!.get(key);
      if (data != null && key is String) {
        documents[key] = _deserializeDocument(key, data);
      }
    }

    return documents;
  }

  @override
  Future<void> deleteDocument(String path) async {
    await _ensureInitialized();
    await _box!.delete(path);
  }

  @override
  Future<void> clear() async {
    await _ensureInitialized();
    await _box!.clear();
  }

  @override
  Future<void> close() async {
    if (_box != null && _box!.isOpen) {
      await _box!.close();
    }
  }

  Map<String, dynamic> _serializeDocument(Document document) {
    return {
      'data': document.data,
      'exists': document.exists,
      'version': document.version,
      'hasPendingWrites': document.metadata.hasPendingWrites,
      'isFromCache': document.metadata.isFromCache,
    };
  }

  Document _deserializeDocument(String path, Map data) {
    return Document(
      path: path,
      data: Map<String, dynamic>.from(data['data'] ?? {}),
      exists: data['exists'] as bool? ?? true,
      version: data['version'] as int?,
      metadata: SnapshotMetadata(
        hasPendingWrites: data['hasPendingWrites'] as bool? ?? false,
        isFromCache: data['isFromCache'] as bool? ?? true,
      ),
    );
  }
}
