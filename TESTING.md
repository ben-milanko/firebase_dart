# Testing Guide (firebase_dart)

## Prerequisites
- **Flutter SDK** installed and on PATH.
  - Verify: `flutter --version`
- (Optional) **Dart SDK** if you want to run `dart test` directly.
  - Verify: `dart --version`

## Primary Test Command (Recommended)
Use Dart for the pure Dart package tests:

```bash
# If dart is not on PATH, use the Flutter SDK dart:
/home/ben/flutter/bin/dart test packages/firebase_dart/test
```

## Additional Test Suites (Optional)
Run plugin/example tests when relevant:

```bash
flutter test packages/firebase_dart_flutter/example/test
```

## Notes
- If you are switching between REST and gRPC backends, keep `Settings.useGrpc` in mind.
- When emulator testing is required, configure `useEmulator(host, port)` in your setup.
