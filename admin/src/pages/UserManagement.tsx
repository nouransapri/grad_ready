import { useState } from 'react'
import { Mail, Calendar, Eye, Download, X } from 'lucide-react'
import { toast } from 'sonner'

interface User {
  id: string
  name: string
  email: string
  academicLevel: string
  major: string
  readinessScore: number
  assessmentsCount: number
  status: 'active' | 'inactive'
  joinDate: string
  lastActive: string
}

const mockUsers: User[] = [
  { id: '1', name: 'Ahmed Hassan', email: 'ahmed@example.com', academicLevel: "Bachelor's", major: 'Computer Science', readinessScore: 78, assessmentsCount: 5, status: 'active', joinDate: '2025-01-15', lastActive: '2 days ago' },
  { id: '2', name: 'Sarah Mohamed', email: 'sarah@example.com', academicLevel: "Master's", major: 'Data Science', readinessScore: 85, assessmentsCount: 8, status: 'active', joinDate: '2025-02-01', lastActive: '1 day ago' },
  { id: '3', name: 'Omar Ali', email: 'omar@example.com', academicLevel: "Bachelor's", major: 'Software Engineering', readinessScore: 92, assessmentsCount: 12, status: 'active', joinDate: '2024-11-20', lastActive: '5 hours ago' },
  { id: '4', name: 'Nour Ibrahim', email: 'nour@example.com', academicLevel: 'PhD', major: 'AI', readinessScore: 88, assessmentsCount: 6, status: 'active', joinDate: '2025-03-10', lastActive: '3 days ago' },
  { id: '5', name: 'Karim Mahmoud', email: 'karim@example.com', academicLevel: "Bachelor's", major: 'Information Systems', readinessScore: 65, assessmentsCount: 3, status: 'inactive', joinDate: '2024-09-05', lastActive: '3 weeks ago' },
]

function getScoreColor(score: number): string {
  if (score >= 80) return 'bg-green-100 text-green-700'
  if (score >= 60) return 'bg-blue-100 text-blue-700'
  return 'bg-orange-100 text-orange-700'
}

export default function UserManagement() {
  const [users] = useState<User[]>(mockUsers)
  const [search, setSearch] = useState('')
  const [filter, setFilter] = useState<'All' | 'Active' | 'Inactive'>('All')
  const [viewUser, setViewUser] = useState<User | null>(null)

  const filtered = users.filter((u) => {
    const matchSearch =
      u.name.toLowerCase().includes(search.toLowerCase()) ||
      u.email.toLowerCase().includes(search.toLowerCase()) ||
      u.major.toLowerCase().includes(search.toLowerCase())
    const matchFilter =
      filter === 'All' || (filter === 'Active' && u.status === 'active') || (filter === 'Inactive' && u.status === 'inactive')
    return matchSearch && matchFilter
  })

  const total = users.length
  const activeCount = users.filter((u) => u.status === 'active').length
  const inactiveCount = users.filter((u) => u.status === 'inactive').length
  const avgAssessments = Math.round(users.reduce((a, u) => a + u.assessmentsCount, 0) / users.length)

  const handleExportUserData = () => {
    toast.success('User data export started')
  }

  return (
    <>
      <div className="grid grid-cols-2 gap-4">
        <div className="bg-white rounded-2xl shadow-sm border border-gray-200 p-4 text-center">
          <p className="text-xl font-bold">{total}</p>
          <p className="text-xs text-gray-500">Total Users</p>
        </div>
        <div className="bg-white rounded-2xl shadow-sm border border-gray-200 p-4 text-center">
          <p className="text-xl font-bold text-green-600">{activeCount}</p>
          <p className="text-xs text-gray-500">Active Users</p>
        </div>
        <div className="bg-white rounded-2xl shadow-sm border border-gray-200 p-4 text-center">
          <p className="text-xl font-bold text-orange-600">{inactiveCount}</p>
          <p className="text-xs text-gray-500">Inactive Users</p>
        </div>
        <div className="bg-white rounded-2xl shadow-sm border border-gray-200 p-4 text-center">
          <p className="text-xl font-bold text-blue-600">{avgAssessments}</p>
          <p className="text-xs text-gray-500">Avg Assessments</p>
        </div>
      </div>

      <input
        type="text"
        placeholder="Search by name, email, or major"
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        className="w-full px-4 py-2 rounded-xl border border-gray-300 focus:ring-2 focus:ring-purple-500"
      />
      <div className="flex gap-2">
        {(['All', 'Active', 'Inactive'] as const).map((f) => (
          <button
            key={f}
            onClick={() => setFilter(f)}
            className={`px-4 py-2 rounded-xl text-sm font-medium ${
              filter === f ? 'bg-purple-600 text-white' : 'bg-white border border-gray-200'
            }`}
          >
            {f} {f === 'All' ? total : f === 'Active' ? activeCount : inactiveCount}
          </button>
        ))}
      </div>

      <div className="space-y-4">
        {filtered.map((u) => (
          <div
            key={u.id}
            className="bg-white rounded-2xl shadow-sm border border-gray-200 p-4 hover:shadow-md transition"
          >
            <div className="flex items-start justify-between">
              <div>
                <div className="flex items-center gap-2">
                  <h4 className="font-bold text-gray-900">{u.name}</h4>
                  <span
                    className={`px-2 py-0.5 rounded-full text-xs ${
                      u.status === 'active' ? 'bg-green-100 text-green-700' : 'bg-gray-100 text-gray-600'
                    }`}
                  >
                    {u.status}
                  </span>
                </div>
                <p className="text-sm text-gray-600 flex items-center gap-1 mt-1">
                  <Mail className="w-4 h-4" />
                  {u.email}
                </p>
                <p className="text-sm text-gray-500 mt-1">
                  {u.academicLevel} • {u.major}
                </p>
              </div>
              <button
                onClick={() => setViewUser(u)}
                className="p-2 rounded-xl bg-purple-100 text-purple-600 hover:bg-purple-200"
              >
                <Eye className="w-4 h-4" />
              </button>
            </div>
            <div className="flex flex-wrap gap-2 mt-3">
              <span className={`px-2 py-0.5 rounded-lg text-xs font-medium ${getScoreColor(u.readinessScore)}`}>
                Score: {u.readinessScore}%
              </span>
              <span className="px-2 py-0.5 rounded-lg bg-blue-100 text-blue-700 text-xs">
                {u.assessmentsCount} assessments
              </span>
              <span className="text-xs text-gray-500 flex items-center gap-1">
                <Calendar className="w-3 h-3" />
                Joined {u.joinDate} • Last active {u.lastActive}
              </span>
            </div>
          </div>
        ))}
      </div>

      {viewUser && (
        <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50">
          <div className="bg-white rounded-2xl shadow-xl max-w-md w-full max-h-[90vh] overflow-y-auto">
            <div className="bg-gradient-to-r from-purple-600 to-indigo-600 text-white p-6 rounded-t-2xl">
              <div className="flex justify-between items-start">
                <div>
                  <h2 className="text-xl font-bold">{viewUser.name}</h2>
                  <p className="text-white/90 text-sm">{viewUser.email}</p>
                </div>
                <button
                  onClick={() => setViewUser(null)}
                  className="p-2 rounded-xl hover:bg-white/20"
                >
                  <X className="w-5 h-5" />
                </button>
              </div>
            </div>
            <div className="p-6 space-y-4">
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <p className="text-xs text-gray-500">Academic Level</p>
                  <p className="font-medium">{viewUser.academicLevel}</p>
                </div>
                <div>
                  <p className="text-xs text-gray-500">Major</p>
                  <p className="font-medium">{viewUser.major}</p>
                </div>
              </div>
              <div className="bg-green-50 rounded-xl p-4 border border-green-200">
                <p className="text-sm text-gray-600 mb-2">Readiness score</p>
                <div className="flex items-center gap-2">
                  <div className="flex-1 h-3 rounded-full bg-gray-200 overflow-hidden">
                    <div
                      className="h-full rounded-full bg-green-500"
                      style={{ width: `${viewUser.readinessScore}%` }}
                    />
                  </div>
                  <span className="font-bold text-green-700">{viewUser.readinessScore}%</span>
                </div>
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <p className="text-xs text-gray-500">Assessments</p>
                  <p className="font-medium">{viewUser.assessmentsCount}</p>
                </div>
                <div>
                  <p className="text-xs text-gray-500">Status</p>
                  <p className="font-medium capitalize">{viewUser.status}</p>
                </div>
              </div>
              <p className="text-sm text-gray-500 flex items-center gap-1">
                <Calendar className="w-4 h-4" />
                Join date: {viewUser.joinDate} • Last active: {viewUser.lastActive}
              </p>
              <button
                onClick={handleExportUserData}
                className="w-full py-3 rounded-xl bg-purple-600 text-white font-medium flex items-center justify-center gap-2 hover:bg-purple-700"
              >
                <Download className="w-5 h-5" />
                Export User Data
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  )
}
