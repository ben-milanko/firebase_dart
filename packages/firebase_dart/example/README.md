# Firebase Dart Examples

This directory contains examples demonstrating how to use firebase_dart.

## Firestore Examples

### 1. Quick Start Example (`firestore_example.dart`)

A simple, focused example showing basic Firestore operations:
- CRUD operations (Create, Read, Update, Delete)
- Simple queries
- Real-time listeners
- Transactions
- Batched writes
- FieldValue operations

**Run it:**
```bash
dart run example/firestore_example.dart
```

### 2. Blog Application Example (`firestore_blog_example.dart`)

A comprehensive example implementing a simple blog system with:
- User management
- Blog post creation and retrieval
- Advanced queries (by author, by tag, search)
- Real-time updates
- Comments with subcollections
- Atomic counters using transactions
- Batched operations
- Pagination

**Run it:**
```bash
dart run example/firestore_blog_example.dart
```

## Other Examples

### Change Password (`change_password.dart`)

Demonstrates Firebase Authentication password change functionality.

**Run it:**
```bash
dart run example/change_password.dart
```

### Main Example (`main.dart`)

Shows basic Firebase setup and usage.

**Run it:**
```bash
dart run example/main.dart
```

## Using with Emulators

For local development and testing, you can use the Firebase Emulator Suite:

1. Install Firebase CLI:
   ```bash
   npm install -g firebase-tools
   ```

2. Start the Firestore emulator:
   ```bash
   firebase emulators:start --only firestore
   ```

3. In your Dart code, configure Firestore to use the emulator:
   ```dart
   final firestore = FirebaseFirestore.instance;
   firestore.useEmulator('localhost', 8080);
   ```

## Configuration

Before running the examples, update the Firebase configuration in each example with your own project credentials:

```dart
final app = await Firebase.initializeApp(
  options: const FirebaseOptions(
    apiKey: 'your-api-key',
    authDomain: 'your-project.firebaseapp.com',
    projectId: 'your-project-id',
    storageBucket: 'your-project.appspot.com',
    messagingSenderId: 'your-sender-id',
    appId: 'your-app-id',
  ),
);
```

You can find these values in your Firebase Console under Project Settings.

## Tips

1. **Start with the quick start example** to understand the basics
2. **Explore the blog example** for more advanced patterns
3. **Use the emulator** for development to avoid costs and rate limits
4. **Check the test files** in `test/firestore/` for more usage examples

## Documentation

For complete API documentation, see:
- [FIRESTORE_README.md](../FIRESTORE_README.md) - Firestore implementation details
- [Official Firebase Firestore Documentation](https://firebase.google.com/docs/firestore)

## Need Help?

- Check the [firebase_dart README](../README.md)
- Review the test files in `test/firestore/`
- Open an issue on GitHub

