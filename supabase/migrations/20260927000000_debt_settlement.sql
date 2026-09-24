-- Link debts to settlement transactions for net sync
ALTER TABLE debts ADD COLUMN IF NOT EXISTS settlement_transaction_id UUID REFERENCES expense_transactions(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_debts_settlement ON debts(settlement_transaction_id);
