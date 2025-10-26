part of '../firestore.dart';

/// A [DocumentReference] refers to a document location in a Firestore database
/// and can be used to write, read, or listen to the location.
///
/// The document at the referenced location may or may not exist.
abstract class DocumentReference {
  /// The [FirebaseFirestore] instance of this document reference.
  FirebaseFirestore get firestore;

  /// The ID of the document.
  String get id;

  /// The parent [CollectionReference] of this document.
  CollectionReference get parent;

  /// The full path to this document (not including the project ID and database ID).
  String get path;

  /// Gets a [CollectionReference] instance that refers to a subcollection of
  /// this document.
  CollectionReference collection(String collectionPath);

  /// Writes to the document referred to by this [DocumentReference].
  ///
  /// If the document does not yet exist, it will be created.
  ///
  /// If [SetOptions.merge] is true, the provided data will be merged into an
  /// existing document instead of overwriting.
  ///
  /// If [SetOptions.mergeFields] is provided, only the specified fields will
  /// be merged (others will be left untouched).
  Future<void> set(Map<String, dynamic> data, [SetOptions? options]);

  /// Updates fields in the document referred to by this [DocumentReference].
  ///
  /// If the document does not exist, the update will fail.
  Future<void> update(Map<String, dynamic> data);

  /// Deletes the document referred to by this [DocumentReference].
  Future<void> delete();

  /// Reads the document referenced by this [DocumentReference].
  ///
  /// By default, [get] attempts to provide up-to-date data when possible by
  /// waiting for data from the server, but it may return cached data or fail
  /// if you are offline and the server cannot be reached.
  Future<DocumentSnapshot> get([GetOptions? options]);

  /// Notifies of documents at this location.
  ///
  /// The [Stream] will always return the full document. If the document does
  /// not exist, the snapshot's [DocumentSnapshot.exists] property will be
  /// false.
  Stream<DocumentSnapshot> snapshots({bool includeMetadataChanges = false});

  @override
  bool operator ==(Object other);

  @override
  int get hashCode;
}

/// Options for [DocumentReference.set] method.
class SetOptions {
  /// If true, the set operation will merge the new data with the existing
  /// document instead of overwriting it.
  final bool? _merge;

  /// If provided, the set operation will only update the fields specified in
  /// this list. All other fields will remain unchanged.
  final List<Object>? _mergeFields;

  const SetOptions._({bool? merge, List<Object>? mergeFields})
      : _merge = merge,
        _mergeFields = mergeFields,
        assert(merge == null || mergeFields == null,
            'Cannot specify both merge and mergeFields');

  bool? get merge => _merge;
  List<Object>? get mergeFields => _mergeFields;

  /// Returns a [SetOptions] instance that merges all data.
  static const SetOptions mergeAll = SetOptions._(merge: true);

  /// Returns a [SetOptions] instance that merges only the specified fields.
  static SetOptions mergeFieldsList(List<Object> fields) =>
      SetOptions._(mergeFields: fields);
}

/// Options for [DocumentReference.get] and [Query.get] methods.
class GetOptions {
  /// Whether to fetch data from the server. If false, data may come from cache.
  final Source source;

  const GetOptions({this.source = Source.defaultSource});

  /// Use cache first, then fallback to server if data is not in cache.
  static const GetOptions cacheFirst = GetOptions(source: Source.cache);

  /// Always fetch data from the server.
  static const GetOptions serverFirst = GetOptions(source: Source.server);
}

/// Source of data for get operations.
enum Source {
  /// Default behavior: prefer server, fallback to cache if offline.
  defaultSource,

  /// Always fetch from server.
  server,

  /// Always fetch from cache.
  cache,
}
