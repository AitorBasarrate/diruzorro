package handler

import (
	"encoding/json"
	"net/http"
	"strconv"
	"time"

	"github.com/aitorbasarrate/diruzorro/backend/internal/model"
	"github.com/aitorbasarrate/diruzorro/backend/internal/service"
	"github.com/go-chi/chi/v5"
)

type Handler struct {
	svc *service.Service
}

func New(svc *service.Service) *Handler {
	return &Handler{svc: svc}
}

func writeJSON(w http.ResponseWriter, status int, v interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}

func writeError(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, map[string]string{"error": msg})
}

func parseID(r *http.Request) (int64, error) {
	return strconv.ParseInt(chi.URLParam(r, "id"), 10, 64)
}

// --- Accounts ---

func (h *Handler) ListAccounts(w http.ResponseWriter, r *http.Request) {
	accounts, err := h.svc.ListAccounts(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if accounts == nil {
		accounts = []model.Account{}
	}
	writeJSON(w, http.StatusOK, accounts)
}

func (h *Handler) CreateAccount(w http.ResponseWriter, r *http.Request) {
	var req model.CreateAccountRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	if req.Name == "" {
		writeError(w, http.StatusBadRequest, "name is required")
		return
	}
	if req.Currency == "" {
		req.Currency = "EUR"
	}
	if req.Type == "" {
		req.Type = "checking"
	}

	account, err := h.svc.CreateAccount(r.Context(), req)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusCreated, account)
}

func (h *Handler) UpdateAccount(w http.ResponseWriter, r *http.Request) {
	id, err := parseID(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid id")
		return
	}
	var req model.CreateAccountRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	account, err := h.svc.UpdateAccount(r.Context(), id, req)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, account)
}

func (h *Handler) DeleteAccount(w http.ResponseWriter, r *http.Request) {
	id, err := parseID(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid id")
		return
	}
	if err := h.svc.DeleteAccount(r.Context(), id); err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// --- Categories ---

func (h *Handler) ListCategories(w http.ResponseWriter, r *http.Request) {
	categories, err := h.svc.ListCategories(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if categories == nil {
		categories = []model.Category{}
	}
	writeJSON(w, http.StatusOK, categories)
}

func (h *Handler) CreateCategory(w http.ResponseWriter, r *http.Request) {
	var req model.CreateCategoryRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	if req.Name == "" {
		writeError(w, http.StatusBadRequest, "name is required")
		return
	}
	if req.Type == "" {
		req.Type = "expense"
	}

	category, err := h.svc.CreateCategory(r.Context(), req)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusCreated, category)
}

func (h *Handler) UpdateCategory(w http.ResponseWriter, r *http.Request) {
	id, err := parseID(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid id")
		return
	}
	var req model.CreateCategoryRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	category, err := h.svc.UpdateCategory(r.Context(), id, req)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, category)
}

func (h *Handler) DeleteCategory(w http.ResponseWriter, r *http.Request) {
	id, err := parseID(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid id")
		return
	}
	if err := h.svc.DeleteCategory(r.Context(), id); err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// --- Transactions ---

func (h *Handler) ListTransactions(w http.ResponseWriter, r *http.Request) {
	filter := model.TransactionFilter{
		From: r.URL.Query().Get("from"),
		To:   r.URL.Query().Get("to"),
		Type: r.URL.Query().Get("type"),
	}
	if catID := r.URL.Query().Get("category_id"); catID != "" {
		id, err := strconv.ParseInt(catID, 10, 64)
		if err == nil {
			filter.CategoryID = &id
		}
	}
	if accID := r.URL.Query().Get("account_id"); accID != "" {
		id, err := strconv.ParseInt(accID, 10, 64)
		if err == nil {
			filter.AccountID = &id
		}
	}

	transactions, err := h.svc.ListTransactions(r.Context(), filter)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if transactions == nil {
		transactions = []model.Transaction{}
	}
	writeJSON(w, http.StatusOK, transactions)
}

func (h *Handler) CreateTransaction(w http.ResponseWriter, r *http.Request) {
	var req model.CreateTransactionRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	if req.AccountID == 0 {
		writeError(w, http.StatusBadRequest, "account_id is required")
		return
	}
	if req.Amount == 0 {
		writeError(w, http.StatusBadRequest, "amount is required")
		return
	}
	if req.Date == "" {
		req.Date = time.Now().Format("2006-01-02")
	}
	if req.Type == "" {
		req.Type = "expense"
	}

	transaction, err := h.svc.CreateTransaction(r.Context(), req)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusCreated, transaction)
}

func (h *Handler) UpdateTransaction(w http.ResponseWriter, r *http.Request) {
	id, err := parseID(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid id")
		return
	}
	var req model.CreateTransactionRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	transaction, err := h.svc.UpdateTransaction(r.Context(), id, req)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, transaction)
}

func (h *Handler) DeleteTransaction(w http.ResponseWriter, r *http.Request) {
	id, err := parseID(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid id")
		return
	}
	if err := h.svc.DeleteTransaction(r.Context(), id); err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// --- Budgets ---

func (h *Handler) ListBudgets(w http.ResponseWriter, r *http.Request) {
	month, _ := strconv.Atoi(r.URL.Query().Get("month"))
	year, _ := strconv.Atoi(r.URL.Query().Get("year"))

	budgets, err := h.svc.ListBudgets(r.Context(), month, year)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if budgets == nil {
		budgets = []model.Budget{}
	}
	writeJSON(w, http.StatusOK, budgets)
}

func (h *Handler) CreateBudget(w http.ResponseWriter, r *http.Request) {
	var req model.CreateBudgetRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	if req.CategoryID == 0 || req.Month == 0 || req.Year == 0 || req.LimitAmount == 0 {
		writeError(w, http.StatusBadRequest, "category_id, month, year, and limit_amount are required")
		return
	}

	budget, err := h.svc.CreateBudget(r.Context(), req)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusCreated, budget)
}

func (h *Handler) UpdateBudget(w http.ResponseWriter, r *http.Request) {
	id, err := parseID(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid id")
		return
	}
	var req model.CreateBudgetRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	budget, err := h.svc.UpdateBudget(r.Context(), id, req)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, budget)
}

// --- Savings Goals ---

func (h *Handler) ListSavingsGoals(w http.ResponseWriter, r *http.Request) {
	goals, err := h.svc.ListSavingsGoals(r.Context())
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if goals == nil {
		goals = []model.SavingsGoal{}
	}
	writeJSON(w, http.StatusOK, goals)
}

func (h *Handler) CreateSavingsGoal(w http.ResponseWriter, r *http.Request) {
	var req model.CreateSavingsGoalRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	if req.Name == "" || req.TargetAmount == 0 {
		writeError(w, http.StatusBadRequest, "name and target_amount are required")
		return
	}

	goal, err := h.svc.CreateSavingsGoal(r.Context(), req)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusCreated, goal)
}

func (h *Handler) UpdateSavingsGoal(w http.ResponseWriter, r *http.Request) {
	id, err := parseID(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid id")
		return
	}
	var req model.UpdateSavingsGoalRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid request body")
		return
	}
	goal, err := h.svc.UpdateSavingsGoal(r.Context(), id, req)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, goal)
}

func (h *Handler) DeleteSavingsGoal(w http.ResponseWriter, r *http.Request) {
	id, err := parseID(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid id")
		return
	}
	if err := h.svc.DeleteSavingsGoal(r.Context(), id); err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

// --- Reports ---

func (h *Handler) ExpensesByCategory(w http.ResponseWriter, r *http.Request) {
	from := r.URL.Query().Get("from")
	to := r.URL.Query().Get("to")
	if from == "" || to == "" {
		writeError(w, http.StatusBadRequest, "from and to query params are required")
		return
	}

	report, err := h.svc.ExpensesByCategory(r.Context(), from, to)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if report == nil {
		report = []model.ExpenseByCategoryReport{}
	}
	writeJSON(w, http.StatusOK, report)
}

func (h *Handler) MonthlyBalance(w http.ResponseWriter, r *http.Request) {
	yearStr := r.URL.Query().Get("year")
	year, err := strconv.Atoi(yearStr)
	if err != nil || year == 0 {
		year = time.Now().Year()
	}

	report, err := h.svc.MonthlyBalance(r.Context(), year)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if report == nil {
		report = []model.MonthlyBalanceReport{}
	}
	writeJSON(w, http.StatusOK, report)
}

func (h *Handler) Trends(w http.ResponseWriter, r *http.Request) {
	monthsStr := r.URL.Query().Get("months")
	months, err := strconv.Atoi(monthsStr)
	if err != nil || months == 0 {
		months = 6
	}

	report, err := h.svc.Trends(r.Context(), months)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if report == nil {
		report = []model.TrendReport{}
	}
	writeJSON(w, http.StatusOK, report)
}

// --- Banking (PSD2) - Placeholder handlers ---

func (h *Handler) ListInstitutions(w http.ResponseWriter, r *http.Request) {
	// TODO: Implement GoCardless API call
	writeJSON(w, http.StatusOK, []interface{}{})
}

func (h *Handler) ConnectBank(w http.ResponseWriter, r *http.Request) {
	// TODO: Implement GoCardless requisition creation
	writeError(w, http.StatusNotImplemented, "banking integration not yet implemented")
}

func (h *Handler) BankCallback(w http.ResponseWriter, r *http.Request) {
	// TODO: Handle GoCardless callback
	writeError(w, http.StatusNotImplemented, "banking integration not yet implemented")
}

func (h *Handler) SyncTransactions(w http.ResponseWriter, r *http.Request) {
	// TODO: Implement transaction sync from GoCardless
	writeError(w, http.StatusNotImplemented, "banking integration not yet implemented")
}

func (h *Handler) DeleteBankConnection(w http.ResponseWriter, r *http.Request) {
	id, err := parseID(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid id")
		return
	}
	if err := h.svc.DeleteBankConnection(r.Context(), id); err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
