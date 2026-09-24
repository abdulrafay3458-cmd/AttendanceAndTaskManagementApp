import 'package:flutter/material.dart';

class WeeklyReportScreen extends StatelessWidget {
  const WeeklyReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Similar to DailyReportScreen but for weekly data
    return Scaffold(
      appBar: AppBar(
        title: Text('Weekly Report'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Text('Weekly report implementation similar to daily'),
      ),
    );
  }
}

