import { useState } from 'react'
import { Plus, Trash2, Check } from 'lucide-react'
import { toast } from 'sonner'

type SkillCategory = 'Technical' | 'Soft Skill' | 'Language' | 'Tool'
type Relevance = 'High' | 'Medium' | 'Low'
type Status = 'Active' | 'Deprecated'

interface Skill {
  id: string
  name: string
  category: SkillCategory
  description: string
  relevance: Relevance
  status: Status
  usageCount: number
}

const mockSkills: Skill[] = [
  { id: '1', name: 'Programming', category: 'Technical', description: 'Code and develop software', relevance: 'High', status: 'Active', usageCount: 28 },
  { id: '2', name: 'Data Analysis', category: 'Technical', description: 'Analyze and interpret data', relevance: 'High', status: 'Active', usageCount: 25 },
  { id: '3', name: 'Cloud Computing', category: 'Technical', description: 'AWS, Azure, GCP', relevance: 'High', status: 'Active', usageCount: 22 },
  { id: '4', name: 'Machine Learning', category: 'Technical', description: 'ML models and algorithms', relevance: 'High', status: 'Active', usageCount: 20 },
  { id: '5', name: 'Communication', category: 'Soft Skill', description: 'Clear verbal and written communication', relevance: 'High', status: 'Active', usageCount: 30 },
  { id: '6', name: 'Problem Solving', category: 'Soft Skill', description: 'Analytical and critical thinking', relevance: 'High', status: 'Active', usageCount: 29 },
  { id: '7', name: 'Leadership', category: 'Soft Skill', description: 'Lead and motivate teams', relevance: 'High', status: 'Active', usageCount: 18 },
  { id: '8', name: 'UI/UX Design', category: 'Technical', description: 'User interface and experience design', relevance: 'High', status: 'Active', usageCount: 15 },
  { id: '9', name: 'Database Management', category: 'Technical', description: 'Design and manage databases', relevance: 'High', status: 'Active', usageCount: 22 },
  { id: '10', name: 'Teamwork', category: 'Soft Skill', description: 'Collaborate effectively with others', relevance: 'High', status: 'Active', usageCount: 27 },
]

const categoryColors: Record<SkillCategory, string> = {
  Technical: 'bg-purple-100 text-purple-700',
  'Soft Skill': 'bg-blue-100 text-blue-700',
  Language: 'bg-green-100 text-green-700',
  Tool: 'bg-orange-100 text-orange-700',
}
const relevanceColors: Record<Relevance, string> = {
  High: 'bg-green-100 text-green-700',
  Medium: 'bg-yellow-100 text-yellow-700',
  Low: 'bg-gray-100 text-gray-700',
}

export default function SkillsManagement() {
  const [skills, setSkills] = useState<Skill[]>(mockSkills)
  const [tab, setTab] = useState<'All' | 'Technical' | 'Soft'>('All')
  const [showAddForm, setShowAddForm] = useState(false)
  const [form, setForm] = useState({
    name: '',
    category: 'Technical' as SkillCategory,
    description: '',
    relevance: 'High' as Relevance,
  })

  const filtered =
    tab === 'All'
      ? skills
      : tab === 'Technical'
        ? skills.filter((s) => s.category === 'Technical')
        : skills.filter((s) => s.category === 'Soft Skill')

  const total = skills.length
  const active = skills.filter((s) => s.status === 'Active').length
  const technical = skills.filter((s) => s.category === 'Technical').length
  const soft = skills.filter((s) => s.category === 'Soft Skill').length

  const handleAddSkill = () => {
    if (!form.name.trim()) {
      toast.error('Skill name is required')
      return
    }
    setSkills((prev) => [
      ...prev,
      {
        id: String(Date.now()),
        ...form,
        status: 'Active',
        usageCount: 0,
      },
    ])
    setForm({ name: '', category: 'Technical', description: '', relevance: 'High' })
    setShowAddForm(false)
    toast.success('Skill added')
  }

  const handleDeleteSkill = (s: Skill) => {
    if (s.usageCount > 0) {
      toast.error('Cannot delete skill that is used in job roles')
      return
    }
    setSkills((prev) => prev.filter((x) => x.id !== s.id))
    toast.success('Skill deleted')
  }

  const handleToggleStatus = (s: Skill) => {
    setSkills((prev) =>
      prev.map((x) =>
        x.id === s.id ? { ...x, status: x.status === 'Active' ? 'Deprecated' : 'Active' } : x
      )
    )
    toast.success(s.status === 'Active' ? 'Skill deprecated' : 'Skill activated')
  }

  return (
    <>
      <div className="grid grid-cols-2 gap-4">
        <div className="bg-white rounded-2xl shadow-sm border border-gray-200 p-4 text-center">
          <p className="text-xl font-bold">{total}</p>
          <p className="text-xs text-gray-500">Total Skills</p>
        </div>
        <div className="bg-white rounded-2xl shadow-sm border border-gray-200 p-4 text-center">
          <p className="text-xl font-bold text-green-600">{active}</p>
          <p className="text-xs text-gray-500">Active Skills</p>
        </div>
        <div className="bg-white rounded-2xl shadow-sm border border-gray-200 p-4 text-center">
          <p className="text-xl font-bold text-purple-600">{technical}</p>
          <p className="text-xs text-gray-500">Technical</p>
        </div>
        <div className="bg-white rounded-2xl shadow-sm border border-gray-200 p-4 text-center">
          <p className="text-xl font-bold text-blue-600">{soft}</p>
          <p className="text-xs text-gray-500">Soft Skills</p>
        </div>
      </div>

      <button
        onClick={() => setShowAddForm(true)}
        className="w-full py-3 rounded-xl bg-purple-600 text-white font-medium flex items-center justify-center gap-2 hover:bg-purple-700"
      >
        <Plus className="w-5 h-5" />
        Add New Skill
      </button>

      {showAddForm && (
        <div className="bg-white rounded-2xl shadow-sm border border-gray-200 p-4 space-y-3">
          <h3 className="font-bold">Add Skill</h3>
          <input
            type="text"
            placeholder="Skill Name *"
            value={form.name}
            onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
            className="w-full px-4 py-2 rounded-xl border border-gray-300 focus:ring-2 focus:ring-purple-500"
          />
          <select
            value={form.category}
            onChange={(e) => setForm((f) => ({ ...f, category: e.target.value as SkillCategory }))}
            className="w-full px-4 py-2 rounded-xl border border-gray-300 focus:ring-2 focus:ring-purple-500"
          >
            <option value="Technical">Technical</option>
            <option value="Soft Skill">Soft Skill</option>
            <option value="Language">Language</option>
            <option value="Tool">Tool</option>
          </select>
          <textarea
            placeholder="Description *"
            value={form.description}
            onChange={(e) => setForm((f) => ({ ...f, description: e.target.value }))}
            rows={2}
            className="w-full px-4 py-2 rounded-xl border border-gray-300 focus:ring-2 focus:ring-purple-500"
          />
          <select
            value={form.relevance}
            onChange={(e) => setForm((f) => ({ ...f, relevance: e.target.value as Relevance }))}
            className="w-full px-4 py-2 rounded-xl border border-gray-300 focus:ring-2 focus:ring-purple-500"
          >
            <option value="High">High</option>
            <option value="Medium">Medium</option>
            <option value="Low">Low</option>
          </select>
          <div className="flex gap-2">
            <button
              onClick={handleAddSkill}
              className="flex-1 py-2 rounded-xl bg-purple-600 text-white font-medium flex items-center justify-center gap-2"
            >
              <Check className="w-4 h-4" />
              Add Skill
            </button>
            <button
              onClick={() => setShowAddForm(false)}
              className="px-4 py-2 rounded-xl border border-gray-300"
            >
              Cancel
            </button>
          </div>
        </div>
      )}

      <div className="flex gap-2">
        {(['All', 'Technical', 'Soft'] as const).map((t) => (
          <button
            key={t}
            onClick={() => setTab(t)}
            className={`px-4 py-2 rounded-xl text-sm font-medium ${
              tab === t ? 'bg-purple-600 text-white' : 'bg-white border border-gray-200'
            }`}
          >
            {t} {t === 'All' ? skills.length : t === 'Technical' ? technical : soft}
          </button>
        ))}
      </div>

      <div className="space-y-4">
        {filtered.map((s) => (
          <div
            key={s.id}
            className="bg-white rounded-2xl shadow-sm border border-gray-200 p-4 hover:shadow-md transition"
          >
            <h4 className="font-bold text-gray-900">{s.name}</h4>
            <p className="text-sm text-gray-600 mt-1">{s.description}</p>
            <div className="flex flex-wrap gap-2 mt-2">
              <span className={`px-2 py-0.5 rounded-lg text-xs ${categoryColors[s.category]}`}>
                {s.category}
              </span>
              <span className={`px-2 py-0.5 rounded-lg text-xs ${relevanceColors[s.relevance]}`}>
                {s.relevance} Relevance
              </span>
              <span
                className={`px-2 py-0.5 rounded-lg text-xs ${s.status === 'Active' ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'}`}
              >
                {s.status}
              </span>
            </div>
            <p className="text-xs text-gray-500 mt-2">Used in {s.usageCount} job roles</p>
            <div className="flex gap-2 mt-3">
              <button
                onClick={() => handleToggleStatus(s)}
                className="px-3 py-1.5 rounded-lg text-sm bg-orange-100 text-orange-700 hover:bg-orange-200"
              >
                {s.status === 'Active' ? 'Deprecate' : 'Activate'}
              </button>
              <button
                onClick={() => handleDeleteSkill(s)}
                className="p-1.5 rounded-lg text-red-600 hover:bg-red-50"
              >
                <Trash2 className="w-4 h-4" />
              </button>
            </div>
          </div>
        ))}
      </div>

      <div className="bg-gradient-to-r from-purple-600 to-indigo-600 rounded-2xl shadow-sm border border-gray-200 p-4 text-white">
        <h3 className="font-bold flex items-center gap-2 mb-2">Proficiency Levels</h3>
        <ul className="text-sm space-y-1">
          <li>Basic: 0–40%</li>
          <li>Intermediate: 41–70%</li>
          <li>Advanced: 71–100%</li>
        </ul>
      </div>
    </>
  )
}
