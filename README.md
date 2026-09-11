# Personal Hub — Backend (Supabase)

The data layer & API for Personal Hub. No app server code — everything is provided by
Supabase (Postgres, Auth, generated REST/GraphQL APIs, RLS).

## Layout
- `supabase/config.toml` — local dev stack config
- `supabase/migrations/` — versioned SQL (schema, RLS, triggers, indexes)
- `supabase/seed.sql` — demo data for local dev (auto-runs on `db reset`)
- `scripts/` — helpers (link/push to cloud)

## Local dev
Requirements: Docker, Supabase CLI (`npm i -g supabase`).

```bash
supabase start          # boots Postgres+Auth+API on http://127.0.0.1:54321
supabase db reset       # drop → reapply migrations → reseed
supabase status         # show keys/URLs (anon + service_role keys)
```

Demo login after reset: `demo@personalhub.local` / `demo123456`

## Cloud deploy
```bash
supabase login
supabase link --project-ref <your-project-ref>
supabase db push        # apply migrations to cloud
```
Then frontend needs: `SUPABASE_URL` = `https://<ref>.supabase.co`,
`SUPABASE_ANON_KEY` and `SUPABASE_SERVICE_ROLE_KEY` from Dashboard → Settings → API.

> In cloud Auth settings, disable email confirmation for the single-user personal
> app (or leave on; signup flow handles it).

## Schema (tables)
| table | purpose |
|---|---|
| `profiles` | user profile, auto-created on signup via trigger |
| `habits` / `habit_logs` | habits + daily check-in logs (unique habit+date) |
| `projects` | optional grouping for tasks |
| `tasks` | todos with priority/status/due/tags |
| `notes` | markdown notes, pinned, tags, full-text search vector |
| `diary_entries` | one daily entry (unique user+date), mood 1–5 |

All tables are RLS-restricted to `auth.uid()`. `user_id` is stamped automatically
(triggers) unless provided.

## Testing
The frontend repo runs Playwright E2E against this local stack. Keep this running:
`supabase start`.