-- Hardening: pin search_path on set_updated_at, cover FK indexes.
-- (Advisor fixes from the initial cloud deploy.)

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end
$$;

create index if not exists projects_user_idx on public.projects (user_id);
create index if not exists tasks_project_user_idx on public.tasks (project_id, user_id);