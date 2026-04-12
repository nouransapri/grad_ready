import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Uploads profile images to Firebase Storage and stores the download URL in Firestore (`photoUrl`).
class ProfilePhotoService {
  ProfilePhotoService._();

  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final ImagePicker _picker = ImagePicker();

  static Future<XFile?> pickImage({ImageSource source = ImageSource.gallery}) {
    return _picker.pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 88,
    );
  }

  /// Uploads [file] to `profile_images/{uid}/avatar.jpg` and updates `users/{uid}.photoUrl`.
  static Future<String> uploadAndSaveProfilePhoto(File file) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw StateError('Not signed in');
    }

    final ref = _storage
        .ref()
        .child('profile_images')
        .child(user.uid)
        .child('avatar.jpg');

    await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg', cacheControl: 'public, max-age=31536000'),
    );

    final url = await ref.getDownloadURL();

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
      {
        'photoUrl': url,
        'photoUpdatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    try {
      await user.updatePhotoURL(url);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('updatePhotoURL skipped: $e');
        debugPrintStack(stackTrace: st);
      }
    }

    return url;
  }
}
