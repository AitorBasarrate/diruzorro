import 'package:diruzorro/models/models.dart';
import 'package:diruzorro/providers/providers.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class ReportsView extends StatelessWidget {
  const ReportsView({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Informes'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Balance mensual'),
              Tab(text: 'Tendencias'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _MonthlyBalanceTab(),
            _TrendsPlaceholder(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Monthly Balance Tab
// ---------------------------------------------------------------------------

class _MonthlyBalanceTab extends ConsumerStatefulWidget {
  const _MonthlyBalanceTab();

  @override
  ConsumerState<_MonthlyBalanceTab> createState() => _MonthlyBalanceTabState();
}

class _MonthlyBalanceTabState extends ConsumerState<_MonthlyBalanceTab> {
  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    _selectedYear = DateTime.now().year;
  }

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(monthlyBalanceProvider(_selectedYear));

    return Column(
      children: [
        _YearSelector(
          year: _selectedYear,
          onPrev: () => setState(() => _selectedYear--),
          onNext: () => setState(() => _selectedYear++),
        ),
        Expanded(
          child: dataAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 8),
                  Text('Error al cargar datos',
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () =>
                        ref.invalidate(monthlyBalanceProvider(_selectedYear)),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
            data: (reports) => _MonthlyBalanceContent(
              year: _selectedYear,
              reports: reports,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Year selector widget
// ---------------------------------------------------------------------------

class _YearSelector extends StatelessWidget {
  final int year;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _YearSelector({
    required this.year,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final currentYear = DateTime.now().year;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrev,
          ),
          Text(
            '$year',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: year >= currentYear ? null : onNext,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Main content: bar chart + summary cards + balance line chart
// ---------------------------------------------------------------------------

class _MonthlyBalanceContent extends StatelessWidget {
  final int year;
  final List<MonthlyBalanceReport> reports;

  const _MonthlyBalanceContent({
    required this.year,
    required this.reports,
  });

  static const _monthAbbreviations = [
    'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
    'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
  ];

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Sin datos para este año',
                style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }

    // Build lookup by month for easy access (fill missing months with zeros).
    final byMonth = <int, MonthlyBalanceReport>{};
    for (final r in reports) {
      byMonth[r.month] = r;
    }

    // Determine visible months: all 12.
    final incomeValues = List<double>.generate(
        12, (i) => byMonth[i + 1]?.income ?? 0.0);
    final expenseValues = List<double>.generate(
        12, (i) => byMonth[i + 1]?.expenses ?? 0.0);
    final balanceValues = List<double>.generate(
        12, (i) => byMonth[i + 1]?.balance ?? 0.0);

    final maxBarY = [...incomeValues, ...expenseValues]
            .fold(0.0, (a, b) => a > b ? a : b) *
        1.25;

    final totalIncome = incomeValues.fold(0.0, (a, b) => a + b);
    final totalExpenses = expenseValues.fold(0.0, (a, b) => a + b);
    final totalBalance = totalIncome - totalExpenses;

    final currencyFormat =
        NumberFormat.currency(locale: 'es_ES', symbol: '€', decimalDigits: 2);

    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // Legend
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendDot(color: Colors.green.shade600, label: 'Ingresos'),
                const SizedBox(width: 24),
                _LegendDot(color: Colors.red.shade400, label: 'Gastos'),
              ],
            ),
          ),
          // Bar chart
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
            child: SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  maxY: maxBarY > 0 ? maxBarY : 100,
                  minY: 0,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey.withAlpha(51),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= 12) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _monthAbbreviations[idx],
                              style: const TextStyle(fontSize: 9),
                            ),
                          );
                        },
                        reservedSize: 22,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 48,
                        getTitlesWidget: (value, meta) {
                          if (value == meta.max || value == 0) {
                            return Text(
                              _formatCompact(value),
                              style: const TextStyle(fontSize: 9),
                            );
                          }
                          return const SizedBox();
                        },
                      ),
                    ),
                  ),
                  barGroups: List.generate(12, (i) {
                    return BarChartGroupData(
                      x: i,
                      barsSpace: 3,
                      barRods: [
                        BarChartRodData(
                          toY: incomeValues[i],
                          color: Colors.green.shade600,
                          width: 8,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(3)),
                        ),
                        BarChartRodData(
                          toY: expenseValues[i],
                          color: Colors.red.shade400,
                          width: 8,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(3)),
                        ),
                      ],
                    );
                  }),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final label =
                            rodIndex == 0 ? 'Ingresos' : 'Gastos';
                        return BarTooltipItem(
                          '$label\n${currencyFormat.format(rod.toY)}',
                          const TextStyle(
                              color: Colors.white, fontSize: 11),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Summary cards
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    label: 'Ingresos',
                    amount: totalIncome,
                    color: Colors.green.shade600,
                    format: currencyFormat,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SummaryCard(
                    label: 'Gastos',
                    amount: totalExpenses,
                    color: Colors.red.shade400,
                    format: currencyFormat,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SummaryCard(
                    label: 'Balance',
                    amount: totalBalance,
                    color: totalBalance >= 0
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                    format: currencyFormat,
                  ),
                ),
              ],
            ),
          ),
          // Balance line chart
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Text(
              'Balance mensual (ingresos − gastos)',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
            child: SizedBox(
              height: 160,
              child: _BalanceLineChart(
                balanceValues: balanceValues,
                monthAbbreviations: _monthAbbreviations,
                currencyFormat: currencyFormat,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatCompact(double value) {
    if (value.abs() >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    return value.toStringAsFixed(0);
  }
}

// ---------------------------------------------------------------------------
// Balance line chart
// ---------------------------------------------------------------------------

class _BalanceLineChart extends StatelessWidget {
  final List<double> balanceValues;
  final List<String> monthAbbreviations;
  final NumberFormat currencyFormat;

  const _BalanceLineChart({
    required this.balanceValues,
    required this.monthAbbreviations,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context) {
    final maxY =
        balanceValues.fold(0.0, (a, b) => a > b ? a : b);
    final minY =
        balanceValues.fold(0.0, (a, b) => a < b ? a : b);
    final padding = ((maxY - minY) * 0.15).clamp(10.0, double.infinity);

    final spots = List.generate(
      12,
      (i) => FlSpot(i.toDouble(), balanceValues[i]),
    );

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: 11,
        minY: minY - padding,
        maxY: maxY + padding,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: value == 0
                ? Colors.grey.withAlpha(128)
                : Colors.grey.withAlpha(38),
            strokeWidth: value == 0 ? 1.5 : 1,
            dashArray: value == 0 ? null : [4, 4],
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= 12) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    monthAbbreviations[idx],
                    style: const TextStyle(fontSize: 9),
                  ),
                );
              },
              reservedSize: 22,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              getTitlesWidget: (value, meta) {
                if (value == meta.max || value == meta.min || value == 0) {
                  return Text(
                    _formatCompact(value),
                    style: const TextStyle(fontSize: 9),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.3,
            color: Colors.blue.shade600,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                radius: 3,
                color: spot.y >= 0
                    ? Colors.green.shade600
                    : Colors.red.shade400,
                strokeWidth: 1.5,
                strokeColor: Colors.white,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blue.shade600.withAlpha(26),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) => touchedSpots
                .map((s) => LineTooltipItem(
                      '${monthAbbreviations[s.x.toInt()]}\n${currencyFormat.format(s.y)}',
                      TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: s.y >= 0
                            ? FontWeight.normal
                            : FontWeight.bold,
                      ),
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }

  static String _formatCompact(double value) {
    if (value.abs() >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    return value.toStringAsFixed(0);
  }
}

// ---------------------------------------------------------------------------
// Helper widgets
// ---------------------------------------------------------------------------

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final NumberFormat format;

  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.format,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withAlpha(77)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: Colors.grey)),
            const SizedBox(height: 4),
            FittedBox(
              child: Text(
                format.format(amount),
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: color, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Trends placeholder (task 4.3)
// ---------------------------------------------------------------------------

class _TrendsPlaceholder extends StatelessWidget {
  const _TrendsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.show_chart, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('Próximamente',
              style: TextStyle(fontSize: 18, color: Colors.grey)),
          SizedBox(height: 4),
          Text('Tendencias de gastos',
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
