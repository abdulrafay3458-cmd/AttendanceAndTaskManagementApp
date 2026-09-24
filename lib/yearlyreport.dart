import 'package:flutter/material.dart';

class YearlyReportScreen extends StatelessWidget {
  const YearlyReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Similar to MonthlyReportScreen but for yearly data
    return Scaffold(
      appBar: AppBar(
        title: Text('Yearly Report'),
        backgroundColor: Colors.purple[700],
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Text('Yearly report implementation similar to monthly'),
      ),
    );
  }
}
