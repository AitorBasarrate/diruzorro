package repository

import (
	"database/sql"
	_ "embed"

	_ "modernc.org/sqlite"
)

//go:embed migrations.sql
var migrationsSQL string

func NewDB(path string) (*sql.DB, error) {
	db, err := sql.Open("sqlite", path+"?_journal_mode=WAL&_busy_timeout=5000&_foreign_keys=on")
	if err != nil {
		return nil, err
	}
	if err := db.Ping(); err != nil {
		return nil, err
	}
	return db, nil
}

func RunMigrations(db *sql.DB) error {
	_, err := db.Exec(migrationsSQL)
	return err
}
