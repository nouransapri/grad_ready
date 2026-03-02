export interface SkillProficiency {
  name: string
  percent: number
}

export type DemandLevel = 'High' | 'Medium' | 'Growing' | 'Stable'

export interface JobRole {
  id: string
  title: string
  description: string
  category: string
  isHighDemand?: boolean
  demand?: DemandLevel
  salaryMinK: number
  salaryMaxK: number
  requiredSkills: string[]
  requiredCourses: string[]
  technicalSkillsWithLevel?: SkillProficiency[]
  softSkillsWithLevel?: SkillProficiency[]
  criticalSkills?: string[]
  lastUpdated?: string // ISO date for market maintenance
}

export const jobRolesDatabase: JobRole[] = [
  {
    id: '1',
    title: 'Data Analyst',
    description: 'Analyze data to help organizations make better decisions',
    category: 'Data & Analytics',
    isHighDemand: true,
    demand: 'High',
    salaryMinK: 65,
    salaryMaxK: 95,
    requiredSkills: ['SQL', 'Excel', 'Python', 'Tableau', 'Statistics', 'Data Visualization', 'Problem Solving', 'Communication'],
    requiredCourses: ['Statistics', 'Data Structures', 'Database Systems', 'Data Visualization'],
    technicalSkillsWithLevel: [
      { name: 'Data Analysis', percent: 85 },
      { name: 'Programming', percent: 65 },
      { name: 'Database Management', percent: 75 },
      { name: 'Business Analysis', percent: 70 },
    ],
    softSkillsWithLevel: [
      { name: 'Problem Solving', percent: 80 },
      { name: 'Communication', percent: 75 },
      { name: 'Critical Thinking', percent: 85 },
      { name: 'Attention to Detail', percent: 80 },
    ],
    criticalSkills: ['Data Analysis', 'Problem Solving', 'Critical Thinking', 'Attention to Detail'],
    lastUpdated: '2024-05-19',
  },
  {
    id: '2',
    title: 'Data Scientist',
    description: 'Use advanced analytics and machine learning to extract insights',
    category: 'Data & Analytics',
    isHighDemand: true,
    demand: 'High',
    salaryMinK: 95,
    salaryMaxK: 140,
    requiredSkills: ['Python', 'R', 'Machine Learning', 'SQL', 'Statistics', 'Deep Learning', 'Data Wrangling', 'A/B Testing', 'Communication', 'Storytelling'],
    requiredCourses: ['Machine Learning', 'Statistics', 'Linear Algebra', 'Database Systems', 'Data Mining', 'Python Programming'],
    lastUpdated: '2024-06-28',
  },
  {
    id: '3',
    title: 'Business Intelligence Analyst',
    description: 'Transform data into actionable business insights',
    category: 'Data & Analytics',
    isHighDemand: true,
    demand: 'High',
    salaryMinK: 70,
    salaryMaxK: 100,
    requiredSkills: ['SQL', 'Power BI', 'Tableau', 'Excel', 'Data Modeling', 'ETL', 'Dashboard Design', 'Communication'],
    requiredCourses: ['Database Systems', 'Business Analytics', 'Data Visualization', 'Statistics'],
    lastUpdated: '2025-11-21',
  },
  {
    id: '4',
    title: 'Marketing Analyst',
    description: 'Analyze marketing data and consumer behavior',
    category: 'Marketing',
    isHighDemand: false,
    demand: 'Medium',
    salaryMinK: 55,
    salaryMaxK: 85,
    requiredSkills: ['Excel', 'Google Analytics', 'SQL', 'Data Visualization', 'A/B Testing', 'SEO', 'Communication', 'Reporting'],
    requiredCourses: ['Marketing Fundamentals', 'Statistics', 'Data Analysis', 'Digital Marketing'],
    lastUpdated: '2024-05-12',
  },
  {
    id: '5',
    title: 'Software Engineer',
    description: 'Design, develop and maintain software applications',
    category: 'Development',
    isHighDemand: true,
    demand: 'High',
    salaryMinK: 80,
    salaryMaxK: 130,
    requiredSkills: ['Programming', 'Data Structures', 'Algorithms', 'Version Control', 'Testing', 'System Design', 'Problem Solving', 'Collaboration'],
    requiredCourses: ['Data Structures', 'Algorithms', 'Database Systems', 'Software Engineering', 'Web or Mobile Development'],
    lastUpdated: '2025-12-13',
  },
  {
    id: '6',
    title: 'Product Manager',
    description: 'Define product strategy and work with engineering to deliver value',
    category: 'Management',
    isHighDemand: true,
    demand: 'High',
    salaryMinK: 90,
    salaryMaxK: 140,
    requiredSkills: ['Product Strategy', 'User Research', 'Agile', 'Stakeholder Management', 'Analytics', 'Communication', 'Prioritization', 'Roadmapping'],
    requiredCourses: ['Product Management', 'Business Fundamentals', 'User Experience', 'Data for Product'],
    lastUpdated: '2025-10-01',
  },
  {
    id: '7',
    title: 'UX Designer',
    description: 'Create user-centered designs for digital products',
    category: 'Design',
    isHighDemand: true,
    demand: 'Growing',
    salaryMinK: 70,
    salaryMaxK: 110,
    requiredSkills: ['Wireframing', 'Prototyping', 'User Research', 'UI Design', 'Figma', 'Usability Testing', 'Communication', 'Collaboration'],
    requiredCourses: ['User Experience Design', 'Visual Design', 'Human-Computer Interaction', 'Design Systems'],
    lastUpdated: '2025-09-15',
  },
  {
    id: '8',
    title: 'DevOps Engineer',
    description: 'Automate and optimize development and deployment pipelines',
    category: 'Infrastructure',
    isHighDemand: true,
    demand: 'High',
    salaryMinK: 85,
    salaryMaxK: 135,
    requiredSkills: ['Linux', 'CI/CD', 'Docker', 'Kubernetes', 'Cloud (AWS/GCP)', 'Scripting', 'Monitoring', 'Security'],
    requiredCourses: ['Operating Systems', 'Networking', 'Cloud Computing', 'Scripting', 'Containers'],
    lastUpdated: '2025-11-01',
  },
  {
    id: '9',
    title: 'Frontend Developer',
    description: 'Build responsive and accessible user interfaces',
    category: 'Development',
    isHighDemand: true,
    demand: 'High',
    salaryMinK: 70,
    salaryMaxK: 120,
    requiredSkills: ['React', 'JavaScript', 'HTML/CSS', 'TypeScript', 'REST APIs', 'Git'],
    requiredCourses: ['Web Development', 'JavaScript', 'UI/UX Basics'],
    lastUpdated: '2025-02-19',
  },
  {
    id: '10',
    title: 'Backend Developer',
    description: 'Build server-side logic and APIs',
    category: 'Development',
    isHighDemand: true,
    demand: 'High',
    salaryMinK: 75,
    salaryMaxK: 125,
    requiredSkills: ['Node.js', 'Python', 'SQL', 'REST', 'Databases', 'Git'],
    requiredCourses: ['Backend Development', 'Database Systems', 'APIs'],
    lastUpdated: '2025-01-10',
  },
  {
    id: '11',
    title: 'Full Stack Developer',
    description: 'Build both front-end and back-end of web applications',
    category: 'Development',
    isHighDemand: true,
    demand: 'High',
    salaryMinK: 70,
    salaryMaxK: 130,
    requiredSkills: ['React.js', 'Node.js', 'PostgreSQL', 'Docker', 'REST APIs', 'Git', 'HTML/CSS', 'JavaScript'],
    requiredCourses: ['Web Development', 'Database Systems', 'Data Structures', 'JavaScript/TypeScript', 'Software Engineering'],
    lastUpdated: '2025-12-11',
  },
  {
    id: '12',
    title: 'Digital Marketing Specialist',
    description: 'Run digital campaigns and optimize conversion',
    category: 'Marketing',
    isHighDemand: false,
    demand: 'Growing',
    salaryMinK: 50,
    salaryMaxK: 85,
    requiredSkills: ['SEO', 'Google Ads', 'Social Media', 'Analytics', 'Content', 'Copywriting'],
    requiredCourses: ['Digital Marketing', 'Analytics', 'Content Marketing'],
    lastUpdated: '2026-02-19',
  },
  {
    id: '13',
    title: 'SEO Specialist',
    description: 'Improve organic search visibility and traffic',
    category: 'Marketing',
    isHighDemand: false,
    demand: 'Stable',
    salaryMinK: 45,
    salaryMaxK: 75,
    requiredSkills: ['SEO', 'Keyword Research', 'Analytics', 'Content', 'Technical SEO'],
    requiredCourses: ['SEO Fundamentals', 'Content Strategy', 'Analytics'],
    lastUpdated: '2025-11-09',
  },
  {
    id: '14',
    title: 'Social Media Manager',
    description: 'Manage brand presence and engagement on social platforms',
    category: 'Marketing',
    isHighDemand: false,
    demand: 'Medium',
    salaryMinK: 45,
    salaryMaxK: 70,
    requiredSkills: ['Social Media', 'Content', 'Analytics', 'Copywriting', 'Scheduling'],
    requiredCourses: ['Social Media Marketing', 'Content Strategy'],
    lastUpdated: '2024-06-15',
  },
  {
    id: '15',
    title: 'Mobile App Developer',
    description: 'Build native or cross-platform mobile applications',
    category: 'Development',
    isHighDemand: true,
    demand: 'High',
    salaryMinK: 75,
    salaryMaxK: 125,
    requiredSkills: ['React Native', 'Swift', 'Kotlin', 'REST', 'Git'],
    requiredCourses: ['Mobile Development', 'APIs', 'UI/UX'],
    lastUpdated: '2025-12-13',
  },
]

export function getUniqueCategories(roles: JobRole[]): string[] {
  const set = new Set(roles.map((r) => r.category))
  return Array.from(set).sort()
}

export function getHighDemandCount(roles: JobRole[]): number {
  return roles.filter((r) => r.isHighDemand || r.demand === 'High').length
}
