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
} from 'recharts'
import { Users, UserCheck, Briefcase, Award, TrendingUp, Activity } from 'lucide-react'
import {
  subscribeUsers,
  fetchJobs,
  getSkillsDefinedCount,
  aggregateJobSelections,
  aggregateSkillGaps,
  aggregateWeeklyActivity,
  aggregateAcademicLevels,
  buildQuickInsights,
  type UserDoc,
  type JobDoc,
} from '../lib/firestoreAdmin'

const COLORS = ['#8b5cf6', '#6366f1', '#3b82f6', '#10b981']

export default function AdminDashboard() {
  const [loading, setLoading] = useState(true)
  const [users, setUsers] = useState<UserDoc[]>([])
  const [jobs, setJobs] = useState<JobDoc[]>([])
  const [stats, setStats] = useState({
    totalUsers: 0,
    newThisMonth: 0,
    jobRoles: 0,
    skillsDefined: 0,
    assessments: 0,
    activeToday: 0,
  })
  const [jobRolesData, setJobRolesData] = useState<{ name: string; count: number }[]>([])
  const [skillGapsData, setSkillGapsData] = useState<{ name: string; percent: number }[]>([])
  const [weeklyActivity, setWeeklyActivity] = useState<{ day: string; count: number }[]>([])
  const [academicLevels, setAcademicLevels] = useState<{ name: string; value: number; color: string }[]>([])
  const [quickInsights, setQuickInsights] = useState<string[]>([])

  useEffect(() => {
    const unsub = subscribeUsers((userList) => {
      setUsers(userList)
    })
    return () => unsub()
  }, [])

  useEffect(() => {
    let cancelled = false
    async function load() {
      setLoading(true)
      try {
        const [skillsCount, jobsList] = await Promise.all([getSkillsDefinedCount(), fetchJobs()])
        if (cancelled) return
        setJobs(jobsList)
        setStats((s) => ({
          ...s,
          jobRoles: jobsList.length,
          skillsDefined: skillsCount,
        }))
      } catch (_) {
        if (!cancelled) setStats((s) => ({ ...s }))
      } finally {
        if (!cancelled) setLoading(false)
      }
    }
    load()
    return () => { cancelled = true }
  }, [])

  useEffect(() => {
    const now = new Date()
    const todayStr = now.toDateString()
    const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1)
    let newThisMonth = 0
    let assessments = 0
    let activeToday = 0
    users.forEach((u) => {
      const created = u.created_at as { toDate?: () => Date } | undefined
      if (created?.toDate && created.toDate() >= startOfMonth) newThisMonth++
      if (u.last_analysis) assessments++
      const at = u.last_analysis_at as { toDate?: () => Date } | undefined
      if (at?.toDate && at.toDate().toDateString() === todayStr) activeToday++
    })
    setStats((s) => ({
      ...s,
      totalUsers: users.length,
      newThisMonth,
      assessments,
      activeToday,
    }))
  }, [users, loading])

  useEffect(() => {
    if (users.length === 0 && jobs.length === 0) return
    const jobData = aggregateJobSelections(users)
    const gapData = aggregateSkillGaps(users, jobs)
    const weekData = aggregateWeeklyActivity(users)
    const academicData = aggregateAcademicLevels(users)
    const insights = buildQuickInsights(users, jobs, jobData, gapData)
    setJobRolesData(jobData.length ? jobData : [{ name: 'No data', count: 0 }])
    setSkillGapsData(gapData.length ? gapData : [{ name: 'No data', percent: 0 }])
    setWeeklyActivity(weekData)
    setAcademicLevels(academicData.length ? academicData : [{ name: 'No data', value: 1, color: '#8b5cf6' }])
    setQuickInsights(insights.length ? insights : ['Connect Firestore to see insights'])
  }, [users, jobs])

  const totalUsersPrev = Math.max(0, stats.totalUsers - stats.newThisMonth)
  const newPercent = totalUsersPrev > 0 ? ((stats.newThisMonth / totalUsersPrev) * 100).toFixed(1) : '0'

  const statCards = [
    { label: 'Total Users', value: loading ? '…' : stats.totalUsers.toLocaleString(), icon: Users, bg: 'bg-purple-100', iconColor: 'text-purple-600' },
    { label: 'New This Month', value: loading ? '…' : stats.newThisMonth.toString(), badge: loading ? undefined : `+${newPercent}%`, icon: UserCheck, bg: 'bg-blue-100', iconColor: 'text-blue-600' },
    { label: 'Job Roles', value: loading ? '…' : stats.jobRoles.toString(), icon: Briefcase, bg: 'bg-green-100', iconColor: 'text-green-600' },
    { label: 'Skills Defined', value: loading ? '…' : stats.skillsDefined.toString(), icon: Award, bg: 'bg-orange-100', iconColor: 'text-orange-600' },
    { label: 'Assessments', value: loading ? '…' : stats.assessments.toLocaleString(), icon: TrendingUp, bg: 'bg-indigo-100', iconColor: 'text-indigo-600' },
    { label: 'Active Today', value: loading ? '…' : stats.activeToday.toString(), icon: Activity, bg: 'bg-pink-100', iconColor: 'text-pink-600' },
  ]

  return (
    <>
      <div className="grid grid-cols-2 gap-4">
        {statCards.map(({ label, value, badge, icon: Icon, bg, iconColor }) => (
          <div
            key={label}
            className="bg-white rounded-2xl shadow-sm border border-gray-200 p-4 flex items-center gap-3"
          >
            <div className={`p-2 rounded-xl ${bg}`}>
              <Icon className={`w-6 h-6 ${iconColor}`} />
            </div>
            <div className="flex-1 min-w-0">
              <p className="text-lg font-bold text-gray-900">{value}</p>
              <p className="text-xs text-gray-500">{label}</p>
            </div>
            {badge && (
              <span className="text-xs font-medium bg-green-100 text-green-700 px-2 py-0.5 rounded-full">
                {badge}
              </span>
            )}
          </div>
        ))}
      </div>

      <div className="bg-white rounded-2xl shadow-sm border border-gray-200 p-4">
        <h3 className="font-bold text-gray-900 mb-4">Most Selected Job Roles</h3>
        <ResponsiveContainer width="100%" height={220}>
          <BarChart data={jobRolesData} margin={{ top: 8, right: 8, left: 0, bottom: 24 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
            <XAxis dataKey="name" tick={{ fontSize: 10 }} angle={-20} textAnchor="end" height={50} />
            <YAxis tick={{ fontSize: 10 }} />
            <Tooltip
              contentStyle={{ background: 'white', border: '1px solid #e5e7eb', borderRadius: 8 }}
            />
            <Bar dataKey="count" fill="#8b5cf6" radius={[4, 4, 0, 0]} isAnimationActive={false} />
          </BarChart>
        </ResponsiveContainer>
      </div>

      <div className="bg-white rounded-2xl shadow-sm border border-gray-200 p-4">
        <h3 className="font-bold text-gray-900 mb-4">Most Common Skill Gaps (%)</h3>
        <ResponsiveContainer width="100%" height={220}>
          <BarChart
            data={skillGapsData}
            layout="vertical"
            margin={{ top: 8, right: 24, left: 80, bottom: 8 }}
          >
            <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
            <XAxis type="number" domain={[0, 60]} tick={{ fontSize: 10 }} />
            <YAxis type="category" dataKey="name" tick={{ fontSize: 10 }} width={75} />
            <Tooltip
              contentStyle={{ background: 'white', border: '1px solid #e5e7eb', borderRadius: 8 }}
            />
            <Bar dataKey="percent" fill="#f59e0b" radius={[0, 4, 4, 0]} isAnimationActive={false} />
          </BarChart>
        </ResponsiveContainer>
      </div>

      <div className="bg-white rounded-2xl shadow-sm border border-gray-200 p-4">
        <h3 className="font-bold text-gray-900 mb-4">Weekly Assessment Activity</h3>
        <ResponsiveContainer width="100%" height={220}>
          <LineChart data={weeklyActivity} margin={{ top: 8, right: 8, left: 0, bottom: 8 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
            <XAxis dataKey="day" tick={{ fontSize: 10 }} />
            <YAxis tick={{ fontSize: 10 }} />
            <Tooltip
              contentStyle={{ background: 'white', border: '1px solid #e5e7eb', borderRadius: 8 }}
            />
            <Line
              type="monotone"
              dataKey="count"
              stroke="#6366f1"
              strokeWidth={3}
              dot={{ fill: '#6366f1', r: 4 }}
              isAnimationActive={false}
            />
          </LineChart>
        </ResponsiveContainer>
      </div>

      <div className="bg-white rounded-2xl shadow-sm border border-gray-200 p-4">
        <h3 className="font-bold text-gray-900 mb-4">Users by Academic Level</h3>
        <ResponsiveContainer width="100%" height={240}>
          <PieChart>
            <Pie
              data={academicLevels}
              cx="50%"
              cy="50%"
              innerRadius={50}
              outerRadius={80}
              paddingAngle={2}
              dataKey="value"
              nameKey="name"
              label={({ name, value }) => `${name} ${value}`}
              isAnimationActive={false}
            >
              {academicLevels.map((entry, i) => (
                <Cell key={i} fill={entry.color} />
              ))}
            </Pie>
            <Legend
              layout="horizontal"
              align="center"
              verticalAlign="bottom"
              formatter={(value, entry) => (
                <span className="text-xs flex items-center gap-1">
                  <span
                    className="inline-block w-2 h-2 rounded-full"
                    style={{ background: (entry as { payload?: { color: string } }).payload?.color }}
                  />
                  {value}
                </span>
              )}
            />
          </PieChart>
        </ResponsiveContainer>
      </div>

      <div className="bg-gradient-to-r from-purple-600 to-indigo-600 rounded-2xl shadow-sm border border-gray-200 p-4 text-white">
        <h3 className="font-bold flex items-center gap-2 mb-3">
          <TrendingUp className="w-5 h-5" />
          Quick Insights
        </h3>
        <ul className="space-y-2 text-sm">
          {quickInsights.map((insight, i) => (
            <li key={i} className="flex gap-2">
              <span className="text-white/80">•</span>
              <span>{insight}</span>
            </li>
          ))}
        </ul>
      </div>
    </>
  )
}
