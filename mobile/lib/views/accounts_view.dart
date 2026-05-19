import 'package:flutter/material.dart';

class AccountsView extends StatelessWidget {
  const AccountsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cuentas')),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Navigate to create account
        },
        child: const Icon(Icons.add),
      ),
      body: const Center(
        child: Text('Lista de cuentas'),
      ),
    );
  }
}
