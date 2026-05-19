import 'package:flutter/material.dart';

class ReportsView extends StatelessWidget {
  const ReportsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Informes')),
      body: const Center(
        child: Text('Gráficos e informes'),
      ),
    );
  }
}
