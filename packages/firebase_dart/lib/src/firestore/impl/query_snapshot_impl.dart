import 'package:firebase_dart/firestore.dart';

import 'document.dart';
import 'document_reference_impl.dart';
import 'document_snapshot_impl.dart';
import 'query_impl.dart';

class QuerySnapshotImpl extends QuerySnapshot {
  final QueryImpl query;
  final List<Document> documents;
  final List<Document>? previousDocuments;

  QuerySnapshotImpl({
    required this.query,
    required this.documents,
    this.previousDocuments,
  });

  @override
  List<DocumentSnapshot> get docs {
    return documents.map((doc) {
      return DocumentSnapshotImpl(
        reference: DocumentReferenceImpl(
          firestore: query.firestore,
          path: doc.path,
        ),
        document: doc,
      );
    }).toList();
  }

  @override
  int get size => documents.length;

  @override
  SnapshotMetadata get metadata {
    // Aggregate metadata from all documents
    final hasPendingWrites =
        documents.any((doc) => doc.metadata.hasPendingWrites);
    final isFromCache = documents.every((doc) => doc.metadata.isFromCache);

    return SnapshotMetadata(
      hasPendingWrites: hasPendingWrites,
      isFromCache: isFromCache,
    );
  }

  @override
  List<DocumentChange> get docChanges {
    if (previousDocuments == null) {
      // First snapshot, all documents are added
      return List.generate(
        documents.length,
        (index) => DocumentChange(
          type: DocumentChangeType.added,
          doc: docs[index],
          oldIndex: -1,
          newIndex: index,
        ),
      );
    }

    final changes = <DocumentChange>[];
    final oldDocs = {
      for (var i in List.generate(previousDocuments!.length, (i) => i))
        previousDocuments![i].path: i
    };
    final newDocs = {
      for (var i in List.generate(documents.length, (i) => i))
        documents[i].path: i
    };

    // Find removed documents
    for (final entry in oldDocs.entries) {
      if (!newDocs.containsKey(entry.key)) {
        changes.add(DocumentChange(
          type: DocumentChangeType.removed,
          doc: DocumentSnapshotImpl(
            reference: DocumentReferenceImpl(
              firestore: query.firestore,
              path: entry.key,
            ),
            document: previousDocuments![entry.value],
          ),
          oldIndex: entry.value,
          newIndex: -1,
        ));
      }
    }

    // Find added and modified documents
    for (final entry in newDocs.entries) {
      final oldIndex = oldDocs[entry.key];
      if (oldIndex == null) {
        // Added
        changes.add(DocumentChange(
          type: DocumentChangeType.added,
          doc: docs[entry.value],
          oldIndex: -1,
          newIndex: entry.value,
        ));
      } else {
        // Check if modified
        final oldDoc = previousDocuments![oldIndex];
        final newDoc = documents[entry.value];
        if (!_documentsEqual(oldDoc, newDoc)) {
          changes.add(DocumentChange(
            type: DocumentChangeType.modified,
            doc: docs[entry.value],
            oldIndex: oldIndex,
            newIndex: entry.value,
          ));
        }
      }
    }

    return changes;
  }

  bool _documentsEqual(Document a, Document b) {
    if (!a.exists || !b.exists) return a.exists == b.exists;
    return _mapsEqual(a.data, b.data);
  }

  bool _mapsEqual(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      final aVal = a[key];
      final bVal = b[key];
      if (aVal is Map && bVal is Map) {
        if (!_mapsEqual(
            aVal as Map<String, dynamic>, bVal as Map<String, dynamic>)) {
          return false;
        }
      } else if (aVal != bVal) {
        return false;
      }
    }
    return true;
  }

  @override
  bool get isEmpty => documents.isEmpty;

  @override
  void forEach(void Function(DocumentSnapshot doc) action) {
    for (final doc in docs) {
      action(doc);
    }
  }

  @override
  String toString() => 'QuerySnapshot(size: $size)';
}
