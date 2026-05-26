package service

import (
	"context"
	"testing"

	"github.com/aitorbasarrate/diruzorro/backend/internal/model"
	"github.com/aitorbasarrate/diruzorro/backend/internal/repository"
)

func setupTestService(t *testing.T) (*Service, func()) {
	t.Helper()
	db, err := repository.NewDB(":memory:")
	if err != nil {
		t.Fatalf("failed to open db: %v", err)
	}
	if err := repository.RunMigrations(db); err != nil {
		t.Fatalf("failed to run migrations: %v", err)
	}
	repo := repository.New(db)
	svc := New(repo)
	return svc, func() { _ = db.Close() }
}

func TestCreateExpenseDecreasesAccountBalance(t *testing.T) {
	svc, cleanup := setupTestService(t)
	defer cleanup()

	ctx := context.Background()

	acc, err := svc.repo.CreateAccount(ctx, model.CreateAccountRequest{
		Name:     "Test",
		Type:     "checking",
		Currency: "EUR",
		Balance:  1000,
	})
	if err != nil {
		t.Fatalf("CreateAccount: %v", err)
	}

	cat, err := svc.repo.CreateCategory(ctx, model.CreateCategoryRequest{
		Name:  "Comida",
		Type:  "expense",
		Icon:  "🍕",
		Color: "#FF0000",
	})
	if err != nil {
		t.Fatalf("CreateCategory: %v", err)
	}

	_, err = svc.CreateTransaction(ctx, model.CreateTransactionRequest{
		AccountID:   acc.ID,
		CategoryID:  &cat.ID,
		Amount:      50,
		Type:        "expense",
		Description: "Supermercado",
		Date:        "2026-05-10",
	})
	if err != nil {
		t.Fatalf("CreateTransaction: %v", err)
	}

	updated, err := svc.repo.GetAccount(ctx, acc.ID)
	if err != nil {
		t.Fatalf("GetBudgetByCategoryMonthYear: %v", err)
	}
	if updated.Balance != 950 {
		t.Errorf("expected spent_amount: %v, got: %f", 950, updated.Balance)
	}
}

func TestCreateIncomeIncreasesAccountBalance(t *testing.T) {
	svc, cleanup := setupTestService(t)
	defer cleanup()

	ctx := context.Background()

	acc, err := svc.repo.CreateAccount(ctx, model.CreateAccountRequest{
		Name:     "Test",
		Type:     "checking",
		Currency: "EUR",
		Balance:  1000,
	})
	if err != nil {
		t.Fatalf("CreateAccount: %v", err)
	}

	cat, err := svc.repo.CreateCategory(ctx, model.CreateCategoryRequest{
		Name:  "Comida",
		Type:  "income",
		Icon:  "🍕",
		Color: "#FF0000",
	})
	if err != nil {
		t.Fatalf("CreateCategory: %v", err)
	}

	_, err = svc.CreateTransaction(ctx, model.CreateTransactionRequest{
		AccountID:   acc.ID,
		CategoryID:  &cat.ID,
		Amount:      50,
		Type:        "income",
		Description: "Supermercado",
		Date:        "2026-05-10",
	})
	if err != nil {
		t.Fatalf("CreateTransaction: %v", err)
	}

	updated, err := svc.repo.GetAccount(ctx, acc.ID)
	if err != nil {
		t.Fatalf("GetBudgetByCategoryMonthYear: %v", err)
	}
	if updated.Balance != 1050 {
		t.Errorf("expected spent_amount: %v, got: %f", 1050, updated.Balance)
	}
}

func TestCreateExpenseIncrementsBudgetSpentAmount(t *testing.T) {
	svc, cleanup := setupTestService(t)
	defer cleanup()

	ctx := context.Background()

	acc, err := svc.repo.CreateAccount(ctx, model.CreateAccountRequest{
		Name:     "Test",
		Type:     "checking",
		Currency: "EUR",
		Balance:  1000,
	})
	if err != nil {
		t.Fatalf("CreateAccount: %v", err)
	}

	cat, err := svc.repo.CreateCategory(ctx, model.CreateCategoryRequest{
		Name:  "Comida",
		Type:  "expense",
		Icon:  "🍕",
		Color: "#FF0000",
	})
	if err != nil {
		t.Fatalf("CreateCategory: %v", err)
	}

	budget, err := svc.repo.CreateBudget(ctx, model.CreateBudgetRequest{
		CategoryID:  cat.ID,
		Month:       5,
		Year:        2026,
		LimitAmount: 300,
	})
	if err != nil {
		t.Fatalf("CreateBudget: %v", err)
	}
	if budget.SpentAmount != 0 {
		t.Fatalf("expected initial spent_amount 0, got %v", budget.SpentAmount)
	}

	_, err = svc.CreateTransaction(ctx, model.CreateTransactionRequest{
		AccountID:   acc.ID,
		CategoryID:  &cat.ID,
		Amount:      50,
		Type:        "expense",
		Description: "Supermercado",
		Date:        "2026-05-10",
	})
	if err != nil {
		t.Fatalf("CreateTransaction: %v", err)
	}

	updated, err := svc.repo.GetBudgetByCategoryMonthYear(ctx, cat.ID, 5, 2026)
	if err != nil {
		t.Fatalf("GetBudgetByCategoryMonthYear: %v", err)
	}
	if updated.SpentAmount != 50 {
		t.Errorf("expected spent_amount 50, got %v", updated.SpentAmount)
	}
}

func TestCreateExpenseAccumulatesBudgetSpentAmount(t *testing.T) {
	svc, cleanup := setupTestService(t)
	defer cleanup()

	ctx := context.Background()

	acc, err := svc.repo.CreateAccount(ctx, model.CreateAccountRequest{
		Name: "Test", Type: "checking", Currency: "EUR", Balance: 1000,
	})
	if err != nil {
		t.Fatalf("CreateAccount: %v", err)
	}
	cat, err := svc.repo.CreateCategory(ctx, model.CreateCategoryRequest{
		Name: "Transporte", Type: "expense", Icon: "🚗", Color: "#0000FF",
	})
	if err != nil {
		t.Fatalf("CreateCategory: %v", err)
	}
	_, err = svc.repo.CreateBudget(ctx, model.CreateBudgetRequest{
		CategoryID: cat.ID, Month: 5, Year: 2026, LimitAmount: 100,
	})
	if err != nil {
		t.Fatalf("CreateBudget: %v", err)
	}

	for _, amount := range []float64{20, 30, 15} {
		_, err := svc.CreateTransaction(ctx, model.CreateTransactionRequest{
			AccountID:   acc.ID,
			CategoryID:  &cat.ID,
			Amount:      amount,
			Type:        "expense",
			Description: "Gasto",
			Date:        "2026-05-15",
		})
		if err != nil {
			t.Fatalf("CreateTransaction(%.0f): %v", amount, err)
		}
	}

	b, err := svc.repo.GetBudgetByCategoryMonthYear(ctx, cat.ID, 5, 2026)
	if err != nil {
		t.Fatalf("GetBudgetByCategoryMonthYear: %v", err)
	}
	if b.SpentAmount != 65 {
		t.Errorf("expected spent_amount 65, got %v", b.SpentAmount)
	}
}

func TestCreateExpenseDoesNotAffectOtherMonthBudget(t *testing.T) {
	svc, cleanup := setupTestService(t)
	defer cleanup()

	ctx := context.Background()

	acc, err := svc.repo.CreateAccount(ctx, model.CreateAccountRequest{
		Name: "Test", Type: "checking", Currency: "EUR", Balance: 1000,
	})
	if err != nil {
		t.Fatalf("CreateAccount: %v", err)
	}
	cat, err := svc.repo.CreateCategory(ctx, model.CreateCategoryRequest{
		Name: "Comida", Type: "expense", Icon: "🛒", Color: "#00AA00",
	})
	if err != nil {
		t.Fatalf("CreateCategory: %v", err)
	}
	// budget for April, but the transaction is in May
	_, err = svc.repo.CreateBudget(ctx, model.CreateBudgetRequest{
		CategoryID: cat.ID, Month: 4, Year: 2026, LimitAmount: 200,
	})
	if err != nil {
		t.Fatalf("CreateBudget: %v", err)
	}

	_, err = svc.CreateTransaction(ctx, model.CreateTransactionRequest{
		AccountID:   acc.ID,
		CategoryID:  &cat.ID,
		Amount:      40,
		Type:        "expense",
		Description: "Mercadona",
		Date:        "2026-05-10",
	})
	if err != nil {
		t.Fatalf("CreateTransaction: %v", err)
	}

	// April budget must remain untouched
	b, err := svc.repo.GetBudgetByCategoryMonthYear(ctx, cat.ID, 4, 2026)
	if err != nil {
		t.Fatalf("GetBudgetByCategoryMonthYear: %v", err)
	}
	if b.SpentAmount != 0 {
		t.Errorf("expected April spent_amount 0, got %v", b.SpentAmount)
	}
}

func TestCreateIncomeDoesNotAffectBudget(t *testing.T) {
	svc, cleanup := setupTestService(t)
	defer cleanup()

	ctx := context.Background()

	acc, err := svc.repo.CreateAccount(ctx, model.CreateAccountRequest{
		Name: "Test", Type: "checking", Currency: "EUR", Balance: 0,
	})
	if err != nil {
		t.Fatalf("CreateAccount: %v", err)
	}
	cat, err := svc.repo.CreateCategory(ctx, model.CreateCategoryRequest{
		Name: "Salario", Type: "income", Icon: "💰", Color: "#00FF00",
	})
	if err != nil {
		t.Fatalf("CreateCategory: %v", err)
	}
	_, err = svc.repo.CreateBudget(ctx, model.CreateBudgetRequest{
		CategoryID: cat.ID, Month: 5, Year: 2026, LimitAmount: 999,
	})
	if err != nil {
		t.Fatalf("CreateBudget: %v", err)
	}

	_, err = svc.CreateTransaction(ctx, model.CreateTransactionRequest{
		AccountID:   acc.ID,
		CategoryID:  &cat.ID,
		Amount:      2000,
		Type:        "income",
		Description: "Nómina",
		Date:        "2026-05-01",
	})
	if err != nil {
		t.Fatalf("CreateTransaction: %v", err)
	}

	b, err := svc.repo.GetBudgetByCategoryMonthYear(ctx, cat.ID, 5, 2026)
	if err != nil {
		t.Fatalf("GetBudgetByCategoryMonthYear: %v", err)
	}
	if b.SpentAmount != 0 {
		t.Errorf("expected spent_amount 0 for income, got %v", b.SpentAmount)
	}
}

func TestDeleteExpenseDecrementsBudgetSpentAmount(t *testing.T) {
	svc, cleanup := setupTestService(t)
	defer cleanup()

	ctx := context.Background()

	acc, err := svc.repo.CreateAccount(ctx, model.CreateAccountRequest{
		Name: "Test", Type: "checking", Currency: "EUR", Balance: 1000,
	})
	if err != nil {
		t.Fatalf("CreateAccount: %v", err)
	}
	cat, err := svc.repo.CreateCategory(ctx, model.CreateCategoryRequest{
		Name: "Ocio", Type: "expense", Icon: "🎮", Color: "#AA00AA",
	})
	if err != nil {
		t.Fatalf("CreateCategory: %v", err)
	}
	_, err = svc.repo.CreateBudget(ctx, model.CreateBudgetRequest{
		CategoryID: cat.ID, Month: 5, Year: 2026, LimitAmount: 150,
	})
	if err != nil {
		t.Fatalf("CreateBudget: %v", err)
	}

	tx, err := svc.CreateTransaction(ctx, model.CreateTransactionRequest{
		AccountID:   acc.ID,
		CategoryID:  &cat.ID,
		Amount:      60,
		Type:        "expense",
		Description: "Netflix",
		Date:        "2026-05-05",
	})
	if err != nil {
		t.Fatalf("CreateTransaction: %v", err)
	}

	b, err := svc.repo.GetBudgetByCategoryMonthYear(ctx, cat.ID, 5, 2026)
	if err != nil {
		t.Fatalf("GetBudgetByCategoryMonthYear: %v", err)
	}
	if b.SpentAmount != 60 {
		t.Errorf("expected spent_amount 60 before delete, got %v", b.SpentAmount)
	}

	if err := svc.DeleteTransaction(ctx, tx.ID); err != nil {
		t.Fatalf("DeleteTransaction: %v", err)
	}

	b, err = svc.repo.GetBudgetByCategoryMonthYear(ctx, cat.ID, 5, 2026)
	if err != nil {
		t.Fatalf("GetBudgetByCategoryMonthYear: %v", err)
	}
	if b.SpentAmount != 0 {
		t.Errorf("expected spent_amount 0 after delete, got %v", b.SpentAmount)
	}
}

func TestDeleteExpenseDoesNotGoBelowZero(t *testing.T) {
	svc, cleanup := setupTestService(t)
	defer cleanup()

	ctx := context.Background()

	acc, err := svc.repo.CreateAccount(ctx, model.CreateAccountRequest{
		Name: "Test", Type: "checking", Currency: "EUR", Balance: 1000,
	})
	if err != nil {
		t.Fatalf("CreateAccount: %v", err)
	}
	cat, err := svc.repo.CreateCategory(ctx, model.CreateCategoryRequest{
		Name: "Varios", Type: "expense", Icon: "📦", Color: "#888888",
	})
	if err != nil {
		t.Fatalf("CreateCategory: %v", err)
	}
	budget, err := svc.repo.CreateBudget(ctx, model.CreateBudgetRequest{
		CategoryID: cat.ID, Month: 5, Year: 2026, LimitAmount: 200,
	})
	if err != nil {
		t.Fatalf("CreateBudget: %v", err)
	}
	// spent_amount is 0; deleting should clamp at 0
	tx, err := svc.repo.CreateTransaction(ctx, model.CreateTransactionRequest{
		AccountID:   acc.ID,
		CategoryID:  &cat.ID,
		Amount:      25,
		Type:        "expense",
		Description: "Test",
		Date:        "2026-05-01",
	})
	if err != nil {
		t.Fatalf("CreateTransaction: %v", err)
	}
	// manually set spent_amount to 0 to simulate edge case
	if err := svc.repo.AdjustBudgetSpentAmount(ctx, budget.ID, 0); err != nil {
		t.Fatalf("AdjustBudgetSpentAmount: %v", err)
	}

	if err := svc.DeleteTransaction(ctx, tx.ID); err != nil {
		t.Fatalf("DeleteTransaction: %v", err)
	}

	b, err := svc.repo.GetBudgetByCategoryMonthYear(ctx, cat.ID, 5, 2026)
	if err != nil {
		t.Fatalf("GetBudgetByCategoryMonthYear: %v", err)
	}
	if b.SpentAmount < 0 {
		t.Errorf("spent_amount must not be negative, got %v", b.SpentAmount)
	}
}
