import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../models/market_insights.dart';

/// Live job signals with multiple sources and in-memory cache.
///
/// **Android:** requires `INTERNET` in `AndroidManifest.xml`.
/// **Web:** third-party APIs may block the browser (CORS).
///
/// **Indeed RSS** often returns 404 or HTML from this environment; Remotive’s
/// public API is the most reliable (`/api/remote-jobs` full list + client filter).
class MarketInsightsService {
  static const _remotiveAllUrl = 'https://remotive.com/api/remote-jobs';
  static const _remotiveFlutterSearchUrl =
      'https://remotive.com/api/remote-jobs?search=flutter';
  static const _indeedRssUrl = 'https://www.indeed.com/rss?q=flutter';

  static const _browserHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
    'Accept':
        'application/json, application/rss+xml, application/xml, text/xml, */*',
    'Accept-Language': 'en-US,en;q=0.9',
  };

  static const Duration _minRefreshInterval = Duration(minutes: 5);

  static MarketInsights? _cached;
  static DateTime? _cachedAt;

  static Future<MarketInsights> getRealInsights({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _cached != null &&
        _cachedAt != null &&
        _cached!.hasLiveData &&
        DateTime.now().difference(_cachedAt!) < _minRefreshInterval) {
      return _cached!;
    }

    MarketInsights? result;
    try {
      result = await _fetchFromNetwork();
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('MarketInsightsService: $e');
        debugPrint('$st');
      }
    }

    if (result != null && result.hasLiveData) {
      _cached = result;
      _cachedAt = DateTime.now();
      return result;
    }

    if (_cached != null && _cached!.hasLiveData) {
      return _cached!;
    }

    return MarketInsights.fallback();
  }

  static Future<MarketInsights?> _fetchFromNetwork() async {
    if (kIsWeb) {
      debugPrint(
        'MarketInsights: Web build — if feeds fail, try Android/iOS (CORS).',
      );
    }

    final remotive = await _fromRemotive();
    if (remotive != null &&
        remotive.hasLiveData &&
        remotive.jobCount > 0) {
      return remotive;
    }

    final indeed = await _fromIndeedRss();
    if (indeed != null &&
        indeed.hasLiveData &&
        indeed.jobCount > 0) {
      return indeed;
    }

    return remotive ?? indeed;
  }

  static bool _matchesFlutterDart(Map<String, dynamic> j) {
    final blob =
        '${j['title'] ?? ''} ${j['category'] ?? ''} ${j['job_type'] ?? ''}'
            .toLowerCase();
    return RegExp(r'flutter|\bdart\b').hasMatch(blob);
  }

  static MarketInsights _buildFromRemotiveMaps(
    List<Map<String, dynamic>> jobs, {
    required String jobListKind,
  }) {
    final n = jobs.length.clamp(0, 999);
    final titles = <String>[];
    final companies = <String>{};
    for (final j in jobs) {
      final title = j['title']?.toString().trim();
      if (title != null && title.isNotEmpty) titles.add(title);
      final company = j['company_name']?.toString().trim();
      if (company != null && company.isNotEmpty) companies.add(company);
    }
    return MarketInsights(
      jobCount: n,
      topJobs: titles.take(5).toList(),
      topCompanies: companies.take(8).toList(),
      // Avoid synthetic KPI math; show only verified live listing signals.
      growthRate: '—',
      avgSalary: '—',
      jobListKind: jobListKind,
    );
  }

  /// Remotive: `search=flutter` is often empty; full feed + filter works better.
  static Future<MarketInsights?> _fromRemotive() async {
    try {
      Future<List<Map<String, dynamic>>?> load(String url) async {
        final response = await http
            .get(Uri.parse(url), headers: _browserHeaders)
            .timeout(const Duration(seconds: 20));
        if (response.statusCode != 200) {
          if (kDebugMode) {
            debugPrint('Remotive: $url → HTTP ${response.statusCode}');
          }
          return null;
        }
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) return null;
        final raw = decoded['jobs'];
        if (raw is! List) return null;
        final out = <Map<String, dynamic>>[];
        for (final e in raw) {
          if (e is Map<String, dynamic>) {
            out.add(e);
          } else if (e is Map) {
            out.add(Map<String, dynamic>.from(e));
          }
        }
        return out;
      }

      var list = await load(_remotiveFlutterSearchUrl);
      if (list != null && list.isNotEmpty) {
        return _buildFromRemotiveMaps(
          list.take(20).toList(),
          jobListKind: 'Flutter-related remote jobs',
        );
      }

      list = await load(_remotiveAllUrl);
      if (list == null || list.isEmpty) return null;

      final filtered =
          list.where(_matchesFlutterDart).take(20).toList();
      if (filtered.isNotEmpty) {
        return _buildFromRemotiveMaps(
          filtered,
          jobListKind: 'Flutter / Dart-related remote jobs',
        );
      }

      return _buildFromRemotiveMaps(
        list.take(20).toList(),
        jobListKind: 'remote job listings (sample)',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Remotive error: $e');
      return null;
    }
  }

  static Future<MarketInsights?> _fromIndeedRss() async {
    try {
      final response = await http
          .get(
            Uri.parse(_indeedRssUrl),
            headers: {
              ..._browserHeaders,
              'Referer': 'https://www.indeed.com/',
            },
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        if (kDebugMode) {
          debugPrint('Indeed RSS: HTTP ${response.statusCode}');
        }
        return null;
      }
      final body = utf8.decode(response.bodyBytes);
      final lower = body.toLowerCase();
      if (!lower.contains('<rss') &&
          !lower.contains('<feed') &&
          !lower.contains('<item')) {
        if (kDebugMode) {
          debugPrint(
            'Indeed RSS: not XML/RSS (${body.length} chars)',
          );
        }
        return null;
      }
      final doc = XmlDocument.parse(body);
      final items = doc.findAllElements('item').take(20).toList();
      if (items.isEmpty) return null;

      final titles = <String>[];
      final companies = <String>{};
      for (final item in items) {
        final title = _textOf(item, 'title');
        if (title != null && title.isNotEmpty) titles.add(title);
        final company = _textOf(item, 'author') ?? _dcCreator(item) ?? 'Remote';
        companies.add(company);
      }

      return MarketInsights(
        jobCount: items.length,
        topJobs: titles.take(5).toList(),
        topCompanies: companies.take(8).toList(),
        growthRate: '—',
        avgSalary: '—',
        jobListKind: 'jobs (Indeed RSS)',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Indeed RSS error: $e');
      return null;
    }
  }

  static String? _textOf(XmlElement parent, String tag) {
    final el = parent.getElement(tag);
    if (el == null) return null;
    final t = el.innerText.trim();
    return t.isEmpty ? null : t;
  }

  static String? _dcCreator(XmlElement item) {
    for (final child in item.childElements) {
      if (child.name.local == 'creator') {
        final t = child.innerText.trim();
        if (t.isNotEmpty) return t;
      }
    }
    return null;
  }

  @visibleForTesting
  static void clearCacheForTest() {
    _cached = null;
    _cachedAt = null;
  }
}
