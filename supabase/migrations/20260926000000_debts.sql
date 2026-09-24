-- Debts / Owes: track money you owe (debt) and money owed to you (owe)
CREATE TABLE debts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  person_name TEXT NOT NULL CHECK (char_length(person_name) > 0),
  amount NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
  type TEXT NOT NULL CHECK (type IN ('debt', 'owe')),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'overdue')),
  due_date DATE,
  note TEXT DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_debts_user ON debts(user_id);
CREATE INDEX idx_debts_user_type ON debts(user_id, type);
CREATE INDEX idx_debts_user_status ON debts(user_id, status);

ALTER TABLE debts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Read own debts" ON debts FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Insert own debts" ON debts FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Update own debts" ON debts FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Delete own debts" ON debts FOR DELETE USING (auth.uid() = user_id);

CREATE TRIGGER debts_set_updated_at
  BEFORE UPDATE ON debts
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER debts_set_user
  BEFORE INSERT ON debts
  FOR EACH ROW EXECUTE FUNCTION set_current_user();
