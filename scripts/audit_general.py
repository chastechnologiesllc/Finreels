from __future__ import annotations

import json
import re
from collections import Counter
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]
path = ROOT / "assets" / "data" / "resources" / "_general.json"
data = json.loads(path.read_text(encoding="utf-8"))
books = data.get("books", [])
domains = Counter(urlparse(str(book.get("freeSourceUrl", ""))).netloc.lower() for book in books)
sources = Counter("Project Gutenberg" if "gutenberg.org" in str(book.get("freeSourceUrl", "")) else "Open Textbook Library/other" for book in books)
keywords = {
    "psychology & human behavior": r"psych|behavior|behaviour|mind|mental|soul|habit|character",
    "personal finance & economics": r"money|finance|econom|business|wealth|bank|trade|commerce|credit|currency|market|price",
    "health & wellbeing": r"health|medicine|medical|nutrition|diet|hygiene|exercise|health",
    "communication & language": r"language|english|writing|speech|communication|rhetoric|grammar",
    "philosophy & ethics": r"philosoph|ethic|morality|virtue|logic",
    "history & society": r"history|society|social|politic|war|government|civilization|travel",
    "science & technical": r"science|physics|chemistry|biology|mathemat|engineering|technology|astronomy",
    "arts & creativity": r"art|music|photograph|design|fashion|cook|craft",
}
topics = Counter()
for book in books:
    text = f"{book.get('title','')} {book.get('freeSourceNote','')} {book.get('verificationMethod','')}"
    for topic, pattern in keywords.items():
        if re.search(pattern, text, re.I):
            topics[topic] += 1
print(json.dumps({
    "books": len(books),
    "sources": dict(sources),
    "topDomains": domains.most_common(15),
    "topicMatches": dict(topics),
}, ensure_ascii=False, indent=2))
