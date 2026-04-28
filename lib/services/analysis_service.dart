import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart' show BorderRadius, Color;

import '../models/skill_model.dart';

/// Academic analysis: GPA, chart groups from Firestore [courses], safe parsing of user data.
class AnalysisService {
  AnalysisService._();

  /// Strongly-typed row for rendering user skills progress in UI.
  static List<UserSkillProgress> parseUserSkillsProgress(dynamic raw) {
    if (raw is! List) return const <UserSkillProgress>[];
    final out = <UserSkillProgress>[];
    for (final item in raw) {
      if (item is! Map) continue;
      try {
        final m = Map<String, dynamic>.from(
          item.map((k, v) => MapEntry(k.toString(), v)),
        );
        final name = m['name']?.toString().trim() ?? '';
        final skillId = m['skillId']?.toString().trim() ?? '';
        final label = name.isNotEmpty ? name : skillId;
        if (label.isEmpty) continue;
        out.add(
          UserSkillProgress(
            label: label,
            percent: skillLevelToPercent(m['level']),
          ),
        );
      } catch (e, st) {
        developer.log(
          'parseUserSkillsProgress row skip: $e',
          name: 'AnalysisService',
          error: e,
          stackTrace: st,
        );
      }
    }
    return out;
  }

  static List<UserCourseEntry> lastCourses(List<UserCourseEntry> rows, {int maxCount = 7}) {
    final valid = rows.where((r) => r.isValid).toList();
    if (valid.length <= maxCount) return valid;
    return valid.sublist(valid.length - maxCount);
  }

  /// Weighted GPA: Σ(gradePoints × credits) / Σ(credits).
  static double? computeWeightedGpa(List<UserCourseEntry> rows) {
    try {
      double sumGp = 0;
      double sumCr = 0;
      for (final r in rows) {
        if (!r.isValid) continue;
        sumGp += r.gradePoints * r.credits;
        sumCr += r.credits;
      }
      if (sumCr <= 0) return null;
      final g = sumGp / sumCr;
      if (g.isNaN || g.isInfinite) return null;
      return double.parse(g.toStringAsFixed(3));
    } catch (e, st) {
      developer.log(
        'computeWeightedGpa: $e',
        name: 'AnalysisService',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }

  /// Parses [users.added_courses] list of maps (flexible keys).
  static List<UserCourseEntry> parseAddedCourses(dynamic raw) {
    if (raw is! List) return [];
    final out = <UserCourseEntry>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(
        item.map((k, v) => MapEntry(k.toString(), v)),
      );
      try {
        final name = (m['name'] ?? m['title'] ?? m['courseName'] ?? '')
            .toString()
            .trim();
        final credits = _parseDouble(
          m['credits'] ?? m['credit_hours'] ?? m['ch'] ?? m['hours'],
        );
        final gradeRaw = m['grade'] ?? m['grade_points'] ?? m['gpa'];
        final gp = _parseGradePoints(gradeRaw);
        if (name.isEmpty || credits == null || credits <= 0 || gp == null) {
          continue;
        }
        out.add(
          UserCourseEntry(
            name: name,
            gradePoints: gp.clamp(0.0, 4.0),
            credits: credits,
          ),
        );
      } catch (e, st) {
        developer.log(
          'parseAddedCourses row skip: $e',
          name: 'AnalysisService',
          error: e,
          stackTrace: st,
        );
      }
    }
    return out;
  }

  static double? _parseDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().trim());
  }

  /// Accepts 0–4 scale, 0–100 (mapped to 4.0 scale), or letter grades.
  static double? _parseGradePoints(dynamic raw) {
    if (raw == null) return null;
    if (raw is num) {
      final n = raw.toDouble();
      if (n >= 0 && n <= 4.5) return n.clamp(0.0, 4.0);
      if (n > 4 && n <= 100) return (n / 100.0 * 4.0).clamp(0.0, 4.0);
      return null;
    }
    final s = raw.toString().trim();
    if (s.isEmpty) return null;
    final letter = _letterToPoints(s);
    if (letter != null) return letter;
    final numeric = _parseDouble(s);
    if (numeric == null) return null;
    if (numeric >= 0 && numeric <= 4.5) return numeric.clamp(0.0, 4.0);
    if (numeric > 4 && numeric <= 100) return (numeric / 100.0 * 4.0).clamp(0.0, 4.0);
    return null;
  }

  static double? _letterToPoints(String s) {
    switch (s.toUpperCase()) {
      case 'A+':
      case 'A':
        return 4.0;
      case 'A-':
        return 3.7;
      case 'B+':
        return 3.3;
      case 'B':
        return 3.0;
      case 'B-':
        return 2.7;
      case 'C+':
        return 2.3;
      case 'C':
        return 2.0;
      case 'C-':
        return 1.7;
      case 'D':
      case 'D+':
        return 1.0;
      case 'F':
        return 0.0;
      default:
        return null;
    }
  }

  /// Profile text field fallback e.g. "3.45" or "3.45/4".
  static double? parseProfileGpaField(dynamic raw) {
    if (raw == null) return null;
    var s = raw.toString().trim();
    if (s.isEmpty) return null;
    final slash = s.split('/');
    if (slash.length == 2) {
      s = slash[0].trim();
    }
    final parsed = double.tryParse(s);
    if (parsed == null) return null;
    if (parsed >= 0 && parsed <= 4.5) return parsed.clamp(0.0, 4.0);
    if (parsed > 4 && parsed <= 100) return (parsed / 100.0 * 4.0).clamp(0.0, 4.0);
    return null;
  }

  /// Bar groups: total [SkillModel.jobCount] per skill (top [maxBars] by count).
  static List<BarChartGroupData> buildJobCountBySkillBars(
    List<SkillModel> skills, {
    int maxBars = 8,
  }) {
    try {
      final sortedSkills = List<SkillModel>.from(skills)
        ..sort((a, b) => (b.jobCount ?? 0).compareTo(a.jobCount ?? 0));
      
      final take = sortedSkills.take(maxBars).toList();
      return List.generate(take.length, (i) {
        return BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: (take[i].jobCount ?? 0).toDouble(),
              width: 14,
              borderRadius: BorderRadius.circular(4),
              color: const Color(0xFF2A6CFF),
            ),
          ],
        );
      });
    } catch (e, st) {
      developer.log(
        'buildJobCountBySkillBars: $e',
        name: 'AnalysisService',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }

  /// X labels for [buildJobCountBySkillBars] (same order).
  static List<String> jobCountBarLabels(
    List<SkillModel> skills, {
    int maxBars = 8,
  }) {
    try {
      final sortedSkills = List<SkillModel>.from(skills)
        ..sort((a, b) => (b.jobCount ?? 0).compareTo(a.jobCount ?? 0));
      
      return sortedSkills
          .take(maxBars)
          .map((e) => e.skillName.length > 10 ? '${e.skillName.substring(0, 9)}…' : e.skillName)
          .toList();
    } catch (e, st) {
      developer.log(
        'jobCountBarLabels: $e',
        name: 'AnalysisService',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }

  /// Line spots: cumulative GPA after each course (by list order).
  static List<FlSpot> cumulativeGpaSpots(List<UserCourseEntry> rows) {
    try {
      final valid = rows.where((r) => r.isValid).toList();
      if (valid.isEmpty) return [];
      double sumGp = 0;
      double sumCr = 0;
      final spots = <FlSpot>[];
      for (var i = 0; i < valid.length; i++) {
        final r = valid[i];
        sumGp += r.gradePoints * r.credits;
        sumCr += r.credits;
        final gpa = sumGp / sumCr;
        spots.add(FlSpot(i.toDouble(), gpa.clamp(0.0, 4.0)));
      }
      return spots;
    } catch (e, st) {
      developer.log(
        'cumulativeGpaSpots: $e',
        name: 'AnalysisService',
        error: e,
        stackTrace: st,
      );
      return [];
    }
  }

  /// Skills progress 0–100 from level strings (Basic/Intermediate/Advanced).
  static double skillLevelToPercent(dynamic level) {
    if (level is num) {
      return level.toDouble().clamp(0, 100);
    }
    final parsed = double.tryParse(level?.toString().trim() ?? '');
    if (parsed != null) {
      return parsed.clamp(0, 100);
    }
    final normalized = level?.toString().toLowerCase().trim();
    switch (normalized) {
      case 'basic':
        return 33;
      case 'intermediate':
        return 66;
      case 'advanced':
        return 100;
      default:
        return 0;
    }
  }

  /// Stream of catalog [SkillModel] for charts (real-time).
  static Stream<List<SkillModel>> watchSkillsCatalog({int limit = 80}) {
    return FirebaseFirestore.instance
        .collection('skills')
        .limit(limit)
        .snapshots()
        .map((snap) {
      try {
        return snap.docs
            .map((d) {
              try {
                return SkillModel.fromFirestore(d.id, d.data());
              } catch (e, st) {
                developer.log(
                  'SkillModel.fromFirestore: $e',
                  name: 'AnalysisService',
                  error: e,
                  stackTrace: st,
                );
                return null;
              }
            })
            .whereType<SkillModel>()
            .toList();
      } catch (e, st) {
        developer.log(
          'watchSkillsCatalog map: $e',
          name: 'AnalysisService',
          error: e,
          stackTrace: st,
        );
        return <SkillModel>[];
      }
    });
  }
}



class UserSkillProgress {
  final String label;
  final double percent;

  const UserSkillProgress({
    required this.label,
    required this.percent,
  });
}

class UserCourseEntry {
  final String name;
  final double gradePoints;
  final double credits;
  
  const UserCourseEntry({
    required this.name,
    required this.gradePoints,
    required this.credits,
  });

  bool get isValid => name.isNotEmpty && credits > 0;
}
