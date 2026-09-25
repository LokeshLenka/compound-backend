-- Manual lock/unlock for debts (user-controlled, not auto on fully paid)
ALTER TABLE debts ADD COLUMN IF NOT EXISTS is_locked BOOLEAN NOT NULL DEFAULT false;
