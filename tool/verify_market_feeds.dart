// ignore_for_file: avoid_print
// Run from project root: dart run tool/verify_market_feeds.dart
// Prints HTTP status and a short body preview for each feed (Indeed RSS, Remotive, RemoteOK).

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

const _ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/122.0.0.0 Safari/537.36';

Future<void> main() async {
  await _probe(
    'Indeed RSS',
    Uri.parse('https://www.indeed.com/rss?q=flutter+developer&l=remote'),
    extraHeaders: {'Referer': 'https://www.indeed.com/'},
    parse: (body) {
      final doc = XmlDocument.parse(body);
      final items = doc.findAllElements('item').take(5).toList();
      print('   items (first 5): ${items.length}');
      for (final item in items) {
        final t = item.getElement('title')?.innerText ?? '?';
        print('   - ${t.length > 80 ? '${t.substring(0, 80)}…' : t}');
      }
    },
  );

  await _probe(
    'Remotive (search=flutter)',
    Uri.parse('https://remotive.com/api/remote-jobs?search=flutter'),
    parse: (body) => _printRemotive(body),
  );

  await _probe(
    'Remotive (no search — all)',
    Uri.parse('https://remotive.com/api/remote-jobs'),
    parse: (body) => _printRemotive(body),
  );

  await _probe(
    'Jobicy',
    Uri.parse('https://jobicy.com/api/v2/remote-jobs?count=20&tag=flutter'),
    parse: (body) {
      final m = jsonDecode(body) as Map<String, dynamic>;
      final jobs = m['jobs'] as List<dynamic>? ?? [];
      print('   jobs: ${jobs.length}');
      for (final j in jobs.take(5)) {
        if (j is Map) {
          print('   - ${j['title']} @ ${j['company_name']}');
        }
      }
    },
  );

  await _probe(
    'RemoteOK JSON',
    Uri.parse('https://remoteok.io/api?tags=flutter'),
    parse: (body) {
      final list = jsonDecode(body) as List<dynamic>;
      var n = 0;
      for (final e in list) {
        if (e is! Map) continue;
        if (e['position'] == null && e['company'] == null) continue;
        n++;
        if (n <= 5) {
          print('   - ${e['position']} @ ${e['company']}');
        }
      }
      print('   job rows (total parsed): $n');
    },
  );
}

void _printRemotive(String body) {
  final m = jsonDecode(body) as Map<String, dynamic>;
  final jobs = m['jobs'] as List<dynamic>? ?? [];
  print('   jobs: ${jobs.length}');
  for (final j in jobs.take(5)) {
    if (j is Map) {
      print('   - ${j['title']} @ ${j['company_name']}');
    }
  }
}

Future<void> _probe(
  String label,
  Uri uri, {
  Map<String, String>? extraHeaders,
  void Function(String body)? parse,
}) async {
  print('\n=== $label ===');
  print('GET $uri');
  try {
    final r = await http
        .get(
          uri,
          headers: {
            'User-Agent': _ua,
            'Accept': '*/*',
            ...?extraHeaders,
          },
        )
        .timeout(const Duration(seconds: 20));
    print('Status: ${r.statusCode}');
    final preview = r.body.length > 400 ? '${r.body.substring(0, 400)}…' : r.body;
    print('Body preview:\n$preview');
    if (parse != null && r.statusCode == 200) {
      try {
        parse(r.body);
      } catch (e) {
        print('Parse error: $e');
      }
    }
  } catch (e) {
    print('Request failed: $e');
  }
}
