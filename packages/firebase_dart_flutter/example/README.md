# Firebase Dart Flutter Example

A Flutter example application demonstrating how to use the `firebase_dart_flutter` package.

## Features

This example app demonstrates:
- Firebase Authentication (Email/Password, Google, Facebook, Apple)
- Firebase Realtime Database operations
- Multi-app support (manage multiple Firebase projects)
- Cross-platform support (iOS, Android, Web, macOS, Windows, Linux)

## Getting Started

### 1. Configure Firebase

The app currently uses demo/stub Firebase configuration. To use with your own Firebase project:

#### Option A: Using Firebase CLI (Recommended)

1. Install Firebase CLI:
   ```bash
   npm install -g firebase-tools
   ```

2. Login to Firebase:
   ```bash
   firebase login
   ```

3. Generate configuration:
   ```bash
   cd packages/firebase_dart_flutter/example
   flutterfire configure
   ```

This will automatically generate the `lib/firebase_options.dart` file with your project's configuration.

#### Option B: Manual Configuration

Edit `lib/firebase_options.dart` and replace the stub values with your Firebase project configuration from the Firebase Console:

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Go to Project Settings > General
4. Scroll down to "Your apps" section
5. Copy the configuration values for each platform

Example configuration:
```dart
static const FirebaseOptions android = FirebaseOptions(
  apiKey: 'YOUR_ANDROID_API_KEY',
  appId: 'YOUR_ANDROID_APP_ID',
  messagingSenderId: 'YOUR_SENDER_ID',
  projectId: 'your-project-id',
  authDomain: 'your-project.firebaseapp.com',
  databaseURL: 'https://your-project.firebaseio.com',
  storageBucket: 'your-project.appspot.com',
);
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Run the App

```bash
flutter run
```

## App Structure

```
lib/
├── main.dart                    # App entry point
├── firebase_options.dart        # Firebase configuration
└── src/
    ├── core.dart               # App list and navigation
    ├── auth.dart               # Authentication examples
    ├── database.dart           # Database examples
    ├── widgets.dart            # Reusable widgets
    └── database/
        └── inspector.dart      # Database inspector UI
```

## Usage

### Adding a New Firebase App

1. Tap the + button on the app list screen
2. Enter your Firebase project details
3. Tap "Add" to save

### Testing Authentication

1. Select a Firebase app from the list
2. Navigate to the Auth section
3. Try different authentication methods:
   - Email/Password sign up and sign in
   - Google Sign-In
   - Facebook Login
   - Apple Sign-In

### Testing Database

1. Select a Firebase app from the list
2. Navigate to the Database section
3. Try CRUD operations on the Realtime Database
4. Use the Database Inspector to view data structure

## Platform-Specific Setup

### iOS

For Apple Sign-In and other iOS features:
1. Enable required capabilities in Xcode
2. Configure URL schemes for OAuth
3. Add required keys to `Info.plist`

### Android

For Google Sign-In and other Android features:
1. Add SHA-1 fingerprint to Firebase Console
2. Download and add `google-services.json`

### Web

For web support:
1. Enable Firebase Authentication for web in Console
2. Configure authorized domains

## Troubleshooting

### Issue: "No Firebase App has been created"
**Solution**: Make sure you've configured Firebase options and initialized the app.

### Issue: Authentication providers not working
**Solution**: Enable the authentication methods in Firebase Console (Authentication > Sign-in method).

### Issue: Database operations failing
**Solution**: Check your Realtime Database rules in Firebase Console.

### Issue: SSL/Certificate errors in debug mode
**Solution**: The app includes `MyHttpOverrides` to allow self-signed certificates for debugging with proxy tools.

## Development Notes

- The app uses Hive for local storage to persist Firebase app configurations
- `isolated: false` is set in `FirebaseDartFlutter.setup()` to run on the main isolate
- Custom HTTP overrides are enabled in debug mode for network debugging

## Additional Resources

- [firebase_dart documentation](../../firebase_dart/README.md)
- [firebase_dart_flutter documentation](../README.md)
- [Firebase Documentation](https://firebase.google.com/docs)

## Contributing

Found a bug or want to add a feature? Contributions are welcome! Please:
1. Check existing issues
2. Create a new issue describing the change
3. Submit a pull request

## License

See the [LICENSE](../../../LICENSE) file for license rights and limitations.
