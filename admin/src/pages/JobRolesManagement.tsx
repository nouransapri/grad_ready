import { useState } from 'react'
import { Plus, Search, Edit2, X } from 'lucide-react'
import { toast } from 'sonner'
import {
  jobRolesDatabase,
  getUniqueCategories,
  getHighDemandCount,
  type JobRole,
  type SkillProficiency,
  type DemandLevel,
} from '../utils/jobDatabase'

const demandColors: Record<DemandLevel, string> = {
  High: 'bg-red-100 text-red-700',
  Growing: 'bg-green-100 text-green-700',
  Medium: 'bg-yellow-100 text-yellow-700',
  Stable: 'bg-blue-100 text-blue-700',
}

export default function JobRolesManagement() {
  const [roles, setRoles] = useState<JobRole[]>(() => [...jobRolesDatabase])
  const [isAddingRole, setIsAddingRole] = useState(false)
  const [editingId, setEditingId] = useState<string | null>(null)
  const [searchQuery, setSearchQuery] = useState('')
  const [categoryFilter, setCategoryFilter] = useState('All Categories')
  const [newRole, setNewRole] = useState({
    title: '',
    description: '',
    category: '',
    demand: 'High' as DemandLevel,
    salaryRange: '',
    technicalSkills: [] as SkillProficiency[],
    softSkills: [] as SkillProficiency[],
  })
  const [newSkillName, setNewSkillName] = useState('')
  const [newSkillLevel, setNewSkillLevel] = useState(50)
  const [newSkillType, setNewSkillType] = useState<'technical' | 'soft'>('technical')

  const categories = ['All Categories', ...getUniqueCategories(roles)]
  const totalRoles = roles.length
  const highDemand = getHighDemandCount(roles)
  const categoriesCount = getUniqueCategories(roles).length

  const filteredRoles = roles
    .filter((r) => {
      const matchSearch =
        r.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
        r.description.toLowerCase().includes(searchQuery.toLowerCase())
      const matchCat = categoryFilter === 'All Categories' || r.category === categoryFilter
      return matchSearch && matchCat
    })
    .slice(0, 15)

  const canSave =
    newRole.title.trim() &&
    newRole.description.trim() &&
    newRole.category.trim() &&
    (newRole.technicalSkills.length > 0 || newRole.softSkills.length > 0)

  const addSkill = () => {
    if (!newSkillName.trim()) return
    const skill = { name: newSkillName.trim(), percent: newSkillLevel }
    if (newSkillType === 'technical') {
      setNewRole((r) => ({ ...r, technicalSkills: [...r.technicalSkills, skill] }))
    } else {
      setNewRole((r) => ({ ...r, softSkills: [...r.softSkills, skill] }))
    }
    setNewSkillName('')
    setNewSkillLevel(50)
  }

  const removeSkill = (type: 'technical' | 'soft', index: number) => {
    if (type === 'technical') {
      setNewRole((r) => ({
        ...r,
        technicalSkills: r.technicalSkills.filter((_, i) => i !== index),
      }))
    } else {
      setNewRole((r) => ({
        ...r,
        softSkills: r.softSkills.filter((_, i) => i !== index),
      }))
    }
  }

  const handleSave = () => {
    if (!canSave) return
    const [minS, maxS] = newRole.salaryRange.replace(/[$,Kk]/g, '').split('-').map((s) => parseInt(s.trim(), 10) || 0)
    const newItem: JobRole = {
      id: String(Date.now()),
      title: newRole.title,
      description: newRole.description,
      category: newRole.category,
      demand: newRole.demand,
      isHighDemand: newRole.demand === 'High',
      salaryMinK: minS || 70,
      salaryMaxK: maxS || 110,
      requiredSkills: [...newRole.technicalSkills, ...newRole.softSkills].map((s) => s.name),
      requiredCourses: [],
      technicalSkillsWithLevel: newRole.technicalSkills,
      softSkillsWithLevel: newRole.softSkills,
    }
    setRoles((r) => [newItem, ...r])
    setNewRole({
      title: '',
      description: '',
      category: '',
      demand: 'High',
      salaryRange: '',
      technicalSkills: [],
      softSkills: [],
    })
    setIsAddingRole(false)
    toast.success('Job role added')
  }

  const cancelForm = () => {
    setIsAddingRole(false)
    setEditingId(null)
    setNewRole({
      title: '',
      description: '',
      category: '',
      demand: 'High',
      salaryRange: '',
      technicalSkills: [],
      softSkills: [],
    })
  }

  return (
    <>
      <div className="grid grid-cols-3 gap-4">
        <div className="bg-white rounded-2xl shadow-sm border border-gray-200 p-4 text-center">
          <p className="text-2xl font-bold text-purple-600">{totalRoles}</p>
          <p className="text-xs text-gray-500">Total Roles</p>
        </div>
        <div className="bg-white rounded-2xl shadow-sm border border-gray-200 p-4 text-center">
          <p className="text-2xl font-bold text-red-600">{highDemand}</p>
          <p className="text-xs text-gray-500">High Demand</p>
        </div>
        <div className="bg-white rounded-2xl shadow-sm border border-gray-200 p-4 text-center">
          <p className="text-2xl font-bold text-blue-600">{categoriesCount}</p>
          <p className="text-xs text-gray-500">Categories</p>
        </div>
      </div>

      <button
        onClick={() => setIsAddingRole(true)}
        className="w-full py-3 rounded-xl bg-gradient-to-r from-purple-600 to-indigo-600 text-white font-medium flex items-center justify-center gap-2"
      >
        <Plus className="w-5 h-5" />
        Add New Job Role
      </button>

      {isAddingRole && (
        <div className="bg-white rounded-2xl shadow-sm border border-gray-200 p-4 space-y-4">
          <h3 className="font-bold">Add / Edit Job Role</h3>
          <input
            type="text"
            placeholder="Job Title *"
            value={newRole.title}
            onChange={(e) => setNewRole((r) => ({ ...r, title: e.target.value }))}
            className="w-full px-4 py-2 rounded-xl border border-gray-300 focus:ring-2 focus:ring-purple-500"
          />
          <textarea
            placeholder="Description *"
            value={newRole.description}
            onChange={(e) => setNewRole((r) => ({ ...r, description: e.target.value }))}
            rows={3}
            className="w-full px-4 py-2 rounded-xl border border-gray-300 focus:ring-2 focus:ring-purple-500"
          />
          <input
            type="text"
            placeholder="Category *"
            value={newRole.category}
            onChange={(e) => setNewRole((r) => ({ ...r, category: e.target.value }))}
            className="w-full px-4 py-2 rounded-xl border border-gray-300 focus:ring-2 focus:ring-purple-500"
          />
          <select
            value={newRole.demand}
            onChange={(e) => setNewRole((r) => ({ ...r, demand: e.target.value as DemandLevel }))}
            className="w-full px-4 py-2 rounded-xl border border-gray-300 focus:ring-2 focus:ring-purple-500"
          >
            <option value="High">High</option>
            <option value="Medium">Medium</option>
            <option value="Growing">Growing</option>
            <option value="Stable">Stable</option>
          </select>
          <input
            type="text"
            placeholder="$70K - $110K"
            value={newRole.salaryRange}
            onChange={(e) => setNewRole((r) => ({ ...r, salaryRange: e.target.value }))}
            className="w-full px-4 py-2 rounded-xl border border-gray-300 focus:ring-2 focus:ring-purple-500"
          />
          <div>
            <p className="text-sm font-medium mb-2">Skills</p>
            <div className="flex gap-2 mb-2">
              <button
                type="button"
                onClick={() => setNewSkillType('technical')}
                className={`px-3 py-1 rounded-lg text-sm ${newSkillType === 'technical' ? 'bg-purple-100 text-purple-700' : 'bg-gray-100'}`}
              >
                Technical
              </button>
              <button
                type="button"
                onClick={() => setNewSkillType('soft')}
                className={`px-3 py-1 rounded-lg text-sm ${newSkillType === 'soft' ? 'bg-blue-100 text-blue-700' : 'bg-gray-100'}`}
              >
                Soft Skills
              </button>
            </div>
            <div className="flex gap-2 flex-wrap">
              <input
                type="text"
                placeholder="Skill name"
                value={newSkillName}
                onChange={(e) => setNewSkillName(e.target.value)}
                className="flex-1 min-w-0 px-3 py-2 rounded-lg border border-gray-300"
              />
              <input
                type="number"
                min={0}
                max={100}
                value={newSkillLevel}
                onChange={(e) => setNewSkillLevel(Number(e.target.value))}
                className="w-16 px-2 py-2 rounded-lg border border-gray-300"
              />
              <button
                type="button"
                onClick={addSkill}
                className="p-2 rounded-lg bg-purple-100 text-purple-600 hover:bg-purple-200"
              >
                <Plus className="w-4 h-4" />
              </button>
            </div>
            <div className="flex flex-wrap gap-2 mt-2">
              {newRole.technicalSkills.map((s, i) => (
                <span
                  key={`t-${i}`}
                  className="inline-flex items-center gap-1 px-2 py-1 rounded-lg bg-purple-50 border border-purple-200 text-sm"
                >
                  {s.name} ({s.percent}%)
                  <button type="button" onClick={() => removeSkill('technical', i)}>
                    <X className="w-3 h-3" />
                  </button>
                </span>
              ))}
              {newRole.softSkills.map((s, i) => (
                <span
                  key={`s-${i}`}
                  className="inline-flex items-center gap-1 px-2 py-1 rounded-lg bg-blue-50 border border-blue-200 text-sm"
                >
                  {s.name} ({s.percent}%)
                  <button type="button" onClick={() => removeSkill('soft', i)}>
                    <X className="w-3 h-3" />
                  </button>
                </span>
              ))}
            </div>
          </div>
          <div className="flex gap-2">
            <button
              onClick={handleSave}
              disabled={!canSave}
              className="flex-1 py-2 rounded-xl bg-purple-600 text-white font-medium disabled:opacity-50"
            >
              Save
            </button>
            <button
              onClick={cancelForm}
              className="px-4 py-2 rounded-xl border border-gray-300"
            >
              Cancel
            </button>
          </div>
        </div>
      )}

      <div className="flex flex-col gap-2">
        <div className="relative">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
          <input
            type="text"
            placeholder="Search job roles..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pl-10 pr-4 py-2 rounded-xl border border-gray-300 focus:ring-2 focus:ring-purple-500"
          />
        </div>
        <select
          value={categoryFilter}
          onChange={(e) => setCategoryFilter(e.target.value)}
          className="w-full px-4 py-2 rounded-xl border border-gray-300 focus:ring-2 focus:ring-purple-500"
        >
          {categories.map((c) => (
            <option key={c} value={c}>
              {c}
            </option>
          ))}
        </select>
      </div>

      <div className="space-y-4">
        {filteredRoles.map((role) => (
          <div
            key={role.id}
            className="bg-white rounded-2xl shadow-sm border border-gray-200 p-4 hover:shadow-md transition relative"
          >
            <button
              className="absolute top-4 right-4 p-1 rounded-lg hover:bg-gray-100"
              onClick={() => setEditingId(editingId === role.id ? null : role.id)}
            >
              <Edit2 className="w-4 h-4 text-gray-600" />
            </button>
            <h4 className="font-bold text-gray-900 pr-8">{role.title}</h4>
            <p className="text-sm text-gray-600 mt-1">{role.description}</p>
            <div className="flex flex-wrap gap-2 mt-3">
              <span className="px-2 py-0.5 rounded-lg bg-purple-100 text-purple-700 text-xs">
                {role.category}
              </span>
              <span
                className={`px-2 py-0.5 rounded-lg text-xs ${demandColors[role.demand || 'High']}`}
              >
                {role.demand || (role.isHighDemand ? 'High' : 'Medium')}
              </span>
              <span className="px-2 py-0.5 rounded-lg bg-blue-100 text-blue-700 text-xs">
                {role.requiredSkills.length} skills
              </span>
              <span className="px-2 py-0.5 rounded-lg bg-green-100 text-green-700 text-xs">
                ${role.salaryMinK}K - ${role.salaryMaxK}K
              </span>
            </div>
          </div>
        ))}
      </div>
    </>
  )
}
