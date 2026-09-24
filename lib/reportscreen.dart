import 'package:attendance_app/absentemployee.dart';
import 'package:attendance_app/checkinreport.dart';
import 'package:attendance_app/dailyreport.dart';
import 'package:attendance_app/employee_task_summary_page.dart';
import 'package:attendance_app/employeereport.dart';
import 'package:attendance_app/lateemployee.dart';
import 'package:attendance_app/models/employee.dart';
import 'package:attendance_app/services/apiservice.dart';
import 'package:flutter/material.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  _ReportsScreenState createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  Employee? get employee => ApiService.currentEmployee;

  @override
  Widget build(BuildContext context) {
    final roles = employee?.role.map((r) => r.toLowerCase()).toList() ?? [];
    final isManager = roles.contains('manager');

    return Scaffold(
      appBar: AppBar(
        title: Text('Report', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue[700],
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildReportCard(
              'Attendance Report',
              Icons.document_scanner,
              Color.fromARGB(255, 205, 230, 195),
              Color.fromARGB(255, 85, 120, 75),
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => Employeereport()),
              ),
            ),
            if (isManager) ...[
              _buildReportCard(
                'Team Attendance',
                Icons.group,
                Color.fromARGB(255, 175, 227, 248),
                Color.fromARGB(255, 83, 119, 133),
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => DailyReportScreen()),
                ),
              ),
              _buildReportCard(
                'Late Employees',
                Icons.alarm,
                Color.fromARGB(255, 248, 196, 175),
                Color.fromARGB(255, 131, 98, 85),
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LateEmployeesScreen()),
                ),
              ),
              _buildReportCard(
                'Absent Employees',
                Icons.person_off,
                Color.fromARGB(255, 191, 211, 249),
                Color.fromARGB(255, 84, 105, 142),
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AbsentEmployeesScreen(),
                  ),
                ),
              ),
              _buildReportCard(
                'Check In/Out Report',
                Icons.lock_clock_rounded,
                Color.fromARGB(255, 249, 249, 191),
                Color.fromARGB(255, 142, 131, 84),
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CheckinReportScreen(),
                  ),
                ),
              ),
              _buildReportCard(
                'Task Report',
                Icons.work_history_rounded,
                Color.fromARGB(255, 225, 215, 240),
                Color.fromARGB(255, 95, 80, 125),
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EmployeeTaskSummaryPage(),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(
    String title,
    IconData icon,
    Color color,
    Color frontColor,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: color,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: frontColor),
              SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: frontColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}