import { Target, BarChart, AlertCircle, CheckCircle2 } from 'lucide-react'
import { motion } from 'motion/react'
import { AnimatedCounter } from '../ui/AnimatedCounter'
import { AnimatedProgressBar } from '../ui/AnimatedProgressBar'
import { FadeIn } from '../ui/FadeIn'
import type { GapAnalysisData } from '../../types/analysis'

interface SkillsBreakdownTabProps {
  data: GapAnalysisData
}

export default function SkillsBreakdownTab({ data }: SkillsBreakdownTabProps) {
  const totalSkills = data.allSkills?.length ?? 0
  const matchedSkills = data.strongSkills?.length ?? 0
  const missingSkills = data.criticalGaps?.length ?? 0
  const developingCount = (data.developingSkills?.length ?? 0)
  const coveragePct = totalSkills > 0 ? Math.round((matchedSkills / totalSkills) * 100) : 0

  const matchedPct = totalSkills > 0 ? (matchedSkills / totalSkills) * 100 : 0
  const developingPct = totalSkills > 0 ? (developingCount / totalSkills) * 100 : 0
  const criticalPct = totalSkills > 0 ? (missingSkills / totalSkills) * 100 : 0

  const technicalSkills = (data.allSkills ?? []).filter((s) => s.type === 'technical')
  const softSkills = (data.allSkills ?? []).filter((s) => s.type === 'soft')
  const technicalMatch = data.technicalMatch ?? (technicalSkills.length > 0
    ? Math.round((technicalSkills.filter((s) => s.status === 'strong').length / technicalSkills.length) * 100)
    : 0)
  const softMatch = data.softMatch ?? (softSkills.length > 0
    ? Math.round((softSkills.filter((s) => s.status === 'strong').length / softSkills.length) * 100)
    : 0)
  const diff = Math.abs(technicalMatch - softMatch)
  const isBalanced = diff <= 15

  return (
    <div className="space-y-6">
      <FadeIn delay={0.05}>
        <div className="bg-gradient-to-r from-purple-500 to-purple-600 rounded-2xl shadow-lg p-6 text-white">
          <div className="flex items-center gap-3 mb-4">
            <div className="w-10 h-10 rounded-xl bg-white/20 flex items-center justify-center">
              <Target className="w-5 h-5" />
            </div>
            <h3 className="font-bold text-lg">Skill Coverage Summary</h3>
          </div>
          <div className="grid grid-cols-2 gap-3 mb-5">
            <div className="bg-white/10 rounded-xl p-3">
              <p className="text-2xl font-bold">
                <AnimatedCounter value={totalSkills} duration={1.5} />
              </p>
              <p className="text-xs text-white/80">Total Required</p>
            </div>
            <div className="bg-white/10 rounded-xl p-3">
              <p className="text-2xl font-bold">
                <AnimatedCounter value={matchedSkills} duration={1.5} />
              </p>
              <p className="text-xs text-white/80">Matched</p>
            </div>
            <div className="bg-white/10 rounded-xl p-3">
              <p className="text-2xl font-bold">
                <AnimatedCounter value={missingSkills} duration={1.5} />
              </p>
              <p className="text-xs text-white/80">Missing</p>
            </div>
            <div className="bg-white/10 rounded-xl p-3">
              <p className="text-2xl font-bold">
                <AnimatedCounter value={coveragePct} suffix="%" duration={1.5} />
              </p>
              <p className="text-xs text-white/80">Coverage</p>
            </div>
          </div>

          <div className="space-y-2">
            <div className="h-8 rounded-lg overflow-hidden flex bg-white/10">
              <motion.div
                className="h-full bg-green-400 flex items-center justify-center min-w-0"
                initial={{ width: 0 }}
                animate={{ width: `${matchedPct}%` }}
                transition={{ duration: 0.8, delay: 0.3 }}
              >
                {matchedSkills > 0 && (
                  <span className="text-xs font-bold text-white truncate px-1">{matchedSkills}</span>
                )}
              </motion.div>
              <motion.div
                className="h-full bg-blue-400 flex items-center justify-center min-w-0"
                initial={{ width: 0 }}
                animate={{ width: `${developingPct}%` }}
                transition={{ duration: 0.8, delay: 0.5 }}
              >
                {developingCount > 0 && (
                  <span className="text-xs font-bold text-white truncate px-1">{developingCount}</span>
                )}
              </motion.div>
              <motion.div
                className="h-full bg-orange-400 flex items-center justify-center min-w-0"
                initial={{ width: 0 }}
                animate={{ width: `${criticalPct}%` }}
                transition={{ duration: 0.8, delay: 0.7 }}
              >
                {missingSkills > 0 && (
                  <span className="text-xs font-bold text-white truncate px-1">{missingSkills}</span>
                )}
              </motion.div>
            </div>
            <div className="flex gap-4 justify-center flex-wrap text-xs">
              <span className="flex items-center gap-1.5">
                <span className="w-3 h-3 rounded bg-green-400" />
                Matched
              </span>
              <span className="flex items-center gap-1.5">
                <span className="w-3 h-3 rounded bg-blue-400" />
                Developing
              </span>
              <span className="flex items-center gap-1.5">
                <span className="w-3 h-3 rounded bg-orange-400" />
                Critical
              </span>
            </div>
          </div>
        </div>
      </FadeIn>

      <FadeIn delay={0.3}>
        <div className="bg-white rounded-2xl shadow-sm border border-gray-200 p-4">
          <div className="flex items-center gap-3 mb-3">
            <div className="w-10 h-10 rounded-xl bg-purple-100 flex items-center justify-center shrink-0">
              <BarChart className="w-5 h-5 text-purple-600" />
            </div>
            <div>
              <h3 className="font-bold text-gray-900">Skill Category Comparison</h3>
              <p className="text-xs text-gray-500">Coverage breakdown by skill type</p>
            </div>
          </div>
          <div className="space-y-4">
            <motion.div
              className="space-y-2"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ delay: 0.3 }}
            >
              <div className="flex items-center gap-2">
                <span className="w-8 h-8 rounded-lg bg-blue-100 flex items-center justify-center text-sm">💻</span>
                <span className="font-medium text-gray-900">Technical Skills Match</span>
              </div>
              <p className="text-2xl font-bold text-blue-600">
                <AnimatedCounter value={technicalMatch} suffix="%" duration={1.5} />
              </p>
              <AnimatedProgressBar value={technicalMatch} color="blue" />
              <div className="flex justify-between text-xs text-gray-500">
                <span>Current Coverage</span>
                <span>{100 - technicalMatch}% gap remaining</span>
              </div>
            </motion.div>
            <motion.div
              className="space-y-2"
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ delay: 0.5 }}
            >
              <div className="flex items-center gap-2">
                <span className="w-8 h-8 rounded-lg bg-purple-100 flex items-center justify-center text-sm">🤝</span>
                <span className="font-medium text-gray-900">Soft Skills Match</span>
              </div>
              <p className="text-2xl font-bold text-purple-600">
                <AnimatedCounter value={softMatch} suffix="%" duration={1.5} />
              </p>
              <AnimatedProgressBar value={softMatch} color="purple" />
              <div className="flex justify-between text-xs text-gray-500">
                <span>Current Coverage</span>
                <span>{100 - softMatch}% gap remaining</span>
              </div>
            </motion.div>
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ delay: 0.8 }}
            >
              {isBalanced ? (
                <div className="flex items-start gap-2 p-3 bg-green-50 border border-green-200 rounded-xl">
                  <CheckCircle2 className="w-5 h-5 text-green-600 shrink-0 mt-0.5" />
                  <p className="text-sm text-green-800">Great balance! Both technical and soft skills are well-developed.</p>
                </div>
              ) : (
                <div className="flex items-start gap-2 p-3 bg-orange-50 border border-orange-200 rounded-xl">
                  <AlertCircle className="w-5 h-5 text-orange-600 shrink-0 mt-0.5" />
                  <p className="text-sm text-orange-800">
                    {technicalMatch >= softMatch + 15
                      ? `Your technical skills (${technicalMatch}%) are stronger than soft skills (${softMatch}%). Consider developing soft skills for better job readiness.`
                      : `Your soft skills (${softMatch}%) are stronger than technical skills (${technicalMatch}%). Consider strengthening technical skills for this role.`}
                  </p>
                </div>
              )}
            </motion.div>
          </div>
        </div>
      </FadeIn>

      <FadeIn delay={0.1}>
        <div className="bg-white rounded-2xl shadow-sm border border-gray-200 p-4">
          <h3 className="font-bold text-gray-900 mb-4">Skills Breakdown</h3>
          <div className="space-y-3">
            {(data.allSkills ?? []).map((skill, i) => (
              <div
                key={`${skill.name}-${i}`}
                className="flex items-center justify-between p-3 rounded-xl border border-gray-100"
              >
                <div>
                  <p className="font-medium text-gray-900">{skill.name}</p>
                  <p className="text-xs text-gray-500">
                    {skill.current}% current · {skill.required}% required
                  </p>
                </div>
                <span
                  className={`px-2 py-0.5 rounded-full text-xs font-medium ${
                    skill.status === 'strong'
                      ? 'bg-green-100 text-green-700'
                      : skill.status === 'developing'
                        ? 'bg-blue-100 text-blue-700'
                        : 'bg-orange-100 text-orange-700'
                  }`}
                >
                  {skill.status}
                </span>
              </div>
            ))}
          </div>
        </div>
      </FadeIn>
    </div>
  )
}
