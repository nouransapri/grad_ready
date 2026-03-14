import {
  collection,
  getDocs,
  onSnapshot,
  query,
  orderBy,
  limit,
  Timestamp,
  DocumentData,
  QuerySnapshot,
} from 'firebase/firestore'
import { db } from './firebase'

export type UserDoc = {
  id: string
  full_name?: string
  email?: string
  university?: string
  major?: string
  academic_year?: string
  skills?: unknown[]
  last_analysis?: string
  last_analysis_at?: Timestamp | null
  created_at?: Timestamp | null
  profile_completed?: boolean
}

export type JobDoc = {
  id: string
  title?: string
  description?: string
  category?: string
  requiredSkills?: string[]
  technicalSkillsWithLevel?: { name: string; percent?: number }[]
  softSkillsWithLevel?: { name: string; percent?: number }[]
  salaryMinK?: number
  salaryMaxK?: number
  lastUpdated?: string
}

/** Total count of users */
export async function getTotalUsers(): Promise<number> {
  const snap = await getDocs(collection(db, 'users'))
  return snap.size
}

/** Total count of job roles */
export async function getTotalJobs(): Promise<number> {
  const snap = await getDocs(collection(db, 'jobs'))
  return snap.size
}

/** Users created since start of month (uses created_at if present) */
export async function getNewUsersThisMonth(): Promise<number> {
  const now = new Date()
  const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1)
  const snap = await getDocs(collection(db, 'users'))
  let count = 0
  snap.docs.forEach((d) => {
    const data = d.data()
    const created = data?.created_at as Timestamp | undefined
    if (created?.toDate && created.toDate() >= startOfMonth) count++
  })
  return count
}

/** Count of users with at least one assessment (last_analysis set) */
export async function getTotalAssessments(): Promise<number> {
  const snap = await getDocs(collection(db, 'users'))
  let count = 0
  snap.docs.forEach((d) => {
    if (d.data()?.last_analysis) count++
  })
  return count
}

/** Users active today (last_analysis_at today) */
export async function getActiveToday(): Promise<number> {
  const snap = await getDocs(collection(db, 'users'))
  const today = new Date().toDateString()
  let count = 0
  snap.docs.forEach((d) => {
    const at = d.data()?.last_analysis_at as Timestamp | undefined
    if (at?.toDate && at.toDate().toDateString() === today) count++
  })
  return count
}

/** Unique skill names across all jobs (requiredSkills + technical/soft names) */
export async function getSkillsDefinedCount(): Promise<number> {
  const snap = await getDocs(collection(db, 'jobs'))
  const set = new Set<string>()
  snap.docs.forEach((d) => {
    const data = d.data()
    ;(data?.requiredSkills || []).forEach((s: string) => set.add(s.trim().toLowerCase()))
    ;(data?.technicalSkillsWithLevel || []).forEach((s: { name?: string }) => set.add((s.name || '').trim().toLowerCase()))
    ;(data?.softSkillsWithLevel || []).forEach((s: { name?: string }) => set.add((s.name || '').trim().toLowerCase()))
  })
  return set.size
}

/** Aggregate last_analysis (job title) counts for chart */
export function aggregateJobSelections(users: UserDoc[]): { name: string; count: number }[] {
  const map = new Map<string, number>()
  users.forEach((u) => {
    const title = (u.last_analysis || '').trim()
    if (title) map.set(title, (map.get(title) || 0) + 1)
  })
  return Array.from(map.entries())
    .map(([name, count]) => ({ name: name.length > 14 ? name.slice(0, 12) + '…' : name, count }))
    .sort((a, b) => b.count - a.count)
    .slice(0, 8)
}

/** Aggregate missing skills from users vs jobs (simplified: skills mentioned in jobs but not in user) */
export function aggregateSkillGaps(users: UserDoc[], jobs: JobDoc[]): { name: string; percent: number }[] {
  const jobSkills = new Set<string>()
  jobs.forEach((j) => {
    ;(j.requiredSkills || []).forEach((s) => jobSkills.add(s.trim().toLowerCase()))
  })
  const userSkillCount = new Map<string, number>()
  jobSkills.forEach((s) => userSkillCount.set(s, 0))
  users.forEach((u) => {
    const list = (u.skills || []) as (string | { name?: string })[]
    const normalized = new Set(
      list.map((x) => (typeof x === 'string' ? x : x?.name || '').trim().toLowerCase()).filter(Boolean)
    )
    userSkillCount.forEach((_, skill) => {
      if (!normalized.has(skill)) userSkillCount.set(skill, (userSkillCount.get(skill) || 0) + 1)
    })
  })
  const total = users.length || 1
  return Array.from(userSkillCount.entries())
    .map(([name, count]) => ({ name: name.charAt(0).toUpperCase() + name.slice(1), percent: Math.round((count / total) * 100) }))
    .sort((a, b) => b.percent - a.percent)
    .slice(0, 6)
}

/** Weekly activity: count by day of week from last_analysis_at */
export function aggregateWeeklyActivity(users: UserDoc[]): { day: string; count: number }[] {
  const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
  const counts = [0, 0, 0, 0, 0, 0, 0]
  users.forEach((u) => {
    const at = u.last_analysis_at as Timestamp | undefined
    if (at?.toDate) {
      const d = at.toDate().getDay()
      counts[d]++
    }
  })
  return days.map((day, i) => ({ day, count: counts[i] }))
}

/** Users by academic_year for pie */
export function aggregateAcademicLevels(users: UserDoc[]): { name: string; value: number; color: string }[] {
  const map = new Map<string, number>()
  users.forEach((u) => {
    const y = (u.academic_year || 'Other').trim() || 'Other'
    map.set(y, (map.get(y) || 0) + 1)
  })
  const colors = ['#8b5cf6', '#6366f1', '#3b82f6', '#10b981']
  return Array.from(map.entries())
    .sort((a, b) => b[1] - a[1])
    .slice(0, 4)
    .map(([name, value], i) => ({ name, value, color: colors[i] || colors[0] }))
}

/** Quick insights from real aggregates */
export function buildQuickInsights(
  users: UserDoc[],
  jobs: JobDoc[],
  jobRolesData: { name: string; count: number }[],
  skillGapsData: { name: string; percent: number }[]
): string[] {
  const insights: string[] = []
  if (jobRolesData.length > 0) {
    insights.push(`${jobRolesData[0].name} is the most selected career (${jobRolesData[0].count} assessments)`)
  }
  if (skillGapsData.length > 0) {
    insights.push(`${skillGapsData[0].name} has the largest skill gap across users (${skillGapsData[0].percent}%)`)
  }
  const thursday = users.filter((u) => {
    const at = u.last_analysis_at as Timestamp | undefined
    return at?.toDate?.()?.getDay() === 4
  }).length
  if (thursday > 0) {
    insights.push(`Thursday has ${thursday} assessments this week`)
  }
  const withYear = users.filter((u) => u.academic_year && u.academic_year !== 'Select year').length
  const pct = users.length ? Math.round((withYear / users.length) * 100) : 0
  insights.push(`${pct}% of users have academic year set`)
  return insights.slice(0, 4)
}

/** Real-time snapshot of users for admin dashboard */
export function subscribeUsers(cb: (users: UserDoc[]) => void): () => void {
  const q = query(collection(db, 'users'), limit(500))
  const unsub = onSnapshot(q, (snap: QuerySnapshot<DocumentData>) => {
    const users: UserDoc[] = snap.docs.map((d) => ({ id: d.id, ...d.data() } as UserDoc))
    cb(users)
  })
  return unsub
}

/** One-time fetch jobs for admin */
export async function fetchJobs(): Promise<JobDoc[]> {
  const snap = await getDocs(collection(db, 'jobs'))
  return snap.docs.map((d) => ({ id: d.id, ...d.data() } as JobDoc))
}

/** One-time fetch all users for analytics */
export async function fetchUsers(): Promise<UserDoc[]> {
  const snap = await getDocs(collection(db, 'users'))
  return snap.docs.map((d) => ({ id: d.id, ...d.data() } as UserDoc))
}

/** Job category distribution from jobs */
export function jobCategoryDistribution(jobs: JobDoc[]): { name: string; percent: number }[] {
  const map = new Map<string, number>()
  jobs.forEach((j) => {
    const c = (j.category || 'Other').trim() || 'Other'
    map.set(c, (map.get(c) || 0) + 1)
  })
  const total = jobs.length || 1
  return Array.from(map.entries())
    .map(([name, count]) => ({ name, percent: Math.round((count / total) * 100) }))
    .sort((a, b) => b.percent - a.percent)
}

/** Top skills from all users' skills arrays */
export function topSkillsFromUsers(users: UserDoc[], topN: number): { name: string; count: number }[] {
  const map = new Map<string, number>()
  users.forEach((u) => {
    const list = (u.skills || []) as (string | { name?: string })[]
    list.forEach((x) => {
      const name = (typeof x === 'string' ? x : x?.name || '').trim()
      if (name) map.set(name, (map.get(name) || 0) + 1)
    })
  })
  return Array.from(map.entries())
    .map(([name, count]) => ({ name, count }))
    .sort((a, b) => b.count - a.count)
    .slice(0, topN)
}

/** User growth trend (last 8 weeks by created_at) */
export function userGrowthTrend(users: UserDoc[]): { week: string; count: number }[] {
  const weeks: number[] = Array(8).fill(0)
  const now = new Date()
  users.forEach((u) => {
    const created = u.created_at as Timestamp | undefined
    if (!created?.toDate) return
    const d = created.toDate()
    const weekAgo = (now.getTime() - d.getTime()) / (7 * 24 * 60 * 60 * 1000)
    const index = Math.floor(weekAgo)
    if (index >= 0 && index < 8) weeks[7 - index]++
  })
  let cum = 0
  return weeks.map((w, i) => {
    cum += w
    return { week: `Week ${i + 1}`, count: cum }
  })
}

/** Radar: top 6 job skills and % of users who have each (skills coverage) */
export function radarSkillsCoverage(users: UserDoc[], jobs: JobDoc[]): { skill: string; value: number }[] {
  const skillSet = new Set<string>()
  jobs.forEach((j) => {
    (j.requiredSkills || []).slice(0, 10).forEach((s) => skillSet.add(s.trim()))
  })
  const arr = Array.from(skillSet).slice(0, 6)
  if (arr.length === 0) return [{ skill: 'N/A', value: 0 }]
  const total = users.length || 1
  return arr.map((skill) => {
    const low = skill.toLowerCase()
    const count = users.filter((u) => {
      const list = (u.skills || []) as (string | { name?: string })[]
      return list.some((x) => (typeof x === 'string' ? x : x?.name || '').trim().toLowerCase() === low)
    }).length
    return { skill: skill.length > 12 ? skill.slice(0, 10) + '…' : skill, value: Math.round((count / total) * 100) }
  })
}

/** Skill gaps with count for analytics (users missing this skill) */
export function skillGapsWithCount(users: UserDoc[], jobs: JobDoc[]): { name: string; percent: number; count: number }[] {
  const jobSkills = new Set<string>()
  jobs.forEach((j) => (j.requiredSkills || []).forEach((s) => jobSkills.add(s.trim().toLowerCase())))
  const userSkillCount = new Map<string, number>()
  jobSkills.forEach((s) => userSkillCount.set(s, 0))
  users.forEach((u) => {
    const list = (u.skills || []) as (string | { name?: string })[]
    const normalized = new Set(
      list.map((x) => (typeof x === 'string' ? x : x?.name || '').trim().toLowerCase()).filter(Boolean)
    )
    userSkillCount.forEach((_, skill) => {
      if (!normalized.has(skill)) userSkillCount.set(skill, (userSkillCount.get(skill) || 0) + 1)
    })
  })
  const total = users.length || 1
  return Array.from(userSkillCount.entries())
    .map(([name, count]) => ({
      name: name.charAt(0).toUpperCase() + name.slice(1),
      percent: Math.round((count / total) * 100),
      count,
    }))
    .sort((a, b) => b.percent - a.percent)
    .slice(0, 7)
}

/** Job roles analytics with pct */
export function jobRolesAnalyticsWithPct(users: UserDoc[]): { name: string; count: number; pct: number }[] {
  const jobData = aggregateJobSelections(users)
  const total = users.filter((u) => u.last_analysis).length || 1
  return jobData.slice(0, 7).map((r) => ({
    name: r.name,
    count: r.count,
    pct: Math.round((r.count / total) * 1000) / 10,
  }))
}

/** User dist with pct for pie */
export function userDistWithPct(users: UserDoc[]): { name: string; value: number; pct: number }[] {
  const map = new Map<string, number>()
  users.forEach((u) => {
    const y = (u.academic_year || 'Other').trim() || 'Other'
    map.set(y, (map.get(y) || 0) + 1)
  })
  const total = users.length || 1
  return Array.from(map.entries())
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5)
    .map(([name, value]) => ({ name, value, pct: Math.round((value / total) * 100) }))
}

/** Key insights from real data */
export function keyInsightsFromData(
  users: UserDoc[],
  jobs: JobDoc[],
  jobRolesData: { name: string; count: number; pct?: number }[],
  skillGapsData: { name: string; percent: number }[],
  topSkills: { name: string; count: number }[],
  categoryDist: { name: string; percent: number }[]
): string[] {
  const insights: string[] = []
  if (jobRolesData.length > 0) {
    insights.push(
      `${jobRolesData[0].name} accounts for ${jobRolesData[0].pct ?? 0}% of job role selections (${jobRolesData[0].count} assessments)`
    )
  }
  if (skillGapsData.length > 0) {
    const second = skillGapsData[1]
    insights.push(
      second
        ? `${skillGapsData[0].name} and ${second.name} are the top skill gaps (${skillGapsData[0].percent}%, ${second.percent}%)`
        : `${skillGapsData[0].name} is the top skill gap (${skillGapsData[0].percent}%)`
    )
  }
  const trend = userGrowthTrend(users)
  const first = trend[0]?.count ?? 0
  const last = trend[7]?.count ?? 0
  const pctChange = first > 0 ? Math.round(((last - first) / first) * 100) : 0
  insights.push(`User growth trend: ${pctChange}% over the last 8 weeks`)
  if (userDistWithPct(users).length > 0) {
    const top = userDistWithPct(users)[0]
    insights.push(`${top?.pct ?? 0}% of users have academic level "${top?.name ?? 'Other'}"`)
  }
  if (topSkills.length > 0) {
    const second = topSkills[1]
    insights.push(
      second
        ? `${topSkills[0].name} and ${second.name} are the most frequently added skills`
        : `${topSkills[0].name} is the most frequently added skill`
    )
  }
  return insights.slice(0, 5)
}
