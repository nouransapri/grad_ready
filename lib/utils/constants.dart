/// Application-wide constants (database, backup paths, schema).
library app_constants;

/// Hive / local encrypted storage and Firestore index naming.
abstract final class AppConstants {
  AppConstants._();

  /// Bump when on-disk Hive layout or encryption changes (see [HiveService] migrations).
  static const int hiveSchemaVersion = 2;

  /// Previous schema (plain Hive, no encryption) — used only for migration detection.
  static const int hiveSchemaVersionLegacy = 1;

  /// Subdirectory under app documents for Hive files (encrypted).
  static const String hiveDataSubDir = 'hive_encrypted_v2';

  /// Legacy subdir (v1) if present on device.
  static const String hiveLegacySubDir = 'hive_legacy_v1';

  static const String secureStorageEncryptionKeyName = 'grad_ready_hive_aes_v2';

  /// Box names (all opened with AES cipher in [HiveService]).
  static const String hiveBoxMeta = 'meta';
  static const String hiveBoxCache = 'app_cache';
  static const String hiveBoxIndices = 'query_indices';
  static const String hiveBoxSession = 'session';

  /// Keys inside [hiveBoxMeta].
  static const String metaKeySchemaVersion = 'schema_version';
  static const String metaKeyLastBackupAt = 'last_backup_at_ms';
  static const String metaKeyLastBackupPath = 'last_backup_path';

  /// Android public backup folder (primary target when permission allows).
  static const String backupFolderName = 'grad_ready';
  static const String backupAndroidEmulatedRoot = '/storage/emulated/0';

  /// Relative to [backupAndroidEmulatedRoot] or equivalent.
  static String get androidPublicBackupPath =>
      '$backupAndroidEmulatedRoot/$backupFolderName';

  /// Subfolder name for timestamped snapshots inside backup root.
  static const String backupSnapshotsDirName = 'snapshots';

  /// Firestore: common composite / single-field indexes (deploy with `firebase deploy --only firestore:indexes`).
  static const List<String> firestoreIndexedCollections = [
    'courses',
    'skills',
    'jobs',
    'insights',
    'market_trends',
  ];

  // --- User document: academic analysis (see [AnalysisService] / [AnalysisScreen]) ---
  static const String userFieldAddedCourses = 'added_courses';
  static const String userFieldGpa = 'gpa';
  static const String userFieldSkills = 'skills';
  static const String userFieldName = 'name';
  static const String userFieldFullName = 'full_name';
  static const String userFieldAcademicYear = 'academic_year';
  static const String userFieldIsSuspended = 'isSuspended';

  static const String collectionUsers = 'users';
  static const String collectionJobs = 'jobs';
  static const String collectionSkills = 'skills';
  static const String collectionCourses = 'courses';

  static const String dialogConfirmTitle = 'Are you sure?';
  static const String dialogConfirmDestructiveMessage =
      'This action cannot be undone.';
  static const String actionCancel = 'Cancel';
  static const String actionDelete = 'Delete';
  static const String actionSuspend = 'Deactivate / Block';
  static const String actionUnsuspend = 'Activate';
}
