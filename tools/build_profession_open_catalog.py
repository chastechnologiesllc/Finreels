from __future__ import annotations

import json
from pathlib import Path

ROOT = Path('/home/ubuntu/Finreels')
RESOURCE_DIR = ROOT / 'assets' / 'data' / 'resources'
OUT = RESOURCE_DIR / '_profession_open_catalog.json'
TODAY = '2026-08-24'

NUC = 'https://www.nuc.edu.ng/wp-content/uploads/2026/03/'
NBTE = 'https://web.nbte.gov.ng/sites/default/files/2026-01/Brochure_%20Curricula_NOS_Jan26Edition.docx_.pdf'


def book(title: str, author: str, url: str, note: str, *, source_type: str = 'web', license_name: str = 'Publisher-authorized free access / see source', stage: str = 'Foundation to undergraduate', subject: str = 'Professional foundations', region: str = 'Global') -> dict:
    return {
        'title': title,
        'author': author,
        'freeSourceUrl': url,
        'freeSourceType': source_type,
        'freeSourceNote': f'{region} • {stage} • {subject}. {note}',
        'license': license_name,
        'region': region,
        'stage': stage,
        'subject': subject,
        'verifiedOn': TODAY,
        'verificationMethod': 'Direct official publisher, institutional repository, or government source checked during the 2026-08-24 profession OER research pass.',
    }


def nuc(title: str, url_suffix: str, subject: str, profession: str) -> dict:
    return book(
        title,
        'National Universities Commission (Nigeria)',
        NUC + url_suffix,
        f'Official Nigerian CCMAS curriculum reference for {profession}; it is a curriculum anchor and not a substitute for a commercial textbook.',
        source_type='pdf',
        license_name='Official Nigerian government curriculum publication; free public access',
        stage='Nigeria undergraduate curriculum anchor',
        subject=subject,
        region='Nigeria',
    )


def nbte(title: str, subject: str, profession: str) -> dict:
    return book(
        title,
        'National Board for Technical Education (Nigeria)',
        NBTE,
        f'Official Nigerian TVET curriculum/National Occupational Standards brochure relevant to {profession}; use it to map local progression and practical competencies.',
        source_type='pdf',
        license_name='Official Nigerian government curriculum publication; free public access',
        stage='Nigeria vocational curriculum anchor',
        subject=subject,
        region='Nigeria',
    )


OPENSTAX = 'https://openstax.org/details/books/'

def ox(slug: str, title: str, subject: str, stage: str = 'Foundation to undergraduate', note: str = 'OpenStax identifies its textbooks as peer-reviewed and openly licensed; the official page provides free online access.') -> dict:
    return book(title, 'OpenStax / Rice University', OPENSTAX + slug, note, license_name='OpenStax open license; see the title page for the current license notice', stage=stage, subject=subject, region='Global')


catalog: dict[str, list[dict]] = {
    'profession_01_medicine': [
        nuc('Medicine and Dentistry CCMAS 2023', 'Medicine-and-Dentistry-CCMAS-2023-FINAL.pdf', 'Medicine and clinical sciences', 'Medicine'),
        ox('anatomy-and-physiology-2e', 'Anatomy and Physiology 2e', 'Anatomy and physiology', 'Pre-clinical'),
        ox('biology-2e', 'Biology 2e', 'Biology and life sciences', 'Pre-medical'),
        ox('chemistry-2e', 'Chemistry 2e', 'General chemistry and biochemistry foundation', 'Pre-medical'),
        ox('microbiology-2e', 'Microbiology 2e', 'Medical microbiology foundation', 'Para-clinical'),
        ox('psychology-2e', 'Psychology 2e', 'Behavioral science and patient care', 'Pre-clinical to clinical'),
    ],
    'profession_02_law': [
        nuc('Law CCMAS', 'Law-ALL.pdf', 'Nigerian legal education and law', 'Law'),
        ox('business-law-i-essentials', 'Business Law I Essentials', 'Legal foundations and contracts', 'Foundation to undergraduate', 'Useful comparative/global business-law foundation; not a Nigerian-law textbook.'),
        ox('business-ethics', 'Business Ethics', 'Professional ethics and legal reasoning', 'Foundation to undergraduate'),
        ox('introduction-philosophy', 'Introduction to Philosophy', 'Logic, ethics, and critical reasoning', 'Foundation'),
        ox('writing-guide', 'Writing Guide with Handbook', 'Legal writing and research communication', 'Foundation'),
        ox('introduction-political-science', 'Introduction to Political Science', 'Constitutional systems and public institutions', 'Foundation to undergraduate'),
    ],
    'profession_03_pharmacy': [
        nuc('Pharmacy and Pharmaceutical Sciences CCMAS 2023', 'Pharmacy-and-Pharmaceutical-Sciences-CCMAS-2023-FINAL.pdf', 'Pharmacy and pharmaceutical sciences', 'Pharmacy'),
        ox('anatomy-and-physiology-2e', 'Anatomy and Physiology 2e', 'Human structure and function', 'Pre-clinical'),
        ox('chemistry-2e', 'Chemistry 2e', 'General and pharmaceutical chemistry foundation', 'Pre-clinical'),
        ox('organic-chemistry', 'Organic Chemistry', 'Organic and medicinal chemistry foundation', 'Pre-clinical to para-clinical'),
        ox('microbiology-2e', 'Microbiology 2e', 'Microbiology and infection', 'Para-clinical'),
        ox('pharmacology-for-nurses', 'Pharmacology for Nurses', 'Pharmacology and safe medication practice', 'Para-clinical to clinical'),
    ],
    'profession_04_nursing': [
        nuc('Allied Health Sciences CCMAS 2023', 'Allied-Health-Sciences-2023.pdf', 'Nursing and allied health curriculum', 'Nursing'),
        ox('nursing-fundamentals', 'Fundamentals of Nursing', 'Nursing foundations and patient care', 'Foundation to undergraduate'),
        ox('clinical-nursing-skills', 'Clinical Nursing Skills', 'Clinical skills and procedures', 'Undergraduate clinical'),
        ox('maternal-newborn-nursing', 'Maternal-Newborn Nursing', 'Maternal and newborn care', 'Undergraduate clinical'),
        ox('medical-surgical-nursing', 'Medical-Surgical Nursing', 'Adult medical-surgical care', 'Undergraduate clinical'),
        ox('nutrition-for-nurses', 'Nutrition for Nurses', 'Nutrition and nursing care', 'Foundation to clinical'),
        ox('pharmacology-for-nurses', 'Pharmacology for Nurses', 'Pharmacology and medication administration', 'Para-clinical to clinical'),
        ox('population-health', 'Population Health for Nurses', 'Community and population health', 'Undergraduate clinical'),
        ox('psychiatric-mental-health', 'Psychiatric-Mental Health Nursing', 'Mental-health nursing', 'Undergraduate clinical'),
    ],
    'profession_05_accounting': [
        nuc('Administration and Management CCMAS', 'Administration-and-Management.pdf', 'Accounting, administration, and management', 'Accounting'),
        ox('principles-financial-accounting', 'Principles of Financial Accounting', 'Financial accounting', 'Foundation to undergraduate'),
        ox('principles-managerial-accounting', 'Principles of Managerial Accounting', 'Management accounting', 'Undergraduate'),
        ox('principles-finance', 'Principles of Finance', 'Corporate and personal finance', 'Foundation to undergraduate'),
        ox('principles-economics-3e', 'Principles of Economics 3e', 'Economics for accounting and business', 'Foundation'),
        ox('introductory-business-statistics', 'Introductory Business Statistics', 'Quantitative methods and statistics', 'Foundation to undergraduate'),
        ox('principles-management', 'Principles of Management', 'Organizational management', 'Foundation to undergraduate'),
    ],
    'profession_06_engineering': [
        nuc('Engineering and Technology CCMAS 2023', 'Engineering-Technology-CCMAS-2023-FINAL.pdf', 'Engineering and technology curriculum', 'Engineering'),
        ox('additive-manufacturing-essentials', 'Additive Manufacturing Essentials', 'Manufacturing and engineering technology', 'Foundation to undergraduate'),
        book('Engineering Statics: Open and Interactive', 'Daniel W. Baker and William Haynes', 'https://engineeringstatics.org/frontmatter.html', 'Open and interactive statics text for engineering mechanics.', license_name='Open educational resource; license stated by publisher', stage='Foundation to undergraduate', subject='Engineering mechanics'),
        book('Intermediate Fluid Mechanics', 'Oregon State University Open Textbook', 'https://open.oregonstate.education/intermediate-fluid-mechanics/', 'Open university textbook for fluid mechanics.', license_name='Open educational resource; license stated by publisher', stage='Undergraduate', subject='Fluid mechanics'),
        ox('principles-data-science', 'Principles of Data Science', 'Computing, data, and engineering analytics', 'Foundation to undergraduate'),
        book('Elementary Differential Equations with Boundary Value Problems', 'William F. Trench', 'https://digitalcommons.trinity.edu/mono/9/', 'Open engineering and science mathematics text.', license_name='CC BY; see repository record', stage='Foundation to undergraduate', subject='Engineering mathematics'),
        book('Fundamentals of Electrical Engineering I', 'Charles Alexander and Matthew Sadiku / OpenStax CNX', 'https://cnx.org/contents/d442r0wh@9.72:g9deOnx5@19', 'Open electrical-engineering foundation text.', license_name='CC BY; see source record', stage='Foundation to undergraduate', subject='Electrical engineering'),
    ],
    'profession_07_architecture': [
        nuc('Architecture CCMAS 2023', 'Architecture-CCMAS-2023-FINAL.pdf', 'Architecture and built environment curriculum', 'Architecture'),
        book('Sustainability: A Comprehensive Foundation', 'Theis and Tomkin, editors', 'https://open.umn.edu/opentextbooks/textbooks/96', 'Open multidisciplinary foundation covering sustainability, engineering, applied arts, natural sciences, social sciences, and humanities.', license_name='CC BY; see Open Textbook Library record', stage='Foundation to undergraduate', subject='Sustainable architecture and built environment'),
        ox('algebra-and-trigonometry-2e', 'Algebra and Trigonometry 2e', 'Design and quantitative foundation', 'Foundation'),
        ox('calculus-volume-1', 'Calculus Volume 1', 'Mathematics for architecture and engineering', 'Foundation to undergraduate'),
        ox('physics-2e', 'University Physics Volume 1', 'Building science and physics foundation', 'Foundation to undergraduate'),
        book('Building Maintenance & Construction: Tools and Maintenance Tasks', 'Open educational resource authors', 'https://pressbooks.oer.hawaii.edu/buildingmaint/', 'Open built-environment maintenance and construction resource.', license_name='Open educational resource; license stated by publisher', stage='Undergraduate practical', subject='Building construction and maintenance'),
    ],
    'profession_08_estate_management_surveying': [
        nuc('Environmental Sciences CCMAS 2023', 'Environmental-Sciences-CCMAS-2023-FINAL.pdf', 'Environmental sciences, estate management, and surveying context', 'Estate management and surveying'),
        book('Surveying and Levelling Instruments, Theoretically and Practically Described', 'William Ford Stanley', 'https://www.gutenberg.org/ebooks/63834', 'Public-domain field-surveying manual; historical equipment content should be supplemented with current standards.', license_name='Project Gutenberg public-domain edition', stage='Foundation and practical', subject='Surveying instruments and field practice'),
        book('Sustainability: A Comprehensive Foundation', 'Theis and Tomkin, editors', 'https://open.umn.edu/opentextbooks/textbooks/96', 'Open multidisciplinary sustainability text relevant to land, buildings, and environmental management.', license_name='CC BY; see Open Textbook Library record', stage='Foundation to undergraduate', subject='Sustainable built environment'),
        book('Engineering Statics: Open and Interactive', 'Daniel W. Baker and William Haynes', 'https://engineeringstatics.org/frontmatter.html', 'Open mechanics foundation for surveying, construction, and built-environment students.', license_name='Open educational resource; license stated by publisher', stage='Foundation', subject='Structures and mechanics'),
        ox('principles-data-science', 'Principles of Data Science', 'GIS, data, and property analytics foundation', 'Foundation to undergraduate'),
    ],
    'profession_09_banking_finance': [
        nuc('Administration and Management CCMAS', 'Administration-and-Management.pdf', 'Banking, finance, administration, and management', 'Banking and Finance'),
        ox('principles-finance', 'Principles of Finance', 'Financial management and markets', 'Foundation to undergraduate'),
        ox('principles-economics-3e', 'Principles of Economics 3e', 'Microeconomics and macroeconomics', 'Foundation to undergraduate'),
        ox('principles-financial-accounting', 'Principles of Financial Accounting', 'Financial reporting and accounting', 'Foundation to undergraduate'),
        ox('principles-managerial-accounting', 'Principles of Managerial Accounting', 'Cost and management accounting', 'Undergraduate'),
        ox('introductory-business-statistics', 'Introductory Business Statistics', 'Statistics and quantitative finance', 'Foundation to undergraduate'),
        ox('principles-data-science', 'Principles of Data Science', 'Finance analytics and data ethics', 'Foundation to undergraduate'),
    ],
    'profession_10_mass_communication_media_pr': [
        nuc('Communication and Media Studies CCMAS 2023', 'Communication-and-Media-Studies-CCMAS-2023-FINAL.pdf', 'Communication, journalism, media, and public relations', 'Mass Communication/Media and PR'),
        ox('writing-guide', 'Writing Guide with Handbook', 'Writing, editing, and communication', 'Foundation'),
        ox('introduction-sociology-3e', 'Introduction to Sociology 3e', 'Media, society, and audiences', 'Foundation to undergraduate'),
        ox('introduction-political-science', 'Introduction to Political Science', 'Public institutions and civic communication', 'Foundation'),
        ox('principles-marketing', 'Principles of Marketing', 'Marketing, public relations, and audience strategy', 'Foundation to undergraduate'),
        book('Interpersonal Communication: A Mindful Approach to Relationships 2nd Edition', 'Ian McCornick', 'https://milneopentextbooks.org/interpersonal-communication-a-mindful-2nd/', 'Open interpersonal-communication text relevant to media and PR practice.', license_name='Open educational resource; license stated by publisher', stage='Foundation to undergraduate', subject='Interpersonal and professional communication'),
    ],
    'profession_11_computer_science_software_engineering': [
        nuc('Computing CCMAS 2023', 'Computing-CCMAS-2023-FINAL.pdf', 'Computing and software engineering curriculum', 'Computer Science/Software Engineering'),
        ox('introduction-computer-science', 'Introduction to Computer Science', 'Algorithms, data structures, systems, and software development', 'Foundation to undergraduate'),
        ox('introduction-python-programming', 'Introduction to Python Programming', 'Programming and computational thinking', 'Foundation to undergraduate'),
        ox('foundations-information-systems', 'Foundations of Information Systems', 'Information systems and organizations', 'Foundation to undergraduate'),
        ox('principles-data-science', 'Principles of Data Science', 'Data science, AI, and ethics', 'Foundation to undergraduate'),
        ox('workplace-software-skills', 'Workplace Software and Skills', 'Digital productivity and workplace technology', 'Foundation'),
    ],
    'profession_12_agriculture': [
        nuc('Agriculture CCMAS 2023', 'Agriculture-2023.pdf', 'Agriculture and agricultural sciences curriculum', 'Agriculture'),
        book('Introduction to Permaculture', 'Open Textbook Library authors', 'https://open.umn.edu/opentextbooks/textbooks/469', 'Open agriculture and sustainable-design foundation.', license_name='Open educational resource; license stated by publisher', stage='Foundation to undergraduate', subject='Sustainable agriculture'),
        ox('biology-2e', 'Biology 2e', 'Plant, animal, and life sciences foundation', 'Foundation'),
        ox('chemistry-2e', 'Chemistry 2e', 'Soil, plant, and agricultural chemistry foundation', 'Foundation'),
        book('Computers on the Farm', 'U.S. Department of Agriculture', 'https://www.gutenberg.org/ebooks/59316', 'Public-domain agricultural technology and farm-computing reference; historical context should be supplemented with current tools.', license_name='Project Gutenberg public-domain edition', stage='Foundation and practical', subject='Agricultural technology'),
        book('Beef Slaughtering, Cutting, Preserving, and Cooking on the Farm', 'U.S. Department of Agriculture', 'https://www.gutenberg.org/ebooks/62848', 'Public-domain livestock and food-processing manual relevant to agricultural value chains.', license_name='Project Gutenberg public-domain edition', stage='Practical foundation', subject='Livestock and agricultural value chains'),
    ],
    'profession_13_education': [
        nuc('Education CCMAS 2023', 'Education-CCMAS-2023-New.pdf', 'Teacher education and education studies', 'Education'),
        book('Educational Psychology - Second Edition', 'Dale H. Schunk / University of Manitoba edition', 'https://home.cc.umanitoba.ca/~seifert/EdPsy2009.pdf', 'Open educational psychology text covering learning, development, diversity, disability, and motivation.', license_name='CC BY; see source record', stage='Foundation to undergraduate', subject='Educational psychology'),
        book('Teaching in a Digital Age 2nd Edition', 'Anthony William Bates', 'https://pressbooks.bccampus.ca/teachinginadigitalagev2/', 'Open text on teaching, learning design, technology, and digital education.', license_name='CC BY-NC; see publisher record', stage='Foundation to undergraduate', subject='Digital pedagogy'),
        ox('psychology-2e', 'Psychology 2e', 'General psychology and learner development', 'Foundation'),
        ox('lifespan-development', 'Lifespan Development', 'Human development across the lifespan', 'Foundation to undergraduate'),
        ox('writing-guide', 'Writing Guide with Handbook', 'Academic literacy and teacher communication', 'Foundation'),
    ],
    'profession_14_dentistry': [
        nuc('Medicine and Dentistry CCMAS 2023', 'Medicine-and-Dentistry-CCMAS-2023-FINAL.pdf', 'Dentistry and medicine curriculum', 'Dentistry'),
        ox('anatomy-and-physiology-2e', 'Anatomy and Physiology 2e', 'Head, neck, and human-body foundations', 'Pre-clinical'),
        ox('biology-2e', 'Biology 2e', 'Life sciences and oral biology foundation', 'Pre-clinical'),
        ox('chemistry-2e', 'Chemistry 2e', 'Chemistry and biomaterials foundation', 'Pre-clinical'),
        ox('microbiology-2e', 'Microbiology 2e', 'Oral microbiology and infection foundation', 'Para-clinical'),
        ox('psychology-2e', 'Psychology 2e', 'Patient communication and behavioral science', 'Foundation to clinical'),
    ],
    'profession_15_psychology_counselling': [
        nuc('Social Sciences CCMAS 2023', 'Social-Sciences-CCMAS-FINAL-2023-A.pdf', 'Psychology and social-science curriculum', 'Psychology/Counselling'),
        ox('psychology-2e', 'Psychology 2e', 'General psychology', 'Foundation to undergraduate'),
        book('Introduction to Psychology', 'University of Minnesota Libraries Publishing', 'https://open.umn.edu/opentextbooks/textbooks/introduction-to-psychology', 'Open introductory psychology text using behavior and empiricism as organizing themes.', license_name='CC BY-NC-SA; see Open Textbook Library record', stage='Foundation'),
        book('Research Methods in Psychology 2nd Canadian Edition', 'I-Chant A. Chiang, Rajiv S. Jhangiani, and Paul C. Price', 'https://opentextbc.ca/researchmethods/', 'Open research-methods and evidence-evaluation text.', license_name='CC BY-NC-SA; see publisher record', stage='Undergraduate', subject='Psychological research methods'),
        book('Principles of Social Psychology', 'University of Minnesota Libraries Publishing', 'https://socialsci.libretexts.org/Bookshelves/Psychology/Social_Psychology_and_Personality/Principles_of_Social_Psychology_(LibreTexts)', 'Open social-psychology foundation.', license_name='CC BY-NC-SA; see source record', stage='Foundation to undergraduate', subject='Social psychology'),
        ox('lifespan-development', 'Lifespan Development', 'Human development and counselling foundations', 'Foundation to undergraduate'),
    ],
    'profession_16_fashion_design_tailoring': [
        nbte('NBTE Approved Curricula and National Occupational Standards Brochure', 'Fashion design, tailoring, and clothing technology', 'Fashion Design and Tailoring'),
        book('Corticelli Home Needlework, 1898: A Manual of Art, Embroidery and Knitting', 'Corticelli Silk Mills', 'https://www.gutenberg.org/ebooks/51204', 'Public-domain practical needlework and textile reference; historical techniques should be supplemented with current Nigerian TVET standards.', license_name='Project Gutenberg public-domain edition', stage='Foundation and practical', subject='Needlework, embroidery, and textile craft'),
        ox('workplace-software-skills', 'Workplace Software and Skills', 'Digital tools for fashion business and production documentation', 'Foundation'),
        ox('principles-marketing', 'Principles of Marketing', 'Fashion marketing and customer development', 'Foundation to practical'),
        ox('principles-management', 'Principles of Management', 'Small studio and tailoring-business management', 'Foundation to practical'),
    ],
    'profession_17_hairdressing_cosmetology': [
        nbte('NBTE Approved Curricula and National Occupational Standards Brochure', 'Hairdressing, cosmetology, beauty therapy, and salon practice', 'Hairdressing and Cosmetology'),
        book('Art and Fundamentals of Hairdressing: A Text-book for Professionals and a Student’s Guide', 'William J. Korf', 'https://archive.org/details/artfundamentalso00korf', 'Free public-access archival scan identified for historical hairdressing fundamentals; confirm local access and rights notice at the source before redistribution.', license_name='Free public-access scan; source rights notice applies', stage='Foundation and practical', subject='Hairdressing fundamentals'),
        ox('chemistry-2e', 'Chemistry 2e', 'Cosmetic chemistry foundation', 'Foundation'),
        ox('biology-2e', 'Biology 2e', 'Skin, hair, and human-biology foundation', 'Foundation'),
        ox('principles-marketing', 'Principles of Marketing', 'Salon and beauty-business marketing', 'Foundation to practical'),
    ],
    'profession_18_catering_event_planning': [
        nbte('NBTE Approved Curricula and National Occupational Standards Brochure', 'Hospitality, catering, food safety, and event-service competencies', 'Hospitality and Catering'),
        book('A Brief Guide to the Food Collection', 'U.S. Department of Agriculture', 'https://www.gutenberg.org/ebooks/64712', 'Public-domain food reference useful for historical food knowledge and culinary foundations.', license_name='Project Gutenberg public-domain edition', stage='Foundation and practical', subject='Food and culinary foundations'),
        book('Choice Recipes and Menus Using Canned Foods', 'U.S. Department of Agriculture', 'https://www.gutenberg.org/ebooks/66069', 'Public-domain recipes and menu planning reference; supplement with current food-safety requirements.', license_name='Project Gutenberg public-domain edition', stage='Foundation and practical', subject='Menu planning'),
        book('A Treatise on Adulterations of Food, and Culinary Poisons', 'Friedrich Accum', 'https://www.gutenberg.org/ebooks/43545', 'Public-domain historical food-safety reference; modern Nigerian regulations must take precedence.', license_name='Project Gutenberg public-domain edition', stage='Foundation', subject='Food safety history'),
        ox('principles-management', 'Principles of Management', 'Catering operations and event-team management', 'Foundation to practical'),
        ox('principles-marketing', 'Principles of Marketing', 'Hospitality marketing and events promotion', 'Foundation to practical'),
    ],
    'profession_19_automobile_technology': [
        nbte('NBTE Approved Curricula and National Occupational Standards Brochure', 'Automobile mechanics, vehicle systems, and transport technology competencies', 'Automobile Technology'),
        ox('additive-manufacturing-essentials', 'Additive Manufacturing Essentials', 'Manufacturing, materials, and engineering technology', 'Foundation to undergraduate'),
        book('Introduction to Mechanical Engineering Design', 'Jacqulyn A. Baughman', 'https://www.iastatedigitalpress.com/plugins/books/131/', 'Open mechanical-design foundation relevant to vehicle systems and workshop design.', license_name='CC BY-SA 4.0; see Iowa State University Digital Press record', stage='Foundation to practical', subject='Mechanical design'),
        book('Fundamentals of Compressible Flow Mechanics', 'Genick Bar-Meir', 'https://zenodo.org/records/18217916', 'Open engineering mechanics text; the direct Zenodo record provides the source and version details.', license_name='CC BY; see Open Textbook Library record', stage='Undergraduate', subject='Fluid and propulsion mechanics'),
        book('Sears Owners Manual', 'Sears, Roebuck and Co.', 'https://www.gutenberg.org/ebooks/39714', 'Public-domain historical equipment manual; not a substitute for current vehicle service manuals or safety standards.', license_name='Project Gutenberg public-domain edition', stage='Historical technical reference', subject='Mechanical equipment documentation'),
        ox('principles-data-science', 'Principles of Data Science', 'Automotive diagnostics and data literacy', 'Foundation'),
    ],
    'profession_20_photography_videography': [
        nbte('NBTE Approved Curricula and National Occupational Standards Brochure', 'Photography, cinematography, media production, and visual storytelling competencies', 'Photography and Cinematography'),
        book('Learning Digital Photography', 'National Institute for Creative Teaching', 'https://nic.pressbooks.pub/learningdigitalphotography/', 'Open digital-photography textbook covering camera operation, exposure, composition, and workflow.', license_name='Open educational resource; license stated by publisher', stage='Foundation to practical', subject='Digital photography'),
        book('A Manual of Photographic Chemistry, Including the Practice of the Collodion Process', 'W. H. Thornthwaite', 'https://www.gutenberg.org/ebooks/63710', 'Public-domain historical photography-chemistry reference; digital production requires current software and safety practices.', license_name='Project Gutenberg public-domain edition', stage='Historical technical reference', subject='Photographic chemistry'),
        book('The Barnet Book of Photography: A Collection of Practical Articles', 'Various authors', 'https://www.gutenberg.org/ebooks/40468', 'Public-domain practical photography collection.', license_name='Project Gutenberg public-domain edition', stage='Foundation and practical', subject='Photography practice'),
        book('The History and Practice of the Art of Photography', 'Henry H. Snelling', 'https://www.gutenberg.org/ebooks/168', 'Public-domain history and practice reference.', license_name='Project Gutenberg public-domain edition', stage='Foundation', subject='Photography history and practice'),
        ox('writing-guide', 'Writing Guide with Handbook', 'Production briefs, captions, scripts, and professional communication', 'Foundation'),
    ],
}

# Avoid adding exact duplicates already present in each profession file. The overlay
# remains additive and intentionally preserves cross-profession reuse of a book.
result = {'version': 1, 'lastUpdated': TODAY, 'sourcePolicy': 'Free/public access only with source/license evidence; commercial textbook titles are not copied unless an authorized free edition is verified.', 'categories': []}
for category_id, candidates in catalog.items():
    existing = RESOURCE_DIR / f'{category_id}.json'
    existing_keys: set[tuple[str, str]] = set()
    if existing.exists():
        data = json.loads(existing.read_text(encoding='utf-8'))
        for item in data.get('books') or []:
            existing_keys.add(((item.get('title') or '').strip().casefold(), (item.get('freeSourceUrl') or '').strip().casefold()))
    unique: list[dict] = []
    seen = set(existing_keys)
    for item in candidates:
        key = (item['title'].strip().casefold(), item['freeSourceUrl'].strip().casefold())
        if key in seen:
            continue
        seen.add(key)
        unique.append(item)
    result['categories'].append({'categoryId': category_id, 'books': unique})

OUT.write_text(json.dumps(result, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
print(json.dumps({'categories': len(result['categories']), 'new_books': sum(len(item['books']) for item in result['categories']), 'output': str(OUT)}, indent=2))
