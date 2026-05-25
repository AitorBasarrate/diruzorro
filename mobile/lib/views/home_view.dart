import 'package:diruzorro/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class HomeView extends ConsumerWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
        appBar: AppBar(title: const Text('Home')),
        body: accountsAsync.when(
            loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
            error: (e, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: Colors.red),
                      const SizedBox(height: 8),
                      Text('Error al cargar cuentas',
                          style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => ref.invalidate(accountsProvider),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
            data: (accounts) {
              // Group balances by currency and sum them.
              final totals = <String, double>{};
              for (final account in accounts) {
                totals[account.currency] =
                    (totals[account.currency] ?? 0) + account.balance;
              }
              final sortedCurrencies = totals.keys.toList()..sort();

              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(accountsProvider),
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 80),
                  children: [
                    _CurrencySummarySection(
                      sortedCurrencies: sortedCurrencies,
                      totals: totals,
                    ),
                    // Other sections go here
                  ],
                ),
              );
            }));
  }
}

class _CurrencySummarySection extends StatelessWidget {
  const _CurrencySummarySection({
    required this.sortedCurrencies,
    required this.totals,
  });

  final List<String> sortedCurrencies;
  final Map<String, double> totals;

  @override
  Widget build(BuildContext context) {
    if (sortedCurrencies.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet_outlined,
                size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No hay cuentas todavía',
                style: TextStyle(fontSize: 16, color: Colors.grey)),
            SizedBox(height: 4),
            Text('Pulsa + para añadir una',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('Balance por moneda',
              style: Theme.of(context).textTheme.titleMedium),
        ),
        ...sortedCurrencies.map((currency) => _CurrencyTotalTile(
              currency: currency,
              total: totals[currency]!,
            )),
      ],
    );
  }
}

class _CurrencyTotalTile extends StatelessWidget {
  const _CurrencyTotalTile({required this.currency, required this.total});

  final String currency;
  final double total;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final balanceColor = total < 0 ? Colors.red : Colors.green.shade700;
    final formatter = NumberFormat.currency(locale: 'es_ES', symbol: currency);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colorScheme.primaryContainer,
          child: Text(
            currency,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
        ),
        title: Text(currency,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: const Text('Balance total'),
        trailing: Text(
          formatter.format(total),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: balanceColor,
          ),
        ),
      ),
    );
  }
}
