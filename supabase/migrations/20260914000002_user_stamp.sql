-- Journal + Expenses: stamp user_id on insert like all other user tables
-- (lets the browser client insert without passing user_id explicitly).
create trigger journal_entries_set_user
before insert on public.journal_entries
for each row execute function public.set_current_user();

create trigger expense_categories_set_user
before insert on public.expense_categories
for each row execute function public.set_current_user();

create trigger expense_transactions_set_user
before insert on public.expense_transactions
for each row execute function public.set_current_user();

create trigger expense_budgets_set_user
before insert on public.expense_budgets
for each row execute function public.set_current_user();
