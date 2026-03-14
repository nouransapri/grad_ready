import { useState } from 'react'
import { BarChart3, Layers, Lightbulb } from 'lucide-react'
import OverviewTab from '../components/analysis/OverviewTab'
import SkillsBreakdownTab from '../components/analysis/SkillsBreakdownTab'
import RecommendationsTab from '../components/analysis/RecommendationsTab'
import type { GapAnalysisData, AnalysisSkill } from '../types/analysis'

function buildSampleData(): GapAnalysisData {
  const allSkills: AnalysisSkill[] = [
    { name: 'SQL', current: 85, required: 80, status: 'strong', type: 'technical' },
    { name: 'Python', current: 70, required: 75, status: 'developing', type: 'technical' },
    { name: 'Data Visualization', current: 40, required: 80, status: 'critical', type: 'technical' },
    { name: 'Communication', current: 90, required: 75, status: 'strong', type: 'soft' },
    { name: 'Problem Solving', current: 55, required: 80, status: 'critical', type: 'soft' },
    { name: 'Statistics', current: 60, required: 70, status: 'developing', type: 'technical' },
  ]
  const strongSkills = allSkills.filter((s) => s.status === 'strong')
  const criticalGaps = allSkills.filter((s) => s.status === 'critical')
  const developingSkills = allSkills.filter((s) => s.status === 'developing')
  const matchedCount = strongSkills.length
  const totalCount = allSkills.length
  const readinessScore = totalCount > 0 ? Math.round((matchedCount / totalCount) * 100) : 0
  const technicalSkills = allSkills.filter((s) => s.type === 'technical')
  const softSkills = allSkills.filter((s) => s.type === 'soft')
  const technicalMatch = technicalSkills.length > 0
    ? Math.round((technicalSkills.filter((s) => s.status === 'strong').length / technicalSkills.length) * 100)
    : 0
  const softMatch = softSkills.length > 0
    ? Math.round((softSkills.filter((s) => s.status === 'strong').length / softSkills.length) * 100)
    : 0
  return {
    readinessScore,
    strongSkills,
    allSkills,
    criticalGaps,
    developingSkills,
    technicalMatch,
    softMatch,
  }
}

const TABS = [
  { id: 'overview', label: 'Overview', icon: BarChart3 },
  { id: 'breakdown', label: 'Skills Breakdown', icon: Layers },
  { id: 'recommendations', label: 'Recommendations', icon: Lightbulb },
] as const

export default function GapAnalysisScreen() {
  const [activeTab, setActiveTab] = useState<(typeof TABS)[number]['id']>('overview')
  const [data] = useState<GapAnalysisData>(buildSampleData())

  return (
    <div className="space-y-6">
      <div className="bg-white rounded-2xl shadow-sm border border-gray-200 p-4">
        <h2 className="text-xl font-bold text-gray-900 mb-1">Decision Support Dashboard</h2>
        <p className="text-sm text-gray-500">Analyze your skill gaps and prioritize learning goals.</p>
      </div>

      <div className="flex gap-2 p-1 bg-gray-100 rounded-2xl">
        {TABS.map(({ id, label, icon: Icon }) => (
          <button
            key={id}
            onClick={() => setActiveTab(id)}
            className={`flex-1 flex items-center justify-center gap-2 py-3 px-4 rounded-xl text-sm font-medium transition ${
              activeTab === id ? 'bg-white text-purple-600 shadow-sm' : 'text-gray-600 hover:text-gray-900'
            }`}
          >
            <Icon className="w-4 h-4" />
            {label}
          </button>
        ))}
      </div>

      {activeTab === 'overview' && <OverviewTab data={data} />}
      {activeTab === 'breakdown' && <SkillsBreakdownTab data={data} />}
      {activeTab === 'recommendations' && <RecommendationsTab data={data} />}
    </div>
  )
}
