import 'dart:async';

import 'package:firebase_dart/firestore.dart';

import 'filter.dart';
import 'firestore_impl.dart';
import 'query_snapshot_impl.dart';

class QueryImpl extends Query {
  @override
  final FirestoreImpl firestore;

  final String? path;
  final String? collectionId;
  final bool isCollectionGroup;
  final List<QueryFilter> filters;
  final List<QueryOrder> orders;
  final int? limitValue;
  final int? limitToLastValue;
  final QueryBoundary? startAtBoundary;
  final QueryBoundary? endAtBoundary;

  QueryImpl({
    required this.firestore,
    this.path,
    this.collectionId,
    this.isCollectionGroup = false,
    this.filters = const [],
    this.orders = const [],
    this.limitValue,
    this.limitToLastValue,
    this.startAtBoundary,
    this.endAtBoundary,
  });

  QueryImpl _copyWith({
    List<QueryFilter>? filters,
    List<QueryOrder>? orders,
    int? limitValue,
    int? limitToLastValue,
    QueryBoundary? startAtBoundary,
    QueryBoundary? endAtBoundary,
    bool clearLimit = false,
    bool clearLimitToLast = false,
    bool clearStartAt = false,
    bool clearEndAt = false,
  }) {
    return QueryImpl(
      firestore: firestore,
      path: path,
      collectionId: collectionId,
      isCollectionGroup: isCollectionGroup,
      filters: filters ?? this.filters,
      orders: orders ?? this.orders,
      limitValue: clearLimit ? null : (limitValue ?? this.limitValue),
      limitToLastValue:
          clearLimitToLast ? null : (limitToLastValue ?? this.limitToLastValue),
      startAtBoundary:
          clearStartAt ? null : (startAtBoundary ?? this.startAtBoundary),
      endAtBoundary: clearEndAt ? null : (endAtBoundary ?? this.endAtBoundary),
    );
  }

  @override
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
  }) {
    final fieldPath = _parseFieldPath(field);
    final newFilters = List<QueryFilter>.from(filters);

    if (isEqualTo != null) {
      newFilters.add(QueryFilter(fieldPath, FilterOperator.equal, isEqualTo));
    }
    if (isNotEqualTo != null) {
      newFilters
          .add(QueryFilter(fieldPath, FilterOperator.notEqual, isNotEqualTo));
    }
    if (isLessThan != null) {
      newFilters
          .add(QueryFilter(fieldPath, FilterOperator.lessThan, isLessThan));
    }
    if (isLessThanOrEqualTo != null) {
      newFilters.add(QueryFilter(
          fieldPath, FilterOperator.lessThanOrEqual, isLessThanOrEqualTo));
    }
    if (isGreaterThan != null) {
      newFilters.add(
          QueryFilter(fieldPath, FilterOperator.greaterThan, isGreaterThan));
    }
    if (isGreaterThanOrEqualTo != null) {
      newFilters.add(QueryFilter(fieldPath, FilterOperator.greaterThanOrEqual,
          isGreaterThanOrEqualTo));
    }
    if (arrayContains != null) {
      newFilters.add(
          QueryFilter(fieldPath, FilterOperator.arrayContains, arrayContains));
    }
    if (arrayContainsAny != null) {
      newFilters.add(QueryFilter(
          fieldPath, FilterOperator.arrayContainsAny, arrayContainsAny));
    }
    if (whereIn != null) {
      newFilters.add(QueryFilter(fieldPath, FilterOperator.in_, whereIn));
    }
    if (whereNotIn != null) {
      newFilters.add(QueryFilter(fieldPath, FilterOperator.notIn, whereNotIn));
    }
    if (isNull == true) {
      newFilters.add(QueryFilter(fieldPath, FilterOperator.equal, null));
    }

    return _copyWith(filters: newFilters);
  }

  @override
  Query orderBy(Object field, {bool descending = false}) {
    final fieldPath = _parseFieldPath(field);
    final newOrders = List<QueryOrder>.from(orders)
      ..add(QueryOrder(fieldPath, descending));
    return _copyWith(orders: newOrders);
  }

  @override
  Query limit(int limit) {
    if (limit <= 0) {
      throw ArgumentError('Limit must be positive');
    }
    return _copyWith(limitValue: limit, clearLimitToLast: true);
  }

  @override
  Query limitToLast(int limit) {
    if (limit <= 0) {
      throw ArgumentError('Limit must be positive');
    }
    return _copyWith(limitToLastValue: limit, clearLimit: true);
  }

  @override
  Query startAtDocument(DocumentSnapshot documentSnapshot) {
    return _copyWith(
      startAtBoundary: QueryBoundary(
        values: _extractBoundaryValues(documentSnapshot),
        inclusive: true,
      ),
    );
  }

  @override
  Query startAt(List<Object?> values) {
    return _copyWith(
      startAtBoundary: QueryBoundary(values: values, inclusive: true),
    );
  }

  @override
  Query startAfterDocument(DocumentSnapshot documentSnapshot) {
    return _copyWith(
      startAtBoundary: QueryBoundary(
        values: _extractBoundaryValues(documentSnapshot),
        inclusive: false,
      ),
    );
  }

  @override
  Query startAfter(List<Object?> values) {
    return _copyWith(
      startAtBoundary: QueryBoundary(values: values, inclusive: false),
    );
  }

  @override
  Query endBeforeDocument(DocumentSnapshot documentSnapshot) {
    return _copyWith(
      endAtBoundary: QueryBoundary(
        values: _extractBoundaryValues(documentSnapshot),
        inclusive: false,
      ),
    );
  }

  @override
  Query endBefore(List<Object?> values) {
    return _copyWith(
      endAtBoundary: QueryBoundary(values: values, inclusive: false),
    );
  }

  @override
  Query endAtDocument(DocumentSnapshot documentSnapshot) {
    return _copyWith(
      endAtBoundary: QueryBoundary(
        values: _extractBoundaryValues(documentSnapshot),
        inclusive: true,
      ),
    );
  }

  @override
  Query endAt(List<Object?> values) {
    return _copyWith(
      endAtBoundary: QueryBoundary(values: values, inclusive: true),
    );
  }

  @override
  Future<QuerySnapshot> get([GetOptions? options]) async {
    final source = options?.source ?? Source.defaultSource;
    final documents = await firestore.syncEngine.executeQuery(
      this,
      source: source,
    );

    return QuerySnapshotImpl(
      query: this,
      documents: documents,
    );
  }

  @override
  Stream<QuerySnapshot> snapshots({bool includeMetadataChanges = false}) {
    return firestore.syncEngine
        .listenToQuery(this, includeMetadataChanges: includeMetadataChanges)
        .map((documents) => QuerySnapshotImpl(
              query: this,
              documents: documents,
            ));
  }

  @override
  Future<AggregateQuerySnapshot> count() async {
    final documents = await firestore.syncEngine.executeQuery(this);
    return AggregateQuerySnapshot(count: documents.length);
  }

  FieldPath _parseFieldPath(Object field) {
    if (field is String) {
      return FieldPath.fromString(field);
    } else if (field is FieldPath) {
      return field;
    } else {
      throw ArgumentError('Field must be a String or FieldPath');
    }
  }

  List<Object?> _extractBoundaryValues(DocumentSnapshot snapshot) {
    final values = <Object?>[];
    for (final order in orders) {
      final value = _getNestedValue(snapshot.data(), order.fieldPath);
      values.add(value);
    }
    if (values.isEmpty) {
      values.add(snapshot.reference.path);
    }
    return values;
  }

  Object? _getNestedValue(Map<String, dynamic>? data, FieldPath fieldPath) {
    if (data == null) return null;

    dynamic current = data;
    for (final component in fieldPath.components) {
      if (current is! Map) return null;
      current = current[component];
    }
    return current;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QueryImpl &&
          runtimeType == other.runtimeType &&
          firestore == other.firestore &&
          path == other.path &&
          isCollectionGroup == other.isCollectionGroup &&
          _listEquals(filters, other.filters) &&
          _listEquals(orders, other.orders) &&
          limitValue == other.limitValue &&
          limitToLastValue == other.limitToLastValue;

  @override
  int get hashCode =>
      firestore.hashCode ^
      path.hashCode ^
      isCollectionGroup.hashCode ^
      filters.hashCode ^
      orders.hashCode;

  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class QueryBoundary {
  final List<Object?> values;
  final bool inclusive;

  const QueryBoundary({
    required this.values,
    required this.inclusive,
  });
}
