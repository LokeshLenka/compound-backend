-- Personal Hub core schema
-- All tables are RLS-restricted to auth.uid(); multi-user ready by design.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- helper functions
-- ---------------------------------------------------------------------------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end
$$;

-- stamp a row with the calling user id (habits, tasks, notes, projects, diary)
create or replace function public.set_current_user()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  if new.user_id is null then
    new.user_id := auth.uid();
  end if;
  return new;
end
$$;

-- create profile on signup
create or replace function public.handle_new_user()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', split_part(new.email, '@', 1), 'User')
  );
  return new;
end
$$;

-- ---------------------------------------------------------------------------
-- profiles
-- ---------------------------------------------------------------------------

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null default '',
  avatar_url text,
  theme text default 'system',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "profiles: read own"    on public.profiles for select using (auth.uid() = id);
create policy "profiles: update own"  on public.profiles for update using (auth.uid() = id);
create policy "profiles: insert own"  on public.profiles for insert with check (auth.uid() = id);

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- habits
-- ---------------------------------------------------------------------------

create table if not exists public.habits (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  emoji text default '⭐',
  color text default 'var(--color-primary)',
  -- daily | weekdays | weekly | every_n_days
  frequency_type text not null default 'daily',
  -- weekdays -> iso weekdays [1..7] ; weekly -> times per week ; every_n_days -> interval
  frequency_value jsonb default '{}'::jsonb,
  archived boolean not null default false,
  archived_at timestamptz,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.habits enable row level security;

create policy "habits: read own"   on public.habits for select using (auth.uid() = user_id);
create policy "habits: insert own" on public.habits for insert with check (auth.uid() = user_id);
create policy "habits: update own" on public.habits for update using (auth.uid() = user_id);
create policy "habits: delete own" on public.habits for delete using (auth.uid() = user_id);

create trigger habits_set_user
before insert on public.habits
for each row execute function public.set_current_user();

create trigger habits_set_updated_at
before update on public.habits
for each row execute function public.set_updated_at();

create index if not exists habits_user_idx on public.habits (user_id, archived, sort_order);

-- ---------------------------------------------------------------------------
-- habit_logs
-- ---------------------------------------------------------------------------

create table if not exists public.habit_logs (
  id uuid primary key default gen_random_uuid(),
  habit_id uuid not null references public.habits (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  log_date date not null,
  note text,
  created_at timestamptz not null default now(),
  unique (habit_id, log_date)
);

alter table public.habit_logs enable row level security;

-- derive user from owning habit so a user can never log someone else's habit
create or replace function public.set_habit_log_user()
returns trigger
language plpgsql security definer set search_path = public
as $$
begin
  new.user_id := (select h.user_id from public.habits h where h.id = new.habit_id);
  return new;
end
$$;

create trigger habit_logs_set_user
before insert or update on public.habit_logs
for each row execute function public.set_habit_log_user();

create policy "habit_logs: read own"   on public.habit_logs for select using (auth.uid() = user_id);
create policy "habit_logs: insert own" on public.habit_logs for insert with check (auth.uid() = user_id);
create policy "habit_logs: update own" on public.habit_logs for update using (auth.uid() = user_id);
create policy "habit_logs: delete own" on public.habit_logs for delete using (auth.uid() = user_id);

create index if not exists habit_logs_user_date_idx on public.habit_logs (user_id, log_date desc);
create index if not exists habit_logs_habit_date_idx on public.habit_logs (habit_id, log_date);

-- ---------------------------------------------------------------------------
-- projects (optional grouping for tasks)
-- ---------------------------------------------------------------------------

create table if not exists public.projects (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  color text default 'hsl(var(--primary))',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.projects enable row level security;

create policy "projects: read own"   on public.projects for select using (auth.uid() = user_id);
create policy "projects: insert own" on public.projects for insert with check (auth.uid() = user_id);
create policy "projects: update own" on public.projects for update using (auth.uid() = user_id);
create policy "projects: delete own" on public.projects for delete using (auth.uid() = user_id);

create trigger projects_set_user
before insert on public.projects
for each row execute function public.set_current_user();

create trigger projects_set_updated_at
before update on public.projects
for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- tasks
-- ---------------------------------------------------------------------------

create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  project_id uuid references public.projects (id) on delete set null,
  title text not null,
  notes text,
  priority text not null default 'medium' check (priority in ('low', 'medium', 'high', 'urgent')),
  status text not null default 'todo' check (status in ('todo', 'in_progress', 'done', 'archived')),
  due_date timestamptz,
  tags text[] not null default '{}',
  completed_at timestamptz,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.tasks enable row level security;

create policy "tasks: read own"   on public.tasks for select using (auth.uid() = user_id);
create policy "tasks: insert own" on public.tasks for insert with check (auth.uid() = user_id);
create policy "tasks: update own" on public.tasks for update using (auth.uid() = user_id);
create policy "tasks: delete own" on public.tasks for delete using (auth.uid() = user_id);

create trigger tasks_set_user
before insert on public.tasks
for each row execute function public.set_current_user();

create trigger tasks_set_updated_at
before update on public.tasks
for each row execute function public.set_updated_at();

create index if not exists tasks_user_status_idx on public.tasks (user_id, status);
create index if not exists tasks_user_due_idx   on public.tasks (user_id, due_date);
create index if not exists tasks_tags_idx       on public.tasks using gin (tags);

-- ---------------------------------------------------------------------------
-- notes
-- ---------------------------------------------------------------------------

create table if not exists public.notes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  title text not null default 'Untitled',
  content text default '',
  is_pinned boolean not null default false,
  archived boolean not null default false,
  tags text[] not null default '{}',
  search_vector tsvector generated always as (
    setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(content, '')), 'B')
  ) stored,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.notes enable row level security;

create policy "notes: read own"   on public.notes for select using (auth.uid() = user_id);
create policy "notes: insert own" on public.notes for insert with check (auth.uid() = user_id);
create policy "notes: update own" on public.notes for update using (auth.uid() = user_id);
create policy "notes: delete own" on public.notes for delete using (auth.uid() = user_id);

create trigger notes_set_user
before insert on public.notes
for each row execute function public.set_current_user();

create trigger notes_set_updated_at
before update on public.notes
for each row execute function public.set_updated_at();

create index if not exists notes_user_idx       on public.notes (user_id, is_pinned, updated_at desc);
create index if not exists notes_search_idx     on public.notes using gin (search_vector);
create index if not exists notes_tags_idx       on public.notes using gin (tags);

-- ---------------------------------------------------------------------------
-- diary_entries (one entry per user per day)
-- ---------------------------------------------------------------------------

create table if not exists public.diary_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  entry_date date not null,
  title text,
  content text default '',
  mood integer check (mood between 1 and 5),
  weather text,
  tags text[] not null default '{}',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, entry_date)
);

alter table public.diary_entries enable row level security;

create policy "diary_entries: read own"   on public.diary_entries for select using (auth.uid() = user_id);
create policy "diary_entries: insert own" on public.diary_entries for insert with check (auth.uid() = user_id);
create policy "diary_entries: update own" on public.diary_entries for update using (auth.uid() = user_id);
create policy "diary_entries: delete own" on public.diary_entries for delete using (auth.uid() = user_id);

create trigger diary_entries_set_user
before insert on public.diary_entries
for each row execute function public.set_current_user();

create trigger diary_entries_set_updated_at
before update on public.diary_entries
for each row execute function public.set_updated_at();

create index if not exists diary_entries_user_date_idx on public.diary_entries (user_id, entry_date desc);