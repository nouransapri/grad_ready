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

const statCards = [
  { label: 'Total Users', value: '1,247', icon: Users, bg: 'bg-purple-100', iconColor: 'text-purple-600' },
  { label: 'New This Month', value: '183', badge: '+14.7%', icon: UserCheck, bg: 'bg-blue-100', iconColor: 'text-blue-600' },
  { label: 'Job Roles', value: '32', icon: Briefcase, bg: 'bg-green-100', iconColor: 'text-green-600' },
  { label: 'Skills Defined', value: '42', icon: Award, bg: 'bg-orange-100', iconColor: 'text-orange-600' },
  { label: 'Assessments', value: '3,891', icon: TrendingUp, bg: 'bg-indigo-100', iconColor: 'text-indigo-600' },
  { label: 'Active Today', value: '89', icon: Activity, bg: 'bg-pink-100', iconColor: 'text-pink-600' },
]

const jobRolesData = [
  { name: 'Frontend Dev', count: 342 },
  { name: 'Data Analyst', count: 298 },
  { name: 'UX Designer', count: 267 },
  { name: 'Backend Dev', count: 245 },
  { name: 'Product Mgr', count: 198 },
]

const skillGapsData = [
  { name: 'Cloud Computing', percent: 35 },
  { name: 'Machine Learning', percent: 42 },
  { name: 'DevOps', percent: 28 },
  { name: 'Leadership', percent: 31 },
  { name: 'UI/UX Design', percent: 25 },
]

const weeklyActivity = [
  { day: 'Mon', count: 45 },
  { day: 'Tue', count: 52 },
  { day: 'Wed', count: 48 },
  { day: 'Thu', count: 61 },
  { day: 'Fri', count: 55 },
  { day: 'Sat', count: 38 },
  { day: 'Sun', count: 32 },
]

const academicLevels = [
  { name: 'Bachelor', value: 45, color: '#8b5cf6' },
  { name: 'Master', value: 30, color: '#6366f1' },
  { name: 'PhD', value: 10, color: '#3b82f6' },
  { name: 'Other', value: 15, color: '#10b981' },
]

const quickInsights = [
  'Frontend Developer is the most popular career choice (342 selections)',
  'Machine Learning has the largest skill gap across users (42%)',
  'User engagement peaks on Thursdays with 61 assessments',
  "45% of users hold Bachelor's degrees",
]

export default function AdminDashboard() {
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
            <Bar dataKey="count" fill="#8b5cf6" radius={[4, 4, 0, 0]} />
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
            <Bar dataKey="percent" fill="#f59e0b" radius={[0, 4, 4, 0]} />
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
              label={({ name, value }) => `${name} ${value}%`}
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
