# Settlements Scraper

Scrapes [ClassAction.org/settlements](https://www.classaction.org/settlements) and upserts rows into your Supabase `settlements` table. The schema matches the Claims iOS app (`Claims/Models/Settlement.swift`).

## Run locally

1. Create a virtualenv and install deps:
   ```bash
   cd scraper
   python3 -m venv .venv
   source .venv/bin/activate   # Windows: .venv\Scripts\activate
   pip install -r requirements.txt
   ```

2. Set Supabase credentials (use the **service_role** key so the script can insert/update):
   ```bash
   export SUPABASE_URL="https://YOUR_PROJECT.supabase.co"
   export SUPABASE_SERVICE_KEY="your_service_role_key"
   ```

3. Run:
   ```bash
   python scrape.py
   ```

Get `SUPABASE_URL` and `SUPABASE_SERVICE_KEY` from [Supabase Dashboard](https://supabase.com/dashboard) → your project → **Settings** → **API** (Project URL and `service_role` secret).

## Run automatically (GitHub Actions)

The workflow [../.github/workflows/scrape.yml](../.github/workflows/scrape.yml) runs the scraper **twice per day** (6:00 and 18:00 UTC) and on manual trigger.

1. Push this repo to GitHub.
2. In the repo: **Settings** → **Secrets and variables** → **Actions**.
3. Add secrets:
   - `SUPABASE_URL` — your Supabase project URL (e.g. `https://xxx.supabase.co`).
   - `SUPABASE_SERVICE_KEY` — the **service_role** key (not the anon key).
4. The workflow will run on schedule. You can also run it manually: **Actions** → **Scrape Settlements** → **Run workflow**.

## Supabase table

The `settlements` table must exist and should have a **unique constraint on `source_id`** so `upsert(..., on_conflict="source_id")` works. If your table uses a different unique key, change the `on_conflict` argument in `scrape.py` to match.
