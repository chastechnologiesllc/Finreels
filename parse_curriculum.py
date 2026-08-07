#!/usr/bin/env python3
"""
Parses FinReels' three source research docs into one structured JSON file
that becomes the app's `assets/data/resource_categories.json`.

Sources (all on disk, read mechanically — no hand-transcription):
  1. FinReels_20_Skills_Business_Questions.md   -> 20 skills, 5 questions each
  2. Finkeels_20_Businesses_Framework.md        -> 20 businesses, 10 Q&A each
  3. finreels-business-of-profession-curriculum.md
       Part 1  -> 10 curriculum modules (M1-M10)
       Part 2  -> the 2026 tax-reform fact bank
       Part 3  -> 20 professions: real problem / 4 questions / don't-know fact

The canonical id/section/number/name for all 60 categories is taken from the
verified table of contents inside FinReels_Complete_Resource_Directory PDF
(extracted separately to /tmp/complete_dir.txt), NOT re-typed by hand.
"""
import json
import re
import unicodedata

UPLOADS = "/mnt/user-data/uploads"


def slugify(name: str) -> str:
    name = name.split(" (Trade)")[0]
    name = unicodedata.normalize("NFKD", name)
    name = re.sub(r"[/&-]", " ", name)          # separators, not deletions
    name = re.sub(r"[^\w\s]", "", name).strip().lower()
    name = re.sub(r"\s+", "_", name)
    return name


# ---------------------------------------------------------------------------
# 1. Canonical 60-category list, taken verbatim from the verified PDF ToC
#    (grep output already confirmed against both source PDFs).
# ---------------------------------------------------------------------------
CANONICAL = {
    "skill": [
        "Tailoring & Fashion Design", "Hairdressing & Hairstyling", "Barbing",
        "Makeup Artistry", "Welding & Metal Fabrication",
        "Carpentry & Furniture Making", "Plumbing",
        "Electrical Installation & Wiring", "Auto Mechanics",
        "Phone & Electronics Repair", "Graphic Design", "Web/App Development",
        "Photography", "Videography & Video Editing", "Catering & Baking",
        "Event Decoration & Planning", "Shoemaking & Leatherwork",
        "POP/Tiling & Interior Decor", "Solar Installation & Renewable Energy",
        "AC & Refrigeration Repair",
    ],
    "business": [
        "POS/Agent Banking", "Provision Store/Mini-Mart",
        "Fashion Retail/Boutique", "Food Vending/Catering/Meal-Prep",
        "Real Estate Agency", "Logistics/Dispatch Rider",
        "Event Planning & Rentals", "Salon/Barbing/Beauty Spa",
        "Car Hire/Ride-Hailing Fleet", "Poultry Farming", "Fish Farming",
        "Laundry & Dry-Cleaning", "Bakery/Confectionery",
        "Cosmetics & Skincare", "Phone & Gadget Sales/Repair",
        "Private Tutorial/Online Tutoring", "Mini-Importation/E-commerce",
        "Cleaning Services", "Pure Water/Sachet & Bottled Water",
        "Social Media/Digital Marketing Agency",
    ],
    "profession": [
        "Medicine", "Law", "Pharmacy", "Nursing", "Accounting", "Engineering",
        "Architecture", "Estate Management/Surveying", "Banking & Finance",
        "Mass Communication/Media & PR", "Computer Science/Software Engineering",
        "Agriculture", "Education", "Dentistry", "Psychology/Counselling",
        "Fashion Design & Tailoring (Trade)", "Hairdressing/Cosmetology (Trade)",
        "Catering & Event Planning (Trade)", "Automobile Technology (Trade)",
        "Photography & Videography (Trade)",
    ],
}

# ---------------------------------------------------------------------------
# 1b. Search keywords/aliases per category, keyed by canonical id — powers
#     the onboarding/Discover "type what you do" allocation (see
#     lib/utils/category_search.dart). Lives here (not in a source doc) so
#     it survives every regeneration of resource_categories.json instead of
#     being hand-patched onto the output and lost next time this runs.
#     Keep in sync with assets/data/resource_categories.json if you ever
#     edit one without the other — this dict is the source of truth.
# ---------------------------------------------------------------------------
SEARCH_KEYWORDS = {
    "skill_01_tailoring_fashion_design": [
        "tailor", "tailoring", "seamstress", "sewing", "sew", "fashion designer",
        "fashion design", "ankara", "aso ebi", "pattern cutting", "cloth making",
        "fabric", "couture", "bespoke clothing", "dressmaking", "dressmaker", "style",
    ],
    "skill_02_hairdressing_hairstyling": [
        "hairdresser", "hairstylist", "hair salon", "braiding", "braider", "weaving",
        "hair styling", "natural hair", "wig making", "wig maker", "relaxer",
        "plaiting", "cornrow", "salon", "hair stylist",
    ],
    "skill_03_barbing": [
        "barber", "barbershop", "barbing salon", "haircut", "hair cut", "fade",
        "clipper", "shaving", "low cut", "hair cutting",
    ],
    "skill_04_makeup_artistry": [
        "makeup artist", "mua", "bridal makeup", "gele", "gele tying", "beauty artist",
        "cosmetics application", "glam", "face beat", "makeup",
    ],
    "skill_05_welding_metal_fabrication": [
        "welder", "welding", "fabrication", "metal work", "iron bending",
        "gate making", "burglary proof", "metal fabricator", "iron works",
        "aluminium works", "grill making",
    ],
    "skill_06_carpentry_furniture_making": [
        "carpenter", "carpentry", "furniture maker", "wood work", "woodwork",
        "joinery", "cabinet making", "furniture making", "wood worker",
    ],
    "skill_07_plumbing": [
        "plumber", "pipe fitting", "water system", "borehole", "drainage",
        "plumbing works", "pipe fitter", "water fitting",
    ],
    "skill_08_electrical_installation_wiring": [
        "electrician", "wiring", "electrical installation", "house wiring",
        "cabling", "power installation", "electrical works",
    ],
    "skill_09_auto_mechanics": [
        "mechanic", "auto repair", "car repair", "vehicle repair", "panel beater",
        "automobile technician", "engine repair", "auto technician", "car mechanic",
    ],
    "skill_10_phone_electronics_repair": [
        "phone repair", "phone technician", "gsm repair", "electronics repair",
        "phone engineer", "screen replacement", "phone repairer", "gadget repair",
    ],
    "skill_11_graphic_design": [
        "graphic designer", "logo design", "branding design", "flyer design",
        "graphics design", "adobe illustrator", "photoshop design", "designer",
    ],
    "skill_12_web_app_development": [
        "web developer", "app developer", "software developer", "programmer",
        "coding", "website design", "web design", "software engineer", "developer",
    ],
    "skill_13_photography": [
        "photographer", "photo shoot", "wedding photography", "portrait photography",
        "camera man", "photo studio",
    ],
    "skill_14_videography_video_editing": [
        "videographer", "video editor", "video editing", "cinematography",
        "film making", "video production", "video shooting",
    ],
    "skill_15_catering_baking": [
        "caterer", "catering", "baker", "baking", "cake making", "cake maker",
        "small chops", "event catering", "cook", "cooking", "pastry",
    ],
    "skill_16_event_decoration_planning": [
        "event decorator", "event planner", "party decoration", "decor",
        "event styling", "party planning", "event decoration", "party decorator",
    ],
    "skill_17_shoemaking_leatherwork": [
        "shoemaker", "cobbler", "shoe making", "leather work", "bag making",
        "sandal making", "shoe maker", "leatherwork",
    ],
    "skill_18_pop_tiling_interior_decor": [
        "pop ceiling", "tiler", "tiling", "interior decorator", "ceiling design",
        "interior design", "screeding", "pop design", "interior decoration",
    ],
    "skill_19_solar_installation_renewable_energy": [
        "solar installer", "solar panel", "inverter installation", "renewable energy",
        "solar power", "solar energy", "inverter installer",
    ],
    "skill_20_ac_refrigeration_repair": [
        "ac repair", "air conditioner repair", "fridge repair", "refrigerator technician",
        "hvac", "cooling repair", "ac technician", "refrigeration",
    ],
    "business_01_pos_agent_banking": [
        "pos agent", "pos business", "agent banking", "mobile money", "bank agent",
        "pos machine",
    ],
    "business_02_provision_store_mini_mart": [
        "provision store", "mini mart", "supermarket", "retail shop",
        "convenience store", "provisions", "shop owner",
    ],
    "business_03_fashion_retail_boutique": [
        "boutique", "fashion retail", "clothing store", "clothes shop", "fashion shop",
        "clothing business",
    ],
    "business_04_food_vending_catering_meal_prep": [
        "food vendor", "food business", "mama put", "meal prep", "food seller",
        "restaurant business", "food vending",
    ],
    "business_05_real_estate_agency": [
        "real estate agent", "property agent", "land sales", "house agent",
        "realtor", "property business", "real estate business",
    ],
    "business_06_logistics_dispatch_rider": [
        "dispatch rider", "logistics business", "courier", "delivery service",
        "bike delivery", "dispatch business", "logistics company",
    ],
    "business_07_event_planning_rentals": [
        "event rental", "chairs and canopy rental", "event planner business",
        "party rental", "canopy rental", "event equipment rental",
    ],
    "business_08_salon_barbing_beauty_spa": [
        "salon business", "spa business", "beauty parlour", "salon owner",
        "barbing shop business", "beauty spa",
    ],
    "business_09_car_hire_ride_hailing_fleet": [
        "car hire", "uber business", "bolt business", "ride hailing", "fleet business",
        "taxi business", "ride share business",
    ],
    "business_10_poultry_farming": [
        "poultry farmer", "chicken farming", "egg business", "poultry business",
        "chicken business", "poultry farm",
    ],
    "business_11_fish_farming": [
        "fish farmer", "catfish farming", "fishery", "aquaculture", "fish farm",
        "fish pond business",
    ],
    "business_12_laundry_dry_cleaning": [
        "laundry business", "dry cleaning", "washing service", "laundromat",
        "dry cleaners", "laundry service",
    ],
    "business_13_bakery_confectionery": [
        "bakery", "confectionery", "bread making business", "pastry business",
        "bread business", "cake business",
    ],
    "business_14_cosmetics_skincare": [
        "cosmetics business", "skincare business", "beauty products", "cream making",
        "skincare products", "cosmetics brand",
    ],
    "business_15_phone_gadget_sales_repair": [
        "phone sales", "gadget shop", "phone accessories business", "gadget business",
        "phone selling",
    ],
    "business_16_private_tutorial_online_tutoring": [
        "tutor", "home lessons", "private lessons", "online tutor", "tutorial center",
        "tutorial centre", "lesson teacher", "extra lessons",
    ],
    "business_17_mini_importation_e_commerce": [
        "importation business", "online store", "e-commerce", "ecommerce",
        "dropshipping", "mini importation", "online selling",
    ],
    "business_18_cleaning_services": [
        "cleaning business", "cleaning company", "janitorial services",
        "home cleaning", "cleaning service",
    ],
    "business_19_pure_water_sachet_bottled_water": [
        "pure water business", "sachet water", "bottled water production",
        "water factory", "pure water factory",
    ],
    "business_20_social_media_digital_marketing_agency": [
        "smma", "social media manager", "digital marketing agency",
        "social media agency", "marketing agency",
    ],
    "profession_01_medicine": ["doctor", "physician", "medical doctor", "medicine", "medical practice"],
    "profession_02_law": ["lawyer", "barrister", "solicitor", "legal practice", "attorney", "law firm"],
    "profession_03_pharmacy": ["pharmacist", "pharmacy", "chemist", "drug store"],
    "profession_04_nursing": ["nurse", "nursing", "registered nurse"],
    "profession_05_accounting": ["accountant", "accounting", "bookkeeping", "auditor", "bookkeeper"],
    "profession_06_engineering": ["engineer", "engineering"],
    "profession_07_architecture": ["architect", "architecture"],
    "profession_08_estate_management_surveying": [
        "estate surveyor", "valuer", "surveying", "estate management", "land surveyor",
    ],
    "profession_09_banking_finance": ["banker", "finance professional", "investment banking", "banking"],
    "profession_10_mass_communication_media_pr": [
        "journalist", "media professional", "public relations", "broadcaster", "pr",
        "mass communication",
    ],
    "profession_11_computer_science_software_engineering": [
        "software engineer", "computer scientist", "programmer", "it professional",
        "computer science",
    ],
    "profession_12_agriculture": ["agriculturist", "farmer", "agronomist", "agric", "agriculture"],
    "profession_13_education": ["teacher", "educator", "lecturer", "teaching", "school teacher"],
    "profession_14_dentistry": ["dentist", "dental practice", "dentistry"],
    "profession_15_psychology_counselling": [
        "psychologist", "counsellor", "counselor", "therapist", "counselling", "counseling",
    ],
    "profession_16_fashion_design_tailoring": ["fashion design profession", "tailoring profession"],
    "profession_17_hairdressing_cosmetology": ["cosmetology", "hairdressing profession"],
    "profession_18_catering_event_planning": ["catering profession", "event planning profession"],
    "profession_19_automobile_technology": ["automobile technology", "auto technology profession"],
    "profession_20_photography_videography": ["photography profession", "videography profession"],
}

categories = {}
for section, names in CANONICAL.items():
    for i, name in enumerate(names, start=1):
        cid = f"{section}_{i:02d}_{slugify(name)}"
        categories[cid] = {
            "id": cid,
            "section": section,
            "number": i,
            "name": name,
            "skillQuestions": None,
            "businessQA": None,
            "realProblem": None,
            "businessQuestions": None,
            "dontKnowFact": None,
            "dontKnowModule": None,
            "dontKnowModules": None,
            "searchKeywords": SEARCH_KEYWORDS.get(cid, []),
        }


def find_category(section: str, number: int):
    return categories[f"{section}_{number:02d}_" + slugify(CANONICAL[section][number - 1])]


# ---------------------------------------------------------------------------
# 2. Skills doc -> 5 questions each
# ---------------------------------------------------------------------------
with open(f"{UPLOADS}/FinReels_20_Skills_Business_Questions.md", encoding="utf-8") as f:
    skills_txt = f.read()

skill_blocks = re.split(r"\n## (\d+)\. (.+?)\n", skills_txt)[1:]
# skill_blocks = [num, name, body, num, name, body, ...]
for i in range(0, len(skill_blocks), 3):
    num, name, body = int(skill_blocks[i]), skill_blocks[i + 1].strip(), skill_blocks[i + 2]
    questions = re.findall(r"^- (.+)$", body, flags=re.MULTILINE)
    cat = find_category("skill", num)
    cat["skillQuestions"] = [q.strip() for q in questions]
    assert len(cat["skillQuestions"]) == 5, f"skill {num} {name} got {len(questions)} q"

# ---------------------------------------------------------------------------
# 3. Businesses doc -> 10 universal questions + 10 answers per business
# ---------------------------------------------------------------------------
with open(f"{UPLOADS}/Finkeels_20_Businesses_Framework.md", encoding="utf-8") as f:
    biz_txt = f.read()

framework_block = re.search(r"## The Framework\n(.+?)\n---", biz_txt, flags=re.DOTALL).group(1)
template_questions = [q.strip() for q in re.findall(r"^\d+\.\s+(.+)$", framework_block, flags=re.MULTILINE)]
assert len(template_questions) == 10

biz_blocks = re.split(r"\n## (\d+)\. (.+?)\n", biz_txt)[1:]
for i in range(0, len(biz_blocks), 3):
    num, name, body = int(biz_blocks[i]), biz_blocks[i + 1].strip(), biz_blocks[i + 2]
    answers = [a.strip() for a in re.findall(r"^\d+\.\s+(.+)$", body, flags=re.MULTILINE)]
    assert len(answers) == 10, f"business {num} {name} got {len(answers)} a"
    cat = find_category("business", num)
    cat["businessQA"] = [{"question": q, "answer": a} for q, a in zip(template_questions, answers)]

# ---------------------------------------------------------------------------
# 4. Curriculum doc -> Part 1 modules, Part 2 tax reform, Part 3 professions
# ---------------------------------------------------------------------------
with open(f"{UPLOADS}/finreels-business-of-profession-curriculum.md", encoding="utf-8") as f:
    curriculum_txt = f.read()

part1 = re.search(r"## Part 1.+?\n(.+?)\n---", curriculum_txt, flags=re.DOTALL).group(1)
modules = []
for m in re.finditer(r"\|\s*(M\d+)\s*\|\s*(.+?)\s*\|\s*(.+?)\s*\|", part1):
    code, mname, desc = m.groups()
    if code == "#":
        continue
    modules.append({"code": code, "name": mname.strip(), "description": desc.strip()})
assert len(modules) == 10, f"got {len(modules)} modules"

part2 = re.search(r"## Part 2.+?\n(.+?)\n---", curriculum_txt, flags=re.DOTALL).group(1)
tax_facts = [f.strip() for f in re.findall(r"^- (.+)$", part2, flags=re.MULTILINE)]
why_match = re.search(r"\*\*Why this matters for FinReels:\*\*\s*(.+?)(?:\n\n|\Z)", part2, flags=re.DOTALL)
tax_reform = {
    "headline": "Nigeria's tax system was overhauled by four laws effective 1 January 2026.",
    "facts": [re.sub(r"\*\*(.+?)\*\*", r"\1", f) for f in tax_facts],
    "whyItMatters": re.sub(r"\s+", " ", why_match.group(1)).strip() if why_match else None,
}

part3 = re.search(r"## Part 3.+?\n(.+?)\n## Part 4", curriculum_txt, flags=re.DOTALL).group(1)
prof_blocks = re.split(r"\n\*\*(\d+)\. (.+?)\*\*\n", part3)[1:]
for i in range(0, len(prof_blocks), 3):
    num, name, body = int(prof_blocks[i]), prof_blocks[i + 1].strip(), prof_blocks[i + 2]
    real_problem = re.search(r"- Real problem:\s*(.+)", body).group(1).strip()
    bq_block = re.search(r"- Business questions:\n((?:\s+- .+\n?)+)", body).group(1)
    biz_questions = [q.strip() for q in re.findall(r"^\s+- (.+)$", bq_block, flags=re.MULTILINE)]
    # Some entries tag more than one module inside one backtick span, e.g.
    # `[M1] [M6]` -> capture all module codes present.
    dk = re.search(r"- Don't know:\s*(.+?)\s*`((?:\[M\d+\]\s*)+)`", body)
    dk_modules = re.findall(r"M\d+", dk.group(2))
    cat = find_category("profession", num)
    cat["realProblem"] = real_problem
    cat["businessQuestions"] = biz_questions
    cat["dontKnowFact"] = dk.group(1).strip()
    cat["dontKnowModule"] = dk_modules[0]
    cat["dontKnowModules"] = dk_modules
    assert len(biz_questions) == 4, f"profession {num} {name} got {len(biz_questions)} q"

# ---------------------------------------------------------------------------
# 5. Sanity: every category has its expected fields populated
# ---------------------------------------------------------------------------
missing = []
for cid, c in categories.items():
    if c["section"] == "skill" and not c["skillQuestions"]:
        missing.append(cid)
    if c["section"] == "business" and not c["businessQA"]:
        missing.append(cid)
    if c["section"] == "profession" and not c["realProblem"]:
        missing.append(cid)
if missing:
    print("WARNING - missing data for:", missing)
else:
    print("OK: all 60 categories fully populated.")

out = {
    "modules": modules,
    "taxReform": tax_reform,
    "categories": list(categories.values()),
}

with open("/home/claude/resource_categories.json", "w", encoding="utf-8") as f:
    json.dump(out, f, indent=2, ensure_ascii=False)

print(f"Wrote {len(categories)} categories, {len(modules)} modules.")
print(f"Skills with questions: {sum(1 for c in categories.values() if c['skillQuestions'])}")
print(f"Businesses with Q&A:   {sum(1 for c in categories.values() if c['businessQA'])}")
print(f"Professions filled:    {sum(1 for c in categories.values() if c['realProblem'])}")
