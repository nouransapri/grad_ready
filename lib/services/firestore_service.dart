import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/insight_model.dart';
import '../models/job_role.dart';
import '../models/trend_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Stream of all jobs from Firestore 'jobs' collection.
  Stream<List<JobRole>> getJobs() {
    return _db.collection('jobs').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => JobRole.fromFirestore(doc.id, doc.data())).toList();
    });
  }

  /// Real-time stream of a single job by id. Use for live skill gap analysis.
  Stream<JobRole?> getJobStream(String jobId) {
    return _db.collection('jobs').doc(jobId).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return JobRole.fromFirestore(doc.id, doc.data()!);
      }
      return null;
    });
  }

  /// Add a new job role to Firestore. Returns the new document id.
  Future<String> addJob(JobRole job) async {
    final ref = _db.collection('jobs').doc();
    await ref.set(job.toFirestore());
    return ref.id;
  }

  /// Update an existing job role in Firestore by id. Used for bulk "Update Selected" in Market.
  Future<void> updateJob(JobRole job) async {
    if (job.id.isEmpty) return;
    await _db.collection('jobs').doc(job.id).set(job.toFirestore());
  }

  /// Upload default jobs (1-8) + additional jobs (9-20) to Firestore. Run once to seed data.
  Future<void> uploadJobs() async {
    final jobs = [..._defaultJobs, ..._additionalJobs];
    final batch = _db.batch();
    for (var i = 0; i < jobs.length; i++) {
      final ref = _db.collection('jobs').doc('job_${i + 1}');
      batch.set(ref, jobs[i].toFirestore());
    }
    await batch.commit();
  }

  /// Jobs 9–20: diverse roles (Tech, Healthcare, Engineering, Finance, etc.)
  static List<JobRole> get _additionalJobs => [
        JobRole(
          id: '9',
          title: 'AI Engineer',
          description: 'Develops and trains complex neural networks and AI models.',
          category: 'Technology',
          salaryMinK: 110,
          salaryMaxK: 180,
          requiredSkills: ['Python', 'PyTorch', 'Machine Learning', 'Natural Language Processing', 'Deep Learning', 'TensorFlow', 'Data Modeling', 'Research'],
          requiredCourses: ['Machine Learning', 'Deep Learning', 'Neural Networks', 'NLP', 'Python Programming', 'Statistics'],
        ),
        JobRole(
          id: '10',
          title: 'Cybersecurity Analyst',
          description: 'Protects networks and data from cyber attacks and unauthorized access.',
          category: 'Security',
          salaryMinK: 75,
          salaryMaxK: 120,
          requiredSkills: ['Network Security', 'Ethical Hacking', 'Linux', 'SIEM tools', 'Incident Response', 'Risk Assessment', 'Cryptography', 'Communication'],
          requiredCourses: ['Network Security', 'Cybersecurity Fundamentals', 'Ethical Hacking', 'Operating Systems', 'Information Assurance'],
        ),
        JobRole(
          id: '11',
          title: 'Full-Stack Developer',
          description: 'Builds both the front-end and back-end of web applications.',
          category: 'Software Development',
          salaryMinK: 70,
          salaryMaxK: 130,
          requiredSkills: ['React.js', 'Node.js', 'PostgreSQL', 'Docker', 'REST APIs', 'Git', 'HTML/CSS', 'JavaScript'],
          requiredCourses: ['Web Development', 'Database Systems', 'Data Structures', 'JavaScript/TypeScript', 'Software Engineering'],
        ),
        JobRole(
          id: '12',
          title: 'Registered Nurse',
          description: 'Provides patient care, administers medications, and coordinates with doctors.',
          category: 'Healthcare',
          salaryMinK: 55,
          salaryMaxK: 85,
          requiredSkills: ['Patient Assessment', 'Critical Thinking', 'BLS/ACLS', 'Clinical Documentation', 'Medication Administration', 'Communication', 'Empathy', 'Teamwork'],
          requiredCourses: ['Anatomy & Physiology', 'Nursing Fundamentals', 'Pharmacology', 'Clinical Practice', 'Patient Care'],
        ),
        JobRole(
          id: '13',
          title: 'Pharmacist',
          description: 'Dispenses medications and provides expertise on safe medicine use.',
          category: 'Healthcare',
          salaryMinK: 100,
          salaryMaxK: 140,
          requiredSkills: ['Pharmacology', 'Clinical Pharmacy', 'Communication', 'Drug Interactions', 'Patient Counseling', 'Regulatory Compliance', 'Attention to Detail', 'Ethics'],
          requiredCourses: ['Pharmacology', 'Pharmacy Practice', 'Medicinal Chemistry', 'Clinical Pharmacy', 'Healthcare Law'],
        ),
        JobRole(
          id: '14',
          title: 'Renewable Energy Engineer',
          description: 'Designs and implements sustainable energy systems like solar and wind power.',
          category: 'Engineering',
          salaryMinK: 70,
          salaryMaxK: 110,
          requiredSkills: ['Solar PV Design', 'Thermodynamics', 'Energy Modeling', 'Project Management', 'CAD', 'Sustainability', 'Electrical Systems', 'Data Analysis'],
          requiredCourses: ['Renewable Energy Systems', 'Thermodynamics', 'Electrical Engineering', 'Environmental Science', 'Energy Policy'],
        ),
        JobRole(
          id: '15',
          title: 'Civil Engineer',
          description: 'Oversees the design and construction of infrastructure projects like bridges and roads.',
          category: 'Engineering',
          salaryMinK: 65,
          salaryMaxK: 105,
          requiredSkills: ['AutoCAD', 'Structural Design', 'Project Management', 'Soil Mechanics', 'Construction Management', 'CAD/Revit', 'Communication', 'Problem Solving'],
          requiredCourses: ['Structural Engineering', 'Surveying', 'Construction Management', 'Mechanics of Materials', 'Hydraulics'],
        ),
        JobRole(
          id: '16',
          title: 'Financial Analyst',
          description: 'Analyzes financial data to help businesses make investment decisions.',
          category: 'Finance',
          salaryMinK: 60,
          salaryMaxK: 95,
          requiredSkills: ['Financial Modeling', 'Excel (Advanced)', 'Data Analysis', 'Valuation', 'Accounting', 'Reporting', 'Communication', 'Attention to Detail'],
          requiredCourses: ['Corporate Finance', 'Accounting', 'Statistics', 'Financial Markets', 'Excel for Finance'],
        ),
        JobRole(
          id: '17',
          title: 'Digital Marketing Manager',
          description: 'Leads online marketing campaigns across social media and search engines.',
          category: 'Business',
          salaryMinK: 65,
          salaryMaxK: 110,
          requiredSkills: ['SEO', 'Content Strategy', 'Google Analytics', 'Copywriting', 'Social Media Marketing', 'PPC', 'Campaign Management', 'Data-Driven Decision Making'],
          requiredCourses: ['Digital Marketing', 'Marketing Analytics', 'Content Marketing', 'SEO/SEM', 'Consumer Behavior'],
        ),
        JobRole(
          id: '18',
          title: 'HR Specialist',
          description: 'Manages recruitment, employee relations, and company benefits.',
          category: 'Management',
          salaryMinK: 50,
          salaryMaxK: 85,
          requiredSkills: ['Talent Acquisition', 'Labor Law', 'Conflict Resolution', 'Recruitment', 'Employee Relations', 'HRIS', 'Communication', 'Organizational Skills'],
          requiredCourses: ['Human Resource Management', 'Labor Law', 'Organizational Behavior', 'Recruitment & Selection', 'Compensation & Benefits'],
        ),
        JobRole(
          id: '19',
          title: 'Video Editor / Motion Designer',
          description: 'Creates engaging video content and animations for brands and social media.',
          category: 'Media',
          salaryMinK: 45,
          salaryMaxK: 85,
          requiredSkills: ['Adobe Premiere Pro', 'After Effects', 'DaVinci Resolve', 'Motion Graphics', 'Color Grading', 'Storytelling', 'Creativity', 'Time Management'],
          requiredCourses: ['Video Production', 'Motion Design', 'Visual Storytelling', 'Post-Production', 'Digital Media'],
        ),
        JobRole(
          id: '20',
          title: 'Biotechnologist',
          description: 'Uses biological organisms to develop products in medicine and agriculture.',
          category: 'Science',
          salaryMinK: 55,
          salaryMaxK: 95,
          requiredSkills: ['Molecular Biology', 'Lab Analysis', 'Bioinformatics', 'PCR', 'Cell Culture', 'Data Analysis', 'Research', 'Documentation'],
          requiredCourses: ['Molecular Biology', 'Genetics', 'Biochemistry', 'Lab Techniques', 'Bioinformatics', 'Statistics'],
        ),
        JobRole(
          id: '21',
          title: 'Sustainability Consultant',
          description: 'Advises companies on how to reduce their environmental impact and carbon footprint.',
          category: 'Environment',
          salaryMinK: 60,
          salaryMaxK: 100,
          requiredSkills: ['Carbon Accounting', 'ESG Reporting', 'Environmental Science', 'Sustainability Strategy', 'Stakeholder Engagement', 'Data Analysis', 'Communication', 'Project Management'],
          requiredCourses: ['Environmental Science', 'Sustainability & ESG', 'Carbon Management', 'Corporate Sustainability', 'Environmental Policy'],
        ),
        JobRole(
          id: '22',
          title: 'E-commerce Manager',
          description: 'Oversees online sales platforms and optimizes the digital shopping journey.',
          category: 'Business',
          salaryMinK: 55,
          salaryMaxK: 95,
          requiredSkills: ['Shopify', 'Inventory Management', 'Digital Ads', 'Logistics', 'Conversion Optimization', 'Analytics', 'Customer Experience', 'Budget Management'],
          requiredCourses: ['E-commerce Fundamentals', 'Digital Marketing', 'Supply Chain Management', 'Retail Analytics', 'Consumer Behavior'],
        ),
        JobRole(
          id: '23',
          title: 'Product Manager (Tech)',
          description: 'Bridges the gap between business, design, and tech to launch successful products.',
          category: 'Management',
          salaryMinK: 95,
          salaryMaxK: 150,
          requiredSkills: ['Agile Methodology', 'Strategic Planning', 'Roadmap Tools', 'User Research', 'Stakeholder Management', 'Data-Driven Decisions', 'Communication', 'Prioritization'],
          requiredCourses: ['Product Management', 'Agile & Scrum', 'Business Strategy', 'User Experience', 'Technical Fundamentals'],
        ),
        JobRole(
          id: '24',
          title: 'Cloud Architect',
          description: 'Designs and manages complex cloud computing strategies and infrastructure.',
          category: 'Cloud Computing',
          salaryMinK: 120,
          salaryMaxK: 180,
          requiredSkills: ['AWS', 'Azure', 'Google Cloud', 'Terraform', 'Kubernetes', 'System Design', 'Security', 'Cost Optimization'],
          requiredCourses: ['Cloud Architecture', 'AWS/Azure/GCP', 'DevOps & IaC', 'Networking', 'Security in the Cloud'],
        ),
        JobRole(
          id: '25',
          title: 'Blockchain Developer',
          description: 'Develops decentralized applications and smart contracts using blockchain tech.',
          category: 'Web3',
          salaryMinK: 100,
          salaryMaxK: 170,
          requiredSkills: ['Solidity', 'Cryptography', 'Ethereum', 'Rust', 'Smart Contracts', 'Web3.js', 'Problem Solving', 'Security'],
          requiredCourses: ['Blockchain Fundamentals', 'Smart Contracts', 'Cryptography', 'Ethereum Development', 'Distributed Systems'],
        ),
        JobRole(
          id: '26',
          title: 'Instructional Designer',
          description: 'Creates educational curricula and digital learning materials for schools and companies.',
          category: 'Education',
          salaryMinK: 50,
          salaryMaxK: 85,
          requiredSkills: ['Learning Management Systems (LMS)', 'Curriculum Design', 'E-learning', 'Instructional Design Models', 'Assessment', 'Multimedia', 'Communication', 'Project Management'],
          requiredCourses: ['Instructional Design', 'E-learning Development', 'Curriculum Development', 'Learning Theories', 'LMS Administration'],
        ),
        // Aviation & Travel
        JobRole(
          id: '27',
          title: 'Commercial Pilot',
          description: 'Operates commercial aircraft for airlines, ensuring passenger safety and navigation.',
          category: 'Aviation',
          salaryMinK: 80,
          salaryMaxK: 200,
          requiredSkills: ['Aircraft Navigation', 'Flight Safety', 'Communication', 'Crisis Management', 'Decision Making', 'Spatial Awareness', 'Teamwork', 'Regulatory Compliance'],
          requiredCourses: ['Flight Training', 'Aviation Safety', 'Meteorology', 'Navigation', 'Aircraft Systems'],
        ),
        JobRole(
          id: '28',
          title: 'Travel Consultant',
          description: 'Plans and sells transportation and accommodations for travel agencies.',
          category: 'Tourism',
          salaryMinK: 35,
          salaryMaxK: 55,
          requiredSkills: ['Destination Knowledge', 'Customer Service', 'Booking Systems', 'Sales', 'Communication', 'Multitasking', 'Geography', 'Cultural Awareness'],
          requiredCourses: ['Travel & Tourism', 'Customer Service', 'Sales Techniques', 'Destination Management', 'Hospitality'],
        ),
        // Legal & Public Services
        JobRole(
          id: '29',
          title: 'Corporate Lawyer',
          description: 'Advises businesses on legal rights, obligations, and complex transactions.',
          category: 'Legal',
          salaryMinK: 90,
          salaryMaxK: 180,
          requiredSkills: ['Contract Law', 'Negotiation', 'Legal Research', 'Compliance', 'Analytical Thinking', 'Communication', 'Document Drafting', 'Ethics'],
          requiredCourses: ['Contract Law', 'Corporate Law', 'Legal Research', 'Business Law', 'Compliance'],
        ),
        JobRole(
          id: '30',
          title: 'Firefighter / Paramedic',
          description: 'Responds to emergencies, fires, and provides medical care in the field.',
          category: 'Public Service',
          salaryMinK: 45,
          salaryMaxK: 75,
          requiredSkills: ['Emergency Response', 'Physical Fitness', 'First Aid', 'Fire Suppression', 'CPR', 'Crisis Management', 'Teamwork', 'Communication'],
          requiredCourses: ['Emergency Medical Services', 'Firefighting', 'First Aid & CPR', 'Hazardous Materials', 'Rescue Operations'],
        ),
        // Arts, Fashion & Entertainment
        JobRole(
          id: '31',
          title: 'Fashion Designer',
          description: 'Creates original clothing, accessories, and footwear.',
          category: 'Arts',
          salaryMinK: 45,
          salaryMaxK: 120,
          requiredSkills: ['Textile Knowledge', 'Sketching', 'Sewing', 'Fashion Trends', 'Creativity', 'Color Theory', 'Pattern Making', 'Presentation'],
          requiredCourses: ['Fashion Design', 'Textile Science', 'Pattern Making', 'Fashion History', 'Design Software'],
        ),
        JobRole(
          id: '32',
          title: 'Sound Engineer',
          description: 'Operates equipment to record, mix, and reproduce sound for music and film.',
          category: 'Entertainment',
          salaryMinK: 40,
          salaryMaxK: 85,
          requiredSkills: ['Audio Mixing', 'Digital Audio Workstations (DAW)', 'Acoustics', 'Recording', 'Editing', 'Signal Flow', 'Ear Training', 'Collaboration'],
          requiredCourses: ['Audio Engineering', 'Sound Design', 'Acoustics', 'Music Production', 'DAW Software'],
        ),
        // Agriculture & Food Science
        JobRole(
          id: '33',
          title: 'Agricultural Scientist',
          description: 'Researches ways to improve the efficiency and safety of agricultural crops and animals.',
          category: 'Agriculture',
          salaryMinK: 55,
          salaryMaxK: 95,
          requiredSkills: ['Soil Science', 'Biology', 'Research Methods', 'Data Collection', 'Statistics', 'Sustainability', 'Lab Techniques', 'Report Writing'],
          requiredCourses: ['Agricultural Science', 'Soil Science', 'Plant Biology', 'Research Methods', 'Statistics'],
        ),
        JobRole(
          id: '34',
          title: 'Executive Chef',
          description: 'Oversees the kitchen operations, menu planning, and staff management in restaurants.',
          category: 'Food Industry',
          salaryMinK: 50,
          salaryMaxK: 95,
          requiredSkills: ['Culinary Arts', 'Menu Engineering', 'Food Safety', 'Leadership', 'Inventory Management', 'Creativity', 'Team Management', 'Cost Control'],
          requiredCourses: ['Culinary Arts', 'Food Safety', 'Nutrition', 'Restaurant Management', 'Menu Planning'],
        ),
        // Fitness & Sports
        JobRole(
          id: '35',
          title: 'Personal Trainer',
          description: 'Designs and implements fitness programs for individuals based on their goals.',
          category: 'Fitness',
          salaryMinK: 35,
          salaryMaxK: 65,
          requiredSkills: ['Anatomy', 'Nutrition Coaching', 'Exercise Programming', 'Motivation', 'Communication', 'Client Assessment', 'Injury Prevention', 'Goal Setting'],
          requiredCourses: ['Exercise Science', 'Anatomy & Physiology', 'Nutrition', 'CPR Certification', 'Fitness Assessment'],
        ),
        JobRole(
          id: '36',
          title: 'Sports Agent',
          description: 'Represents professional athletes and handles their contracts and endorsements.',
          category: 'Sports Management',
          salaryMinK: 60,
          salaryMaxK: 150,
          requiredSkills: ['Contract Negotiation', 'Marketing', 'Public Relations', 'Law', 'Networking', 'Communication', 'Financial Planning', 'Industry Knowledge'],
          requiredCourses: ['Sports Management', 'Contract Law', 'Marketing', 'Negotiation', 'Finance'],
        ),
        // Logistics
        JobRole(
          id: '37',
          title: 'Logistics Manager',
          description: 'Coordinates the movement and storage of goods in a supply chain.',
          category: 'Logistics',
          salaryMinK: 60,
          salaryMaxK: 100,
          requiredSkills: ['Inventory Management', 'Transportation Planning', 'Analytics', 'Supply Chain', 'Vendor Management', 'Problem Solving', 'Communication', 'ERP Systems'],
          requiredCourses: ['Supply Chain Management', 'Logistics', 'Operations Management', 'Inventory Control', 'Analytics'],
        ),
        // Space & Future Tech
        JobRole(
          id: '38',
          title: 'Aerospace Engineer',
          description: 'Designs and tests satellites, spacecraft, and missiles.',
          category: 'Space & Tech',
          salaryMinK: 85,
          salaryMaxK: 140,
          requiredSkills: ['Aerodynamics', 'Propulsion', 'Physics', 'CAD Software', 'Systems Engineering', 'Simulation', 'Problem Solving', 'Documentation'],
          requiredCourses: ['Aerospace Engineering', 'Aerodynamics', 'Propulsion', 'Structural Analysis', 'Control Systems'],
        ),
        JobRole(
          id: '39',
          title: 'Robotics Technician',
          description: 'Builds, installs, and maintains robotic systems for manufacturing.',
          category: 'Robotics',
          salaryMinK: 50,
          salaryMaxK: 85,
          requiredSkills: ['Electronics', 'C++', 'Hydraulics', 'Troubleshooting', 'PLC', 'Mechanical Systems', 'Safety Protocols', 'Documentation'],
          requiredCourses: ['Robotics', 'Electronics', 'Programming', 'Hydraulics & Pneumatics', 'Industrial Maintenance'],
        ),
        // Media, Arts & Design
        JobRole(
          id: '40',
          title: 'Journalist / News Reporter',
          description: 'Investigates and reports on current events for news organizations.',
          category: 'Media',
          salaryMinK: 40,
          salaryMaxK: 75,
          requiredSkills: ['News Writing', 'Interviewing', 'Ethics', 'Investigative Research', 'Communication', 'Deadline Management', 'Fact-Checking', 'Multimedia'],
          requiredCourses: ['Journalism', 'Media Ethics', 'Writing', 'Research Methods', 'Broadcasting'],
        ),
        JobRole(
          id: '41',
          title: 'Interior Designer',
          description: 'Makes indoor spaces functional, safe, and beautiful through layout and decor.',
          category: 'Design',
          salaryMinK: 45,
          salaryMaxK: 85,
          requiredSkills: ['Space Planning', 'Lighting Design', 'Revit', 'Material Science', 'Color Theory', 'Client Communication', 'Budgeting', 'Building Codes'],
          requiredCourses: ['Interior Design', 'Space Planning', 'CAD/Revit', 'Materials & Finishes', 'Building Codes'],
        ),
        JobRole(
          id: '42',
          title: 'Voice Actor',
          description: 'Provides voices for animations, commercials, and audiobooks.',
          category: 'Entertainment',
          salaryMinK: 35,
          salaryMaxK: 90,
          requiredSkills: ['Voice Modulation', 'Script Reading', 'Audio Recording', 'Dialects', 'Character Acting', 'Breath Control', 'Interpretation', 'Studio Etiquette'],
          requiredCourses: ['Voice Acting', 'Acting', 'Speech', 'Audio Production', 'Script Analysis'],
        ),
        // Nature & Environment
        JobRole(
          id: '43',
          title: 'Marine Biologist',
          description: 'Studies ocean organisms and their interactions with the environment.',
          category: 'Environment',
          salaryMinK: 50,
          salaryMaxK: 90,
          requiredSkills: ['Marine Ecology', 'Scuba Diving', 'Data Analysis', 'Lab Research', 'Field Work', 'Scientific Writing', 'Conservation', 'Statistics'],
          requiredCourses: ['Marine Biology', 'Ecology', 'Oceanography', 'Statistics', 'Research Methods'],
        ),
        JobRole(
          id: '44',
          title: 'Urban Planner',
          description: 'Develops plans and programs for the use of land in cities.',
          category: 'Construction',
          salaryMinK: 55,
          salaryMaxK: 95,
          requiredSkills: ['GIS Mapping', 'Public Policy', 'Sustainability', 'Zoning Laws', 'Community Engagement', 'Data Analysis', 'Presentation', 'Project Management'],
          requiredCourses: ['Urban Planning', 'GIS', 'Public Policy', 'Land Use', 'Sustainability'],
        ),
        // Psychology & Social
        JobRole(
          id: '45',
          title: 'Mental Health Counselor',
          description: 'Helps people manage and overcome mental and emotional disorders.',
          category: 'Healthcare',
          salaryMinK: 45,
          salaryMaxK: 75,
          requiredSkills: ['Empathy', 'Crisis Intervention', 'Psychology', 'Case Management', 'Active Listening', 'Ethics', 'Documentation', 'Cultural Sensitivity'],
          requiredCourses: ['Psychology', 'Counseling', 'Clinical Practice', 'Ethics', 'Crisis Intervention'],
        ),
        JobRole(
          id: '46',
          title: 'Social Media Influencer Manager',
          description: 'Manages partnerships between brands and social media creators.',
          category: 'Marketing',
          salaryMinK: 45,
          salaryMaxK: 85,
          requiredSkills: ['Influencer Marketing', 'Contract Management', 'Trend Analysis', 'Campaign Planning', 'Communication', 'Analytics', 'Negotiation', 'Brand Awareness'],
          requiredCourses: ['Digital Marketing', 'Social Media', 'Influencer Marketing', 'Analytics', 'Brand Management'],
        ),
        // Industry & Logistics
        JobRole(
          id: '47',
          title: 'Quality Control Inspector',
          description: 'Ensures products meet quality standards before they reach customers.',
          category: 'Manufacturing',
          salaryMinK: 40,
          salaryMaxK: 65,
          requiredSkills: ['Inspection Techniques', 'Precision Measuring', 'ISO Standards', 'Documentation', 'Attention to Detail', 'Statistical Process Control', 'Communication', 'Problem Solving'],
          requiredCourses: ['Quality Assurance', 'ISO Standards', 'Measurement Systems', 'Manufacturing', 'Statistics'],
        ),
        JobRole(
          id: '48',
          title: 'Warehouse Manager',
          description: 'Oversees daily operations of a warehouse, including shipping and receiving.',
          category: 'Logistics',
          salaryMinK: 50,
          salaryMaxK: 85,
          requiredSkills: ['Logistics', 'Team Leadership', 'Safety Compliance', 'Inventory Software', 'Shipping & Receiving', 'Space Optimization', 'Vendor Coordination', 'Reporting'],
          requiredCourses: ['Warehouse Management', 'Logistics', 'Inventory Management', 'Safety', 'Supply Chain'],
        ),
      ];

  static List<JobRole> get _defaultJobs => [
        JobRole(
          id: '1',
          title: 'Data Analyst',
          description: 'Analyze data to help organizations make better decisions',
          category: 'Data & Analytics',
          salaryMinK: 65,
          salaryMaxK: 95,
          requiredSkills: ['SQL', 'Excel', 'Python', 'Tableau', 'Statistics', 'Data Visualization', 'Problem Solving', 'Communication'],
          requiredCourses: ['Statistics', 'Data Structures', 'Database Systems', 'Data Visualization'],
          technicalSkillsWithLevel: const [
            SkillProficiency(name: 'Data Analysis', percent: 85),
            SkillProficiency(name: 'Programming', percent: 65),
            SkillProficiency(name: 'Database Management', percent: 75),
            SkillProficiency(name: 'Business Analysis', percent: 70),
          ],
          softSkillsWithLevel: const [
            SkillProficiency(name: 'Problem Solving', percent: 80),
            SkillProficiency(name: 'Communication', percent: 75),
            SkillProficiency(name: 'Critical Thinking', percent: 85),
            SkillProficiency(name: 'Attention to Detail', percent: 80),
          ],
          criticalSkills: const ['Data Analysis', 'Problem Solving', 'Critical Thinking', 'Attention to Detail'],
        ),
        JobRole(
          id: '2',
          title: 'Data Scientist',
          description: 'Use advanced analytics and machine learning to extract insights',
          category: 'Data & Analytics',
          salaryMinK: 95,
          salaryMaxK: 140,
          requiredSkills: ['Python', 'R', 'Machine Learning', 'SQL', 'Statistics', 'Deep Learning', 'Data Wrangling', 'A/B Testing', 'Communication', 'Storytelling'],
          requiredCourses: ['Machine Learning', 'Statistics', 'Linear Algebra', 'Database Systems', 'Data Mining', 'Python Programming'],
        ),
        JobRole(
          id: '3',
          title: 'Business Intelligence Analyst',
          description: 'Transform data into actionable business insights',
          category: 'Data & Analytics',
          salaryMinK: 70,
          salaryMaxK: 100,
          requiredSkills: ['SQL', 'Power BI', 'Tableau', 'Excel', 'Data Modeling', 'ETL', 'Dashboard Design', 'Communication'],
          requiredCourses: ['Database Systems', 'Business Analytics', 'Data Visualization', 'Statistics'],
        ),
        JobRole(
          id: '4',
          title: 'Marketing Analyst',
          description: 'Analyze marketing data and consumer behavior',
          category: 'Marketing',
          salaryMinK: 55,
          salaryMaxK: 85,
          requiredSkills: ['Excel', 'Google Analytics', 'SQL', 'Data Visualization', 'A/B Testing', 'SEO', 'Communication', 'Reporting'],
          requiredCourses: ['Marketing Fundamentals', 'Statistics', 'Data Analysis', 'Digital Marketing'],
        ),
        JobRole(
          id: '5',
          title: 'Software Engineer',
          description: 'Design, develop and maintain software applications',
          category: 'Engineering',
          salaryMinK: 80,
          salaryMaxK: 130,
          requiredSkills: ['Programming', 'Data Structures', 'Algorithms', 'Version Control', 'Testing', 'System Design', 'Problem Solving', 'Collaboration'],
          requiredCourses: ['Data Structures', 'Algorithms', 'Database Systems', 'Software Engineering', 'Web or Mobile Development'],
        ),
        JobRole(
          id: '6',
          title: 'Product Manager',
          description: 'Define product strategy and work with engineering to deliver value',
          category: 'Product',
          salaryMinK: 90,
          salaryMaxK: 140,
          requiredSkills: ['Product Strategy', 'User Research', 'Agile', 'Stakeholder Management', 'Analytics', 'Communication', 'Prioritization', 'Roadmapping'],
          requiredCourses: ['Product Management', 'Business Fundamentals', 'User Experience', 'Data for Product'],
        ),
        JobRole(
          id: '7',
          title: 'UX Designer',
          description: 'Create user-centered designs for digital products',
          category: 'Design',
          salaryMinK: 70,
          salaryMaxK: 110,
          requiredSkills: ['Wireframing', 'Prototyping', 'User Research', 'UI Design', 'Figma', 'Usability Testing', 'Communication', 'Collaboration'],
          requiredCourses: ['User Experience Design', 'Visual Design', 'Human-Computer Interaction', 'Design Systems'],
        ),
        JobRole(
          id: '8',
          title: 'DevOps Engineer',
          description: 'Automate and optimize development and deployment pipelines',
          category: 'Engineering',
          salaryMinK: 85,
          salaryMaxK: 135,
          requiredSkills: ['Linux', 'CI/CD', 'Docker', 'Kubernetes', 'Cloud (AWS/GCP)', 'Scripting', 'Monitoring', 'Security'],
          requiredCourses: ['Operating Systems', 'Networking', 'Cloud Computing', 'Scripting', 'Containers'],
        ),
      ];

  /// إضافة أو تحديث بيانات المستخدم
  Future<void> addUser({
    required String name,
    required int age,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception("No user logged in");
    }

    await _db.collection('users').doc(user.uid).set({
      'name': name,
      'age': age,
      'createdAt': Timestamp.now(),
    });
  }

  /// جلب بيانات المستخدم
  Future<Map<String, dynamic>?> getUserData() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return null;

    final doc = await _db.collection('users').doc(user.uid).get();

    return doc.exists ? doc.data() : null;
  }

  /// تحديث بيانات المستخدم
  Future<void> updateUserData(Map<String, dynamic> data) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception("No user logged in");
    }

    await _db.collection('users').doc(user.uid).update(data);
  }

  // --- Home: Insights & Market Trends (real-time streams) ---

  /// Real-time stream of insights (skill progress bars). Order by [order] field.
  Stream<List<InsightModel>> streamInsights() {
    return _db
        .collection('insights')
        .orderBy('order')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => InsightModel.fromFirestore(doc.id, doc.data()))
            .toList());
  }

  /// Real-time stream of market trends (growth cards). Order by [order] field.
  Stream<List<TrendModel>> streamMarketTrends() {
    return _db
        .collection('market_trends')
        .orderBy('order')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TrendModel.fromFirestore(doc.id, doc.data()))
            .toList());
  }

  /// One-time fetch of home data (insights + market trends). Use streams for live updates.
  Future<({List<InsightModel> insights, List<TrendModel> trends})> fetchHomeData() async {
    final insightsSnap = await _db.collection('insights').orderBy('order').get();
    final trendsSnap = await _db.collection('market_trends').orderBy('order').get();
    return (
      insights: insightsSnap.docs
          .map((doc) => InsightModel.fromFirestore(doc.id, doc.data()))
          .toList(),
      trends: trendsSnap.docs
          .map((doc) => TrendModel.fromFirestore(doc.id, doc.data()))
          .toList(),
    );
  }

  /// Temporary: upload initial data for Latest Insights and Job Market Trends.
  /// Field names match [InsightModel.fromFirestore]: skill_name, percentage (+ order for sort).
  /// Field names match [TrendModel.fromFirestore]: title, growth_percentage, icon_name, subtitle (+ order for sort).
  /// Call once (e.g. from main.dart or a debug button) to fill Firestore, then remove or comment out.
  Future<void> uploadHomeMockData() async {
    final batch = _db.batch();

    // insights: fields used by InsightModel.fromFirestore — skill_name, percentage
    final insights = [
      {'skill_name': 'Python', 'percentage': 95, 'order': 0},
      {'skill_name': 'Data Analysis', 'percentage': 88, 'order': 1},
      {'skill_name': 'Cloud Computing', 'percentage': 82, 'order': 2},
      {'skill_name': 'Machine Learning', 'percentage': 78, 'order': 3},
    ];
    for (var i = 0; i < insights.length; i++) {
      final ref = _db.collection('insights').doc('insight_${i + 1}');
      batch.set(ref, insights[i]);
    }

    // market_trends: fields used by TrendModel.fromFirestore — title, growth_percentage, icon_name, subtitle
    final trends = [
      {
        'title': 'AI/ML Jobs',
        'growth_percentage': 45,
        'icon_name': 'trending_up',
        'order': 0,
      },
      {
        'title': 'Cybersecurity',
        'growth_percentage': 0,
        'icon_name': 'security',
        'subtitle': 'High demand, 350K+ openings',
        'order': 1,
      },
      {
        'title': 'Remote Work',
        'growth_percentage': 65,
        'icon_name': 'home_work',
        'subtitle': '65% of tech jobs now remote-friendly',
        'order': 2,
      },
    ];
    for (var i = 0; i < trends.length; i++) {
      final ref = _db.collection('market_trends').doc('trend_${i + 1}');
      batch.set(ref, trends[i]);
    }

    await batch.commit();
  }
}