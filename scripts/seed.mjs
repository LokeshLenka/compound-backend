#!/usr/bin/env node
/**
 * Seed demo data into a CLOUD Supabase project (local uses seed.sql at db reset).
 *
 * Usage:
 *   SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... node scripts/seed.mjs
 *
 * Requires the @supabase/supabase-js package: `npm i -D @supabase/supabase-js` (in backend repo)
 */
import { createClient } from '@supabase/supabase-js'

const url = process.env.SUPABASE_URL
const key = process.env.SUPABASE_SERVICE_ROLE_KEY
if (!url || !key) {
  console.error('Missing SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY')
  process.exit(1)
}

const sb = createClient(url, key, { auth: { autoRefreshToken: false, persistSession: false } })

async function main() {
  const email = 'demo@personalhub.local'
  const password = 'demo123456'

  const { data: existing, error: findErr } = await sb.auth.admin.listUsers({ page: 0, perPage: 200 })
  if (findErr) throw findErr
  const demo = existing.users.find((u) => u.email === email)

  let userId
  if (demo) {
    userId = demo.id
    console.log('demo user already exists')
  } else {
    const { data: created, error: createErr } = await sb.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
      user_metadata: { full_name: 'Demo Dev' },
    })
    if (createErr) throw createErr
    userId = created.id
    console.log('created demo user')
  }

  const seed = {
    habits: [
      { name: 'Drink water', emoji: '💧', color: 'sky', frequency_type: 'daily', frequency_value: {} },
      { name: 'Gym', emoji: '🏋️', color: 'red', frequency_type: 'weekly', frequency_value: { times: 3 } },
      { name: 'Code 30 min', emoji: '💻', color: 'violet', frequency_type: 'weekdays', frequency_value: { days: [1, 2, 3, 4, 5] } },
      { name: 'Read', emoji: '📚', color: 'amber', frequency_type: 'every_n_days', frequency_value: { every: 2 } },
    ],
    projects: [
      { name: 'Personal', color: 'sky' },
      { name: 'Work', color: 'violet' },
    ],
    tasks: [
      { title: 'Welcome task', notes: 'Using Personal Hub', priority: 'medium', status: 'todo' },
    ],
    notes: [
      { title: 'Welcome', content: '# Personal Hub\nPrivate markdown notes.', is_pinned: true },
    ],
  }

  for (const [table, rows] of Object.entries(seed)) {
    const { error } = await sb.from(table).insert(rows.map((r) => ({ ...r, user_id: userId })))
    if (error && error.code !== '23505') {
      console.error(`seed ${table}:`, error.message)
    } else {
      console.log(`seeded ${table} (${rows.length})`)
    }
  }

  if (!demo) {
    const { data: day } = await sb.from('diary_entries').insert({ user_id: userId, entry_date: new Date().toISOString().slice(0, 10), title: 'A new start', content: 'Seeded via script.', mood: 4 })
    if (day) console.log('seeded diary (1)')
  }

  console.log('\nDone. Login:', email, '/', password)
}

main().catch((e) => {
  console.error(e)
  process.exit(1)
})