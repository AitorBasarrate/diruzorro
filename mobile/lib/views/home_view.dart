import 'package:diruzorro/providers/providers.dart';
import 'package:fl_chart/fl_chart.dart';
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
                    const _MonthlyExpenseSection()
                    // Other sections go here
                  ],
                ),
              );
            }));
  }
}

class _CurrencySummarySection extends StatelessWidget {
  // Grafico con el balance del mes.
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

class _MonthlyExpenseSection extends ConsumerWidget {
  const _MonthlyExpenseSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(transactionsProvider);

    return txAsync.when(
      loading: () => const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (transactions) {
        final now = DateTime.now();
        final monthTxs = transactions.where((t) {
          final d = DateTime.parse(t.date);
          return d.year == now.year && d.month == now.month;
        }).toList();

        if (monthTxs.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Balance de ${DateFormat('MMMM yyyy', 'es_ES').format(now)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 24),
                const Center(
                    child: Text('Sin transacciones este mes',
                        style: TextStyle(color: Colors.grey))),
                const SizedBox(height: 16),
              ],
            ),
          );
        }

        // Group income and expenses by day of month.
        final incomeByDay = <int, double>{};
        final expenseByDay = <int, double>{};
        for (final t in monthTxs) {
          final day = DateTime.parse(t.date).day;
          if (t.type == 'income') {
            incomeByDay[day] = (incomeByDay[day] ?? 0) + t.amount;
          } else {
            expenseByDay[day] = (expenseByDay[day] ?? 0) + t.amount;
          }
        }

        final days = {...incomeByDay.keys, ...expenseByDay.keys}.toList()
          ..sort();

        final barGroups = days
            .map((day) => BarChartGroupData(
                  x: day,
                  barRods: [
                    BarChartRodData(
                      toY: incomeByDay[day] ?? 0,
                      color: Colors.green.shade600,
                      width: 6,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4)),
                    ),
                    BarChartRodData(
                      toY: expenseByDay[day] ?? 0,
                      color: Colors.red.shade400,
                      width: 6,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4)),
                    ),
                  ],
                ))
            .toList();

        final maxY = [...incomeByDay.values, ...expenseByDay.values]
                .fold(0.0, (a, b) => a > b ? a : b) *
            1.2;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Balance de ${DateFormat('MMMM yyyy', 'es_ES').format(now)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    maxY: maxY,
                    barGroups: barGroups,
                    gridData: const FlGridData(
                        show: true, drawVerticalLine: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 44,
                          getTitlesWidget: (value, _) => Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, _) => Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _LegendDot(
                      color: Colors.green.shade600, label: 'Ingresos'),
                  const SizedBox(width: 16),
                  _LegendDot(
                      color: Colors.red.shade400, label: 'Gastos'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
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
        title:
            Text(currency, style: const TextStyle(fontWeight: FontWeight.w600)),
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
