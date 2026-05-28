import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:diruzorro/models/models.dart';
import 'package:diruzorro/providers/providers.dart';

// ── Screen ───────────────────────────────────────────────────────────────────

class SavingsView extends ConsumerWidget {
  const SavingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsAsync = ref.watch(savingsGoalsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Objetivos de Ahorro'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context, ref),
        tooltip: 'Nuevo objetivo',
        child: const Icon(Icons.add),
      ),
      body: goalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(
          message: 'Error al cargar los objetivos',
          onRetry: () => ref.invalidate(savingsGoalsProvider),
        ),
        data: (goals) {
          if (goals.isEmpty) {
            return const _EmptyState();
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(savingsGoalsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 80),
              itemCount: goals.length,
              itemBuilder: (context, index) {
                final goal = goals[index];
                return _GoalCard(
                  goal: goal,
                  onAddProgress: () =>
                      _showAddProgressDialog(context, ref, goal),
                  onDelete: () => _deleteGoal(context, ref, goal),
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (_) => _CreateGoalDialog(
        onCreated: () => ref.invalidate(savingsGoalsProvider),
      ),
    );
  }

  void _showAddProgressDialog(
      BuildContext context, WidgetRef ref, SavingsGoal goal) {
    showDialog<void>(
      context: context,
      builder: (_) => _AddProgressDialog(
        goal: goal,
        onUpdated: () => ref.invalidate(savingsGoalsProvider),
      ),
    );
  }

  Future<void> _deleteGoal(
      BuildContext context, WidgetRef ref, SavingsGoal goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar objetivo'),
        content: Text('¿Eliminar "${goal.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    try {
      final api = ref.read(apiClientProvider);
      await api.deleteSavingsGoal(goal.id);
      ref.invalidate(savingsGoalsProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar: $e')),
      );
    }
  }
}

// ── Goal card ────────────────────────────────────────────────────────────────

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goal,
    required this.onAddProgress,
    required this.onDelete,
  });

  final SavingsGoal goal;
  final VoidCallback onAddProgress;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final progress = goal.progress.clamp(0.0, 1.0);
    final completed = goal.progress >= 1.0;
    final barColor = completed
        ? const Color(0xFF43A047) // verde completado
        : Theme.of(context).colorScheme.primary;

    return Dismissible(
      key: ValueKey(goal.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false; // la eliminación real la gestiona onDelete
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: completed ? null : onAddProgress,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor:
                          barColor.withValues(alpha: 0.15),
                      child: Icon(
                        completed
                            ? Icons.check_circle
                            : Icons.savings_outlined,
                        color: barColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            goal.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15),
                          ),
                          if (goal.targetDate != null)
                            Text(
                              'Meta: ${_formatDate(goal.targetDate!)}',
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
                    if (completed)
                      Chip(
                        label: const Text('Completado'),
                        backgroundColor:
                            const Color(0xFF43A047).withValues(alpha: 0.15),
                        labelStyle:
                            const TextStyle(color: Color(0xFF43A047)),
                        side: BorderSide.none,
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        tooltip: 'Añadir progreso',
                        onPressed: onAddProgress,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: barColor.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(barColor),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_money(goal.currentAmount)} / ${_money(goal.targetAmount)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    Text(
                      '${(goal.progress * 100).clamp(0, 999).toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: barColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatDate(String iso) {
  try {
    final parts = iso.split('-');
    if (parts.length < 3) return iso;
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  } catch (_) {
    return iso;
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
          Icon(Icons.savings_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Sin objetivos de ahorro todavía',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          SizedBox(height: 4),
          Text('Pulsa + para crear tu primer objetivo',
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

// ── Create goal dialog ───────────────────────────────────────────────────────

class _CreateGoalDialog extends ConsumerStatefulWidget {
  const _CreateGoalDialog({required this.onCreated});

  final VoidCallback onCreated;

  @override
  ConsumerState<_CreateGoalDialog> createState() => _CreateGoalDialogState();
}

class _CreateGoalDialogState extends ConsumerState<_CreateGoalDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _targetController = TextEditingController();
  DateTime? _targetDate;
  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo objetivo de ahorro'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  hintText: 'Ej: Vacaciones, Fondo emergencia…',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Escribe un nombre' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _targetController,
                decoration: const InputDecoration(
                  labelText: 'Cantidad objetivo (€)',
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Introduce una cantidad';
                  final parsed = double.tryParse(v.replaceAll(',', '.'));
                  if (parsed == null || parsed <= 0) return 'Cantidad inválida';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: Text(
                  _targetDate == null
                      ? 'Fecha objetivo (opcional)'
                      : _formatDate(
                          '${_targetDate!.year}-${_targetDate!.month.toString().padLeft(2, '0')}-${_targetDate!.day.toString().padLeft(2, '0')}'),
                ),
                trailing: _targetDate != null
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Quitar fecha',
                        onPressed: () =>
                            setState(() => _targetDate = null),
                      )
                    : null,
                onTap: _pickDate,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
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

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      helpText: 'Fecha objetivo',
    );
    if (picked != null) setState(() => _targetDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final data = <String, dynamic>{
        'name': _nameController.text.trim(),
        'target_amount':
            double.parse(_targetController.text.replaceAll(',', '.')),
        if (_targetDate != null)
          'target_date':
              '${_targetDate!.year}-${_targetDate!.month.toString().padLeft(2, '0')}-${_targetDate!.day.toString().padLeft(2, '0')}',
      };
      await api.createSavingsGoal(data);
      widget.onCreated();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al crear objetivo: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ── Add progress dialog ──────────────────────────────────────────────────────

class _AddProgressDialog extends ConsumerStatefulWidget {
  const _AddProgressDialog({required this.goal, required this.onUpdated});

  final SavingsGoal goal;
  final VoidCallback onUpdated;

  @override
  ConsumerState<_AddProgressDialog> createState() => _AddProgressDialogState();
}

class _AddProgressDialogState extends ConsumerState<_AddProgressDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = (widget.goal.targetAmount - widget.goal.currentAmount)
        .clamp(0.0, double.infinity);

    return AlertDialog(
      title: Text('Añadir a "${widget.goal.name}"'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Actual: ${_money(widget.goal.currentAmount)} / ${_money(widget.goal.targetAmount)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              'Falta: ${_money(remaining)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Cantidad a añadir (€)',
                border: OutlineInputBorder(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Introduce una cantidad';
                final parsed = double.tryParse(v.replaceAll(',', '.'));
                if (parsed == null || parsed <= 0) return 'Cantidad inválida';
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
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
              : const Text('Añadir'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final added =
          double.parse(_amountController.text.replaceAll(',', '.'));
      final newAmount = widget.goal.currentAmount + added;
      await api.updateSavingsGoal(widget.goal.id, {'current_amount': newAmount});
      widget.onUpdated();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
