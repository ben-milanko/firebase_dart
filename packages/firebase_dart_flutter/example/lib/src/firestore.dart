import 'dart:async';
import 'dart:convert';

import 'package:firebase_dart/firebase_dart.dart';
import 'package:flutter/material.dart';

import 'widgets.dart';

class FirestoreTab extends StatefulWidget {
  final FirebaseApp app;

  const FirestoreTab({super.key, required this.app});

  @override
  State<FirestoreTab> createState() => _FirestoreTabState();
}

class _FirestoreTabState extends State<FirestoreTab> {
  late final FirebaseFirestore firestore;
  final TextEditingController _collectionController = TextEditingController(text: 'users');
  StreamSubscription<QuerySnapshot>? _subscription;
  QuerySnapshot? _querySnapshot;
  String? _error;

  @override
  void initState() {
    super.initState();
    firestore = FirebaseFirestore.instanceFor(app: widget.app);
    _loadCollection();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _collectionController.dispose();
    super.dispose();
  }

  void _loadCollection() {
    _subscription?.cancel();
    _error = null;

    if (_collectionController.text.trim().isEmpty) {
      setState(() {
        _querySnapshot = null;
      });
      return;
    }

    try {
      final collection = firestore.collection(_collectionController.text.trim());
      _subscription = collection.snapshots().listen(
        (snapshot) {
          setState(() {
            _querySnapshot = snapshot;
            _error = null;
          });
        },
        onError: (error) {
          setState(() {
            _error = error.toString();
            _querySnapshot = null;
          });
        },
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
        _querySnapshot = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _collectionController,
                  decoration: const InputDecoration(
                    labelText: 'Collection path',
                    hintText: 'e.g., users, posts',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _loadCollection,
                child: const Text('Load'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _showAddDocumentDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add Document'),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.red.shade100,
              child: Text(
                'Error: $_error',
                style: TextStyle(color: Colors.red.shade900),
              ),
            ),
          if (_error == null && _querySnapshot != null) ...[
            Text(
              'Documents (${_querySnapshot!.size}):',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _querySnapshot!.docs.isEmpty
                  ? const Center(
                      child: Text('No documents found in this collection'),
                    )
                  : ListView.builder(
                      itemCount: _querySnapshot!.docs.length,
                      itemBuilder: (context, index) {
                        final doc = _querySnapshot!.docs[index];
                        return _DocumentCard(
                          doc: doc,
                          firestore: firestore,
                          collectionPath: _collectionController.text.trim(),
                          onDeleted: _loadCollection,
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAddDocumentDialog() {
    final collectionPath = _collectionController.text.trim();
    if (collectionPath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a collection path first')),
      );
      return;
    }

    final docIdController = TextEditingController();
    final dataController = TextEditingController(text: '{}');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Document'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: docIdController,
                decoration: const InputDecoration(
                  labelText: 'Document ID (leave empty for auto-generated)',
                  hintText: 'Optional',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: dataController,
                decoration: const InputDecoration(
                  labelText: 'Data (JSON)',
                  hintText: '{"name": "John", "age": 30}',
                ),
                maxLines: 5,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () async {
              try {
                Map<String, dynamic> data;
                if (dataController.text.trim().isEmpty) {
                  data = {};
                } else {
                  data = jsonDecode(dataController.text) as Map<String, dynamic>;
                }

                final collection = firestore.collection(collectionPath);
                if (docIdController.text.trim().isEmpty) {
                  await collection.add(data);
                } else {
                  await collection.doc(docIdController.text.trim()).set(data);
                }

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Document added successfully')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: Text(MaterialLocalizations.of(context).okButtonLabel),
          ),
        ],
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final DocumentSnapshot doc;
  final FirebaseFirestore firestore;
  final String collectionPath;
  final VoidCallback onDeleted;

  const _DocumentCard({
    required this.doc,
    required this.firestore,
    required this.collectionPath,
    required this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final dataString = data != null
        ? const JsonEncoder.withIndent('  ').convert(data)
        : 'No data';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        title: Text(
          doc.id,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          doc.exists ? '${(data as Map?)?.length ?? 0} fields' : 'Document does not exist',
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: SelectableText(
                    dataString,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _showEditDialog(context),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit'),
                    ),
                    TextButton.icon(
                      onPressed: () => _showDeleteDialog(context),
                      icon: const Icon(Icons.delete, size: 18),
                      label: const Text('Delete'),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(BuildContext context) {
    final data = doc.data() ?? <String, dynamic>{};
    final dataController = TextEditingController(
      text: const JsonEncoder.withIndent('  ').convert(data),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit Document: ${doc.id}'),
        content: SingleChildScrollView(
          child: TextField(
            controller: dataController,
            decoration: const InputDecoration(
              labelText: 'Data (JSON)',
            ),
            maxLines: 10,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () async {
              try {
                final data = jsonDecode(dataController.text) as Map<String, dynamic>;
                await firestore
                    .collection(collectionPath)
                    .doc(doc.id)
                    .set(data);

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Document updated successfully')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: Text(MaterialLocalizations.of(context).okButtonLabel),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showConfirmDialog(
      context: context,
      title: 'Delete Document',
      bodyText: 'Are you sure you want to delete "${doc.id}"? This action cannot be undone.',
      onContinue: () async {
        try {
          await firestore.collection(collectionPath).doc(doc.id).delete();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Document deleted successfully')),
            );
          }
          onDeleted();
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e')),
            );
          }
        }
      },
    );
  }
}

