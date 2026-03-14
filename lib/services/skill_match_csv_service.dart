import 'package:flutter/services.dart';

import '../models/skill_match_row.dart';

/// Loads and parses skill_match_results.csv from assets/data/.
class SkillMatchCsvService {
  static const String _assetPath = 'assets/data/skill_match_results.csv';

  /// Loads all rows from the CSV. Returns empty list on error.
  static Future<List<SkillMatchRow>> loadFromAssets() async {
    try {
      final String data = await rootBundle.loadString(_assetPath);
      return parseCsv(data);
    } catch (_) {
      return [];
    }
  }

  /// Parses CSV text into [SkillMatchRow] list. First line = header.
  static List<SkillMatchRow> parseCsv(String csvText) {
    final lines = csvText
        .split(RegExp(r'\r?\n'))
        .where((l) => l.trim().isNotEmpty)
        .toList();
    if (lines.length < 2) return [];
    // Skip header
    final rows = <SkillMatchRow>[];
    for (var i = 1; i < lines.length; i++) {
      final cols = _parseCsvLine(lines[i]);
      if (cols.length >= 4) {
        final recommend = cols[3].toLowerCase() == 'true';
        final pct = double.tryParse(cols[2]) ?? 0.0;
        rows.add(
          SkillMatchRow(
            userId: cols[0].trim(),
            jobId: cols[1].trim(),
            matchPercentage: pct,
            recommend: recommend,
          ),
        );
      }
    }
    return rows;
  }

  static List<String> _parseCsvLine(String line) {
    final result = <String>[];
    var current = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        inQuotes = !inQuotes;
      } else if ((c == ',' && !inQuotes) || (c == '\n' && !inQuotes)) {
        result.add(current.toString());
        current = StringBuffer();
      } else {
        current.write(c);
      }
    }
    result.add(current.toString());
    return result;
  }
}
