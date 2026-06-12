import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:diruzorro/services/api_client.dart';
import 'package:diruzorro/models/models.dart';

// API Client provider
// NOTE: For Android emulator use 10.0.2.2 instead of localhost.
// For a physical device, use the LAN IP of the host machine.
String _envOr(String key, String fallback) {
  final value = dotenv.env[key];
  if (value == null || value.trim().isEmpty) {
    return fallback;
  }
  return value.trim();
}

final apiBaseUrl = _envOr('API_BASE_URL', '');
final apiKeyValue = _envOr('API_KEY', 'dev-key-change-me');

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    baseUrl: apiBaseUrl,
    apiKey: apiKeyValue,
  );
});

// --- Accounts ---
final accountsProvider = FutureProvider<List<Account>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.getAccounts();
  return data.map((e) => Account.fromJson(e as Map<String, dynamic>)).toList();
});

// --- Categories ---
final categoriesProvider = FutureProvider<List<Category>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.getCategories();
  return data.map((e) => Category.fromJson(e as Map<String, dynamic>)).toList();
});

// --- Transactions ---
final transactionsProvider = FutureProvider<List<Transaction>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.getTransactions();
  return data
      .map((e) => Transaction.fromJson(e as Map<String, dynamic>))
      .toList();
});

// --- Budgets ---
final budgetsProvider =
    FutureProvider.family<List<Budget>, ({int month, int year})>(
        (ref, params) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.getBudgets(month: params.month, year: params.year);
  return data.map((e) => Budget.fromJson(e as Map<String, dynamic>)).toList();
});

// --- Reports: Monthly Balance ---
final monthlyBalanceProvider =
    FutureProvider.family<List<MonthlyBalanceReport>, int>((ref, year) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.getMonthlyBalance(year);
  return data
      .map((e) => MonthlyBalanceReport.fromJson(e as Map<String, dynamic>))
      .toList();
});

// --- Reports: Trends ---
final trendsProvider =
    FutureProvider.family<List<TrendPoint>, int>((ref, months) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.getTrends(months: months);
  return data
      .map((e) => TrendPoint.fromJson(e as Map<String, dynamic>))
      .toList();
});

// --- Savings Goals ---
final savingsGoalsProvider = FutureProvider<List<SavingsGoal>>((ref) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.getSavingsGoals();
  return data
      .map((e) => SavingsGoal.fromJson(e as Map<String, dynamic>))
      .toList();
});
