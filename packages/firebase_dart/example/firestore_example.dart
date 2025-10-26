// A quick-start example showing basic Firestore operations.
//
// This example demonstrates:
// - Basic CRUD operations (Create, Read, Update, Delete)
// - Simple queries
// - Real-time listeners
// - Transactions
// - Batched writes

import 'package:firebase_dart/firebase_dart.dart';

void main() async {
  print('🔥 Firebase Dart - Firestore Quick Start\n');

  // 1. Setup Firebase
  FirebaseDart.setup();

  // 2. Initialize Firebase app
  final app = await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'demo-api-key',
      authDomain: 'demo-project.firebaseapp.com',
      projectId: 'demo-project',
      storageBucket: 'demo-project.appspot.com',
      messagingSenderId: '123456789',
      appId: '1:123456789:web:abcdef',
    ),
  );

  // 3. Get Firestore instance
  final firestore = FirebaseFirestore.instanceFor(app: app);

  // Optional: Use emulator for local development
  // firestore.useEmulator('localhost', 8080);

  try {
    // ============= CREATE =============
    print('📝 CREATE: Adding a new user...');
    final docRef = firestore.collection('users').doc('user1');

    await docRef.set({
      'name': 'John Doe',
      'email': 'john@example.com',
      'age': 30,
      'hobbies': ['reading', 'coding'],
      'createdAt': FieldValue.serverTimestamp(),
    });
    print('✓ User created!\n');

    // ============= READ =============
    print('📖 READ: Getting user data...');
    final snapshot = await docRef.get();
    if (snapshot.exists) {
      print('✓ User data: ${snapshot.data()}\n');
    }

    // ============= UPDATE =============
    print('✏️  UPDATE: Updating user age...');
    await docRef.update({
      'age': 31,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    print('✓ User updated!\n');

    // ============= QUERY =============
    print('🔍 QUERY: Finding adult users...');
    final query = firestore
        .collection('users')
        .where('age', isGreaterThan: 18)
        .orderBy('age')
        .limit(10);

    final querySnapshot = await query.get();
    print('✓ Found ${querySnapshot.size} users:');
    for (final doc in querySnapshot.docs) {
      print('  - ${doc.id}: ${doc.get('name')} (${doc.get('age')} years old)');
    }
    print('');

    // ============= REAL-TIME LISTENER =============
    print('👂 LISTENER: Watching for changes...');
    final subscription = docRef.snapshots().listen(
      (snapshot) {
        if (snapshot.exists) {
          print('📬 Document changed: ${snapshot.data()}');
        }
      },
      onError: (error) => print('❌ Error: $error'),
    );

    // Make a change to trigger the listener
    await Future.delayed(Duration(milliseconds: 500));
    await docRef.update({'age': 32});

    // Wait to see the update
    await Future.delayed(Duration(seconds: 1));
    await subscription.cancel();
    print('✓ Listener stopped\n');

    // ============= TRANSACTION =============
    print('🔄 TRANSACTION: Incrementing age atomically...');
    await firestore.runTransaction((transaction) async {
      final doc = await transaction.get(docRef);
      final currentAge = doc.get('age') as int;
      transaction.update(docRef, {'age': currentAge + 1});
    });
    print('✓ Transaction completed!\n');

    // ============= BATCH WRITE =============
    print('📦 BATCH: Performing multiple operations...');
    final batch = firestore.batch();

    // Add a new user
    batch.set(
      firestore.collection('users').doc('user2'),
      {
        'name': 'Jane Doe',
        'email': 'jane@example.com',
        'age': 28,
      },
    );

    // Update existing user
    batch.update(docRef, {
      'lastModified': FieldValue.serverTimestamp(),
      'hobbies': FieldValue.arrayUnion(['gaming']),
    });

    // Commit all operations atomically
    await batch.commit();
    print('✓ Batch write completed!\n');

    // ============= FIELD VALUES =============
    print('💫 FIELD VALUES: Using special operations...');

    // Array operations
    await docRef.update({
      'hobbies': FieldValue.arrayRemove(['reading']),
    });
    print('✓ Removed hobby from array');

    // Increment operation
    await docRef.update({
      'loginCount': FieldValue.increment(1),
    });
    print('✓ Incremented login count');

    // Server timestamp
    await docRef.update({
      'lastLogin': FieldValue.serverTimestamp(),
    });
    print('✓ Set server timestamp\n');

    // ============= DELETE =============
    print('🗑️  DELETE: Removing documents...');
    await firestore.collection('users').doc('user2').delete();
    await docRef.delete();
    print('✓ Documents deleted!\n');

    print('✅ All operations completed successfully!');
  } catch (e, stackTrace) {
    print('❌ Error occurred: $e');
    print('Stack trace: $stackTrace');
  } finally {
    // Cleanup
    await app.delete();
    print('\n👋 Done!');
  }
}
