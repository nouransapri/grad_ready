import 'package:flutter_test/flutter_test.dart';

/// Mirrors Firestore security intent for `users/{userId}` read access
/// (see firestore.rules: admin OR own document).
bool canReadUserDocument({
  required bool isSignedIn,
  required bool isAdmin,
  required String authUid,
  required String documentUserId,
}) {
  if (!isSignedIn) return false;
  if (isAdmin) return true;
  return authUid == documentUserId;
}

void main() {
  group('users collection read (client-side expectation)', () {
    test('owner can read own document', () {
      expect(
        canReadUserDocument(
          isSignedIn: true,
          isAdmin: false,
          authUid: 'u1',
          documentUserId: 'u1',
        ),
        isTrue,
      );
    });

    test('non-admin cannot read another user document', () {
      expect(
        canReadUserDocument(
          isSignedIn: true,
          isAdmin: false,
          authUid: 'u1',
          documentUserId: 'u2',
        ),
        isFalse,
      );
    });

    test('admin can read any user document', () {
      expect(
        canReadUserDocument(
          isSignedIn: true,
          isAdmin: true,
          authUid: 'admin1',
          documentUserId: 'u2',
        ),
        isTrue,
      );
    });

    test('anonymous cannot read', () {
      expect(
        canReadUserDocument(
          isSignedIn: false,
          isAdmin: false,
          authUid: '',
          documentUserId: 'u1',
        ),
        isFalse,
      );
    });
  });
}
