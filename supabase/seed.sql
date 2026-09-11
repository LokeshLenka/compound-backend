-- Demo data for local development.
-- Creates a demo user (demo@personalhub.local / demo123456) + realistic data.
-- Runs automatically on `supabase db reset`. For cloud, run scripts/seed.mjs instead.

do $$
declare
  demo_user uuid := '11111111-1111-1111-1111-111111111111';
  h1 uuid := '22222222-2222-2222-2222-222222222201';
  h2 uuid := '22222222-2222-2222-2222-222222222202';
  h3 uuid := '22222222-2222-2222-2222-222222222203';
  h4 uuid := '22222222-2222-2222-2222-222222222204';
  p1 uuid := '33333333-3333-3333-3333-333333333301';
  p2 uuid := '33333333-3333-3333-3333-333333333302';
begin
  -- demo auth user ------------------------------------------------------------
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, invited_at, confirmation_token, recovery_token,
    email_change, email_change_token_new, email_change_token_current,
    email_change_confirm_status, phone, phone_change, phone_change_token,
    reauthentication_token, is_sso_user, is_anonymous,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at
  ) values (
    '00000000-0000-0000-0000-000000000000', demo_user, 'authenticated', 'authenticated',
    'demo@personalhub.local', crypt('demo123456', gen_salt('bf')),
    now(), now(), '', '',
    '', '', '', 0,
    '', '', '',
    '', false, false,
    '{"provider":"email","providers":["email"]}', '{"full_name":"Demo Dev"}',
    now(), now()
  ) on conflict (id) do nothing;

  insert into auth.identities (
    provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at
  ) values (
    'demo@personalhub.local', demo_user, format('{"sub":"%s","email":"demo@personalhub.local"}', demo_user)::jsonb,
    'email', now(), now(), now()
  ) on conflict (provider_id, provider) do nothing;

  -- habits -------------------------------------------------------------------
  insert into public.habits (id, user_id, name, emoji, color, frequency_type, frequency_value, sort_order) values
    (h1, demo_user, 'Drink water', '💧', 'sky', 'daily', '{}', 1),
    (h2, demo_user, 'Gym',         '🏋️', 'red',   'weekly', '{"times":3}', 2),
    (h3, demo_user, 'Code 30 min', '💻', 'violet','weekdays', '{"days":[1,2,3,4,5]}', 3),
    (h4, demo_user, 'Read',        '📚', 'amber', 'every_n_days', '{"every":2}', 4)
  on conflict (id) do nothing;

  -- last 30 days of logs for h1 (daily)
  insert into public.habit_logs (habit_id, user_id, log_date)
  select h1, demo_user, (current_date - (29 - gs)::int)
  from generate_series(0, 29) gs
  where gs in (0,1,2,3,4,5,7,8,10,12,13,14,16,17,19,20,22,24,25,27,29)
  on conflict (habit_id, log_date) do nothing;

  insert into public.habit_logs (habit_id, user_id, log_date) values
    (h2, demo_user, current_date - interval '1 day'),
    (h2, demo_user, current_date - interval '4 days'),
    (h2, demo_user, current_date - interval '8 days'),
    (h3, demo_user, current_date - interval '1 day'),
    (h3, demo_user, current_date - interval '2 days'),
    (h3, demo_user, current_date - interval '3 days')
  on conflict (habit_id, log_date) do nothing;

  -- projects -----------------------------------------------------------------
  insert into public.projects (id, user_id, name, color) values
    (p1, demo_user, 'Personal', 'sky'),
    (p2, demo_user, 'Work', 'violet')
  on conflict (id) do nothing;

  -- tasks --------------------------------------------------------------------
  insert into public.tasks (user_id, project_id, title, notes, priority, status, due_date, tags, sort_order) values
    (demo_user, p2, 'Finish redesign proposal', 'Draft for review', 'high', 'in_progress', now() + interval '1 day',  array['work','design'], 1),
    (demo_user, p1, 'Buy groceries', 'Milk, eggs, bread', 'medium', 'todo', now() + interval '2 days', array['home'], 2),
    (demo_user, null, 'Book dentist', null, 'low', 'todo', null, array['health'], 3),
    (demo_user, p1, 'Call mom', null, 'medium', 'done', now() - interval '1 day', array['family'], 4);

  -- notes --------------------------------------------------------------------
  insert into public.notes (user_id, title, content, is_pinned, tags) values
    (demo_user, 'Welcome to Personal Hub', '# Hello 👋\n\nThis is your **Personal Hub**. Use the sidebar to manage:\n\n- **Habits** — check off daily, track streaks\n- **Tasks** — projects, priorities, kanban\n- **Notes** — markdown notes with search\n- **Diary** — one entry per day with mood\n\nEverything is private to your account.\n', true, array['intro']),
    (demo_user, 'Weekend ideas', '## Ideas\n- Hike the ridge trail\n- Visit the market\n- Try a new coffee place\n', false, array['ideas']);

  -- diary --------------------------------------------------------------------
  insert into public.diary_entries (user_id, entry_date, title, content, mood, weather) values
    (demo_user, current_date, 'A new start', 'Today I set up my Personal Hub. Excited to build habits and capture thoughts.\n\n> Small steps every day.', 4, 'sunny'),
    (demo_user, current_date - 1, 'Quiet day', 'Nothing much happened. Read half of a book.', 3, 'cloudy'),
    (demo_user, current_date - 2, 'Hectic', 'Too many meetings today. Need to plan better.', 2, 'rainy');
end $$;