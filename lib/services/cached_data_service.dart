/// Short-lived in-memory cache for expensive Firestore reads (e.g. full jobs list).
class CachedDataService {
  CachedDataService._();

  static final Map<String, Object> _cache = {};
  static final Map<String, DateTime> _timestamps = {};
  static const Duration ttl = Duration(minutes: 5);

  /// Cache key for [FirestoreService.getJobsOnce].
  static const String keyJobsOnce = 'firestore_jobs_once';
  static const String _keyJobDocumentsOncePrefix = 'firestore_job_documents_once_';
  static const String _keyUsersOncePrefix = 'firestore_users_once_';
  static const String _keyUsersSearchPrefix = 'firestore_users_search_';

  static String keyJobDocumentsOnce(int limit) => '$_keyJobDocumentsOncePrefix$limit';
  static String keyUsersOnce(int limit) => '$_keyUsersOncePrefix$limit';
  static String keyUsersSearch({required String query, required int limit}) =>
      '$_keyUsersSearchPrefix${query.trim().toLowerCase()}_$limit';

  static Future<T> getCached<T extends Object>(
    String key,
    Future<T> Function() fetcher,
  ) async {
    final now = DateTime.now();
    final ts = _timestamps[key];
    final hit = _cache[key];
    if (ts != null && hit != null && hit is T && now.difference(ts) < ttl) {
      return hit;
    }
    final data = await fetcher();
    _cache[key] = data;
    _timestamps[key] = now;
    return data;
  }

  static void invalidate(String key) {
    _cache.remove(key);
    _timestamps.remove(key);
  }

  static void invalidateAll() {
    _cache.clear();
    _timestamps.clear();
  }
}
