#!/usr/bin/env python3
"""
Scrapes ClassAction.org settlements page and inserts into Supabase settlements table.
Only adds NEW settlements that don't already exist in the database.
"""
import os
import re
import uuid
from datetime import date, datetime, timezone

import requests
from bs4 import BeautifulSoup
from supabase import create_client

SETTLEMENTS_URL = "https://www.classaction.org/settlements"
BASE_URL = "https://www.classaction.org"
USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"

# Known major brands for "Picked for You"
MAJOR_BRANDS = {
    "23andme", "amazon", "google", "facebook", "meta", "apple", "microsoft",
    "capital one", "wells fargo", "robinhood", "doordash", "uber", "lyft",
    "target", "walmart", "nissan", "toyota", "ford", "hyundai", "kia",
    "kaiser", "theranos", "peloton",
}


def fetch_page() -> str:
    """Fetch the settlements page HTML."""
    resp = requests.get(SETTLEMENTS_URL, headers={"User-Agent": USER_AGENT}, timeout=30)
    resp.raise_for_status()
    return resp.text


def parse_settlements(html: str) -> list[dict]:
    """
    Parse settlements from ClassAction.org HTML.
    Each settlement card has a data-name attribute on an <a> tag.
    We walk up to the parent that contains just this card's content.
    """
    soup = BeautifulSoup(html, "html.parser")
    settlements = []
    seen_slugs = set()

    # Find all elements with data-name (these are settlement title links)
    for el in soup.find_all(attrs={"data-name": True}):
        data_name = el.get("data-name", "").strip()
        data_slug = el.get("data-slug", "").strip().lower()
        claim_url = el.get("href", "").strip()
        
        if not data_name or not claim_url:
            continue
        if not data_slug:
            data_slug = re.sub(r'[^a-z0-9]+', '-', data_name.lower()).strip('-')
        if data_slug in seen_slugs:
            continue
        
        # Walk up to find the card container (level 3-4 from the <a> tag)
        # The right level has 200-500 chars of text and contains the card info
        card = el
        card_text = ""
        for level in range(8):
            card = card.parent
            if card is None:
                break
            text = card.get_text(separator=" ", strip=True)
            
            # Good card: has reasonable length and contains this settlement's info
            # Bad card: too short (just title) or too long (multiple settlements)
            if 150 < len(text) < 800:
                # Make sure it contains settlement-specific keywords
                if "Payout" in text and "Deadline" in text:
                    card_text = text
                    break
            elif len(text) > 800:
                # Went too far, use previous level's text if we had one
                break
        
        if not card_text:
            # Fallback: just use what we can find
            card = el
            for _ in range(5):
                card = card.parent
                if card is None:
                    break
            if card:
                card_text = card.get_text(separator=" ", strip=True)
        
        # Parse the card text
        settlement = parse_card_text(data_name, data_slug, claim_url, card_text)
        if settlement:
            settlements.append(settlement)
            seen_slugs.add(data_slug)
    
    return settlements


def parse_card_text(name: str, slug: str, claim_url: str, text: str) -> dict | None:
    """Parse a single settlement card's text into a data dict."""
    
    # Full name
    full_name = name.strip()
    if "Settlement" not in full_name:
        full_name = f"{name} Class Action Settlement"
    
    # Company name (before " - " or full name)
    company_name = name.split(" - ")[0].strip() if " - " in name else name.strip()
    
    # Payout parsing
    payout_min, payout_max = None, None
    payout_display = "Varies"
    
    # Range: $100 - $10,000
    range_match = re.search(r'\$\s*([\d,]+)\s*[-–]\s*\$\s*([\d,]+)', text)
    if range_match:
        payout_min = float(range_match.group(1).replace(",", ""))
        payout_max = float(range_match.group(2).replace(",", ""))
        payout_display = f"${int(payout_min):,} - ${int(payout_max):,}"
    else:
        # Up to $X
        upto_match = re.search(r'Up\s+to\s+\$\s*([\d,]+)', text, re.IGNORECASE)
        if upto_match:
            payout_max = float(upto_match.group(1).replace(",", ""))
            payout_display = f"Up to ${int(payout_max):,}"
        else:
            # Single: $X or $X+
            single_match = re.search(r'Payout\s*\$\s*([\d,]+)\s*(\+)?', text, re.IGNORECASE)
            if single_match:
                val = float(single_match.group(1).replace(",", ""))
                if single_match.group(2):
                    payout_min = val
                    payout_display = f"${int(val):,}+"
                else:
                    payout_min = payout_max = val
                    payout_display = f"${int(val):,}"
    
    # Deadline: M/D/YY or M/D/YYYY
    deadline_str = None
    days_left = None
    deadline_match = re.search(r'Deadline\s*(\d{1,2}/\d{1,2}/\d{2,4})', text, re.IGNORECASE)
    if deadline_match:
        try:
            date_text = deadline_match.group(1)
            if len(date_text.split("/")[-1]) == 2:
                dt = datetime.strptime(date_text, "%m/%d/%y")
            else:
                dt = datetime.strptime(date_text, "%m/%d/%Y")
            deadline_str = dt.strftime("%Y-%m-%d")
            days_left = max(0, (dt.date() - date.today()).days)
        except ValueError:
            pass
    
    # Days left fallback
    if days_left is None:
        days_match = re.search(r'<?\s*(\d+)\s*Days?\s*Left', text, re.IGNORECASE)
        if days_match:
            days_left = int(days_match.group(1))
    
    # Proof required
    requires_proof = None
    if re.search(r'Proof\s*Required\?\s*No', text, re.IGNORECASE):
        requires_proof = False
    elif re.search(r'Proof\s*Required\?\s*Yes', text, re.IGNORECASE):
        requires_proof = True
    
    # Description (eligibility text)
    description = None
    patterns = [
        r'(You may be (?:included|covered|eligible|able)[^.]+\.)',
        r'(This settlement covers[^.]+\.)',
        r'(If you [^.]+(?:you may|this settlement)[^.]+\.)',
        r'(Class members are[^.]+\.)',
    ]
    for pattern in patterns:
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            description = match.group(1).strip()
            break
    
    # Generate stable ID
    stable_id = str(uuid.uuid5(uuid.NAMESPACE_DNS, f"classaction.org/{slug}"))
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    
    return {
        "id": stable_id,
        "source_id": slug,
        "name": full_name,
        "company_name": company_name,
        "payout_min": payout_min,
        "payout_max": payout_max,
        "deadline": deadline_str,
        "days_left": days_left,
        "description": description,
        "requires_proof": requires_proof,
        "claim_url": claim_url,
        "source_url": SETTLEMENTS_URL,
        "is_featured": None,
        "logo_url": None,
        "created_at": now,
        "updated_at": now,
    }


def normalize_for_comparison(s: str) -> str:
    """Normalize a string for comparison."""
    if not s:
        return ""
    s = s.lower()
    s = re.sub(r'[^a-z0-9\s]', '', s)
    s = re.sub(r'\s+', ' ', s).strip()
    return s


def main() -> None:
    supabase_url = os.environ.get("SUPABASE_URL")
    supabase_key = os.environ.get("SUPABASE_SERVICE_KEY")
    if not supabase_url or not supabase_key:
        raise SystemExit("Set SUPABASE_URL and SUPABASE_SERVICE_KEY environment variables.")

    try:
        client = create_client(supabase_url, supabase_key)

        # Fetch existing settlements
        print("Fetching existing settlements from Supabase...")
        existing = client.table("settlements").select("name, company_name, claim_url").execute()
        
        existing_names = set()
        existing_urls = set()
        for row in existing.data:
            if row.get("name"):
                existing_names.add(normalize_for_comparison(row["name"]))
            if row.get("company_name"):
                existing_names.add(normalize_for_comparison(row["company_name"]))
            if row.get("claim_url"):
                existing_urls.add(row["claim_url"].lower().rstrip("/"))
        
        print(f"Found {len(existing.data)} existing settlements.")

        # Scrape ClassAction.org
        print("Fetching settlements from ClassAction.org...")
        html = fetch_page()
        scraped = parse_settlements(html)
        print(f"Scraped {len(scraped)} settlements from website.")

        if not scraped:
            print("WARNING: No settlements parsed. Check page structure.")
            return

        # Filter to NEW only
        new_settlements = []
        for s in scraped:
            name_norm = normalize_for_comparison(s["name"])
            company_norm = normalize_for_comparison(s["company_name"])
            url_norm = (s.get("claim_url") or "").lower().rstrip("/")
            
            if name_norm in existing_names:
                continue
            if company_norm in existing_names:
                continue
            if url_norm and url_norm in existing_urls:
                continue
            
            new_settlements.append(s)

        print(f"Found {len(new_settlements)} NEW settlements to add.")

        if not new_settlements:
            print("No new settlements. Database is up to date.")
            return

        # Insert new settlements
        result = client.table("settlements").insert(new_settlements).execute()
        print(f"Successfully inserted {len(new_settlements)} new settlements.")
        
        for s in new_settlements:
            print(f"  + {s['company_name']}: {s['claim_url']}")

    except Exception as e:
        print(f"ERROR: {e}")
        import traceback
        traceback.print_exc()
        raise SystemExit(1)


if __name__ == "__main__":
    main()
