import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:diruzorro/views/home_view.dart';
import 'package:diruzorro/views/transactions_view.dart';
import 'package:diruzorro/views/accounts_view.dart';
import 'package:diruzorro/views/budgets_view.dart';
import 'package:diruzorro/views/categories_view.dart';
import 'package:diruzorro/views/reports_view.dart';

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) => ScaffoldWithNavBar(child: child),
      routes: [
        GoRoute(path: '/', builder: (context, state) => const HomeView()),
        GoRoute(path: '/transactions', builder: (context, state) => const TransactionsView()),
        GoRoute(path: '/accounts', builder: (context, state) => const AccountsView()),
        GoRoute(path: '/budgets', builder: (context, state) => const BudgetsView()),
        GoRoute(path: '/reports', builder: (context, state) => const ReportsView()),
        GoRoute(path: '/categories', builder: (context, state) => const CategoriesView()),
      ],
    ),
    GoRoute(
      path: '/transactions/new',
      builder: (context, state) => const CreateTransactionView(),
    ),
  ],
);

class DiruzorroApp extends StatelessWidget {
  const DiruzorroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Diruzorro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2E7D32),
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: const Color(0xFF2E7D32),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      routerConfig: _router,
    );
  }
}

class ScaffoldWithNavBar extends StatelessWidget {
  final Widget child;
  const ScaffoldWithNavBar({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _calculateSelectedIndex(context),
        onDestinationSelected: (index) => _onItemTapped(index, context),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.swap_horiz), label: 'Movimientos'),
          NavigationDestination(icon: Icon(Icons.account_balance), label: 'Cuentas'),
          NavigationDestination(icon: Icon(Icons.pie_chart), label: 'Presupuesto'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Informes'),
          NavigationDestination(icon: Icon(Icons.savings_outlined), label: 'Ahorro'),
        ],
      ),
    );
  }

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location == '/') return 0;
    if (location.startsWith('/transactions')) return 1;
    if (location.startsWith('/accounts')) return 2;
    if (location.startsWith('/budgets')) return 3;
    if (location.startsWith('/reports')) return 4;
    if (location.startsWith('/savings')) return 5;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0: context.go('/');
      case 1: context.go('/transactions');
      case 2: context.go('/accounts');
      case 3: context.go('/budgets');
      case 4: context.go('/reports');
      case 5: context.go('/savings');
    }
  }
}
