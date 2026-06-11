import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:diruzorro/models/models.dart';
import 'package:diruzorro/providers/providers.dart';

class TransactionsView extends ConsumerStatefulWidget {
  const TransactionsView({super.key});

  @override
  ConsumerState<TransactionsView> createState() => _TransactionsViewState();
}

class _TransactionsViewState extends ConsumerState<TransactionsView> {
  DateTimeRange? _dateRange;
  int? _filterCategoryId;
  int? _filterAccountId;

  bool get _hasFilters =>
      _dateRange != null || _filterCategoryId != null || _filterAccountId != null;

  List<Transaction> _applyFilters(List<Transaction> transactions) {
    return transactions.where((t) {
      if (_dateRange != null) {
        final date = DateTime.tryParse(t.date);
        if (date == null) return false;
        final start = _dateRange!.start;
        final end = _dateRange!.end;
        if (date.isBefore(DateTime(start.year, start.month, start.day)) ||
            date.isAfter(DateTime(end.year, end.month, end.day, 23, 59, 59))) {
          return false;
        }
      }
      if (_filterCategoryId != null && t.categoryId != _filterCategoryId) {
        return false;
      }
      if (_filterAccountId != null && t.accountId != _filterAccountId) {
        return false;
      }
      return true;
    }).toList();
  }

  void _clearFilters() => setState(() {
        _dateRange = null;
        _filterCategoryId = null;
        _filterAccountId = null;
      });

  void _openFilters(
    BuildContext context,
    List<Category> categories,
    List<Account> accounts,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _FilterSheet(
        categories: categories,
        accounts: accounts,
        initialDateRange: _dateRange,
        initialCategoryId: _filterCategoryId,
        initialAccountId: _filterAccountId,
        onApply: (dr, catId, accId) => setState(() {
          _dateRange = dr;
          _filterCategoryId = catId;
          _filterAccountId = accId;
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final accountsAsync = ref.watch(accountsProvider);

    final categoryMap = <int, Category>{};
    categoriesAsync.whenData((cats) {
      for (final c in cats) { categoryMap[c.id] = c; }
    });

    final accountMap = <int, Account>{};
    accountsAsync.whenData((accs) {
      for (final a in accs) { accountMap[a.id] = a; }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Movimientos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Importar CSV',
            onPressed: () async {
              await context.push('/transactions/import');
              ref.invalidate(transactionsProvider);
            },
          ),
          IconButton(
            icon: Icon(
              Icons.filter_list,
              color: _hasFilters ? Theme.of(context).colorScheme.primary : null,
            ),
            tooltip: 'Filtrar',
            onPressed: () => _openFilters(
              context,
              switch (categoriesAsync) {
                AsyncData(:final value) => value,
                _ => const <Category>[],
              },
              switch (accountsAsync) {
                AsyncData(:final value) => value,
                _ => const <Account>[],
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push('/transactions/new');
          ref.invalidate(transactionsProvider);
        },
        tooltip: 'Nueva transacción',
        child: const Icon(Icons.add),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_hasFilters)
            _ActiveFiltersBar(
              dateRange: _dateRange,
              categoryId: _filterCategoryId,
              accountId: _filterAccountId,
              categoryMap: categoryMap,
              accountMap: accountMap,
              onClearDate: () => setState(() => _dateRange = null),
              onClearCategory: () => setState(() => _filterCategoryId = null),
              onClearAccount: () => setState(() => _filterAccountId = null),
              onClearAll: _clearFilters,
            ),
          Expanded(
            child: transactionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 8),
                    Text('Error al cargar transacciones',
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => ref.invalidate(transactionsProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
              data: (transactions) {
                final sorted = [...transactions]
                  ..sort((a, b) => b.date.compareTo(a.date));
                final filtered = _applyFilters(sorted);

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.receipt_long_outlined,
                            size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          _hasFilters
                              ? 'Sin resultados para los filtros aplicados'
                              : 'No hay transacciones todavía',
                          style: const TextStyle(
                              fontSize: 16, color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        if (!_hasFilters)
                          const Text('Pulsa + para añadir una',
                              style: TextStyle(color: Colors.grey)),
                        if (_hasFilters) ...[
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: _clearFilters,
                            icon: const Icon(Icons.filter_list_off),
                            label: const Text('Quitar filtros'),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(transactionsProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) => _TransactionTile(
                      transaction: filtered[index],
                      category: filtered[index].categoryId != null
                          ? categoryMap[filtered[index].categoryId]
                          : null,
                      onDeleted: () => ref.invalidate(transactionsProvider),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Transaction tile with swipe-to-delete ────────────────────────────────────

class _TransactionTile extends ConsumerWidget {
  const _TransactionTile({
    required this.transaction,
    required this.category,
    required this.onDeleted,
  });

  final Transaction transaction;
  final Category? category;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isIncome = transaction.type == 'income';
    final isTransfer = transaction.type == 'transfer';
    final amountColor = isIncome
        ? Colors.green.shade700
        : isTransfer
            ? Colors.blue.shade700
            : Colors.red.shade700;
    final sign = isIncome ? '+' : '';
    final formatter = NumberFormat.currency(locale: 'es_ES', symbol: '€');
    final catColor = category != null ? _parseColor(category!.color) : Colors.grey;

    return Dismissible(
      key: ValueKey(transaction.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        color: Colors.red,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Eliminar transacción'),
            content: const Text(
                '¿Eliminar esta transacción? Esta acción no se puede deshacer.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) async {
        final api = ref.read(apiClientProvider);
        try {
          await api.deleteTransaction(transaction.id);
          onDeleted();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Transacción eliminada')),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('Error al eliminar: $e'),
                  backgroundColor: Colors.red),
            );
          }
        }
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: catColor.withValues(alpha: 0.15),
            child: category != null
                ? Text(category!.icon, style: const TextStyle(fontSize: 18))
                : Icon(_typeIcon(transaction.type), color: catColor, size: 20),
          ),
          title: Text(
            transaction.description.isNotEmpty
                ? transaction.description
                : _typeLabel(transaction.type),
            style: const TextStyle(fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            [
              if (category != null) category!.name,
              _formatDate(transaction.date),
            ].join(' · '),
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          trailing: Text(
            '$sign${formatter.format(transaction.amount)}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: amountColor,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      final cleaned = hex.replaceAll('#', '');
      return Color(int.parse('FF$cleaned', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }

  IconData _typeIcon(String type) => switch (type) {
        'income' => Icons.arrow_downward,
        'transfer' => Icons.swap_horiz,
        _ => Icons.arrow_upward,
      };

  String _typeLabel(String type) => switch (type) {
        'income' => 'Ingreso',
        'transfer' => 'Transferencia',
        _ => 'Gasto',
      };

  String _formatDate(String isoDate) {
    try {
      return DateFormat('dd/MM/yyyy').format(DateTime.parse(isoDate));
    } catch (_) {
      return isoDate;
    }
  }
}

// ── Create transaction screen ────────────────────────────────────────────────

class CreateTransactionView extends ConsumerStatefulWidget {
  const CreateTransactionView({super.key});

  @override
  ConsumerState<CreateTransactionView> createState() =>
      _CreateTransactionViewState();
}

class _CreateTransactionViewState
    extends ConsumerState<CreateTransactionView> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  late final TextEditingController _dateController;

  String _type = 'expense';
  int? _accountId;
  int? _categoryId;
  DateTime _date = DateTime.now();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _dateController =
        TextEditingController(text: DateFormat('dd/MM/yyyy').format(_date));
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva transacción'),
        actions: [
          FilledButton(
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Guardar'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Type chips
            _TypeSelector(
              value: _type,
              onChanged: (v) => setState(() {
                _type = v;
                _categoryId = null;
              }),
            ),
            const SizedBox(height: 16),
            // Amount
            TextFormField(
              controller: _amountController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Importe',
                prefixText: '€ ',
                border: OutlineInputBorder(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Campo requerido';
                final parsed = double.tryParse(v.replaceAll(',', '.'));
                if (parsed == null || parsed <= 0) {
                  return 'Introduce un importe positivo';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Account
            accountsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error cargando cuentas: $e'),
              data: (accounts) => DropdownButtonFormField<int>(
                initialValue: _accountId,
                decoration: const InputDecoration(
                  labelText: 'Cuenta',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                ),
                items: accounts
                    .map((a) =>
                        DropdownMenuItem(value: a.id, child: Text(a.name)))
                    .toList(),
                onChanged: (v) => setState(() => _accountId = v),
                validator: (v) =>
                    v == null ? 'Selecciona una cuenta' : null,
              ),
            ),
            const SizedBox(height: 16),
            // Category (hidden for transfers)
            if (_type != 'transfer') ...[
              categoriesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
                data: (categories) {
                  final filtered =
                      categories.where((c) => c.type == _type).toList();
                  return DropdownButtonFormField<int>(
                    key: ValueKey(_type),
                    initialValue: _categoryId,
                    decoration: const InputDecoration(
                      labelText: 'Categoría (opcional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.label_outline),
                    ),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('Sin categoría')),
                      ...filtered.map((c) => DropdownMenuItem(
                            value: c.id,
                            child: Row(children: [
                              Text(c.icon),
                              const SizedBox(width: 8),
                              Text(c.name),
                            ]),
                          )),
                    ],
                    onChanged: (v) => setState(() => _categoryId = v),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
            // Date
            TextFormField(
              controller: _dateController,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Fecha',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.calendar_today),
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() {
                    _date = picked;
                    _dateController.text =
                        DateFormat('dd/MM/yyyy').format(_date);
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes),
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    final api = ref.read(apiClientProvider);

    try {
      await api.createTransaction({
        'account_id': _accountId,
        'type': _type,
        'amount': double.parse(_amountController.text.replaceAll(',', '.')),
        if (_categoryId != null) 'category_id': _categoryId,
        'date': DateFormat('yyyy-MM-dd').format(_date),
        'description': _descriptionController.text.trim(),
      });
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error al crear la transacción: $e'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ── Type selector (segmented button row) ─────────────────────────────────────

class _TypeSelector extends StatelessWidget {
  const _TypeSelector({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(
          value: 'expense',
          label: Text('Gasto'),
          icon: Icon(Icons.arrow_upward),
        ),
        ButtonSegment(
          value: 'income',
          label: Text('Ingreso'),
          icon: Icon(Icons.arrow_downward),
        ),
        ButtonSegment(
          value: 'transfer',
          label: Text('Transferencia'),
          icon: Icon(Icons.swap_horiz),
        ),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
      style: ButtonStyle(
        iconColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return value == 'income'
                ? Colors.green.shade700
                : value == 'transfer'
                    ? Colors.blue.shade700
                    : Colors.red.shade700;
          }
          return null;
        }),
      ),
    );
  }
}

// ── Active filters bar ────────────────────────────────────────────────────────

class _ActiveFiltersBar extends StatelessWidget {
  const _ActiveFiltersBar({
    required this.dateRange,
    required this.categoryId,
    required this.accountId,
    required this.categoryMap,
    required this.accountMap,
    required this.onClearDate,
    required this.onClearCategory,
    required this.onClearAccount,
    required this.onClearAll,
  });

  final DateTimeRange? dateRange;
  final int? categoryId;
  final int? accountId;
  final Map<int, Category> categoryMap;
  final Map<int, Account> accountMap;
  final VoidCallback onClearDate;
  final VoidCallback onClearCategory;
  final VoidCallback onClearAccount;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yy');
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (dateRange != null)
                    Chip(
                      avatar: const Icon(Icons.calendar_today, size: 14),
                      label: Text(
                          '${fmt.format(dateRange!.start)} – ${fmt.format(dateRange!.end)}'),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: onClearDate,
                    ),
                  if (categoryId != null)
                    Chip(
                      avatar: categoryMap[categoryId] != null
                          ? Text(categoryMap[categoryId]!.icon,
                              style: const TextStyle(fontSize: 14))
                          : const Icon(Icons.label_outline, size: 14),
                      label: Text(categoryMap[categoryId]?.name ?? 'Categoría'),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: onClearCategory,
                    ),
                  if (accountId != null)
                    Chip(
                      avatar: const Icon(
                          Icons.account_balance_wallet_outlined, size: 14),
                      label: Text(accountMap[accountId]?.name ?? 'Cuenta'),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: onClearAccount,
                    ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.filter_list_off),
              tooltip: 'Limpiar filtros',
              iconSize: 20,
              onPressed: onClearAll,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Filter bottom sheet ───────────────────────────────────────────────────────

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.categories,
    required this.accounts,
    required this.initialDateRange,
    required this.initialCategoryId,
    required this.initialAccountId,
    required this.onApply,
  });

  final List<Category> categories;
  final List<Account> accounts;
  final DateTimeRange? initialDateRange;
  final int? initialCategoryId;
  final int? initialAccountId;
  final void Function(DateTimeRange?, int?, int?) onApply;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  DateTimeRange? _dateRange;
  int? _categoryId;
  int? _accountId;
  late final TextEditingController _startCtrl;
  late final TextEditingController _endCtrl;
  final _fmt = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _dateRange = widget.initialDateRange;
    _categoryId = widget.initialCategoryId;
    _accountId = widget.initialAccountId;
    _startCtrl = TextEditingController(
        text: _dateRange != null ? _fmt.format(_dateRange!.start) : '');
    _endCtrl = TextEditingController(
        text: _dateRange != null ? _fmt.format(_dateRange!.end) : '');
  }

  @override
  void dispose() {
    _startCtrl.dispose();
    _endCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _dateRange ??
          DateTimeRange(
            start: DateTime(now.year, now.month, 1),
            end: now,
          ),
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _dateRange = picked;
        _startCtrl.text = _fmt.format(picked.start);
        _endCtrl.text = _fmt.format(picked.end);
      });
    }
  }

  void _clearDateRange() => setState(() {
        _dateRange = null;
        _startCtrl.clear();
        _endCtrl.clear();
      });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Text('Filtros', style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() {
                  _dateRange = null;
                  _categoryId = null;
                  _accountId = null;
                  _startCtrl.clear();
                  _endCtrl.clear();
                }),
                child: const Text('Limpiar todo'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Date range
          Text('Rango de fechas',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _startCtrl,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Desde',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onTap: _pickDateRange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _endCtrl,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Hasta',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onTap: _pickDateRange,
                ),
              ),
              if (_dateRange != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _clearDateRange,
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),

          // Category
          Text('Categoría', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          DropdownButtonFormField<int?>(
            initialValue: _categoryId,
            isExpanded: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.label_outline),
              isDense: true,
            ),
            hint: const Text('Todas las categorías'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Todas')),
              ...widget.categories.map((c) => DropdownMenuItem(
                    value: c.id,
                    child: Row(children: [
                      Text(c.icon),
                      const SizedBox(width: 8),
                      Expanded(child: Text(c.name, overflow: TextOverflow.ellipsis)),
                    ]),
                  )),
            ],
            onChanged: (v) => setState(() => _categoryId = v),
          ),
          const SizedBox(height: 20),

          // Account
          Text('Cuenta', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          DropdownButtonFormField<int?>(
            initialValue: _accountId,
            isExpanded: true,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              prefixIcon:
                  Icon(Icons.account_balance_wallet_outlined),
              isDense: true,
            ),
            hint: const Text('Todas las cuentas'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Todas')),
              ...widget.accounts.map((a) => DropdownMenuItem(
                    value: a.id,
                    child: Text(a.name),
                  )),
            ],
            onChanged: (v) => setState(() => _accountId = v),
          ),
          const SizedBox(height: 24),

          // Apply button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                widget.onApply(_dateRange, _categoryId, _accountId);
                Navigator.pop(context);
              },
              child: const Text('Aplicar filtros'),
            ),
          ),
        ],
        ),
      ),
    );
  }
}
