import '../document.dart';
import 'persistence_manager.dart';

/// In-memory implementation of persistence (no disk storage).
class MemoryPersistence implements PersistenceManager {
  final Map<String, Document> _documents = {};

  @override
  Future<Document?> getDocument(String path) async {
    return _documents[path];
  }

  @override
  Future<void> saveDocument(Document document) async {
    if (document.exists) {
      _documents[document.path] = document;
    } else {
      _documents.remove(document.path);
    }
  }

  @override
  Future<Map<String, Document>> getAllDocuments() async {
    return Map.from(_documents);
  }

  @override
  Future<void> deleteDocument(String path) async {
    _documents.remove(path);
  }

  @override
  Future<void> clear() async {
    _documents.clear();
  }

  @override
  Future<void> close() async {
    // Nothing to close for in-memory storage
  }
}
