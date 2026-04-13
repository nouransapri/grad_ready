/// Phase 1: Seed data for Firestore "skills" collection.
/// Safe to run once: only inserts if document does not exist. Does not modify users or jobs.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/skill_document.dart';

/// Returns the 10 Phase 1 skills with full structure (courses, certifications, resources, projects).
List<SkillDocument> getPhase1Skills() {
  final now = DateTime.now();
  return [
    _javascript(now),
    _python(now),
    _react(now),
    _html(now),
    _css(now),
    _communication(now),
    _teamwork(now),
    _problemSolving(now),
    _figma(now),
    _git(now),
  ];
}

SkillDocument _javascript(DateTime now) {
  return SkillDocument(
    skillId: 'javascript',
    skillName: 'JavaScript',
    aliases: ['JS', 'ECMAScript'],
    type: 'Technical',
    category: 'Programming',
    subCategory: 'Frontend',
    description: 'The standard language for web interactivity and modern full-stack development.',
    difficultyLevel: 'Intermediate',
    learningCurve: 'Moderate',
    averageTimeToLearn: const AverageTimeToLearn(beginner: '2-4 weeks', intermediate: '3-6 months', advanced: '1-2 years'),
    prerequisites: ['html', 'css'],
    relatedSkills: ['typescript', 'react', 'node_js', 'html', 'css'],
    advancedSkills: ['node_js', 'typescript', 'react'],
    demandLevel: 'Very High',
    trending: true,
    growthRate: '12%',
    averageSalaryImpact: '+15%',
    usedInJobs: const [],
    courses: [
      const SkillCourse(
        courseId: 'js-complete-guide',
        title: 'JavaScript - The Complete Guide 2024',
        platform: 'Udemy',
        url: 'https://www.udemy.com/course/javascript-the-complete-guide-2020-beginner-advanced/',
        rating: 4.6,
        level: 'Beginner',
        isPrimary: true,
      ),
      const SkillCourse(
        courseId: 'js-tutorial',
        title: 'The Modern JavaScript Tutorial',
        platform: 'freeCodeCamp',
        url: 'https://www.freecodecamp.org/news/learn-javascript-full-course/',
        rating: 4.8,
        level: 'Beginner',
        isPrimary: false,
      ),
    ],
    certifications: const [
      SkillCertification(
        certId: 'meta-frontend',
        name: 'Meta Front-End Developer Professional Certificate',
        provider: 'Coursera',
        url: 'https://www.coursera.org/professional-certificates/meta-front-end-developer',
        cost: 'Subscription',
        validityYears: 0,
        difficulty: 'Intermediate',
      ),
    ],
    learningResources: const [
      SkillLearningResource(type: 'Documentation', title: 'MDN JavaScript Guide', url: 'https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide', source: 'MDN', isFree: true),
      SkillLearningResource(type: 'Tutorial', title: 'JavaScript.info', url: 'https://javascript.info/', source: 'javascript.info', isFree: true),
      SkillLearningResource(type: 'Practice', title: 'freeCodeCamp JavaScript Algorithms', url: 'https://www.freecodecamp.org/learn/javascript-algorithms-and-data-structures/', source: 'freeCodeCamp', isFree: true),
    ],
    practiceProjects: const [
      SkillPracticeProject(title: 'Todo App', description: 'Build a todo list with add, complete, delete.', difficulty: 'Beginner', estimatedHours: 4, githubUrl: 'https://github.com', tutorialUrl: 'https://javascript.info'),
      SkillPracticeProject(title: 'Weather App', description: 'Fetch and display weather using a public API.', difficulty: 'Intermediate', estimatedHours: 8, githubUrl: 'https://github.com'),
      SkillPracticeProject(title: 'Portfolio Site', description: 'Single-page portfolio with smooth scroll and forms.', difficulty: 'Beginner', estimatedHours: 6),
    ],
    totalJobsUsingSkill: 0,
    averageRequiredLevel: 0,
    mostCommonPriority: 'Critical',
    icon: null,
    color: '#F7DF1E',
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
}

SkillDocument _python(DateTime now) {
  return SkillDocument(
    skillId: 'python',
    skillName: 'Python',
    aliases: ['Py'],
    type: 'Technical',
    category: 'Programming',
    subCategory: 'Backend / Data',
    description: 'General-purpose language for web, data science, automation, and scripting.',
    difficultyLevel: 'Beginner',
    learningCurve: 'Gentle',
    averageTimeToLearn: const AverageTimeToLearn(beginner: '2-3 weeks', intermediate: '2-4 months', advanced: '1+ years'),
    prerequisites: [],
    relatedSkills: ['django', 'flask', 'sql', 'machine_learning'],
    advancedSkills: ['django', 'machine_learning', 'data_analysis'],
    demandLevel: 'Very High',
    trending: true,
    growthRate: '14%',
    averageSalaryImpact: '+18%',
    usedInJobs: const [],
    courses: [
      const SkillCourse(
        courseId: 'python-everybody',
        title: 'Python for Everybody Specialization',
        platform: 'Coursera',
        url: 'https://www.coursera.org/specializations/python',
        rating: 4.8,
        level: 'Beginner',
        isPrimary: true,
      ),
      const SkillCourse(
        courseId: 'python-freecodecamp',
        title: 'Learn Python - Full Course for Beginners',
        platform: 'freeCodeCamp',
        url: 'https://www.freecodecamp.org/news/learn-python-full-course/',
        rating: 4.7,
        level: 'Beginner',
        isPrimary: false,
      ),
    ],
    certifications: const [
      SkillCertification(
        certId: 'pcap',
        name: 'PCAP – Certified Associate in Python Programming',
        provider: 'Python Institute',
        url: 'https://pythoninstitute.org/pcap',
        cost: '~\$295',
        validityYears: 0,
        difficulty: 'Intermediate',
      ),
    ],
    learningResources: const [
      SkillLearningResource(type: 'Documentation', title: 'Python Official Tutorial', url: 'https://docs.python.org/3/tutorial/', source: 'Python.org', isFree: true),
      SkillLearningResource(type: 'Book', title: 'Automate the Boring Stuff', url: 'https://automatetheboringstuff.com/', source: 'Al Sweigart', isFree: true),
      SkillLearningResource(type: 'Practice', title: 'LeetCode Python', url: 'https://leetcode.com/', source: 'LeetCode', isFree: true),
    ],
    practiceProjects: const [
      SkillPracticeProject(title: 'CLI Calculator', description: 'Command-line calculator with basic operations.', difficulty: 'Beginner', estimatedHours: 2),
      SkillPracticeProject(title: 'Web Scraper', description: 'Scrape a website and save data to CSV.', difficulty: 'Intermediate', estimatedHours: 6),
      SkillPracticeProject(title: 'REST API with Flask', description: 'Simple REST API with GET/POST endpoints.', difficulty: 'Intermediate', estimatedHours: 8),
    ],
    totalJobsUsingSkill: 0,
    averageRequiredLevel: 0,
    mostCommonPriority: 'Critical',
    color: '#3776AB',
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
}

SkillDocument _react(DateTime now) {
  return SkillDocument(
    skillId: 'react',
    skillName: 'React',
    aliases: ['React.js', 'ReactJS'],
    type: 'Technical',
    category: 'Framework',
    subCategory: 'Frontend',
    description: 'Library for building user interfaces with components and declarative UI.',
    difficultyLevel: 'Intermediate',
    learningCurve: 'Moderate',
    averageTimeToLearn: const AverageTimeToLearn(beginner: '3-4 weeks', intermediate: '2-4 months', advanced: '6+ months'),
    prerequisites: ['javascript', 'html', 'css'],
    relatedSkills: ['javascript', 'redux', 'typescript', 'next_js'],
    advancedSkills: ['next_js', 'redux', 'react_native'],
    demandLevel: 'Very High',
    trending: true,
    growthRate: '10%',
    averageSalaryImpact: '+12%',
    usedInJobs: const [],
    courses: [
      const SkillCourse(
        courseId: 'react-complete',
        title: 'React - The Complete Guide',
        platform: 'Udemy',
        url: 'https://www.udemy.com/course/react-the-complete-guide/',
        rating: 4.6,
        level: 'Beginner',
        isPrimary: true,
      ),
      const SkillCourse(
        courseId: 'react-frontend',
        title: 'Front-End Development with React',
        platform: 'Coursera',
        url: 'https://www.coursera.org/learn/front-end-react',
        rating: 4.7,
        level: 'Intermediate',
        isPrimary: false,
      ),
    ],
    certifications: const [
      SkillCertification(
        certId: 'meta-react',
        name: 'Meta Front-End Developer Professional Certificate',
        provider: 'Coursera',
        url: 'https://www.coursera.org/professional-certificates/meta-front-end-developer',
        cost: 'Subscription',
        validityYears: 0,
        difficulty: 'Intermediate',
      ),
    ],
    learningResources: const [
      SkillLearningResource(type: 'Documentation', title: 'React Official Docs', url: 'https://react.dev/', source: 'React', isFree: true),
      SkillLearningResource(type: 'Tutorial', title: 'React Tutorial (official)', url: 'https://react.dev/learn', source: 'React', isFree: true),
      SkillLearningResource(type: 'Practice', title: 'freeCodeCamp Front End Libraries', url: 'https://www.freecodecamp.org/learn/front-end-development-libraries/', source: 'freeCodeCamp', isFree: true),
    ],
    practiceProjects: const [
      SkillPracticeProject(title: 'Counter App', description: 'Stateful counter with hooks.', difficulty: 'Beginner', estimatedHours: 2),
      SkillPracticeProject(title: 'Movie Search', description: 'Search movies via API and display results.', difficulty: 'Intermediate', estimatedHours: 6),
      SkillPracticeProject(title: 'Todo with Filters', description: 'Todo app with filter by status and persistence.', difficulty: 'Intermediate', estimatedHours: 8),
    ],
    totalJobsUsingSkill: 0,
    averageRequiredLevel: 0,
    mostCommonPriority: 'Critical',
    color: '#61DAFB',
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
}

SkillDocument _html(DateTime now) {
  return SkillDocument(
    skillId: 'html',
    skillName: 'HTML',
    aliases: ['HTML5', 'Hypertext Markup Language'],
    type: 'Technical',
    category: 'Programming',
    subCategory: 'Frontend',
    description: 'Markup language for structure and content of web pages.',
    difficultyLevel: 'Beginner',
    learningCurve: 'Gentle',
    averageTimeToLearn: const AverageTimeToLearn(beginner: '1-2 weeks', intermediate: '1-2 months', advanced: '3-6 months'),
    prerequisites: [],
    relatedSkills: ['css', 'javascript', 'accessibility'],
    advancedSkills: ['accessibility', 'semantic_html'],
    demandLevel: 'Very High',
    trending: false,
    growthRate: '5%',
    averageSalaryImpact: '+5%',
    usedInJobs: const [],
    courses: [
      const SkillCourse(
        courseId: 'html-mdn',
        title: 'HTML - Structuring the Web',
        platform: 'MDN',
        url: 'https://developer.mozilla.org/en-US/docs/Learn/HTML',
        rating: 4.8,
        level: 'Beginner',
        isPrimary: true,
      ),
      const SkillCourse(
        courseId: 'html-freecodecamp',
        title: 'Responsive Web Design - HTML',
        platform: 'freeCodeCamp',
        url: 'https://www.freecodecamp.org/learn/responsive-web-design/',
        rating: 4.7,
        level: 'Beginner',
        isPrimary: false,
      ),
    ],
    certifications: const [
      SkillCertification(
        certId: 'w3c-html',
        name: 'W3Cx Front-End Developer Program',
        provider: 'edX',
        url: 'https://www.edx.org/learn/html',
        cost: 'Free / Paid certificate',
        validityYears: 0,
        difficulty: 'Beginner',
      ),
    ],
    learningResources: const [
      SkillLearningResource(type: 'Documentation', title: 'MDN HTML', url: 'https://developer.mozilla.org/en-US/docs/Web/HTML', source: 'MDN', isFree: true),
      SkillLearningResource(type: 'Reference', title: 'HTML Reference', url: 'https://htmlreference.io/', source: 'htmlreference.io', isFree: true),
      SkillLearningResource(type: 'Practice', title: 'freeCodeCamp HTML', url: 'https://www.freecodecamp.org/learn/responsive-web-design/', source: 'freeCodeCamp', isFree: true),
    ],
    practiceProjects: const [
      SkillPracticeProject(title: 'Personal Page', description: 'Single-page bio with sections.', difficulty: 'Beginner', estimatedHours: 3),
      SkillPracticeProject(title: 'Recipe Page', description: 'Structured recipe with lists and images.', difficulty: 'Beginner', estimatedHours: 4),
      SkillPracticeProject(title: 'Survey Form', description: 'Accessible form with labels and validation.', difficulty: 'Beginner', estimatedHours: 5),
    ],
    totalJobsUsingSkill: 0,
    averageRequiredLevel: 0,
    mostCommonPriority: 'Critical',
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
}

SkillDocument _css(DateTime now) {
  return SkillDocument(
    skillId: 'css',
    skillName: 'CSS',
    aliases: ['CSS3', 'Cascading Style Sheets'],
    type: 'Technical',
    category: 'Programming',
    subCategory: 'Frontend',
    description: 'Stylesheet language for layout, colors, and presentation of web pages.',
    difficultyLevel: 'Beginner',
    learningCurve: 'Moderate',
    averageTimeToLearn: const AverageTimeToLearn(beginner: '2-3 weeks', intermediate: '2-4 months', advanced: '6+ months'),
    prerequisites: ['html'],
    relatedSkills: ['html', 'javascript', 'sass', 'responsive_design'],
    advancedSkills: ['sass', 'css_grid', 'animations'],
    demandLevel: 'Very High',
    trending: false,
    growthRate: '5%',
    averageSalaryImpact: '+5%',
    usedInJobs: const [],
    courses: [
      const SkillCourse(
        courseId: 'css-mdn',
        title: 'CSS - Styling the Web',
        platform: 'MDN',
        url: 'https://developer.mozilla.org/en-US/docs/Learn/CSS',
        rating: 4.8,
        level: 'Beginner',
        isPrimary: true,
      ),
      const SkillCourse(
        courseId: 'css-freecodecamp',
        title: 'Responsive Web Design - CSS',
        platform: 'freeCodeCamp',
        url: 'https://www.freecodecamp.org/learn/responsive-web-design/',
        rating: 4.7,
        level: 'Beginner',
        isPrimary: false,
      ),
    ],
    certifications: const [
      SkillCertification(
        certId: 'w3c-css',
        name: 'W3Cx Front-End Developer - CSS',
        provider: 'edX',
        url: 'https://www.edx.org/learn/css',
        cost: 'Free / Paid certificate',
        validityYears: 0,
        difficulty: 'Beginner',
      ),
    ],
    learningResources: const [
      SkillLearningResource(type: 'Documentation', title: 'MDN CSS', url: 'https://developer.mozilla.org/en-US/docs/Web/CSS', source: 'MDN', isFree: true),
      SkillLearningResource(type: 'Reference', title: 'CSS-Tricks', url: 'https://css-tricks.com/', source: 'CSS-Tricks', isFree: true),
      SkillLearningResource(type: 'Practice', title: 'freeCodeCamp CSS', url: 'https://www.freecodecamp.org/learn/responsive-web-design/', source: 'freeCodeCamp', isFree: true),
    ],
    practiceProjects: const [
      SkillPracticeProject(title: 'Landing Page', description: 'Hero, features, footer with Flexbox/Grid.', difficulty: 'Beginner', estimatedHours: 5),
      SkillPracticeProject(title: 'Photo Gallery', description: 'Responsive grid with hover effects.', difficulty: 'Beginner', estimatedHours: 4),
      SkillPracticeProject(title: 'Dashboard Layout', description: 'Sidebar + main content responsive layout.', difficulty: 'Intermediate', estimatedHours: 6),
    ],
    totalJobsUsingSkill: 0,
    averageRequiredLevel: 0,
    mostCommonPriority: 'Critical',
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
}

SkillDocument _communication(DateTime now) {
  return SkillDocument(
    skillId: 'communication',
    skillName: 'Communication',
    aliases: ['Verbal Communication', 'Written Communication'],
    type: 'Soft',
    category: 'Interpersonal',
    subCategory: 'Professional Skills',
    description: 'Ability to convey ideas clearly and listen effectively in professional settings.',
    difficultyLevel: 'Beginner',
    learningCurve: 'Gentle',
    averageTimeToLearn: const AverageTimeToLearn(beginner: 'Ongoing', intermediate: '6 months', advanced: 'Continuous'),
    prerequisites: [],
    relatedSkills: ['presentation_skills', 'writing', 'teamwork', 'leadership'],
    advancedSkills: ['presentation_skills', 'negotiation', 'storytelling'],
    demandLevel: 'Very High',
    trending: true,
    growthRate: '8%',
    averageSalaryImpact: '+10%',
    usedInJobs: const [],
    courses: [
      const SkillCourse(
        courseId: 'comm-coursera',
        title: 'Improve Your English Communication Skills',
        platform: 'Coursera',
        url: 'https://www.coursera.org/specializations/improve-english',
        rating: 4.7,
        level: 'Beginner',
        isPrimary: true,
      ),
      const SkillCourse(
        courseId: 'comm-effective',
        title: 'Effective Communication: Writing, Design, and Presentation',
        platform: 'Coursera',
        url: 'https://www.coursera.org/specializations/effective-business-communication',
        rating: 4.6,
        level: 'Beginner',
        isPrimary: false,
      ),
    ],
    certifications: const [
      SkillCertification(
        certId: 'linkedin-comm',
        name: 'Communication Foundations',
        provider: 'LinkedIn Learning',
        url: 'https://www.linkedin.com/learning/communication-foundations',
        cost: 'Subscription',
        validityYears: 0,
        difficulty: 'Beginner',
      ),
    ],
    learningResources: const [
      SkillLearningResource(type: 'Article', title: 'Harvard Business Review - Communication', url: 'https://hbr.org/topic/subject/communication', source: 'HBR', isFree: true),
      SkillLearningResource(type: 'Video', title: 'TED Talks - Communication', url: 'https://www.ted.com/topics/communication', source: 'TED', isFree: true),
      SkillLearningResource(type: 'Course', title: 'Coursera - Work Smarter', url: 'https://www.coursera.org/learn/work-smarter-not-harder', source: 'Coursera', isFree: true),
    ],
    practiceProjects: const [
      SkillPracticeProject(title: 'Elevator Pitch', description: 'Write and deliver a 60-second pitch.', difficulty: 'Beginner', estimatedHours: 2),
      SkillPracticeProject(title: 'Meeting Notes', description: 'Take and share clear meeting notes for 5 meetings.', difficulty: 'Beginner', estimatedHours: 5),
      SkillPracticeProject(title: 'Presentation', description: 'Create and present a 10-min presentation to peers.', difficulty: 'Intermediate', estimatedHours: 8),
    ],
    totalJobsUsingSkill: 0,
    averageRequiredLevel: 0,
    mostCommonPriority: 'Critical',
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
}

SkillDocument _teamwork(DateTime now) {
  return SkillDocument(
    skillId: 'teamwork',
    skillName: 'Teamwork',
    aliases: ['Collaboration', 'Team Player'],
    type: 'Soft',
    category: 'Interpersonal',
    subCategory: 'Professional Skills',
    description: 'Working effectively with others toward shared goals.',
    difficultyLevel: 'Beginner',
    learningCurve: 'Gentle',
    averageTimeToLearn: const AverageTimeToLearn(beginner: 'Ongoing', intermediate: '3-6 months', advanced: 'Continuous'),
    prerequisites: ['communication'],
    relatedSkills: ['communication', 'leadership', 'conflict_resolution'],
    advancedSkills: ['leadership', 'facilitation'],
    demandLevel: 'Very High',
    trending: true,
    growthRate: '7%',
    averageSalaryImpact: '+8%',
    usedInJobs: const [],
    courses: [
      const SkillCourse(
        courseId: 'teamwork-coursera',
        title: 'Teamwork Skills: Communicating Effectively in Groups',
        platform: 'Coursera',
        url: 'https://www.coursera.org/learn/teamwork-skills-effective-communication',
        rating: 4.7,
        level: 'Beginner',
        isPrimary: true,
      ),
      const SkillCourse(
        courseId: 'leading-teams',
        title: 'Leading Teams',
        platform: 'Coursera',
        url: 'https://www.coursera.org/learn/leading-teams',
        rating: 4.8,
        level: 'Intermediate',
        isPrimary: false,
      ),
    ],
    certifications: const [
      SkillCertification(
        certId: 'scrum-foundation',
        name: 'Scrum Foundation Professional Certificate',
        provider: 'CertiProf',
        url: 'https://www.certiprof.com/',
        cost: 'Free',
        validityYears: 0,
        difficulty: 'Beginner',
      ),
    ],
    learningResources: const [
      SkillLearningResource(type: 'Article', title: 'Mind Tools - Teamwork', url: 'https://www.mindtools.com/pages/article/newLDR_86.htm', source: 'Mind Tools', isFree: true),
      SkillLearningResource(type: 'Video', title: 'Google re:Work - Team Effectiveness', url: 'https://rework.withgoogle.com/', source: 'Google', isFree: true),
      SkillLearningResource(type: 'Guide', title: 'Project Management Guide', url: 'https://www.pmi.org/learning', source: 'PMI', isFree: true),
    ],
    practiceProjects: const [
      SkillPracticeProject(title: 'Group Project', description: 'Complete a small project with 2-3 peers.', difficulty: 'Beginner', estimatedHours: 10),
      SkillPracticeProject(title: 'Peer Feedback', description: 'Give and receive structured feedback in a team.', difficulty: 'Beginner', estimatedHours: 3),
      SkillPracticeProject(title: 'Retrospective', description: 'Facilitate a team retrospective meeting.', difficulty: 'Intermediate', estimatedHours: 2),
    ],
    totalJobsUsingSkill: 0,
    averageRequiredLevel: 0,
    mostCommonPriority: 'Important',
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
}

SkillDocument _problemSolving(DateTime now) {
  return SkillDocument(
    skillId: 'problem_solving',
    skillName: 'Problem Solving',
    aliases: ['Analytical Thinking', 'Critical Thinking'],
    type: 'Soft',
    category: 'Cognitive',
    subCategory: 'Professional Skills',
    description: 'Identifying problems, analyzing options, and implementing effective solutions.',
    difficultyLevel: 'Beginner',
    learningCurve: 'Moderate',
    averageTimeToLearn: const AverageTimeToLearn(beginner: '3 months', intermediate: '6 months', advanced: 'Ongoing'),
    prerequisites: [],
    relatedSkills: ['critical_thinking', 'communication', 'analytical_skills'],
    advancedSkills: ['systems_thinking', 'decision_making'],
    demandLevel: 'Very High',
    trending: true,
    growthRate: '9%',
    averageSalaryImpact: '+12%',
    usedInJobs: const [],
    courses: [
      const SkillCourse(
        courseId: 'creative-problem-solving',
        title: 'Creative Problem Solving',
        platform: 'Coursera',
        url: 'https://www.coursera.org/learn/creative-problem-solving',
        rating: 4.7,
        level: 'Beginner',
        isPrimary: true,
      ),
      const SkillCourse(
        courseId: 'critical-thinking',
        title: 'Critical Thinking and Problem Solving',
        platform: 'LinkedIn Learning',
        url: 'https://www.linkedin.com/learning/critical-thinking-and-problem-solving',
        rating: 4.6,
        level: 'Beginner',
        isPrimary: false,
      ),
    ],
    certifications: const [
      SkillCertification(
        certId: 'certiprof-critical',
        name: 'Critical Thinking Professional Certificate',
        provider: 'CertiProf',
        url: 'https://www.certiprof.com/',
        cost: 'Free',
        validityYears: 0,
        difficulty: 'Beginner',
      ),
    ],
    learningResources: const [
      SkillLearningResource(type: 'Article', title: 'Problem Solving Techniques', url: 'https://www.mindtools.com/pages/article/newTMC_72.htm', source: 'Mind Tools', isFree: true),
      SkillLearningResource(type: 'Practice', title: 'LeetCode', url: 'https://leetcode.com/', source: 'LeetCode', isFree: true),
      SkillLearningResource(type: 'Course', title: 'Algorithmic Thinking', url: 'https://www.coursera.org/learn/algorithmic-thinking', source: 'Coursera', isFree: true),
    ],
    practiceProjects: const [
      SkillPracticeProject(title: 'Debug a Bug', description: 'Document and fix a real bug using a method.', difficulty: 'Beginner', estimatedHours: 3),
      SkillPracticeProject(title: 'Process Improvement', description: 'Identify and propose improvement for a workflow.', difficulty: 'Intermediate', estimatedHours: 5),
      SkillPracticeProject(title: 'Case Study', description: 'Analyze a business case and present solution.', difficulty: 'Intermediate', estimatedHours: 6),
    ],
    totalJobsUsingSkill: 0,
    averageRequiredLevel: 0,
    mostCommonPriority: 'Critical',
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
}

SkillDocument _figma(DateTime now) {
  return SkillDocument(
    skillId: 'figma',
    skillName: 'Figma',
    aliases: ['Figma Design'],
    type: 'Tool',
    category: 'Design',
    subCategory: 'UI/UX',
    description: 'Collaborative interface design and prototyping tool.',
    difficultyLevel: 'Beginner',
    learningCurve: 'Gentle',
    averageTimeToLearn: const AverageTimeToLearn(beginner: '1-2 weeks', intermediate: '1-2 months', advanced: '3-6 months'),
    prerequisites: [],
    relatedSkills: ['ui_design', 'ux_design', 'prototyping'],
    advancedSkills: ['design_systems', 'prototyping'],
    demandLevel: 'High',
    trending: true,
    growthRate: '15%',
    averageSalaryImpact: '+8%',
    usedInJobs: const [],
    courses: [
      const SkillCourse(
        courseId: 'figma-bootcamp',
        title: 'Figma Design - UI/UX Design Bootcamp',
        platform: 'Udemy',
        url: 'https://www.udemy.com/course/figma-design/',
        rating: 4.6,
        level: 'Beginner',
        isPrimary: true,
      ),
      const SkillCourse(
        courseId: 'figma-coursera',
        title: 'UI/UX Design with Figma',
        platform: 'Coursera',
        url: 'https://www.coursera.org/learn/ui-ux-design-figma',
        rating: 4.5,
        level: 'Beginner',
        isPrimary: false,
      ),
    ],
    certifications: const [
      SkillCertification(
        certId: 'figma-cert',
        name: 'Figma Skills Certificate',
        provider: 'Figma',
        url: 'https://www.figma.com/skill-certification/',
        cost: 'Free',
        validityYears: 0,
        difficulty: 'Beginner',
      ),
    ],
    learningResources: const [
      SkillLearningResource(type: 'Documentation', title: 'Figma Help', url: 'https://help.figma.com/', source: 'Figma', isFree: true),
      SkillLearningResource(type: 'Tutorial', title: 'Figma YouTube', url: 'https://www.youtube.com/figma', source: 'Figma', isFree: true),
      SkillLearningResource(type: 'Community', title: 'Figma Community', url: 'https://www.figma.com/community', source: 'Figma', isFree: true),
    ],
    practiceProjects: const [
      SkillPracticeProject(title: 'Mobile Screen', description: 'Design one mobile app screen from scratch.', difficulty: 'Beginner', estimatedHours: 4),
      SkillPracticeProject(title: 'Component Set', description: 'Create 5 reusable components with variants.', difficulty: 'Intermediate', estimatedHours: 6),
      SkillPracticeProject(title: 'Clickable Prototype', description: 'Build a 5-screen clickable prototype.', difficulty: 'Intermediate', estimatedHours: 8),
    ],
    totalJobsUsingSkill: 0,
    averageRequiredLevel: 0,
    mostCommonPriority: 'Important',
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
}

SkillDocument _git(DateTime now) {
  return SkillDocument(
    skillId: 'git',
    skillName: 'Git',
    aliases: ['Version Control', 'Source Control'],
    type: 'Tool',
    category: 'Development',
    subCategory: 'Version Control',
    description: 'Distributed version control for tracking code changes and collaboration.',
    difficultyLevel: 'Beginner',
    learningCurve: 'Moderate',
    averageTimeToLearn: const AverageTimeToLearn(beginner: '1 week', intermediate: '1 month', advanced: '3 months'),
    prerequisites: [],
    relatedSkills: ['github', 'ci_cd', 'linux'],
    advancedSkills: ['github_actions', 'git_workflows'],
    demandLevel: 'Very High',
    trending: false,
    growthRate: '6%',
    averageSalaryImpact: '+5%',
    usedInJobs: const [],
    courses: [
      const SkillCourse(
        courseId: 'git-coursera',
        title: 'Version Control with Git',
        platform: 'Coursera',
        url: 'https://www.coursera.org/learn/version-control-with-git',
        rating: 4.7,
        level: 'Beginner',
        isPrimary: true,
      ),
      const SkillCourse(
        courseId: 'git-complete',
        title: 'Git Complete: The Definitive Guide',
        platform: 'Udemy',
        url: 'https://www.udemy.com/course/git-complete/',
        rating: 4.6,
        level: 'Beginner',
        isPrimary: false,
      ),
    ],
    certifications: const [
      SkillCertification(
        certId: 'git-associate',
        name: 'Git Associate Certification',
        provider: 'ExamPro',
        url: 'https://www.exampro.co/',
        cost: 'Paid',
        validityYears: 0,
        difficulty: 'Beginner',
      ),
    ],
    learningResources: const [
      SkillLearningResource(type: 'Documentation', title: 'Git Book', url: 'https://git-scm.com/book/en/v2', source: 'Git', isFree: true),
      SkillLearningResource(type: 'Tutorial', title: 'Learn Git Branching', url: 'https://learngitbranching.js.org/', source: 'PCG', isFree: true),
      SkillLearningResource(type: 'Practice', title: 'GitHub Skills', url: 'https://skills.github.com/', source: 'GitHub', isFree: true),
    ],
    practiceProjects: const [
      SkillPracticeProject(title: 'First Repo', description: 'Create repo, add files, commit, push to GitHub.', difficulty: 'Beginner', estimatedHours: 2),
      SkillPracticeProject(title: 'Branch & Merge', description: 'Create branch, make changes, merge to main.', difficulty: 'Beginner', estimatedHours: 3),
      SkillPracticeProject(title: 'Collaboration', description: 'Fork a repo, clone, push branch, open PR.', difficulty: 'Intermediate', estimatedHours: 4),
    ],
    totalJobsUsingSkill: 0,
    averageRequiredLevel: 0,
    mostCommonPriority: 'Critical',
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
}

/// Seeds the Firestore "skills" collection with Phase 1 data. Safe to run multiple times:
/// only inserts a document if it does not already exist (by skillId). Does not modify users or jobs.
Future<void> seedSkillsPhase1() async {
  final db = FirebaseFirestore.instance;
  final skills = getPhase1Skills();
  for (final skill in skills) {
    try {
      final ref = db.collection('skills').doc(skill.skillId);
      final snap = await ref.get();
      if (snap.exists) {
        continue;
      }
      await ref.set(skill.toFirestore());
    } catch (_) {
    }
  }
  
}
