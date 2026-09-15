-- Expense Tracker: categories, transactions, budgets
CREATE TABLE expense_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
  icon TEXT DEFAULT 'tag',
  color TEXT DEFAULT 'slate',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, name)
);

CREATE INDEX idx_expense_categories_user ON expense_categories(user_id);

ALTER TABLE expense_categories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Read own categories" ON expense_categories FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Insert own categories" ON expense_categories FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Update own categories" ON expense_categories FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Delete own categories" ON expense_categories FOR DELETE USING (auth.uid() = user_id);

CREATE TRIGGER expense_categories_set_updated_at
  BEFORE UPDATE ON expense_categories
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE expense_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  amount NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
  type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
  category_id UUID REFERENCES expense_categories(id) ON DELETE SET NULL,
  date DATE NOT NULL DEFAULT CURRENT_DATE,
  note TEXT DEFAULT '',
  recurring_interval TEXT DEFAULT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_expense_transactions_user ON expense_transactions(user_id);
CREATE INDEX idx_expense_transactions_user_date ON expense_transactions(user_id, date DESC);
CREATE INDEX idx_expense_transactions_user_type ON expense_transactions(user_id, type);

ALTER TABLE expense_transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Read own transactions" ON expense_transactions FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Insert own transactions" ON expense_transactions FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Update own transactions" ON expense_transactions FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Delete own transactions" ON expense_transactions FOR DELETE USING (auth.uid() = user_id);

CREATE TRIGGER expense_transactions_set_updated_at
  BEFORE UPDATE ON expense_transactions
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TABLE expense_budgets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  category_id UUID NOT NULL REFERENCES expense_categories(id) ON DELETE CASCADE,
  amount NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
  period TEXT NOT NULL DEFAULT 'monthly' CHECK (period IN ('weekly', 'monthly', 'yearly')),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(user_id, category_id, period)
);

CREATE INDEX idx_expense_budgets_user ON expense_budgets(user_id);

ALTER TABLE expense_budgets ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Read own budgets" ON expense_budgets FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Insert own budgets" ON expense_budgets FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Update own budgets" ON expense_budgets FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Delete own budgets" ON expense_budgets FOR DELETE USING (auth.uid() = user_id);

CREATE TRIGGER expense_budgets_set_updated_at
  BEFORE UPDATE ON expense_budgets
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
