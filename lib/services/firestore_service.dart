import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/course.dart';
import '../models/insight_model.dart';
import '../models/job_document.dart';
import '../models/job_role.dart';
import '../models/skill.dart';
import '../models/skill_document.dart';
import '../models/trend_model.dart';
import '../data/seed_jobs_data.dart';
import '../utils/skill_utils.dart';
import 'analysis_refresh_scheduler.dart';
import 'cached_data_service.dart';
import 'gap_analysis_service.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Map<String, Skill>? _skillsCache;
  static DateTime? _skillsCacheTime;
  static const Duration _skillsCacheTtl = Duration(minutes: 5);

  /// Stream of all jobs from Firestore 'jobs' collection.
  /// Supports both new (JobDocument) and legacy (JobRole) format; returns JobRole for app compatibility.
  Stream<List<JobRole>> getJobs() {
    return _db.collection('jobs').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        if (JobDocument.isNewFormat(data)) {
          return JobDocument.fromFirestore(doc.id, data).toJobRole();
        }
        return JobRole.fromFirestore(doc.id, data);
      }).toList();
    });
  }

  /// One-time fetch of all jobs. Used when recalculating gap analysis for all roles after skill updates.
  /// Cached in memory for [CachedDataService.ttl] to avoid hammering Firestore during analysis refreshes.
  Future<List<JobRole>> getJobsOnce() async {
    return CachedDataService.getCached<List<JobRole>>(
      CachedDataService.keyJobsOnce,
      () async {
        final snapshot = await _db.collection('jobs').get();
        return snapshot.docs.map((doc) {
          final data = doc.data();
          if (JobDocument.isNewFormat(data)) {
            return JobDocument.fromFirestore(doc.id, data).toJobRole();
          }
          return JobRole.fromFirestore(doc.id, data);
        }).toList();
      },
    );
  }

  static void _invalidateJobsCache() {
    CachedDataService.invalidate(CachedDataService.keyJobsOnce);
  }

  String _defaultCategoryForGroup(String group) {
    if (group == 'softSkills') return 'Soft';
    if (group == 'tools') return 'Tool';
    return 'Technical';
  }

  String _jobIdentityKey(String title, String category) =>
      canonicalJobId(title, category);

  Future<String?> _findExistingJobIdByIdentity(
    String title,
    String category, {
    String? excludeDocId,
  }) async {
    final key = _jobIdentityKey(title, category);
    if (key.isEmpty) return null;
    final snapshot = await _db.collection('jobs').get();
    for (final doc in snapshot.docs) {
      if (excludeDocId != null && excludeDocId.isNotEmpty && doc.id == excludeDocId) {
        continue;
      }
      final data = doc.data();
      final docTitle = data['title']?.toString().trim() ?? '';
      final docCategory = data['category']?.toString().trim() ?? '';
      if (_jobIdentityKey(docTitle, docCategory) == key) {
        return doc.id;
      }
    }
    return null;
  }

  String? _matchSkillIdFromCatalog(
    String rawName,
    Map<String, Skill> catalog,
  ) {
    final canonicalNameId = canonicalSkillId(rawName);
    if (canonicalNameId.isNotEmpty && catalog.containsKey(canonicalNameId)) {
      return canonicalNameId;
    }
    final normalized = normalizeSkillName(rawName);
    final aliasKey = normalizeSkillAliasKey(rawName);
    for (final s in catalog.values) {
      if (canonicalSkillId(s.id) == canonicalNameId) return s.id;
      if (normalizeSkillName(s.name) == normalized) return s.id;
      for (final alias in s.aliases) {
        if (normalizeSkillName(alias) == normalized ||
            normalizeSkillAliasKey(alias) == aliasKey) {
          return s.id;
        }
      }
      if (normalizeSkillAliasKey(s.name) == aliasKey) {
        return s.id;
      }
    }
    return null;
  }

  /// Public lookup for UI/forms/imports: resolve by canonical id, name, or alias.
  Future<Skill?> getSkillByNameOrAlias(String value) async {
    final q = value.trim();
    if (q.isEmpty) return null;
    final catalog = await getSkills();
    final id = _matchSkillIdFromCatalog(q, catalog);
    if (id == null || id.isEmpty) return null;
    return catalog[canonicalSkillId(id)] ?? catalog[id];
  }

  Future<String> resolveOrCreateSkillId(
    String rawName, {
    String defaultCategory = 'Technical',
    bool createIfMissing = true,
    bool isVerified = false,
  }) async {
    final name = rawName.trim();
    if (name.isEmpty) return '';
    final catalog = await getSkills();
    final existingId = _matchSkillIdFromCatalog(name, catalog);
    if (existingId != null && existingId.isNotEmpty) {
      return canonicalSkillId(existingId);
    }
    final generatedId = skillNameToSkillId(name);
    if (!createIfMissing || generatedId.isEmpty) {
      return generatedId;
    }
    await _db.collection('skills').doc(generatedId).set({
      'skillId': generatedId,
      'skillName': name,
      'name': name,
      'aliases': [name],
      'category': defaultCategory,
      'type': defaultCategory,
      'isVerified': isVerified,
      'relatedSkills': <String>[],
      'domain': defaultCategory,
      'demandLevel': 'Medium',
      'totalJobsUsingSkill': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    invalidateSkillsCache();
    return generatedId;
  }

  Future<List<JobSkillItem>> _normalizeJobSkills(
    List<JobSkillItem> input, {
    required String groupKey,
  }) async {
    if (input.isEmpty) return input;
    final defaultCategory = _defaultCategoryForGroup(groupKey);
    return input.map((item) {
      return JobSkillItem(
        skillId: item.skillId,
        name: item.name,
        requiredLevel: item.requiredLevel,
        priority: item.priority,
        weight: item.weight,
        category: item.category.isEmpty ? defaultCategory : item.category,
      );
    }).toList();
  }

  /// Stream of full job documents (for admin panel). Only parses new-format docs as JobDocument.
  Stream<List<JobDocument>> getJobDocuments() {
    return _db.collection('jobs').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return JobDocument.fromFirestore(doc.id, data);
      }).toList();
    });
  }

  /// One-time fetch of all job documents (for admin).
  Future<List<JobDocument>> getJobDocumentsOnce() async {
    final snapshot = await _db.collection('jobs').get();
    return snapshot.docs.map((doc) => JobDocument.fromFirestore(doc.id, doc.data())).toList();
  }

  /// Fetch a single job document by Firestore document id (for edit).
  Future<JobDocument?> getJobDocumentById(String id) async {
    if (id.isEmpty) return null;
    final doc = await _db.collection('jobs').doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    final data = doc.data()!;
    if (!JobDocument.isNewFormat(data)) return null;
    return JobDocument.fromFirestore(doc.id, data);
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
  /// [skills] is the raw Firestore list (strings and/or maps) so analytics can count names/skillIds correctly.
  Stream<List<Map<String, dynamic>>> streamUsersForAnalytics() {
    return _db.collection('users').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final skillsRaw = data['skills'] as List?;
        return <String, dynamic>{
          'id': doc.id,
          'skills': skillsRaw ?? <dynamic>[],
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
        final data = doc.data()!;
        if (JobDocument.isNewFormat(data)) {
          return JobDocument.fromFirestore(doc.id, data).toJobRole();
        }
        return JobRole.fromFirestore(doc.id, data);
      }
      return null;
    });
  }

  /// Add a new job role to Firestore. Returns the new document id.
  Future<String> addJob(JobRole job) async {
    final ref = _db.collection('jobs').doc();
    await ref.set(job.toFirestore());
    _invalidateJobsCache();
    return ref.id;
  }

  /// Update an existing job role in Firestore by id.
  Future<void> updateJob(JobRole job) async {
    if (job.id.isEmpty) return;
    await _db.collection('jobs').doc(job.id).set(job.toFirestore());
    _invalidateJobsCache();
  }

  /// Add a new job document (comprehensive format). Uses [job.jobId] as doc id if provided, else auto-generates.
  Future<String> addJobDocument(JobDocument job) async {
    final normalizedTechRaw = await _normalizeJobSkills(
      job.technicalSkills,
      groupKey: 'technicalSkills',
    );
    final normalizedSoftRaw = await _normalizeJobSkills(
      job.softSkills,
      groupKey: 'softSkills',
    );
    final normalizedToolsRaw = await _normalizeJobSkills(
      job.tools,
      groupKey: 'tools',
    );
    final normalizedTech = await Future.wait(
      normalizedTechRaw.map((s) async {
        final resolved = await resolveOrCreateSkillId(
          s.skillId.isNotEmpty ? s.skillId : s.name,
          defaultCategory: _defaultCategoryForGroup('technicalSkills'),
        );
        return JobSkillItem(
          skillId: resolved,
          name: s.name,
          requiredLevel: s.requiredLevel,
          priority: s.priority,
          weight: s.weight,
          category: s.category,
        );
      }),
    );
    final normalizedSoft = await Future.wait(
      normalizedSoftRaw.map((s) async {
        final resolved = await resolveOrCreateSkillId(
          s.skillId.isNotEmpty ? s.skillId : s.name,
          defaultCategory: _defaultCategoryForGroup('softSkills'),
        );
        return JobSkillItem(
          skillId: resolved,
          name: s.name,
          requiredLevel: s.requiredLevel,
          priority: s.priority,
          weight: s.weight,
          category: s.category,
        );
      }),
    );
    final normalizedTools = await Future.wait(
      normalizedToolsRaw.map((s) async {
        final resolved = await resolveOrCreateSkillId(
          s.skillId.isNotEmpty ? s.skillId : s.name,
          defaultCategory: _defaultCategoryForGroup('tools'),
        );
        return JobSkillItem(
          skillId: resolved,
          name: s.name,
          requiredLevel: s.requiredLevel,
          priority: s.priority,
          weight: s.weight,
          category: s.category,
        );
      }),
    );
    final canonicalId = canonicalJobId(job.title, job.category);
    if (canonicalId.isEmpty) {
      throw StateError('Job title/category are required.');
    }
    final normalizedJob = JobDocument(
      id: job.id,
      jobId: canonicalId,
      title: job.title,
      category: job.category,
      industry: job.industry,
      experienceLevel: job.experienceLevel,
      description: job.description,
      technicalSkills: normalizedTech,
      softSkills: normalizedSoft,
      tools: normalizedTools,
      certifications: job.certifications,
      education: job.education,
      experience: job.experience,
      salary: job.salary,
      createdAt: job.createdAt,
      updatedAt: job.updatedAt,
      isActive: job.isActive,
      totalSkillsCount: job.totalSkillsCount,
      averageRequiredLevel: job.averageRequiredLevel,
    );
    final existingById = await _db.collection('jobs').doc(canonicalId).get();
    final duplicateId = await _findExistingJobIdByIdentity(
      job.title,
      job.category,
    );
    if (duplicateId != null && duplicateId != canonicalId && !existingById.exists) {
      throw StateError(
        'A job with the same title and category already exists (id: $duplicateId).',
      );
    }
    final id = canonicalId;
    final ref = _db.collection('jobs').doc(id);
    await ref.set(normalizedJob.toFirestore());
    _invalidateJobsCache();
    return ref.id;
  }

  /// Update an existing job document. Soft-update: set updatedAt and isActive.
  Future<void> updateJobDocument(JobDocument job) async {
    if (job.id.isEmpty) return;
    final duplicateId = await _findExistingJobIdByIdentity(
      job.title,
      job.category,
      excludeDocId: job.id,
    );
    if (duplicateId != null) {
      throw StateError(
        'Another job with the same title and category already exists (id: $duplicateId).',
      );
    }
    final normalizedTechRaw = await _normalizeJobSkills(
      job.technicalSkills,
      groupKey: 'technicalSkills',
    );
    final normalizedSoftRaw = await _normalizeJobSkills(
      job.softSkills,
      groupKey: 'softSkills',
    );
    final normalizedToolsRaw = await _normalizeJobSkills(
      job.tools,
      groupKey: 'tools',
    );
    final normalizedTech = await Future.wait(
      normalizedTechRaw.map((s) async {
        final resolved = await resolveOrCreateSkillId(
          s.skillId.isNotEmpty ? s.skillId : s.name,
          defaultCategory: _defaultCategoryForGroup('technicalSkills'),
        );
        return JobSkillItem(
          skillId: resolved,
          name: s.name,
          requiredLevel: s.requiredLevel,
          priority: s.priority,
          weight: s.weight,
          category: s.category,
        );
      }),
    );
    final normalizedSoft = await Future.wait(
      normalizedSoftRaw.map((s) async {
        final resolved = await resolveOrCreateSkillId(
          s.skillId.isNotEmpty ? s.skillId : s.name,
          defaultCategory: _defaultCategoryForGroup('softSkills'),
        );
        return JobSkillItem(
          skillId: resolved,
          name: s.name,
          requiredLevel: s.requiredLevel,
          priority: s.priority,
          weight: s.weight,
          category: s.category,
        );
      }),
    );
    final normalizedTools = await Future.wait(
      normalizedToolsRaw.map((s) async {
        final resolved = await resolveOrCreateSkillId(
          s.skillId.isNotEmpty ? s.skillId : s.name,
          defaultCategory: _defaultCategoryForGroup('tools'),
        );
        return JobSkillItem(
          skillId: resolved,
          name: s.name,
          requiredLevel: s.requiredLevel,
          priority: s.priority,
          weight: s.weight,
          category: s.category,
        );
      }),
    );
    final updated = JobDocument(
      id: job.id,
      jobId: job.jobId,
      title: job.title,
      category: job.category,
      industry: job.industry,
      experienceLevel: job.experienceLevel,
      description: job.description,
      technicalSkills: normalizedTech,
      softSkills: normalizedSoft,
      tools: normalizedTools,
      certifications: job.certifications,
      education: job.education,
      experience: job.experience,
      salary: job.salary,
      createdAt: job.createdAt,
      updatedAt: DateTime.now(),
      isActive: job.isActive,
      totalSkillsCount: job.totalSkillsCount,
      averageRequiredLevel: job.averageRequiredLevel,
    );
    await _db.collection('jobs').doc(job.id).set(updated.toFirestore());
    _invalidateJobsCache();
  }

  /// Soft-delete job: set isActive = false.
  Future<void> deleteJobSoft(String jobId) async {
    if (jobId.isEmpty) return;
    final doc = await _db.collection('jobs').doc(jobId).get();
    if (!doc.exists || doc.data() == null) return;
    final j = JobDocument.fromFirestore(doc.id, doc.data()!);
    final updated = JobDocument(
      id: j.id,
      jobId: j.jobId,
      title: j.title,
      category: j.category,
      industry: j.industry,
      experienceLevel: j.experienceLevel,
      description: j.description,
      technicalSkills: j.technicalSkills,
      softSkills: j.softSkills,
      tools: j.tools,
      certifications: j.certifications,
      education: j.education,
      experience: j.experience,
      salary: j.salary,
      createdAt: j.createdAt,
      updatedAt: DateTime.now(),
      isActive: false,
      totalSkillsCount: j.totalSkillsCount,
      averageRequiredLevel: j.averageRequiredLevel,
    );
    await _db.collection('jobs').doc(jobId).set(updated.toFirestore());
    _invalidateJobsCache();
  }

  /// Deletes all documents in the jobs collection (batches of 500). Use with caution (e.g. debug or admin).
  Future<void> clearAllJobs() async {
    const batchSize = 500;
    var done = false;
    while (!done) {
      final snapshot = await _db.collection('jobs').limit(batchSize).get();
      if (snapshot.docs.isEmpty) {
        done = true;
        break;
      }
      final batch = _db.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      if (snapshot.docs.length < batchSize) done = true;
    }
    _invalidateJobsCache();
    debugPrint('clearAllJobs: all job documents deleted');
  }

  /// Clears all jobs and seeds with the comprehensive job database (15 jobs). Call in debug or one-time migration.
  static Future<void> clearAllJobsAndSeed() async {
    final db = FirebaseFirestore.instance;
    const batchSize = 500;
    var done = false;
    while (!done) {
      final snapshot = await db.collection('jobs').limit(batchSize).get();
      if (snapshot.docs.isEmpty) {
        done = true;
        break;
      }
      final batch = db.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      if (snapshot.docs.length < batchSize) done = true;
    }
    final jobs = getSeedJobs();
    for (final job in jobs) {
      await db.collection('jobs').doc(job.jobId).set(job.toFirestore());
    }
    CachedDataService.invalidate(CachedDataService.keyJobsOnce);
    debugPrint('clearAllJobsAndSeed: deleted all jobs and seeded ${jobs.length} jobs');
  }

  /// If jobs collection is empty, seeds with the comprehensive job database. Safe to call on app start (e.g. kDebugMode).
  static Future<void> seedJobsIfEmpty() async {
    final db = FirebaseFirestore.instance;
    final snapshot = await db.collection('jobs').limit(1).get();
    if (snapshot.docs.isNotEmpty) return;
    final jobs = getSeedJobs();
    for (final job in jobs) {
      await db.collection('jobs').doc(job.jobId).set(job.toFirestore());
    }
    CachedDataService.invalidate(CachedDataService.keyJobsOnce);
    debugPrint('seedJobsIfEmpty: seeded ${jobs.length} jobs');
  }

  /// Idempotent jobs seed: for each seed job, creates the document if missing or updates it if it exists (same jobId).
  /// Does NOT delete or overwrite other job documents. Safe to run multiple times.
  static Future<void> seedJobsUpsert() async {
    final db = FirebaseFirestore.instance;
    final jobs = getSeedJobs();
    for (final job in jobs) {
      await db.collection('jobs').doc(job.jobId).set(job.toFirestore());
    }
    CachedDataService.invalidate(CachedDataService.keyJobsOnce);
    debugPrint('seedJobsUpsert: upserted ${jobs.length} jobs');
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
      if (skill.name.isNotEmpty) {
        map[canonicalSkillId(skill.id)] = skill;
      }
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

  // ---------------------------------------------------------------------------
  // Skills collection (SkillDocument): for Admin Skills Library & Add/Edit.
  // ---------------------------------------------------------------------------

  /// Fetches all skill documents with optional filters. For Admin Skills Library. Filter/sort in memory to avoid composite indexes.
  Future<List<SkillDocument>> getSkillDocumentsOnce({
    String? type,
    String? category,
    String? demandLevel,
    bool? trending,
    String orderBy = 'totalJobsUsingSkill',
    bool descending = true,
  }) async {
    final snapshot = await _db.collection('skills').get();
    var list = snapshot.docs.map((doc) {
      final s = SkillDocument.fromFirestore(doc.data(), doc.id);
      return s;
    }).whereType<SkillDocument>().toList();

    if (type != null && type.isNotEmpty && type != 'All') {
      list = list.where((s) => s.type == type).toList();
    }
    if (category != null && category.isNotEmpty && category != 'All') {
      list = list.where((s) => s.category == category).toList();
    }
    if (demandLevel != null && demandLevel.isNotEmpty && demandLevel != 'All') {
      list = list.where((s) => s.demandLevel == demandLevel).toList();
    }
    if (trending != null) {
      list = list.where((s) => s.trending == trending).toList();
    }

    switch (orderBy) {
      case 'skillName':
        list.sort((a, b) => (descending ? b.skillName : a.skillName).compareTo(descending ? a.skillName : b.skillName));
        break;
      case 'demandLevel':
        final order = ['Very High', 'High', 'Medium', 'Low'];
        list.sort((a, b) {
          final ia = order.indexOf(a.demandLevel ?? '');
          final ib = order.indexOf(b.demandLevel ?? '');
          return descending ? (ia - ib) : (ib - ia);
        });
        break;
      case 'createdAt':
        list.sort((a, b) {
          final ta = a.createdAt ?? DateTime(0);
          final tb = b.createdAt ?? DateTime(0);
          return descending ? tb.compareTo(ta) : ta.compareTo(tb);
        });
        break;
      case 'totalJobsUsingSkill':
      default:
        list.sort((a, b) => descending
            ? b.totalJobsUsingSkill.compareTo(a.totalJobsUsingSkill)
            : a.totalJobsUsingSkill.compareTo(b.totalJobsUsingSkill));
    }
    return list;
  }

  /// Fetches a single skill document by id.
  Future<SkillDocument?> getSkillDocument(String skillId) async {
    final doc = await _db.collection('skills').doc(skillId).get();
    if (doc.data() == null) return null;
    return SkillDocument.fromFirestore(doc.data(), doc.id);
  }

  /// Search skills by name prefix (indexed) with legacy alias/substring fallback.
  Future<List<SkillDocument>> searchSkillDocuments({
    required String query,
    String? type,
    int limit = 20,
  }) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    try {
      final prefix = q;
      final end = '$prefix\uf8ff';
      Query<Map<String, dynamic>> coll = _db.collection('skills');
      if (type != null && type.isNotEmpty && type != 'All') {
        coll = coll
            .where('type', isEqualTo: type)
            .where('skillName', isGreaterThanOrEqualTo: prefix)
            .where('skillName', isLessThanOrEqualTo: end)
            .orderBy('skillName')
            .limit(limit);
      } else {
        coll = coll
            .where('skillName', isGreaterThanOrEqualTo: prefix)
            .where('skillName', isLessThanOrEqualTo: end)
            .orderBy('skillName')
            .limit(limit);
      }
      final snapshot = await coll.get();
      var list = snapshot.docs
          .map((doc) => SkillDocument.fromFirestore(doc.data(), doc.id))
          .whereType<SkillDocument>()
          .toList();
      if (list.length < limit && q.length >= 2) {
        final extra = await _searchSkillDocumentsLegacy(
          query: q,
          type: type,
          limit: limit - list.length,
          excludeIds: list.map((s) => s.skillId).toSet(),
        );
        list = [...list, ...extra];
      }
      list.sort((a, b) => a.skillName.compareTo(b.skillName));
      return list.take(limit).toList();
    } on FirebaseException catch (e) {
      if (kDebugMode) {
        debugPrint('searchSkillDocuments: prefix query failed ($e), using legacy scan');
      }
      return _searchSkillDocumentsLegacy(
        query: q,
        type: type,
        limit: limit,
        excludeIds: const {},
      );
    }
  }

  /// Full scan + substring match (fallback when index missing or prefix misses case/aliases).
  Future<List<SkillDocument>> _searchSkillDocumentsLegacy({
    required String query,
    String? type,
    required int limit,
    required Set<String> excludeIds,
  }) async {
    final q = query.toLowerCase();
    Query<Map<String, dynamic>> coll = _db.collection('skills');
    if (type != null && type.isNotEmpty && type != 'All') {
      coll = coll.where('type', isEqualTo: type);
    }
    final snapshot = await coll.get();
    final list = <SkillDocument>[];
    for (final doc in snapshot.docs) {
      if (excludeIds.contains(doc.id)) continue;
      final data = doc.data();
      final name = (data['skillName'] as String? ?? data['name'] as String? ?? '').toLowerCase();
      final aliases = (data['aliases'] as List?)?.map((e) => e.toString().toLowerCase()).toList() ?? [];
      if (name.contains(q) || aliases.any((a) => a.contains(q))) {
        final s = SkillDocument.fromFirestore(data, doc.id);
        if (s != null) list.add(s);
        if (list.length >= limit) break;
      }
    }
    list.sort((a, b) => a.skillName.compareTo(b.skillName));
    return list;
  }

  /// Adds or overwrites a skill document. Id = skillId.
  Future<void> addOrUpdateSkillDocument(SkillDocument skill) async {
    await _db.collection('skills').doc(skill.skillId).set(skill.toFirestore());
    invalidateSkillsCache();
  }

  /// Updates a skill document (merge). Partial update by skillId.
  Future<void> updateSkillDocument(String skillId, Map<String, dynamic> data) async {
    await _db.collection('skills').doc(skillId).update(data);
    invalidateSkillsCache();
  }

  /// Same slug as jobs import / [canonicalSkillId] (hyphens, case-insensitive).
  static String skillNameToSkillId(String name) => canonicalSkillId(name);

  static String _skillNameToDocId(String name) => skillNameToSkillId(name);

  /// Fetch suggested learning resources (course names) for missing skills from Firestore.
  /// 1) Reads [suggestedCourses] on each `skills/{id}` doc when present.
  /// 2) If empty, falls back to [courses] collection (same data as Recommendations tab).
  /// Returns map skillName (display) -> up to [maxPerSkill] short labels.
  Future<Map<String, List<String>>> getSuggestedCoursesForSkills(
    List<String> skillNames, {
    bool verifiedOnly = false,
  }) async {
    const maxPerSkill = 3;
    final names = skillNames.map((n) => n.trim()).where((n) => n.isNotEmpty).toList();
    final result = <String, List<String>>{
      for (final n in names) n: <String>[],
    };
    if (names.isEmpty) return result;

    final catalog = await getSkills();
    try {
      final uniqueIds = <String>{};
      final allowedByName = <String, bool>{};
      for (final name in names) {
        final matched = _matchSkillIdFromCatalog(name, catalog);
        final id = matched ?? _skillNameToDocId(name);
        if (id.isNotEmpty) uniqueIds.add(id);
        final skill = id.isNotEmpty ? (catalog[canonicalSkillId(id)] ?? catalog[id]) : null;
        final allowed = !verifiedOnly || (skill?.isVerified == true);
        allowedByName[name] = allowed;
      }
      if (uniqueIds.isNotEmpty) {
        final refs = uniqueIds.map((id) => _db.collection('skills').doc(id)).toList();
        final snapshots = await Future.wait(refs.map((r) => r.get()));
        final idToSuggested = <String, List<String>>{};
        for (var i = 0; i < snapshots.length && i < refs.length; i++) {
          final data = snapshots[i].data();
          if (verifiedOnly && data?['isVerified'] == false) {
            idToSuggested[refs[i].id] = const [];
            continue;
          }
          final list = data?['suggestedCourses'] as List<dynamic>?;
          final suggested =
              list
                  ?.map((e) => e?.toString().trim())
                  .where((s) => s != null && s.isNotEmpty)
                  .cast<String>()
                  .take(maxPerSkill)
                  .toList() ??
              [];
          idToSuggested[refs[i].id] = suggested;
        }
        for (final name in names) {
          final id = _matchSkillIdFromCatalog(name, catalog) ?? _skillNameToDocId(name);
          if ((allowedByName[name] ?? false) == false) {
            continue;
          }
          final fromDoc = idToSuggested[id] ?? [];
          if (fromDoc.isNotEmpty) {
            result[name] = fromDoc;
          }
        }
      }
    } catch (e, st) {
      debugPrint('getSuggestedCoursesForSkills (skills docs): $e');
      if (kDebugMode) debugPrintStack(stackTrace: st);
    }

    bool allowFallback(String name) {
      if (!verifiedOnly) return true;
      final id = _matchSkillIdFromCatalog(name, catalog) ?? _skillNameToDocId(name);
      if (id.isEmpty) return false;
      final s = catalog[canonicalSkillId(id)] ?? catalog[id];
      return s?.isVerified == true;
    }
    final needFallback = names
        .where((n) => result[n]!.isEmpty && allowFallback(n))
        .toList();
    if (needFallback.isEmpty) return result;

    try {
      final fromCourses = await getCoursesForSkills(needFallback, maxPerSkill);
      for (final name in needFallback) {
        final courses = fromCourses[name] ?? [];
        result[name] = courses
            .map((c) {
              final t = c.title.trim();
              final p = c.platform.trim();
              if (t.isEmpty) return '';
              return p.isNotEmpty ? '$t ($p)' : t;
            })
            .where((s) => s.isNotEmpty)
            .take(maxPerSkill)
            .toList();
      }
    } catch (e, st) {
      debugPrint('getSuggestedCoursesForSkills (courses fallback): $e');
      if (kDebugMode) debugPrintStack(stackTrace: st);
    }

    return result;
  }

  /// Enhanced recommendations:
  /// - Course labels for each missing skill
  /// - Related skills that the user already has (bridging hints)
  Future<Map<String, List<String>>> getSmartRecommendationsForSkills(
    List<String> missingSkillNames,
    Set<String> userSkillIds, {
    bool verifiedOnly = true,
  }) async {
    final result = await getSuggestedCoursesForSkills(
      missingSkillNames,
      verifiedOnly: verifiedOnly,
    );
    if (missingSkillNames.isEmpty) return result;
    final catalog = await getSkills();
    final userSet = userSkillIds.map(canonicalSkillId).where((e) => e.isNotEmpty).toSet();
    for (final missing in missingSkillNames) {
      final missingId = _matchSkillIdFromCatalog(missing, catalog);
      if (missingId == null || missingId.isEmpty) continue;
      final skill = catalog[canonicalSkillId(missingId)];
      if (skill == null) continue;
      if (verifiedOnly && !skill.isVerified) continue;
      final bridges = <String>[];
      for (final relatedId in skill.relatedSkills) {
        final cid = canonicalSkillId(relatedId);
        if (!userSet.contains(cid)) continue;
        final rel = catalog[cid];
        if (rel == null) continue;
        bridges.add('Bridge from your `${rel.name}` skill to `${skill.name}`');
        if (bridges.length >= 2) break;
      }
      if (bridges.isNotEmpty) {
        result[missing] = [...(result[missing] ?? const <String>[]), ...bridges];
      }
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Courses collection: full course documents for Recommendations tab.
  // ---------------------------------------------------------------------------

  /// Fetches courses for a single skill from Firestore `courses` collection.
  /// Tries exact match first, then title-case match for flexibility.
  Future<List<Course>> getCoursesForSkill(String skillName, int limit) async {
    final name = skillName.trim();
    if (name.isEmpty) return [];
    try {
      var list = await _getCoursesForSkillExact(name, limit);
      if (list.isEmpty && name.isNotEmpty) {
        final titleCase = name.split(' ').map((w) {
          if (w.isEmpty) return w;
          return w.substring(0, 1).toUpperCase() + w.substring(1).toLowerCase();
        }).join(' ');
        list = await _getCoursesForSkillExact(titleCase, limit);
      }
      if (list.isEmpty) {
        final docId = skillNameToSkillId(name);
        if (docId.isNotEmpty) {
          final snap = await _db.collection('skills').doc(docId).get();
          final data = snap.data();
          final fromSkillDoc =
              data?['skillName']?.toString().trim() ??
              data?['name']?.toString().trim() ??
              '';
          if (fromSkillDoc.isNotEmpty && fromSkillDoc != name) {
            list = await _getCoursesForSkillExact(fromSkillDoc, limit);
          }
        }
      }
      return list;
    } catch (e) {
      debugPrint('getCoursesForSkill failed: $e');
      return [];
    }
  }

  Future<List<Course>> _getCoursesForSkillExact(String skillName, int limit) async {
    final fetchLimit = (limit <= 0 ? 10 : limit * 5).clamp(10, 100);
    final snapshot = await _db
        .collection('courses')
        .where('skillName', isEqualTo: skillName)
        .limit(fetchLimit)
        .get();
    final courses = snapshot.docs
        .map((d) => Course.fromFirestore(d.data()))
        .where((c) => c.title.isNotEmpty && c.url.isNotEmpty)
        .toList();
    courses.sort((a, b) {
      final scoreCmp = b.relevanceScore.compareTo(a.relevanceScore);
      if (scoreCmp != 0) return scoreCmp;
      final ratingCmp = b.rating.compareTo(a.rating);
      if (ratingCmp != 0) return ratingCmp;
      return a.priority.compareTo(b.priority);
    });
    return courses.take(limit).toList();
  }

  /// Fetches courses for multiple skills in parallel. Returns map skillName -> list of courses (up to maxPerSkill each).
  Future<Map<String, List<Course>>> getCoursesForSkills(
    List<String> skillNames,
    int maxPerSkill,
  ) async {
    final entries = await Future.wait(
      skillNames.map((name) async {
        final courses = await getCoursesForSkill(name, maxPerSkill);
        return MapEntry(name, courses);
      }),
    );
    return Map.fromEntries(entries);
  }

  /// Adds a course document to Firestore (admin). Returns the new document id.
  Future<String> addCourse(Course course) async {
    final uri = Uri.tryParse(course.url.trim());
    final validUrl = uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        (uri.host.isNotEmpty);
    if (!validUrl) {
      throw StateError('Course URL must be a valid http/https URL.');
    }
    final skill = await getSkillByNameOrAlias(course.skillName);
    if (skill == null) {
      throw StateError(
        'Course skill "${course.skillName}" was not found in skills catalog.',
      );
    }
    final normalized = Course(
      skillName: skill.name,
      skillId: canonicalSkillId(skill.id),
      title: course.title.trim(),
      platform: course.platform.trim(),
      url: course.url.trim(),
      duration: course.duration.trim(),
      cost: course.cost.trim(),
      estimatedPrice: course.estimatedPrice?.trim(),
      rating: course.rating,
      level: course.level.trim(),
      description: course.description.trim(),
      priority: course.priority,
      relevanceScore: course.relevanceScore,
    );
    final ref = _db.collection('courses').doc();
    await ref.set(normalized.toFirestore());
    return ref.id;
  }

  /// One-time seed for `courses` collection if empty (debug only). Call from main in kDebugMode.
  static Future<void> seedCoursesIfEmpty() async {
    final db = FirebaseFirestore.instance;
    final snapshot = await db.collection('courses').limit(1).get();
    if (snapshot.docs.isNotEmpty) return;
    final batch = db.batch();
    for (final doc in _seedCourses) {
      final ref = db.collection('courses').doc();
      batch.set(ref, doc);
    }
    await batch.commit();
    debugPrint('seedCoursesIfEmpty: seeded ${_seedCourses.length} courses');
  }

  static final List<Map<String, dynamic>> _seedCourses = [
    ..._seedCoursesForSkill('JavaScript', [
      {
        'skillName': 'JavaScript',
        'title': 'JavaScript - The Complete Guide 2024',
        'platform': 'Udemy',
        'url': 'https://www.udemy.com/course/javascript-the-complete-guide-2020-beginner-advanced/',
        'duration': '52 hours',
        'cost': 'Paid',
        'estimatedPrice': r'$84.99',
        'rating': 4.6,
        'level': 'Beginner',
        'description': 'Master JavaScript with the most complete course! Projects, challenges, quizzes, ES6+, OOP, AJAX, Webpack',
      },
      {
        'skillName': 'JavaScript',
        'title': 'The Modern JavaScript Tutorial',
        'platform': 'FreeCodeCamp',
        'url': 'https://www.freecodecamp.org/news/learn-javascript-full-course/',
        'duration': '8 hours',
        'cost': 'Free',
        'rating': 4.8,
        'level': 'Beginner',
        'description': 'Learn JavaScript from scratch with hands-on projects and exercises.',
      },
    ]),
    ..._seedCoursesForSkill('Python', [
      {
        'skillName': 'Python',
        'title': 'Python for Everybody Specialization',
        'platform': 'Coursera',
        'url': 'https://www.coursera.org/specializations/python',
        'duration': '8 months',
        'cost': 'Freemium',
        'estimatedPrice': r'$49/month',
        'rating': 4.8,
        'level': 'Beginner',
        'description': 'Learn to Program and Analyze Data with Python by University of Michigan',
      },
      {
        'skillName': 'Python',
        'title': 'Learn Python - Full Course for Beginners',
        'platform': 'FreeCodeCamp',
        'url': 'https://www.freecodecamp.org/news/learn-python-full-course/',
        'duration': '4.5 hours',
        'cost': 'Free',
        'rating': 4.7,
        'level': 'Beginner',
        'description': 'Complete Python tutorial for beginners with exercises.',
      },
    ]),
    ..._seedCoursesForSkill('React', [
      {'skillName': 'React', 'title': 'React - The Complete Guide', 'platform': 'Udemy', 'url': 'https://www.udemy.com/course/react-the-complete-guide/', 'duration': '48 hours', 'cost': 'Paid', 'estimatedPrice': r'$84.99', 'rating': 4.6, 'level': 'Beginner', 'description': 'Dive in and learn React from scratch. Hooks, Redux, React Router.'},
      {'skillName': 'React', 'title': 'Front-End Development with React', 'platform': 'Coursera', 'url': 'https://www.coursera.org/learn/front-end-react', 'duration': '26 hours', 'cost': 'Freemium', 'estimatedPrice': r'$49/month', 'rating': 4.7, 'level': 'Intermediate', 'description': 'Build dynamic user interfaces with React by The Hong Kong University of Science and Technology.'},
    ]),
    ..._seedCoursesForSkill('Node.js', [
      {'skillName': 'Node.js', 'title': 'Node.js, Express, MongoDB & More', 'platform': 'Udemy', 'url': 'https://www.udemy.com/course/nodejs-express-mongodb/', 'duration': '40 hours', 'cost': 'Paid', 'estimatedPrice': r'$84.99', 'rating': 4.7, 'level': 'Beginner', 'description': 'Complete Node.js bootcamp with Express, MongoDB and authentication.'},
      {'skillName': 'Node.js', 'title': 'Server-Side Development with NodeJS', 'platform': 'Coursera', 'url': 'https://www.coursera.org/learn/server-development-nodejs', 'duration': '32 hours', 'cost': 'Freemium', 'estimatedPrice': r'$49/month', 'rating': 4.6, 'level': 'Intermediate', 'description': 'Build backend services and APIs with Node.js and Express.'},
    ]),
    ..._seedCoursesForSkill('SQL', [
      {'skillName': 'SQL', 'title': 'SQL for Data Science', 'platform': 'Coursera', 'url': 'https://www.coursera.org/learn/sql-for-data-science', 'duration': '14 hours', 'cost': 'Freemium', 'estimatedPrice': r'$49/month', 'rating': 4.6, 'level': 'Beginner', 'description': 'Learn SQL fundamentals for querying and analyzing data.'},
      {'skillName': 'SQL', 'title': 'The Complete SQL Bootcamp', 'platform': 'Udemy', 'url': 'https://www.udemy.com/course/the-complete-sql-bootcamp/', 'duration': '9 hours', 'cost': 'Paid', 'estimatedPrice': r'$84.99', 'rating': 4.7, 'level': 'Beginner', 'description': 'Go from zero to hero in SQL with PostgreSQL.'},
    ]),
    ..._seedCoursesForSkill('Java', [
      {'skillName': 'Java', 'title': 'Java Programming and Software Engineering Fundamentals', 'platform': 'Coursera', 'url': 'https://www.coursera.org/specializations/java-programming', 'duration': '5 months', 'cost': 'Freemium', 'estimatedPrice': r'$49/month', 'rating': 4.7, 'level': 'Beginner', 'description': 'Learn core Java and object-oriented programming by Duke University.'},
      {'skillName': 'Java', 'title': 'Java Tutorial for Complete Beginners', 'platform': 'Udemy', 'url': 'https://www.udemy.com/course/java-tutorial/', 'duration': '16 hours', 'cost': 'Paid', 'estimatedPrice': r'$84.99', 'rating': 4.5, 'level': 'Beginner', 'description': 'Learn Java step by step with practical examples.'},
    ]),
    ..._seedCoursesForSkill('Git', [
      {'skillName': 'Git', 'title': 'Version Control with Git', 'platform': 'Coursera', 'url': 'https://www.coursera.org/learn/version-control-with-git', 'duration': '13 hours', 'cost': 'Freemium', 'estimatedPrice': r'$49/month', 'rating': 4.7, 'level': 'Beginner', 'description': 'Learn Git for version control and collaboration.'},
      {'skillName': 'Git', 'title': 'Git Complete: The Definitive Guide', 'platform': 'Udemy', 'url': 'https://www.udemy.com/course/git-complete/', 'duration': '6.5 hours', 'cost': 'Paid', 'estimatedPrice': r'$84.99', 'rating': 4.6, 'level': 'Beginner', 'description': 'From zero to hero in Git and GitHub.'},
    ]),
    ..._seedCoursesForSkill('Docker', [
      {'skillName': 'Docker', 'title': 'Docker for the Absolute Beginner', 'platform': 'Udemy', 'url': 'https://www.udemy.com/course/docker-for-the-absolute-beginner/', 'duration': '4 hours', 'cost': 'Paid', 'estimatedPrice': r'$84.99', 'rating': 4.6, 'level': 'Beginner', 'description': 'Hands-on Docker with Kubernetes and Docker Compose.'},
      {'skillName': 'Docker', 'title': 'Containers and Kubernetes', 'platform': 'edX', 'url': 'https://www.edx.org/learn/docker', 'duration': '4 weeks', 'cost': 'Freemium', 'estimatedPrice': r'$99', 'rating': 4.5, 'level': 'Intermediate', 'description': 'Learn containerization and orchestration with Docker and Kubernetes.'},
    ]),
    ..._seedCoursesForSkill('AWS', [
      {'skillName': 'AWS', 'title': 'AWS Cloud Technical Essentials', 'platform': 'Coursera', 'url': 'https://www.coursera.org/learn/aws-cloud-technical-essentials', 'duration': '14 hours', 'cost': 'Freemium', 'estimatedPrice': r'$49/month', 'rating': 4.7, 'level': 'Beginner', 'description': 'Introduction to AWS services and cloud concepts.'},
      {'skillName': 'AWS', 'title': 'AWS Certified Solutions Architect', 'platform': 'Udemy', 'url': 'https://www.udemy.com/course/aws-certified-solutions-architect-associate/', 'duration': '17 hours', 'cost': 'Paid', 'estimatedPrice': r'$84.99', 'rating': 4.6, 'level': 'Intermediate', 'description': 'Prepare for AWS certification with hands-on labs.'},
    ]),
    ..._seedCoursesForSkill('Machine Learning', [
      {'skillName': 'Machine Learning', 'title': 'Machine Learning', 'platform': 'Coursera', 'url': 'https://www.coursera.org/learn/machine-learning', 'duration': '60 hours', 'cost': 'Freemium', 'estimatedPrice': r'$49/month', 'rating': 4.9, 'level': 'Intermediate', 'description': 'Machine Learning by Stanford University - Andrew Ng.'},
      {'skillName': 'Machine Learning', 'title': 'Intro to Machine Learning', 'platform': 'Udacity', 'url': 'https://www.udacity.com/course/intro-to-machine-learning--ud120', 'duration': '10 weeks', 'cost': 'Freemium', 'estimatedPrice': r'$399/month', 'rating': 4.5, 'level': 'Intermediate', 'description': 'Supervised and unsupervised learning with Python.'},
    ]),
    ..._seedCoursesForSkill('Communication', [
      {'skillName': 'Communication', 'title': 'Improve Your English Communication Skills', 'platform': 'Coursera', 'url': 'https://www.coursera.org/specializations/improve-english', 'duration': '4 months', 'cost': 'Freemium', 'estimatedPrice': r'$49/month', 'rating': 4.7, 'level': 'Beginner', 'description': 'Write and speak professionally in English.'},
      {'skillName': 'Communication', 'title': 'Effective Communication: Writing, Design, and Presentation', 'platform': 'Coursera', 'url': 'https://www.coursera.org/specializations/effective-business-communication', 'duration': '5 months', 'cost': 'Freemium', 'estimatedPrice': r'$49/month', 'rating': 4.6, 'level': 'Beginner', 'description': 'Build communication skills for the workplace.'},
    ]),
    ..._seedCoursesForSkill('Teamwork', [
      {'skillName': 'Teamwork', 'title': 'Teamwork Skills: Communicating Effectively in Groups', 'platform': 'Coursera', 'url': 'https://www.coursera.org/learn/teamwork-skills-effective-communication', 'duration': '15 hours', 'cost': 'Freemium', 'estimatedPrice': r'$49/month', 'rating': 4.7, 'level': 'Beginner', 'description': 'Learn to collaborate and communicate in teams.'},
      {'skillName': 'Teamwork', 'title': 'Leading Teams', 'platform': 'Coursera', 'url': 'https://www.coursera.org/learn/leading-teams', 'duration': '17 hours', 'cost': 'Freemium', 'estimatedPrice': r'$49/month', 'rating': 4.8, 'level': 'Intermediate', 'description': 'Build and lead high-performing teams.'},
    ]),
    ..._seedCoursesForSkill('Problem Solving', [
      {'skillName': 'Problem Solving', 'title': 'Creative Problem Solving', 'platform': 'Coursera', 'url': 'https://www.coursera.org/learn/creative-problem-solving', 'duration': '4 weeks', 'cost': 'Freemium', 'estimatedPrice': r'$49', 'rating': 4.7, 'level': 'Beginner', 'description': 'Learn creative problem-solving techniques by University of Minnesota.'},
      {'skillName': 'Problem Solving', 'title': 'Critical Thinking and Problem Solving', 'platform': 'LinkedIn Learning', 'url': 'https://www.linkedin.com/learning/critical-thinking-and-problem-solving', 'duration': '1.5 hours', 'cost': 'Freemium', 'estimatedPrice': r'$39.99/month', 'rating': 4.6, 'level': 'Beginner', 'description': 'Develop critical thinking and structured problem-solving skills.'},
    ]),
    ..._seedCoursesForSkill('Leadership', [
      {'skillName': 'Leadership', 'title': 'Inspiring Leadership through Emotional Intelligence', 'platform': 'Coursera', 'url': 'https://www.coursera.org/learn/emotional-intelligence-leadership', 'duration': '19 hours', 'cost': 'Freemium', 'estimatedPrice': r'$49/month', 'rating': 4.8, 'level': 'Intermediate', 'description': 'Build leadership and emotional intelligence skills.'},
      {'skillName': 'Leadership', 'title': 'Leading People and Teams', 'platform': 'Coursera', 'url': 'https://www.coursera.org/specializations/leading-people-teams', 'duration': '5 months', 'cost': 'Freemium', 'estimatedPrice': r'$49/month', 'rating': 4.7, 'level': 'Intermediate', 'description': 'Leadership fundamentals from University of Michigan.'},
    ]),
    ..._seedCoursesForSkill('Time Management', [
      {'skillName': 'Time Management', 'title': 'Work Smarter, Not Harder: Time Management for Personal & Professional Productivity', 'platform': 'Coursera', 'url': 'https://www.coursera.org/learn/work-smarter-not-harder', 'duration': '10 hours', 'cost': 'Freemium', 'estimatedPrice': r'$49/month', 'rating': 4.7, 'level': 'Beginner', 'description': 'Manage time and priorities effectively.'},
      {'skillName': 'Time Management', 'title': 'Time Management Fundamentals', 'platform': 'LinkedIn Learning', 'url': 'https://www.linkedin.com/learning/time-management-fundamentals', 'duration': '2 hours', 'cost': 'Freemium', 'estimatedPrice': r'$39.99/month', 'rating': 4.6, 'level': 'Beginner', 'description': 'Plan and prioritize to get more done.'},
    ]),
  ];

  static List<Map<String, dynamic>> _seedCoursesForSkill(
    String skillName,
    List<Map<String, dynamic>> courses,
  ) {
    return courses.map((m) => {...m, 'skillName': skillName}).toList();
  }

  // ---------------------------------------------------------------------------
  // Skill add/update API: updates Firestore skills, profile completion, and
  // analysis_results. Dashboard and gap analysis screens use Firestore streams,
  // so they update immediately when these methods write to the user document.
  // ---------------------------------------------------------------------------

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
    final skillId = await resolveOrCreateSkillId(
      skillName,
      defaultCategory: 'Technical',
      createIfMissing: true,
      isVerified: false,
    );
    await addSkillById(uid, skillId, pointsClamped);
  }

  /// Adds or updates a skill by master skill id and level (0-100). Writes users.skills as { skillId, level }.
  Future<void> addSkillById(String uid, String skillId, int level) async {
    if (uid.isEmpty || skillId.trim().isEmpty) return;
    final canonicalId = canonicalSkillId(skillId);
    if (canonicalId.isEmpty) return;
    final catalog = await getSkills();
    if (!catalog.containsKey(canonicalId)) {
      throw StateError('Skill "$canonicalId" does not exist in skills catalog.');
    }
    final ref = _db.collection('users').doc(uid);
    final doc = await ref.get();
    if (!doc.exists || doc.data() == null) return;

    final data = doc.data()!;
    final skills = _parseSkillsList(data['skills']);
    final levelClamped = level.clamp(0, 100);
    final idx = skills.indexWhere(
      (s) => canonicalSkillId(s['skillId']?.toString()) == canonicalId,
    );
    final entry = {'skillId': canonicalId, 'level': levelClamped};
    if (idx >= 0) {
      skills[idx] = entry;
    } else {
      skills.add(entry);
    }
    await ref.update({'skills': skills, 'profile_completed': true});
    scheduleRefreshAnalysisResultsForUser(uid);
  }

  /// Updates an existing skill's level by skillId (0-100).
  Future<void> updateSkillById(String uid, String skillId, int level) async {
    if (uid.isEmpty || skillId.trim().isEmpty) return;
    final canonicalId = canonicalSkillId(skillId);
    if (canonicalId.isEmpty) return;
    final catalog = await getSkills();
    if (!catalog.containsKey(canonicalId)) {
      throw StateError('Skill "$canonicalId" does not exist in skills catalog.');
    }
    final ref = _db.collection('users').doc(uid);
    final doc = await ref.get();
    if (!doc.exists || doc.data() == null) return;

    final data = doc.data()!;
    final skills = _parseSkillsList(data['skills']);
    final target = canonicalId;
    final idx = skills.indexWhere(
      (s) => canonicalSkillId(s['skillId']?.toString()) == target,
    );
    if (idx < 0) return;
    skills[idx]['level'] = level.clamp(0, 100);
    await ref.update({'skills': skills, 'profile_completed': true});
    scheduleRefreshAnalysisResultsForUser(uid);
  }

  /// Updates an existing skill's level/points by normalized name.
  /// If the skill name exists in the catalog, uses updateSkillById (new format); otherwise legacy.
  Future<void> updateSkill(String uid, String skillName, int points) async {
    if (uid.isEmpty || skillName.trim().isEmpty) return;
    final pointsClamped = points.clamp(0, 100);
    final skillId = await resolveOrCreateSkillId(
      skillName,
      defaultCategory: 'Technical',
      createIfMissing: true,
      isVerified: false,
    );
    final ref = _db.collection('users').doc(uid);
    final doc = await ref.get();
    if (!doc.exists || doc.data() == null) return;

    final data = doc.data()!;
    final skills = _parseSkillsList(data['skills']);
    final idx = skills.indexWhere(
      (s) => (s['skillId']?.toString().trim() ?? '') == skillId,
    );
    if (idx < 0) {
      await addSkillById(uid, skillId, pointsClamped);
      return;
    }
    skills[idx] = {'skillId': skillId, 'level': pointsClamped};
    await ref.update({'skills': skills, 'profile_completed': true});
    scheduleRefreshAnalysisResultsForUser(uid);
  }

  /// Debounced full refresh after skill edits (coalesces rapid slider changes).
  void scheduleRefreshAnalysisResultsForUser(String uid) {
    if (uid.isEmpty) return;
    AnalysisRefreshScheduler.schedule(uid, () => refreshAnalysisResultsForUser(uid));
  }

  /// Recalculates and merges one job into [analysis_results] (e.g. on-demand refresh).
  Future<void> updateAnalysisResultsForJob(String uid, String jobId) async {
    if (uid.isEmpty || jobId.trim().isEmpty) return;
    await refreshAnalysisResultsForUser(uid, onlyJobIds: {jobId});
  }

  /// Recalculates skill gap match for job roles and writes a summary to [analysis_results].
  /// [onlyJobIds]: if set, only those jobs are recomputed and merged with existing entries.
  /// If null, all jobs are recomputed in parallel (replaces the whole map).
  Future<void> refreshAnalysisResultsForUser(
    String uid, {
    Set<String>? onlyJobIds,
  }) async {
    final sw = Stopwatch()..start();
    var msUser = 0;
    var msJobsSkills = 0;
    var msCompute = 0;

    final userDoc = await _db.collection('users').doc(uid).get();
    msUser = sw.elapsedMilliseconds;
    if (!userDoc.exists || userDoc.data() == null) return;

    final userData = userDoc.data()!;
    final jobs = await getJobsOnce();
    final skillsCatalog = await getSkills();
    msJobsSkills = sw.elapsedMilliseconds;

    final jobsToRun = onlyJobIds == null
        ? jobs
        : jobs.where((j) => onlyJobIds.contains(j.id)).toList();
    if (jobsToRun.isEmpty) return;

    final computed = await Future.wait(
      jobsToRun.map((job) async {
        final result = await GapAnalysisService.runGapAnalysis(
          userData,
          job,
          fetchRecommendations: getSuggestedCoursesForSkills,
          fetchSmartRecommendations: (names, userSkillIds) =>
              getSmartRecommendationsForSkills(
                names,
                userSkillIds,
                verifiedOnly: true,
              ),
          fetchCourseDetails: (names) => getCoursesForSkills(names, 3),
          skillsCatalog: skillsCatalog.isNotEmpty ? skillsCatalog : null,
        );
        return MapEntry(
          job.id,
          <String, dynamic>{
            'matchPercentage': result.matchPercentage,
            'weightedMatchPercentage': result.weightedMatchPercentage,
            'missingCount': result.missingSkills.length,
            'matchedCount': result.matchedSkills.length,
          },
        );
      }),
    );
    msCompute = sw.elapsedMilliseconds;

    if (onlyJobIds == null) {
      await _db.collection('users').doc(uid).update({
        'analysis_results': Map<String, dynamic>.fromEntries(computed),
      });
    } else {
      final merged = _parseAnalysisResultsMap(userData['analysis_results']);
      for (final e in computed) {
        merged[e.key] = e.value;
      }
      await _db.collection('users').doc(uid).update({
        'analysis_results': Map<String, dynamic>.from(merged),
      });
    }

    sw.stop();
    if (kDebugMode) {
      debugPrint(
        'refreshAnalysisResultsForUser: ${jobsToRun.length} job(s) total=${sw.elapsedMilliseconds}ms '
        '(userDoc=${msUser}ms, jobs+skills=${msJobsSkills - msUser}ms, '
        'compute=${msCompute - msJobsSkills}ms, write=${sw.elapsedMilliseconds - msCompute}ms, '
        'scope=${onlyJobIds == null ? 'all' : 'partial'})',
      );
    }
  }

  static Map<String, Map<String, dynamic>> _parseAnalysisResultsMap(dynamic raw) {
    final out = <String, Map<String, dynamic>>{};
    if (raw is! Map) return out;
    for (final e in raw.entries) {
      final v = e.value;
      if (v is Map<String, dynamic>) {
        out[e.key.toString()] = Map<String, dynamic>.from(v);
      } else if (v is Map) {
        out[e.key.toString()] = Map<String, dynamic>.from(
          v.map((k, v) => MapEntry(k.toString(), v)),
        );
      }
    }
    return out;
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

  /// Market insights aggregated from `skills` collection demand analytics.
  /// Returns top demanded skills for dashboard widgets.
  Future<MarketInsights> getMarketInsights() async {
    final snapshot = await _db
        .collection('skills')
        .where('totalJobsUsingSkill', isGreaterThan: 0)
        .orderBy('totalJobsUsingSkill', descending: true)
        .limit(20)
        .get();

    final topDemandedSkills = <String>[];
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final name =
          data['name']?.toString().trim() ??
          data['skillName']?.toString().trim() ??
          doc.id;
      if (name.isNotEmpty) {
        topDemandedSkills.add(name);
      }
    }

    return MarketInsights(
      topDemandedSkills: topDemandedSkills,
      mostMatchedSkills: const [],
      mostMissingSkills: const [],
    );
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

  /// Adds or updates basic user fields on the current user's document.
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

  /// Fetches the signed-in user's document data.
  Future<Map<String, dynamic>?> getUserData() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return null;

    final doc = await _db.collection('users').doc(user.uid).get();

    return doc.exists ? doc.data() : null;
  }

  /// Updates the signed-in user's document.
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
