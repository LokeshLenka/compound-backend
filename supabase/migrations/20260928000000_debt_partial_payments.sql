-- Partial payments for debts/owes
ALTER TABLE debts ADD COLUMN IF NOT EXISTS paid_amount NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (paid_amount >= 0);
-- Ensure paid_amount never exceeds amount (deferred check via trigger or constraint)
ALTER TABLE debts DROP CONSTRAINT IF EXISTS debts_paid_amount_check;
ALTER TABLE debts ADD CONSTRAINT debts_paid_amount_check CHECK (paid_amount <= amount);

-- Backfill existing paid debts
UPDATE debts SET paid_amount = amount WHERE status = 'paid' AND (paid_amount = 0 OR paid_amount IS NULL);
UPDATE debts SET paid_amount = 0 WHERE status != 'paid' AND paid_amount IS NULL;

-- Debt payments history (partial settlements)
CREATE TABLE IF NOT EXISTS debt_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  debt_id UUID NOT NULL REFERENCES debts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  amount NUMERIC(12,2) NOT NULL CHECK (amount > 0),
  date DATE NOT NULL DEFAULT CURRENT_DATE,
  note TEXT DEFAULT '',
  transaction_id UUID REFERENCES expense_transactions(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_debt_payments_debt ON debt_payments(debt_id);
CREATE INDEX IF NOT EXISTS idx_debt_payments_user ON debt_payments(user_id);
CREATE INDEX IF NOT EXISTS idx_debt_payments_transaction ON debt_payments(transaction_id);

ALTER TABLE debt_payments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Read own debt_payments" ON debt_payments;
CREATE POLICY "Read own debt_payments" ON debt_payments FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Insert own debt_payments" ON debt_payments;
CREATE POLICY "Insert own debt_payments" ON debt_payments FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "Update own debt_payments" ON debt_payments;
CREATE POLICY "Update own debt_payments" ON debt_payments FOR UPDATE USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Delete own debt_payments" ON debt_payments;
CREATE POLICY "Delete own debt_payments" ON debt_payments FOR DELETE USING (auth.uid() = user_id);

DROP TRIGGER IF EXISTS debt_payments_set_updated_at ON debt_payments;
CREATE TRIGGER debt_payments_set_updated_at BEFORE UPDATE ON debt_payments FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS debt_payments_set_user ON debt_payments;
CREATE TRIGGER debt_payments_set_user BEFORE INSERT ON debt_payments FOR EACH ROW EXECUTE FUNCTION set_current_user();

-- Migrate existing single settlements into debt_payments
INSERT INTO debt_payments (debt_id, user_id, amount, date, note, transaction_id)
SELECT d.id, d.user_id, d.amount, CURRENT_DATE, COALESCE(d.note, '') || ' (migrated settlement)', d.settlement_transaction_id
FROM debts d
WHERE d.settlement_transaction_id IS NOT NULL AND d.status = 'paid'
ON CONFLICT DO NOTHING;
