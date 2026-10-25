# Kamp-s360

## Automatic official announcements

The workflow collects announcements from Bingöl University and Student Affairs, including source excerpts and official attachment links. It publishes successful sources to the existing Supabase cache every two hours (at minute 23, UTC). A failed source does not clear its stored announcements.

### One-time setup

1. Open **Settings → Secrets and variables → Actions → New repository secret**.
2. Name: `NEWS_INGEST_TOKEN`. Value: the same private token already configured in Supabase Edge Function secrets. Do not put the token in code or issues.
3. Open **Actions → Update campus announcements → Run workflow** on `main`.
4. Confirm the `publish` job prints `PUBLISHED`. The app reads the updated cache through the existing `official-news` function.

No Supabase service-role key is required in GitHub. The public endpoint is configured in the workflow. JWT verification for the existing function must remain disabled; publishing uses the custom ingest token.

Pushes run parser tests and a source connectivity check without publishing. Scheduled and manual runs test, collect details, and publish. A successful source check alone does not confirm publication.

### Local use

Python 3.12 or later, standard library only:

```powershell
python -m unittest discover -s tests -v
python scripts/collect_news.py
python scripts/collect_news.py --publish
```

Local publishing prompts for the token without displaying it. Preview output is written to `news_preview.json` and is ignored by Git.

GitHub schedules may be delayed. For public repositories GitHub can disable scheduled workflows after 60 days without repository activity; re-enable the workflow under Actions if needed.
