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

  // ---------------------------------------------------------------------------
  // Shared visual language used by employeereport.dart
  // ---------------------------------------------------------------------------
  static const Color _kBg = Color(0xFFF5F6FA);
  static const Color _kInk = Color(0xFF1F2430);
  static const Color _kMuted = Color(0xFF7A8194);
  static const Color _kLine = Color(0xFFE6E8F0);
  static const Color _kGreen = Color(0xFF22A06B);
  static const Color _kAmber = Color(0xFFE59A1F);
  static const Color _kRed = Color(0xFFE5484D);
  static const Color _kPurple = Color(0xFF7B5CC9);
  static const Color _kGradient = Color.fromARGB(255, 12, 86, 147);
  static const Color _kAccent = Color.fromARGB(255, 12, 86, 147);

  static const BoxShadow _softShadow = BoxShadow(
    color: Color(0x0D1F2430),
    blurRadius: 16,
    offset: Offset(0, 6),
  );

  LinearGradient get _bannerGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_kGradient, _kGradient.withOpacity(0.72)],
      );

  TextStyle _labelStyle() => TextStyle(
        color: _kMuted,
        fontSize: SizeConfig.f(11),
        fontWeight: FontWeight.w600,
      );

  TextStyle _valueStyle(Color color) => TextStyle(
        color: color,
        fontSize: SizeConfig.f(22),
        fontWeight: FontWeight.w800,
      );

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
      final managerId = ApiService.empGuid;
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
    final hasRange = _startDate != null && _endDate != null;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          _softShadow,
        ],
      ),
      child: Column(
        children: [
          // Segmented toggle
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _kBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(child: _buildFilterChip('Today', Icons.today_rounded)),
                Expanded(
                  child: _buildFilterChip(
                      'Date Range', Icons.date_range_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _selectedRange == 'Date Range' ? _selectDateRange : null,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: _kLine),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _selectedRange == 'Date Range'
                        ? Icons.calendar_month_rounded
                        : Icons.today_rounded,
                    size: 18,
                    color: const Color.fromARGB(255, 12, 86, 147),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _getDateRangePickerText(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: (_selectedRange == 'Date Range' && !hasRange)
                            ? _kMuted
                            : _kInk,
                      ),
                    ),
                  ),
                  if (_selectedRange == 'Date Range')
                    const Icon(Icons.keyboard_arrow_down_rounded,
                        color: _kMuted),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, IconData icon) {
    final isSelected = _selectedRange == label;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        if (!isSelected) {
          _changeRangeType(label);
        }
        if (label == 'Date Range' && (_startDate == null || _endDate == null)) {
          _selectDateRange();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? _kAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: isSelected ? Colors.white : _kMuted),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : _kMuted,
              ),
            ),
          ],
        ),
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
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color.fromARGB(255, 12, 86, 147),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Attendance Report',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadReport,
            tooltip: 'Refresh',
            iconSize: 22,
          ),
          const SizedBox(width: 4),
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
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          'Loading Report...',
                          style: TextStyle(
                            color: _kMuted,
                            fontSize: SizeConfig.f(14),
                          ),
                        ),
                      ],
                    ),
                  )
                : _report == null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: _kRed.withOpacity(0.10),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.error_outline_rounded,
                                  size: 38,
                                  color: _kRed,
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'Failed to load report',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: _kInk,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Check your connection and try again.',
                                style:
                                    TextStyle(fontSize: 13.5, color: _kMuted),
                              ),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed: _loadReport,
                                icon: const Icon(Icons.refresh_rounded,
                                    size: 18),
                                label: const Text('Retry'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: _kAccent,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 22, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 32),
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
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: _bannerGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _kGradient.withOpacity(0.30),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.20),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _selectedRange == 'Today'
                  ? Icons.today_rounded
                  : Icons.date_range_rounded,
              size: 26,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getRangeTitle(),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.88),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _getDateRangeText(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatistics() {
    if (_report == null || _report!['statistics'] == null) {
      return const SizedBox.shrink();
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

    final totalEmployees =
        (stats['totalEmployees'] as int?) ?? summaries.length;
    final total = present + late + absent;
    final coverage = total > 0 ? present / total : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeading(
            '$_selectedRange Statistics',
            trailing: '${summaries.length} Employees',
          ),
          const SizedBox(height: 14),
          GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: 84,
            ),
            children: [
              _buildStatCard('Total Employees', totalEmployees.toString(),
                  Icons.people_alt_outlined, _kAccent),
              _buildStatCard('Present', present.toString(),
                  Icons.check_circle_outline_rounded, _kGreen),
              _buildStatCard('Late', late.toString(),
                  Icons.access_time_rounded, _kAmber),
              _buildStatCard('Absent', absent.toString(),
                  Icons.person_off_outlined, _kRed),
              if (_selectedRange != 'Today')
                _buildStatCard('Total Hours',
                    '${totalHours.toStringAsFixed(1)}h',
                    Icons.timer_outlined, _kPurple),
              _buildStatCard('Coverage', '${(coverage * 100).toStringAsFixed(1)}%',
                  Icons.bar_chart_rounded, _kGreen),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeading(String text, {String? trailing}) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: _kAccent,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: _kInk,
              fontSize: SizeConfig.f(17),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (trailing != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _kAccent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              trailing,
              style: TextStyle(
                color: _kAccent,
                fontSize: SizeConfig.f(10),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          _softShadow,
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 24, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: _kMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeList() {
    final summaries = (_report?['employeeSummaries'] as List? ?? []);

    if (summaries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 30, 16, 30),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _kLine),
            boxShadow: const [_softShadow],
          ),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _kAccent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.people_outline_rounded,
                  size: 30,
                  color: _kAccent,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'No employee data available',
                style: TextStyle(
                  color: _kInk,
                  fontSize: SizeConfig.f(15),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'There are no attendance records for this period.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _kMuted,
                  fontSize: SizeConfig.f(12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeading(
            'Employee Details',
            trailing: '${summaries.length} Employees',
          ),
          const SizedBox(height: 12),
          ...summaries.map((emp) => _buildEmployeeCard(emp)),
        ],
      ),
    );
  }

Widget _buildDialogHeader({
  required IconData icon,
  required String title,
  required int count,
  required Color color,
}) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 12, 14),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: _kInk,
                  fontSize: SizeConfig.f(16),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$count records',
                style: TextStyle(
                  color: _kMuted,
                  fontSize: SizeConfig.f(11),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded, color: _kMuted),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Close',
        ),
      ],
    ),
  );
}

void _showPresentRecordsDialog(BuildContext context, List<dynamic> presentRecords) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          width: SizeConfig.w(85),
          constraints: BoxConstraints(
            maxHeight: SizeConfig.h(70),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogHeader(
                icon: Icons.check_circle_outline_rounded,
                title: 'Present Records',
                count: presentRecords.length,
                color: _kGreen,
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
                          final Color statusColor = isOnTime ? _kGreen : _kAmber;
                          
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
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
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
              _buildDialogHeader(
                icon: Icons.access_time_rounded,
                title: 'Late Records',
                count: lateRecords.length,
                color: _kAmber,
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
                              border: Border.all(color: _kAmber.withOpacity(0.3)),
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
                                        color: _kAmber,
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
                                        color: _kAmber,
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
                                        color: _kRed,
                                      ),
                                      SizedBox(width: SizeConfig.w(2)),
                                      Text(
                                        'Late by: ${_formatLateDuration(record['lateBy'])}',
                                        style: TextStyle(
                                          fontSize: SizeConfig.f(13),
                                          color: _kRed,
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
                                          color: _kAmber,
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
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
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
              _buildDialogHeader(
                icon: Icons.person_off_outlined,
                title: 'Absent Records',
                count: absentRecords.length,
                color: _kRed,
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
                                color: isOnLeave ? Colors.blue.withOpacity(0.3) : _kRed.withOpacity(0.3),
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
                                        color: isOnLeave ? Colors.blue : _kRed,
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
                                  //       color: isOnLeave ? Colors.blue : _kRed,
                                  //     ),
                                  //     SizedBox(width: SizeConfig.w(2)),
                                  //     Text(
                                  //       isOnLeave ? 'On Leave' : 'Absent without leave',
                                  //       style: TextStyle(
                                  //         fontSize: SizeConfig.f(13),
                                  //         color: isOnLeave ? Colors.blue[600] : _kRed[600],
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
                                          color: isOnLeave ? Colors.blue : _kRed,
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
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: onTap != null ? color.withOpacity(0.22) : _kLine,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 17, color: color),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _labelStyle(),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: SizeConfig.f(13),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: _kMuted,
              ),
          ],
        ),
      ),
    ),
  );
}

// Make this a StatefulWidget or use StatefulBuilder
Widget _buildEmployeeCard(Map<String, dynamic> emp) {
    final present = emp['presentDays'] ?? 0;
    final late = emp['lateDays'] ?? 0;
    final absent = emp['absentDays'] ?? 0;
    final hoursText =
        '${_safeGetDouble(emp['totalHoursWorked']).toStringAsFixed(1)}h';

    final bool isPeriodicReport = _selectedRange == 'Date Range';

    final Color statusColor = !isPeriodicReport
        ? (absent > 0 ? _kRed : (late > 0 ? _kAmber : _kGreen))
        : _kAccent;

    final name = (emp['employeeName'] ?? '').toString();
    final dept = (emp['department'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          _softShadow,
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: Container(
            width: SizeConfig.f(44),
            height: SizeConfig.f(44),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: _bannerGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              _getInitial(name),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: SizeConfig.f(16),
              ),
            ),
          ),
          title: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: _kInk,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ID: ${emp['employeeId']}',
                  style: const TextStyle(fontSize: 12, color: _kMuted),
                ),
                if (dept.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    dept,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _kAccent,
                    ),
                  ),
                ],
              ],
            ),
          ),
          trailing: isPeriodicReport
              ? null
              : Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        absent > 0
                            ? Icons.cancel_outlined
                            : (late > 0
                                ? Icons.access_time_rounded
                                : Icons.check_circle_rounded),
                        size: 14,
                        color: statusColor,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        absent > 0 ? 'ABSENT' : (late > 0 ? 'LATE' : 'PRESENT'),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 10.5,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
          children: [
            const Divider(height: 1, color: _kLine, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.all(16),
              child: GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: 66,
                ),
                children: [
                  _buildDetailItem(
                    'Present Days',
                    present.toString(),
                    _kGreen,
                    Icons.check_circle_outline_rounded,
                    onTap: () => _showPresentRecordsDialog(
                        context, emp['presentRecords'] ?? []),
                  ),
                  _buildDetailItem(
                    'Late Days',
                    late.toString(),
                    _kAmber,
                    Icons.access_time_rounded,
                    onTap: () => _showLateRecordsDialog(
                        context, emp['lateRecords'] ?? []),
                  ),
                  _buildDetailItem(
                    'Absent Days',
                    absent.toString(),
                    _kRed,
                    Icons.person_off_outlined,
                    onTap: () => _showAbsentRecordsDialog(
                        context, emp['absentRecords'] ?? []),
                  ),
                  _buildDetailItem(
                    'Total Hours',
                    hoursText,
                    _kAccent,
                    Icons.timer_outlined,
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