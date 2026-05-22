import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:diruzorro/models/models.dart';
import 'package:diruzorro/providers/providers.dart';

class AccountsView extends ConsumerWidget {
  const AccountsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuentas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.label_outline),
            tooltip: 'Categorías',
            onPressed: () => context.push('/categories'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context, ref),
        tooltip: 'Nueva cuenta',
        child: const Icon(Icons.add),
      ),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 8),
              Text('Error al cargar cuentas', style: Theme.of(context).textTheme.bodyMedium),
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
          if (accounts.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No hay cuentas todavía', style: TextStyle(fontSize: 16, color: Colors.grey)),
                  SizedBox(height: 4),
                  Text('Pulsa + para añadir una', style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(accountsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: accounts.length,
              itemBuilder: (context, index) => _AccountTile(
                account: accounts[index],
                onDeleted: () => ref.invalidate(accountsProvider),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (_) => _CreateAccountDialog(
        onCreated: () => ref.invalidate(accountsProvider),
      ),
    );
  }
}

// ── Account tile with swipe-to-delete ────────────────────────────────────────

class _AccountTile extends ConsumerWidget {
  const _AccountTile({required this.account, required this.onDeleted});

  final Account account;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final balanceColor = account.balance < 0 ? Colors.red : Colors.green.shade700;
    final formatter = NumberFormat.currency(locale: 'es_ES', symbol: account.currency);

    return Dismissible(
      key: ValueKey(account.id),
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
            title: const Text('Eliminar cuenta'),
            content: Text('¿Eliminar "${account.name}"? Esta acción no se puede deshacer.'),
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
          await api.deleteAccount(account.id);
          onDeleted();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('"${account.name}" eliminada')),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: Colors.red),
            );
          }
        }
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: colorScheme.primaryContainer,
            child: Icon(_accountIcon(account.type), color: colorScheme.primary),
          ),
          title: Text(account.name, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(_accountTypeLabel(account.type)),
          trailing: Text(
            formatter.format(account.balance),
            style: TextStyle(fontWeight: FontWeight.bold, color: balanceColor, fontSize: 16),
          ),
        ),
      ),
    );
  }

  IconData _accountIcon(String type) => switch (type) {
        'savings' => Icons.savings_outlined,
        'credit' => Icons.credit_card,
        _ => Icons.account_balance_outlined,
      };

  String _accountTypeLabel(String type) => switch (type) {
        'checking' => 'Cuenta corriente',
        'savings' => 'Cuenta de ahorro',
        'credit' => 'Tarjeta de crédito',
        _ => type,
      };
}

// ── Create account dialog ─────────────────────────────────────────────────────

class _CreateAccountDialog extends ConsumerStatefulWidget {
  const _CreateAccountDialog({required this.onCreated});

  final VoidCallback onCreated;

  @override
  ConsumerState<_CreateAccountDialog> createState() => _CreateAccountDialogState();
}

class _CreateAccountDialogState extends ConsumerState<_CreateAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController(text: '0');
  String _type = 'checking';
  String _currency = 'EUR';
  bool _loading = false;

  static const _accountTypes = [
    ('checking', 'Cuenta corriente'),
    ('savings', 'Cuenta de ahorro'),
    ('credit', 'Tarjeta de crédito'),
  ];

  static const _currencies = ['EUR', 'USD', 'GBP'];

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva cuenta'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder()),
                textCapitalization: TextCapitalization.sentences,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Tipo', border: OutlineInputBorder()),
                items: _accountTypes
                    .map((t) => DropdownMenuItem(value: t.$1, child: Text(t.$2)))
                    .toList(),
                onChanged: (v) => setState(() => _type = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _currency,
                decoration: const InputDecoration(labelText: 'Moneda', border: OutlineInputBorder()),
                items: _currencies
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _currency = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _balanceController,
                decoration: const InputDecoration(labelText: 'Saldo inicial', border: OutlineInputBorder()),
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Campo requerido';
                  if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Número inválido';
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
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Crear'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    final api = ref.read(apiClientProvider);

    try {
      await api.createAccount({
        'name': _nameController.text.trim(),
        'type': _type,
        'currency': _currency,
        'balance': double.parse(_balanceController.text.replaceAll(',', '.')),
      });
      widget.onCreated();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al crear la cuenta: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
