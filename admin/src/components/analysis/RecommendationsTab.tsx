import { ArrowUp, TrendingUp, Zap, MapPin, Clock, Lightbulb, AlertTriangle } from 'lucide-react'
import { motion } from 'motion/react'
import { AnimatedCounter } from '../ui/AnimatedCounter'
import { FadeIn } from '../ui/FadeIn'
import type { GapAnalysisData, AnalysisSkill } from '../../types/analysis'

interface RecommendationsTabProps {
  data: GapAnalysisData
}

function improvementPerSkill(totalSkills: number): number {
  return totalSkills > 0 ? 100 / totalSkills : 0
}

function skillImprovement(skill: AnalysisSkill, totalSkills: number): number {
  const per = improvementPerSkill(totalSkills)
  const currentContribution = skill.required > 0 ? (skill.current / skill.required) * per : 0
  return per - currentContribution
}

function expectedScoreIfSkillCompleted(
  currentScore: number,
  skill: AnalysisSkill,
  totalSkills: number
): number {
  const add = skillImprovement(skill, totalSkills)
  return Math.min(100, Math.round((currentScore + add) * 10) / 10)
}

interface RoadmapStep {
  skill: AnalysisSkill & { gap?: number }
  step: number
  weeks: number
  impact: 'High' | 'Medium' | 'Low'
  isCritical: boolean
}

function buildLearningRoadmap(data: GapAnalysisData): RoadmapStep[] {
  const withGap = (s: AnalysisSkill) => ({
    ...s,
    gap: s.required > 0 ? ((s.required - s.current) / s.required) * 100 : 0,
  })
  const critical = [...(data.criticalGaps ?? [])].map(withGap).sort((a, b) => (b.gap ?? 0) - (a.gap ?? 0))
  const developing = [...(data.developingSkills ?? [])].map(withGap).sort((a, b) => (b.gap ?? 0) - (a.gap ?? 0))
  const combined: (AnalysisSkill & { gap?: number })[] = [...critical, ...developing]
  const steps: RoadmapStep[] = combined.slice(0, 6).map((skill, index) => {
    const gap = skill.gap ?? 0
    const weeks = gap >= 50 ? 6 : gap >= 30 ? 4 : 2
    const isCritical = skill.status === 'critical'
    const impact: 'High' | 'Medium' | 'Low' =
      isCritical && gap >= 40 ? 'High' : isCritical || gap >= 25 ? 'Medium' : 'Low'
    return { skill, step: index + 1, weeks, impact, isCritical }
  })
  return steps
}

export default function RecommendationsTab({ data }: RecommendationsTabProps) {
  const totalSkills = data.allSkills?.length ?? 1
  const currentScore = data.readinessScore ?? 0
  const criticalSorted = [...(data.criticalGaps ?? [])].map((s) => ({
    ...s,
    gap: s.required > 0 ? ((s.required - s.current) / s.required) * 100 : 0,
  })).sort((a, b) => (b.gap ?? 0) - (a.gap ?? 0))

  const top3Improvements = criticalSorted.slice(0, 3).reduce((sum, s) => sum + skillImprovement(s, totalSkills), 0)
  const potentialScore = Math.min(100, Math.round((currentScore + top3Improvements) * 10) / 10)
  const developingSorted = [...(data.developingSkills ?? [])].map((s) => ({
    ...s,
    gap: s.required > 0 ? ((s.required - s.current) / s.required) * 100 : 0,
  })).sort((a, b) => (b.gap ?? 0) - (a.gap ?? 0))

  return (
    <div className="space-y-6">
      <FadeIn delay={0.05}>
        <div className="bg-white rounded-2xl shadow-sm border-2 border-green-200 p-6">
          <div className="flex items-center gap-3 mb-4">
            <div className="w-10 h-10 rounded-xl bg-green-100 flex items-center justify-center">
              <ArrowUp className="w-5 h-5 text-green-600" />
            </div>
            <h3 className="font-bold text-gray-900">Potential Score Improvement</h3>
          </div>
          <div className="p-4 bg-green-50 border border-green-100 rounded-xl">
            <div className="flex items-center justify-between gap-4">
              <div className="text-center flex-1">
                <p className="text-xs text-gray-500 mb-1">Current Score</p>
                <p className="text-2xl font-bold text-purple-600">
                  <AnimatedCounter value={Math.round(currentScore)} suffix="%" duration={1.5} />
                </p>
              </div>
              <TrendingUp className="w-8 h-8 text-green-500 shrink-0" />
              <div className="text-center flex-1">
                <p className="text-xs text-gray-500 mb-1">Potential Score</p>
                <p className="text-2xl font-bold text-green-600">
                  <AnimatedCounter value={Math.round(potentialScore)} suffix="%" duration={1.5} />
                </p>
              </div>
            </div>
            <p className="text-center text-sm text-gray-600 mt-3">
              Completing the top 3 critical skills could raise your match to <AnimatedCounter value={Math.round(potentialScore)} suffix="%" duration={1.5} />
            </p>
          </div>
        </div>
      </FadeIn>

      <FadeIn delay={0.1}>
        <div className="bg-white rounded-2xl shadow-sm border border-gray-200 p-4">
          <h3 className="font-bold text-gray-900 mb-2 flex items-center gap-2">
            <span aria-hidden>🔥</span>
            High Priority Skills
          </h3>
          <div className="space-y-3">
            {criticalSorted.map((skill, index) => {
              const expected = expectedScoreIfSkillCompleted(currentScore, skill, totalSkills)
              const improvement = expected - currentScore
              return (
                <motion.div
                  key={skill.name}
                  className="bg-gradient-to-r from-orange-50 to-red-50 rounded-2xl border border-orange-200 p-4"
                  whileHover={{ scale: 1.02, x: 5 }}
                  transition={{ type: 'spring', stiffness: 300 }}
                >
                  <div className="flex items-start gap-3">
                    <div
                      className="w-10 h-10 rounded-xl bg-gradient-to-r from-orange-500 to-red-500 text-white flex items-center justify-center font-bold text-sm shrink-0"
                    >
                      {index + 1}
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2 flex-wrap">
                        <h4 className="font-bold text-gray-900">{skill.name}</h4>
                        <span className="px-2 py-0.5 rounded-full bg-orange-600 text-white text-xs font-medium">
                          High Priority
                        </span>
                        <span className="text-xs text-gray-500">
                          {skill.type === 'technical' ? '💻 Technical' : '🤝 Soft Skill'}
                        </span>
                      </div>
                      <p className="text-sm text-gray-600 mt-1">
                        Gap: <AnimatedCounter value={Math.round(skill.gap ?? 0)} suffix="%" duration={1} /> · Improve from{' '}
                        <AnimatedCounter value={Math.round(currentScore)} suffix="%" duration={1} /> to{' '}
                        <AnimatedCounter value={Math.round(expected)} suffix="%" duration={1} />
                      </p>
                      <div className="mt-3 p-3 bg-white border border-orange-200 rounded-xl flex items-center gap-2">
                        <TrendingUp className="w-4 h-4 text-green-500 shrink-0" />
                        <p className="text-sm text-gray-700">
                          Learning this skill will increase your match score from{' '}
                          <span className="text-purple-600 font-medium"><AnimatedCounter value={Math.round(currentScore)} suffix="%" duration={1} /></span>
                          {' '}to{' '}
                          <span className="text-green-600 font-medium"><AnimatedCounter value={Math.round(expected)} suffix="%" duration={1} /></span>
                          {' '}(+<AnimatedCounter value={Math.round(improvement)} suffix="%" duration={1} />)
                        </p>
                      </div>
                    </div>
                  </div>
                </motion.div>
              )
            })}
          </div>
        </div>
      </FadeIn>

      <FadeIn delay={0.15}>
        <div className="bg-white rounded-2xl shadow-sm border border-gray-200 p-4">
          <h3 className="font-bold text-gray-900 mb-2 flex items-center gap-2">
            <Zap className="w-5 h-5 text-blue-500" />
            Medium Priority Skills
          </h3>
          <div className="space-y-3">
            {developingSorted.map((skill, index) => {
              const expected = expectedScoreIfSkillCompleted(currentScore, skill, totalSkills)
              return (
                <motion.div
                  key={skill.name}
                  className="bg-blue-50 rounded-2xl border border-blue-200 p-4"
                  whileHover={{ scale: 1.02, x: 5 }}
                  transition={{ type: 'spring', stiffness: 300 }}
                >
                  <div className="flex items-start gap-3">
                    <div className="w-8 h-8 rounded-lg bg-blue-500 text-white flex items-center justify-center font-bold text-sm shrink-0">
                      {index + 1}
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2 flex-wrap">
                        <h4 className="font-bold text-gray-900">{skill.name}</h4>
                        <span className="px-2 py-0.5 rounded-full bg-blue-500 text-white text-xs font-medium">
                          Medium Priority
                        </span>
                      </div>
                      <p className="text-sm text-gray-600 mt-1">
                        Gap: <AnimatedCounter value={Math.round(skill.gap ?? 0)} suffix="%" duration={1} />
                      </p>
                      <p className="text-sm text-blue-700 mt-1">
                        Improving this skill will boost your score to <AnimatedCounter value={Math.round(expected)} suffix="%" duration={1} />
                      </p>
                    </div>
                  </div>
                </motion.div>
              )
            })}
          </div>
        </div>
      </FadeIn>

      <FadeIn delay={0.8}>
        <div className="bg-white rounded-2xl shadow-sm border border-gray-200 p-6">
          <div className="flex items-center gap-3 mb-2">
            <div
              className="w-10 h-10 rounded-xl flex items-center justify-center shrink-0"
              style={{ background: 'linear-gradient(to right, #a855f7, #3b82f6)' }}
            >
              <MapPin className="w-5 h-5 text-white" />
            </div>
            <div>
              <h3 className="font-bold text-gray-900">Suggested Learning Roadmap</h3>
              <p className="text-xs text-gray-500">Follow this path to close your skill gaps efficiently</p>
            </div>
          </div>
          <div className="relative mt-6 pl-8">
            <div
              className="absolute left-[15px] top-2 bottom-2 w-0.5 rounded-full"
              style={{ background: 'linear-gradient(to bottom, #e9d5ff, #bfdbfe, #e5e7eb)' }}
            />
            {buildLearningRoadmap(data).map(({ skill, step, weeks, impact, isCritical }, index) => (
              <motion.div
                key={skill.name}
                className="relative mb-4 last:mb-0"
                initial={{ opacity: 0, x: -30 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ delay: 0.1 * index, duration: 0.4 }}
                whileHover={{ x: 5, scale: 1.01 }}
              >
                <div
                  className={`rounded-r-2xl border-l-4 pl-4 pr-4 py-3 ${
                    isCritical
                      ? 'bg-gradient-to-r from-orange-100 to-red-100 border-orange-500'
                      : 'bg-blue-50 border-blue-500'
                  }`}
                >
                  <div className="flex items-start justify-between gap-2 flex-wrap">
                    <div className="flex items-center gap-3 min-w-0">
                      <div
                        className="w-10 h-10 rounded-full flex items-center justify-center font-bold text-white text-sm shrink-0 shadow-md -ml-9 relative z-10"
                        style={
                          isCritical
                            ? { background: 'linear-gradient(to right, #ea580c, #dc2626)' }
                            : { background: 'linear-gradient(to right, #3b82f6, #a855f7)' }
                        }
                      >
                        {step}
                      </div>
                      <div>
                        <h4 className="font-bold text-gray-900">{skill.name}</h4>
                        <p className="text-sm text-gray-600">
                          {skill.type === 'technical' ? '💻 Technical' : '🤝 Soft Skill'} · Gap{' '}
                          <AnimatedCounter value={Math.round(skill.gap ?? 0)} suffix="%" duration={1} />
                        </p>
                      </div>
                    </div>
                    <span
                      className={`shrink-0 px-2 py-0.5 rounded-full text-xs font-medium ${
                        impact === 'High'
                          ? 'bg-red-100 text-red-700'
                          : impact === 'Medium'
                            ? 'bg-orange-100 text-orange-700'
                            : 'bg-yellow-100 text-yellow-700'
                      }`}
                    >
                      {impact} Impact
                    </span>
                  </div>
                  <div className="flex items-center gap-2 mt-2 text-sm text-gray-600">
                    <Clock className="w-4 h-4 shrink-0" />
                    <span>Estimated learning time: {weeks} weeks</span>
                  </div>
                  {isCritical && (
                    <p className="mt-2 flex items-center gap-1 text-sm text-orange-700 font-medium">
                      <AlertTriangle className="w-4 h-4 shrink-0" />
                      Priority: Start with this skill
                    </p>
                  )}
                </div>
              </motion.div>
            ))}
          </div>
          <motion.div
            className="mt-6 p-4 rounded-xl text-gray-800"
            style={{ background: 'linear-gradient(to right, #ede9fe, #dbeafe)' }}
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.8 }}
          >
            <div className="flex items-start gap-2">
              <Lightbulb className="w-5 h-5 text-amber-500 shrink-0 mt-0.5" />
              <div>
                <p className="font-semibold text-gray-900">💡 Roadmap Tip</p>
                <p className="text-sm mt-1">
                  Follow the order shown above for maximum efficiency. High-impact skills will boost your job readiness
                  score faster. You can adjust the pace based on your schedule, but try to maintain the priority order.
                </p>
              </div>
            </div>
          </motion.div>
        </div>
      </FadeIn>
    </div>
  )
}
