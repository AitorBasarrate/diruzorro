import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:diruzorro/models/models.dart';
import 'package:diruzorro/providers/providers.dart';

class ParsedTransaction {
  final int index;
  bool isSelected;
  DateTime date;
  double amount;
  String type; // 'expense' or 'income'
  String description;
  int? categoryId;

  ParsedTransaction({
    required this.index,
    this.isSelected = true,
    required this.date,
    required this.amount,
    required this.type,
    required this.description,
    this.categoryId,
  });
}

class _SkippedRow {
  final int rowNumber; // 1-based CSV row (excluding header)
  final String rawLine;
  final String reason;

  _SkippedRow({
    required this.rowNumber,
    required this.rawLine,
    required this.reason,
  });
}

class CsvImportView extends ConsumerStatefulWidget {
  const CsvImportView({super.key});

  @override
  ConsumerState<CsvImportView> createState() => _CsvImportViewState();
}

class _CsvImportViewState extends ConsumerState<CsvImportView> {
  int _currentStep =
      0; // 0: Config & Mapping, 1: Preview & Edit, 2: Importing Progress

  // Step 0 states
  String? _fileName;
  List<List<dynamic>> _rawLines = [];
  List<String> _headers = [];
  int? _targetAccountId;
  int? _dateColumnIndex;
  int? _amountColumnIndex;
  int? _descriptionColumnIndex;
  String _dateFormat = 'dd/MM/yyyy';
  String _decimalSeparator = ',';

  // Step 1 states
  List<ParsedTransaction> _preparedTransactions = [];
  String _searchQuery = '';
  final _searchController = TextEditingController();

  // Step 2 states
  bool _isImporting = false;
  int _importTotal = 0;
  int _importSuccess = 0;
  int _importFailed = 0;
  final List<String> _importErrors = [];
  List<_SkippedRow> _skippedRows = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'txt'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes;
        if (bytes == null) {
          throw Exception("No se pudieron leer los datos del archivo");
        }

        final content = utf8.decode(bytes, allowMalformed: true);

        // Guess delimiter: semicolon or comma
        String delimiter = ',';
        final firstLine = content.split('\n').firstOrNull ?? '';
        if (firstLine.contains(';')) {
          delimiter = ';';
        } else if (firstLine.contains('\t')) {
          delimiter = '\t';
        }

        final csv = Csv(
          fieldDelimiter: delimiter,
        );

        final rows = csv.decode(content);
        if (rows.isEmpty) {
          throw Exception("El archivo CSV está vacío");
        }

        setState(() {
          _fileName = file.name;
          _rawLines = rows;
          _headers = rows.first.map((e) => e.toString().trim()).toList();

          // Reset mapping selections
          _dateColumnIndex = null;
          _amountColumnIndex = null;
          _descriptionColumnIndex = null;

          // Auto-guessing columns based on names
          for (int i = 0; i < _headers.length; i++) {
            final h = _headers[i].toLowerCase();
            if (_dateColumnIndex == null &&
                (h.contains('fecha') ||
                    h.contains('date') ||
                    h.contains('día') ||
                    h.contains('dia'))) {
              _dateColumnIndex = i;
            }
            if (_amountColumnIndex == null &&
                (h.contains('importe') ||
                    h.contains('cantidad') ||
                    h.contains('amount') ||
                    h.contains('valor') ||
                    h.contains('suma') ||
                    h.contains('total') ||
                    h.contains('monto'))) {
              _amountColumnIndex = i;
            }
            if (_descriptionColumnIndex == null &&
                (h.contains('concepto') ||
                    h.contains('descrip') ||
                    h.contains('desc') ||
                    h.contains('detalle') ||
                    h.contains('referencia') ||
                    h.contains('memo'))) {
              _descriptionColumnIndex = i;
            }
          }

          // Fallbacks
          if (_headers.isNotEmpty) {
            _dateColumnIndex ??= 0;
            if (_headers.length > 1) {
              _amountColumnIndex ??= 1;
            }
            if (_headers.length > 2) {
              _descriptionColumnIndex ??= 2;
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al leer el archivo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  DateTime? _parseDateString(String raw, String format) {
    try {
      raw = raw.trim();
      final parts = raw.split(RegExp(r'[\/\-\.]'));
      if (parts.length < 3) return null;

      if (format == 'dd/MM/yyyy' || format == 'dd-MM-yyyy') {
        int day = int.parse(parts[0]);
        int month = int.parse(parts[1]);
        int year = int.parse(parts[2]);
        if (year < 100) year += 2000;
        return DateTime(year, month, day);
      } else if (format == 'yyyy-MM-dd') {
        int year = int.parse(parts[0]);
        int month = int.parse(parts[1]);
        int day = int.parse(parts[2]);
        return DateTime(year, month, day);
      }
    } catch (_) {}
    return DateTime.tryParse(raw);
  }

  double? _parseAmountString(String raw, String decimalSeparator) {
    try {
      // 1. Limpieza inicial: conservar solo dígitos, comas, puntos y signos
      String cleaned = raw.replaceAll(RegExp(r'[^\d,\.\-\+]'), '').trim();
      if (cleaned.isEmpty) return null;

      // 2. Detectar y guardar el signo
      bool isNegative = cleaned.startsWith('-');
      cleaned = cleaned.replaceAll(RegExp(r'[\-\+]'), '');

      // 3. Normalizar el formato numérico para Dart (que espera obligatoriamente un '.')
      if (decimalSeparator == ',') {
        // Si el separador decimal es la coma, el punto actúa como separador de miles.
        // Los eliminamos para que no rompa el parser.
        cleaned = cleaned.replaceAll('.', '');
        // Cambiamos la coma decimal por el punto que entiende Dart
        cleaned = cleaned.replaceAll(',', '.');
      } else {
        // Si el separador decimal es el punto, la coma actúa como separador de miles.
        // Eliminamos las comas de miles.
        cleaned = cleaned.replaceAll(',', '');
      }

      // 4. Parsear de forma segura
      double? val = double.tryParse(cleaned);

      if (val != null && isNegative) {
        val = -val;
      }
      return val;
    } catch (_) {
      return null;
    }
  }

  void _prepareTransactions() {
    if (_dateColumnIndex == null ||
        _amountColumnIndex == null ||
        _targetAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Selecciona una cuenta y mapea las columnas de Fecha e Importe.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final List<ParsedTransaction> parsedList = [];
    final List<_SkippedRow> skippedList = [];
    for (int i = 1; i < _rawLines.length; i++) {
      final row = _rawLines[i];
      // Skip fully empty rows
      if (row.isEmpty || row.every((cell) => cell.toString().trim().isEmpty)) {
        continue;
      }

        String rowLabel() => row
          .take(3)
          .map((e) => e.toString().trim())
          .where((s) => s.isNotEmpty)
          .join(' | ');

      if (row.length <= _dateColumnIndex! ||
          row.length <= _amountColumnIndex!) {
        skippedList.add(_SkippedRow(
          rowNumber: i,
          rawLine: rowLabel(),
          reason:
              'Fila con columnas insuficientes (${row.length} columnas, se necesitan al menos ${[_dateColumnIndex!, _amountColumnIndex!].reduce((a, b) => a > b ? a : b) + 1})',
        ));
        continue;
      }

      final rawDate = row[_dateColumnIndex!].toString();
      final rawAmount = row[_amountColumnIndex!].toString();
      final rawDescription = _descriptionColumnIndex != null &&
              row.length > _descriptionColumnIndex!
          ? row[_descriptionColumnIndex!].toString()
          : '';

      final parsedDate = _parseDateString(rawDate, _dateFormat);
      final parsedAmount = _parseAmountString(rawAmount, _decimalSeparator);

      if (parsedDate == null) {
        skippedList.add(_SkippedRow(
          rowNumber: i,
          rawLine: rowLabel(),
          reason:
              'Fecha no válida: "$rawDate" (formato esperado: $_dateFormat)',
        ));
        continue;
      }
      if (parsedAmount == null) {
        skippedList.add(_SkippedRow(
          rowNumber: i,
          rawLine: rowLabel(),
          reason:
              'Importe no válido: "$rawAmount" (separador decimal: "$_decimalSeparator")',
        ));
        continue;
      }

      final type = parsedAmount < 0 ? 'expense' : 'income';
      final absAmount = parsedAmount.abs();

      parsedList.add(ParsedTransaction(
        index: i,
        date: parsedDate,
        amount: absAmount,
        type: type,
        description: rawDescription.trim(),
      ));
    }

    if (parsedList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'No se pudieron procesar transacciones del archivo. Comprueba las columnas mapeadas y formatos.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _preparedTransactions = parsedList;
      _skippedRows = skippedList;
      _currentStep = 1;
    });
  }

  String _extractErrorMessage(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        final msg = data['error'] ?? data['message'];
        if (msg != null) return msg.toString();
      }
      if (data is String && data.trim().isNotEmpty) return data.trim();
      final code = e.response?.statusCode;
      if (code != null) return 'Error HTTP $code';
      return e.message ?? 'Error de red';
    }
    return e.toString();
  }

  Future<void> _startImport() async {
    final toImport = _preparedTransactions.where((t) => t.isSelected).toList();
    if (toImport.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No hay transacciones seleccionadas para importar.')),
      );
      return;
    }

    setState(() {
      _currentStep = 2;
      _isImporting = true;
      _importTotal = toImport.length;
      _importSuccess = 0;
      _importFailed = 0;
      _importErrors.clear();
    });

    final api = ref.read(apiClientProvider);

    for (final tx in toImport) {
      try {
        await api.createTransaction({
          'account_id': _targetAccountId,
          'type': tx.type,
          'amount': tx.amount,
          if (tx.categoryId != null) 'category_id': tx.categoryId,
          'date': DateFormat('yyyy-MM-dd').format(tx.date),
          'description': tx.description,
        });
        if (mounted) {
          setState(() {
            _importSuccess++;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _importFailed++;
            _importErrors.add(
                'Fila ${tx.index} — "${tx.description.isEmpty ? 'Sin descripción' : tx.description}" '
                '(${DateFormat('dd/MM/yyyy').format(tx.date)}): ${_extractErrorMessage(e)}');
          });
        }
      }
    }

    if (mounted) {
      setState(() {
        _isImporting = false;
      });
    }
  }

  void _bulkCategorize(List<Category> categories) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Categorización en masa',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Selecciona una categoría para aplicar a todas las transacciones actualmente visibles y seleccionadas.',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  final color = _parseColor(cat.color);
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.15),
                      child:
                          Text(cat.icon, style: const TextStyle(fontSize: 16)),
                    ),
                    title: Text(cat.name),
                    subtitle:
                        Text(cat.type == 'income' ? 'Ingresos' : 'Gastos'),
                    onTap: () {
                      final filtered = _getFilteredTransactions();
                      setState(() {
                        for (var tx in filtered) {
                          if (tx.isSelected && tx.type == cat.type) {
                            tx.categoryId = cat.id;
                          }
                        }
                      });
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ],
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

  List<ParsedTransaction> _getFilteredTransactions() {
    if (_searchQuery.isEmpty) return _preparedTransactions;
    return _preparedTransactions.where((t) {
      return t.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          t.amount.toString().contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Importar desde CSV'),
        leading: _currentStep > 0 && !_isImporting
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() {
                  _currentStep--;
                }),
              )
            : null,
      ),
      body: _buildStepContent(accountsAsync, categoriesAsync),
    );
  }

  Widget _buildStepContent(
    AsyncValue<List<Account>> accountsAsync,
    AsyncValue<List<Category>> categoriesAsync,
  ) {
    switch (_currentStep) {
      case 0:
        return _buildStep0Config(accountsAsync);
      case 1:
        return _buildStep1Preview(categoriesAsync);
      case 2:
      default:
        return _buildStep2Importing();
    }
  }

  // --- Step 0: Selection & Header Mapping UI ---
  Widget _buildStep0Config(AsyncValue<List<Account>> accountsAsync) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Target Account
        accountsAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Card(
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text('Error al cargar las cuentas: $e',
                  style: const TextStyle(color: Colors.red)),
            ),
          ),
          data: (accounts) {
            // Pre-select first account if null
            if (_targetAccountId == null && accounts.isNotEmpty) {
              _targetAccountId = accounts.first.id;
            }
            return DropdownButtonFormField<int>(
              initialValue: _targetAccountId,
              decoration: const InputDecoration(
                labelText: 'Cuenta destino',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.account_balance_wallet_outlined),
              ),
              items: accounts
                  .map(
                      (a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
                  .toList(),
              onChanged: (v) => setState(() => _targetAccountId = v),
            );
          },
        ),
        const SizedBox(height: 20),

        // File picker container
        GestureDetector(
          onTap: _pickFile,
          child: Container(
            height: 180,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              border: Border.all(
                color: _fileName != null
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
                width: 2,
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _fileName != null ? Icons.check_circle : Icons.upload_file,
                    size: 54,
                    color: _fileName != null
                        ? Colors.green.shade600
                        : Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _fileName ?? 'Toca para seleccionar un archivo CSV',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _fileName != null ? Colors.green.shade700 : null,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_fileName == null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Formatos soportados: .csv, .txt',
                      style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.outline),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),

        if (_fileName != null) ...[
          Text('Mapear Columnas',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          // Mapping fields
          DropdownButtonFormField<int>(
            initialValue: _dateColumnIndex,
            decoration: const InputDecoration(
              labelText: 'Columna de Fecha (Requerido)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.calendar_today),
            ),
            items: _headers.asMap().entries.map((e) {
              return DropdownMenuItem(
                  value: e.key, child: Text('[${e.key}] ${e.value}'));
            }).toList(),
            onChanged: (v) => setState(() => _dateColumnIndex = v),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _amountColumnIndex,
            decoration: const InputDecoration(
              labelText: 'Columna de Importe (Requerido)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.monetization_on_outlined),
            ),
            items: _headers.asMap().entries.map((e) {
              return DropdownMenuItem(
                  value: e.key, child: Text('[${e.key}] ${e.value}'));
            }).toList(),
            onChanged: (v) => setState(() => _amountColumnIndex = v),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _descriptionColumnIndex,
            decoration: const InputDecoration(
              labelText: 'Columna de Descripción (Opcional)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.notes),
            ),
            items: [
              const DropdownMenuItem(
                  value: null, child: Text('No mapear (vacío)')),
              ..._headers.asMap().entries.map((e) {
                return DropdownMenuItem(
                    value: e.key, child: Text('[${e.key}] ${e.value}'));
              }),
            ],
            onChanged: (v) => setState(() => _descriptionColumnIndex = v),
          ),
          const SizedBox(height: 20),

          Text('Configuración de Formato',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          // Date format
          DropdownButtonFormField<String>(
            initialValue: _dateFormat,
            decoration: const InputDecoration(
              labelText: 'Formato de fecha',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.date_range_outlined),
            ),
            items: const [
              DropdownMenuItem(
                  value: 'dd/MM/yyyy',
                  child: Text('Día/Mes/Año (Ej. 29/05/2026)')),
              DropdownMenuItem(
                  value: 'dd-MM-yyyy',
                  child: Text('Día-Mes-Año (Ej. 29-05-2026)')),
              DropdownMenuItem(
                  value: 'yyyy-MM-dd',
                  child: Text('Año-Mes-Día (Ej. 2026-05-29)')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _dateFormat = v);
            },
          ),
          const SizedBox(height: 16),
          // Decimal separator
          DropdownButtonFormField<String>(
            initialValue: _decimalSeparator,
            decoration: const InputDecoration(
              labelText: 'Separador decimal de importes',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.data_thresholding_outlined),
            ),
            items: const [
              DropdownMenuItem(value: ',', child: Text('Coma (Ej. -1.250,45)')),
              DropdownMenuItem(value: '.', child: Text('Punto (Ej. -1250.45)')),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _decimalSeparator = v);
            },
          ),
          const SizedBox(height: 32),

          // Next button
          SizedBox(
            height: 50,
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _prepareTransactions,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Analizar y Vista Previa',
                  style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ],
    );
  }

  // --- Step 1: Interactive Preview & Match list ---
  Widget _buildStep1Preview(AsyncValue<List<Category>> categoriesAsync) {
    final filtered = _getFilteredTransactions();
    final categories = categoriesAsync.valueOrNull ?? [];
    final currencyFmt = NumberFormat.currency(locale: 'es_ES', symbol: '€');

    return Column(
      children: [
        // Skipped-rows warning banner
        if (_skippedRows.isNotEmpty) _SkippedRowsBanner(skippedRows: _skippedRows),

        // Bulk action & Search Bar Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: SearchBar(
                      controller: _searchController,
                      hintText: 'Buscar movimientos...',
                      leading: const Icon(Icons.search),
                      onChanged: (v) => setState(() => _searchQuery = v),
                      elevation: const WidgetStatePropertyAll(0),
                      backgroundColor: WidgetStatePropertyAll(
                        Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${filtered.length} seleccionados de ${_preparedTransactions.length}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        icon:
                            const Icon(Icons.label_important_outline, size: 18),
                        label: const Text('Categoría en Masa'),
                        onPressed: categories.isEmpty
                            ? null
                            : () => _bulkCategorize(categories),
                      ),
                      IconButton(
                        tooltip: 'Invertir selección',
                        icon: const Icon(Icons.swap_calls),
                        onPressed: () {
                          setState(() {
                            for (var t in filtered) {
                              t.isSelected = !t.isSelected;
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),

        // Scrollable list of rows
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off_outlined,
                          size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text(
                        'No hay resultados que coincidan',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final tx = filtered[index];
                    final isIncome = tx.type == 'income';
                    final color =
                        isIncome ? Colors.green.shade700 : Colors.red.shade700;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      elevation: tx.isSelected ? 2 : 0,
                      color: tx.isSelected
                          ? null
                          : Theme.of(context)
                              .colorScheme
                              .surfaceContainerLowest
                              .withValues(alpha: 0.5),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Checkbox(
                                  value: tx.isSelected,
                                  onChanged: (v) {
                                    setState(() {
                                      tx.isSelected = v ?? false;
                                    });
                                  },
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Editable Description
                                      TextFormField(
                                        initialValue: tx.description,
                                        onChanged: (v) =>
                                            tx.description = v.trim(),
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          contentPadding:
                                              EdgeInsets.symmetric(vertical: 4),
                                          border: InputBorder.none,
                                          hintText: 'Sin descripción',
                                        ),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        DateFormat('dd/MM/yyyy')
                                            .format(tx.date),
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Amount & Type toggle button
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${isIncome ? "+" : "-"}${currencyFmt.format(tx.amount)}',
                                      style: TextStyle(
                                        color: color,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    // Segmented selector for Gasto vs Ingreso
                                    SizedBox(
                                      height: 28,
                                      child: ToggleButtons(
                                        isSelected: [!isIncome, isIncome],
                                        onPressed: (idx) {
                                          setState(() {
                                            tx.type =
                                                idx == 0 ? 'expense' : 'income';
                                          });
                                        },
                                        borderRadius: BorderRadius.circular(4),
                                        constraints: const BoxConstraints(
                                            minWidth: 42, minHeight: 24),
                                        children: const [
                                          Text('Gasto',
                                              style: TextStyle(fontSize: 10)),
                                          Text('Ingr',
                                              style: TextStyle(fontSize: 10)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Divider(height: 12),
                            // Category Dropdown selector
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                const Text('Categoría: ',
                                    style: TextStyle(
                                        fontSize: 13, color: Colors.grey)),
                                const SizedBox(width: 4),
                                categoriesAsync.when(
                                  loading: () => const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 1.5)),
                                  error: (_, __) => const Text('Error'),
                                  data: (cats) {
                                    final matchCats = cats
                                        .where((c) => c.type == tx.type)
                                        .toList();
                                    return DropdownButton<int?>(
                                      value: tx.categoryId,
                                      isDense: true,
                                      underline: const SizedBox.shrink(),
                                      hint: const Text('Sin categoría',
                                          style: TextStyle(fontSize: 13)),
                                      items: [
                                        const DropdownMenuItem(
                                          value: null,
                                          child: Text('Sin categoría',
                                              style: TextStyle(fontSize: 13)),
                                        ),
                                        ...matchCats.map((c) =>
                                            DropdownMenuItem(
                                              value: c.id,
                                              child: Row(
                                                children: [
                                                  Text(c.icon,
                                                      style: const TextStyle(
                                                          fontSize: 13)),
                                                  const SizedBox(width: 6),
                                                  Text(c.name,
                                                      style: const TextStyle(
                                                          fontSize: 13)),
                                                ],
                                              ),
                                            )),
                                      ],
                                      onChanged: (v) {
                                        setState(() {
                                          tx.categoryId = v;
                                        });
                                      },
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Import Button Bar
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 50,
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _startImport,
                icon: const Icon(Icons.upload),
                label: Text(
                  'Importar ${filtered.where((t) => t.isSelected).length} Transacciones',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- Step 2: Progress & Completion UI ---
  Widget _buildStep2Importing() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isImporting) ...[
              const SizedBox(
                width: 72,
                height: 72,
                child: CircularProgressIndicator(strokeWidth: 6),
              ),
              const SizedBox(height: 32),
              Text(
                'Importando transacciones...',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: _importTotal > 0
                    ? (_importSuccess + _importFailed) / _importTotal
                    : 0,
              ),
              const SizedBox(height: 12),
              Text(
                'Procesando ${_importSuccess + _importFailed} de $_importTotal movimientos',
                style: const TextStyle(fontSize: 15, color: Colors.grey),
              ),
            ] else ...[
              Icon(
                _importFailed == 0
                    ? Icons.check_circle_outline
                    : Icons.warning_amber_outlined,
                size: 80,
                color: _importFailed == 0
                    ? Colors.green.shade600
                    : Colors.orange.shade700,
              ),
              const SizedBox(height: 24),
              Text(
                'Importación finalizada',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Importadas con éxito:',
                              style: TextStyle(fontSize: 15)),
                          Text('$_importSuccess',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.green.shade700)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Fallidas:',
                              style: TextStyle(fontSize: 15)),
                          Text('$_importFailed',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: _importFailed > 0
                                      ? Colors.red.shade700
                                      : null)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (_importFailed > 0) ...[
                const SizedBox(height: 20),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Errores de importación:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: _importErrors.length,
                    itemBuilder: (context, idx) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline,
                                color: Colors.red, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                _importErrors[idx],
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
              const Spacer(),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: SizedBox(
                    height: 50,
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        // Invalidate transaction provider & go back
                        ref.invalidate(transactionsProvider);
                        Navigator.pop(context);
                      },
                      child: const Text('Ver Movimientos',
                          style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SkippedRowsBanner extends StatefulWidget {
  final List<_SkippedRow> skippedRows;

  const _SkippedRowsBanner({required this.skippedRows});

  @override
  State<_SkippedRowsBanner> createState() => _SkippedRowsBannerState();
}

class _SkippedRowsBannerState extends State<_SkippedRowsBanner> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.orange.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.orange.shade800, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${widget.skippedRows.length} fila${widget.skippedRows.length == 1 ? '' : 's'} omitida${widget.skippedRows.length == 1 ? '' : 's'} por errores de formato',
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.orange.shade800,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: widget.skippedRows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, i) {
                final row = widget.skippedRows[i];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fila ${row.rowNumber}',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade900),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (row.rawLine.isNotEmpty)
                            Text(
                              row.rawLine,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.orange.shade800,
                                  fontStyle: FontStyle.italic),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          Text(
                            row.reason,
                            style: TextStyle(
                                fontSize: 11, color: Colors.orange.shade900),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
          ],
          Divider(height: 1, color: Colors.orange.shade200),
        ],
      ),
    );
  }
}
