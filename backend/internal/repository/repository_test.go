package repository

import (
	"context"
	"testing"

	"github.com/aitorbasarrate/diruzorro/backend/internal/model"
)

func setupTestRepo(t *testing.T) (*Repository, func()) {
	t.Helper()

	db, err := NewDB(":memory:")
	if err != nil {
		t.Fatalf("failed to open in-memory db: %v", err)
	}
	if err := RunMigrations(db); err != nil {
		t.Fatalf("failed to run migrations: %v", err)
	}

	return New(db), func() { _ = db.Close() }
}

func mustCreateAccount(t *testing.T, r *Repository, name string) model.Account {
	t.Helper()
	a, err := r.CreateAccount(context.Background(), model.CreateAccountRequest{
		Name:     name,
		Type:     "checking",
		Currency: "EUR",
		Balance:  1000,
	})
	if err != nil {
		t.Fatalf("CreateAccount: %v", err)
	}
	return a
}

func mustCreateCategory(t *testing.T, r *Repository, name, typ string) model.Category {
	t.Helper()
	c, err := r.CreateCategory(context.Background(), model.CreateCategoryRequest{
		Name:        name,
		Type:        typ,
		Icon:        "🛒",
		Color:       "#FF0000",
		BudgetLimit: 0,
	})
	if err != nil {
		t.Fatalf("CreateCategory: %v", err)
	}
	return c
}

func TestCreateAccount(t *testing.T) {
	repo, cleanup := setupTestRepo(t)
	defer cleanup()

	ctx := context.Background()
	acc, err := repo.CreateAccount(ctx, model.CreateAccountRequest{
		Name:     "Cuenta corriente",
		Type:     "checking",
		Currency: "EUR",
		Balance:  500.50,
	})
	if err != nil {
		t.Fatalf("CreateAccount returned error: %v", err)
	}
	if acc.ID == 0 {
		t.Errorf("expected non-zero ID")
	}
	if acc.Name != "Cuenta corriente" {
		t.Errorf("expected name 'Cuenta corriente', got %q", acc.Name)
	}
	if acc.Balance != 500.50 {
		t.Errorf("expected balance 500.50, got %v", acc.Balance)
	}

	accounts, err := repo.ListAccounts(ctx)
	if err != nil {
		t.Fatalf("ListAccounts: %v", err)
	}
	if len(accounts) != 1 {
		t.Errorf("expected 1 account, got %d", len(accounts))
	}
}

func TestCreateCategory(t *testing.T) {
	repo, cleanup := setupTestRepo(t)
	defer cleanup()

	ctx := context.Background()
	cat, err := repo.CreateCategory(ctx, model.CreateCategoryRequest{
		Name:        "Alimentación",
		Type:        "expense",
		Icon:        "🍕",
		Color:       "#00AA00",
		BudgetLimit: 300,
	})
	if err != nil {
		t.Fatalf("CreateCategory: %v", err)
	}
	if cat.ID == 0 {
		t.Errorf("expected non-zero ID")
	}
	if cat.Name != "Alimentación" {
		t.Errorf("expected name 'Alimentación', got %q", cat.Name)
	}
	if cat.Type != "expense" {
		t.Errorf("expected type 'expense', got %q", cat.Type)
	}
	if cat.BudgetLimit != 300 {
		t.Errorf("expected budget_limit 300, got %v", cat.BudgetLimit)
	}
}

func TestCreateTransaction(t *testing.T) {
	repo, cleanup := setupTestRepo(t)
	defer cleanup()

	ctx := context.Background()
	acc := mustCreateAccount(t, repo, "Cuenta test")
	cat := mustCreateCategory(t, repo, "Compras", "expense")

	tx, err := repo.CreateTransaction(ctx, model.CreateTransactionRequest{
		AccountID:   acc.ID,
		CategoryID:  &cat.ID,
		Amount:      25.30,
		Type:        "expense",
		Description: "Mercadona",
		Date:        "2026-05-01",
	})
	if err != nil {
		t.Fatalf("CreateTransaction: %v", err)
	}
	if tx.ID == 0 {
		t.Errorf("expected non-zero ID")
	}
	if tx.Amount != 25.30 {
		t.Errorf("expected amount 25.30, got %v", tx.Amount)
	}
	if tx.CategoryID == nil || *tx.CategoryID != cat.ID {
		t.Errorf("expected category_id %d, got %v", cat.ID, tx.CategoryID)
	}

	got, err := repo.GetTransaction(ctx, tx.ID)
	if err != nil {
		t.Fatalf("GetTransaction: %v", err)
	}
	if got.Description != "Mercadona" {
		t.Errorf("expected description 'Mercadona', got %q", got.Description)
	}
}

func TestFilterTransactionsByDate(t *testing.T) {
	repo, cleanup := setupTestRepo(t)
	defer cleanup()

	ctx := context.Background()
	acc := mustCreateAccount(t, repo, "Cuenta")
	cat := mustCreateCategory(t, repo, "Gastos", "expense")

	dates := []string{"2026-04-15", "2026-05-01", "2026-05-15", "2026-06-01"}
	for _, d := range dates {
		_, err := repo.CreateTransaction(ctx, model.CreateTransactionRequest{
			AccountID:   acc.ID,
			CategoryID:  &cat.ID,
			Amount:      10,
			Type:        "expense",
			Description: "test",
			Date:        d,
		})
		if err != nil {
			t.Fatalf("CreateTransaction(%s): %v", d, err)
		}
	}

	txs, err := repo.ListTransactions(ctx, model.TransactionFilter{
		From: "2026-05-01",
		To:   "2026-05-31",
	})
	if err != nil {
		t.Fatalf("ListTransactions: %v", err)
	}
	if len(txs) != 2 {
		t.Errorf("expected 2 transactions in May, got %d", len(txs))
	}
	for _, tx := range txs {
		if tx.Date < "2026-05-01" || tx.Date > "2026-05-31" {
			t.Errorf("transaction date %q out of range", tx.Date)
		}
	}
}

func TestFilterTransactionsByCategory(t *testing.T) {
	repo, cleanup := setupTestRepo(t)
	defer cleanup()

	ctx := context.Background()
	acc := mustCreateAccount(t, repo, "Cuenta")
	food := mustCreateCategory(t, repo, "Alimentación", "expense")
	transport := mustCreateCategory(t, repo, "Transporte", "expense")

	makeTx := func(catID int64, desc string) {
		_, err := repo.CreateTransaction(ctx, model.CreateTransactionRequest{
			AccountID:   acc.ID,
			CategoryID:  &catID,
			Amount:      10,
			Type:        "expense",
			Description: desc,
			Date:        "2026-05-10",
		})
		if err != nil {
			t.Fatalf("CreateTransaction: %v", err)
		}
	}
	makeTx(food.ID, "Supermercado")
	makeTx(food.ID, "Restaurante")
	makeTx(transport.ID, "Gasolina")

	txs, err := repo.ListTransactions(ctx, model.TransactionFilter{
		CategoryID: &food.ID,
	})
	if err != nil {
		t.Fatalf("ListTransactions: %v", err)
	}
	if len(txs) != 2 {
		t.Errorf("expected 2 transactions for Alimentación, got %d", len(txs))
	}
	for _, tx := range txs {
		if tx.CategoryID == nil || *tx.CategoryID != food.ID {
			t.Errorf("expected category_id %d, got %v", food.ID, tx.CategoryID)
		}
	}
}
