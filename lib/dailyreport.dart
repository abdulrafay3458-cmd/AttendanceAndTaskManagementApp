import 'dart:convert';

import 'package:attendance_app/main.dart';
import 'package:attendance_app/services/ApiClient.dart';
import 'package:attendance_app/services/apiservice.dart';
import 'package:attendance_app/widgets/SizeConfig.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class DailyReportScreen extends StatefulWidget {
  const DailyReportScreen({super.key});

  @override
  _DailyReportScreenState createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends State<DailyReportScreen> {
  Map<String, dynamic>? _report;
  bool _isLoading = true;
  String _selectedRange = 'Today'; // Default to Today
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  double _safeGetDouble(dynamic value) {
    if (value is int) {
      return value.toDouble();
    } else if (value is double) {
      return value;
    } else if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);

    try {
      final managerId = ApiService.employeeId;
      String url = '';
      
      // Build URL based on selected range
      if (_selectedRange == 'Today') {
        final dateStr = DateTime.now().toIso8601String().split('T')[0];
        url = 'report/daily?date=$dateStr&managerId=$managerId';
      } else {
        // Date Range: use selected dates or default to today
        final start = _startDate ?? DateTime.now();
        final end = _endDate ?? DateTime.now();
        final startStr = start.toIso8601String().split('T')[0];
        final endStr = end.toIso8601String().split('T')[0];
        url = 'report/daily?date=$startStr&endDate=$endStr&managerId=$managerId';
      }

      print('Loading report from: $url'); // Debug log

      final response = await ApiClient().dio.get(url).timeout(Duration(seconds: 15));

      if (response.statusCode == 200) {
        setState(() {
          _report = response.data as Map<String, dynamic>;
          _isLoading = false;
        });
      } else {
        print('Failed to load report: ${response.statusCode}');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading report: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDateRange() async {
    final DateTime? pickedStart = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Select Start Date',
    );

    if (pickedStart != null) {
      final DateTime? pickedEnd = await showDatePicker(
        context: context,
        initialDate: _endDate ?? DateTime.now(),
        firstDate: pickedStart,
        lastDate: DateTime.now(),
        helpText: 'Select End Date',
      );

      if (pickedEnd != null) {
        setState(() {
          _startDate = pickedStart;
          _endDate = pickedEnd;
          _selectedRange = 'Date Range';
        });
        _loadReport();
      }
    }
  }

  void _changeRangeType(String range) {
    setState(() {
      _selectedRange = range;
      if (range == 'Today') {
        _startDate = null;
        _endDate = null;
      }
    });
    if (range == 'Today') {
      _loadReport();
    } else if (range == 'Date Range' && _startDate != null && _endDate != null) {
      _loadReport();
    }
  }

  Widget _buildDateRangeSelector() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        color: Colors.grey[50],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildFilterChipOption('Today', Icons.today),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildFilterChipOption('Date Range', Icons.date_range),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_selectedRange == 'Date Range')
              InkWell(
                onTap: _selectDateRange,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, size: 18, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _getDateRangePickerText(),
                          style: TextStyle(
                            color: (_startDate == null || _endDate == null)
                                ? Colors.grey
                                : Colors.black,
                          ),
                        ),
                      ),
                      Icon(Icons.arrow_drop_down, color: Colors.grey),
                    ],
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
                ),
                child: Row(
                  children: [
                    Icon(Icons.today, size: 18, color: Colors.blue[700]),
                    const SizedBox(width: 8),
                    Text(_getTodayDisplayText()),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChipOption(String label, IconData icon) {
    final isSelected = _selectedRange == label;
    return FilterChip(
      label: Row(
        children: [
          Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.blue[700]),
          const SizedBox(width: 4, height: 28),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          if (label == 'Date Range') {
            _changeRangeType('Date Range');
            if (_startDate == null || _endDate == null) {
              _selectDateRange();
            }
          } else {
            _changeRangeType(label);
          }
        }
      },
      selectedColor: Colors.blue[700],
      checkmarkColor: Colors.white,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontSize: 13,
      ),
    );
  }

  String _getDateRangePickerText() {
    if (_startDate != null && _endDate != null) {
      return '${DateFormat('MMM dd, yyyy').format(_startDate!)} - ${DateFormat('MMM dd, yyyy').format(_endDate!)}';
    }
    return 'Select Date Range';
  }

  String _getTodayDisplayText() {
    return 'Today: ${DateFormat('MMM dd, yyyy').format(DateTime.now())}';
  }

  String _getRangeTitle() {
    switch (_selectedRange) {
      case 'Today':
        return 'Today\'s Attendance Overview';
      case 'Date Range':
        return 'Date Range Attendance Overview';
      default:
        return 'Attendance Overview';
    }
  }

  String _getDateRangeText() {
    switch (_selectedRange) {
      case 'Today':
        return DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now().toLocal());
      case 'Date Range':
        if (_startDate != null && _endDate != null) {
          return '${DateFormat('MMM dd, yyyy').format(_startDate!)} - ${DateFormat('MMM dd, yyyy').format(_endDate!)}';
        }
        return 'Select Date Range';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Attendance Report',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: SizeConfig.f(20),
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue[700],
        elevation: 0,
        actions: [
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.refresh_outlined),
            onPressed: _loadReport,
            tooltip: 'Refresh',
            iconSize: 22,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildDateRangeSelector(),
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Loading Report...',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: SizeConfig.f(14),
                          ),
                        ),
                      ],
                    ),
                  )
                : _report == null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Failed to load report',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: SizeConfig.f(16),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: _loadReport,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue[700],
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Retry',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(),
                            _buildStatistics(),
                            _buildEmployeeList(),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.blue[700]!, Colors.purple[700]!],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              _selectedRange == 'Today' 
                ? Icons.today_outlined
                : Icons.date_range_outlined,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _getDateRangeText(),
            style: TextStyle(
              color: Colors.white,
              fontSize: SizeConfig.f(20),
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            _getRangeTitle(),
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: SizeConfig.f(14),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_selectedRange.toUpperCase()} VIEW',
              style: TextStyle(
                color: Colors.white,
                fontSize: SizeConfig.f(11),
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatistics() {
    if (_report == null || _report!['statistics'] == null) {
      return Container(); // Return empty container if no data
    }
    
    final stats = _report!['statistics'];
    final summaries = _report!['employeeSummaries'] as List? ?? [];

    int present = 0, late = 0, absent = 0;
    double totalHours = 0;
    
    for (var emp in summaries) {
      present += (emp['presentDays'] as int?) ?? 0;
      late += (emp['lateDays'] as int?) ?? 0;
      absent += (emp['absentDays'] as int?) ?? 0;
      totalHours += _safeGetDouble(emp['totalHoursWorked']);
    }

    int totalEmployees = (stats['totalEmployees'] as int?) ?? summaries.length;
    double coverage = (present + late + absent) > 0 
        ? (present / (present + late + absent)) * 100 
        : 0;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: SizeConfig.h(2.5),
                width: SizeConfig.w(1),
                decoration: BoxDecoration(
                  color: Colors.blue[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$_selectedRange Statistics',
                style: TextStyle(
                  fontSize: SizeConfig.f(18),
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.2,
            children: [
              _buildStatCard(
                'Total Employees',
                totalEmployees.toString(),
                Icons.people_alt_outlined,
                Colors.blue,
              ),
              _buildStatCard(
                'Present',
                present.toString(),
                Icons.check_circle_outline,
                Colors.green,
              ),
              _buildStatCard(
                'Late',
                late.toString(),
                Icons.access_time_outlined,
                Colors.orange,
              ),
              _buildStatCard(
                'Absent',
                absent.toString(),
                Icons.person_off_outlined,
                Colors.red,
              ),
              if (_selectedRange != 'Today')
                _buildStatCard(
                  'Total Hours',
                  '${totalHours.toStringAsFixed(1)}h',
                  Icons.timer_outlined,
                  Colors.purple,
                ),
              _buildStatCard(
                'Coverage',
                '${coverage.toStringAsFixed(1)}%',
                Icons.bar_chart_outlined,
                Colors.teal,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Padding(
        padding: EdgeInsets.all(SizeConfig.f(14)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: SizeConfig.w(12),
              height: SizeConfig.h(5),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 24,
                  color: color,
                ),
              ),
            ),
            SizedBox(height: SizeConfig.h(1)),
            Text(
              value,
              style: TextStyle(
                fontSize: SizeConfig.f(23),
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: SizeConfig.f(12),
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeList() {
    final summaries = (_report?['employeeSummaries'] as List? ?? []);
    
    if (summaries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.people_outline,
                size: 64,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 16),
              Text(
                'No employee data available',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: SizeConfig.f(16),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: SizeConfig.h(2.5),
                width: SizeConfig.w(1),
                decoration: BoxDecoration(
                  color: Colors.blue[700],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Employee Details',
                style: TextStyle(
                  fontSize: SizeConfig.f(18),
                  fontWeight: FontWeight.w700,
                  color: Colors.grey[800],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Text(
                  '${summaries.length} Employees',
                  style: TextStyle(
                    fontSize: SizeConfig.f(12),
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...summaries.map((emp) => _buildEmployeeCard(emp)),
        ],
      ),
    );
  }

void _showPresentRecordsDialog(BuildContext context, List<dynamic> presentRecords) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          width: SizeConfig.w(85),
          constraints: BoxConstraints(
            maxHeight: SizeConfig.h(70),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: SizeConfig.w(4)),
                    Text(
                      'Present Records (${presentRecords.length})',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: SizeConfig.f(16),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              
              Expanded(
                child: presentRecords.isEmpty
                    ? Center(
                        child: Text(
                          'No present records found',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: SizeConfig.f(14),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: presentRecords.length,
                        itemBuilder: (context, index) {
                          final record = presentRecords[index];
                          final bool isOnTime = record['isOnTime'] != false;
                          final Color statusColor = isOnTime ? Colors.green : Colors.orange;
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: statusColor.withOpacity(0.3),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Date
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today,
                                        size: SizeConfig.f(14),
                                        color: statusColor,
                                      ),
                                      SizedBox(width: SizeConfig.w(2)),
                                      Text(
                                        _formatDate(record['date']),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: SizeConfig.f(14),
                                          color: Colors.grey[800],
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          isOnTime ? 'ON TIME' : 'LATE',
                                          style: TextStyle(
                                            color: statusColor,
                                            fontSize: SizeConfig.f(10),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  // Reason (if not empty)
                                  if (record['reason'] != null && record['reason'].toString().isNotEmpty) ...[
                                    SizedBox(height: SizeConfig.h(1)),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.info_outline,
                                          size: SizeConfig.f(14),
                                          color: statusColor,
                                        ),
                                        SizedBox(width: SizeConfig.w(2)),
                                        Expanded(
                                          child: Text(
                                            'Notes: ${record['reason']}',
                                            style: TextStyle(
                                              fontSize: SizeConfig.f(13),
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

// Late Records Detail Popup
void _showLateRecordsDialog(BuildContext context, List<dynamic> lateRecords) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          width: SizeConfig.w(85),
          constraints: BoxConstraints(
            maxHeight: SizeConfig.h(70),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.access_time, color: Colors.white),
                    SizedBox(width: SizeConfig.w(4)),
                    Text(
                      'Late Records (${lateRecords.length})',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: SizeConfig.f(16),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              
              // Records List
              Expanded(
                child: lateRecords.isEmpty
                    ? Center(
                        child: Text(
                          'No late records found',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: SizeConfig.f(14),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: lateRecords.length,
                        itemBuilder: (context, index) {
                          final record = lateRecords[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.orange.withOpacity(0.3)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Date
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today,
                                        size: SizeConfig.f(14),
                                        color: Colors.orange,
                                      ),
                                      SizedBox(width: SizeConfig.w(2)),
                                      Text(
                                        _formatDate(record['date']),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: SizeConfig.f(14),
                                          color: Colors.grey[800],
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: SizeConfig.h(1.5)),
                                  
                                  // Check-in Time
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.access_time,
                                        size: SizeConfig.f(14),
                                        color: Colors.orange,
                                      ),
                                      SizedBox(width: SizeConfig.w(2)),
                                      Text(
                                        'Check-in: ${_formatTime(record['checkInTime'])}',
                                        style: TextStyle(
                                          fontSize: SizeConfig.f(13),
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: SizeConfig.h(1)),
                                  
                                  // Late By
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.timer_off,
                                        size: SizeConfig.f(14),
                                        color: Colors.red[300],
                                      ),
                                      SizedBox(width: SizeConfig.w(2)),
                                      Text(
                                        'Late by: ${_formatLateDuration(record['lateBy'])}',
                                        style: TextStyle(
                                          fontSize: SizeConfig.f(13),
                                          color: Colors.red[600],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  
                                  // Reason (if not empty)
                                  if (record['reason'] != null && record['reason'].toString().isNotEmpty) ...[
                                    SizedBox(height: SizeConfig.h(1)),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.info_outline,
                                          size: SizeConfig.f(14),
                                          color: Colors.orange,
                                        ),
                                        SizedBox(width: SizeConfig.w(2)),
                                        Expanded(
                                          child: Text(
                                            'Reason: ${record['reason']}',
                                            style: TextStyle(
                                              fontSize: SizeConfig.f(13),
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

// Absent Records Detail Popup
void _showAbsentRecordsDialog(BuildContext context, List<dynamic> absentRecords) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          width: SizeConfig.w(85),
          constraints: BoxConstraints(
            maxHeight: SizeConfig.h(70),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person_off, color: Colors.white),
                    SizedBox(width: SizeConfig.w(4)),
                    Text(
                      'Absent Records (${absentRecords.length})',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: SizeConfig.f(16),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              
              // Records List
              Expanded(
                child: absentRecords.isEmpty
                    ? Center(
                        child: Text(
                          'No absent records found',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: SizeConfig.f(14),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: absentRecords.length,
                        itemBuilder: (context, index) {
                          final record = absentRecords[index];
                          final bool isOnLeave = record['onLeave'] == true;
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isOnLeave ? Colors.blue.withOpacity(0.3) : Colors.red.withOpacity(0.3),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Date
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today,
                                        size: SizeConfig.f(14),
                                        color: isOnLeave ? Colors.blue : Colors.red,
                                      ),
                                      SizedBox(width: SizeConfig.w(2)),
                                      Text(
                                        _formatDate(record['date']),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: SizeConfig.f(14),
                                          color: Colors.grey[800],
                                        ),
                                      ),
                                    ],
                                  ),
                                  // SizedBox(height: SizeConfig.h(1)),
                                  
                                  // On Leave Status
                                  // Row(
                                  //   children: [
                                  //     Icon(
                                  //       isOnLeave ? Icons.beach_access : Icons.work_off,
                                  //       size: SizeConfig.f(14),
                                  //       color: isOnLeave ? Colors.blue : Colors.red,
                                  //     ),
                                  //     SizedBox(width: SizeConfig.w(2)),
                                  //     Text(
                                  //       isOnLeave ? 'On Leave' : 'Absent without leave',
                                  //       style: TextStyle(
                                  //         fontSize: SizeConfig.f(13),
                                  //         color: isOnLeave ? Colors.blue[600] : Colors.red[600],
                                  //         fontWeight: FontWeight.w500,
                                  //       ),
                                  //     ),
                                  //   ],
                                  // ),
                                  
                                  // Reason (if not empty)
                                  if (record['reason'] != null && record['reason'].toString().isNotEmpty) ...[
                                    SizedBox(height: SizeConfig.h(1)),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.info_outline,
                                          size: SizeConfig.f(14),
                                          color: isOnLeave ? Colors.blue : Colors.red,
                                        ),
                                        SizedBox(width: SizeConfig.w(2)),
                                        Expanded(
                                          child: Text(
                                            'Reason: ${record['reason']}',
                                            style: TextStyle(
                                              fontSize: SizeConfig.f(13),
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

String _formatDate(String? dateString) {
  if (dateString == null || dateString.isEmpty) return 'N/A';
  
  try {
    final date = DateTime.parse(dateString);
    return '${date.day}/${date.month}/${date.year}';
  } catch (e) {
    return dateString;
  }
}

String _formatTime(String? timeString) {
  if (timeString == null || timeString.isEmpty) return 'N/A';
  
  try {
    final parts = timeString.split(':');
    if (parts.length >= 2) {
      final hour = int.parse(parts[0]);
      final minute = parts[1];
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$displayHour:$minute $period';
    }
    return timeString;
  } catch (e) {
    return timeString;
  }
}

String _formatLateDuration(String? durationString) {
  if (durationString == null || durationString.isEmpty) return 'N/A';
  
  try {
    final parts = durationString.split(':');
    if (parts.length >= 3) {
      final hours = int.parse(parts[0]);
      final minutes = int.parse(parts[1]);
      
      if (hours > 0) {
        return '${hours}h ${minutes}m';
      } else {
        return '${minutes}m';
      }
    }
    return durationString;
  } catch (e) {
    return durationString;
  }
}

Widget _buildDetailItem(
  String label,
  String value,
  Color color,
  IconData icon, {
  VoidCallback? onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: onTap != null 
              ? color.withOpacity(0.3)
              : Colors.grey[100]!,
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: SizeConfig.f(6), vertical: SizeConfig.f(6)),
      child: Row(
        children: [
          Container(
            width: SizeConfig.w(9),
            height: SizeConfig.h(9),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Icon(
                icon,
                size: SizeConfig.w(5),
                color: color,
              ),
            ),
          ),
          SizedBox(width: SizeConfig.w(4)),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: SizeConfig.f(9),
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: color,
                    fontSize: SizeConfig.f(13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

// Make this a StatefulWidget or use StatefulBuilder
Widget _buildEmployeeCard(Map<String, dynamic> emp) {
  final present = emp['presentDays'] ?? 0;
  final late = emp['lateDays'] ?? 0;
  final absent = emp['absentDays'] ?? 0;
  final hoursText = '${_safeGetDouble(emp['totalHoursWorked']).toStringAsFixed(1)}h';

  final bool isPeriodicReport = _selectedRange == 'Date Range';
  
  Color statusColor = !isPeriodicReport 
      ? (absent > 0 ? Colors.red : (late > 0 ? Colors.orange : Colors.green))
      : Colors.blue;

  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.08),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
      border: Border.all(color: Colors.grey[100]!),
    ),
    child: Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
      ),
      child: ExpansionTile(
        leading: Container(
          width: SizeConfig.w(11),
          height: SizeConfig.h(7),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                statusColor.withOpacity(0.2),
                statusColor.withOpacity(0.1),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              _getInitial(emp['employeeName']),
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w800,
                fontSize: SizeConfig.f(16),
              ),
            ),
          ),
        ),
        title: Text(
          emp['employeeName'].toString(),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: SizeConfig.f(14),
            color: Colors.grey[800],
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: SizeConfig.h(0.3)),
            Text(
              'ID: ${emp['employeeId']}',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: SizeConfig.f(11),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              emp['department'].toString(),
              style: TextStyle(
                color: Colors.blue[700],
                fontSize: SizeConfig.f(11),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        trailing: isPeriodicReport 
            ? null
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      absent > 0
                          ? Icons.cancel_outlined
                          : (late > 0 ? Icons.access_time : Icons.check_circle),
                      size: SizeConfig.f(14),
                      color: statusColor,
                    ),
                    SizedBox(width: SizeConfig.w(3)),
                    Text(
                      absent > 0 ? 'ABSENT' : (late > 0 ? 'LATE' : 'PRESENT'),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                        fontSize: SizeConfig.f(10),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
        children: [
          Divider(
            height: 1,
            color: Colors.grey[100],
            indent: 20,
            endIndent: 20,
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 2.5,
                  children: [
                    _buildDetailItem(
                      'Present Days',
                      present.toString(),
                      Colors.green,
                      Icons.check_circle_outlined,
                      onTap: () => _showPresentRecordsDialog(context, emp['presentRecords'] ?? []),
                    ),
                    _buildDetailItem(
                      'Late Days',
                      late.toString(),
                      Colors.orange,
                      Icons.access_time_outlined,
                      onTap: () => _showLateRecordsDialog(context, emp['lateRecords'] ?? []),
                    ),
                    _buildDetailItem(
                      'Absent Days',
                      absent.toString(),
                      Colors.red,
                      Icons.person_off_outlined,
                      onTap: () => _showAbsentRecordsDialog(context, emp['absentRecords'] ?? []),
                    ),
                    _buildDetailItem(
                      'Total Hours',
                      hoursText,
                      Colors.blue,
                      Icons.timer_outlined,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

String _getInitial(String? name) {
  if (name == null || name.isEmpty) return '?';
  return name.substring(0, 1).toUpperCase();
}
}