// A comprehensive example demonstrating Firestore usage in firebase_dart.
//
// This example implements a simple blog system with:
// - User management
// - Blog post creation and retrieval
// - Comments on posts
// - Real-time updates
// - Transactions for counters
// - Batched operations

import 'dart:async';

import 'package:firebase_dart/firebase_dart.dart';

/// Blog post model
class BlogPost {
  final String id;
  final String title;
  final String content;
  final String authorId;
  final DateTime createdAt;
  final int views;
  final List<String> tags;

  BlogPost({
    required this.id,
    required this.title,
    required this.content,
    required this.authorId,
    required this.createdAt,
    required this.views,
    required this.tags,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'content': content,
        'authorId': authorId,
        'createdAt': createdAt,
        'views': views,
        'tags': tags,
      };

  factory BlogPost.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data()!;
    return BlogPost(
      id: snapshot.id,
      title: data['title'] as String,
      content: data['content'] as String,
      authorId: data['authorId'] as String,
      createdAt: (data['createdAt'] as DateTime),
      views: data['views'] as int? ?? 0,
      tags: List<String>.from(data['tags'] as List? ?? []),
    );
  }
}

/// User model
class User {
  final String id;
  final String name;
  final String email;
  final DateTime joinedAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.joinedAt,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'joinedAt': joinedAt,
      };

  factory User.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data()!;
    return User(
      id: snapshot.id,
      name: data['name'] as String,
      email: data['email'] as String,
      joinedAt: data['joinedAt'] as DateTime,
    );
  }
}

class BlogService {
  final FirebaseFirestore firestore;

  BlogService(this.firestore);

  // CRUD Operations

  /// Create a new user
  Future<String> createUser(String name, String email) async {
    final docRef = firestore.collection('users').doc();
    await docRef.set({
      'name': name,
      'email': email,
      'joinedAt': FieldValue.serverTimestamp(),
      'postCount': 0,
    });
    print('✓ Created user: $name (${docRef.id})');
    return docRef.id;
  }

  /// Create a new blog post
  Future<String> createPost({
    required String authorId,
    required String title,
    required String content,
    required List<String> tags,
  }) async {
    final docRef = await firestore.collection('posts').add({
      'title': title,
      'content': content,
      'authorId': authorId,
      'createdAt': FieldValue.serverTimestamp(),
      'views': 0,
      'tags': tags,
      'likes': [],
    });

    // Increment user's post count using transaction
    await _incrementUserPostCount(authorId);

    print('✓ Created post: $title (${docRef.id})');
    return docRef.id;
  }

  /// Get a single post
  Future<BlogPost?> getPost(String postId) async {
    final snapshot = await firestore.collection('posts').doc(postId).get();
    if (!snapshot.exists) {
      print('✗ Post not found: $postId');
      return null;
    }
    print('✓ Retrieved post: ${snapshot.id}');
    return BlogPost.fromSnapshot(snapshot);
  }

  /// Update a post
  Future<void> updatePost(String postId, Map<String, dynamic> updates) async {
    await firestore.collection('posts').doc(postId).update(updates);
    print('✓ Updated post: $postId');
  }

  /// Delete a post
  Future<void> deletePost(String postId) async {
    await firestore.collection('posts').doc(postId).delete();
    print('✓ Deleted post: $postId');
  }

  // Query Operations

  /// Get all posts by a specific author
  Future<List<BlogPost>> getPostsByAuthor(String authorId) async {
    final querySnapshot = await firestore
        .collection('posts')
        .where('authorId', isEqualTo: authorId)
        .orderBy('createdAt', descending: true)
        .get();

    print('✓ Found ${querySnapshot.size} posts by author $authorId');
    return querySnapshot.docs.map((doc) => BlogPost.fromSnapshot(doc)).toList();
  }

  /// Get posts with specific tags
  Future<List<BlogPost>> getPostsByTag(String tag) async {
    final querySnapshot = await firestore
        .collection('posts')
        .where('tags', arrayContains: tag)
        .orderBy('createdAt', descending: true)
        .limit(10)
        .get();

    print('✓ Found ${querySnapshot.size} posts with tag: $tag');
    return querySnapshot.docs.map((doc) => BlogPost.fromSnapshot(doc)).toList();
  }

  /// Get popular posts (most viewed)
  Future<List<BlogPost>> getPopularPosts({int limit = 10}) async {
    final querySnapshot = await firestore
        .collection('posts')
        .orderBy('views', descending: true)
        .limit(limit)
        .get();

    print('✓ Found ${querySnapshot.size} popular posts');
    return querySnapshot.docs.map((doc) => BlogPost.fromSnapshot(doc)).toList();
  }

  /// Search posts by title (simple prefix search)
  Future<List<BlogPost>> searchPosts(String query) async {
    final querySnapshot = await firestore
        .collection('posts')
        .where('title', isGreaterThanOrEqualTo: query)
        .where('title', isLessThan: '${query}z')
        .get();

    print('✓ Search found ${querySnapshot.size} posts');
    return querySnapshot.docs.map((doc) => BlogPost.fromSnapshot(doc)).toList();
  }

  // Real-time Operations

  /// Listen to post changes
  Stream<BlogPost> watchPost(String postId) {
    return firestore
        .collection('posts')
        .doc(postId)
        .snapshots()
        .where((snapshot) => snapshot.exists)
        .map((snapshot) => BlogPost.fromSnapshot(snapshot));
  }

  /// Listen to new posts from an author
  Stream<List<BlogPost>> watchAuthorPosts(String authorId) {
    return firestore
        .collection('posts')
        .where('authorId', isEqualTo: authorId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((querySnapshot) => querySnapshot.docs
            .map((doc) => BlogPost.fromSnapshot(doc))
            .toList());
  }

  // Transaction Operations

  /// Increment post view count atomically
  Future<void> incrementPostViews(String postId) async {
    await firestore.runTransaction((transaction) async {
      final postRef = firestore.collection('posts').doc(postId);
      final snapshot = await transaction.get(postRef);

      if (!snapshot.exists) {
        throw Exception('Post does not exist');
      }

      final currentViews = snapshot.get('views') as int? ?? 0;
      transaction.update(postRef, {'views': currentViews + 1});
    });
    print('✓ Incremented views for post: $postId');
  }

  /// Like a post (add user to likes array)
  Future<void> likePost(String postId, String userId) async {
    await firestore.collection('posts').doc(postId).update({
      'likes': FieldValue.arrayUnion([userId]),
    });
    print('✓ User $userId liked post $postId');
  }

  /// Unlike a post (remove user from likes array)
  Future<void> unlikePost(String postId, String userId) async {
    await firestore.collection('posts').doc(postId).update({
      'likes': FieldValue.arrayRemove([userId]),
    });
    print('✓ User $userId unliked post $postId');
  }

  /// Increment user's post count
  Future<void> _incrementUserPostCount(String userId) async {
    await firestore.collection('users').doc(userId).update({
      'postCount': FieldValue.increment(1),
    });
  }

  // Batch Operations

  /// Add a comment to a post (using batch)
  Future<void> addComment({
    required String postId,
    required String userId,
    required String content,
  }) async {
    final batch = firestore.batch();

    // Add comment document
    final commentRef =
        firestore.collection('posts').doc(postId).collection('comments').doc();
    batch.set(commentRef, {
      'userId': userId,
      'content': content,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Increment comment count on post
    final postRef = firestore.collection('posts').doc(postId);
    batch.update(postRef, {
      'commentCount': FieldValue.increment(1),
    });

    await batch.commit();
    print('✓ Added comment to post $postId');
  }

  /// Delete all posts by a user (using batch)
  Future<void> deleteAllUserPosts(String authorId) async {
    final querySnapshot = await firestore
        .collection('posts')
        .where('authorId', isEqualTo: authorId)
        .get();

    if (querySnapshot.isEmpty) {
      print('✓ No posts to delete for user $authorId');
      return;
    }

    final batch = firestore.batch();
    for (final doc in querySnapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
    print('✓ Deleted ${querySnapshot.size} posts for user $authorId');
  }

  // Pagination

  /// Get paginated posts
  Future<List<BlogPost>> getPaginatedPosts({
    int pageSize = 10,
    DocumentSnapshot? startAfter,
  }) async {
    var query = firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(pageSize);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final querySnapshot = await query.get();
    print('✓ Retrieved page with ${querySnapshot.size} posts');
    return querySnapshot.docs.map((doc) => BlogPost.fromSnapshot(doc)).toList();
  }
}

void main() async {
  print('🔥 Firebase Dart - Firestore Blog Example\n');

  // Setup Firebase
  FirebaseDart.setup();

  // Initialize Firebase app
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

  // Get Firestore instance
  final firestore = FirebaseFirestore.instanceFor(app: app);

  // For demo purposes, use emulator if available
  // firestore.useEmulator('localhost', 8080);

  final blogService = BlogService(firestore);

  try {
    // Example 1: Create users
    print('\n📝 Example 1: Creating Users');
    print('─' * 50);
    final alice =
        await blogService.createUser('Alice Johnson', 'alice@example.com');
    final bob = await blogService.createUser('Bob Smith', 'bob@example.com');

    // Example 2: Create blog posts
    print('\n📝 Example 2: Creating Blog Posts');
    print('─' * 50);
    final post1 = await blogService.createPost(
      authorId: alice,
      title: 'Introduction to Dart',
      content: 'Dart is a great language for building applications...',
      tags: ['dart', 'programming', 'tutorial'],
    );

    await blogService.createPost(
      authorId: alice,
      title: 'Firebase for Dart Developers',
      content: 'Learn how to use Firebase with Dart...',
      tags: ['dart', 'firebase', 'backend'],
    );

    final post3 = await blogService.createPost(
      authorId: bob,
      title: 'Building REST APIs',
      content: 'Best practices for REST API design...',
      tags: ['api', 'rest', 'backend'],
    );

    // Example 3: Read operations
    print('\n📖 Example 3: Reading Posts');
    print('─' * 50);
    final retrievedPost = await blogService.getPost(post1);
    if (retrievedPost != null) {
      print('Post title: ${retrievedPost.title}');
      print('Author: ${retrievedPost.authorId}');
      print('Tags: ${retrievedPost.tags.join(', ')}');
    }

    // Example 4: Query operations
    print('\n🔍 Example 4: Querying Posts');
    print('─' * 50);
    final alicePosts = await blogService.getPostsByAuthor(alice);
    print('Alice has written ${alicePosts.length} posts:');
    for (final post in alicePosts) {
      print('  - ${post.title}');
    }

    final dartPosts = await blogService.getPostsByTag('dart');
    print('\nPosts tagged with "dart": ${dartPosts.length}');
    for (final post in dartPosts) {
      print('  - ${post.title}');
    }

    // Example 5: Update operations
    print('\n✏️  Example 5: Updating Posts');
    print('─' * 50);
    await blogService.updatePost(post1, {
      'content': 'Updated content: Dart is an amazing language...',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Example 6: Transactions
    print('\n🔄 Example 6: Transactions');
    print('─' * 50);
    await blogService.incrementPostViews(post1);
    await blogService.incrementPostViews(post1);
    await blogService.incrementPostViews(post1);

    // Example 7: FieldValue operations
    print('\n💝 Example 7: FieldValue Operations');
    print('─' * 50);
    await blogService.likePost(post1, bob);
    await blogService.likePost(post1, alice);
    await blogService.unlikePost(post1, alice);

    // Example 8: Batch operations
    print('\n📦 Example 8: Batch Operations');
    print('─' * 50);
    await blogService.addComment(
      postId: post1,
      userId: bob,
      content: 'Great article! Very helpful.',
    );
    await blogService.addComment(
      postId: post1,
      userId: alice,
      content: 'Thanks for reading!',
    );

    // Example 9: Real-time listeners
    print('\n👂 Example 9: Real-time Listeners');
    print('─' * 50);
    print('Listening for changes to post "$post1"...');

    final subscription = blogService.watchPost(post1).listen(
      (post) {
        print('📬 Post updated: ${post.title} (${post.views} views)');
      },
      onError: (error) {
        print('❌ Error: $error');
      },
    );

    // Make some changes to trigger the listener
    await Future.delayed(Duration(milliseconds: 500));
    await blogService.incrementPostViews(post1);

    await Future.delayed(Duration(milliseconds: 500));
    await blogService.updatePost(post1, {
      'title': 'Introduction to Dart (Updated)',
    });

    // Wait a bit to see the updates
    await Future.delayed(Duration(seconds: 2));

    // Cancel the subscription
    await subscription.cancel();
    print('✓ Stopped listening');

    // Example 10: Popular posts
    print('\n🌟 Example 10: Popular Posts');
    print('─' * 50);
    final popularPosts = await blogService.getPopularPosts(limit: 5);
    print('Top ${popularPosts.length} most viewed posts:');
    for (var i = 0; i < popularPosts.length; i++) {
      final post = popularPosts[i];
      print('  ${i + 1}. ${post.title} (${post.views} views)');
    }

    // Example 11: Cleanup
    print('\n🧹 Example 11: Cleanup');
    print('─' * 50);
    await blogService.deletePost(post3);

    print('\n✅ All examples completed successfully!');
  } catch (e, stackTrace) {
    print('\n❌ Error occurred: $e');
    print('Stack trace: $stackTrace');
  } finally {
    // Cleanup
    await app.delete();
    print('\n👋 Firebase app deleted. Goodbye!');
  }
}
