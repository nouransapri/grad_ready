/// Web OAuth 2.0 client ID (ends with `.apps.googleusercontent.com`).
///
/// Required on Android for Firebase Auth + Google when `idToken` is needed.
/// Set this after enabling Google sign-in in Firebase Console and adding your
/// app SHA-1, or paste the **Web client** ID from:
/// Firebase Console → Project settings → Your apps → Web app, or
/// Google Cloud Console → APIs & Services → Credentials → OAuth 2.0 Client IDs (Web).
///
/// You can also pass at build time without editing this file:
/// `flutter build apk --dart-define=GOOGLE_SERVER_CLIENT_ID=xxxxx.apps.googleusercontent.com`
library;

const String kGoogleOAuthWebClientId = '';
