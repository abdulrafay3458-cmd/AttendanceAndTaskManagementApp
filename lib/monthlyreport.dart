import 'dart:convert';
import 'dart:io';

import 'package:attendance_app/main.dart';
import 'package:attendance_app/services/apiservice.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class MonthlyReportScreen extends StatefulWidget {
  const MonthlyReportScreen({super.key});

  @override
  _MonthlyReportScreenState createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  Map<String, dynamic>? _report;
  bool _isLoading = true;
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;

  late DateTime _selectDate; 


  final String _selectedRange = 'Daily';
  String managerId = ApiService.currentEmployee!.employeeId;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _loadReport();
    _selectDate = DateTime(_selectedYear, _selectedMonth, 1);
  }
  Future<void> _downloadReport() async {
  setState(() => _isDownloading = true);

  try {
    final bytes = await ApiService.downloadManagerReportBytes(
      _selectedRange,
      _selectDate,
      managerId,
    );

    if (bytes == null || bytes.isEmpty) {
      throw Exception('Empty file received');
    }

    final directory = await getExternalStorageDirectory();
    final downloadDir = Directory('${directory!.path}/Download');

    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }

    final fileName =
        'Team_Attendance_Report_${managerId}_${DateTime.now().millisecondsSinceEpoch}.xlsx';

    final file = File('${downloadDir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Report downloaded successfully'),
        backgroundColor: Colors.green,
        action: SnackBarAction(
          label: 'VIEW',
          textColor: Colors.white,
          onPressed: () {
            OpenFilex.open(file.path);
          },
        ),
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Download failed: $e'),
        backgroundColor: Colors.red,
      ),
    );
  } finally {
    setState(() => _isDownloading = false);
  }
}
  Future<void> _loadReport() async {
    setState(() => _isLoading = true);

    try {
      final managerId = ApiService.employeeId;
      final response = await http
          .get(
            Uri.parse(
              '$API_BASE_URL/report/monthly?year=$_selectedYear&month=$_selectedMonth&managerId=$managerId',
            ),
            headers: ApiService.getHeaders(),
          )
          .timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        setState(() {
          _report = jsonDecode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading monthly report: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Monthly Report'),
        backgroundColor: Colors.orange[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () {
              setState(() {
                if (_selectedMonth == 1) {
                  _selectedMonth = 12;
                  _selectedYear--;
                } else {
                  _selectedMonth--;
                }
              });
              _loadReport();
            },
          ),
          IconButton(
            icon: Icon(Icons.arrow_forward),
            onPressed: () {
              setState(() {
                if (_selectedMonth == 12) {
                  _selectedMonth = 1;
                  _selectedYear++;
                } else {
                  _selectedMonth++;
                }
              });
              _loadReport();
            },
          ),
          IconButton(icon: Icon(Icons.refresh), onPressed: _loadReport),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _report == null
          ? Center(child: Text('Failed to load report'))
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildHeader(),
                  _buildStatistics(),
                  _buildTopPerformers(),
                  _buildEmployeeList(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.orange[700],
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          Text(
            '${months[_selectedMonth - 1]} $_selectedYear',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Monthly Attendance Report',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildStatistics() {
    final stats = _report!['statistics'];

    return Padding(
      padding: EdgeInsets.all(16),
      child: Card(
        elevation: 4,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Overall Statistics',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              _buildStatRow(
                'Total Employees',
                stats['totalEmployees'].toString(),
                Icons.people,
                Colors.blue,
              ),
              _buildStatRow(
                'Attendance Rate',
                '${stats['overallAttendanceRate'].toStringAsFixed(1)}%',
                Icons.check_circle,
                Colors.green,
              ),
              _buildStatRow(
                'Late Rate',
                '${stats['averageLateRate'].toStringAsFixed(1)}%',
                Icons.alarm,
                Colors.orange,
              ),
              _buildStatRow(
                'Total Absences',
                stats['totalAbsences'].toString(),
                Icons.cancel,
                Colors.red,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(fontSize: 14))),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopPerformers() {
    final summaries = _report!['employeeSummaries'] as List;
    final sorted = List.from(summaries);
    sorted.sort(
      (a, b) => (b['presentDays'] as int).compareTo(a['presentDays'] as int),
    );
    final topPerformers = sorted.take(5).toList();

    return Padding(
      padding: EdgeInsets.all(16),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.emoji_events, color: Colors.amber),
                  SizedBox(width: 8),
                  Text(
                    'Top Performers',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              SizedBox(height: 12),
              ...topPerformers.asMap().entries.map((entry) {
                final index = entry.key;
                final emp = entry.value;
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    backgroundColor: index == 0
                        ? Colors.amber
                        : (index == 1 ? Colors.grey : Colors.brown[300]),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(emp['employeeName']),
                  trailing: Text(
                    '${emp['presentDays']} days',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeList() {
    final summaries = _report!['employeeSummaries'] as List;

    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'All Employees',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12),
          ...summaries.map((emp) => _buildEmployeeCard(emp)),
        ],
      ),
    );
  }

  Widget _buildEmployeeCard(Map<String, dynamic> emp) {
    final attendanceRate = emp['totalDays'] > 0
        ? (emp['presentDays'] / emp['totalDays'] * 100)
        : 0.0;

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Text(
                    emp['employeeName'].substring(0, 1).toUpperCase(),
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        emp['employeeName'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '${emp['employeeId']} • ${emp['department']}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: attendanceRate >= 90
                        ? Colors.green.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${attendanceRate.toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: attendanceRate >= 90
                          ? Colors.green
                          : Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetric(
                  'Present',
                  emp['presentDays'].toString(),
                  Colors.green,
                ),
                _buildMetric('Late', emp['lateDays'].toString(), Colors.orange),
                _buildMetric(
                  'Absent',
                  emp['absentDays'].toString(),
                  Colors.red,
                ),
                _buildMetric(
                  'Hours',
                  emp['totalHoursWorked'].toStringAsFixed(0),
                  Colors.blue,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: color,
          ),
        ),
        SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }
}
