import 'package:flutter/material.dart';

class BudgetsView extends StatelessWidget {
  const BudgetsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Presupuestos')),
      body: const Center(
        child: Text('Presupuestos mensuales'),
      ),
    );
  }
}
