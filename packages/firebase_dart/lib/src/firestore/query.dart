part of '../firestore.dart';

/// A [Query] refers to a query which you can read or listen to.
///
/// You can also construct refined [Query] objects by adding filters and
/// ordering.
abstract class Query {
  /// The [FirebaseFirestore] instance of this query.
  FirebaseFirestore get firestore;

  /// Creates and returns a new [Query] with the additional filter that
  /// documents must contain the specified field and the value should satisfy
  /// the relation constraint provided.
  Query where(
    Object field, {
    Object? isEqualTo,
    Object? isNotEqualTo,
    Object? isLessThan,
    Object? isLessThanOrEqualTo,
    Object? isGreaterThan,
    Object? isGreaterThanOrEqualTo,
    Object? arrayContains,
    List<Object?>? arrayContainsAny,
    List<Object?>? whereIn,
    List<Object?>? whereNotIn,
    bool? isNull,
  });

  /// Creates and returns a new [Query] that's additionally sorted by the
  /// specified field, optionally in descending order instead of ascending.
  Query orderBy(Object field, {bool descending = false});

  /// Creates and returns a new [Query] that's additionally limited to only
  /// return up to the specified number of documents.
  Query limit(int limit);

  /// Creates and returns a new [Query] that only returns the last matching
  /// documents up to the specified number.
  Query limitToLast(int limit);

  /// Creates and returns a new [Query] that starts at the provided document
  /// (inclusive). The starting position is relative to the order of the query.
  Query startAtDocument(DocumentSnapshot documentSnapshot);

  /// Creates and returns a new [Query] that starts at the provided fields
  /// relative to the order of the query.
  Query startAt(List<Object?> values);

  /// Creates and returns a new [Query] that starts after the provided document
  /// (exclusive). The starting position is relative to the order of the query.
  Query startAfterDocument(DocumentSnapshot documentSnapshot);

  /// Creates and returns a new [Query] that starts after the provided fields
  /// relative to the order of the query.
  Query startAfter(List<Object?> values);

  /// Creates and returns a new [Query] that ends before the provided document
  /// (exclusive). The ending position is relative to the order of the query.
  Query endBeforeDocument(DocumentSnapshot documentSnapshot);

  /// Creates and returns a new [Query] that ends before the provided fields
  /// relative to the order of the query.
  Query endBefore(List<Object?> values);

  /// Creates and returns a new [Query] that ends at the provided document
  /// (inclusive). The ending position is relative to the order of the query.
  Query endAtDocument(DocumentSnapshot documentSnapshot);

  /// Creates and returns a new [Query] that ends at the provided fields
  /// relative to the order of the query.
  Query endAt(List<Object?> values);

  /// Executes the query and returns the results as a [QuerySnapshot].
  Future<QuerySnapshot> get([GetOptions? options]);

  /// Notifies of query results at this location.
  Stream<QuerySnapshot> snapshots({bool includeMetadataChanges = false});

  /// Returns the number of documents that match the query.
  Future<AggregateQuerySnapshot> count();

  @override
  bool operator ==(Object other);

  @override
  int get hashCode;
}

/// The results of an aggregate query.
class AggregateQuerySnapshot {
  /// The number of documents that matched the query.
  final int? count;

  const AggregateQuerySnapshot({this.count});
}
