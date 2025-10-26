import 'package:firebase_dart/firestore.dart';

import 'document.dart';
import 'filter.dart';

/// Comparator for sorting documents based on query orders.
class DocumentComparator {
  final List<QueryOrder> orders;

  const DocumentComparator(this.orders);

  int compare(Document a, Document b) {
    for (final order in orders) {
      final aValue = _getFieldValue(a.data, order.fieldPath);
      final bValue = _getFieldValue(b.data, order.fieldPath);

      var result = _compareValues(aValue, bValue);
      if (order.descending) {
        result = -result;
      }

      if (result != 0) return result;
    }

    // If all fields are equal, compare by document path
    return a.path.compareTo(b.path);
  }

  dynamic _getFieldValue(Map<String, dynamic> data, FieldPath fieldPath) {
    dynamic current = data;
    for (final component in fieldPath.components) {
      if (current is! Map) return null;
      current = current[component];
    }
    return current;
  }

  int _compareValues(dynamic a, dynamic b) {
    // Firestore ordering: null < booleans < numbers < dates < strings < bytes < refs < geopoints < arrays < objects

    if (a == null && b == null) return 0;
    if (a == null) return -1;
    if (b == null) return 1;

    // Type ordering
    final aType = _getTypeOrder(a);
    final bType = _getTypeOrder(b);
    if (aType != bType) return aType.compareTo(bType);

    // Same type comparison
    if (a is bool && b is bool) {
      return a == b ? 0 : (a ? 1 : -1);
    } else if (a is num && b is num) {
      return a.compareTo(b);
    } else if (a is DateTime && b is DateTime) {
      return a.compareTo(b);
    } else if (a is String && b is String) {
      return a.compareTo(b);
    } else if (a is List && b is List) {
      return _compareLists(a, b);
    } else if (a is Map && b is Map) {
      return _compareMaps(a as Map<String, dynamic>, b as Map<String, dynamic>);
    }

    return 0;
  }

  int _getTypeOrder(dynamic value) {
    if (value == null) return 0;
    if (value is bool) return 1;
    if (value is num) return 2;
    if (value is DateTime) return 3;
    if (value is String) return 4;
    // bytes would be 5
    // refs would be 6
    // geopoints would be 7
    if (value is List) return 8;
    if (value is Map) return 9;
    return 10;
  }

  int _compareLists(List a, List b) {
    final minLength = a.length < b.length ? a.length : b.length;
    for (var i = 0; i < minLength; i++) {
      final result = _compareValues(a[i], b[i]);
      if (result != 0) return result;
    }
    return a.length.compareTo(b.length);
  }

  int _compareMaps(Map<String, dynamic> a, Map<String, dynamic> b) {
    final aKeys = a.keys.toList()..sort();
    final bKeys = b.keys.toList()..sort();

    final minLength = aKeys.length < bKeys.length ? aKeys.length : bKeys.length;
    for (var i = 0; i < minLength; i++) {
      final keyCompare = aKeys[i].compareTo(bKeys[i]);
      if (keyCompare != 0) return keyCompare;

      final valueCompare = _compareValues(a[aKeys[i]], b[bKeys[i]]);
      if (valueCompare != 0) return valueCompare;
    }

    return aKeys.length.compareTo(bKeys.length);
  }
}
