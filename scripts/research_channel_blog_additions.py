from __future__ import annotations

import json
import re
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from urllib.parse import quote, urlparse

import requests
from bs4 import BeautifulSoup

ROOT = Path(__file__).resolve().parents[1]
RESOURCE_DIR = ROOT / "assets" / "data" / "resources"
CATEGORY_FILE = ROOT / "assets" / "data" / "resource_categories.json"
OUT = ROOT / "docs" / "research" / "channel_blog_additions.json"
TODAY = "2026-08-23"

PALETTE = ["0xFF2563EB", "0xFF16A34A", "0xFFF0AA1D", "0xFF7C3AED", "0xFF0891B2", "0xFFDB4437", "0xFF0F766E", "0xFF9333EA", "0xFFB45309", "0xFF475569"]

CHANNEL_POOLS = {
    "general": [
        ("OpenLearn_OU", "OpenLearn from The Open University", "University-led free learning across philosophy, economics, history, science, language, and everyday skills."),
        ("MITOpenCourseWare", "MIT OpenCourseWare", "Free lecture materials and courses from MIT across science, engineering, technology, and the humanities."),
        ("YaleCourses", "YaleCourses", "Complete open university lectures across humanities, social science, medicine, science, law, and professional life."),
        ("StanfordOnline", "Stanford Online", "Open lectures and learning from Stanford across technology, business, health, and professional development."),
        ("khanacademy", "Khan Academy", "Foundational and advanced learning in mathematics, science, economics, computing, and test preparation."),
        ("CrashCourse", "CrashCourse", "Structured introductory courses in history, science, psychology, economics, media, and the humanities."),
        ("TED-Ed", "TED-Ed", "Short lessons and explainers that build curiosity, critical thinking, and broad subject knowledge."),
        ("Veritasium", "Veritasium", "Evidence-based science and engineering explanations with experiments and expert interviews."),
        ("SmarterEveryDay", "SmarterEveryDay", "Practical science, engineering, technology, and problem-solving investigations."),
        ("TheSchoolOfLife", "The School of Life", "Psychology, emotional intelligence, relationships, philosophy, and self-awareness."),
        ("SciShow", "SciShow", "Accessible science education spanning biology, chemistry, physics, medicine, and Earth science."),
        ("numberphile", "Numberphile", "Mathematics, numbers, proofs, history, and mathematical problem-solving."),
        ("3blue1brown", "3Blue1Brown", "Visual explanations of mathematics, calculus, linear algebra, probability, and abstract ideas."),
        ("Kurzgesagt", "Kurzgesagt – In a Nutshell", "Research-based explanations of science, society, technology, and long-term human questions."),
        ("BigThink", "Big Think", "Ideas and conversations about psychology, philosophy, science, leadership, and society."),
        ("PBSIdeaChannel", "PBS Idea Channel", "Media literacy, culture, technology, philosophy, and critical analysis."),
        ("HarvardOnline", "Harvard Online", "University learning and professional education across leadership, health, data, and society."),
        ("GoogleTalks", "Talks at Google", "Author, researcher, practitioner, and expert conversations across many disciplines."),
        ("NationalGeographic", "National Geographic", "Science, geography, nature, culture, conservation, and documentary storytelling."),
        ("BBCIdeas", "BBC Ideas", "Short explainers on society, philosophy, science, history, culture, and everyday decision-making."),
    ],
    "crafts": [
        ("thisoldhouse", "This Old House", "Practical building, renovation, electrical, plumbing, carpentry, and home-maintenance education."),
        ("EssentialCraftsman", "Essential Craftsman", "Foundational craftsmanship, construction, metalwork, tools, and practical problem-solving."),
        ("HomeRenoVisionDIY", "Home RenoVision DIY", "Hands-on renovation, drywall, flooring, tiling, plumbing, and project planning."),
        ("TheHonestCarpenter", "The Honest Carpenter", "Carpentry knowledge, building science, tool use, and construction quality."),
        ("PerkinsBuilderBrothers", "Perkins Builder Brothers", "Residential construction, framing, tools, building systems, and project execution."),
        ("ElectricianU", "Electrician U", "Electrical installation, wiring, code concepts, tools, and electrician career learning."),
        ("Got2Learn", "Got2Learn", "Hands-on electrical, HVAC, refrigeration, and trade troubleshooting tutorials."),
        ("SeeJaneDrill", "See Jane Drill", "Accessible DIY maintenance, repairs, tools, and home-improvement skills."),
        ("RogerWakefield", "Roger Wakefield", "Plumbing fundamentals, diagnosis, installation, maintenance, and trade practice."),
        ("ACServiceTech", "AC Service Tech", "Air-conditioning, refrigeration, electrical diagnostics, and HVAC service training."),
        ("WordofAdviceTV", "Word of Advice TV", "Home repair, plumbing, heating, electrical, and practical maintenance guidance."),
        ("GreatScott!", "GreatScott!", "Electronics, circuits, batteries, embedded projects, and engineering experimentation."),
        ("ElectroBOOM", "ElectroBOOM", "Electrical engineering concepts, safety lessons, circuits, and demonstrations."),
        ("ChrisFix", "ChrisFix", "Automotive maintenance, diagnostics, repair procedures, tools, and workshop skills."),
        ("TheCarCareNut", "The Car Care Nut", "Vehicle systems, diagnostics, maintenance, repair quality, and automotive ownership."),
        ("ProfessorPincushion", "Professor Pincushion", "Sewing, tailoring, garment construction, patterns, and textile skills."),
        ("withwendy", "withwendy", "Garment sewing, pattern adaptation, design process, and clothing construction."),
    ],
    "beauty": [
        ("FreeSalonEducation", "Free Salon Education", "Professional hairdressing education, cutting, coloring, styling, and salon technique."),
        ("SamVillaHair", "Sam Villa", "Haircutting, styling, tools, salon education, and professional technique."),
        ("MattBeck", "Matt Beck", "Barbering, haircutting, clipper work, fades, and practical shop skills."),
        ("BradMondo", "Brad Mondo", "Hair color, haircut analysis, salon technique, and hair-care education."),
        ("MakeupbyMARIO", "Makeup by Mario", "Professional makeup artistry, complexion, technique, and product application."),
        ("LisaEldridge", "Lisa Eldridge", "Professional makeup technique, beauty history, artistry, and practical tutorials."),
        ("JackieAina", "Jackie Aina", "Makeup technique, product education, representation, and beauty industry knowledge."),
        ("TheMakeupChair", "The Makeup Chair", "Makeup fundamentals, application, face structure, and technique."),
        ("NikkieTutorials", "NikkieTutorials", "Makeup artistry, product technique, creative looks, and beauty communication."),
        ("HairliciousInc", "Hairlicious Inc", "Hair care, scalp health, styling routines, and evidence-aware hair education."),
        ("ManesByMell", "Manes by Mell", "Curly hair science, technique, routines, and hair-care education."),
        ("TheSalonGuy", "TheSalonGuy", "Men’s hairstyling, cutting, grooming, and salon technique."),
    ],
    "creative": [
        ("thefuturishere", "The Futur", "Design, branding, creative business, critique, client work, and professional practice."),
        ("PHLEARN", "PHLEARN", "Photography, retouching, compositing, lighting, and image-making technique."),
        ("PeterMcKinnon", "Peter McKinnon", "Photography, filmmaking, lighting, editing, visual storytelling, and creator craft."),
        ("FilmRiot", "Film Riot", "Filmmaking, directing, cinematography, production, and visual storytelling."),
        ("cinecom.net", "Cinecom.net", "Video production, editing, visual effects, filmmaking, and post-production."),
        ("DSLRVideoShooter", "DSLR Video Shooter", "Camera systems, lighting, audio, production workflows, and video technique."),
        ("AdobeCreativeCloud", "Adobe Creative Cloud", "Official tutorials for graphic design, photography, video, illustration, and creative tools."),
        ("fstoppers", "Fstoppers", "Photography, lighting, visual storytelling, business, and professional image-making."),
        ("SLRLounge", "SLR Lounge", "Photography education, posing, lighting, workflow, and professional practice."),
        ("PiXimperfect", "PiXimperfect", "Photoshop, compositing, retouching, design, and digital image technique."),
        ("BlenderGuru", "Blender Guru", "3D modeling, materials, lighting, rendering, and computer graphics."),
        ("Schoolism", "Schoolism", "Drawing, painting, concept art, animation, and professional visual development."),
        ("AaronBlaiseArt", "Aaron Blaise", "Animation, drawing, character design, illustration, and visual storytelling."),
        ("BHPhotoVideo", "B&H Photo Video", "Photography, video, audio, equipment, workflow, and production education."),
        ("CreativeLive", "CreativeLive", "Photography, design, craft, entrepreneurship, and creative career development."),
    ],
    "business": [
        ("ycombinator", "Y Combinator", "Startup formation, product development, fundraising, hiring, and founder learning."),
        ("stanfordecorner", "Stanford eCorner", "Entrepreneurship, innovation, leadership, and venture-building lectures."),
        ("HarvardBusinessReview", "Harvard Business Review", "Management, strategy, leadership, organizational behavior, and decision-making."),
        ("GoogleforStartups", "Google for Startups", "Startup growth, technology, product, marketing, and founder education."),
        ("HubSpotMarketing", "HubSpot Marketing", "Marketing, sales, CRM, content, customer experience, and business growth."),
        ("AhrefsCom", "Ahrefs", "SEO, content strategy, digital marketing, analytics, and audience growth."),
        ("NeilPatel", "Neil Patel", "Digital marketing, SEO, content, customer acquisition, and online business."),
        ("MoneyMacro", "Money & Macro", "Economics, monetary policy, finance, markets, and macroeconomic reasoning."),
        ("BenFelixCSI", "Ben Felix", "Evidence-based investing, personal finance, portfolio construction, and financial literacy."),
        ("ThePlainBagel", "The Plain Bagel", "Investing, economics, personal finance, risk, and financial decision-making."),
        ("AswathDamodaranonValuation", "Aswath Damodaran", "Valuation, corporate finance, investing, accounting, and financial modeling."),
        ("CFAInstitute", "CFA Institute", "Investment analysis, ethics, portfolio management, and professional finance."),
        ("GaryVee", "GaryVee", "Entrepreneurship, marketing, communication, leadership, and creator business."),
        ("ThinkMediaTV", "Think Media", "Content strategy, video marketing, audience growth, and creator systems."),
        ("patflynn", "Pat Flynn", "Online business, digital products, entrepreneurship, and ethical audience building."),
    ],
    "medicine": [
        ("NinjaNerdScience", "Ninja Nerd", "Medical education across anatomy, physiology, pathology, pharmacology, and clinical science."),
        ("Osmosis", "Osmosis", "Medicine, nursing, health sciences, disease mechanisms, and clinical learning."),
        ("MedCram", "MedCram", "Medical explanations, physiology, infectious disease, and clinical concepts."),
        ("ArmandoHasudungan", "Armando Hasudungan", "Illustrated anatomy, physiology, pathology, and medical education."),
        ("StrongMedicine", "Strong Medicine", "Clinical reasoning, internal medicine, patient care, and medical education."),
        ("ZeroToFinals", "Zero To Finals", "Medical revision, clinical medicine, pathology, pharmacology, and exam preparation."),
        ("DoctorNajeeb", "Dr Najeeb Lectures", "Detailed anatomy, physiology, pathology, pharmacology, and medical science lectures."),
        ("JohnsHopkinsSPH", "Johns Hopkins Bloomberg School of Public Health", "Public health, epidemiology, policy, global health, and prevention."),
        ("WHO", "World Health Organization", "Global health, public health, disease prevention, policy, and health systems."),
        ("StanfordMedicine", "Stanford Medicine", "Clinical research, medical innovation, patient care, and health sciences."),
        ("YaleMedicine", "Yale Medicine", "Medical knowledge, clinical research, patient education, and health practice."),
        ("KhanAcademyMedicine", "Khan Academy Medicine", "Foundational anatomy, physiology, biology, and health-science learning."),
        ("DrBeenMedicalLectures", "DrBeen Medical Lectures", "Clinical medicine, pharmacology, and evidence-based medical education."),
        ("InstituteOfHumanAnatomy", "Institute of Human Anatomy", "Human anatomy, dissection, and applied anatomical education."),
        ("MedicosisPerfectionalis", "Medicosis Perfectionalis", "Medical science, pathology, pharmacology, and clinical review."),
    ],
    "law": [
        ("LegalEagle", "LegalEagle", "Legal reasoning, courtroom practice, media law, and public legal education."),
        ("LawShelf", "LawShelf", "Accessible legal concepts, contracts, business law, and legal foundations."),
        ("CornellLawSchool", "Cornell Law School", "Legal education, public law, policy, and academic legal scholarship."),
        ("HarvardLawSchool", "Harvard Law School", "Legal scholarship, public lectures, policy, and professional legal education."),
        ("YaleLawSchool", "Yale Law School", "Law, legal theory, public policy, rights, and academic legal discussion."),
        ("GeorgetownLaw", "Georgetown Law", "Law, policy, regulation, technology, and professional legal education."),
        ("StanfordLawSchool", "Stanford Law School", "Law, technology, entrepreneurship, policy, and legal scholarship."),
        ("Justia", "Justia", "Legal information, case law, legal practice, and public legal education."),
        ("ABANational", "American Bar Association", "Professional legal practice, ethics, access to justice, and legal policy."),
        ("LawCrimeNetwork", "Law&Crime Network", "Criminal justice, trials, legal analysis, and court reporting."),
        ("UNODC", "United Nations Office on Drugs and Crime", "Criminal justice, law enforcement, corruption, and international law."),
        ("TheUniversityOfLaw", "The University of Law", "Legal study, professional qualification, employability, and legal practice."),
    ],
    "engineering": [
        ("PracticalEngineeringChannel", "Practical Engineering", "Civil infrastructure, engineering systems, hazards, and real-world design."),
        ("RealEngineering", "Real Engineering", "Engineering history, technology, aerospace, energy, and systems analysis."),
        ("EngineeringExplained", "Engineering Explained", "Automotive engineering, mechanics, energy, and technical analysis."),
        ("AppliedScience", "Applied Science", "Materials, chemistry, electronics, laboratory work, and experimental engineering."),
        ("NPTEL", "NPTEL", "University engineering, science, mathematics, computing, and professional courses."),
        ("LearnEngineering", "Learn Engineering", "Mechanical, civil, electrical, and industrial engineering explainers."),
        ("TheEfficientEngineer", "The Efficient Engineer", "Mechanical engineering fundamentals, design, mechanics, and materials."),
        ("GreatScott!", "GreatScott!", "Electronics, circuits, batteries, embedded systems, and hands-on engineering."),
        ("ElectroBOOM", "ElectroBOOM", "Electrical engineering, circuits, safety, and measurement."),
        ("branch_education", "Branch Education", "Engineering, machines, electronics, and how complex systems work."),
        ("MITOpenCourseWare", "MIT OpenCourseWare", "Free engineering, physics, mathematics, computing, and technology courses."),
        ("StanfordOnline", "Stanford Online", "Engineering, technology, innovation, and professional learning from Stanford."),
    ],
    "agriculture": [
        ("FAO", "FAO of the United Nations", "Food systems, agriculture, fisheries, forestry, nutrition, and rural development."),
        ("CornellSmallFarms", "Cornell Small Farms Program", "Small farm management, production, markets, soil, and sustainable agriculture."),
        ("TexasAMAgriLife", "Texas A&M AgriLife", "Agriculture, livestock, horticulture, food systems, and extension education."),
        ("UGAExtension", "UGA Cooperative Extension", "Agriculture, poultry, horticulture, family, and community education."),
        ("PennStateExtension", "Penn State Extension", "Farm management, crops, livestock, food, and agricultural practice."),
        ("UCANR", "UC Agriculture and Natural Resources", "Agriculture, water, pests, food systems, and natural resources."),
        ("OhioStateExtension", "OSU Extension", "Agronomy, livestock, horticulture, farm business, and rural development."),
        ("PoultryScience", "Poultry Science Association", "Poultry science, research, production, health, and industry education."),
        ("AquacultureHub", "Aquaculture Hub", "Aquaculture systems, fish production, water quality, and farm management."),
        ("OklahomaStateUniversity", "Oklahoma State University Agriculture", "Crop, livestock, agricultural engineering, and extension knowledge."),
        ("UniversityofGuelph", "University of Guelph", "Food, agriculture, veterinary medicine, environment, and life sciences."),
        ("IowaStateExtension", "Iowa State University Extension", "Crops, livestock, farm economics, and applied agricultural research."),
    ],
    "education": [
        ("Edutopia", "Edutopia", "Evidence-informed teaching, learning design, classroom practice, and education leadership."),
        ("cultofpedagogy", "Cult of Pedagogy", "Teaching methods, classroom management, assessment, and teacher development."),
        ("TeachingChannel", "Teaching Channel", "Teacher practice, instructional strategies, curriculum, and professional learning."),
        ("OpenLearn_OU", "OpenLearn from The Open University", "Free learning across education, society, science, and lifelong learning."),
        ("YaleCourses", "YaleCourses", "University lectures across humanities, science, medicine, law, and professional fields."),
        ("MITOpenCourseWare", "MIT OpenCourseWare", "Free courses, lectures, and teaching materials from MIT."),
        ("CrashCourse", "CrashCourse", "Structured introductory lessons across history, science, psychology, economics, and media."),
        ("khanacademy", "Khan Academy", "Foundational and advanced learning with practice across core subjects."),
        ("ASCD", "ASCD", "Curriculum, instruction, school leadership, and education improvement."),
        ("HarvardEducation", "Harvard Graduate School of Education", "Research, education policy, teaching, learning, and human development."),
        ("EducationWeek", "Education Week", "Education policy, practice, leadership, and teaching profession coverage."),
        ("TheLearningNetwork", "The New York Times Learning Network", "Classroom activities, media literacy, writing, and critical thinking."),
    ],
    "psychology": [
        ("CrashCourse", "CrashCourse", "Structured psychology, neuroscience, sociology, and behavioral science foundations."),
        ("HealthyGamerGG", "Healthy Gamer", "Mental health, motivation, attention, habits, and behavior conversations."),
        ("TheSchoolOfLife", "The School of Life", "Psychology, emotional intelligence, relationships, and self-awareness."),
        ("Psych2Go", "Psych2Go", "Accessible psychology, mental health literacy, relationships, and behavior."),
        ("DrTraceyMarks", "Dr. Tracey Marks", "Psychiatry, mental health, diagnosis, treatment concepts, and self-understanding."),
        ("TherapyinaNutshell", "Therapy in a Nutshell", "Evidence-informed mental health skills, emotional regulation, and coping."),
        ("APA", "American Psychological Association", "Psychology research, professional practice, public education, and ethics."),
        ("YaleCourses", "YaleCourses", "Psychology, neuroscience, philosophy, social science, and clinical-adjacent learning."),
        ("SciShowPsych", "SciShow Psych", "Psychology, neuroscience, cognition, mental health, and research explainers."),
        ("StanfordOnline", "Stanford Online", "Psychology, learning, decision-making, leadership, and human behavior."),
        ("BrainCraft", "BrainCraft", "Neuroscience, psychology, cognition, and behavior education."),
        ("TheBehaviorPanel", "The Behavior Panel", "Behavior observation, communication, interviewing, and critical interpretation."),
    ],
    "online": [
        ("freecodecamp", "freeCodeCamp.org", "Free programming, web development, data, algorithms, and career learning."),
        ("TraversyMedia", "Traversy Media", "Web development, programming, APIs, tools, and project-based learning."),
        ("NetNinja", "The Net Ninja", "Web development, JavaScript, frameworks, databases, and coding projects."),
        ("Fireship", "Fireship", "Fast technical explainers on web development, cloud, AI, and software tools."),
        ("CoreySchafer", "Corey Schafer", "Python, programming fundamentals, automation, and developer workflows."),
        ("ProgrammingwithMosh", "Programming with Mosh", "Programming, software engineering, web development, and career skills."),
        ("GoogleDevelopers", "Google for Developers", "Developer tools, cloud, Android, web, AI, and technical documentation."),
        ("Canva", "Canva", "Design, visual communication, social media content, and creator workflows."),
        ("AhrefsCom", "Ahrefs", "SEO, content marketing, keyword research, and digital growth systems."),
        ("HubSpotMarketing", "HubSpot Marketing", "Marketing, CRM, sales, content, customer experience, and growth."),
        ("CreatorWizard", "Creator Wizard", "Creator strategy, audience building, content systems, and digital products."),
        ("ThinkMediaTV", "Think Media", "YouTube strategy, video systems, content marketing, and audience growth."),
        ("patflynn", "Pat Flynn", "Online business, digital products, ethical marketing, and creator entrepreneurship."),
        ("Semrush", "Semrush", "SEO, digital marketing, analytics, content, and online business education."),
        ("Moz", "Moz", "SEO, search strategy, content, local marketing, and web visibility."),
    ],
}

BLOG_POOLS = {
    "general": [
        ("OpenLearn", "https://www.open.edu/openlearn/", "Free university learning and lifelong education."),
        ("MIT OpenCourseWare", "https://ocw.mit.edu/blog/", "Open courses, teaching, science, engineering, and lifelong learning."),
        ("Yale Insights", "https://insights.som.yale.edu/", "Research and ideas on leadership, society, economics, and organizations."),
        ("Stanford eCorner", "https://ecorner.stanford.edu/", "Entrepreneurship, innovation, and leadership research and practice."),
        ("The Conversation", "https://theconversation.com/", "Academic experts explain current issues across science, society, and culture."),
        ("Greater Good Magazine", "https://greatergood.berkeley.edu/", "Psychology, wellbeing, relationships, compassion, and human flourishing."),
        ("Farnam Street", "https://fs.blog/", "Mental models, decision-making, learning, and clear thinking."),
        ("Ness Labs", "https://nesslabs.com/", "Learning, productivity, creativity, neuroscience, and mindful work."),
        ("MindTools", "https://www.mindtools.com/", "Leadership, communication, management, teamwork, and career skills."),
        ("The Decision Lab", "https://thedecisionlab.com/", "Behavioral science, decision-making, psychology, and public policy."),
        ("Edutopia", "https://www.edutopia.org/", "Teaching, learning design, classroom practice, and education innovation."),
        ("Harvard Health Blog", "https://www.health.harvard.edu/blog", "Health, wellbeing, prevention, and medical explainers."),
        ("Our World in Data", "https://ourworldindata.org/blog", "Evidence-based data, global development, health, and society."),
        ("Smithsonian Magazine", "https://www.smithsonianmag.com/", "History, science, culture, art, and public scholarship."),
        ("MIT Technology Review", "https://www.technologyreview.com/", "Technology, science, innovation, and social implications."),
        ("Mozilla Blog", "https://blog.mozilla.org/", "Internet health, privacy, technology, and digital society."),
        ("Google AI Blog", "https://blog.google/technology/ai/", "Artificial intelligence research, tools, and applications."),
        ("Datawrapper Blog", "https://blog.datawrapper.de/", "Data visualization, communication, charts, and evidence presentation."),
        ("NASA Science", "https://science.nasa.gov/solar-system/", "Space science, Earth science, missions, and scientific discovery."),
        ("BBC Future", "https://www.bbc.com/future", "Science, health, technology, behavior, and the future."),
    ],
    "crafts": [
        ("This Old House", "https://www.thisoldhouse.com/", "Construction, repair, renovation, tools, and home systems."),
        ("Family Handyman", "https://www.familyhandyman.com/", "DIY, woodworking, repair, tools, and practical home skills."),
        ("Fine Woodworking", "https://www.finewoodworking.com/", "Advanced woodworking, furniture making, tools, and craftsmanship."),
        ("Wood Magazine", "https://www.woodmagazine.com/", "Woodworking projects, techniques, tools, and shop practice."),
        ("Plumbing & Mechanical", "https://www.pmmag.com/", "Plumbing, HVAC, hydronics, codes, and trade practice."),
        ("Electrical Contractor", "https://www.ecmag.com/", "Electrical installation, safety, technology, and the electrical trade."),
        ("Electronics Notes", "https://www.electronics-notes.com/", "Electronics fundamentals, components, circuits, and design."),
        ("Auto Service Professional", "https://www.autoserviceprofessional.com/", "Automotive diagnostics, repair, service, and shop operations."),
        ("Sew News", "https://www.sewnews.com/", "Sewing, garment construction, patterns, and textile skills."),
        ("Threads Magazine", "https://www.threadsmagazine.com/", "Sewing, tailoring, fitting, and garment design."),
        ("Modern Salon", "https://www.modernsalon.com/", "Salon technique, hairdressing, beauty, and professional practice."),
        ("Behindthechair", "https://behindthechair.com/", "Hair education, salon careers, color, and professional technique."),
    ],
    "creative": [
        ("No Film School", "https://nofilmschool.com/", "Filmmaking, cinematography, production, and creative industry practice."),
        ("PetaPixel", "https://petapixel.com/", "Photography, cameras, visual storytelling, and industry news."),
        ("Fstoppers", "https://fstoppers.com/", "Photography, lighting, filmmaking, workflow, and professional practice."),
        ("Creative Bloq", "https://www.creativebloq.com/", "Graphic design, illustration, 3D, digital art, and creative tools."),
        ("Smashing Magazine", "https://www.smashingmagazine.com/", "Web design, UX, front-end development, accessibility, and performance."),
        ("Adobe Blog", "https://blog.adobe.com/", "Creative tools, design, photography, video, and digital creativity."),
        ("Canva Design School", "https://www.canva.com/designschool/", "Design principles, visual communication, and creator education."),
        ("AIGA Eye on Design", "https://eyeondesign.aiga.org/", "Graphic design, visual culture, design history, and critical practice."),
        ("CreativePro Network", "https://creativepro.com/", "Design software, typography, publishing, and production workflows."),
        ("The Futur Blog", "https://thefutur.com/blog", "Design practice, branding, creative business, and professional development."),
    ],
    "food": [
        ("Serious Eats", "https://www.seriouseats.com/", "Cooking technique, food science, recipes, and culinary knowledge."),
        ("King Arthur Baking", "https://www.kingarthurbaking.com/blog", "Baking science, recipes, ingredients, and professional technique."),
        ("The Kitchn", "https://www.thekitchn.com/", "Cooking, kitchen skills, food culture, and meal planning."),
        ("Food52", "https://food52.com/blog", "Recipes, culinary technique, food culture, and kitchen practice."),
        ("ChefSteps", "https://www.chefsteps.com/", "Culinary technique, food science, and professional cooking."),
        ("The Spruce Eats", "https://www.thespruceeats.com/", "Cooking, baking, ingredients, kitchen skills, and recipes."),
        ("Taste of Home", "https://www.tasteofhome.com/", "Cooking, baking, food preparation, and family food culture."),
        ("Baking Bites", "https://www.bakingbites.com/", "Baking technique, ingredients, and practical recipes."),
        ("Modernist Pantry", "https://blog.modernistpantry.com/", "Food science, culinary ingredients, technique, and experimentation."),
        ("Food Business News", "https://www.foodbusinessnews.net/", "Food industry, manufacturing, product development, and regulation."),
    ],
    "agriculture": [
        ("FAO", "https://www.fao.org/news/en/", "Food, agriculture, fisheries, forestry, nutrition, and rural development."),
        ("USDA Blog", "https://www.usda.gov/media/blog", "Agriculture, food systems, rural development, and government research."),
        ("Cornell Small Farms", "https://smallfarms.cornell.edu/", "Small farm production, management, markets, and sustainability."),
        ("Penn State Extension", "https://extension.psu.edu/", "Agriculture, crops, livestock, food, and rural education."),
        ("UC Agriculture and Natural Resources", "https://ucanr.edu/blogs/", "Agriculture, water, pests, food systems, and natural resources."),
        ("AgFunderNews", "https://agfundernews.com/", "Agri-food technology, investment, innovation, and food systems."),
        ("Poultry World", "https://www.poultryworld.net/", "Poultry production, health, technology, and industry practice."),
        ("The Fish Site", "https://thefishsite.com/", "Aquaculture, fish farming, aquatic health, and production."),
        ("Farm Journal", "https://www.agweb.com/", "Farm management, markets, crop production, and agricultural business."),
        ("Aquaculture Alliance", "https://www.aquaculturealliance.org/advocate/", "Aquaculture production, sustainability, science, and markets."),
    ],
    "medicine": [
        ("World Health Organization", "https://www.who.int/news-room", "Global health, public health, disease prevention, and health systems."),
        ("NIH News", "https://newsinhealth.nih.gov/", "Medical research, health science, and evidence-based public information."),
        ("CDC", "https://blogs.cdc.gov/", "Public health, prevention, epidemiology, and health guidance."),
        ("BMJ Blogs", "https://blogs.bmj.com/", "Medical research, clinical practice, policy, and professional perspectives."),
        ("NEJM Journal Watch", "https://www.jwatch.org/", "Clinical evidence, medical research, and practice updates."),
        ("Harvard Health", "https://www.health.harvard.edu/blog", "Health, prevention, wellbeing, and medical explainers."),
        ("Nature Medicine", "https://www.nature.com/nm/", "Biomedical research, medicine, and translational science."),
        ("The Lancet", "https://www.thelancet.com/", "Clinical medicine, global health, research, and policy."),
        ("Johns Hopkins Public Health", "https://publichealth.jhu.edu/", "Public health, epidemiology, policy, and health systems."),
        ("Medscape", "https://www.medscape.com/", "Clinical medicine, medical education, and professional practice."),
    ],
    "law": [
        ("Cornell Legal Information Institute", "https://www.law.cornell.edu/", "Free legal information, statutes, cases, and legal concepts."),
        ("Justia", "https://www.justia.com/", "Case law, legal guides, courts, and public legal education."),
        ("SCOTUSblog", "https://www.scotusblog.com/", "U.S. Supreme Court cases, doctrine, and legal analysis."),
        ("ABA Journal", "https://www.abajournal.com/", "Legal profession, courts, ethics, policy, and practice."),
        ("Lawfare", "https://www.lawfaremedia.org/", "National security law, policy, technology, and governance."),
        ("Harvard Law Review", "https://harvardlawreview.org/", "Legal scholarship, doctrine, and public law analysis."),
        ("Yale Journal on Regulation", "https://www.yalejreg.com/", "Administrative law, regulation, economics, and policy."),
        ("FindLaw", "https://www.findlaw.com/", "Legal information, rights, practice areas, and public education."),
        ("Legal Dive", "https://www.legaldive.com/", "Legal operations, technology, regulation, and professional practice."),
        ("UNODC", "https://www.unodc.org/unodc/en/frontpage/", "International criminal justice, law, corruption, and governance."),
    ],
    "finance": [
        ("CFA Institute Enterprising Investor", "https://blogs.cfainstitute.org/investor/", "Investment analysis, ethics, portfolio management, and markets."),
        ("Investopedia", "https://www.investopedia.com/", "Financial literacy, investing, economics, and markets."),
        ("Accounting Today", "https://www.accountingtoday.com/", "Accounting profession, tax, technology, and practice management."),
        ("Journal of Accountancy", "https://www.journalofaccountancy.com/", "Accounting, audit, tax, ethics, and professional standards."),
        ("AICPA", "https://www.aicpa-cima.com/", "Accounting, assurance, ethics, finance, and professional development."),
        ("IFRS Foundation", "https://www.ifrs.org/news-and-events/", "International financial reporting, standards, and accounting practice."),
        ("Federal Reserve Bank of St. Louis", "https://www.stlouisfed.org/on-the-economy", "Economics, monetary policy, data, and financial systems."),
        ("IMF Blog", "https://www.imf.org/en/Blogs", "Macroeconomics, financial stability, policy, and global development."),
        ("World Bank Blogs", "https://blogs.worldbank.org/", "Development economics, finance, policy, and poverty reduction."),
        ("Corporate Finance Institute", "https://corporatefinanceinstitute.com/resources/", "Financial modeling, valuation, accounting, and corporate finance."),
    ],
    "engineering": [
        ("IEEE Spectrum", "https://spectrum.ieee.org/", "Engineering, computing, technology, research, and innovation."),
        ("ASME", "https://www.asme.org/topics-resources/content", "Mechanical engineering, standards, design, and professional practice."),
        ("Engineering.com", "https://www.engineering.com/", "Engineering design, manufacturing, software, and industry knowledge."),
        ("NIST", "https://www.nist.gov/blogs/taking-measure", "Measurement, standards, engineering, science, and technology."),
        ("NASA", "https://www.nasa.gov/blogs/", "Aerospace, space science, engineering, and missions."),
        ("The Engineer", "https://www.theengineer.co.uk/", "Engineering careers, technology, design, and industry."),
        ("Ars Technica", "https://arstechnica.com/", "Technology, science, computing, and engineering analysis."),
        ("Hackaday", "https://hackaday.com/", "Electronics, embedded systems, fabrication, and open hardware."),
        ("Electronics Weekly", "https://www.electronicsweekly.com/", "Electronics engineering, components, systems, and industry."),
        ("Practical Engineering", "https://practical.engineering/", "Engineering systems, infrastructure, and applied problem-solving."),
    ],
    "education": [
        ("Edutopia", "https://www.edutopia.org/", "Teaching, learning design, classroom practice, and education innovation."),
        ("Education Week", "https://www.edweek.org/", "Education policy, schools, teaching, leadership, and research."),
        ("EdSurge", "https://www.edsurge.com/", "Education technology, learning science, teaching, and institutions."),
        ("Inside Higher Ed", "https://www.insidehighered.com/", "Higher education, teaching, policy, research, and academic work."),
        ("TeachThought", "https://www.teachthought.com/", "Pedagogy, critical thinking, learning design, and classroom practice."),
        ("Cult of Pedagogy", "https://www.cultofpedagogy.com/", "Teaching methods, classroom management, assessment, and teacher growth."),
        ("Faculty Focus", "https://www.facultyfocus.com/", "College teaching, instructional design, assessment, and faculty development."),
        ("EdTech Magazine", "https://edtechmagazine.com/", "Education technology, institutions, IT, and learning environments."),
        ("MindShift", "https://www.kqed.org/mindshift", "Learning, schools, technology, and education change."),
        ("OpenLearn", "https://www.open.edu/openlearn/", "Free higher education and lifelong learning."),
    ],
    "psychology": [
        ("American Psychological Association", "https://www.apa.org/news/", "Psychology research, mental health, practice, and ethics."),
        ("Psychology Today", "https://www.psychologytoday.com/", "Psychology, therapy, relationships, behavior, and wellbeing."),
        ("Greater Good Magazine", "https://greatergood.berkeley.edu/", "Positive psychology, compassion, relationships, and human flourishing."),
        ("PsyPost", "https://www.psypost.org/", "Psychology and neuroscience research reporting."),
        ("BPS Research Digest", "https://digest.bps.org.uk/", "Research summaries from the British Psychological Society."),
        ("Mindful", "https://www.mindful.org/", "Mindfulness, wellbeing, attention, and emotional regulation."),
        ("Scientific American Mind", "https://www.scientificamerican.com/mind/", "Mind, brain, behavior, and psychology research."),
        ("The Decision Lab", "https://thedecisionlab.com/", "Behavioral science, cognition, judgment, and decision-making."),
        ("Behavioral Scientist", "https://behavioralscientist.org/", "Behavioral science, psychology, policy, and application."),
        ("Child Mind Institute", "https://childmind.org/article/", "Child development, mental health, parenting, and clinical education."),
    ],
    "online": [
        ("Moz Blog", "https://moz.com/blog", "SEO, search strategy, content, and digital marketing."),
        ("Ahrefs Blog", "https://ahrefs.com/blog/", "SEO, content strategy, keyword research, and audience growth."),
        ("Search Engine Land", "https://searchengineland.com/", "Search, digital marketing, advertising, and analytics."),
        ("Social Media Examiner", "https://www.socialmediaexaminer.com/", "Social media strategy, content, advertising, and community."),
        ("Buffer Resources", "https://buffer.com/resources", "Social media, content creation, workflow, and creator practice."),
        ("Hootsuite Blog", "https://blog.hootsuite.com/", "Social media management, analytics, content, and marketing."),
        ("Later Blog", "https://later.com/blog/", "Social media, creator marketing, content planning, and analytics."),
        ("Copyblogger", "https://copyblogger.com/", "Writing, content marketing, audience, and digital products."),
        ("ConvertKit Resources", "https://convertkit.com/resources", "Creator business, email, digital products, and audience building."),
        ("Zapier Blog", "https://zapier.com/blog/", "Automation, productivity, apps, workflows, and online operations."),
        ("Shopify Blog", "https://www.shopify.com/blog", "E-commerce, product, marketing, operations, and entrepreneurship."),
        ("Canva Design School", "https://www.canva.com/designschool/", "Design, visual communication, and creator skills."),
    ],
}


def category_pool(category_id: str, name: str) -> str:
    text = f"{category_id} {name}".casefold()
    if any(word in text for word in ("medicine", "nursing", "pharmacy", "dentistry", "psychology", "counselling")):
        return "medicine" if "psychology" not in text and "counselling" not in text else "psychology"
    if "law" in text:
        return "law"
    if any(word in text for word in ("accounting", "banking", "finance")):
        return "finance"
    if "agriculture" in text or "poultry" in text or "fish farming" in text:
        return "agriculture"
    if "education" in text or "tutorial" in text or "tutoring" in text or "online courses" in text:
        return "education"
    if any(word in text for word in ("photography", "videography", "graphic design", "fashion", "tailoring", "makeup", "cosmetology", "hairdressing", "barbing", "beauty", "catering", "baking", "event decoration", "event planning", "shoemaking", "leatherwork")):
        if any(word in text for word in ("catering", "baking")):
            return "food"
        if any(word in text for word in ("hair", "barb", "makeup", "cosmetology", "beauty")):
            return "beauty"
        if any(word in text for word in ("photography", "videography", "graphic", "fashion", "tailor", "shoe", "leather", "event")):
            return "creative"
    if any(word in text for word in ("welding", "carpentry", "plumbing", "electrical", "auto", "automobile", "phone", "electronics", "solar", "renewable", "refrigeration", "tiling", "interior")):
        return "crafts" if "engineering" not in text else "engineering"
    if any(word in text for word in ("engineering", "architecture", "computer science", "software")):
        return "engineering"
    if any(word in text for word in ("affiliate", "freelance", "social media", "virtual assistance", "transcription", "content creation", "ai services", "digital products", "blogging", "seo", "ads management", "dropshipping", "e-commerce", "ecommerce", "web/no-code", "web development", "digital agency", "vtu")):
        return "online"
    if any(word in text for word in ("business", "real estate", "logistics", "salon", "cosmetics", "provision", "bakery", "phone & gadget", "pos", "mini-importation", "cleaning", "water")):
        return "business"
    return "general"


def resolve_channel(item: tuple[str, str, str]) -> dict | None:
    handle, name, description = item
    url = f"https://www.youtube.com/@{quote(handle, safe='@._-')}/about"
    try:
        r = requests.get(url, headers={"User-Agent": "Rumuo-channel-research/1.0"}, timeout=12)
        if r.status_code >= 400:
            return None
        text = r.text
        patterns = [r'"channelId":"(UC[\w-]{22})"', r'"externalId":"(UC[\w-]{22})"', r'channel_id=(UC[\w-]{22})']
        channel_id = next((match.group(1) for pattern in patterns if (match := re.search(pattern, text))), None)
        if not channel_id:
            return None
        return {"id": channel_id, "name": name, "handle": f"@{handle}", "description": description, "sourceUrl": f"https://www.youtube.com/channel/{channel_id}"}
    except requests.RequestException:
        return None


def check_blog(item: tuple[str, str, str]) -> dict | None:
    name, url, focus = item
    try:
        r = requests.get(url, headers={"User-Agent": "Rumuo-blog-research/1.0"}, timeout=12, allow_redirects=True)
        if r.status_code >= 400:
            return None
        content_type = r.headers.get("content-type", "").lower()
        # Accept HTML landing pages as well as XML feeds; BlogRssService will
        # discover an RSS/Atom alternate when the URL is a homepage.
        if "html" not in content_type and "xml" not in content_type and "text" not in content_type:
            return None
        return {"name": name, "url": r.url, "focus": focus}
    except requests.RequestException:
        return None


categories = json.loads(CATEGORY_FILE.read_text(encoding="utf-8"))["categories"]
all_channels = {}
for pool in CHANNEL_POOLS.values():
    for item in pool:
        all_channels[item[0].casefold()] = item
with ThreadPoolExecutor(max_workers=10) as executor:
    resolved = [result for result in (future.result() for future in as_completed({executor.submit(resolve_channel, item): item for item in all_channels.values()})) if result]
resolved_by_key = {item["handle"].lstrip("@").casefold(): item for item in resolved}

all_blogs = {}
for pool in BLOG_POOLS.values():
    for item in pool:
        all_blogs[item[1].rstrip('/').casefold()] = item
with ThreadPoolExecutor(max_workers=10) as executor:
    checked_blogs = [result for result in (future.result() for future in as_completed({executor.submit(check_blog, item): item for item in all_blogs.values()})) if result]

report = {"date": TODAY, "resolvedChannels": len(resolved), "checkedBlogs": len(checked_blogs), "categories": {}, "unresolvedHandles": sorted(set(all_channels) - set(resolved_by_key)), "rejectedBlogs": sorted(set(all_blogs) - set(item["url"].rstrip('/').casefold() for item in checked_blogs)), "files": []}
blog_by_url = {item["url"].rstrip('/').casefold(): item for item in checked_blogs}

def make_channel(item: dict, category_id: str, category_name: str, index: int) -> dict:
    initials = ''.join(part[0] for part in re.sub(r"[^A-Za-z0-9 ]", "", item["name"]).split()[:2]).upper() or "ED"
    return {
        "id": item["id"], "name": item["name"], "handle": item["handle"],
        "description": item["description"], "accentColor": PALETTE[index % len(PALETTE)],
        "initials": initials[:2], "focus": f"{category_name}: {item['description']}",
        "region": "Global", "verifiedOn": TODAY,
        "verificationMethod": f"Direct YouTube handle page resolved to channel ID {item['id']}; selected for the {category_name} learning pathway beyond business-only content.",
    }

for category in categories:
    category_id, category_name = category["id"], category["name"]
    pool_name = category_pool(category_id, category_name)
    channel_items = CHANNEL_POOLS.get(pool_name, CHANNEL_POOLS["general"]) + CHANNEL_POOLS["general"] + CHANNEL_POOLS["business"]
    blog_items = BLOG_POOLS.get(pool_name, BLOG_POOLS["general"]) + BLOG_POOLS["general"]
    path = RESOURCE_DIR / f"{category_id}.json"
    data = json.loads(path.read_text(encoding="utf-8")) if path.exists() else {"categoryId": category_id, "status": "verified", "channels": [], "blogs": [], "books": []}
    existing_ids = {str(item.get("id", "")).casefold() for item in data.get("channels", [])}
    existing_urls = {str(item.get("url", "")).rstrip('/').casefold() for item in data.get("blogs", [])}
    additions_channels = []
    channel_target = 20
    needed_channels = max(0, channel_target - len(data.get("channels", [])))
    for key, _, _ in channel_items:
        resolved_item = resolved_by_key.get(key.casefold())
        if resolved_item and resolved_item["id"].casefold() not in existing_ids and all(c["id"].casefold() != resolved_item["id"].casefold() for c in additions_channels):
            additions_channels.append(make_channel(resolved_item, category_id, category_name, len(additions_channels)))
        if len(additions_channels) >= needed_channels:
            break
    additions_blogs = []
    blog_target = 20
    needed_blogs = max(0, blog_target - len(data.get("blogs", [])))
    for _, url, focus in blog_items:
        blog = blog_by_url.get(url.rstrip('/').casefold())
        if blog and blog["url"].rstrip('/').casefold() not in existing_urls and all(b["url"].rstrip('/').casefold() != blog["url"].rstrip('/').casefold() for b in additions_blogs):
            additions_blogs.append({"name": blog["name"], "url": blog["url"], "region": "Global", "focus": focus, "verifiedOn": TODAY, "verificationMethod": "Direct source URL returned successfully; BlogRssService resolves RSS/Atom alternates and conventional feed paths at runtime."})
        if len(additions_blogs) >= needed_blogs:
            break
    data["channels"] = data.get("channels", []) + additions_channels
    data["blogs"] = data.get("blogs", []) + additions_blogs
    data["lastUpdated"] = TODAY
    data["notes"] = (str(data.get("notes", "")).strip() + f" {TODAY}: Added researched educational channels and blogs spanning the full learning pathway, not only business content.").strip()
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    report["categories"][category_id] = {"pool": pool_name, "channelsAdded": len(additions_channels), "blogsAdded": len(additions_blogs), "finalChannels": len(data["channels"]), "finalBlogs": len(data["blogs"])}
    report["files"].append(path.name)

# General receives ten of each, separate from the category-specific additions.
general_path = RESOURCE_DIR / "_general.json"
general = json.loads(general_path.read_text(encoding="utf-8"))
existing_ids = {str(item.get("id", "")).casefold() for item in general.get("channels", [])}
existing_urls = {str(item.get("url", "")).rstrip('/').casefold() for item in general.get("blogs", [])}
general_channels = []
needed_general_channels = max(0, 10 - len(general.get("channels", [])))
for key, _, _ in CHANNEL_POOLS["general"]:
    item = resolved_by_key.get(key.casefold())
    if item and item["id"].casefold() not in existing_ids:
        general_channels.append(make_channel(item, "_general", "General Learning", len(general_channels)))
    if len(general_channels) >= needed_general_channels:
        break
general_blogs = []
needed_general_blogs = max(0, 10 - len(general.get("blogs", [])))
for _, url, focus in BLOG_POOLS["general"]:
    item = blog_by_url.get(url.rstrip('/').casefold())
    if item and item["url"].rstrip('/').casefold() not in existing_urls:
        general_blogs.append({"name": item["name"], "url": item["url"], "region": "Global", "focus": focus, "verifiedOn": TODAY, "verificationMethod": "Direct source URL returned successfully; BlogRssService resolves RSS/Atom alternates and conventional feed paths at runtime."})
    if len(general_blogs) >= needed_general_blogs:
        break
general["channels"] = general.get("channels", []) + general_channels
general["blogs"] = general.get("blogs", []) + general_blogs
general["lastUpdated"] = TODAY
general["notes"] = (str(general.get("notes", "")).strip() + f" {TODAY}: Added ten broad educational channels and ten learning blogs for General discovery.").strip()
general_path.write_text(json.dumps(general, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
report["general"] = {"channelsAdded": len(general_channels), "blogsAdded": len(general_blogs), "finalChannels": len(general["channels"]), "finalBlogs": len(general["blogs"])}
OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"resolvedChannels": report["resolvedChannels"], "checkedBlogs": report["checkedBlogs"], "unresolvedHandles": len(report["unresolvedHandles"]), "rejectedBlogs": len(report["rejectedBlogs"]), "general": report["general"], "categorySummary": {k: {"channelsAdded": v["channelsAdded"], "blogsAdded": v["blogsAdded"]} for k,v in report["categories"].items()}}, ensure_ascii=False, indent=2))
