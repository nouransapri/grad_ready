# Analytics and Dashboard — How It Works

This document explains step-by-step how analytics and dashboards work in the GradReady project: which Firestore collections and fields are used, how data is processed, what calculations are performed, and whether values are dynamic or hardcoded.

---

## 1. Firestore collections used for analysis

| Collection        | Used in              | Purpose |
|-------------------|----------------------|--------|
| **`users`**       | Home dashboard, Admin | Per-user profile and activity (skills, last_analysis, etc.). |
| **`jobs`**        | Admin Analytics      | Job roles and required skills for gap analytics. |
| **`insights`**    | Home dashboard       | “Latest Insights” skill bars (skill_name, percentage, order). |
| **`market_trends`** | Home dashboard     | “Job Market Trends” cards (title, growth_percentage, icon_name, subtitle, order). |
| **`skills`**      | Gap analysis         | Suggested learning resources per skill (suggestedCourses). |

**Related code:**

- **`lib/services/firestore_service.dart`**
  - `_db.collection('users')` — users stream / doc reads
  - `_db.collection('jobs')` — jobs stream / doc reads
  - `_db.collection('insights')` — insights stream
  - `_db.collection('market_trends')` — market_trends stream
  - `_db.collection('skills')` — skill recommendations (getSuggestedCoursesForSkills)

- **`lib/screens/home_page.dart`**
  - `FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots()` — current user profile for dashboard stats

---

## 2. Fields read from Firestore

### 2.1 `users` (per document: `users/{uid}`)

| Field               | Where used           | Purpose |
|---------------------|----------------------|--------|
| `full_name`         | Home, profile        | Display / validation. |
| `university`        | Home, profile        | Profile completion. |
| `major`             | Home, profile        | Profile completion. |
| `academic_year`     | Home, profile        | Profile completion. |
| `gpa`               | Profile              | Display. |
| `added_courses`     | Home (optional)      | “Courses” count and profile completion (if present). |
| `skills`            | Home, Admin          | Skills count, profile completion, gap analytics. |
| `internships`       | Home, profile        | Profile completion. |
| `clubs`             | Home, profile        | Profile completion. |
| `projects`          | Home, profile        | Profile completion. |
| `last_analysis`     | Home, Admin          | “Last Analysis” stat and “Most Selected Job Roles” (job title string). |
| `last_analysis_at`  | Admin                | Assessment Activity Trend (timestamp; grouped by week). |
| `profile_completed` | main.dart            | Routing (home vs create profile). |
| `role`              | main.dart            | Admin vs student routing. |

**Code references:**

```dart
// lib/screens/home_page.dart — Dashboard stats from user doc
final data = snapshot.data?.data();
final stats = _DashboardStats.fromUserData(data);

// _DashboardStats.fromUserData reads:
final skills = data['skills'] as List?;
final courses = data['added_courses'] as List?;
final lastAnalysisValue = data['last_analysis'];
// + _profileCompletionPercentage(data) which reads:
// full_name, university, major, academic_year, added_courses, skills, internships, clubs, projects
```

```dart
// lib/services/firestore_service.dart — streamUsers() for Admin
final data = doc.data();
final skillsRaw = data['skills'] as List?;
// Returns list of { 'id': doc.id, 'skills': skills }
```

### 2.2 `jobs`

Fields read via `JobRole.fromFirestore()`: `title`, `description`, `category`, `isHighDemand`, `salaryMinK`, `salaryMaxK`, `requiredSkills`, `technicalSkillsWithLevel`, `softSkillsWithLevel`, `criticalSkills`.

Used in Admin Analytics to compute match %, most missing skill, and “users per job” bar chart.

### 2.3 `insights`

| Field        | Type   | Purpose |
|-------------|--------|--------|
| `skill_name`| string | Label for the bar. |
| `percentage`| number | Bar value (0–100). |
| `order`     | number | Sort order in the list. |

**Code:** `lib/models/insight_model.dart` — `InsightModel.fromFirestore(id, data)` reads `skill_name`, `percentage`.

### 2.4 `market_trends`

| Field               | Type   | Purpose |
|--------------------|--------|--------|
| `title`            | string | Card title. |
| `growth_percentage`| number | Growth value. |
| `icon_name`        | string | Icon key (e.g. trending_up, security). |
| `subtitle`         | string | Optional card subtitle. |
| `order`            | number | Sort order. |

**Code:** `lib/models/trend_model.dart` — `TrendModel.fromFirestore(id, data)` reads these fields.

---

## 3. How data is processed after fetch

### 3.1 Home dashboard (user document)

1. **Source:** `users/{currentUser.uid}` via `.snapshots()`.
2. **Processing:**
   - `snapshot.data?.data()` → `Map<String, dynamic> data`
   - `_DashboardStats.fromUserData(data)`:
     - `skillsCount = data['skills']?.length ?? 0`
     - `coursesCount = data['added_courses']?.length ?? 0`
     - `lastAnalysis = data['last_analysis']?.toString() ?? 'N/A'`
     - `profileCompletionPercent = _profileCompletionPercentage(data)`
3. **Profile completion:** Count how many of 6 sections are “filled” (academic info, courses, skills, internships, clubs, projects), then `(completed / 6) * 100`.

**Relevant code:**

```120:143:lib/screens/home_page.dart
  /// 6 sections: Academic Info, Courses, Skills, Internships, Clubs, Projects.
  static int _profileCompletionPercentage(Map<String, dynamic>? data) {
    if (data == null) return 0;
    int completed = 0;
    final name = (data['full_name'] as String?)?.trim().isNotEmpty ?? false;
    // ... academicOk, courses, skills, internships, clubs, projects
    return ((completed / 6) * 100).round();
  }
```

```711:743:lib/screens/home_page.dart
class _DashboardStats {
  factory _DashboardStats.fromUserData(Map<String, dynamic>? data) {
    // ... builds skillsCount, coursesCount, profileCompletionPercent, lastAnalysis
  }
}
```

### 3.2 Latest Insights (insights collection)

1. **Source:** `FirestoreService.streamInsights()` → `insights` collection, `.orderBy('order')`, `.snapshots()`.
2. **Processing:** Each doc → `InsightModel.fromFirestore(doc.id, doc.data())` (skill_name, percentage).
3. **Display:** Progress bars using `InsightModel.progress` (percentage/100).

**Code:** `lib/services/firestore_service.dart` — `streamInsights()`; `lib/models/insight_model.dart` — `fromFirestore`.

### 3.3 Job Market Trends (market_trends collection)

1. **Source:** `FirestoreService.streamMarketTrends()` → `market_trends` collection, `.orderBy('order')`, `.snapshots()`.
2. **Processing:** Each doc → `TrendModel.fromFirestore(doc.id, doc.data())`.
3. **Display:** Cards with title, subtitle (or default “+X% growth”), and icon from `trendIconFromName(iconName)`.

**Code:** `lib/services/firestore_service.dart` — `streamMarketTrends()`; `lib/models/trend_model.dart` — `fromFirestore`, `trendIconFromName`.

### 3.4 Admin — All analytics (users + jobs, dynamic)

1. **Source:** `FirestoreService.streamUsersForAnalytics()` (users with `id`, `skills`, `academic_year`, `last_analysis`, `last_analysis_at`) and `FirestoreService.getJobs()` (both real-time streams).
2. **Processing:** Same as below for each card; all values are computed from Firestore (no hardcoded lists).

**Skills Gap section:** For each user, extract skill names from `user['skills']`; for each job use `job.requiredSkills`. Compute average match %, most missing skill, users per job (match % > 0). Chart: top 8 jobs by users matching.

**Most Selected Job Roles:** Group users by `last_analysis` (job title string); count per job title that exists in `jobs`; sort by count descending; take top 7. Total selections = count of users with non-empty `last_analysis`.

**Users by Academic Level:** Group users by `academic_year`; count per level; percent = count / total users × 100. Pie chart and legend from these segments.

**Most Frequently Added Skills:** Flatten all `user['skills']` (string or map with `name`), normalize names; count frequency per skill across users; sort descending; take top 5.

**Job Category Distribution:** From `jobs`, group by `category`; count per category; percent = count / total jobs × 100. Progress bars by category.

**Assessment Activity Trend:** From users with `last_analysis_at` (Timestamp): bucket by week (last 4 weeks); count users per week; line chart. Trend message: compare first half vs second half of weeks (percent change).

**Key Insights Summary:** Generated from the above: e.g. most selected role and %, top academic segment, top added skill, top job category, activity trend sentence, total users if needed.

**Code:** `lib/screens/admin/admin_analytics_screen.dart` — `streamUsersForAnalytics` used in a single nested `StreamBuilder`; `computeMostSelectedJobRoles`, `computeTotalSelections`, `computeAcademicSegments`, `computeMostFrequentSkills`, `computeCategoryDistribution`, `computeActivitySpots`, `computeActivityTrendMessage`, `computeKeyInsights`; all cards take computed data as parameters.

---

## 4. Calculations performed

### 4.1 Home dashboard

| Calculation              | Formula / logic |
|--------------------------|------------------|
| Skills count             | `skills.length` |
| Courses count            | `added_courses.length` (if present) |
| Profile completion %    | `(number of completed sections / 6) * 100` (sections: academic, courses, skills, internships, clubs, projects) |
| Last Analysis            | Display string from `last_analysis` (e.g. job title) |

No averages or trends on the home dashboard; only counts and one stored string.

### 4.2 Admin — Skills Gap Analytics (dynamic)

| Calculation        | Formula |
|--------------------|--------|
| Match % (one user vs one job) | `(number of required skills the user has / total required skills) * 100` (skill names normalized). |
| Average match %    | Sum of all (user, job) match percentages / number of (user, job) pairs. |
| Most missing skill | For each required skill: count users who don’t have it; pick skill with max count. |
| Users per job      | For each job: count users with match % > 0. |

**Functions:**

```171:184:lib/screens/admin/admin_analytics_screen.dart
double _matchPercent(List<dynamic> userSkills, List<String> requiredSkills) {
  if (requiredSkills.isEmpty) return 100.0;
  final userSet = userSkills
      .map((s) => GapAnalysisService.normalize(s is String ? s : s is Map ? (s['name']?.toString() ?? '') : ''))
      .where((s) => s.isNotEmpty)
      .toSet();
  int matched = 0;
  for (final r in requiredSkills) {
    if (userSet.contains(GapAnalysisService.normalize(r))) matched++;
  }
  return (matched / requiredSkills.length) * 100.0;
}
```

### 4.3 Admin — All cards (dynamic from Firestore)

| Card | Calculation |
|------|--------------|
| **Most Selected Job Roles** | Count users per job title where `user.last_analysis == job.title`; sort by count; top 7. Total = users with non-empty `last_analysis`. |
| **Assessment Activity Trend** | Group users by week from `last_analysis_at` (last 4 weeks); count per week → line chart. Trend = % change first half vs second half of weeks. |
| **Users by Academic Level** | Group by `academic_year`; count and percent = count/total×100; pie + legend. |
| **Most Frequently Added Skills** | Flatten all `users.skills`; count by (normalized) skill name; sort desc; top 5. |
| **Job Category Distribution** | From `jobs`, group by `category`; percent = count/total jobs×100. |
| **Key Insights Summary** | Generated from the above: most selected role %, top academic segment, top skill, top category %, trend message. |

All use **Firestore data only**; no hardcoded analytics values.

---

## 5. Exact functions responsible for analytics

### 5.1 FirestoreService (`lib/services/firestore_service.dart`)

| Function                     | Collection(s)   | Returns / effect |
|-----------------------------|-----------------|-------------------|
| `getJobs()`                 | jobs            | `Stream<List<JobRole>>` |
| `getJobStream(jobId)`       | jobs            | `Stream<JobRole?>` |
| `streamUsers()`             | users           | `Stream<List<Map<String, dynamic>>>` (id + parsed skills) |
| `streamUsersForAnalytics()` | users           | `Stream<List<Map<String, dynamic>>>` (id, skills, academic_year, last_analysis, last_analysis_at) for admin analytics |
| `streamInsights()`          | insights        | `Stream<List<InsightModel>>` |
| `streamMarketTrends()`     | market_trends   | `Stream<List<TrendModel>>` |
| `fetchHomeData()`           | insights, market_trends | One-time fetch of insights + trends |
| `uploadHomeMockDataIfEmpty()` | insights, market_trends | Seeds initial data if empty |
| `getSuggestedCoursesForSkills(skillNames)` | skills | `Future<Map<String, List<String>>>` (for gap analysis recommendations) |
| `getMarketInsights()`       | —               | Stub: returns empty `MarketInsights` |

### 5.2 Home dashboard (`lib/screens/home_page.dart`)

| Function / usage                    | Role |
|------------------------------------|------|
| `StreamBuilder` on `users/{uid}.snapshots()` | Subscribes to current user doc. |
| `_DashboardStats.fromUserData(data)`         | Builds stats from user map. |
| `_profileCompletionPercentage(data)`        | Computes profile completion % (6 sections). |
| `_buildStatGrid(stats)`                      | Renders 4 stat cards (Skills, Courses, Profile %, Last Analysis). |
| `_buildInsightsSection()`                    | `StreamBuilder` on `_firestore.streamInsights()` → insight bars. |
| `_buildMarketTrendsSection()`                | `StreamBuilder` on `_firestore.streamMarketTrends()` → trend cards. |

### 5.3 Admin Analytics (`lib/screens/admin/admin_analytics_screen.dart`)

| Function / widget                      | Role |
|---------------------------------------|------|
| `_matchPercent(userSkills, requiredSkills)` | Match % for one user vs one job. |
| `_userSkillStrings(user)`             | Extracts list of skill names from `user['skills']`. |
| `streamUsersForAnalytics()`          | Firestore: users with skills, academic_year, last_analysis, last_analysis_at. |
| `computeMostSelectedJobRoles(users, jobs)` | Count users per job title (last_analysis); top 7. |
| `computeTotalSelections(users)`      | Count users with non-empty last_analysis. |
| `computeAcademicSegments(users)`     | Group by academic_year; count and percent. |
| `computeMostFrequentSkills(users)`   | Count skill names across users; top 5. |
| `computeCategoryDistribution(jobs)`  | Group jobs by category; percent per category. |
| `computeActivitySpots(users)`         | Count users per week from last_analysis_at (last 4 weeks). |
| `computeActivityTrendMessage(users, weeks)` | Trend text from week counts. |
| `computeKeyInsights(...)`             | Build insight strings from all computed analytics. |
| `_SkillsGapAnalyticsSection`         | Uses same users + jobs; computes avg match %, most missing skill, users per job; bar chart. |
| `_AnalyticsOverviewCard`              | UI only (period selector + download chips). |
| `_MostSelectedJobRolesAnalyticsCard` | Bar chart + top 3 list from computed barData and totalSelections. |
| `_AssessmentActivityTrendCard`       | Line chart + trend message from computed spots and trendMessage. |
| `_UsersByAcademicLevelAnalyticsCard` | Pie + legend from computed segments. |
| `_MostFrequentlyAddedSkillsCard`     | List from computed topSkills. |
| `_JobCategoryDistributionCard`       | Bars from computed distribution. |
| `_KeyInsightsSummaryCard`            | Bullets from computed insights. |

---

## 6. Dynamic vs hardcoded dashboard values

### 6.1 Home dashboard (user-facing)

- **Dynamic (from Firestore):**
  - Stats grid: Skills count, Courses count, Profile completion %, Last Analysis — all from `users/{uid}`.
  - Latest Insights: from `insights` (skill_name, percentage).
  - Job Market Trends: from `market_trends` (title, growth_percentage, icon_name, subtitle).
- **Hardcoded:** Quick Tips text and layout; colors and labels of stat cards.

### 6.2 Admin Analytics

- **Dynamic (from Firestore):**
  - **Skills Gap Analytics:** Average match %, most missing skill, “users per job” bar chart — from `streamUsersForAnalytics()` and `getJobs()`.
  - **Most Selected Job Roles:** Count users per job from `last_analysis`; bar chart and top 3.
  - **Assessment Activity Trend:** Count users per week from `last_analysis_at`; line chart and trend message.
  - **Users by Academic Level:** Group by `academic_year`; pie and legend.
  - **Most Frequently Added Skills:** Count skills across users; top 5 list.
  - **Job Category Distribution:** Group jobs by `category`; percent bars.
  - **Key Insights Summary:** Generated from the above computed values.
- **Hardcoded:** Analytics Overview (period selector and download chips only); chart colors and layout.

---

## 7. How the dashboard updates when new data is added to Firestore

### 7.1 Home dashboard

- **User document:** The body uses a **single** `StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>` on:
  - `FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots()`
- So any change to the current user’s document (skills, last_analysis, profile fields, etc.) triggers a new snapshot → `builder` runs again → `_DashboardStats.fromUserData(data)` and the stat grid re-render. **Updates are real-time.**

- **Latest Insights:** `_buildInsightsSection()` uses `StreamBuilder<List<InsightModel>>` on `_firestore.streamInsights()`, which is `insights.orderBy('order').snapshots().map(...)`. Any add/edit/delete in `insights` causes a new snapshot → list of `InsightModel` updates → bars re-render. **Real-time.**

- **Job Market Trends:** Same idea with `_firestore.streamMarketTrends()` and `market_trends.orderBy('order').snapshots().map(...)`. **Real-time.**

So: **when new or updated data is written to `users`, `insights`, or `market_trends`, the home dashboard updates automatically** because everything is driven by Firestore streams.

### 7.2 Admin Analytics

- **All Admin analytics** use one nested `StreamBuilder`:
  - Outer: `firestore.streamUsersForAnalytics()` (users with skills, academic_year, last_analysis, last_analysis_at).
  - Inner: `firestore.getJobs()` (jobs collection).
- When any user doc or any job doc changes, both streams emit → the whole analytics column rebuilds: all six metrics and Key Insights are recomputed and charts update. **Real-time.**

---

## Summary table

| Component              | Firestore collections   | Fields read                    | Calculated / dynamic? | Updates when data changes? |
|------------------------|--------------------------|--------------------------------|------------------------|-----------------------------|
| Home stat grid         | users                    | skills, added_courses, last_analysis, profile sections | Counts + profile %     | Yes (stream)               |
| Latest Insights        | insights                 | skill_name, percentage, order | None                   | Yes (stream)                |
| Job Market Trends      | market_trends            | title, growth_percentage, icon_name, subtitle, order | None                   | Yes (stream)                |
| Admin all cards        | users, jobs              | users: skills, academic_year, last_analysis, last_analysis_at; jobs: category, title, requiredSkills | All 6 metrics + Key Insights from aggregations | Yes (streams)        |

---

## Related code files

- **`lib/services/firestore_service.dart`** — All Firestore access (users, jobs, insights, market_trends, skills).
- **`lib/screens/home_page.dart`** — User dashboard (stats, insights, market trends).
- **`lib/screens/admin/admin_analytics_screen.dart`** — Admin analytics (all cards dynamic from Firestore via `streamUsersForAnalytics()` and `getJobs()`).
- **`lib/models/insight_model.dart`** — Insight shape and `fromFirestore`.
- **`lib/models/trend_model.dart`** — Trend shape, `fromFirestore`, and `trendIconFromName`.
