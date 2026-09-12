-- Water intake tracker.
-- Logs amount-per-drink with a timestamp; per-user settings live on profiles.

-- ---------------------------------------------------------------------------
-- profiles: water settings (goal + display unit + quick-add presets in ml)
-- ---------------------------------------------------------------------------

alter table public.profiles
  add column if not exists water_goal_ml       integer not null default 2500,
  add column if not exists water_unit          text    not null default 'ml',
  add column if not exists water_quick_amounts integer[] not null default '{200,400,800}';

alter table public.profiles
  add constraint profiles_water_goal_ml_check       check (water_goal_ml > 0 and water_goal_ml <= 10000),
  add constraint profiles_water_unit_check          check (water_unit in ('ml', 'oz')),
  add constraint profiles_water_quick_amounts_check check (cardinality(water_quick_amounts) between 1 and 6 and 0 < all (water_quick_amounts));

-- ---------------------------------------------------------------------------
-- water_intake_logs
-- ---------------------------------------------------------------------------

create table if not exists public.water_intake_logs (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references auth.users (id) on delete cascade,
  amount_ml  integer not null check (amount_ml > 0 and amount_ml <= 5000),
  drank_at   timestamptz not null default now(),
  note       text,
  created_at timestamptz not null default now()
);

alter table public.water_intake_logs enable row level security;

create policy "water_intake_logs: read own"   on public.water_intake_logs for select using (auth.uid() = user_id);
create policy "water_intake_logs: insert own" on public.water_intake_logs for insert with check (auth.uid() = user_id);
create policy "water_intake_logs: update own" on public.water_intake_logs for update using (auth.uid() = user_id);
create policy "water_intake_logs: delete own" on public.water_intake_logs for delete using (auth.uid() = user_id);

create trigger water_intake_logs_set_user
before insert on public.water_intake_logs
for each row execute function public.set_current_user();

create index if not exists water_intake_logs_user_drank_idx on public.water_intake_logs (user_id, drank_at desc);