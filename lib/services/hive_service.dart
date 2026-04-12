import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../utils/constants.dart';

/// Initializes Hive with AES-256, schema versioning, and v1→v2 migration hooks.
class HiveService {
  HiveService._();

  static const FlutterSecureStorage _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static HiveAesCipher? _cipher;
  static bool _initialized = false;

  static bool get isInitialized => _initialized;

  /// Call once after [WidgetsFlutterBinding.ensureInitialized].
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      await Hive.initFlutter(AppConstants.hiveDataSubDir);

      final key = await _loadOrCreateAesKey();
      _cipher = HiveAesCipher(key);

      await _openMetaAndMigrate();

      await Future.wait([
        Hive.openBox<dynamic>(
          AppConstants.hiveBoxCache,
          encryptionCipher: _cipher,
        ),
        Hive.openBox<dynamic>(
          AppConstants.hiveBoxIndices,
          encryptionCipher: _cipher,
        ),
        Hive.openBox<dynamic>(
          AppConstants.hiveBoxSession,
          encryptionCipher: _cipher,
        ),
      ]);

      _initialized = true;

      if (kDebugMode) {
        developer.log(
          'HiveService: initialized (schema v${AppConstants.hiveSchemaVersion}, AES)',
          name: 'HiveService',
        );
      }
    } catch (e, st) {
      developer.log(
        'HiveService.initialize failed: $e',
        name: 'HiveService',
        error: e,
        stackTrace: st,
        level: 1000,
      );
      _initialized = false;
      if (kDebugMode) {
        debugPrint('HiveService: continuing without local encrypted cache');
      }
    }
  }

  static Future<Uint8List> _loadOrCreateAesKey() async {
    try {
      final existing = await _secure.read(
        key: AppConstants.secureStorageEncryptionKeyName,
      );
      if (existing != null && existing.isNotEmpty) {
        return Uint8List.fromList(base64Decode(existing));
      }
      final key = Hive.generateSecureKey();
      final bytes = Uint8List.fromList(key);
      await _secure.write(
        key: AppConstants.secureStorageEncryptionKeyName,
        value: base64Encode(bytes),
      );
      return bytes;
    } catch (e, st) {
      developer.log(
        'HiveService: key load/create failed: $e',
        name: 'HiveService',
        error: e,
        stackTrace: st,
        level: 1000,
      );
      rethrow;
    }
  }

  static Future<void> _openMetaAndMigrate() async {
    Box<dynamic> meta;
    try {
      meta = await Hive.openBox<dynamic>(
        AppConstants.hiveBoxMeta,
        encryptionCipher: _cipher,
      );
    } catch (e, st) {
      developer.log(
        'HiveService: opening meta box failed: $e',
        name: 'HiveService',
        error: e,
        stackTrace: st,
        level: 1000,
      );
      rethrow;
    }

    final raw = meta.get(AppConstants.metaKeySchemaVersion);
    int version = 0;
    if (raw is int) {
      version = raw;
    } else if (raw is num) {
      version = raw.toInt();
    }

    if (version < AppConstants.hiveSchemaVersion) {
      await _migrate(
        from: version,
        meta: meta,
      );
      await meta.put(
        AppConstants.metaKeySchemaVersion,
        AppConstants.hiveSchemaVersion,
      );
      if (kDebugMode) {
        developer.log(
          'HiveService: migration finished -> v${AppConstants.hiveSchemaVersion}',
          name: 'HiveService',
        );
      }
    }
  }

  /// Schema migrations (extend when [AppConstants.hiveSchemaVersion] increases).
  static Future<void> _migrate({
    required int from,
    required Box<dynamic> meta,
  }) async {
    try {
      if (from < 2) {
        await _migrateToV2(meta);
      }
    } catch (e, st) {
      developer.log(
        'HiveService._migrate failed (from=$from): $e',
        name: 'HiveService',
        error: e,
        stackTrace: st,
        level: 1000,
      );
      rethrow;
    }
  }

  /// v2.0: AES-encrypted boxes + schema flag. (v1 had no encryption; no on-device migration path.)
  static Future<void> _migrateToV2(Box<dynamic> meta) async {
    if (kDebugMode) {
      developer.log(
        'HiveService: applying v2 schema (encrypted); legacy v1 path: ${AppConstants.hiveLegacySubDir}',
        name: 'HiveService',
      );
    }
    await meta.put('migrated_from', AppConstants.hiveSchemaVersionLegacy);
    await meta.put('migrated_at_ms', DateTime.now().millisecondsSinceEpoch);
  }

  static HiveAesCipher get cipher {
    final c = _cipher;
    if (c == null) {
      throw StateError('HiveService not initialized');
    }
    return c;
  }

  /// Absolute directory used for Hive files (for backup).
  static Future<Directory> hiveStorageDirectory() async {
    final doc = await getApplicationDocumentsDirectory();
    return Directory(p.join(doc.path, AppConstants.hiveDataSubDir));
  }
}
