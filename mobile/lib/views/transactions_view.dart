import 'package:flutter/material.dart';

class TransactionsView extends StatelessWidget {
  const TransactionsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Movimientos')),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Navigate to create transaction
        },
        child: const Icon(Icons.add),
      ),
      body: const Center(
        child: Text('Lista de transacciones'),
      ),
    );
  }
}
