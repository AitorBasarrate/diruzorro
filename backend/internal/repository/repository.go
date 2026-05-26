package repository

import (
	"context"
	"database/sql"
	"fmt"
	"strings"

	"github.com/aitorbasarrate/diruzorro/backend/internal/model"
)

type Repository struct {
	db *sql.DB
}

func New(db *sql.DB) *Repository {
	return &Repository{db: db}
}

// --- Accounts ---

func (r *Repository) ListAccounts(ctx context.Context) ([]model.Account, error) {
	rows, err := r.db.QueryContext(ctx, "SELECT id, name, type, currency, balance, bank_id, created_at FROM accounts ORDER BY name")
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var accounts []model.Account
	for rows.Next() {
		var a model.Account
		if err := rows.Scan(&a.ID, &a.Name, &a.Type, &a.Currency, &a.Balance, &a.BankID, &a.CreatedAt); err != nil {
			return nil, err
		}
		accounts = append(accounts, a)
	}
	return accounts, rows.Err()
}

func (r *Repository) CreateAccount(ctx context.Context, req model.CreateAccountRequest) (model.Account, error) {
	res, err := r.db.ExecContext(ctx,
		"INSERT INTO accounts (name, type, currency, balance) VALUES (?, ?, ?, ?)",
		req.Name, req.Type, req.Currency, req.Balance)
	if err != nil {
		return model.Account{}, err
	}
	id, _ := res.LastInsertId()
	return r.GetAccount(ctx, id)
}

func (r *Repository) GetAccount(ctx context.Context, id int64) (model.Account, error) {
	var a model.Account
	err := r.db.QueryRowContext(ctx,
		"SELECT id, name, type, currency, balance, bank_id, created_at FROM accounts WHERE id = ?", id).
		Scan(&a.ID, &a.Name, &a.Type, &a.Currency, &a.Balance, &a.BankID, &a.CreatedAt)
	return a, err
}

func (r *Repository) UpdateAccount(ctx context.Context, id int64, req model.CreateAccountRequest) (model.Account, error) {
	_, err := r.db.ExecContext(ctx,
		"UPDATE accounts SET name = ?, type = ?, currency = ?, balance = ? WHERE id = ?",
		req.Name, req.Type, req.Currency, req.Balance, id)
	if err != nil {
		return model.Account{}, err
	}
	return r.GetAccount(ctx, id)
}

func (r *Repository) DeleteAccount(ctx context.Context, id int64) error {
	_, err := r.db.ExecContext(ctx, "DELETE FROM accounts WHERE id = ?", id)
	return err
}

// --- Categories ---

func (r *Repository) ListCategories(ctx context.Context) ([]model.Category, error) {
	rows, err := r.db.QueryContext(ctx, "SELECT id, name, type, icon, color, budget_limit FROM categories ORDER BY name")
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var categories []model.Category
	for rows.Next() {
		var c model.Category
		if err := rows.Scan(&c.ID, &c.Name, &c.Type, &c.Icon, &c.Color, &c.BudgetLimit); err != nil {
			return nil, err
		}
		categories = append(categories, c)
	}
	return categories, rows.Err()
}

func (r *Repository) CreateCategory(ctx context.Context, req model.CreateCategoryRequest) (model.Category, error) {
	res, err := r.db.ExecContext(ctx,
		"INSERT INTO categories (name, type, icon, color, budget_limit) VALUES (?, ?, ?, ?, ?)",
		req.Name, req.Type, req.Icon, req.Color, req.BudgetLimit)
	if err != nil {
		return model.Category{}, err
	}
	id, _ := res.LastInsertId()
	return r.GetCategory(ctx, id)
}

func (r *Repository) GetCategory(ctx context.Context, id int64) (model.Category, error) {
	var c model.Category
	err := r.db.QueryRowContext(ctx,
		"SELECT id, name, type, icon, color, budget_limit FROM categories WHERE id = ?", id).
		Scan(&c.ID, &c.Name, &c.Type, &c.Icon, &c.Color, &c.BudgetLimit)
	return c, err
}

func (r *Repository) UpdateCategory(ctx context.Context, id int64, req model.CreateCategoryRequest) (model.Category, error) {
	_, err := r.db.ExecContext(ctx,
		"UPDATE categories SET name = ?, type = ?, icon = ?, color = ?, budget_limit = ? WHERE id = ?",
		req.Name, req.Type, req.Icon, req.Color, req.BudgetLimit, id)
	if err != nil {
		return model.Category{}, err
	}
	return r.GetCategory(ctx, id)
}

func (r *Repository) DeleteCategory(ctx context.Context, id int64) error {
	_, err := r.db.ExecContext(ctx, "DELETE FROM categories WHERE id = ?", id)
	return err
}

// --- Transactions ---

func (r *Repository) ListTransactions(ctx context.Context, filter model.TransactionFilter) ([]model.Transaction, error) {
	query := "SELECT id, account_id, category_id, amount, type, description, date, bank_transaction_id, created_at FROM transactions WHERE 1=1"
	var args []interface{}

	if filter.From != "" {
		query += " AND date >= ?"
		args = append(args, filter.From)
	}
	if filter.To != "" {
		query += " AND date <= ?"
		args = append(args, filter.To)
	}
	if filter.CategoryID != nil {
		query += " AND category_id = ?"
		args = append(args, *filter.CategoryID)
	}
	if filter.AccountID != nil {
		query += " AND account_id = ?"
		args = append(args, *filter.AccountID)
	}
	if filter.Type != "" {
		query += " AND type = ?"
		args = append(args, filter.Type)
	}

	query += " ORDER BY date DESC, id DESC"

	rows, err := r.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var transactions []model.Transaction
	for rows.Next() {
		var t model.Transaction
		if err := rows.Scan(&t.ID, &t.AccountID, &t.CategoryID, &t.Amount, &t.Type, &t.Description, &t.Date, &t.BankTransactionID, &t.CreatedAt); err != nil {
			return nil, err
		}
		transactions = append(transactions, t)
	}
	return transactions, rows.Err()
}

func (r *Repository) CreateTransaction(ctx context.Context, req model.CreateTransactionRequest) (model.Transaction, error) {
	res, err := r.db.ExecContext(ctx,
		"INSERT INTO transactions (account_id, category_id, amount, type, description, date) VALUES (?, ?, ?, ?, ?, ?)",
		req.AccountID, req.CategoryID, req.Amount, req.Type, req.Description, req.Date)
	if err != nil {
		return model.Transaction{}, err
	}
	id, _ := res.LastInsertId()
	return r.GetTransaction(ctx, id)
}

func (r *Repository) GetTransaction(ctx context.Context, id int64) (model.Transaction, error) {
	var t model.Transaction
	err := r.db.QueryRowContext(ctx,
		"SELECT id, account_id, category_id, amount, type, description, date, bank_transaction_id, created_at FROM transactions WHERE id = ?", id).
		Scan(&t.ID, &t.AccountID, &t.CategoryID, &t.Amount, &t.Type, &t.Description, &t.Date, &t.BankTransactionID, &t.CreatedAt)
	return t, err
}

func (r *Repository) UpdateTransaction(ctx context.Context, id int64, req model.CreateTransactionRequest) (model.Transaction, error) {
	_, err := r.db.ExecContext(ctx,
		"UPDATE transactions SET account_id = ?, category_id = ?, amount = ?, type = ?, description = ?, date = ? WHERE id = ?",
		req.AccountID, req.CategoryID, req.Amount, req.Type, req.Description, req.Date, id)
	if err != nil {
		return model.Transaction{}, err
	}
	return r.GetTransaction(ctx, id)
}

func (r *Repository) DeleteTransaction(ctx context.Context, id int64) error {
	_, err := r.db.ExecContext(ctx, "DELETE FROM transactions WHERE id = ?", id)
	return err
}

func (r *Repository) CreateTransactionBatch(ctx context.Context, transactions []model.CreateTransactionRequest) error {
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback() }()

	stmt, err := tx.PrepareContext(ctx,
		"INSERT INTO transactions (account_id, category_id, amount, type, description, date, bank_transaction_id) VALUES (?, ?, ?, ?, ?, ?, ?)")
	if err != nil {
		return err
	}
	defer stmt.Close()

	for _, t := range transactions {
		if _, err := stmt.ExecContext(ctx, t.AccountID, t.CategoryID, t.Amount, t.Type, t.Description, t.Date, nil); err != nil {
			return err
		}
	}
	return tx.Commit()
}

// --- Budgets ---

func (r *Repository) ListBudgets(ctx context.Context, month, year int) ([]model.Budget, error) {
	query := "SELECT id, category_id, month, year, limit_amount, spent_amount FROM budgets WHERE 1=1"
	var args []interface{}
	if month > 0 {
		query += " AND month = ?"
		args = append(args, month)
	}
	if year > 0 {
		query += " AND year = ?"
		args = append(args, year)
	}
	query += " ORDER BY year DESC, month DESC"

	rows, err := r.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var budgets []model.Budget
	for rows.Next() {
		var b model.Budget
		if err := rows.Scan(&b.ID, &b.CategoryID, &b.Month, &b.Year, &b.LimitAmount, &b.SpentAmount); err != nil {
			return nil, err
		}
		budgets = append(budgets, b)
	}
	return budgets, rows.Err()
}

func (r *Repository) CreateBudget(ctx context.Context, req model.CreateBudgetRequest) (model.Budget, error) {
	res, err := r.db.ExecContext(ctx,
		"INSERT INTO budgets (category_id, month, year, limit_amount) VALUES (?, ?, ?, ?)",
		req.CategoryID, req.Month, req.Year, req.LimitAmount)
	if err != nil {
		return model.Budget{}, err
	}
	id, _ := res.LastInsertId()
	var b model.Budget
	err = r.db.QueryRowContext(ctx,
		"SELECT id, category_id, month, year, limit_amount, spent_amount FROM budgets WHERE id = ?", id).
		Scan(&b.ID, &b.CategoryID, &b.Month, &b.Year, &b.LimitAmount, &b.SpentAmount)
	return b, err
}

func (r *Repository) UpdateBudget(ctx context.Context, id int64, req model.CreateBudgetRequest) (model.Budget, error) {
	_, err := r.db.ExecContext(ctx,
		"UPDATE budgets SET category_id = ?, month = ?, year = ?, limit_amount = ? WHERE id = ?",
		req.CategoryID, req.Month, req.Year, req.LimitAmount, id)
	if err != nil {
		return model.Budget{}, err
	}
	var b model.Budget
	err = r.db.QueryRowContext(ctx,
		"SELECT id, category_id, month, year, limit_amount, spent_amount FROM budgets WHERE id = ?", id).
		Scan(&b.ID, &b.CategoryID, &b.Month, &b.Year, &b.LimitAmount, &b.SpentAmount)
	return b, err
}

func (r *Repository) GetBudgetByCategoryMonthYear(ctx context.Context, categoryID int64, month, year int) (model.Budget, error) {
	var b model.Budget
	err := r.db.QueryRowContext(ctx,
		"SELECT id, category_id, month, year, limit_amount, spent_amount FROM budgets WHERE category_id = ? AND month = ? AND year = ?",
		categoryID, month, year).
		Scan(&b.ID, &b.CategoryID, &b.Month, &b.Year, &b.LimitAmount, &b.SpentAmount)
	return b, err
}

func (r *Repository) AdjustBudgetSpentAmount(ctx context.Context, budgetID int64, delta float64) error {
	_, err := r.db.ExecContext(ctx,
		"UPDATE budgets SET spent_amount = MAX(0, spent_amount + ?) WHERE id = ?",
		delta, budgetID)
	return err
}

// --- Savings Goals ---

func (r *Repository) ListSavingsGoals(ctx context.Context) ([]model.SavingsGoal, error) {
	rows, err := r.db.QueryContext(ctx, "SELECT id, name, target_amount, current_amount, target_date, created_at FROM savings_goals ORDER BY created_at DESC")
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var goals []model.SavingsGoal
	for rows.Next() {
		var g model.SavingsGoal
		if err := rows.Scan(&g.ID, &g.Name, &g.TargetAmount, &g.CurrentAmount, &g.TargetDate, &g.CreatedAt); err != nil {
			return nil, err
		}
		goals = append(goals, g)
	}
	return goals, rows.Err()
}

func (r *Repository) CreateSavingsGoal(ctx context.Context, req model.CreateSavingsGoalRequest) (model.SavingsGoal, error) {
	res, err := r.db.ExecContext(ctx,
		"INSERT INTO savings_goals (name, target_amount, target_date) VALUES (?, ?, ?)",
		req.Name, req.TargetAmount, req.TargetDate)
	if err != nil {
		return model.SavingsGoal{}, err
	}
	id, _ := res.LastInsertId()
	return r.GetSavingsGoal(ctx, id)
}

func (r *Repository) GetSavingsGoal(ctx context.Context, id int64) (model.SavingsGoal, error) {
	var g model.SavingsGoal
	err := r.db.QueryRowContext(ctx,
		"SELECT id, name, target_amount, current_amount, target_date, created_at FROM savings_goals WHERE id = ?", id).
		Scan(&g.ID, &g.Name, &g.TargetAmount, &g.CurrentAmount, &g.TargetDate, &g.CreatedAt)
	return g, err
}

func (r *Repository) UpdateSavingsGoal(ctx context.Context, id int64, req model.UpdateSavingsGoalRequest) (model.SavingsGoal, error) {
	var sets []string
	var args []interface{}

	if req.Name != nil {
		sets = append(sets, "name = ?")
		args = append(args, *req.Name)
	}
	if req.TargetAmount != nil {
		sets = append(sets, "target_amount = ?")
		args = append(args, *req.TargetAmount)
	}
	if req.CurrentAmount != nil {
		sets = append(sets, "current_amount = ?")
		args = append(args, *req.CurrentAmount)
	}
	if req.TargetDate != nil {
		sets = append(sets, "target_date = ?")
		args = append(args, *req.TargetDate)
	}

	if len(sets) == 0 {
		return r.GetSavingsGoal(ctx, id)
	}

	query := fmt.Sprintf("UPDATE savings_goals SET %s WHERE id = ?", strings.Join(sets, ", "))
	args = append(args, id)
	if _, err := r.db.ExecContext(ctx, query, args...); err != nil {
		return model.SavingsGoal{}, err
	}
	return r.GetSavingsGoal(ctx, id)
}

func (r *Repository) DeleteSavingsGoal(ctx context.Context, id int64) error {
	_, err := r.db.ExecContext(ctx, "DELETE FROM savings_goals WHERE id = ?", id)
	return err
}

// --- Bank Connections ---

func (r *Repository) ListBankConnections(ctx context.Context) ([]model.BankConnection, error) {
	rows, err := r.db.QueryContext(ctx, "SELECT id, institution_id, requisition_id, status, last_sync, created_at FROM bank_connections ORDER BY created_at DESC")
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var connections []model.BankConnection
	for rows.Next() {
		var bc model.BankConnection
		if err := rows.Scan(&bc.ID, &bc.InstitutionID, &bc.RequisitionID, &bc.Status, &bc.LastSync, &bc.CreatedAt); err != nil {
			return nil, err
		}
		connections = append(connections, bc)
	}
	return connections, rows.Err()
}

func (r *Repository) CreateBankConnection(ctx context.Context, institutionID, requisitionID string) (model.BankConnection, error) {
	res, err := r.db.ExecContext(ctx,
		"INSERT INTO bank_connections (institution_id, requisition_id, status) VALUES (?, ?, 'pending')",
		institutionID, requisitionID)
	if err != nil {
		return model.BankConnection{}, err
	}
	id, _ := res.LastInsertId()
	var bc model.BankConnection
	err = r.db.QueryRowContext(ctx,
		"SELECT id, institution_id, requisition_id, status, last_sync, created_at FROM bank_connections WHERE id = ?", id).
		Scan(&bc.ID, &bc.InstitutionID, &bc.RequisitionID, &bc.Status, &bc.LastSync, &bc.CreatedAt)
	return bc, err
}

func (r *Repository) UpdateBankConnectionStatus(ctx context.Context, requisitionID, status string) error {
	_, err := r.db.ExecContext(ctx, "UPDATE bank_connections SET status = ? WHERE requisition_id = ?", status, requisitionID)
	return err
}

func (r *Repository) UpdateBankConnectionSync(ctx context.Context, id int64) error {
	_, err := r.db.ExecContext(ctx, "UPDATE bank_connections SET last_sync = CURRENT_TIMESTAMP WHERE id = ?", id)
	return err
}

func (r *Repository) DeleteBankConnection(ctx context.Context, id int64) error {
	_, err := r.db.ExecContext(ctx, "DELETE FROM bank_connections WHERE id = ?", id)
	return err
}

func (r *Repository) GetBankConnection(ctx context.Context, id int64) (model.BankConnection, error) {
	var bc model.BankConnection
	err := r.db.QueryRowContext(ctx,
		"SELECT id, institution_id, requisition_id, status, last_sync, created_at FROM bank_connections WHERE id = ?", id).
		Scan(&bc.ID, &bc.InstitutionID, &bc.RequisitionID, &bc.Status, &bc.LastSync, &bc.CreatedAt)
	return bc, err
}

func (r *Repository) GetBankConnectionByRequisition(ctx context.Context, requisitionID string) (model.BankConnection, error) {
	var bc model.BankConnection
	err := r.db.QueryRowContext(ctx,
		"SELECT id, institution_id, requisition_id, status, last_sync, created_at FROM bank_connections WHERE requisition_id = ?", requisitionID).
		Scan(&bc.ID, &bc.InstitutionID, &bc.RequisitionID, &bc.Status, &bc.LastSync, &bc.CreatedAt)
	return bc, err
}

// --- Reports ---

func (r *Repository) ExpensesByCategory(ctx context.Context, from, to string) ([]model.ExpenseByCategoryReport, error) {
	rows, err := r.db.QueryContext(ctx, `
		SELECT c.id, c.name, COALESCE(SUM(t.amount), 0), c.color
		FROM categories c
		LEFT JOIN transactions t ON t.category_id = c.id AND t.type = 'expense' AND t.date >= ? AND t.date <= ?
		WHERE c.type = 'expense'
		GROUP BY c.id
		HAVING COALESCE(SUM(t.amount), 0) > 0
		ORDER BY COALESCE(SUM(t.amount), 0) DESC
	`, from, to)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var reports []model.ExpenseByCategoryReport
	for rows.Next() {
		var r model.ExpenseByCategoryReport
		if err := rows.Scan(&r.CategoryID, &r.CategoryName, &r.Total, &r.Color); err != nil {
			return nil, err
		}
		reports = append(reports, r)
	}
	return reports, rows.Err()
}

func (r *Repository) MonthlyBalance(ctx context.Context, year int) ([]model.MonthlyBalanceReport, error) {
	rows, err := r.db.QueryContext(ctx, `
		SELECT
			CAST(strftime('%m', date) AS INTEGER) as month,
			CAST(strftime('%Y', date) AS INTEGER) as year,
			COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END), 0) as income,
			COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) as expenses
		FROM transactions
		WHERE strftime('%Y', date) = ?
		GROUP BY strftime('%Y-%m', date)
		ORDER BY month
	`, fmt.Sprintf("%d", year))
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var reports []model.MonthlyBalanceReport
	for rows.Next() {
		var r model.MonthlyBalanceReport
		if err := rows.Scan(&r.Month, &r.Year, &r.Income, &r.Expenses); err != nil {
			return nil, err
		}
		r.Balance = r.Income - r.Expenses
		reports = append(reports, r)
	}
	return reports, rows.Err()
}

func (r *Repository) Trends(ctx context.Context, months int) ([]model.TrendReport, error) {
	rows, err := r.db.QueryContext(ctx, `
		SELECT strftime('%Y-%m', date) as month, COALESCE(SUM(amount), 0) as total
		FROM transactions
		WHERE type = 'expense' AND date >= date('now', ? || ' months')
		GROUP BY strftime('%Y-%m', date)
		ORDER BY month
	`, fmt.Sprintf("-%d", months))
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var reports []model.TrendReport
	for rows.Next() {
		var r model.TrendReport
		if err := rows.Scan(&r.Month, &r.Total); err != nil {
			return nil, err
		}
		reports = append(reports, r)
	}
	return reports, rows.Err()
}
