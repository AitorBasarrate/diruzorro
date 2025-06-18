package database

import (
	"database/sql"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

type DB struct {
	*sql.DB
}

type Config struct {
	DatabasePath   string
	MigrationsPath string
}

func NewConnection(config Config) (*DB, error) {
	dbDir := filepath.Dir(config.DatabasePath)
	if err := os.MkdirAll(dbDir, 0755); err != nil {
		return nil, fmt.Errorf("failed to create databse directory: %w", err)
	}

	sqlDB, err := sql.Open("sqlite", config.DatabasePath)
	if err != nil {
		return nil, fmt.Errorf("failed to open database: %w", err)
	}

	sqlDB.SetMaxOpenConns(1)
	sqlDB.SetMaxIdleConns(1)

	if err := sqlDB.Ping(); err != nil {
		return nil, fmt.Errorf("failed to ping database: %w", err)
	}

	db := &DB{sqlDB}

	if config.MigrationsPath != "" {
		if err := db.runMigrations(config.MigrationsPath); err != nil {
			return nil, fmt.Errorf("failed to run migrations: %w", err)
		}
	}

	return db, nil
}

func (db *DB) runMigrations(migrationsPath string) error {
	createMigrationsTable := `
		CREATE TABLE IF NOT EXISTS migrations (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			filename TEXT UNIQUE NOT NULL,
			executed_at DATETIME DEFAILT CURRENT_TIMESTAMP
		);`

	if _, err := db.Exec(createMigrationsTable); err != nil {
		return fmt.Errorf("failed creating migrations table: %w", err)
	}

	files, err := os.ReadDir(migrationsPath)
	if err != nil {
		if os.IsNotExist(err) {
			return nil
		}
		return fmt.Errorf("failed to read migrations directory: %w", err)
	}

	var sqlFiles []fs.DirEntry
	for _, file := range files {
		if !file.IsDir() && strings.HasSuffix(file.Name(), "sql") {
			sqlFiles = append(sqlFiles, file)
		}
	}

	sort.Slice(sqlFiles, func(i, j int) bool {
		return sqlFiles[i].Name() < sqlFiles[j].Name()
	})

	for _, file := range sqlFiles {
		filename := file.Name()

		var count int
		err := db.QueryRow("SELECT COUNT(*) FROM migrations WHERE filename = ?", filename).Scan(&count)
		if err != nil {
			return fmt.Errorf("failed to check migration status: %w", err)
		}

		if count > 0 {
			continue
		}

		migrationsPath := filepath.Join(migrationsPath, filename)
		content, err := os.ReadFile(migrationsPath)
		if err != nil {
			return fmt.Errorf("failed to read migration file %s: %w", filename, err)
		}

		tx, err := db.Begin()
		if err != nil {
			return fmt.Errorf("failed to begin transaction from migration %s: %w", filename, err)
		}

		if _, err := tx.Exec(string(content)); err != nil {
			tx.Rollback()
			return fmt.Errorf("failed to execute migration %s: %w", filename, err)
		}

		if _, err := tx.Exec("INSERT INTO migrations (filename) VALUES (?)", filename); err != nil {
			return fmt.Errorf("failed to commit migration %s: %w", filename, err)
		}

		fmt.Printf("Migration executed: %s\n", filename)
	}

	return nil
}

func (db *DB) Close() error {
	return db.DB.Close()
}

func (db *DB) Health() error {
	return db.Ping()
}

func (db *DB) GetVersion() (int, error) {
	var count int
	err := db.QueryRow("SELECT COUNT(*) FROM migrations").Scan(&count)
	return count, err
}

func (db *DB) TableExists(tableName string) (bool, error) {
	query := `
		SELECT COUNT(*)
		FROM sqlite_master
		WHERE type='table' AND name=?`

	var count int
	err := db.QueryRow(query, tableName).Scan(&count)
	if err != nil {
		return false, err
	}
	return count > 0, err
}

func (db *DB) SeedDefaultCategories(userID int) error {
	defaultCategories := []struct {
		Name  string
		Type  string
		Icon  string
		Color string
	}{
		//TODO: Define correctly the categories
		{"Alimentación", "expense", "🍔", "#e74c3c"},
		{"Ocio", "expense", "🏠", "#9b59b6"},
		{"Transporte", "expense", "🚗", "#3498db"},
		{"", "expense", "💊", "#1abc9c"},
		{"Entretenimiento", "expense", "🎯", "#f39c12"},
		{"Ropa", "expense", "👕", "#e67e22"},
		{"Educación", "expense", "📚", "#2ecc71"},
		{"Servicios", "expense", "⚡", "#34495e"},
		{"Otros gastos", "expense", "💳", "#95a5a6"},

		{"Salario", "income", "💼", "#27ae60"},
		{"Otros ingresos", "income", "💰", "#16a085"},
	}

	tx, err := db.Begin()
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}

	defer tx.Rollback()

	query := `
		INSERT INTO categories (user_id, name, type, icon, color)
		VALUE (?, ?, ?, ?, ?)`

	for _, cat := range defaultCategories {
		_, err := tx.Exec(query, userID, cat.Name, cat.Type, cat.Icon, cat.Color)
		if err != nil {
			return fmt.Errorf("failed to insert category %s: %w", cat.Name, err)
		}
	}

	return tx.Commit()
}
