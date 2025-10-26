import 'dart:async';

import 'document.dart';
import 'mutation.dart';
import 'query_impl.dart';
import 'comparator.dart';
import 'persistence/persistence_manager.dart';

/// Manages local document cache and query execution.
class LocalStore {
  final PersistenceManager persistence;
  final Map<String, Document> _cache = {};

  LocalStore({required this.persistence});

  /// Gets a document from local cache.
  Future<Document> getDocument(String path) async {
    // Check in-memory cache first
    if (_cache.containsKey(path)) {
      return _cache[path]!;
    }

    // Try persistence
    final doc = await persistence.getDocument(path);
    if (doc != null) {
      _cache[path] = doc;
      return doc;
    }

    // Document doesn't exist locally
    return Document.nonExistent(path);
  }

  /// Updates a document in local cache.
  Future<void> updateDocument(Document document) async {
    _cache[document.path] = document;
    await persistence.saveDocument(document);
  }

  /// Applies a mutation to local cache (optimistic update).
  Future<void> applyMutation(Mutation mutation) async {
    final currentDoc = await getDocument(mutation.path);
    final updatedDoc = mutation.apply(currentDoc);
    await updateDocument(updatedDoc);
  }

  /// Executes a query against local cache.
  Future<List<Document>> executeQuery(QueryImpl query) async {
    List<Document> documents;

    if (query.isCollectionGroup) {
      // Collection group query - search all documents
      documents = await _getAllDocuments();
      documents = documents.where((doc) {
        final segments = doc.path.split('/');
        return segments.isNotEmpty && segments.last == query.collectionId;
      }).toList();
    } else if (query.path != null) {
      // Collection query - get documents in collection
      documents = await _getCollectionDocuments(query.path!);
    } else {
      return [];
    }

    // Filter out non-existent documents
    documents = documents.where((doc) => doc.exists).toList();

    // Apply filters
    for (final filter in query.filters) {
      documents = documents.where((doc) => filter.matches(doc)).toList();
    }

    // Apply ordering
    if (query.orders.isNotEmpty) {
      final comparator = DocumentComparator(query.orders);
      documents.sort(comparator.compare);
    }

    // Apply boundaries
    if (query.startAtBoundary != null) {
      documents = _applyStartBoundary(documents, query);
    }
    if (query.endAtBoundary != null) {
      documents = _applyEndBoundary(documents, query);
    }

    // Apply limit
    if (query.limitValue != null) {
      documents = documents.take(query.limitValue!).toList();
    }
    if (query.limitToLastValue != null) {
      documents = documents.reversed
          .take(query.limitToLastValue!)
          .toList()
          .reversed
          .toList();
    }

    return documents;
  }

  Future<List<Document>> _getAllDocuments() async {
    // Get all documents from cache and persistence
    final persistedDocs = await persistence.getAllDocuments();

    // Merge with in-memory cache
    final allDocs = Map<String, Document>.from(persistedDocs);
    _cache.forEach((path, doc) {
      allDocs[path] = doc;
    });

    return allDocs.values.toList();
  }

  Future<List<Document>> _getCollectionDocuments(String collectionPath) async {
    final allDocs = await _getAllDocuments();
    final prefix = '$collectionPath/';

    return allDocs.where((doc) {
      // Check if document is a direct child of the collection
      if (!doc.path.startsWith(prefix)) return false;

      final remainder = doc.path.substring(prefix.length);
      // Ensure it's a direct child (no more slashes)
      return !remainder.contains('/');
    }).toList();
  }

  List<Document> _applyStartBoundary(
      List<Document> documents, QueryImpl query) {
    // Simplified boundary application
    // In a real implementation, this would compare based on order fields
    return documents;
  }

  List<Document> _applyEndBoundary(List<Document> documents, QueryImpl query) {
    // Simplified boundary application
    return documents;
  }

  /// Clears all persistence.
  Future<void> clearPersistence() async {
    _cache.clear();
    await persistence.clear();
  }

  /// Terminates the local store.
  Future<void> terminate() async {
    _cache.clear();
    await persistence.close();
  }
}
