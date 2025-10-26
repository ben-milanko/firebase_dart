# Firestore Implementation for firebase_dart

This document describes the Firestore implementation added to the `firebase_dart` package.

## Overview

Firestore support has been added to `firebase_dart` following the same patterns as the existing Database, Auth, and Storage implementations. The implementation provides:

- **Full CRUD operations** (Create, Read, Update, Delete)
- **Advanced queries** with filtering, ordering, and pagination
- **Real-time listeners** for documents and queries
- **Transactions** with optimistic concurrency control
- **Batched writes** for atomic operations
- **Offline persistence** using Hive (with in-memory fallback)
- **FieldValue operations** (serverTimestamp, increment, arrayUnion, arrayRemove, delete)

## Architecture

### Public API Layer

Located in `lib/src/firestore/`:
- `firestore.dart` - Main Firestore service class
- `document_reference.dart` - Document operations
- `collection_reference.dart` - Collection operations and queries
- `query.dart` - Query builder
- `document_snapshot.dart` - Document data wrapper
- `query_snapshot.dart` - Query results wrapper
- `write_batch.dart` - Batched write operations
- `transaction.dart` - Transaction support
- `field_value.dart` - Special field values
- `field_path.dart` - Field path utilities
- `settings.dart` - Firestore settings
- `exception.dart` - Firestore-specific exceptions

### Implementation Layer

Located in `lib/src/firestore/impl/`:

**Core Infrastructure:**
- `firestore_impl.dart` - Concrete Firestore implementation
- `document_reference_impl.dart` - Document reference implementation
- `collection_reference_impl.dart` - Collection reference implementation
- `query_impl.dart` - Query execution engine

**Data Management:**
- `document.dart` - Internal document representation
- `mutation.dart` - Write operation representation (Set, Update, Delete)
- `filter.dart` - Query filter evaluation
- `comparator.dart` - Document comparators for ordering

**Backend Communication:**
- `backend/backend.dart` - Abstract backend interface
- `backend/rest_backend.dart` - REST API implementation using Firestore REST API v1

**Synchronization:**
- `sync_engine.dart` - Coordinates local/remote state
- `local_store.dart` - Manages local cache and persistence
- `remote_store.dart` - Manages remote backend communication

**Persistence:**
- `persistence/persistence_manager.dart` - Persistence coordinator
- `persistence/memory_persistence.dart` - In-memory storage
- `persistence/hive_persistence.dart` - Hive-based disk storage

## Usage Examples

### Basic CRUD Operations

```dart
import 'package:firebase_dart/firebase_dart.dart';

// Initialize Firebase
FirebaseDart.setup();
final app = await Firebase.initializeApp(options: options);
final firestore = FirebaseFirestore.instanceFor(app: app);

// Create a document
final docRef = firestore.collection('users').doc('user1');
await docRef.set({
  'name': 'John Doe',
  'email': 'john@example.com',
  'age': 30,
});

// Read a document
final snapshot = await docRef.get();
if (snapshot.exists) {
  print('User: ${snapshot.data()}');
}

// Update a document
await docRef.update({'age': 31});

// Delete a document
await docRef.delete();
```

### Queries

```dart
// Simple query
final query = firestore
    .collection('users')
    .where('age', isGreaterThan: 18)
    .orderBy('age')
    .limit(10);

final querySnapshot = await query.get();
for (final doc in querySnapshot.docs) {
  print('${doc.id}: ${doc.data()}');
}

// Complex query with multiple filters
final complexQuery = firestore
    .collection('products')
    .where('category', isEqualTo: 'electronics')
    .where('price', isLessThan: 1000)
    .orderBy('price', descending: true)
    .limit(20);
```

### Real-time Listeners

```dart
// Listen to document changes
docRef.snapshots().listen((snapshot) {
  if (snapshot.exists) {
    print('Updated data: ${snapshot.data()}');
  }
});

// Listen to query changes
query.snapshots().listen((querySnapshot) {
  for (final change in querySnapshot.docChanges) {
    switch (change.type) {
      case DocumentChangeType.added:
        print('New document: ${change.doc.id}');
        break;
      case DocumentChangeType.modified:
        print('Modified document: ${change.doc.id}');
        break;
      case DocumentChangeType.removed:
        print('Removed document: ${change.doc.id}');
        break;
    }
  }
});
```

### Transactions

```dart
await firestore.runTransaction((transaction) async {
  final snapshot = await transaction.get(docRef);
  final currentCount = snapshot.get('count') as int;
  transaction.update(docRef, {'count': currentCount + 1});
});
```

### Batched Writes

```dart
final batch = firestore.batch();
batch.set(firestore.collection('users').doc('user1'), {'name': 'Alice'});
batch.update(firestore.collection('users').doc('user2'), {'age': 25});
batch.delete(firestore.collection('users').doc('user3'));
await batch.commit();
```

### FieldValue Operations

```dart
// Server timestamp
await docRef.set({
  'createdAt': FieldValue.serverTimestamp(),
});

// Increment
await docRef.update({
  'views': FieldValue.increment(1),
});

// Array operations
await docRef.update({
  'tags': FieldValue.arrayUnion(['dart', 'firebase']),
  'oldTags': FieldValue.arrayRemove(['deprecated']),
});

// Delete field
await docRef.update({
  'temporaryField': FieldValue.delete(),
});
```

### Collection Groups

```dart
// Query across all collections named 'messages'
final query = firestore
    .collectionGroup('messages')
    .where('timestamp', isGreaterThan: DateTime.now().subtract(Duration(days: 7)))
    .orderBy('timestamp');
```

## Backend Protocol

The implementation uses the Firestore REST API v1:
- Base URL: `https://firestore.googleapis.com/v1/projects/{project}/databases/{database}/documents`
- Endpoints: `GET`, `POST`, `PATCH`, `DELETE` for documents
- `POST :commit` for transactions and batched writes
- `POST :listen` for real-time updates (currently using polling, gRPC streaming planned)

Authentication is handled via Firebase Auth ID tokens through the existing `AuthTokenProvider`.

## Offline Persistence

The implementation supports offline persistence using Hive:
1. All writes go to local cache immediately (optimistic updates)
2. Mutations are queued for server synchronization
3. Reads can come from cache, server, or default (server with cache fallback)
4. Listeners receive both cached and server updates
5. Conflict resolution: server wins

## Configuration

### Emulator Support

```dart
firestore.useEmulator('localhost', 8080);
```

### Network Control

```dart
// Disable network (offline mode)
await firestore.disableNetwork();

// Re-enable network
await firestore.enableNetwork();
```

### Persistence Settings

```dart
final firestore = FirebaseFirestore.instanceFor(
  app: app,
  databaseId: '(default)',
);

// Clear persistence (must be called when app is terminated)
await firestore.clearPersistence();
```

## Testing

Run the Firestore tests:

```bash
cd packages/firebase_dart
dart test test/firestore/firestore_test.dart
```

## Known Limitations

1. **Isolate Mode**: Firestore is not yet supported in isolate mode. Use non-isolated mode instead.
2. **Real-time Listeners**: Currently use polling instead of true Server-Sent Events or gRPC streaming. This will be improved in future versions.
3. **Collection Group Queries**: Implemented but may need indexes configured on the server side.
4. **Offline Persistence**: Uses Hive for disk storage; ensure proper initialization with `storagePath`.

## Future Enhancements

- [ ] gRPC-based real-time listeners for better performance
- [ ] Isolate mode support
- [ ] Advanced query features (geo queries, full-text search)
- [ ] Better conflict resolution strategies
- [ ] Index management utilities
- [ ] Performance optimizations
- [ ] More comprehensive error handling

## Integration with Existing firebase_dart

The Firestore implementation follows the same patterns as existing services:
- Registered through `FirebaseImplementation.createFirestore()`
- Uses the same `AuthTokenProvider` for authentication
- Follows the same service singleton pattern
- Integrates with the existing app lifecycle

## API Compatibility

The API closely mirrors the official Firebase Firestore SDK for consistency:
- Method names and signatures match official SDK
- Same query builder pattern
- Same transaction and batch write APIs
- Compatible error codes and exceptions

## Contributing

When contributing to Firestore:
1. Follow the existing code patterns
2. Add tests for new features
3. Update documentation
4. Ensure linter passes without errors
5. Test both online and offline scenarios

## Example Project

See `example/firestore_example.dart` for a complete working example.

