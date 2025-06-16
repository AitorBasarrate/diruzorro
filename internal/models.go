package models

import (
	"database/sql"
	"modernc.org/sqlite"
)

type Expense struct {
	id           string
	value        int32
	date         int64
	expense_type string
}
