import { Brain, AlertTriangle, TrendingUp } from 'lucide-react'
import { motion } from 'motion/react'
import { AnimatedCounter } from '../ui/AnimatedCounter'
import { AnimatedProgressBar } from '../ui/AnimatedProgressBar'
import { FadeIn } from '../ui/FadeIn'
import type { GapAnalysisData, AnalysisSkill } from '../../types/analysis'

interface OverviewTabProps {
  data: GapAnalysisData
}

const TECHNICAL_DEMAND: Record<string, number> = {
  javascript: 82, python: 85, sql: 80, java: 78, react: 81, 'data analysis': 84,
  'data visualization': 79, tableau: 75, excel: 77, statistics: 76, 'machine learning': 83,
  'problem solving': 72, communication: 88, leadership: 85, teamwork: 86,
  'business analysis': 72, 'database management': 78, programming: 85,
}
const SOFT_DEMAND: Record<string, number> = {
  communication: 90, leadership: 85, teamwork: 86, 'problem solving': 82,
  'time management': 78, 'critical thinking': 80, collaboration: 84,
  'attention to detail': 75, 'business analysis': 72,
}

function getMarketDemand(skill: AnalysisSkill): number {
  const name = (skill.name || '').trim().toLowerCase()
  const isTechnical = skill.type === 'technical'
  const lookup = isTechnical ? TECHNICAL_DEMAND : SOFT_DEMAND
  if (lookup[name]) return lookup[name]
  for (const key of Object.keys(lookup)) {
    if (name.includes(key) || key.includes(name)) return lookup[key]
  }
  return isTechnical ? 65 : 70
}

function getReadinessLevel(score: number) {
  if (score >= 90) return { label: 'Job Ready', emoji: '🎯', gradient: 'linear-gradient(to right, #10b981, #059669)', message: 'You have strong alignment with this role. Focus on polishing your interview skills and portfolio.' }
  if (score >= 70) return { label: 'Almost Job Ready', emoji: '⚡', gradient: 'linear-gradient(to right, #3b82f6, #2563eb)', message: 'You are close. Prioritize the top skill gaps to become job ready.' }
  if (score >= 50) return { label: 'Needs Improvement', emoji: '📚', gradient: 'linear-gradient(to right, #f59e0b, #d97706)', message: 'Build foundational skills in the critical gap areas to improve your match.' }
  return { label: 'Beginner', emoji: '🚀', gradient: 'linear-gradient(to right, #ef4444, #dc2626)', message: 'Start with the highest-priority skills and work through the learning path.' }
}

export default function OverviewTab({ data }: OverviewTabProps) {
  const score = data.readinessScore ?? 0
  const level = getReadinessLevel(score)
  const matchedCount = data.strongSkills?.length ?? 0
  const totalCount = data.allSkills?.length ?? 0

  const criticalSkills = (data.allSkills ?? []).filter((s) => s.status === 'critical')
  const topCritical = [...criticalSkills]
    .map((s) => ({ ...s, gap: (s.required - s.current) / Math.max(1, s.required) * 100 }))
    .sort((a, b) => (b.gap ?? 0) - (a.gap ?? 0))[0]

  return (
    <div className="space-y-6">
      <FadeIn delay={0.05}>
        <div
          className="rounded-2xl shadow-lg p-6 text-white"
          style={{ background: level.gradient }}
        >
          <div className="flex items-start gap-4">
            <span className="text-4xl" aria-hidden>{level.emoji}</span>
            <div className="flex-1 min-w-0">
              <h2 className="text-2xl font-bold">{level.label}</h2>
              <p className="mt-2 text-white/90 text-sm">{level.message}</p>
              <p className="mt-3 text-white font-medium">
                You match <AnimatedCounter value={matchedCount} duration={1.5} /> out of <AnimatedCounter value={totalCount} duration={1.5} /> required skills
              </p>
            </div>
          </div>
        </div>
      </FadeIn>

      {topCritical && (
        <FadeIn delay={0.1}>
          <div className="bg-white rounded-2xl shadow-sm border-2 border-orange-200 p-6">
            <div className="flex items-start gap-3">
              <div className="w-12 h-12 bg-orange-100 rounded-xl flex items-center justify-center shrink-0">
                <Brain className="w-6 h-6 text-orange-600" />
              </div>
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2 flex-wrap">
                  <h3 className="text-lg font-bold text-gray-900">{topCritical.name}</h3>
                  <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full bg-orange-600 text-white text-xs font-medium">
                    <AlertTriangle className="w-3.5 h-3.5" />
                    High Priority
                  </span>
                </div>
                <p className="mt-2 text-sm text-gray-600">
                  Current level: <AnimatedCounter value={topCritical.current} suffix="%" duration={1} /> · Required: <AnimatedCounter value={topCritical.required} suffix="%" duration={1} />
                </p>
                <p className="mt-1 text-sm font-medium text-orange-600">
                  Gap: <AnimatedCounter value={topCritical.gap ?? 0} suffix="%" duration={1} decimals={0} />
                </p>
                <div className="mt-3 p-3 bg-orange-50 border border-orange-100 rounded-xl">
                  <p className="text-sm text-orange-900">Focus on this skill first for the biggest impact on your readiness score.</p>
                </div>
              </div>
            </div>
          </div>
        </FadeIn>
      )}

      <FadeIn delay={0.3}>
        <div className="bg-white rounded-2xl shadow-sm border-2 border-blue-200 p-6">
          <div className="flex items-center gap-3 mb-3">
            <div className="w-10 h-10 rounded-full bg-blue-100 flex items-center justify-center shrink-0">
              <TrendingUp className="w-5 h-5 text-blue-600" />
            </div>
            <div>
              <h3 className="font-bold text-gray-900">Market Demand Insight</h3>
              <p className="text-xs text-gray-500">How often these skills appear in job postings</p>
            </div>
          </div>
          {criticalSkills.length === 0 ? (
            <div className="p-4 bg-green-50 border border-green-200 rounded-xl text-green-800 text-sm">
              Great! You don&apos;t have any critical skill gaps.
            </div>
          ) : (
            <div className="space-y-3">
              {[...criticalSkills]
                .map((s) => ({ ...s, gap: (s.required - s.current) / Math.max(1, s.required) * 100 }))
                .sort((a, b) => (b.gap ?? 0) - (a.gap ?? 0))
                .slice(0, 3)
                .map((skill, i) => {
                  const demand = getMarketDemand(skill)
                  const demandLevel = demand >= 75 ? 'High Demand' : demand >= 60 ? 'Moderate Demand' : 'Low Demand'
                  return (
                    <motion.div
                      key={skill.name}
                      className="p-3 bg-blue-50 rounded-xl border border-blue-100"
                      initial={{ opacity: 0, x: -20 }}
                      animate={{ opacity: 1, x: 0 }}
                      transition={{ delay: 0.1 * (i + 1), duration: 0.4 }}
                    >
                      <div className="flex items-center justify-between gap-2 flex-wrap">
                        <span className="font-bold text-gray-900">{skill.name}</span>
                        <span className="text-xs text-gray-500">
                          {skill.type === 'technical' ? '💻' : '🤝'} {skill.type === 'technical' ? 'Technical' : 'Soft'}
                        </span>
                      </div>
                      <p className="text-sm text-gray-600 mt-1">
                        <AnimatedCounter value={Math.round(demand)} suffix="%" duration={1} /> demand in job postings · {demandLevel}
                      </p>
                      <AnimatedProgressBar value={demand} color="blue" className="mt-2" />
                    </motion.div>
                  )
                })}
            </div>
          )}
        </div>
      </FadeIn>

      <FadeIn delay={0.15}>
        <div className="bg-white rounded-2xl shadow-sm border border-gray-200 p-4">
          <h3 className="font-bold text-gray-900 mb-4">Summary Stats</h3>
          <div className="grid grid-cols-3 gap-3">
            <div className="rounded-xl bg-gray-50 p-3 text-center">
              <p className="text-xl font-bold text-purple-600">
                <AnimatedCounter value={matchedCount} duration={1.5} />
              </p>
              <p className="text-xs text-gray-500">Matched</p>
            </div>
            <div className="rounded-xl bg-gray-50 p-3 text-center">
              <p className="text-xl font-bold text-blue-600">
                <AnimatedCounter value={data.developingSkills?.length ?? 0} duration={1.5} />
              </p>
              <p className="text-xs text-gray-500">Developing</p>
            </div>
            <div className="rounded-xl bg-gray-50 p-3 text-center">
              <p className="text-xl font-bold text-orange-600">
                <AnimatedCounter value={data.criticalGaps?.length ?? 0} duration={1.5} />
              </p>
              <p className="text-xs text-gray-500">Critical</p>
            </div>
          </div>
        </div>
      </FadeIn>
    </div>
  )
}
