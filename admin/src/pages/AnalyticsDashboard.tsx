import { useEffect, useState } from 'react'
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  ResponsiveContainer,
  LineChart,
  Line,
  PieChart,
  Pie,
  Cell,
  Legend,
  RadarChart,
  PolarGrid,
  PolarAngleAxis,
  PolarRadiusAxis,
  Radar,
} from 'recharts'
import { Download } from 'lucide-react'
import { toast } from 'sonner'
import {
  fetchUsers,
  fetchJobs,
  jobRolesAnalyticsWithPct,
  skillGapsWithCount,
  userGrowthTrend,
  userDistWithPct,
  topSkillsFromUsers,
  jobCategoryDistribution,
  radarSkillsCoverage,
  keyInsightsFromData,
  type UserDoc,
  type JobDoc,
} from '../lib/firestoreAdmin'

const COLORS = ['#8b5cf6', '#6366f1', '#3b82f6', '#10b981', '#f59e0b']

export default function AnalyticsDashboard() {
  const [dateRange, setDateRange] = useState<'Week' | 'Month' | 'Year'>('Week')
  const [loading, setLoading] = useState(true)
  const [users, setUsers] = useState<UserDoc[]>([])
  const [jobs, setJobs] = useState<JobDoc[]>([])
  const [jobRolesAnalytics, setJobRolesAnalytics] = useState<{ name: string; count: number; pct: number }[]>([])
  const [skillGapsAnalytics, setSkillGapsAnalytics] = useState<{ name: string; percent: number; count: number }[]>([])
  const [radarData, setRadarData] = useState<{ skill: string; value: number }[]>([])
  const [timelineData, setTimelineData] = useState<{ week: string; count: number }[]>([])
  const [userDist, setUserDist] = useState<{ name: string; value: number; pct: number }[]>([])
  const [topSkills, setTopSkills] = useState<{ name: string; count: number }[]>([])
  const [jobCategoryDist, setJobCategoryDist] = useState<{ name: string; percent: number }[]>([])
  const [keyInsights, setKeyInsights] = useState<string[]>([])

  useEffect(() => {
    let cancelled = false
    async function load() {
      setLoading(true)
      try {
        const [userList, jobsList] = await Promise.all([fetchUsers(), fetchJobs()])
        if (cancelled) return
        setUsers(userList)
        setJobs(jobsList)
      } catch (_) {
        if (!cancelled) setUsers([]); setJobs([])
      } finally {
        if (!cancelled) setLoading(false)
      }
    }
    load()
    return () => { cancelled = true }
  }, [])

  useEffect(() => {
    if (users.length === 0 && jobs.length === 0 && !loading) return
    const jobRoles = jobRolesAnalyticsWithPct(users)
    const skillGaps = skillGapsWithCount(users, jobs)
    const top = topSkillsFromUsers(users, 5)
    const categories = jobCategoryDistribution(jobs)
    setJobRolesAnalytics(jobRoles)
    setSkillGapsAnalytics(skillGaps)
    setRadarData(radarSkillsCoverage(users, jobs))
    setTimelineData(userGrowthTrend(users))
    setUserDist(userDistWithPct(users))
    setTopSkills(top)
    setJobCategoryDist(categories)
    setKeyInsights(keyInsightsFromData(users, jobs, jobRoles, skillGaps, top, categories))
  }, [users, jobs, loading])

  const handleExport = (format: 'pdf' | 'csv') => {
    toast.success(`${format.toUpperCase()} export started`)
  }

  const maxSkillCount = Math.max(1, ...topSkills.map((s) => s.count))
  const trendFirst = timelineData[0]?.count ?? 0
  const trendLast = timelineData[7]?.count ?? 0
  const trendPct = trendFirst > 0 ? Math.round(((trendLast - trendFirst) / trendFirst) * 100) : 0

  return (
    <>
      <div className="bg-white rounded-2xl shadow-sm border border-gray-200 p-4">
        <div className="flex flex-wrap items-center justify-between gap-2 mb-4">
          <h3 className="font-bold text-gray-900">Analytics Overview</h3>
          <div className="flex gap-2">
            <button
              onClick={() => handleExport('csv')}
              className="flex items-center gap-1 px-3 py-1.5 rounded-xl bg-green-100 text-green-700 text-sm font-medium"
            >
              <Download className="w-4 h-4" />
              CSV
            </button>
            <button
              onClick={() => handleExport('pdf')}
              className="flex items-center gap-1 px-3 py-1.5 rounded-xl bg-blue-100 text-blue-700 text-sm font-medium"
            >
              <Download className="w-4 h-4" />
              PDF
            </button>
          </div>
        </div>
        <div className="flex gap-2">
          {(['Week', 'Month', 'Year'] as const).map((r) => (
            <button
              key={r}
              onClick={() => setDateRange(r)}
              className={`px-4 py-2 rounded-xl text-sm font-medium transition ${
                dateRange === r ? 'bg-purple-600 text-white' : 'bg-gray-100 text-gray-700'
              }`}
            >
              {r}
            </button>
          ))}
        </div>
      </div>

      <div className="bg-white rounded-2xl shadow-sm border border-gray-200 p-4">
        <h3 className="font-bold text-gray-900 mb-4">Most Selected Job Roles</h3>
        <ResponsiveContainer width="100%" height={240}>
          <BarChart
            data={jobRolesAnalytics.length ? jobRolesAnalytics : [{ name: 'No data', count: 0, pct: 0 }]}
            margin={{ bottom: 40 }}
          >
            <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
            <XAxis dataKey="name" angle={-25} textAnchor="end" height={60} tick={{ fontSize: 10 }} />
            <YAxis tick={{ fontSize: 10 }} />
            <Tooltip contentStyle={{ borderRadius: 8, border: '1px solid #e5e7eb' }} />
            <Bar dataKey="count" fill="#8b5cf6" radius={[4, 4, 0, 0]} isAnimationActive={false} />
          </BarChart>
        </ResponsiveContainer>
        <ul className="mt-3 space-y-1">
          {jobRolesAnalytics.slice(0, 3).map((r, i) => (
            <li key={r.name} className="flex items-center gap-2 text-sm">
              <span className="w-6 h-6 rounded-full bg-purple-100 text-purple-700 flex items-center justify-center text-xs font-bold">
                {i + 1}
              </span>
              {r.name} {r.count} ({r.pct}%)
            </li>
          ))}
        </ul>
      </div>

      <div className="bg-white rounded-2xl shadow-sm border border-gray-200 p-4">
        <h3 className="font-bold text-gray-900 mb-4">Most Common Skill Gaps</h3>
        <ResponsiveContainer width="100%" height={260}>
          <BarChart
            data={skillGapsAnalytics.length ? skillGapsAnalytics : [{ name: 'No data', percent: 0, count: 0 }]}
            layout="vertical"
            margin={{ left: 100, right: 16 }}
          >
            <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
            <XAxis type="number" domain={[0, 60]} tick={{ fontSize: 10 }} />
            <YAxis type="category" dataKey="name" tick={{ fontSize: 10 }} width={95} />
            <Tooltip contentStyle={{ borderRadius: 8, border: '1px solid #e5e7eb' }} />
            <Bar dataKey="percent" fill="#f59e0b" radius={[0, 4, 4, 0]} isAnimationActive={false} />
          </BarChart>
        </ResponsiveContainer>
      </div>

      <div className="bg-white rounded-2xl shadow-sm border border-gray-200 p-4">
        <h3 className="font-bold text-gray-900 mb-4">Average Skills Coverage</h3>
        <ResponsiveContainer width="100%" height={260}>
          <RadarChart data={radarData.length ? radarData : [{ skill: 'N/A', value: 0 }]}>
            <PolarGrid />
            <PolarAngleAxis dataKey="skill" tick={{ fontSize: 10 }} />
            <PolarRadiusAxis angle={30} domain={[0, 100]} tick={{ fontSize: 10 }} />
            <Radar
              name="Coverage"
              dataKey="value"
              stroke="#6366f1"
              fill="#6366f1"
              fillOpacity={0.6}
              isAnimationActive={false}
            />
          </RadarChart>
        </ResponsiveContainer>
      </div>

      <div className="bg-white rounded-2xl shadow-sm border border-gray-200 p-4">
        <h3 className="font-bold text-gray-900 mb-4">Assessment Activity Trend</h3>
        <ResponsiveContainer width="100%" height={200}>
          <LineChart
            data={timelineData.length ? timelineData : [{ week: 'Week 1', count: 0 }]}
            margin={{ left: 0, right: 8 }}
          >
            <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
            <XAxis dataKey="week" tick={{ fontSize: 10 }} />
            <YAxis tick={{ fontSize: 10 }} />
            <Tooltip contentStyle={{ borderRadius: 8, border: '1px solid #e5e7eb' }} />
            <Line
              type="monotone"
              dataKey="count"
              stroke="#6366f1"
              strokeWidth={2}
              dot={{ fill: '#6366f1' }}
              isAnimationActive={false}
            />
          </LineChart>
        </ResponsiveContainer>
        <div className="mt-3 p-3 rounded-xl bg-blue-50 border border-blue-100 text-sm text-blue-800">
          Trend: {loading ? 'Loading…' : `User growth ${trendPct >= 0 ? '+' : ''}${trendPct}% over the last 8 weeks.`}
        </div>
      </div>

      <div className="bg-white rounded-2xl shadow-sm border border-gray-200 p-4">
        <h3 className="font-bold text-gray-900 mb-4">Users by Academic Level</h3>
        <ResponsiveContainer width="100%" height={220}>
          <PieChart>
            <Pie
              data={userDist.length ? userDist : [{ name: 'No data', value: 1, pct: 0 }]}
              cx="50%"
              cy="50%"
              innerRadius={45}
              outerRadius={70}
              paddingAngle={2}
              dataKey="value"
              nameKey="name"
              label={({ name, pct }) => `${name} ${pct}%`}
              isAnimationActive={false}
            >
              {(userDist.length ? userDist : [{ name: 'No data', value: 1, pct: 0 }]).map((_, i) => (
                <Cell key={i} fill={COLORS[i % COLORS.length]} />
              ))}
            </Pie>
            <Legend
              layout="horizontal"
              verticalAlign="bottom"
              formatter={(v, e) => `${v}: ${(e as { payload?: { value?: number } }).payload?.value ?? 0}`}
            />
          </PieChart>
        </ResponsiveContainer>
      </div>

      <div className="bg-white rounded-2xl shadow-sm border border-gray-200 p-4">
        <h3 className="font-bold text-gray-900 mb-4">Most Frequently Added Skills</h3>
        <div className="space-y-3">
          {(topSkills.length ? topSkills : [{ name: 'No data', count: 0 }]).map((s, i) => (
            <div key={s.name} className="flex items-center gap-2">
              <span className="w-6 h-6 rounded-full bg-purple-100 text-purple-700 flex items-center justify-center text-xs font-bold shrink-0">
                {i + 1}
              </span>
              <span className="text-sm font-medium w-28 shrink-0">{s.name}</span>
              <div className="flex-1 h-3 rounded-full bg-gray-200 overflow-hidden">
                <div
                  className="h-full rounded-full bg-gradient-to-r from-purple-600 to-indigo-600"
                  style={{ width: `${maxSkillCount ? (s.count / maxSkillCount) * 100 : 0}%` }}
                />
              </div>
              <span className="text-sm text-gray-600 w-10">{s.count}</span>
            </div>
          ))}
        </div>
      </div>

      <div className="bg-white rounded-2xl shadow-sm border border-gray-200 p-4">
        <h3 className="font-bold text-gray-900 mb-4">Job Category Distribution</h3>
        <div className="space-y-3">
          {(jobCategoryDist.length ? jobCategoryDist : [{ name: 'No data', percent: 0 }]).map((c) => (
            <div key={c.name} className="flex items-center gap-2">
              <span className="text-sm w-32 shrink-0">{c.name}</span>
              <div className="flex-1 h-3 rounded-full bg-gray-200 overflow-hidden">
                <div
                  className="h-full rounded-full bg-purple-600"
                  style={{ width: `${c.percent}%` }}
                />
              </div>
              <span className="text-sm font-medium w-10">{c.percent}%</span>
            </div>
          ))}
        </div>
      </div>

      <div className="bg-gradient-to-r from-purple-600 to-indigo-600 rounded-2xl shadow-sm border border-gray-200 p-4 text-white">
        <h3 className="font-bold mb-3">Key Insights Summary</h3>
        <ul className="space-y-2 text-sm">
          {(keyInsights.length ? keyInsights : ['Connect Firestore to see insights']).map((insight, i) => (
            <li key={i} className="flex gap-2">
              <span>•</span>
              <span>{insight}</span>
            </li>
          ))}
        </ul>
      </div>
    </>
  )
}
