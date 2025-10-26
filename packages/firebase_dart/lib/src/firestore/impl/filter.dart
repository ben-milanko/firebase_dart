import 'package:firebase_dart/firestore.dart';

import 'document.dart';

/// Represents a query filter.
class QueryFilter {
  final FieldPath fieldPath;
  final FilterOperator operator;
  final Object? value;

  const QueryFilter(this.fieldPath, this.operator, this.value);

  /// Tests if a document matches this filter.
  bool matches(Document document) {
    final fieldValue = _getFieldValue(document.data, fieldPath);
    return _compareValues(fieldValue, operator, value);
  }

  dynamic _getFieldValue(Map<String, dynamic> data, FieldPath fieldPath) {
    dynamic current = data;
    for (final component in fieldPath.components) {
      if (current is! Map) return null;
      current = current[component];
    }
    return current;
  }

  bool _compareValues(
      dynamic fieldValue, FilterOperator op, dynamic filterValue) {
    switch (op) {
      case FilterOperator.equal:
        return fieldValue == filterValue;
      case FilterOperator.notEqual:
        return fieldValue != filterValue;
      case FilterOperator.lessThan:
        return _compare(fieldValue, filterValue) < 0;
      case FilterOperator.lessThanOrEqual:
        return _compare(fieldValue, filterValue) <= 0;
      case FilterOperator.greaterThan:
        return _compare(fieldValue, filterValue) > 0;
      case FilterOperator.greaterThanOrEqual:
        return _compare(fieldValue, filterValue) >= 0;
      case FilterOperator.arrayContains:
        return fieldValue is List && fieldValue.contains(filterValue);
      case FilterOperator.arrayContainsAny:
        if (fieldValue is! List || filterValue is! List) return false;
        return filterValue.any((v) => fieldValue.contains(v));
      case FilterOperator.in_:
        return filterValue is List && filterValue.contains(fieldValue);
      case FilterOperator.notIn:
        return filterValue is List && !filterValue.contains(fieldValue);
    }
  }

  int _compare(dynamic a, dynamic b) {
    if (a == null && b == null) return 0;
    if (a == null) return -1;
    if (b == null) return 1;

    if (a is num && b is num) {
      return a.compareTo(b);
    } else if (a is String && b is String) {
      return a.compareTo(b);
    } else if (a is bool && b is bool) {
      return a == b ? 0 : (a ? 1 : -1);
    } else if (a is DateTime && b is DateTime) {
      return a.compareTo(b);
    }

    // Default to string comparison
    return a.toString().compareTo(b.toString());
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QueryFilter &&
          runtimeType == other.runtimeType &&
          fieldPath == other.fieldPath &&
          operator == other.operator &&
          value == other.value;

  @override
  int get hashCode => fieldPath.hashCode ^ operator.hashCode ^ value.hashCode;

  @override
  String toString() => 'QueryFilter($fieldPath $operator $value)';
}

/// Filter operators.
enum FilterOperator {
  equal,
  notEqual,
  lessThan,
  lessThanOrEqual,
  greaterThan,
  greaterThanOrEqual,
  arrayContains,
  arrayContainsAny,
  in_,
  notIn,
}

/// Represents a query order.
class QueryOrder {
  final FieldPath fieldPath;
  final bool descending;

  const QueryOrder(this.fieldPath, this.descending);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QueryOrder &&
          runtimeType == other.runtimeType &&
          fieldPath == other.fieldPath &&
          descending == other.descending;

  @override
  int get hashCode => fieldPath.hashCode ^ descending.hashCode;

  @override
  String toString() => 'QueryOrder($fieldPath ${descending ? 'desc' : 'asc'})';
}
