import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/insight_model.dart';
import '../models/job_role.dart';
import '../models/skill.dart';
import '../models/trend_model.dart';
import '../utils/skill_utils.dart';
import 'gap_analysis_service.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Map<String, Skill>? _skillsCache;
  static DateTime? _skillsCacheTime;
  static const Duration _skillsCacheTtl = Duration(minutes: 5);

  /// Stream of all jobs from Firestore 'jobs' collection.
  Stream<List<JobRole>> getJobs() {
    return _db.collection('jobs').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => JobRole.fromFirestore(doc.id, doc.data()))
          .toList();
    });
  }

  /// One-time fetch of all jobs. Used when recalculating gap analysis for all roles after skill updates.
  Future<List<JobRole>> getJobsOnce() async {
    final snapshot = await _db.collection('jobs').get();
    return snapshot.docs
        .map((doc) => JobRole.fromFirestore(doc.id, doc.data()))
        .toList();
  }

  /// Real-time stream of all users (id + skills). Skills can be List<String> or list of maps with 'name'.
  Stream<List<Map<String, dynamic>>> streamUsers() {
    return _db.collection('users').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final skillsRaw = data['skills'] as List?;
        final skills = <String>[];
        if (skillsRaw != null) {
          for (final s in skillsRaw) {
            if (s is String && s.toString().trim().isNotEmpty) {
              skills.add(s.toString().trim());
            } else if (s is Map) {
              final name = s['name']?.toString().trim();
              final skillId = s['skillId']?.toString().trim();
              if (name != null && name.isNotEmpty) {
                skills.add(name);
              } else if (skillId != null && skillId.isNotEmpty) {
                skills.add(skillId);
              }
            }
          }
        }
        return <String, dynamic>{'id': doc.id, 'skills': skills};
      }).toList();
    });
  }

  /// Stream of all users with fields needed for admin analytics: id, skills, academic_year, last_analysis, last_analysis_at.
  Stream<List<Map<String, dynamic>>> streamUsersForAnalytics() {
    return _db.collection('users').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final skillsRaw = data['skills'] as List?;
        final skills = <String>[];
        if (skillsRaw != null) {
          for (final s in skillsRaw) {
            if (s is String && s.toString().trim().isNotEmpty) {
              skills.add(s.toString().trim());
            } else if (s is Map) {
              final name = s['name']?.toString().trim();
              final skillId = s['skillId']?.toString().trim();
              if (name != null && name.isNotEmpty) {
                skills.add(name);
              } else if (skillId != null && skillId.isNotEmpty) {
                skills.add(skillId);
              }
            }
          }
        }
        return <String, dynamic>{
          'id': doc.id,
          'skills': skills,
          'academic_year': data['academic_year'],
          'last_analysis': data['last_analysis'],
          'last_analysis_at': data['last_analysis_at'],
        };
      }).toList();
    });
  }

  /// Real-time stream of a single job by id. Use for live skill gap analysis.
  Stream<JobRole?> getJobStream(String jobId) {
    return _db.collection('jobs').doc(jobId).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return JobRole.fromFirestore(doc.id, doc.data()!);
      }
      return null;
    });
  }

  /// Add a new job role to Firestore. Returns the new document id.
  Future<String> addJob(JobRole job) async {
    final ref = _db.collection('jobs').doc();
    await ref.set(job.toFirestore());
    return ref.id;
  }

  /// Update an existing job role in Firestore by id. Used for bulk "Update Selected" in Market.
  Future<void> updateJob(JobRole job) async {
    if (job.id.isEmpty) return;
    await _db.collection('jobs').doc(job.id).set(job.toFirestore());
  }

  /// Master skills collection: id -> Skill (name, category). Cached in memory for [_skillsCacheTtl].
  Future<Map<String, Skill>> getSkills() async {
    final now = DateTime.now();
    if (_skillsCache != null &&
        _skillsCacheTime != null &&
        now.difference(_skillsCacheTime!) < _skillsCacheTtl) {
      return _skillsCache!;
    }
    final snapshot = await _db.collection('skills').get();
    final map = <String, Skill>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (data.isEmpty) continue;
      final skill = Skill.fromFirestore(doc.id, data);
      if (skill.name.isNotEmpty) map[skill.id] = skill;
    }
    _skillsCache = map;
    _skillsCacheTime = now;
    return map;
  }

  /// Call when skills collection is updated (e.g. admin) so next getSkills() fetches fresh data.
  static void invalidateSkillsCache() {
    _skillsCache = null;
    _skillsCacheTime = null;
  }

  /// Normalized skill id from display name (doc id in skills collection).
  static String skillNameToSkillId(String name) {
    return name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
  }

  static String _skillNameToDocId(String name) => skillNameToSkillId(name);

  /// Fetch suggested learning resources (course names) for missing skills from Firestore.
  /// Uses batch getAll to avoid N+1 reads. Returns map skillName (display) -> list of up to 3 course names.
  Future<Map<String, List<String>>> getSuggestedCoursesForSkills(
    List<String> skillNames,
  ) async {
    const maxPerSkill = 3;
    final result = <String, List<String>>{};
    final uniqueIds = skillNames
        .map(_skillNameToDocId)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (uniqueIds.isEmpty) return result;
    try {
      final refs = uniqueIds
          .map((id) => _db.collection('skills').doc(id))
          .toList();
      final snapshots = await Future.wait(refs.map((r) => r.get()));
      final idToCourses = <String, List<String>>{};
      for (var i = 0; i < snapshots.length && i < refs.length; i++) {
        final data = snapshots[i].data();
        final list = data?['suggestedCourses'] as List<dynamic>?;
        final courses =
            list
                ?.map((e) => e?.toString().trim())
                .where((s) => s != null && s.isNotEmpty)
                .cast<String>()
                .take(maxPerSkill)
                .toList() ??
            [];
        idToCourses[refs[i].id] = courses;
      }
      for (final name in skillNames) {
        final id = _skillNameToDocId(name);
        result[name] = idToCourses[id] ?? [];
      }
    } catch (e, st) {
      debugPrint('getSuggestedCoursesForSkills failed: $e');
      if (kDebugMode) debugPrintStack(stackTrace: st);
      for (final name in skillNames) {
        result[name] = [];
      }
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Skill add/update API: updates Firestore skills, profile completion, and
  // analysis_results. Dashboard and gap analysis screens use Firestore streams,
  // so they update immediately when these methods write to the user document.
  // ---------------------------------------------------------------------------

  /// Converts a points value (0–100) to a display level string used by the
  /// profile UI and stored in Firestore (Basic / Intermediate / Advanced).
  static String _pointsToLevel(int points) {
    final p = points.clamp(0, 100);
    if (p <= 35) return 'Basic';
    if (p <= 70) return 'Intermediate';
    return 'Advanced';
  }

  /// Parses the raw skills list from a user document into a list of skill maps.
  /// Handles: legacy List<String>; legacy Map with 'name','type','level','points'; new Map with 'skillId','level' (0-100).
  static List<Map<String, dynamic>> _parseSkillsList(dynamic raw) {
    if (raw == null) return [];
    if (raw is! List) return [];
    final list = <Map<String, dynamic>>[];
    for (final item in raw) {
      if (item is Map) {
        final m = Map<String, dynamic>.from(
          item.map((k, v) => MapEntry(k.toString(), v)),
        );
        final skillId = m['skillId']?.toString().trim();
        final name = m['name']?.toString().trim();
        if (skillId != null && skillId.isNotEmpty) {
          list.add({
            'skillId': skillId,
            'level': (m['level'] is int)
                ? (m['level'] as int).clamp(0, 100)
                : (int.tryParse(m['level']?.toString() ?? '0') ?? 0).clamp(
                    0,
                    100,
                  ),
          });
        } else if (name != null && name.isNotEmpty) {
          list.add(m);
        }
      } else if (item is String && item.trim().isNotEmpty) {
        list.add({
          'name': item.trim(),
          'type': 'Technical',
          'level': 'Basic',
          'points': 35,
        });
      }
    }
    return list;
  }

  /// Adds a new skill or updates level/points if a skill with the same name exists.
  /// If the skill name exists in the master skills catalog, writes new format { skillId, level };
  /// otherwise writes legacy { name, type, level, points }. Use addSkillById to always write new format.
  Future<void> addSkill(String uid, String skillName, int points) async {
    if (uid.isEmpty || skillName.trim().isEmpty) return;
    final pointsClamped = points.clamp(0, 100);
    final catalog = await getSkills();
    if (catalog.isNotEmpty) {
      final normalized = normalizeSkillName(skillName);
      for (final s in catalog.values) {
        if (normalizeSkillName(s.name) == normalized) {
          await addSkillById(uid, s.id, pointsClamped);
          return;
        }
      }
    }
    final ref = _db.collection('users').doc(uid);
    final doc = await ref.get();
    if (!doc.exists || doc.data() == null) return;

    final data = doc.data()!;
    final skills = _parseSkillsList(data['skills']);
    final normalizedNew = normalizeSkillName(skillName);
    final displayName = skillName.trim();
    final level = _pointsToLevel(pointsClamped);

    final idx = skills.indexWhere(
      (s) => normalizeSkillName(s['name']?.toString()) == normalizedNew,
    );
    final Map<String, dynamic> skillMap = {
      'name': displayName,
      'type': idx >= 0
          ? (skills[idx]['type'] ?? 'Technical').toString()
          : 'Technical',
      'level': level,
      'points': pointsClamped,
    };
    if (idx >= 0) {
      skills[idx] = {...skills[idx], ...skillMap};
    } else {
      skills.add(skillMap);
    }

    await ref.update({
      'skills': skills.map((s) => s).toList(),
      'profile_completed': true,
    });

    refreshAnalysisResultsForUser(uid).catchError((e, st) {
      debugPrint('refreshAnalysisResultsForUser failed: $e');
      if (kDebugMode) debugPrintStack(stackTrace: st);
    });
  }

  /// Adds or updates a skill by master skill id and level (0-100). Writes users.skills as { skillId, level }.
  Future<void> addSkillById(String uid, String skillId, int level) async {
    if (uid.isEmpty || skillId.trim().isEmpty) return;
    final ref = _db.collection('users').doc(uid);
    final doc = await ref.get();
    if (!doc.exists || doc.data() == null) return;

    final data = doc.data()!;
    final skills = _parseSkillsList(data['skills']);
    final levelClamped = level.clamp(0, 100);
    final idx = skills.indexWhere(
      (s) => (s['skillId']?.toString().trim() ?? '') == skillId.trim(),
    );
    final entry = {'skillId': skillId.trim(), 'level': levelClamped};
    if (idx >= 0) {
      skills[idx] = entry;
    } else {
      skills.add(entry);
    }
    await ref.update({'skills': skills, 'profile_completed': true});
    refreshAnalysisResultsForUser(uid).catchError((e, st) {
      debugPrint('refreshAnalysisResultsForUser failed: $e');
      if (kDebugMode) debugPrintStack(stackTrace: st);
    });
  }

  /// Updates an existing skill's level by skillId (0-100).
  Future<void> updateSkillById(String uid, String skillId, int level) async {
    if (uid.isEmpty || skillId.trim().isEmpty) return;
    final ref = _db.collection('users').doc(uid);
    final doc = await ref.get();
    if (!doc.exists || doc.data() == null) return;

    final data = doc.data()!;
    final skills = _parseSkillsList(data['skills']);
    final target = skillId.trim();
    final idx = skills.indexWhere(
      (s) => (s['skillId']?.toString().trim() ?? '') == target,
    );
    if (idx < 0) return;
    skills[idx]['level'] = level.clamp(0, 100);
    await ref.update({'skills': skills, 'profile_completed': true});
    refreshAnalysisResultsForUser(uid).catchError((e, st) {
      debugPrint('refreshAnalysisResultsForUser failed: $e');
      if (kDebugMode) debugPrintStack(stackTrace: st);
    });
  }

  /// Updates an existing skill's level/points by normalized name.
  /// If the skill name exists in the catalog, uses updateSkillById (new format); otherwise legacy.
  Future<void> updateSkill(String uid, String skillName, int points) async {
    if (uid.isEmpty || skillName.trim().isEmpty) return;
    final pointsClamped = points.clamp(0, 100);
    final catalog = await getSkills();
    if (catalog.isNotEmpty) {
      final normalized = normalizeSkillName(skillName);
      for (final s in catalog.values) {
        if (normalizeSkillName(s.name) == normalized) {
          await updateSkillById(uid, s.id, pointsClamped);
          return;
        }
      }
    }
    final ref = _db.collection('users').doc(uid);
    final doc = await ref.get();
    if (!doc.exists || doc.data() == null) return;

    final data = doc.data()!;
    final skills = _parseSkillsList(data['skills']);
    final normalizedTarget = normalizeSkillName(skillName);
    final level = _pointsToLevel(pointsClamped);

    final idx = skills.indexWhere(
      (s) => normalizeSkillName(s['name']?.toString()) == normalizedTarget,
    );
    if (idx < 0) return;

    skills[idx]['level'] = level;
    skills[idx]['points'] = pointsClamped;

    await ref.update({
      'skills': skills.map((s) => s).toList(),
      'profile_completed': true,
    });

    refreshAnalysisResultsForUser(uid).catchError((e, st) {
      debugPrint('refreshAnalysisResultsForUser failed: $e');
      if (kDebugMode) debugPrintStack(stackTrace: st);
    });
  }

  /// Recalculates skill gap match for all job roles and writes a summary to the user's
  /// analysis_results field. Called automatically after addSkill/updateSkill so that
  /// dashboard and learning suggestions stay in sync. Each job's result includes
  /// matchPercentage, weightedMatchPercentage, and missingCount for potential dashboard use.
  Future<void> refreshAnalysisResultsForUser(String uid) async {
    final userDoc = await _db.collection('users').doc(uid).get();
    if (!userDoc.exists || userDoc.data() == null) return;

    final userData = userDoc.data()!;
    final jobs = await getJobsOnce();
    final skillsCatalog = await getSkills();
    final results = <String, Map<String, dynamic>>{};

    for (final job in jobs) {
      final result = await GapAnalysisService.runGapAnalysis(
        userData,
        job,
        fetchRecommendations: getSuggestedCoursesForSkills,
        skillsCatalog: skillsCatalog.isNotEmpty ? skillsCatalog : null,
      );
      results[job.id] = {
        'matchPercentage': result.matchPercentage,
        'weightedMatchPercentage': result.weightedMatchPercentage,
        'missingCount': result.missingSkills.length,
        'matchedCount': result.matchedSkills.length,
      };
    }

    await _db.collection('users').doc(uid).update({
      'analysis_results': results,
    });
  }

  // ---------------------------------------------------------------------------
  // Level-based skill gap: seed skills collection and migrate users/jobs
  // ---------------------------------------------------------------------------

  /// One-time fetch of all user documents (id + data). Used for migration.
  /// Each map has '_uid' (document id) plus all document fields.
  Future<List<Map<String, dynamic>>> getAllUsersOnce() async {
    final snapshot = await _db.collection('users').get();
    return snapshot.docs.map((doc) => {'_uid': doc.id, ...doc.data()}).toList();
  }

  /// Ensures Firestore 'skills' collection exists and is populated from jobs + users.
  /// Each doc: id = skillId (normalized name), fields: { name, category: Technical|Soft }.
  /// Call once to enable level-based gap analysis. Safe to call repeatedly (merges/updates).
  Future<int> seedSkillsCollectionFromJobsAndUsers() async {
    final jobs = await getJobsOnce();
    final users = await getAllUsersOnce();
    final skillEntries = <String, ({String name, String category})>{};

    void add(String displayName, String category) {
      final id = skillNameToSkillId(displayName);
      if (id.isEmpty) return;
      final name = displayName.trim();
      if (name.isEmpty) return;
      if (!skillEntries.containsKey(id) || skillEntries[id]!.name.isEmpty) {
        skillEntries[id] = (name: name, category: category);
      }
    }

    for (final job in jobs) {
      for (final s in job.technicalSkillsWithLevel) {
        if (s.name.trim().isNotEmpty) add(s.name, 'Technical');
      }
      for (final s in job.softSkillsWithLevel) {
        if (s.name.trim().isNotEmpty) add(s.name, 'Soft');
      }
      for (final name in job.requiredSkills) {
        if (name.trim().isNotEmpty) add(name, 'Technical');
      }
    }
    for (final user in users) {
      final raw = user['skills'];
      if (raw is! List) continue;
      for (final s in raw) {
        if (s is String && s.trim().isNotEmpty) add(s, 'Technical');
        if (s is Map) {
          final name = s['name']?.toString().trim();
          final type = s['type']?.toString().trim();
          if (name != null && name.isNotEmpty) {
            add(name, type == 'Soft' ? 'Soft' : 'Technical');
          }
        }
      }
    }

    if (skillEntries.isEmpty) return 0;
    invalidateSkillsCache();
    const batchSize = 500;
    final ids = skillEntries.keys.toList();
    var written = 0;
    for (var i = 0; i < ids.length; i += batchSize) {
      final batch = _db.batch();
      final chunk = ids.skip(i).take(batchSize).toList();
      for (final id in chunk) {
        final e = skillEntries[id]!;
        batch.set(_db.collection('skills').doc(id), {
          'name': e.name,
          'category': e.category,
        });
        written++;
      }
      await batch.commit();
    }
    return written;
  }

  /// Migrates user skills from legacy { name, level/points } to { skillId, level } using catalog.
  /// Skips users that already have only new-format skills. Run after seedSkillsCollectionFromJobsAndUsers.
  Future<int> migrateAllUsersToNewSkillsFormat() async {
    final catalog = await getSkills();
    if (catalog.isEmpty) return 0;
    final nameToId = <String, String>{};
    for (final s in catalog.values) {
      nameToId[normalizeSkillName(s.name)] = s.id;
    }
    final users = await getAllUsersOnce();
    var migrated = 0;
    for (final user in users) {
      final uid = user['_uid'] as String?;
      if (uid == null) continue;
      final raw = user['skills'];
      if (raw == null || raw is! List || raw.isEmpty) continue;
      final hasLegacy = raw.any(
        (s) => s is Map && s.containsKey('name') && !s.containsKey('skillId'),
      );
      if (!hasLegacy) continue;
      final newSkills = <Map<String, dynamic>>[];
      final seenIds = <String>{};
      for (final s in raw) {
        final us = UserSkill.fromFirestore(s);
        if (us != null) {
          if (seenIds.add(us.skillId)) newSkills.add(us.toFirestore());
          continue;
        }
        if (s is! Map) continue;
        final m = Map<String, dynamic>.from(
          s.map((k, v) => MapEntry(k.toString(), v)),
        );
        final name = m['name']?.toString().trim();
        if (name == null || name.isEmpty) continue;
        int level = 0;
        if (m['level'] is int) {
          level = (m['level'] as int).clamp(0, 100);
        } else if (m['points'] is int) {
          level = (m['points'] as int).clamp(0, 100);
        } else {
          final str = m['level']?.toString().trim().toLowerCase() ?? '';
          if (str == 'advanced') {
            level = 95;
          } else if (str == 'intermediate')
            level = 65;
          else if (str == 'basic')
            level = 35;
          else
            level = (int.tryParse(str) ?? 35).clamp(0, 100);
        }
        final skillId = nameToId[normalizeSkillName(name)];
        if (skillId != null && seenIds.add(skillId)) {
          newSkills.add({'skillId': skillId, 'level': level});
        }
      }
      if (newSkills.isEmpty) continue;
      await _db.collection('users').doc(uid).update({'skills': newSkills});
      migrated++;
    }
    return migrated;
  }

  /// Migrates jobs to requiredSkillsWithLevel from technicalSkillsWithLevel + softSkillsWithLevel using catalog.
  /// Skips jobs that already have requiredSkillsWithLevel. Run after seedSkillsCollectionFromJobsAndUsers.
  Future<int> migrateAllJobsToRequiredSkillsWithLevel() async {
    final catalog = await getSkills();
    if (catalog.isEmpty) return 0;
    final nameToId = <String, String>{};
    for (final s in catalog.values) {
      nameToId[normalizeSkillName(s.name)] = s.id;
    }
    final jobs = await getJobsOnce();
    Set<String> criticalNormalized(List<String> names) =>
        names.map((n) => normalizeSkillName(n)).toSet();
    var migrated = 0;
    for (final job in jobs) {
      if (job.requiredSkillsWithLevel.isNotEmpty) continue;
      final critical = criticalNormalized(job.criticalSkills);
      final list = <JobRequiredSkill>[];
      for (final s in job.technicalSkillsWithLevel) {
        final id = nameToId[normalizeSkillName(s.name)];
        if (id != null) {
          list.add(
            JobRequiredSkill(
              skillId: id,
              requiredLevel: s.percent.clamp(0, 100),
              importance: critical.contains(normalizeSkillName(s.name)) ? 3 : 2,
            ),
          );
        }
      }
      for (final s in job.softSkillsWithLevel) {
        final id = nameToId[normalizeSkillName(s.name)];
        if (id != null) {
          list.add(
            JobRequiredSkill(
              skillId: id,
              requiredLevel: s.percent.clamp(0, 100),
              importance: critical.contains(normalizeSkillName(s.name)) ? 3 : 2,
            ),
          );
        }
      }
      if (list.isEmpty) {
        for (final name in job.requiredSkills) {
          final id = nameToId[normalizeSkillName(name)];
          if (id != null) {
            list.add(
              JobRequiredSkill(skillId: id, requiredLevel: 70, importance: 2),
            );
          }
        }
      }
      if (list.isEmpty) continue;
      final updated = JobRole(
        id: job.id,
        title: job.title,
        description: job.description,
        category: job.category,
        isHighDemand: job.isHighDemand,
        salaryMinK: job.salaryMinK,
        salaryMaxK: job.salaryMaxK,
        requiredSkills: job.requiredSkills,
        requiredSkillsWithLevel: list,
        technicalSkillsWithLevel: job.technicalSkillsWithLevel,
        softSkillsWithLevel: job.softSkillsWithLevel,
        criticalSkills: job.criticalSkills,
      );
      await updateJob(updated);
      migrated++;
    }
    return migrated;
  }

  /// Runs full level-based setup: seed skills, migrate jobs, optionally migrate users.
  /// Returns counts { skillsWritten, jobsMigrated, usersMigrated }.
  Future<Map<String, int>> runLevelBasedSetup({
    bool migrateUsers = true,
  }) async {
    final skillsWritten = await seedSkillsCollectionFromJobsAndUsers();
    final jobsMigrated = await migrateAllJobsToRequiredSkillsWithLevel();
    final usersMigrated = migrateUsers
        ? await migrateAllUsersToNewSkillsFormat()
        : 0;
    return {
      'skillsWritten': skillsWritten,
      'jobsMigrated': jobsMigrated,
      'usersMigrated': usersMigrated,
    };
  }

  /// Market insights aggregated across users (for Admin dashboard). Stub: override with real aggregation.
  Future<MarketInsights> getMarketInsights() async {
    return const MarketInsights();
  }

  /// Upload default jobs (1-8) + additional jobs (9-20) to Firestore. Run once to seed data.
  Future<void> uploadJobs() async {
    final jobs = [..._defaultJobs, ..._additionalJobs];
    final batch = _db.batch();
    for (var i = 0; i < jobs.length; i++) {
      final ref = _db.collection('jobs').doc('job_${i + 1}');
      batch.set(ref, jobs[i].toFirestore());
    }
    await batch.commit();
  }

  /// Jobs 9–20: diverse roles (Tech, Healthcare, Engineering, Finance, etc.)
  static List<JobRole> get _additionalJobs => [
    const JobRole(
      id: '9',
      title: 'AI Engineer',
      description: 'Develops and trains complex neural networks and AI models.',
      category: 'Technology',
      salaryMinK: 110,
      salaryMaxK: 180,
      requiredSkills: [
        'Python',
        'PyTorch',
        'Machine Learning',
        'Natural Language Processing',
        'Deep Learning',
        'TensorFlow',
        'Data Modeling',
        'Research',
      ],
    ),
    const JobRole(
      id: '10',
      title: 'Cybersecurity Analyst',
      description:
          'Protects networks and data from cyber attacks and unauthorized access.',
      category: 'Security',
      salaryMinK: 75,
      salaryMaxK: 120,
      requiredSkills: [
        'Network Security',
        'Ethical Hacking',
        'Linux',
        'SIEM tools',
        'Incident Response',
        'Risk Assessment',
        'Cryptography',
        'Communication',
      ],
    ),
    const JobRole(
      id: '11',
      title: 'Full-Stack Developer',
      description:
          'Builds both the front-end and back-end of web applications.',
      category: 'Software Development',
      salaryMinK: 70,
      salaryMaxK: 130,
      requiredSkills: [
        'React.js',
        'Node.js',
        'PostgreSQL',
        'Docker',
        'REST APIs',
        'Git',
        'HTML/CSS',
        'JavaScript',
      ],
    ),
    const JobRole(
      id: '12',
      title: 'Registered Nurse',
      description:
          'Provides patient care, administers medications, and coordinates with doctors.',
      category: 'Healthcare',
      salaryMinK: 55,
      salaryMaxK: 85,
      requiredSkills: [
        'Patient Assessment',
        'Critical Thinking',
        'BLS/ACLS',
        'Clinical Documentation',
        'Medication Administration',
        'Communication',
        'Empathy',
        'Teamwork',
      ],
    ),
    const JobRole(
      id: '13',
      title: 'Pharmacist',
      description:
          'Dispenses medications and provides expertise on safe medicine use.',
      category: 'Healthcare',
      salaryMinK: 100,
      salaryMaxK: 140,
      requiredSkills: [
        'Pharmacology',
        'Clinical Pharmacy',
        'Communication',
        'Drug Interactions',
        'Patient Counseling',
        'Regulatory Compliance',
        'Attention to Detail',
        'Ethics',
      ],
    ),
    const JobRole(
      id: '14',
      title: 'Renewable Energy Engineer',
      description:
          'Designs and implements sustainable energy systems like solar and wind power.',
      category: 'Engineering',
      salaryMinK: 70,
      salaryMaxK: 110,
      requiredSkills: [
        'Solar PV Design',
        'Thermodynamics',
        'Energy Modeling',
        'Project Management',
        'CAD',
        'Sustainability',
        'Electrical Systems',
        'Data Analysis',
      ],
    ),
    const JobRole(
      id: '15',
      title: 'Civil Engineer',
      description:
          'Oversees the design and construction of infrastructure projects like bridges and roads.',
      category: 'Engineering',
      salaryMinK: 65,
      salaryMaxK: 105,
      requiredSkills: [
        'AutoCAD',
        'Structural Design',
        'Project Management',
        'Soil Mechanics',
        'Construction Management',
        'CAD/Revit',
        'Communication',
        'Problem Solving',
      ],
    ),
    const JobRole(
      id: '16',
      title: 'Financial Analyst',
      description:
          'Analyzes financial data to help businesses make investment decisions.',
      category: 'Finance',
      salaryMinK: 60,
      salaryMaxK: 95,
      requiredSkills: [
        'Financial Modeling',
        'Excel (Advanced)',
        'Data Analysis',
        'Valuation',
        'Accounting',
        'Reporting',
        'Communication',
        'Attention to Detail',
      ],
    ),
    const JobRole(
      id: '17',
      title: 'Digital Marketing Manager',
      description:
          'Leads online marketing campaigns across social media and search engines.',
      category: 'Business',
      salaryMinK: 65,
      salaryMaxK: 110,
      requiredSkills: [
        'SEO',
        'Content Strategy',
        'Google Analytics',
        'Copywriting',
        'Social Media Marketing',
        'PPC',
        'Campaign Management',
        'Data-Driven Decision Making',
      ],
    ),
    const JobRole(
      id: '18',
      title: 'HR Specialist',
      description:
          'Manages recruitment, employee relations, and company benefits.',
      category: 'Management',
      salaryMinK: 50,
      salaryMaxK: 85,
      requiredSkills: [
        'Talent Acquisition',
        'Labor Law',
        'Conflict Resolution',
        'Recruitment',
        'Employee Relations',
        'HRIS',
        'Communication',
        'Organizational Skills',
      ],
    ),
    const JobRole(
      id: '19',
      title: 'Video Editor / Motion Designer',
      description:
          'Creates engaging video content and animations for brands and social media.',
      category: 'Media',
      salaryMinK: 45,
      salaryMaxK: 85,
      requiredSkills: [
        'Adobe Premiere Pro',
        'After Effects',
        'DaVinci Resolve',
        'Motion Graphics',
        'Color Grading',
        'Storytelling',
        'Creativity',
        'Time Management',
      ],
    ),
    const JobRole(
      id: '20',
      title: 'Biotechnologist',
      description:
          'Uses biological organisms to develop products in medicine and agriculture.',
      category: 'Science',
      salaryMinK: 55,
      salaryMaxK: 95,
      requiredSkills: [
        'Molecular Biology',
        'Lab Analysis',
        'Bioinformatics',
        'PCR',
        'Cell Culture',
        'Data Analysis',
        'Research',
        'Documentation',
      ],
    ),
    const JobRole(
      id: '21',
      title: 'Sustainability Consultant',
      description:
          'Advises companies on how to reduce their environmental impact and carbon footprint.',
      category: 'Environment',
      salaryMinK: 60,
      salaryMaxK: 100,
      requiredSkills: [
        'Carbon Accounting',
        'ESG Reporting',
        'Environmental Science',
        'Sustainability Strategy',
        'Stakeholder Engagement',
        'Data Analysis',
        'Communication',
        'Project Management',
      ],
    ),
    const JobRole(
      id: '22',
      title: 'E-commerce Manager',
      description:
          'Oversees online sales platforms and optimizes the digital shopping journey.',
      category: 'Business',
      salaryMinK: 55,
      salaryMaxK: 95,
      requiredSkills: [
        'Shopify',
        'Inventory Management',
        'Digital Ads',
        'Logistics',
        'Conversion Optimization',
        'Analytics',
        'Customer Experience',
        'Budget Management',
      ],
    ),
    const JobRole(
      id: '23',
      title: 'Product Manager (Tech)',
      description:
          'Bridges the gap between business, design, and tech to launch successful products.',
      category: 'Management',
      salaryMinK: 95,
      salaryMaxK: 150,
      requiredSkills: [
        'Agile Methodology',
        'Strategic Planning',
        'Roadmap Tools',
        'User Research',
        'Stakeholder Management',
        'Data-Driven Decisions',
        'Communication',
        'Prioritization',
      ],
    ),
    const JobRole(
      id: '24',
      title: 'Cloud Architect',
      description:
          'Designs and manages complex cloud computing strategies and infrastructure.',
      category: 'Cloud Computing',
      salaryMinK: 120,
      salaryMaxK: 180,
      requiredSkills: [
        'AWS',
        'Azure',
        'Google Cloud',
        'Terraform',
        'Kubernetes',
        'System Design',
        'Security',
        'Cost Optimization',
      ],
    ),
    const JobRole(
      id: '25',
      title: 'Blockchain Developer',
      description:
          'Develops decentralized applications and smart contracts using blockchain tech.',
      category: 'Web3',
      salaryMinK: 100,
      salaryMaxK: 170,
      requiredSkills: [
        'Solidity',
        'Cryptography',
        'Ethereum',
        'Rust',
        'Smart Contracts',
        'Web3.js',
        'Problem Solving',
        'Security',
      ],
    ),
    const JobRole(
      id: '26',
      title: 'Instructional Designer',
      description:
          'Creates educational curricula and digital learning materials for schools and companies.',
      category: 'Education',
      salaryMinK: 50,
      salaryMaxK: 85,
      requiredSkills: [
        'Learning Management Systems (LMS)',
        'Curriculum Design',
        'E-learning',
        'Instructional Design Models',
        'Assessment',
        'Multimedia',
        'Communication',
        'Project Management',
      ],
    ),
    // Aviation & Travel
    const JobRole(
      id: '27',
      title: 'Commercial Pilot',
      description:
          'Operates commercial aircraft for airlines, ensuring passenger safety and navigation.',
      category: 'Aviation',
      salaryMinK: 80,
      salaryMaxK: 200,
      requiredSkills: [
        'Aircraft Navigation',
        'Flight Safety',
        'Communication',
        'Crisis Management',
        'Decision Making',
        'Spatial Awareness',
        'Teamwork',
        'Regulatory Compliance',
      ],
    ),
    const JobRole(
      id: '28',
      title: 'Travel Consultant',
      description:
          'Plans and sells transportation and accommodations for travel agencies.',
      category: 'Tourism',
      salaryMinK: 35,
      salaryMaxK: 55,
      requiredSkills: [
        'Destination Knowledge',
        'Customer Service',
        'Booking Systems',
        'Sales',
        'Communication',
        'Multitasking',
        'Geography',
        'Cultural Awareness',
      ],
    ),
    // Legal & Public Services
    const JobRole(
      id: '29',
      title: 'Corporate Lawyer',
      description:
          'Advises businesses on legal rights, obligations, and complex transactions.',
      category: 'Legal',
      salaryMinK: 90,
      salaryMaxK: 180,
      requiredSkills: [
        'Contract Law',
        'Negotiation',
        'Legal Research',
        'Compliance',
        'Analytical Thinking',
        'Communication',
        'Document Drafting',
        'Ethics',
      ],
    ),
    const JobRole(
      id: '30',
      title: 'Firefighter / Paramedic',
      description:
          'Responds to emergencies, fires, and provides medical care in the field.',
      category: 'Public Service',
      salaryMinK: 45,
      salaryMaxK: 75,
      requiredSkills: [
        'Emergency Response',
        'Physical Fitness',
        'First Aid',
        'Fire Suppression',
        'CPR',
        'Crisis Management',
        'Teamwork',
        'Communication',
      ],
    ),
    // Arts, Fashion & Entertainment
    const JobRole(
      id: '31',
      title: 'Fashion Designer',
      description: 'Creates original clothing, accessories, and footwear.',
      category: 'Arts',
      salaryMinK: 45,
      salaryMaxK: 120,
      requiredSkills: [
        'Textile Knowledge',
        'Sketching',
        'Sewing',
        'Fashion Trends',
        'Creativity',
        'Color Theory',
        'Pattern Making',
        'Presentation',
      ],
    ),
    const JobRole(
      id: '32',
      title: 'Sound Engineer',
      description:
          'Operates equipment to record, mix, and reproduce sound for music and film.',
      category: 'Entertainment',
      salaryMinK: 40,
      salaryMaxK: 85,
      requiredSkills: [
        'Audio Mixing',
        'Digital Audio Workstations (DAW)',
        'Acoustics',
        'Recording',
        'Editing',
        'Signal Flow',
        'Ear Training',
        'Collaboration',
      ],
    ),
    // Agriculture & Food Science
    const JobRole(
      id: '33',
      title: 'Agricultural Scientist',
      description:
          'Researches ways to improve the efficiency and safety of agricultural crops and animals.',
      category: 'Agriculture',
      salaryMinK: 55,
      salaryMaxK: 95,
      requiredSkills: [
        'Soil Science',
        'Biology',
        'Research Methods',
        'Data Collection',
        'Statistics',
        'Sustainability',
        'Lab Techniques',
        'Report Writing',
      ],
    ),
    const JobRole(
      id: '34',
      title: 'Executive Chef',
      description:
          'Oversees the kitchen operations, menu planning, and staff management in restaurants.',
      category: 'Food Industry',
      salaryMinK: 50,
      salaryMaxK: 95,
      requiredSkills: [
        'Culinary Arts',
        'Menu Engineering',
        'Food Safety',
        'Leadership',
        'Inventory Management',
        'Creativity',
        'Team Management',
        'Cost Control',
      ],
    ),
    // Fitness & Sports
    const JobRole(
      id: '35',
      title: 'Personal Trainer',
      description:
          'Designs and implements fitness programs for individuals based on their goals.',
      category: 'Fitness',
      salaryMinK: 35,
      salaryMaxK: 65,
      requiredSkills: [
        'Anatomy',
        'Nutrition Coaching',
        'Exercise Programming',
        'Motivation',
        'Communication',
        'Client Assessment',
        'Injury Prevention',
        'Goal Setting',
      ],
    ),
    const JobRole(
      id: '36',
      title: 'Sports Agent',
      description:
          'Represents professional athletes and handles their contracts and endorsements.',
      category: 'Sports Management',
      salaryMinK: 60,
      salaryMaxK: 150,
      requiredSkills: [
        'Contract Negotiation',
        'Marketing',
        'Public Relations',
        'Law',
        'Networking',
        'Communication',
        'Financial Planning',
        'Industry Knowledge',
      ],
    ),
    // Logistics
    const JobRole(
      id: '37',
      title: 'Logistics Manager',
      description:
          'Coordinates the movement and storage of goods in a supply chain.',
      category: 'Logistics',
      salaryMinK: 60,
      salaryMaxK: 100,
      requiredSkills: [
        'Inventory Management',
        'Transportation Planning',
        'Analytics',
        'Supply Chain',
        'Vendor Management',
        'Problem Solving',
        'Communication',
        'ERP Systems',
      ],
    ),
    // Space & Future Tech
    const JobRole(
      id: '38',
      title: 'Aerospace Engineer',
      description: 'Designs and tests satellites, spacecraft, and missiles.',
      category: 'Space & Tech',
      salaryMinK: 85,
      salaryMaxK: 140,
      requiredSkills: [
        'Aerodynamics',
        'Propulsion',
        'Physics',
        'CAD Software',
        'Systems Engineering',
        'Simulation',
        'Problem Solving',
        'Documentation',
      ],
    ),
    const JobRole(
      id: '39',
      title: 'Robotics Technician',
      description:
          'Builds, installs, and maintains robotic systems for manufacturing.',
      category: 'Robotics',
      salaryMinK: 50,
      salaryMaxK: 85,
      requiredSkills: [
        'Electronics',
        'C++',
        'Hydraulics',
        'Troubleshooting',
        'PLC',
        'Mechanical Systems',
        'Safety Protocols',
        'Documentation',
      ],
    ),
    // Media, Arts & Design
    const JobRole(
      id: '40',
      title: 'Journalist / News Reporter',
      description:
          'Investigates and reports on current events for news organizations.',
      category: 'Media',
      salaryMinK: 40,
      salaryMaxK: 75,
      requiredSkills: [
        'News Writing',
        'Interviewing',
        'Ethics',
        'Investigative Research',
        'Communication',
        'Deadline Management',
        'Fact-Checking',
        'Multimedia',
      ],
    ),
    const JobRole(
      id: '41',
      title: 'Interior Designer',
      description:
          'Makes indoor spaces functional, safe, and beautiful through layout and decor.',
      category: 'Design',
      salaryMinK: 45,
      salaryMaxK: 85,
      requiredSkills: [
        'Space Planning',
        'Lighting Design',
        'Revit',
        'Material Science',
        'Color Theory',
        'Client Communication',
        'Budgeting',
        'Building Codes',
      ],
    ),
    const JobRole(
      id: '42',
      title: 'Voice Actor',
      description:
          'Provides voices for animations, commercials, and audiobooks.',
      category: 'Entertainment',
      salaryMinK: 35,
      salaryMaxK: 90,
      requiredSkills: [
        'Voice Modulation',
        'Script Reading',
        'Audio Recording',
        'Dialects',
        'Character Acting',
        'Breath Control',
        'Interpretation',
        'Studio Etiquette',
      ],
    ),
    // Nature & Environment
    const JobRole(
      id: '43',
      title: 'Marine Biologist',
      description:
          'Studies ocean organisms and their interactions with the environment.',
      category: 'Environment',
      salaryMinK: 50,
      salaryMaxK: 90,
      requiredSkills: [
        'Marine Ecology',
        'Scuba Diving',
        'Data Analysis',
        'Lab Research',
        'Field Work',
        'Scientific Writing',
        'Conservation',
        'Statistics',
      ],
    ),
    const JobRole(
      id: '44',
      title: 'Urban Planner',
      description: 'Develops plans and programs for the use of land in cities.',
      category: 'Construction',
      salaryMinK: 55,
      salaryMaxK: 95,
      requiredSkills: [
        'GIS Mapping',
        'Public Policy',
        'Sustainability',
        'Zoning Laws',
        'Community Engagement',
        'Data Analysis',
        'Presentation',
        'Project Management',
      ],
    ),
    // Psychology & Social
    const JobRole(
      id: '45',
      title: 'Mental Health Counselor',
      description:
          'Helps people manage and overcome mental and emotional disorders.',
      category: 'Healthcare',
      salaryMinK: 45,
      salaryMaxK: 75,
      requiredSkills: [
        'Empathy',
        'Crisis Intervention',
        'Psychology',
        'Case Management',
        'Active Listening',
        'Ethics',
        'Documentation',
        'Cultural Sensitivity',
      ],
    ),
    const JobRole(
      id: '46',
      title: 'Social Media Influencer Manager',
      description:
          'Manages partnerships between brands and social media creators.',
      category: 'Marketing',
      salaryMinK: 45,
      salaryMaxK: 85,
      requiredSkills: [
        'Influencer Marketing',
        'Contract Management',
        'Trend Analysis',
        'Campaign Planning',
        'Communication',
        'Analytics',
        'Negotiation',
        'Brand Awareness',
      ],
    ),
    // Industry & Logistics
    const JobRole(
      id: '47',
      title: 'Quality Control Inspector',
      description:
          'Ensures products meet quality standards before they reach customers.',
      category: 'Manufacturing',
      salaryMinK: 40,
      salaryMaxK: 65,
      requiredSkills: [
        'Inspection Techniques',
        'Precision Measuring',
        'ISO Standards',
        'Documentation',
        'Attention to Detail',
        'Statistical Process Control',
        'Communication',
        'Problem Solving',
      ],
    ),
    const JobRole(
      id: '48',
      title: 'Warehouse Manager',
      description:
          'Oversees daily operations of a warehouse, including shipping and receiving.',
      category: 'Logistics',
      salaryMinK: 50,
      salaryMaxK: 85,
      requiredSkills: [
        'Logistics',
        'Team Leadership',
        'Safety Compliance',
        'Inventory Software',
        'Shipping & Receiving',
        'Space Optimization',
        'Vendor Coordination',
        'Reporting',
      ],
    ),
  ];

  static List<JobRole> get _defaultJobs => [
    const JobRole(
      id: '1',
      title: 'Data Analyst',
      description: 'Analyze data to help organizations make better decisions',
      category: 'Data & Analytics',
      salaryMinK: 65,
      salaryMaxK: 95,
      requiredSkills: [
        'SQL',
        'Excel',
        'Python',
        'Tableau',
        'Statistics',
        'Data Visualization',
        'Problem Solving',
        'Communication',
      ],
      technicalSkillsWithLevel: [
        SkillProficiency(name: 'Data Analysis', percent: 85),
        SkillProficiency(name: 'Programming', percent: 65),
        SkillProficiency(name: 'Database Management', percent: 75),
        SkillProficiency(name: 'Business Analysis', percent: 70),
      ],
      softSkillsWithLevel: [
        SkillProficiency(name: 'Problem Solving', percent: 80),
        SkillProficiency(name: 'Communication', percent: 75),
        SkillProficiency(name: 'Critical Thinking', percent: 85),
        SkillProficiency(name: 'Attention to Detail', percent: 80),
      ],
      criticalSkills: [
        'Data Analysis',
        'Problem Solving',
        'Critical Thinking',
        'Attention to Detail',
      ],
    ),
    const JobRole(
      id: '2',
      title: 'Data Scientist',
      description:
          'Use advanced analytics and machine learning to extract insights',
      category: 'Data & Analytics',
      salaryMinK: 95,
      salaryMaxK: 140,
      requiredSkills: [
        'Python',
        'R',
        'Machine Learning',
        'SQL',
        'Statistics',
        'Deep Learning',
        'Data Wrangling',
        'A/B Testing',
        'Communication',
        'Storytelling',
      ],
    ),
    const JobRole(
      id: '3',
      title: 'Business Intelligence Analyst',
      description: 'Transform data into actionable business insights',
      category: 'Data & Analytics',
      salaryMinK: 70,
      salaryMaxK: 100,
      requiredSkills: [
        'SQL',
        'Power BI',
        'Tableau',
        'Excel',
        'Data Modeling',
        'ETL',
        'Dashboard Design',
        'Communication',
      ],
    ),
    const JobRole(
      id: '4',
      title: 'Marketing Analyst',
      description: 'Analyze marketing data and consumer behavior',
      category: 'Marketing',
      salaryMinK: 55,
      salaryMaxK: 85,
      requiredSkills: [
        'Excel',
        'Google Analytics',
        'SQL',
        'Data Visualization',
        'A/B Testing',
        'SEO',
        'Communication',
        'Reporting',
      ],
    ),
    const JobRole(
      id: '5',
      title: 'Software Engineer',
      description: 'Design, develop and maintain software applications',
      category: 'Engineering',
      salaryMinK: 80,
      salaryMaxK: 130,
      requiredSkills: [
        'Programming',
        'Data Structures',
        'Algorithms',
        'Version Control',
        'Testing',
        'System Design',
        'Problem Solving',
        'Collaboration',
      ],
    ),
    const JobRole(
      id: '6',
      title: 'Product Manager',
      description:
          'Define product strategy and work with engineering to deliver value',
      category: 'Product',
      salaryMinK: 90,
      salaryMaxK: 140,
      requiredSkills: [
        'Product Strategy',
        'User Research',
        'Agile',
        'Stakeholder Management',
        'Analytics',
        'Communication',
        'Prioritization',
        'Roadmapping',
      ],
    ),
    const JobRole(
      id: '7',
      title: 'UX Designer',
      description: 'Create user-centered designs for digital products',
      category: 'Design',
      salaryMinK: 70,
      salaryMaxK: 110,
      requiredSkills: [
        'Wireframing',
        'Prototyping',
        'User Research',
        'UI Design',
        'Figma',
        'Usability Testing',
        'Communication',
        'Collaboration',
      ],
    ),
    const JobRole(
      id: '8',
      title: 'DevOps Engineer',
      description: 'Automate and optimize development and deployment pipelines',
      category: 'Engineering',
      salaryMinK: 85,
      salaryMaxK: 135,
      requiredSkills: [
        'Linux',
        'CI/CD',
        'Docker',
        'Kubernetes',
        'Cloud (AWS/GCP)',
        'Scripting',
        'Monitoring',
        'Security',
      ],
    ),
  ];

  /// إضافة أو تحديث بيانات المستخدم
  Future<void> addUser({required String name, required int age}) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception("No user logged in");
    }

    await _db.collection('users').doc(user.uid).set({
      'name': name,
      'age': age,
      'createdAt': Timestamp.now(),
    });
  }

  /// جلب بيانات المستخدم
  Future<Map<String, dynamic>?> getUserData() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return null;

    final doc = await _db.collection('users').doc(user.uid).get();

    return doc.exists ? doc.data() : null;
  }

  /// تحديث بيانات المستخدم
  Future<void> updateUserData(Map<String, dynamic> data) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception("No user logged in");
    }

    await _db.collection('users').doc(user.uid).update(data);
  }

  // --- Home: Insights & Market Trends (real-time streams) ---

  /// Real-time stream of insights (skill progress bars). Order by [order] field.
  Stream<List<InsightModel>> streamInsights() {
    return _db
        .collection('insights')
        .orderBy('order')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => InsightModel.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }

  /// Real-time stream of market trends (growth cards). Order by [order] field.
  Stream<List<TrendModel>> streamMarketTrends() {
    return _db
        .collection('market_trends')
        .orderBy('order')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => TrendModel.fromFirestore(doc.id, doc.data()))
              .toList(),
        );
  }

  /// One-time fetch of home data (insights + market trends). Use streams for live updates.
  Future<({List<InsightModel> insights, List<TrendModel> trends})>
  fetchHomeData() async {
    final insightsSnap = await _db
        .collection('insights')
        .orderBy('order')
        .get();
    final trendsSnap = await _db
        .collection('market_trends')
        .orderBy('order')
        .get();
    return (
      insights: insightsSnap.docs
          .map((doc) => InsightModel.fromFirestore(doc.id, doc.data()))
          .toList(),
      trends: trendsSnap.docs
          .map((doc) => TrendModel.fromFirestore(doc.id, doc.data()))
          .toList(),
    );
  }

  /// Upload initial data for Latest Insights and Job Market Trends only if collections are empty.
  /// Safe to call on app start (e.g. in debug): won't overwrite existing data.
  /// Field names match [InsightModel.fromFirestore]: skill_name, percentage (+ order for sort).
  /// Field names match [TrendModel.fromFirestore]: title, growth_percentage, icon_name, subtitle (+ order for sort).
  Future<void> uploadHomeMockDataIfEmpty() async {
    final insightsSnap = await _db.collection('insights').limit(1).get();
    if (insightsSnap.docs.isNotEmpty) return;

    final batch = _db.batch();

    // insights: fields used by InsightModel.fromFirestore — skill_name, percentage
    final insights = [
      {'skill_name': 'Python', 'percentage': 95, 'order': 0},
      {'skill_name': 'Data Analysis', 'percentage': 88, 'order': 1},
      {'skill_name': 'Cloud Computing', 'percentage': 82, 'order': 2},
      {'skill_name': 'Machine Learning', 'percentage': 78, 'order': 3},
    ];
    for (var i = 0; i < insights.length; i++) {
      final ref = _db.collection('insights').doc('insight_${i + 1}');
      batch.set(ref, insights[i]);
    }

    // market_trends: fields used by TrendModel.fromFirestore — title, growth_percentage, icon_name, subtitle
    final trends = [
      {
        'title': 'AI/ML Jobs',
        'growth_percentage': 45,
        'icon_name': 'trending_up',
        'order': 0,
      },
      {
        'title': 'Cybersecurity',
        'growth_percentage': 0,
        'icon_name': 'security',
        'subtitle': 'High demand, 350K+ openings',
        'order': 1,
      },
      {
        'title': 'Remote Work',
        'growth_percentage': 65,
        'icon_name': 'home_work',
        'subtitle': '65% of tech jobs now remote-friendly',
        'order': 2,
      },
    ];
    for (var i = 0; i < trends.length; i++) {
      final ref = _db.collection('market_trends').doc('trend_${i + 1}');
      batch.set(ref, trends[i]);
    }

    await batch.commit();
  }
}
