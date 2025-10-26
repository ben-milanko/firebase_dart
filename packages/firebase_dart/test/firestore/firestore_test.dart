import 'package:firebase_dart/firebase_dart.dart';
import 'package:test/test.dart';

void main() {
  group('Firestore', () {
    late FirebaseApp app;
    late FirebaseFirestore firestore;

    setUpAll(() async {
      FirebaseDart.setup();

      app = await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'test-api-key',
          authDomain: 'test.firebaseapp.com',
          projectId: 'test-project',
          storageBucket: 'test.appspot.com',
          messagingSenderId: '123456789',
          appId: '1:123456789:web:abcdef',
        ),
      );

      firestore = FirebaseFirestore.instanceFor(app: app);
    });

    tearDownAll(() async {
      await app.delete();
    });

    test('can create and get instance', () {
      expect(firestore, isNotNull);
      expect(firestore.app, equals(app));
    });

    test('can create collection reference', () {
      final collection = firestore.collection('users');
      expect(collection, isNotNull);
      expect(collection.id, equals('users'));
      expect(collection.path, equals('users'));
    });

    test('can create document reference', () {
      final doc = firestore.collection('users').doc('user1');
      expect(doc, isNotNull);
      expect(doc.id, equals('user1'));
      expect(doc.path, equals('users/user1'));
    });

    test('can create document reference with auto-generated ID', () {
      final doc = firestore.collection('users').doc();
      expect(doc, isNotNull);
      expect(doc.id, isNotEmpty);
    });

    test('validates collection path', () {
      expect(() => firestore.collection(''), throwsArgumentError);
      expect(() => firestore.collection('users//test'), throwsArgumentError);
      expect(() => firestore.collection('/users'), throwsArgumentError);
      expect(() => firestore.collection('users/'), throwsArgumentError);
      expect(() => firestore.collection('users/user1'), throwsArgumentError);
    });

    test('validates document path', () {
      expect(() => firestore.doc(''), throwsArgumentError);
      expect(() => firestore.doc('users'), throwsArgumentError);
      expect(() => firestore.doc('users//user1'), throwsArgumentError);
    });

    test('can build queries', () {
      final query = firestore
          .collection('users')
          .where('age', isGreaterThan: 18)
          .orderBy('age')
          .limit(10);

      expect(query, isNotNull);
    });

    test('can create WriteBatch', () {
      final batch = firestore.batch();
      expect(batch, isNotNull);

      final doc = firestore.collection('users').doc('user1');
      batch.set(doc, {'name': 'John'});
      batch.update(doc, {'age': 30});
      batch.delete(doc);
    });

    test('WriteBatch validates data', () {
      final batch = firestore.batch();
      final doc = firestore.collection('users').doc('user1');

      // Update with empty data should throw
      expect(() => batch.update(doc, {}), throwsArgumentError);
    });

    test('can create collection group query', () {
      final query = firestore.collectionGroup('messages');
      expect(query, isNotNull);
    });

    test('validates collection group ID', () {
      expect(() => firestore.collectionGroup(''), throwsArgumentError);
      expect(() => firestore.collectionGroup('messages/test'),
          throwsArgumentError);
    });

    test('FieldPath validates components', () {
      expect(() => FieldPath([]), throwsArgumentError);
      expect(() => FieldPath(['test', '']), throwsArgumentError);
    });

    test('FieldPath.fromString works correctly', () {
      final path = FieldPath.fromString('address.city');
      expect(path.components, equals(['address', 'city']));
      expect(path.toString(), equals('address.city'));
    });

    test('FieldPath.documentId creates special path', () {
      final path = FieldPath.documentId();
      expect(path.components, equals(['__name__']));
    });

    test('SetOptions provides merge options', () {
      final mergeAll = SetOptions.mergeAll;
      expect(mergeAll.merge, isTrue);
      expect(mergeAll.mergeFields, isNull);

      final mergeSpecific = SetOptions.mergeFieldsList(['field1', 'field2']);
      expect(mergeSpecific.merge, isNull);
      expect(mergeSpecific.mergeFields, isNotNull);
    });

    test('can use field values', () {
      expect(FieldValue.serverTimestamp(), isA<ServerTimestampFieldValue>());
      expect(FieldValue.delete(), isA<DeleteFieldValue>());
      expect(FieldValue.increment(5), isA<IncrementFieldValue>());
      expect(FieldValue.arrayUnion([1, 2]), isA<ArrayUnionFieldValue>());
      expect(FieldValue.arrayRemove([3, 4]), isA<ArrayRemoveFieldValue>());
    });

    test('SnapshotMetadata equality works', () {
      const meta1 = SnapshotMetadata(
        hasPendingWrites: true,
        isFromCache: false,
      );
      const meta2 = SnapshotMetadata(
        hasPendingWrites: true,
        isFromCache: false,
      );
      const meta3 = SnapshotMetadata(
        hasPendingWrites: false,
        isFromCache: true,
      );

      expect(meta1, equals(meta2));
      expect(meta1, isNot(equals(meta3)));
    });
  });
}
