import '../document.dart';

/// Abstract interface for persistence managers.
abstract class PersistenceManager {
  /// Gets a document from persistence.
  Future<Document?> getDocument(String path);

  /// Saves a document to persistence.
  Future<void> saveDocument(Document document);

  /// Gets all documents from persistence.
  Future<Map<String, Document>> getAllDocuments();

  /// Deletes a document from persistence.
  Future<void> deleteDocument(String path);

  /// Clears all data from persistence.
  Future<void> clear();

  /// Closes the persistence manager.
  Future<void> close();
}
