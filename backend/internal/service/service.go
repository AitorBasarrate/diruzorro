package service

import (
	"context"

	"github.com/aitorbasarrate/diruzorro/backend/internal/model"
	"github.com/aitorbasarrate/diruzorro/backend/internal/repository"
)

type Service struct {
	repo *repository.Repository
}

func New(repo *repository.Repository) *Service {
	return &Service{repo: repo}
}

// --- Accounts ---

func (s *Service) ListAccounts(ctx context.Context) ([]model.Account, error) {
	return s.repo.ListAccounts(ctx)
}

func (s *Service) CreateAccount(ctx context.Context, req model.CreateAccountRequest) (model.Account, error) {
	return s.repo.CreateAccount(ctx, req)
}

func (s *Service) UpdateAccount(ctx context.Context, id int64, req model.CreateAccountRequest) (model.Account, error) {
	return s.repo.UpdateAccount(ctx, id, req)
}

func (s *Service) DeleteAccount(ctx context.Context, id int64) error {
	return s.repo.DeleteAccount(ctx, id)
}

// --- Categories ---

func (s *Service) ListCategories(ctx context.Context) ([]model.Category, error) {
	return s.repo.ListCategories(ctx)
}

func (s *Service) CreateCategory(ctx context.Context, req model.CreateCategoryRequest) (model.Category, error) {
	return s.repo.CreateCategory(ctx, req)
}

func (s *Service) UpdateCategory(ctx context.Context, id int64, req model.CreateCategoryRequest) (model.Category, error) {
	return s.repo.UpdateCategory(ctx, id, req)
}

func (s *Service) DeleteCategory(ctx context.Context, id int64) error {
	return s.repo.DeleteCategory(ctx, id)
}

// --- Transactions ---

func (s *Service) ListTransactions(ctx context.Context, filter model.TransactionFilter) ([]model.Transaction, error) {
	return s.repo.ListTransactions(ctx, filter)
}

func (s *Service) CreateTransaction(ctx context.Context, req model.CreateTransactionRequest) (model.Transaction, error) {
	tx, err := s.repo.CreateTransaction(ctx, req)
	if err != nil {
		return model.Transaction{}, err
	}

	var delta float64
	switch req.Type {
	case "income":
		delta = req.Amount
	case "expense":
		delta = -req.Amount
	}

	if delta != 0 {
		account, err := s.repo.GetAccount(ctx, req.AccountID)
		if err != nil {
			return model.Transaction{}, err
		}
		updateReq := model.CreateAccountRequest{
			Name:     account.Name,
			Type:     account.Type,
			Currency: account.Currency,
			Balance:  account.Balance + delta,
		}
		if _, err := s.repo.UpdateAccount(ctx, req.AccountID, updateReq); err != nil {
			return model.Transaction{}, err
		}
	}

	return tx, nil
}

func (s *Service) UpdateTransaction(ctx context.Context, id int64, req model.CreateTransactionRequest) (model.Transaction, error) {
	return s.repo.UpdateTransaction(ctx, id, req)
}

func (s *Service) DeleteTransaction(ctx context.Context, id int64) error {
	return s.repo.DeleteTransaction(ctx, id)
}

// --- Budgets ---

func (s *Service) ListBudgets(ctx context.Context, month, year int) ([]model.Budget, error) {
	return s.repo.ListBudgets(ctx, month, year)
}

func (s *Service) CreateBudget(ctx context.Context, req model.CreateBudgetRequest) (model.Budget, error) {
	return s.repo.CreateBudget(ctx, req)
}

func (s *Service) UpdateBudget(ctx context.Context, id int64, req model.CreateBudgetRequest) (model.Budget, error) {
	return s.repo.UpdateBudget(ctx, id, req)
}

// --- Savings Goals ---

func (s *Service) ListSavingsGoals(ctx context.Context) ([]model.SavingsGoal, error) {
	return s.repo.ListSavingsGoals(ctx)
}

func (s *Service) CreateSavingsGoal(ctx context.Context, req model.CreateSavingsGoalRequest) (model.SavingsGoal, error) {
	return s.repo.CreateSavingsGoal(ctx, req)
}

func (s *Service) UpdateSavingsGoal(ctx context.Context, id int64, req model.UpdateSavingsGoalRequest) (model.SavingsGoal, error) {
	return s.repo.UpdateSavingsGoal(ctx, id, req)
}

func (s *Service) DeleteSavingsGoal(ctx context.Context, id int64) error {
	return s.repo.DeleteSavingsGoal(ctx, id)
}

// --- Reports ---

func (s *Service) ExpensesByCategory(ctx context.Context, from, to string) ([]model.ExpenseByCategoryReport, error) {
	return s.repo.ExpensesByCategory(ctx, from, to)
}

func (s *Service) MonthlyBalance(ctx context.Context, year int) ([]model.MonthlyBalanceReport, error) {
	return s.repo.MonthlyBalance(ctx, year)
}

func (s *Service) Trends(ctx context.Context, months int) ([]model.TrendReport, error) {
	return s.repo.Trends(ctx, months)
}

// --- Bank Connections ---

func (s *Service) ListBankConnections(ctx context.Context) ([]model.BankConnection, error) {
	return s.repo.ListBankConnections(ctx)
}

func (s *Service) GetBankConnection(ctx context.Context, id int64) (model.BankConnection, error) {
	return s.repo.GetBankConnection(ctx, id)
}

func (s *Service) CreateBankConnection(ctx context.Context, institutionID, requisitionID string) (model.BankConnection, error) {
	return s.repo.CreateBankConnection(ctx, institutionID, requisitionID)
}

func (s *Service) UpdateBankConnectionStatus(ctx context.Context, requisitionID, status string) error {
	return s.repo.UpdateBankConnectionStatus(ctx, requisitionID, status)
}

func (s *Service) DeleteBankConnection(ctx context.Context, id int64) error {
	return s.repo.DeleteBankConnection(ctx, id)
}

func (s *Service) GetBankConnectionByRequisition(ctx context.Context, requisitionID string) (model.BankConnection, error) {
	return s.repo.GetBankConnectionByRequisition(ctx, requisitionID)
}
