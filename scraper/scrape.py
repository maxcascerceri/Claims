#!/usr/bin/env python3
"""
Scrapes ClassAction.org settlements page and upserts into Supabase settlements table.
Matches the schema expected by the Claims iOS app (see Claims/Models/Settlement.swift).
Run: SUPABASE_URL=... SUPABASE_SERVICE_KEY=... python scrape.py
"""
import os
import re
import uuid
from datetime import date, datetime

import requests
from bs4 import BeautifulSoup
from supabase import create_client

SETTLEMENTS_URL = "https://www.classaction.org/settlements"
BASE_URL = "https://www.classaction.org"
USER_AGENT = "ClaimWise-Scraper/1.0 (Class Action Settlements)"

# Known major brands for "Picked for You" in the app
MAJOR_BRANDS = {
    "23andme", "amazon", "google", "facebook", "meta", "apple", "microsoft",
    "capital one", "wells fargo", "robinhood", "doordash", "uber", "lyft",
    "target", "walmart", "nissan", "toyota", "ford", "hyundai", "kia",
    "kaiser", "theranos", "peloton",
}


def slug_from_name(name: str) -> str:
    """Build slug from settlement name (matches Swift slugFromName)."""
    s = name.lower().strip()
    for suffix in [" class action settlement", " - class action settlement"]:
        if s.endswith(suffix):
            s = s[: -len(suffix)]
    s = re.sub(r"\s+", " ", s)
    s = s.replace(" - ", "-").replace(" ", "-").replace("&", "and")
    return "".join(c for c in s if c.isalnum() or c == "-").strip("-")


def company_from_name(name: str) -> str:
    """Extract company name (before ' - ' or full name)."""
    if " - " in name:
        return name.split(" - ")[0].strip()
    return name.strip()


def parse_payout(text: str) -> tuple[float | None, float | None, str]:
    """Parse payout text to min, max, and display string. Returns (min, max, display)."""
    if not text or not text.strip():
        return None, None, "Varies"
    text = text.strip()
    # e.g. "$100 - $10,000", "Up to $5,000", "$10+", "Varies", "$18+"
    text_clean = re.sub(r"[\s,]", "", text)
    display = text.strip()
    min_val, max_val = None, None
    # Range: $100-$10000 or $100 - $10000
    range_m = re.search(r"\$?(\d+)\s*-\s*\$?(\d+)", text_clean, re.IGNORECASE)
    if range_m:
        min_val = float(range_m.group(1))
        max_val = float(range_m.group(2))
        return min_val, max_val, display
    # Single: $100 or Up to $5000
    single_m = re.search(r"(?:up\s*to\s*)?\$?(\d+)", text_clean, re.IGNORECASE)
    if single_m:
        val = float(single_m.group(1))
        if "up to" in text.lower() or "max" in text.lower():
            return 0.0, val, display
        return val, val, display
    # Plus: $10+
    plus_m = re.search(r"\$?(\d+)\s*\+", text_clean, re.IGNORECASE)
    if plus_m:
        min_val = float(plus_m.group(1))
        return min_val, None, display
    return None, None, display


def parse_deadline_and_days(text: str) -> tuple[str | None, int | None]:
    """Parse deadline line (e.g. 'Deadline 2/17/26') and days left. Returns (yyyy-MM-dd, days_left)."""
    if not text:
        return None, None
    # Deadline M/D/YY or M/D/YYYY
    deadline_m = re.search(r"deadline\s*(\d{1,2}/\d{1,2}/\d{2,4})", text, re.IGNORECASE)
    date_str = None
    if deadline_m:
        try:
            dt = datetime.strptime(deadline_m.group(1), "%m/%d/%y")
            date_str = dt.strftime("%Y-%m-%d")
        except ValueError:
            try:
                dt = datetime.strptime(deadline_m.group(1), "%m/%d/%Y")
                date_str = dt.strftime("%Y-%m-%d")
            except ValueError:
                pass
    # Days: "20 Days Left" or "< 7 Days Left"
    days_left = None
    days_m = re.search(r"(?:<\s*)?(\d+)\s*Days?\s*Left", text, re.IGNORECASE)
    if days_m:
        days_left = int(days_m.group(1))
    if date_str and days_left is None:
        try:
            d = datetime.strptime(date_str, "%Y-%m-%d").date()
            days_left = max(0, (d - date.today()).days)
        except Exception:
            pass
    return date_str, days_left


def parse_proof(text: str) -> bool | None:
    """Parse 'Proof Required? Yes/No/N/A' -> requires_proof (True = proof required)."""
    if not text:
        return None
    if re.search(r"proof\s*required\?\s*no", text, re.IGNORECASE):
        return False
    if re.search(r"proof\s*required\?\s*yes", text, re.IGNORECASE):
        return True
    if re.search(r"proof\s*required\?\s*n/a", text, re.IGNORECASE):
        return None
    return None


def infer_category(name: str) -> str:
    """Infer category from name: Privacy, Finance, Consumer."""
    n = name.lower()
    if "data breach" in n or "data privacy" in n or "privacy" in n:
        return "Privacy"
    if any(x in n for x in ["mortgage", "credit", "bank", "insurance", "401(k)", "investment", "robinhood", "order flow"]):
        return "Finance"
    return "Consumer"


def infer_case_type(name: str) -> str | None:
    """Infer case type from name."""
    n = name.lower()
    if "data breach" in n:
        return "Data Breach"
    if "ftc" in n or "ftc case" in n:
        return "FTC Case"
    if "antitrust" in n:
        return "Antitrust"
    if "privacy" in n:
        return "Data Privacy"
    return None


def _row_from_parsed(
    name: str,
    slug: str,
    claim_url: str,
    text: str,
    payout_display: str = "Varies",
    payout_min: float | None = None,
    payout_max: float | None = None,
    deadline_str: str | None = None,
    days_left: int | None = None,
    requires_proof: bool | None = None,
    eligibility: str | None = None,
) -> dict:
    """Build one Supabase row from parsed fields."""
    company_name = company_from_name(name)
    category = infer_category(name)
    case_type = infer_case_type(name)
    is_major = company_name.lower() in MAJOR_BRANDS or any(b in name.lower() for b in MAJOR_BRANDS)
    stable_id = str(uuid.uuid5(uuid.NAMESPACE_DNS, f"classaction.org/{slug}"))
    now = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
    return {
        "id": stable_id,
        "source_id": slug,
        "name": name,
        "company_name": company_name,
        "payout_min": payout_min,
        "payout_max": payout_max,
        "deadline": deadline_str,
        "days_left": days_left,
        "description": eligibility,
        "requires_proof": requires_proof,
        "claim_url": claim_url,
        "source_url": f"{BASE_URL}/settlements",
        "is_featured": None,
        "logo_url": None,
        "created_at": now,
        "updated_at": now,
        "case_type": case_type,
        "payout_display": payout_display,
        "about_text": eligibility,
        "eligibility": eligibility,
        "category": category,
        "is_major_brand": is_major,
    }


def _parse_card_text(text: str) -> tuple[str, float | None, float | None, str | None, int | None, bool | None, str | None]:
    """Extract payout_display, min, max, deadline, days_left, requires_proof, eligibility from card text."""
    payout_display = "Varies"
    payout_min, payout_max = None, None
    if "Payout" in text:
        payout_m = re.search(r"Payout\s*([^\n]+?)(?=Deadline|Proof|Required|$)", text, re.IGNORECASE | re.DOTALL)
        if payout_m:
            payout_min, payout_max, payout_display = parse_payout(payout_m.group(1))
    deadline_str, days_left = None, None
    if "Deadline" in text or "Days Left" in text:
        deadline_str, days_left = parse_deadline_and_days(text)
        if days_left is None and "Days Left" in text:
            days_m = re.search(r"(?:<\s*)?(\d+)\s*Days?\s*Left", text, re.IGNORECASE)
            if days_m:
                days_left = int(days_m.group(1))
    requires_proof = parse_proof(text)
    eligibility = None
    for sent in re.split(r"[.!?]\s+", text):
        if "you may be" in sent.lower() or "class members" in sent.lower():
            eligibility = sent.strip()
            break
    if not eligibility and len(text) > 200:
        eligibility = text[:500].strip()
    return payout_display, payout_min, payout_max, deadline_str, days_left, requires_proof, eligibility


def scrape_settlements() -> list[dict]:
    """Fetch ClassAction.org settlements page and return list of row dicts for Supabase."""
    resp = requests.get(SETTLEMENTS_URL, headers={"User-Agent": USER_AGENT}, timeout=30)
    resp.raise_for_status()
    html = resp.text
    soup = BeautifulSoup(html, "html.parser")

    rows = []
    seen_slugs = set()

    # Strategy 1: elements with data-name (ClassAction.org card attributes)
    for el in soup.find_all(attrs={"data-name": True}):
        data_name = el.get("data-name", "").strip()
        data_slug = (el.get("data-slug") or slug_from_name(data_name)).strip().lower()
        if not data_name or not data_slug or data_slug in seen_slugs:
            continue

        card = el
        for _ in range(8):
            card = card.parent
            if card is None:
                break
            text = card.get_text(separator=" ", strip=True)
            claim_url = None
            for a in card.find_all("a", href=True):
                href = (a.get("href") or "").strip()
                if href.startswith("http") and "classaction.org" not in href:
                    claim_url = href
                    break
            if not claim_url or len(text) < 50:
                continue
            payout_display, payout_min, payout_max, deadline_str, days_left, requires_proof, eligibility = _parse_card_text(text)
            name = data_name if "Settlement" in data_name else f"{data_name} Class Action Settlement"
            row = _row_from_parsed(
                name=name,
                slug=data_slug,
                claim_url=claim_url,
                text=text,
                payout_display=payout_display,
                payout_min=payout_min,
                payout_max=payout_max,
                deadline_str=deadline_str,
                days_left=days_left,
                requires_proof=requires_proof,
                eligibility=eligibility,
            )
            rows.append(row)
            seen_slugs.add(data_slug)
            break

    # Strategy 2: fallback — find h2/h3 with links to external URLs, treat as card title
    if len(rows) < 10:
        for tag in soup.find_all(["h2", "h3"]):
            for a in tag.find_all("a", href=True):
                href = a.get("href", "").strip()
                if not href.startswith("http") or "classaction.org" in href:
                    continue
                name = (a.get_text() or "").strip()
                if not name or len(name) < 5:
                    continue
                slug = slug_from_name(name)
                if slug in seen_slugs:
                    continue
                # Get following content until next h2/h3
                block = []
                for s in tag.next_siblings:
                    if hasattr(s, "name") and s.name in ("h2", "h3"):
                        break
                    if hasattr(s, "get_text"):
                        block.append(s.get_text(separator=" ", strip=True))
                    elif isinstance(s, str):
                        block.append(s.strip())
                text = " ".join(block)
                payout_display, payout_min, payout_max, deadline_str, days_left, requires_proof, eligibility = _parse_card_text(text)
                full_name = name if "Settlement" in name else f"{name} Class Action Settlement"
                row = _row_from_parsed(
                    name=full_name,
                    slug=slug,
                    claim_url=href,
                    text=text,
                    payout_display=payout_display,
                    payout_min=payout_min,
                    payout_max=payout_max,
                    deadline_str=deadline_str,
                    days_left=days_left,
                    requires_proof=requires_proof,
                    eligibility=eligibility,
                )
                rows.append(row)
                seen_slugs.add(slug)
                break

    return rows


def main() -> None:
    supabase_url = os.environ.get("SUPABASE_URL")
    supabase_key = os.environ.get("SUPABASE_SERVICE_KEY")
    if not supabase_url or not supabase_key:
        raise SystemExit("Set SUPABASE_URL and SUPABASE_SERVICE_KEY environment variables.")

    print("Fetching settlements from ClassAction.org...")
    rows = scrape_settlements()
    print(f"Scraped {len(rows)} settlements.")

    if not rows:
        print("No settlements parsed. Check page structure.")
        return

    client = create_client(supabase_url, supabase_key)
    # Upsert on conflict source_id (table must have unique on source_id)
    result = client.table("settlements").upsert(rows, on_conflict="source_id").execute()
    print(f"Upserted {len(rows)} rows into Supabase settlements.")


if __name__ == "__main__":
    main()
