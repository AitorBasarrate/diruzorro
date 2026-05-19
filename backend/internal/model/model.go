package model

import "time"

type Account struct {
	ID        int64     `json:"id"`
	Name      string    `json:"name"`
	Type      string    `json:"type"` // checking, savings, credit
	Currency  string    `json:"currency"`
	Balance   float64   `json:"balance"`
	BankID    *string   `json:"bank_id,omitempty"`
	CreatedAt time.Time `json:"created_at"`
}

type Category struct {
	ID          int64   `json:"id"`
	Name        string  `json:"name"`
	Type        string  `json:"type"` // expense, income
	Icon        string  `json:"icon"`
	Color       string  `json:"color"`
	BudgetLimit float64 `json:"budget_limit"`
}

type Transaction struct {
	ID                int64     `json:"id"`
	AccountID         int64     `json:"account_id"`
	CategoryID        *int64    `json:"category_id,omitempty"`
	Amount            float64   `json:"amount"`
	Type              string    `json:"type"` // expense, income, transfer
	Description       string    `json:"description"`
	Date              string    `json:"date"` // YYYY-MM-DD
	BankTransactionID *string   `json:"bank_transaction_id,omitempty"`
	CreatedAt         time.Time `json:"created_at"`
}

type Budget struct {
	ID          int64   `json:"id"`
	CategoryID  int64   `json:"category_id"`
	Month       int     `json:"month"`
	Year        int     `json:"year"`
	LimitAmount float64 `json:"limit_amount"`
	SpentAmount float64 `json:"spent_amount"`
}

type SavingsGoal struct {
	ID            int64     `json:"id"`
	Name          string    `json:"name"`
	TargetAmount  float64   `json:"target_amount"`
	CurrentAmount float64   `json:"current_amount"`
	TargetDate    *string   `json:"target_date,omitempty"` // YYYY-MM-DD
	CreatedAt     time.Time `json:"created_at"`
}

type BankConnection struct {
	ID            int64      `json:"id"`
	InstitutionID string     `json:"institution_id"`
	RequisitionID string     `json:"requisition_id"`
	Status        string     `json:"status"`
	LastSync      *time.Time `json:"last_sync,omitempty"`
	CreatedAt     time.Time  `json:"created_at"`
}

// Request/Response types

type CreateAccountRequest struct {
	Name     string  `json:"name"`
	Type     string  `json:"type"`
	Currency string  `json:"currency"`
	Balance  float64 `json:"balance"`
}

type CreateCategoryRequest struct {
	Name        string  `json:"name"`
	Type        string  `json:"type"`
	Icon        string  `json:"icon"`
	Color       string  `json:"color"`
	BudgetLimit float64 `json:"budget_limit"`
}

type CreateTransactionRequest struct {
	AccountID   int64   `json:"account_id"`
	CategoryID  *int64  `json:"category_id,omitempty"`
	Amount      float64 `json:"amount"`
	Type        string  `json:"type"`
	Description string  `json:"description"`
	Date        string  `json:"date"`
}

type CreateBudgetRequest struct {
	CategoryID  int64   `json:"category_id"`
	Month       int     `json:"month"`
	Year        int     `json:"year"`
	LimitAmount float64 `json:"limit_amount"`
}

type CreateSavingsGoalRequest struct {
	Name         string  `json:"name"`
	TargetAmount float64 `json:"target_amount"`
	TargetDate   *string `json:"target_date,omitempty"`
}

type UpdateSavingsGoalRequest struct {
	Name          *string  `json:"name,omitempty"`
	TargetAmount  *float64 `json:"target_amount,omitempty"`
	CurrentAmount *float64 `json:"current_amount,omitempty"`
	TargetDate    *string  `json:"target_date,omitempty"`
}

type TransactionFilter struct {
	From       string
	To         string
	CategoryID *int64
	AccountID  *int64
	Type       string
}

// Report types

type ExpenseByCategoryReport struct {
	CategoryID   int64   `json:"category_id"`
	CategoryName string  `json:"category_name"`
	Total        float64 `json:"total"`
	Color        string  `json:"color"`
}

type MonthlyBalanceReport struct {
	Month    int     `json:"month"`
	Year     int     `json:"year"`
	Income   float64 `json:"income"`
	Expenses float64 `json:"expenses"`
	Balance  float64 `json:"balance"`
}

type TrendReport struct {
	Month string  `json:"month"` // YYYY-MM
	Total float64 `json:"total"`
}
