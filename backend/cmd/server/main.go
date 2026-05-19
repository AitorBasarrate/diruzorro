package main

import (
	"context"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/aitorbasarrate/diruzorro/backend/internal/config"
	"github.com/aitorbasarrate/diruzorro/backend/internal/handler"
	"github.com/aitorbasarrate/diruzorro/backend/internal/middleware"
	"github.com/aitorbasarrate/diruzorro/backend/internal/repository"
	"github.com/aitorbasarrate/diruzorro/backend/internal/service"
	"github.com/go-chi/chi/v5"
	chimw "github.com/go-chi/chi/v5/middleware"
)

func main() {
	cfg := config.Load()

	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
		Level: slog.LevelInfo,
	}))
	slog.SetDefault(logger)

	db, err := repository.NewDB(cfg.DatabasePath)
	if err != nil {
		slog.Error("failed to open database", "error", err)
		os.Exit(1)
	}
	defer db.Close()

	if err := repository.RunMigrations(db); err != nil {
		slog.Error("failed to run migrations", "error", err)
		os.Exit(1)
	}

	repo := repository.New(db)
	svc := service.New(repo)
	h := handler.New(svc)

	r := chi.NewRouter()
	r.Use(chimw.RequestID)
	r.Use(chimw.RealIP)
	r.Use(chimw.Logger)
	r.Use(chimw.Recoverer)
	r.Use(chimw.Timeout(30 * time.Second))
	r.Use(middleware.CORS)

	r.Get("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"status":"ok"}`))
	})

	r.Route("/api/v1", func(r chi.Router) {
		r.Use(middleware.Auth(cfg.APIKey))

		// Cuentas
		r.Route("/accounts", func(r chi.Router) {
			r.Get("/", h.ListAccounts)
			r.Post("/", h.CreateAccount)
			r.Put("/{id}", h.UpdateAccount)
			r.Delete("/{id}", h.DeleteAccount)
		})

		// Categorías
		r.Route("/categories", func(r chi.Router) {
			r.Get("/", h.ListCategories)
			r.Post("/", h.CreateCategory)
			r.Put("/{id}", h.UpdateCategory)
			r.Delete("/{id}", h.DeleteCategory)
		})

		// Transacciones
		r.Route("/transactions", func(r chi.Router) {
			r.Get("/", h.ListTransactions)
			r.Post("/", h.CreateTransaction)
			r.Put("/{id}", h.UpdateTransaction)
			r.Delete("/{id}", h.DeleteTransaction)
		})

		// Presupuestos
		r.Route("/budgets", func(r chi.Router) {
			r.Get("/", h.ListBudgets)
			r.Post("/", h.CreateBudget)
			r.Put("/{id}", h.UpdateBudget)
		})

		// Objetivos de ahorro
		r.Route("/savings-goals", func(r chi.Router) {
			r.Get("/", h.ListSavingsGoals)
			r.Post("/", h.CreateSavingsGoal)
			r.Put("/{id}", h.UpdateSavingsGoal)
			r.Delete("/{id}", h.DeleteSavingsGoal)
		})

		// Informes
		r.Route("/reports", func(r chi.Router) {
			r.Get("/expenses-by-category", h.ExpensesByCategory)
			r.Get("/monthly-balance", h.MonthlyBalance)
			r.Get("/trends", h.Trends)
		})

		// Banca PSD2
		r.Route("/banking", func(r chi.Router) {
			r.Get("/institutions", h.ListInstitutions)
			r.Post("/connect", h.ConnectBank)
			r.Post("/sync", h.SyncTransactions)
			r.Delete("/connections/{id}", h.DeleteBankConnection)
		})
	})

	// Callback bancario sin auth (viene del banco)
	r.Get("/api/v1/banking/callback", h.BankCallback)

	srv := &http.Server{
		Addr:         ":" + cfg.Port,
		Handler:      r,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 30 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	go func() {
		slog.Info("server starting", "port", cfg.Port)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			slog.Error("server failed", "error", err)
			os.Exit(1)
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	slog.Info("shutting down server")
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		slog.Error("server shutdown failed", "error", err)
	}
}
