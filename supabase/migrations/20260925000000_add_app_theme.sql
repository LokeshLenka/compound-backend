-- Add app_theme preference for Compound vs Solo Leveling themes
alter table public.profiles
  add column if not exists app_theme text not null default 'solo' check (app_theme in ('compound','solo'));
