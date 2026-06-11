import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:diruzorro/models/models.dart';
import 'package:diruzorro/providers/providers.dart';

// ── State: selected month / year ─────────────────────────────────────────────

class _Period {
  final int month;
  final int year;
  const _Period(this.month, this.year);
}

// ── Screen ───────────────────────────────────────────────────────────────────

class BudgetsView extends ConsumerStatefulWidget {
  const BudgetsView({super.key});

  @override
  ConsumerState<BudgetsView> createState() => _BudgetsViewState();
}

class _BudgetsViewState extends ConsumerState<BudgetsView> {
  late int _selectedMonth;
  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
  }

  @override
  Widget build(BuildContext context) {
    final period = _Period(_selectedMonth, _selectedYear);
    final budgetsAsync = ref.watch(
      budgetsProvider((month: _selectedMonth, year: _selectedYear)),
    );
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Presupuestos'),
        actions: [
          TextButton.icon(
            onPressed: () => _pickPeriod(context),
            icon: const Icon(Icons.calendar_month),
            label: Text(_periodLabel(period)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context),
        tooltip: 'Nuevo presupuesto',
        child: const Icon(Icons.add),
      ),
      body: budgetsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          message: 'Error al cargar presupuestos',
          onRetry: () => ref.invalidate(
            budgetsProvider((month: period.month, year: period.year)),
          ),
        ),
        data: (budgets) {
          if (budgets.isEmpty) {
            return const _EmptyState();
          }
          final categories = switch (categoriesAsync) {
            AsyncData(:final value) => value,
            _ => const <Category>[],
          };
          final categoriesById = {for (final c in categories) c.id: c};

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(
              budgetsProvider((month: period.month, year: period.year)),
            ),
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 80),
              itemCount: budgets.length,
              itemBuilder: (context, index) {
                final b = budgets[index];
                return _BudgetTile(
                  budget: b,
                  category: categoriesById[b.categoryId],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickPeriod(BuildContext context) async {
    final initial = DateTime(_selectedYear, _selectedMonth);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Selecciona mes y año',
    );
    if (picked != null) {
      setState(() {
        _selectedMonth = picked.month;
        _selectedYear = picked.year;
      });
    }
  }

  void _showCreateDialog(BuildContext context) {
    final period = _Period(_selectedMonth, _selectedYear);
    showDialog<void>(
      context: context,
      builder: (_) => _CreateBudgetDialog(
        initialMonth: period.month,
        initialYear: period.year,
        onCreated: () => ref.invalidate(
          budgetsProvider((month: period.month, year: period.year)),
        ),
      ),
    );
  }
}

String _periodLabel(_Period p) {
  const months = [
    'Ene',
    'Feb',
    'Mar',
    'Abr',
    'May',
    'Jun',
    'Jul',
    'Ago',
    'Sep',
    'Oct',
    'Nov',
    'Dic',
  ];
  return '${months[p.month - 1]} ${p.year}';
}

// ── Budget tile ──────────────────────────────────────────────────────────────

class _BudgetTile extends StatelessWidget {
  const _BudgetTile({required this.budget, required this.category});

  final Budget budget;
  final Category? category;

  @override
  Widget build(BuildContext context) {
    final progress = budget.progress.clamp(0.0, 1.0);
    final overspent = budget.progress > 1.0;
    final warn = budget.progress >= 0.8;
    final barColor = _progressColor(budget.progress);
    final categoryColor = _parseColor(category?.color);
    final categoryName = category?.name ?? 'Categoría eliminada';
    final icon = category?.icon ?? '📦';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: categoryColor.withValues(alpha: 0.15),
                  child: Text(icon, style: const TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        categoryName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_money(budget.spentAmount)} de ${_money(budget.limitAmount)}',
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (warn)
                  Tooltip(
                    message: overspent
                        ? 'Presupuesto superado'
                        : 'Cerca del límite',
                    child: Icon(
                      overspent ? Icons.error : Icons.warning_amber_rounded,
                      color: barColor,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 10,
                backgroundColor: barColor.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(budget.progress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                      color: barColor, fontWeight: FontWeight.w600),
                ),
                Text(
                  overspent
                      ? 'Excedido en ${_money(budget.spentAmount - budget.limitAmount)}'
                      : 'Restante ${_money(budget.remainingAmount)}',
                  style: TextStyle(
                    color: overspent
                        ? barColor
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Color _progressColor(double progress) {
  if (progress > 1.0) return const Color(0xFFE53935); // rojo
  if (progress >= 0.8) return const Color(0xFFF9A825); // amarillo
  return const Color(0xFF43A047); // verde
}

Color _parseColor(String? hex) {
  if (hex == null) return Colors.grey;
  try {
    final cleaned = hex.replaceAll('#', '');
    return Color(int.parse('FF$cleaned', radix: 16));
  } catch (_) {
    return Colors.grey;
  }
}

String _money(double v) => '${v.toStringAsFixed(2)} €';

// ── Empty / error states ─────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.pie_chart_outline, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('No hay presupuestos para este mes',
              style: TextStyle(fontSize: 16, color: Colors.grey)),
          SizedBox(height: 4),
          Text('Pulsa + para añadir uno',
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 8),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}

// ── Create budget dialog ─────────────────────────────────────────────────────

class _CreateBudgetDialog extends ConsumerStatefulWidget {
  const _CreateBudgetDialog({
    required this.initialMonth,
    required this.initialYear,
    required this.onCreated,
  });

  final int initialMonth;
  final int initialYear;
  final VoidCallback onCreated;

  @override
  ConsumerState<_CreateBudgetDialog> createState() =>
      _CreateBudgetDialogState();
}

class _CreateBudgetDialogState extends ConsumerState<_CreateBudgetDialog> {
  final _formKey = GlobalKey<FormState>();
  final _limitController = TextEditingController();
  int? _categoryId;
  late int _month;
  late int _year;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _month = widget.initialMonth;
    _year = widget.initialYear;
  }

  @override
  void dispose() {
    _limitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return AlertDialog(
      title: const Text('Nuevo presupuesto'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              categoriesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text('Error cargando categorías: $e'),
                data: (cats) {
                  final expenseCats =
                      cats.where((c) => c.type == 'expense').toList();
                  if (expenseCats.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                          'Crea primero una categoría de tipo "Gasto".'),
                    );
                  }
                  return DropdownButtonFormField<int>(
                    initialValue: _categoryId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Categoría',
                      border: OutlineInputBorder(),
                    ),
                    items: expenseCats
                        .map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Row(
                                children: [
                                  Text(c.icon),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(c.name,
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _categoryId = v),
                    validator: (v) => v == null ? 'Selecciona categoría' : null,
                  );
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _month,
                      decoration: const InputDecoration(
                        labelText: 'Mes',
                        border: OutlineInputBorder(),
                      ),
                      items: List.generate(12, (i) => i + 1)
                          .map((m) => DropdownMenuItem(
                                value: m,
                                child: Text(_monthName(m)),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _month = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _year,
                      decoration: const InputDecoration(
                        labelText: 'Año',
                        border: OutlineInputBorder(),
                      ),
                      items: _yearOptions(_year)
                          .map((y) => DropdownMenuItem(
                                value: y,
                                child: Text('$y'),
                              ))
                          .toList(),
                      onChanged: (v) => setState(() => _year = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _limitController,
                decoration: const InputDecoration(
                  labelText: 'Límite (€)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: false),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Campo requerido';
                  final parsed = double.tryParse(v.replaceAll(',', '.'));
                  if (parsed == null || parsed <= 0) {
                    return 'Introduce un importe mayor que 0';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Crear'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) return;

    setState(() => _loading = true);
    final api = ref.read(apiClientProvider);
    try {
      await api.createBudget({
        'category_id': _categoryId,
        'month': _month,
        'year': _year,
        'limit_amount':
            double.parse(_limitController.text.replaceAll(',', '.')),
      });
      widget.onCreated();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al crear: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

String _monthName(int m) => const [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ][m - 1];

List<int> _yearOptions(int current) {
  final now = DateTime.now().year;
  final start = (current < now ? current : now) - 2;
  final end = (current > now ? current : now) + 5;
  return [for (var y = start; y <= end; y++) y];
}
