# Personal Hub — Backend (Supabase)

The data layer & API for Personal Hub. No app server code — everything is provided by
Supabase (Postgres, Auth, generated REST/GraphQL APIs, RLS).

## Layout
- `supabase/config.toml` — local dev stack config
- `supabase/migrations/` — versioned SQL (schema, RLS, triggers, indexes)
- `supabase/functions/` — edge functions (e.g. `delete-account`)
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
supabase link --project-ref <your-project-ref>   # dlcivqevddnyltudhjnk for the MCP-linked project
supabase db push                                  # apply migrations to cloud
supabase functions deploy delete-account          # required for Settings → Delete account
```
Then the frontend needs (in Vercel):
`NEXT_PUBLIC_SUPABASE_URL` = `https://<ref>.supabase.co`,
`NEXT_PUBLIC_SUPABASE_ANON_KEY` = project anon key (Dashboard → Settings → API).
The `SUPABASE_SERVICE_ROLE_KEY` is only for seeding/admin/E2E helpers — never a `NEXT_PUBLIC_`.

> In cloud Auth settings, enable email confirmation (the frontend handles it); the
> local stack has it off for the demo user.

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