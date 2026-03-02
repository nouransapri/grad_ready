import { useState } from 'react'
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

const jobRolesAnalytics = [
  { name: 'Frontend Developer', count: 342, pct: 15.2 },
  { name: 'Data Analyst', count: 298, pct: 13.3 },
  { name: 'UX Designer', count: 267, pct: 11.9 },
  { name: 'Backend Developer', count: 245, pct: 10.9 },
  { name: 'Product Manager', count: 198, pct: 8.8 },
  { name: 'Full Stack Dev', count: 176, pct: 7.8 },
  { name: 'Data Scientist', count: 152, pct: 6.8 },
]

const skillGapsAnalytics = [
  { name: 'Cloud Computing', percent: 35, count: 420 },
  { name: 'Machine Learning', percent: 42, count: 512 },
  { name: 'DevOps', percent: 28, count: 340 },
  { name: 'Leadership', percent: 31, count: 378 },
  { name: 'UI/UX Design', percent: 25, count: 298 },
  { name: 'Data Analysis', percent: 22, count: 265 },
  { name: 'Cybersecurity', percent: 19, count: 228 },
]

const radarData = [
  { skill: 'Programming', value: 85 },
  { skill: 'Communication', value: 78 },
  { skill: 'Problem Solving', value: 82 },
  { skill: 'Data Analysis', value: 65 },
  { skill: 'Cloud Computing', value: 58 },
  { skill: 'Leadership', value: 69 },
]

const timelineData = [
  { week: 'Week 1', count: 120 },
  { week: 'Week 2', count: 145 },
  { week: 'Week 3', count: 162 },
  { week: 'Week 4', count: 178 },
  { week: 'Week 5', count: 195 },
  { week: 'Week 6', count: 208 },
  { week: 'Week 7', count: 215 },
  { week: 'Week 8', count: 220 },
]

const userDist = [
  { name: "Bachelor's", value: 561, pct: 30 },
  { name: "Master's", value: 374, pct: 20 },
  { name: 'PhD', value: 125, pct: 10 },
  { name: 'Diploma', value: 125, pct: 10 },
  { name: 'Other', value: 62, pct: 5 },
]

const topSkills = [
  { name: 'JavaScript', count: 512 },
  { name: 'Python', count: 487 },
  { name: 'Communication', count: 456 },
  { name: 'React', count: 398 },
  { name: 'Data Analysis', count: 365 },
]

const jobCategoryDist = [
  { name: 'Development', percent: 35 },
  { name: 'Data & Analytics', percent: 22 },
  { name: 'Design', percent: 15 },
  { name: 'Marketing', percent: 12 },
  { name: 'Management', percent: 10 },
  { name: 'Other', percent: 6 },
]

const keyInsights = [
  'Development roles (Frontend, Backend, Full Stack) account for 34% of total selections',
  'Cloud Computing and Machine Learning are the top skill gaps requiring attention',
  'User engagement has grown consistently, with 47% increase in assessments',
  "45% of users hold Bachelor's degrees, indicating strong undergraduate adoption",
  'JavaScript and Python are the most commonly added technical skills',
]

const COLORS = ['#8b5cf6', '#6366f1', '#3b82f6', '#10b981', '#f59e0b']

export default function AnalyticsDashboard() {
  const [dateRange, setDateRange] = useState<'Week' | 'Month' | 'Year'>('Week')

  const handleExport = (format: 'pdf' | 'csv') => {
    toast.success(`${format.toUpperCase()} export started`)
  }

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
          <BarChart data={jobRolesAnalytics} margin={{ bottom: 40 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
            <XAxis dataKey="name" angle={-25} textAnchor="end" height={60} tick={{ fontSize: 10 }} />
            <YAxis tick={{ fontSize: 10 }} />
            <Tooltip contentStyle={{ borderRadius: 8, border: '1px solid #e5e7eb' }} />
            <Bar dataKey="count" fill="#8b5cf6" radius={[4, 4, 0, 0]} />
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
            data={skillGapsAnalytics}
            layout="vertical"
            margin={{ left: 100, right: 16 }}
          >
            <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
            <XAxis type="number" domain={[0, 60]} tick={{ fontSize: 10 }} />
            <YAxis type="category" dataKey="name" tick={{ fontSize: 10 }} width={95} />
            <Tooltip contentStyle={{ borderRadius: 8, border: '1px solid #e5e7eb' }} />
            <Bar dataKey="percent" fill="#f59e0b" radius={[0, 4, 4, 0]} />
          </BarChart>
        </ResponsiveContainer>
      </div>

      <div className="bg-white rounded-2xl shadow-sm border border-gray-200 p-4">
        <h3 className="font-bold text-gray-900 mb-4">Average Skills Coverage</h3>
        <ResponsiveContainer width="100%" height={260}>
          <RadarChart data={radarData}>
            <PolarGrid />
            <PolarAngleAxis dataKey="skill" tick={{ fontSize: 10 }} />
            <PolarRadiusAxis angle={30} domain={[0, 100]} tick={{ fontSize: 10 }} />
            <Radar
              name="Coverage"
              dataKey="value"
              stroke="#6366f1"
              fill="#6366f1"
              fillOpacity={0.6}
            />
          </RadarChart>
        </ResponsiveContainer>
      </div>

      <div className="bg-white rounded-2xl shadow-sm border border-gray-200 p-4">
        <h3 className="font-bold text-gray-900 mb-4">Assessment Activity Trend</h3>
        <ResponsiveContainer width="100%" height={200}>
          <LineChart data={timelineData} margin={{ left: 0, right: 8 }}>
            <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
            <XAxis dataKey="week" tick={{ fontSize: 10 }} />
            <YAxis tick={{ fontSize: 10 }} />
            <Tooltip contentStyle={{ borderRadius: 8, border: '1px solid #e5e7eb' }} />
            <Line type="monotone" dataKey="count" stroke="#6366f1" strokeWidth={2} dot={{ fill: '#6366f1' }} />
          </LineChart>
        </ResponsiveContainer>
        <div className="mt-3 p-3 rounded-xl bg-blue-50 border border-blue-100 text-sm text-blue-800">
          Trend: Assessment activity increased by 47% over the last 8 weeks.
        </div>
      </div>

      <div className="bg-white rounded-2xl shadow-sm border border-gray-200 p-4">
        <h3 className="font-bold text-gray-900 mb-4">Users by Academic Level</h3>
        <ResponsiveContainer width="100%" height={220}>
          <PieChart>
            <Pie
              data={userDist}
              cx="50%"
              cy="50%"
              innerRadius={45}
              outerRadius={70}
              paddingAngle={2}
              dataKey="value"
              nameKey="name"
              label={({ name, pct }) => `${name} ${pct}%`}
            >
              {userDist.map((_, i) => (
                <Cell key={i} fill={COLORS[i % COLORS.length]} />
              ))}
            </Pie>
            <Legend layout="horizontal" verticalAlign="bottom" formatter={(v, e) => `${v}: ${(e as { payload?: { value?: number } }).payload?.value ?? 0}`} />
          </PieChart>
        </ResponsiveContainer>
      </div>

      <div className="bg-white rounded-2xl shadow-sm border border-gray-200 p-4">
        <h3 className="font-bold text-gray-900 mb-4">Most Frequently Added Skills</h3>
        <div className="space-y-3">
          {topSkills.map((s, i) => (
            <div key={s.name} className="flex items-center gap-2">
              <span className="w-6 h-6 rounded-full bg-purple-100 text-purple-700 flex items-center justify-center text-xs font-bold shrink-0">
                {i + 1}
              </span>
              <span className="text-sm font-medium w-28 shrink-0">{s.name}</span>
              <div className="flex-1 h-3 rounded-full bg-gray-200 overflow-hidden">
                <div
                  className="h-full rounded-full bg-gradient-to-r from-purple-600 to-indigo-600"
                  style={{ width: `${(s.count / 512) * 100}%` }}
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
          {jobCategoryDist.map((c) => (
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
          {keyInsights.map((insight, i) => (
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
