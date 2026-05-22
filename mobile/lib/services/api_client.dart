import 'package:dio/dio.dart';

class ApiClient {
  final Dio _dio;

  ApiClient({required String baseUrl, required String apiKey})
      : _dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          headers: {
            'Content-Type': 'application/json',
            'X-API-Key': apiKey,
          },
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
        ));

  // --- Accounts ---
  Future<List<dynamic>> getAccounts() async {
    final response = await _dio.get('/accounts');
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createAccount(Map<String, dynamic> data) async {
    final response = await _dio.post('/accounts', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteAccount(int id) async {
    await _dio.delete('/accounts/$id');
  }

  // --- Categories ---
  Future<List<dynamic>> getCategories() async {
    final response = await _dio.get('/categories');
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createCategory(Map<String, dynamic> data) async {
    final response = await _dio.post('/categories', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteCategory(int id) async {
    await _dio.delete('/categories/$id');
  }

  // --- Transactions ---
  Future<List<dynamic>> getTransactions({String? from, String? to, int? categoryId, int? accountId}) async {
    final params = <String, dynamic>{};
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    if (categoryId != null) params['category_id'] = categoryId;
    if (accountId != null) params['account_id'] = accountId;

    final response = await _dio.get('/transactions', queryParameters: params);
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createTransaction(Map<String, dynamic> data) async {
    final response = await _dio.post('/transactions', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteTransaction(int id) async {
    await _dio.delete('/transactions/$id');
  }

  // --- Budgets ---
  Future<List<dynamic>> getBudgets({int? month, int? year}) async {
    final params = <String, dynamic>{};
    if (month != null) params['month'] = month;
    if (year != null) params['year'] = year;

    final response = await _dio.get('/budgets', queryParameters: params);
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createBudget(Map<String, dynamic> data) async {
    final response = await _dio.post('/budgets', data: data);
    return response.data as Map<String, dynamic>;
  }

  // --- Savings Goals ---
  Future<List<dynamic>> getSavingsGoals() async {
    final response = await _dio.get('/savings-goals');
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createSavingsGoal(Map<String, dynamic> data) async {
    final response = await _dio.post('/savings-goals', data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteSavingsGoal(int id) async {
    await _dio.delete('/savings-goals/$id');
  }

  // --- Reports ---
  Future<List<dynamic>> getExpensesByCategory(String from, String to) async {
    final response = await _dio.get('/reports/expenses-by-category', queryParameters: {'from': from, 'to': to});
    return response.data as List<dynamic>;
  }

  Future<List<dynamic>> getMonthlyBalance(int year) async {
    final response = await _dio.get('/reports/monthly-balance', queryParameters: {'year': year});
    return response.data as List<dynamic>;
  }

  Future<List<dynamic>> getTrends({int months = 6}) async {
    final response = await _dio.get('/reports/trends', queryParameters: {'months': months});
    return response.data as List<dynamic>;
  }
}
