part of '../firestore.dart';

/// Exception thrown by Firestore operations.
class FirestoreException implements Exception {
  /// The error code.
  final String code;

  /// A human-readable message about the error.
  final String message;

  /// The stack trace at the point where this exception was created.
  final StackTrace? stackTrace;

  const FirestoreException({
    required this.code,
    required this.message,
    this.stackTrace,
  });

  @override
  String toString() => 'FirestoreException($code): $message';

  // Common error codes
  static const String codeAborted = 'aborted';
  static const String codeAlreadyExists = 'already-exists';
  static const String codeCancelled = 'cancelled';
  static const String codeDataLoss = 'data-loss';
  static const String codeDeadlineExceeded = 'deadline-exceeded';
  static const String codeFailedPrecondition = 'failed-precondition';
  static const String codeInternal = 'internal';
  static const String codeInvalidArgument = 'invalid-argument';
  static const String codeNotFound = 'not-found';
  static const String codeOutOfRange = 'out-of-range';
  static const String codePermissionDenied = 'permission-denied';
  static const String codeResourceExhausted = 'resource-exhausted';
  static const String codeUnauthenticated = 'unauthenticated';
  static const String codeUnavailable = 'unavailable';
  static const String codeUnimplemented = 'unimplemented';
  static const String codeUnknown = 'unknown';
}
