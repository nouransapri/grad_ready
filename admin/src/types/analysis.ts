export type SkillStatus = 'strong' | 'developing' | 'critical'

export interface AnalysisSkill {
  name: string
  current: number
  required: number
  status: SkillStatus
  gap?: number
  type?: 'technical' | 'soft'
}

export interface GapAnalysisData {
  readinessScore: number
  strongSkills: AnalysisSkill[]
  allSkills: AnalysisSkill[]
  criticalGaps: AnalysisSkill[]
  developingSkills: AnalysisSkill[]
  technicalMatch?: number
  softMatch?: number
}
