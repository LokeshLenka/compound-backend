-- Journaling: personal journal entries (unlimited per day, unlike diary's one-per-day)
CREATE TABLE journal_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL DEFAULT '',
  content TEXT NOT NULL DEFAULT '',
  mood SMALLINT CHECK (mood BETWEEN 1 AND 5),
  tags TEXT[] DEFAULT '{}',
  category TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_journal_entries_user ON journal_entries(user_id);
CREATE INDEX idx_journal_entries_user_created ON journal_entries(user_id, created_at DESC);
CREATE INDEX idx_journal_entries_user_mood ON journal_entries(user_id, mood) WHERE mood IS NOT NULL;
CREATE INDEX idx_journal_entries_user_tags ON journal_entries USING GIN(tags) WHERE tags <> '{}';

ALTER TABLE journal_entries ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Read own journal entries" ON journal_entries FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Insert own journal entries" ON journal_entries FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Update own journal entries" ON journal_entries FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Delete own journal entries" ON journal_entries FOR DELETE USING (auth.uid() = user_id);

CREATE TRIGGER journal_entries_set_updated_at
  BEFORE UPDATE ON journal_entries
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
