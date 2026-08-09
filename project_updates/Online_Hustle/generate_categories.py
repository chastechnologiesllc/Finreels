#!/usr/bin/env python3
"""Generate online_hustle category entries for resource_categories.json"""

import json
from pathlib import Path
from hustle_definitions import HUSTLES

def make_business_qa(hustle):
    """Generate realistic businessQA style questions for an online hustle."""
    name = hustle["name"]
    return [
        {
            "question": "How does this hustle make money in the real world?",
            "answer": hustle["summary"]
        },
        {
            "question": "Who actually pays, and why?",
            "answer": "Individuals, small businesses, creators, or platforms that need the specific service or product the hustler provides."
        },
        {
            "question": "What problem does it solve for the customer?",
            "answer": f"Solves a time, skill, reach or convenience gap that the customer cannot or does not want to handle themselves in the context of {name.lower()}."
        },
        {
            "question": "How does it attract and keep customers?",
            "answer": "Consistent delivery, clear communication, visible results, social proof, and easy payment/onboarding paths that work for Nigerian clients (Paystack, bank transfer, OPay, etc.)."
        },
        {
            "question": "What tools, systems or platforms does it need to run and earn?",
            "answer": "Smartphone or laptop, reliable data, the relevant platforms (listed in the detailed PDF), a payment method that accepts Nigerian accounts or Payoneer/Grey/Wise, and basic record-keeping."
        },
        {
            "question": "How is the price/value set?",
            "answer": "Market rates for the skill/service in Nigeria and on global platforms; value-based pricing for higher-ticket work; volume + margin for product-based models."
        },
        {
            "question": "What turns it from a hustle into a real business?",
            "answer": "Repeat clients or residual income, documented processes, separation of personal and business money, and systems that can be handed to someone else."
        },
        {
            "question": "What assets can be built from it?",
            "answer": "Portfolio, audience/list, templates/processes, reputation, and in some cases intellectual property (courses, digital products, brand)."
        },
        {
            "question": "Where do people in this hustle commonly lose money or time?",
            "answer": "Undercharging, chasing free work, ignoring payment terms, platform dependency without own audience, and poor cash-flow tracking."
        },
        {
            "question": "How does it build long-term leverage?",
            "answer": "By converting one-off gigs into retainers, products, or systems, and by building an audience or network that compounds over time."
        },
    ]

def generate_categories():
    categories = []
    for h in HUSTLES:
        cat = {
            "id": h["id"],
            "section": "online_hustle",
            "number": h["number"],
            "name": h["name"],
            "skillQuestions": None,
            "businessQA": make_business_qa(h),
            "realProblem": None,
            "businessQuestions": None,
            "dontKnowFact": None,
            "dontKnowModule": None,
            "dontKnowModules": None,
            "searchKeywords": h["keywords"],
        }
        categories.append(cat)
    return categories

if __name__ == "__main__":
    cats = generate_categories()
    out = Path("/home/workdir/artifacts/Online_Hustle/project_updates/online_hustle_categories.json")
    out.write_text(json.dumps(cats, indent=2, ensure_ascii=False))
    print(f"Wrote {len(cats)} category entries to {out}")
    print("Sample IDs:")
    for c in cats[:3]:
        print(f"  {c['id']}")
