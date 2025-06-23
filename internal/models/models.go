package database

import (
	"time"
)

// User in the system
type User struct {
	ID        int       `json:"id"`
	Name      string    `json:"name"`
	Email     string    `json:"email"`
	CreatedAt time.Time `json:"created_at"`
	UpdatedAt time.Time `json:"updated_at"`
}

// Financial account
type Account struct {
	ID          int       `json:"id"`
	UserID      int       `json:"user_id"`
	Balance     float64   `json:"balance"`
	Description string    `json:"description"`
	IsActive    bool      `json:"is_active"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

// Category of the transaction
type Category struct {
	ID          int       `json:"id"`
	Name        string    `json:"name"`
	Type        string    `json:"type"`
	Color       string    `json:"color"`
	Icon        string    `json:"icon"`
	Description string    `json:"description"`
	IsActive    bool      `json:"is_active"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

type Transaction struct {
	ID          int       `json:"id"`
	UserID      int       `json:"user_id"`
	AccountID   int       `json:"account_id"`
	CategoryID  int       `json:"category_id"`
	Amount      float64   `json:"amount"` // positive for income, negative for expense
	Description string    `json:"description"`
	Date        time.Time `json:"date"`
	CreatedAt   time.Time `json:"created_at"`
	UpdatedAt   time.Time `json:"updated_at"`
}

type SavingsGoal struct {
	ID            int       `json:"id"`
	UserID        int       `json:"user_id"`
	Name          string    `json:"name"`
	Description   string    `json:"description"`
	TargetAmount  float64   `json:"target_amount"`
	CurrentAmount float64   `json:"current_amount"`
	TargetDate    time.Time `json:"target_date"`
	IsCompleted   bool      `json:"is_completed"`
	CreatedAt     time.Time `json:"created_at"`
	UpdatedAt     time.Time `json:"updated_at"`
}

type UserRepository interface {
	Create(user *User) error
	GetByID(id int) (*User, error)
	GetByEmail(emain string) (*User, error)
	Update(user *User) error
	Delete(id int) error
}

type AccountRepository interface {
	Create(account *Account) error
	GetByID(id int) (*User, error)
	Update(account *Account) error
	Delete(id int) error
}

type CategoryRepository interface {
	Create(category *Category) error
	GetByID(id int) (*User, error)
	Update(category *Category) error
	Delete(id int) error
}

type TransactionRepository interface {
	Create(transaction *Transaction) error
	GetByID(id int) (*Transaction, error)
	Update(transaction *Transaction) error
	Delete(id int) error
}

type SavingsGoalRepository interface {
	Create(savingsGoal *SavingsGoal) error
	GetByID(id int) (*SavingsGoal, error)
	Update(savingsGoal *SavingsGoal) error
	UpdateProgress(id int, amount float64) error
	Delete(id int) error
}
