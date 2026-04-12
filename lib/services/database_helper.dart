import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../utils/constants.dart';
import 'hive_service.dart';

/// Typed access to encrypted Hive boxes: cache, secondary indexes, session.
/// All operations are async; errors are logged and rethrown (or surfaced as [DatabaseResult]).
class DatabaseHelper {
  DatabaseHelper._();

  static DateTime? _lastAutoBackupAt;
  static const Duration _backupCooldown = Duration(minutes: 10);

  // --- Core boxes (must call [HiveService.initialize] first) ---

  static Box<dynamic> _box(String name) {
    if (!HiveService.isInitialized) {
      throw StateError('HiveService.initialize() must be called first');
    }
    return Hive.box<dynamic>(name);
  }

  static Future<T> _guard<T>(
    String operation,
    Future<T> Function() fn,
  ) async {
    try {
      return await fn();
    } catch (e, st) {
      developer.log(
        'DatabaseHelper.$operation failed: $e',
        name: 'DatabaseHelper',
        error: e,
        stackTrace: st,
        level: 1000,
      );
      rethrow;
    }
  }

  // --- Cache (JSON-serializable values) ---

  /// Persists a JSON-encodable value with optional TTL metadata for fast reads.
  static Future<void> putCache({
    required String key,
    required Object? value,
    Duration? ttl,
  }) {
    return _guard('putCache', () async {
      final payload = <String, dynamic>{
        'v': 1,
        'savedAt': DateTime.now().millisecondsSinceEpoch,
        if (ttl != null) 'expiresAt': DateTime.now().add(ttl).millisecondsSinceEpoch,
        'data': value,
      };
      await _box(AppConstants.hiveBoxCache).put(key, jsonEncode(payload));
    });
  }

  static Future<Object?> getCache(String key) {
    return _guard('getCache', () async {
      final raw = _box(AppConstants.hiveBoxCache).get(key);
      if (raw is! String) return null;
      Map<String, dynamic> map;
      try {
        map = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        await _box(AppConstants.hiveBoxCache).delete(key);
        return null;
      }
      final exp = map['expiresAt'];
      if (exp is num && DateTime.now().millisecondsSinceEpoch > exp.toInt()) {
        await _box(AppConstants.hiveBoxCache).delete(key);
        return null;
      }
      return map['data'];
    });
  }

  static Future<void> deleteCache(String key) {
    return _guard('deleteCache', () async {
      await _box(AppConstants.hiveBoxCache).delete(key);
    });
  }

  // --- Secondary index (Hive "indexes": O(1) lookup lists by bucket key) ---

  static String _indexHiveKey(String indexName, String lookupValue) =>
      'idx::$indexName::$lookupValue';

  /// Adds [recordKey] to the index bucket for [lookupValue].
  static Future<void> indexAdd({
    required String indexName,
    required String lookupValue,
    required String recordKey,
  }) {
    return _guard('indexAdd', () async {
      final b = _box(AppConstants.hiveBoxIndices);
      final k = _indexHiveKey(indexName, lookupValue);
      final list = (b.get(k) as List?)?.map((e) => e.toString()).toList() ?? <String>[];
      if (!list.contains(recordKey)) {
        list.add(recordKey);
        await b.put(k, list);
      }
    });
  }

  /// Replaces the bucket with the exact list (for rebuilds).
  static Future<void> indexPutBucket({
    required String indexName,
    required String lookupValue,
    required List<String> recordKeys,
  }) {
    return _guard('indexPutBucket', () async {
      await _box(AppConstants.hiveBoxIndices).put(
        _indexHiveKey(indexName, lookupValue),
        recordKeys,
      );
    });
  }

  /// Returns record ids for [lookupValue], or empty if none.
  static Future<List<String>> indexQuery({
    required String indexName,
    required String lookupValue,
  }) {
    return _guard('indexQuery', () async {
      final raw = _box(AppConstants.hiveBoxIndices).get(
        _indexHiveKey(indexName, lookupValue),
      );
      if (raw is! List) return [];
      return raw.map((e) => e.toString()).toList();
    });
  }

  static Future<void> indexRemoveRecord({
    required String indexName,
    required String lookupValue,
    required String recordKey,
  }) {
    return _guard('indexRemoveRecord', () async {
      final b = _box(AppConstants.hiveBoxIndices);
      final k = _indexHiveKey(indexName, lookupValue);
      final list = (b.get(k) as List?)?.map((e) => e.toString()).toList() ?? <String>[];
      list.remove(recordKey);
      if (list.isEmpty) {
        await b.delete(k);
      } else {
        await b.put(k, list);
      }
    });
  }

  // --- Session (non-sensitive flags; still encrypted at rest) ---

  static Future<void> putSession(String key, Object? value) {
    return _guard('putSession', () async {
      await _box(AppConstants.hiveBoxSession).put(key, value);
    });
  }

  static Future<T?> getSession<T>(String key) {
    return _guard('getSession', () async {
      final v = _box(AppConstants.hiveBoxSession).get(key);
      return v is T ? v : null;
    });
  }

  // --- Backup ---

  static bool _withinCooldown() {
    final t = _lastAutoBackupAt;
    if (t == null) return false;
    return DateTime.now().difference(t) < _backupCooldown;
  }

  /// Copies all `.hive` files from the encrypted Hive directory to a backup folder.
  /// Android: prefers `/storage/emulated/0/grad_ready/` when storage permission allows.
  static Future<DatabaseResult<String>> performAutoBackup() async {
    if (!HiveService.isInitialized) {
      return DatabaseResult.failure('Hive not initialized');
    }
    if (_withinCooldown()) {
      return DatabaseResult.failure('Backup skipped (cooldown)');
    }

    try {
      final hiveRoot = await HiveService.hiveStorageDirectory();
      if (!await hiveRoot.exists()) {
        return DatabaseResult.failure('Hive directory missing');
      }

      final backupRoot = await _resolveWritableBackupRoot();
      final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
      final snap = Directory(
        p.join(backupRoot.path, AppConstants.backupSnapshotsDirName, stamp),
      );
      await snap.create(recursive: true);

      var count = 0;
      await for (final entity in hiveRoot.list()) {
        if (entity is! File) continue;
        if (!entity.path.toLowerCase().endsWith('.hive')) continue;
        final target = File(p.join(snap.path, p.basename(entity.path)));
        await entity.copy(target.path);
        count++;
      }

      await _box(AppConstants.hiveBoxMeta).put(
        AppConstants.metaKeyLastBackupAt,
        DateTime.now().millisecondsSinceEpoch,
      );
      await _box(AppConstants.hiveBoxMeta).put(
        AppConstants.metaKeyLastBackupPath,
        snap.path,
      );
      _lastAutoBackupAt = DateTime.now();

      if (kDebugMode) {
        developer.log(
          'DatabaseHelper: backup OK ($count files) -> ${snap.path}',
          name: 'DatabaseHelper',
        );
      }
      return DatabaseResult.ok(snap.path);
    } catch (e, st) {
      developer.log(
        'DatabaseHelper.performAutoBackup: $e',
        name: 'DatabaseHelper',
        error: e,
        stackTrace: st,
        level: 1000,
      );
      return DatabaseResult.failure('$e');
    }
  }

  static Future<Directory> _resolveWritableBackupRoot() async {
    if (Platform.isAndroid) {
      await Permission.storage.request();
      final public = Directory(AppConstants.androidPublicBackupPath);
      try {
        await public.create(recursive: true);
        await File(p.join(public.path, '.write_test')).writeAsString('ok', flush: true);
        await File(p.join(public.path, '.write_test')).delete();
        return public;
      } catch (e, st) {
        if (kDebugMode) {
          developer.log(
            'DatabaseHelper: public backup path unavailable ($e), using app storage',
            name: 'DatabaseHelper',
            stackTrace: st,
          );
        }
      }
    }

    final doc = await getApplicationDocumentsDirectory();
    final fallback = Directory(p.join(doc.path, AppConstants.backupFolderName));
    await fallback.create(recursive: true);
    return fallback;
  }

  /// Call after writes that should be durable off-device (debounced).
  static void scheduleBackupDebounced() {
    if (_withinCooldown()) return;
    unawaited(performAutoBackup());
  }
}

/// Lightweight result for operations where exceptions should not always propagate.
class DatabaseResult<T> {
  DatabaseResult._({this.data, this.error});

  final T? data;
  final String? error;

  bool get isSuccess => error == null;

  static DatabaseResult<T> ok<T>(T value) => DatabaseResult._(data: value);

  static DatabaseResult<T> failure<T>(String message) =>
      DatabaseResult._(error: message);
}
