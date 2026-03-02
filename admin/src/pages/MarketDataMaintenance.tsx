import { useState } from 'react'
import { AlertTriangle, RefreshCw, CheckCircle, Calendar, TrendingUp } from 'lucide-react'
import { toast } from 'sonner'
import { jobRolesDatabase } from '../utils/jobDatabase'

const OUTDATED_DAYS = 180

function getDaysAgo(dateStr: string): number {
  const d = new Date(dateStr)
  const now = new Date()
  const diff = now.getTime() - d.getTime()
  return Math.floor(diff / (1000 * 60 * 60 * 24))
}

function formatDate(dateStr: string): string {
  return new Date(dateStr).toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
  })
}

type RoleWithMeta = (typeof jobRolesDatabase)[0] & { daysAgo: number; isOutdated: boolean }

export default function MarketDataMaintenance() {
  const rolesWithMeta: RoleWithMeta[] = jobRolesDatabase.map((r) => {
    const last = r.lastUpdated || '2024-01-01'
    const daysAgo = getDaysAgo(last)
    return { ...r, daysAgo, isOutdated: daysAgo > OUTDATED_DAYS }
  })

  const outdated = rolesWithMeta.filter((r) => r.isOutdated)
  const upToDate = rolesWithMeta.filter((r) => !r.isOutdated)
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set())

  const totalRoles = rolesWithMeta.length
  const needUpdate = outdated.length
  const upToDateCount = upToDate.length

  const handleSelectRole = (id: string) => {
    setSelectedIds((prev) => {
      const next = new Set(prev)
      if (next.has(id)) next.delete(id)
      else next.add(id)
      return next
    })
  }

  const handleSelectAllOutdated = () => {
    if (selectedIds.size === outdated.length) {
      setSelectedIds(new Set())
    } else {
      setSelectedIds(new Set(outdated.map((r) => r.id)))
    }
  }

  const handleBulkUpdate = () => {
    if (selectedIds.size === 0) {
      toast.error('Select at least one role to update')
      return
    }
    toast.success(`Update requested for ${selectedIds.size} role(s)`)
    setSelectedIds(new Set())
  }

  const marketInsights = [
    'Regular updates ensure students receive accurate market information',
    'Review job requirements quarterly to reflect industry trends',
    'Update proficiency levels based on employer feedback',
    'Mark deprecated skills and add emerging technologies',
  ]

  return (
    <>
      {outdated.length > 0 && (
        <div className="rounded-2xl border-l-4 border-orange-500 bg-orange-50 p-4 flex gap-3">
          <AlertTriangle className="w-6 h-6 text-orange-600 shrink-0" />
          <div>
            <p className="font-semibold text-orange-900">Market Data Needs Attention</p>
            <p className="text-sm text-orange-800">
              {needUpdate} job role(s) haven&apos;t been updated in over 6 months. Please review and
              update to ensure accuracy.
            </p>
          </div>
        </div>
      )}

      <div className="grid grid-cols-2 gap-4">
        <div className="bg-white rounded-2xl shadow-sm border border-gray-200 p-4 text-center">
          <p className="text-xl font-bold text-purple-600">{totalRoles}</p>
          <p className="text-xs text-gray-500">Total Roles</p>
        </div>
        <div className="bg-white rounded-2xl shadow-sm border border-gray-200 p-4 text-center">
          <p className="text-xl font-bold text-orange-600">{needUpdate}</p>
          <p className="text-xs text-gray-500">Need Update</p>
        </div>
        <div className="bg-white rounded-2xl shadow-sm border border-gray-200 p-4 text-center">
          <p className="text-xl font-bold text-green-600">{upToDateCount}</p>
          <p className="text-xs text-gray-500">Up to Date</p>
        </div>
        <div className="bg-white rounded-2xl shadow-sm border border-gray-200 p-4 text-center">
          <p className="text-xl font-bold text-blue-600">{selectedIds.size}</p>
          <p className="text-xs text-gray-500">Selected</p>
        </div>
      </div>

      <div className="bg-white rounded-2xl shadow-sm border border-gray-200 p-4">
        <h3 className="font-bold text-gray-900 mb-3">Bulk Actions</h3>
        <div className="flex gap-2 flex-wrap">
          <button
            onClick={handleSelectAllOutdated}
            className="px-4 py-2 rounded-xl bg-orange-100 text-orange-700 font-medium text-sm hover:bg-orange-200"
          >
            Select All Outdated
          </button>
          <button
            onClick={handleBulkUpdate}
            disabled={selectedIds.size === 0}
            className="flex items-center gap-2 px-4 py-2 rounded-xl bg-purple-100 text-purple-700 font-medium text-sm disabled:opacity-50 disabled:cursor-not-allowed"
          >
            <RefreshCw className="w-4 h-4" />
            Update Selected
          </button>
        </div>
      </div>

      {outdated.length > 0 && (
        <div>
          <h3 className="font-bold text-gray-900 mb-2 flex items-center gap-2">
            <AlertTriangle className="w-5 h-5 text-orange-500" />
            Needs Update ({outdated.length})
          </h3>
          <div className="space-y-3">
            {outdated.map((r) => (
              <div
                key={r.id}
                onClick={() => handleSelectRole(r.id)}
                className={`bg-white rounded-2xl shadow-sm border p-4 cursor-pointer transition ${
                  selectedIds.has(r.id) ? 'border-purple-500 ring-2 ring-purple-200' : 'border-orange-200'
                }`}
              >
                <div className="flex items-start justify-between">
                  <div>
                    <h4 className="font-bold text-gray-900">{r.title}</h4>
                    <p className="text-sm text-gray-600">{r.category}</p>
                  </div>
                  {selectedIds.has(r.id) && (
                    <CheckCircle className="w-5 h-5 text-purple-600 shrink-0" />
                  )}
                </div>
                <div className="flex flex-wrap gap-2 mt-2">
                  <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-lg bg-orange-100 text-orange-700 text-xs">
                    <Calendar className="w-3 h-3" />
                    {r.daysAgo} days ago
                  </span>
                  <span className="px-2 py-0.5 rounded-lg bg-gray-100 text-gray-700 text-xs">
                    {r.requiredSkills.length} skills
                  </span>
                </div>
                <p className="text-xs text-gray-500 mt-2">Last updated: {formatDate(r.lastUpdated!)}</p>
                <p className="text-sm text-orange-600 font-medium mt-1">Review needed</p>
              </div>
            ))}
          </div>
        </div>
      )}

      <div>
        <h3 className="font-bold text-gray-900 mb-2 flex items-center gap-2">
          <CheckCircle className="w-5 h-5 text-green-500" />
          Up to Date ({upToDateCount})
        </h3>
        <div className="space-y-3">
          {upToDate.slice(0, 5).map((r) => (
            <div
              key={r.id}
              className="bg-white rounded-2xl shadow-sm border border-gray-200 border-l-4 border-l-green-500 p-4"
            >
              <div className="flex items-start justify-between">
                <div>
                  <h4 className="font-bold text-gray-900">{r.title}</h4>
                  <p className="text-sm text-gray-600">{r.category}</p>
                </div>
                <CheckCircle className="w-5 h-5 text-green-600 shrink-0" />
              </div>
              <div className="flex flex-wrap gap-2 mt-2">
                <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-lg bg-green-100 text-green-700 text-xs">
                  <Calendar className="w-3 h-3" />
                  {r.daysAgo} days ago
                </span>
                <span className="px-2 py-0.5 rounded-lg bg-gray-100 text-gray-700 text-xs">
                  {r.requiredSkills.length} skills
                </span>
              </div>
              <p className="text-xs text-gray-500 mt-2">Last updated: {formatDate(r.lastUpdated!)}</p>
              <p className="text-sm text-green-600 font-medium mt-1">Current</p>
            </div>
          ))}
        </div>
        {upToDateCount > 5 && (
          <p className="text-sm text-gray-500 mt-2">
            Showing first 5 of {upToDateCount} up-to-date roles.
          </p>
        )}
      </div>

      <div className="bg-gradient-to-r from-cyan-500 to-blue-600 rounded-2xl shadow-sm border border-gray-200 p-4 text-white">
        <h3 className="font-bold flex items-center gap-2 mb-3">
          <TrendingUp className="w-5 h-5" />
          Market Insights
        </h3>
        <ul className="space-y-2 text-sm">
          {marketInsights.map((tip, i) => (
            <li key={i} className="flex gap-2">
              <span>•</span>
              <span>{tip}</span>
            </li>
          ))}
        </ul>
      </div>
    </>
  )
}
