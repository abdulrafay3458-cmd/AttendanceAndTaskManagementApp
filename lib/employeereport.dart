import 'dart:io';

import 'package:attendance_app/services/apiservice.dart';
import 'package:attendance_app/widgets/SizeConfig.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:attendance_app/services/ApiClient.dart';

// -----------------------------------------------------------------------------
// Design tokens
// -----------------------------------------------------------------------------
const Color _kBg = Color(0xFFF5F6FA);
const Color _kInk = Color(0xFF1F2430);
const Color _kMuted = Color(0xFF7A8194);
const Color _kLine = Color(0xFFE6E8F0);
const Color _kGreen = Color(0xFF22A06B);
const Color _kAmber = Color(0xFFE59A1F);
const Color _kRed = Color(0xFFE5484D);
const Color _kPurple = Color(0xFF7B5CC9);

/// Base color for gradient banners / avatars.
const Color _kGradient = Color.fromARGB(255, 12, 86, 147);

/// Accent color for pills, icon tiles and the active filter.
const Color _kAccent = Color.fromARGB(255, 12, 86, 147);

List<BoxShadow> get _softShadow => [
      BoxShadow(
        color: const Color(0xFF1F2430).withOpacity(0.05),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
    ];

LinearGradient get _bannerGradient => LinearGradient(
      colors: [_kGradient, _kGradient.withOpacity(0.72)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

class Employeereport extends StatefulWidget {
  const Employeereport({super.key});

  @override
  _EmployeeReportState createState() => _EmployeeReportState();
}

class _EmployeeReportState extends State<Employeereport> {
  Map<String, dynamic>? _report;
  bool _isLoading = true;
  String _selectedFilter = 'Today';
  DateTime? _startDate;
  DateTime? _endDate;
  String employeeCode = ApiService.currentEmployee!.empGuid;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  void _snack(String message, {bool isError = false, SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? _kRed : _kGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        action: action,
      ),
    );
  }

  Future<void> _downloadReport() async {
    setState(() => _isDownloading = true);

    try {
      final DateTime start = _selectedFilter == 'Today'
          ? DateTime.now()
          : (_startDate ?? DateTime.now());
      final DateTime end = _selectedFilter == 'Today'
          ? DateTime.now()
          : (_endDate ?? DateTime.now());

      final bytes = await ApiService.downloadEmployeeReportBytes(
        _selectedFilter,
        start,
        end,
        employeeCode,
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
          'Employee_Report_${employeeCode}_${DateTime.now().millisecondsSinceEpoch}.xlsx';

      final file = File('${downloadDir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);

      _snack(
        'Report downloaded successfully',
        action: SnackBarAction(
          label: 'VIEW',
          textColor: Colors.white,
          onPressed: () {
            OpenFilex.open(file.path);
          },
        ),
      );
    } catch (e) {
      _snack('Download failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
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
      final employeeId = ApiService.empGuid;
      print("misbah ${employeeId}" );
      String url = '';
      String startStr = '';
      String endStr = '';

      if (_selectedFilter == 'Today') {
        final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
        url =
            'report/empmonthly?date=$dateStr&endDate=$dateStr&employeeId=$employeeId';
      } else {
        final start = _startDate ?? DateTime.now();
        final end = _endDate ?? DateTime.now();
        startStr = DateFormat('yyyy-MM-dd').format(start);
        endStr = DateFormat('yyyy-MM-dd').format(end);
        url =
            'report/empmonthly?date=$startStr&endDate=$endStr&employeeId=$employeeId';
      }

      final response = await ApiClient().dio.get(url);

      if (response.statusCode == 200) {
        if (!mounted) return;
        setState(() {
          _report = response.data as Map<String, dynamic>;
          _isLoading = false;
        });
      } else {
        print('Loading Failed: ${response.data}');
        print('Failed to load report: ${response.statusCode}');
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading report: $e');
      if (mounted) setState(() => _isLoading = false);
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

    if (pickedStart != null && mounted) {
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
        });
        _loadReport();
      }
    }
  }

  void _changeFilterType(String filter) {
    setState(() {
      _selectedFilter = filter;
      if (filter == 'Today') {
        _startDate = null;
        _endDate = null;
      }
    });
    if (filter == 'Today') {
      _loadReport();
    } else if (filter == 'Date Range' &&
        _startDate != null &&
        _endDate != null) {
      _loadReport();
    }
  }

  String _getFilterDisplayText() {
    if (_selectedFilter == 'Today') {
      return 'Today: ${DateFormat('MMM dd, yyyy').format(DateTime.now())}';
    } else {
      if (_startDate != null && _endDate != null) {
        return '${DateFormat('MMM dd, yyyy').format(_startDate!)} - ${DateFormat('MMM dd, yyyy').format(_endDate!)}';
      }
      return 'Select Date Range';
    }
  }

  String _getRangeTitle() {
    switch (_selectedFilter) {
      case 'Today':
        return 'Today\'s Attendance Overview';
      case 'Date Range':
        return 'Date Range Attendance Overview';
      default:
        return 'Attendance Overview';
    }
  }

  String _getDateRangeText() {
    if (_selectedFilter == 'Today') {
      return DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now().toLocal());
    } else {
      if (_startDate != null && _endDate != null) {
        return '${DateFormat('MMM dd, yyyy').format(_startDate!)} - ${DateFormat('MMM dd, yyyy').format(_endDate!)}';
      }
      return 'Select Date Range';
    }
  }

  // ---------------------------------------------------------------------------
  // Filter bar
  // ---------------------------------------------------------------------------
  Widget _buildDateRangeSelector() {
    final hasRange = _startDate != null && _endDate != null;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: _softShadow,
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
            onTap: _selectedFilter == 'Date Range' ? _selectDateRange : null,
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
                    _selectedFilter == 'Date Range'
                        ? Icons.calendar_month_rounded
                        : Icons.today_rounded,
                    size: 18,
                    color: _kAccent,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _getFilterDisplayText(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: (_selectedFilter == 'Date Range' && !hasRange)
                            ? _kMuted
                            : _kInk,
                      ),
                    ),
                  ),
                  if (_selectedFilter == 'Date Range')
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
    final isSelected = _selectedFilter == label;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        if (!isSelected) {
          _changeFilterType(label);
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

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.20),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _selectedFilter == 'Today'
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
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isDownloading ? null : _downloadReport,
              icon: _isDownloading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _kGradient,
                      ),
                    )
                  : const Icon(Icons.download_rounded, size: 20),
              label: Text(_isDownloading ? 'Downloading…' : 'Download Excel'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.blue[700],
                disabledBackgroundColor: Colors.white.withOpacity(0.85),
                disabledForegroundColor: _kGradient,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String text, {String? trailing}) {
    return Row(
      children: [
        Container(
          height: 20,
          width: 4,
          decoration: BoxDecoration(
            color: _kAccent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: _kInk,
            ),
          ),
        ),
        if (trailing != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: _kAccent.withOpacity(0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              trailing,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: _kAccent,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatistics() {
    if (_report == null || _report!['statistics'] == null) {
      return const SizedBox.shrink(); // no data
    }

    final summaries = _report!['employeeSummaries'] as List? ?? [];

    int present = 0, late = 0, absent = 0;
    double totalHours = 0;

    for (var emp in summaries) {
      present += (emp['presentDays'] as int?) ?? 0;
      late += (emp['lateDays'] as int?) ?? 0;
      absent += (emp['absentDays'] as int?) ?? 0;
      totalHours += _safeGetDouble(emp['totalHoursWorked']);
    }

    final total = present + late + absent;
    final double coverage = total > 0 ? (present / total) : 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('$_selectedFilter Statistics'),
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
              _buildStatCard('Present', present.toString(),
                  Icons.check_circle_outline_rounded, _kGreen),
              _buildStatCard('Late', late.toString(),
                  Icons.access_time_rounded, _kAmber),
              _buildStatCard('Absent', absent.toString(),
                  Icons.person_off_outlined, _kRed),
              _buildStatCard('Total Hours', '${totalHours.toStringAsFixed(1)}h',
                  Icons.timer_outlined, _kPurple),
            ],
          ),
          if (total > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: _softShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'On-time rate',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: _kMuted,
                          ),
                        ),
                      ),
                      Text(
                        '${(coverage * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _kInk,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: coverage,
                      minHeight: 8,
                      backgroundColor: _kLine,
                      valueColor: const AlwaysStoppedAnimation<Color>(_kGreen),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: _softShadow,
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
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _kAccent.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.people_outline_rounded,
                    size: 38, color: _kAccent),
              ),
              const SizedBox(height: 14),
              const Text(
                'No employee data available',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _kInk,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Employee Details',
              trailing: '${summaries.length} Employees'),
          const SizedBox(height: 14),
          ...summaries.map((emp) => _buildEmployeeCard(emp)),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Records popups
  // ---------------------------------------------------------------------------
  void _showRecordsDialog({
    required String title,
    required IconData icon,
    required Color color,
    required String emptyText,
    required List<dynamic> records,
    required Widget Function(dynamic record) itemBuilder,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 440,
              maxHeight: MediaQuery.of(dialogContext).size.height * 0.72,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 8, 14),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(icon, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: _kInk,
                              ),
                            ),
                            Text(
                              '${records.length} record(s)',
                              style: const TextStyle(
                                  fontSize: 13, color: _kMuted),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: _kMuted),
                        onPressed: () => Navigator.of(dialogContext).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: _kLine),
                Flexible(
                  child: records.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            emptyText,
                            style: const TextStyle(
                                color: _kMuted, fontSize: 14),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.all(16),
                          itemCount: records.length,
                          itemBuilder: (context, index) =>
                              itemBuilder(records[index]),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _recordCard(Color color, List<Widget> children) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _recordRow(IconData icon, Color iconColor, String text,
      {Color? textColor, FontWeight? weight, double size = 13.5}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: size,
              color: textColor ?? _kInk,
              fontWeight: weight,
            ),
          ),
        ),
      ],
    );
  }

  bool _hasReason(dynamic record) =>
      record['reason'] != null && record['reason'].toString().isNotEmpty;

  void _showPresentRecordsDialog(
      BuildContext context, List<dynamic> presentRecords) {
    _showRecordsDialog(
      title: 'Present Records',
      icon: Icons.check_circle_rounded,
      color: _kGreen,
      emptyText: 'No present records found',
      records: presentRecords,
      itemBuilder: (record) {
        final bool isOnTime = record['isOnTime'] != false;
        final Color statusColor = isOnTime ? _kGreen : _kAmber;

        return _recordCard(statusColor, [
          Row(
            children: [
              Icon(Icons.calendar_today_rounded,
                  size: 15, color: statusColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _formatDate(record['date']?.toString()),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: _kInk,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isOnTime ? 'ON TIME' : 'LATE',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          if (_hasReason(record)) ...[
            const SizedBox(height: 10),
            _recordRow(Icons.info_outline_rounded, statusColor,
                'Notes: ${record['reason']}',
                textColor: _kMuted),
          ],
        ]);
      },
    );
  }

  // Late Records Detail Popup
  void _showLateRecordsDialog(
      BuildContext context, List<dynamic> lateRecords) {
    _showRecordsDialog(
      title: 'Late Records',
      icon: Icons.access_time_rounded,
      color: _kAmber,
      emptyText: 'No late records found',
      records: lateRecords,
      itemBuilder: (record) {
        return _recordCard(_kAmber, [
          _recordRow(
            Icons.calendar_today_rounded,
            _kAmber,
            _formatDate(record['date']?.toString()),
            weight: FontWeight.w700,
            size: 14,
          ),
          const SizedBox(height: 10),
          _recordRow(
            Icons.login_rounded,
            _kAmber,
            'Check-in: ${_formatTime(record['checkInTime']?.toString())}',
            textColor: _kMuted,
          ),
          const SizedBox(height: 8),
          _recordRow(
            Icons.timer_off_outlined,
            _kRed,
            'Late by: ${_formatLateDuration(record['lateBy']?.toString())}',
            textColor: _kRed,
            weight: FontWeight.w600,
          ),
          if (_hasReason(record)) ...[
            const SizedBox(height: 8),
            _recordRow(Icons.info_outline_rounded, _kAmber,
                'Reason: ${record['reason']}',
                textColor: _kMuted),
          ],
        ]);
      },
    );
  }

  // Absent Records Detail Popup
  void _showAbsentRecordsDialog(
      BuildContext context, List<dynamic> absentRecords) {
    _showRecordsDialog(
      title: 'Absent Records',
      icon: Icons.person_off_rounded,
      color: _kRed,
      emptyText: 'No absent records found',
      records: absentRecords,
      itemBuilder: (record) {
        final bool isOnLeave = record['onLeave'] == true;
        final Color c = isOnLeave ? _kAccent : _kRed;

        return _recordCard(c, [
          _recordRow(
            Icons.calendar_today_rounded,
            c,
            _formatDate(record['date']?.toString()),
            weight: FontWeight.w700,
            size: 14,
          ),
          if (_hasReason(record)) ...[
            const SizedBox(height: 10),
            _recordRow(Icons.info_outline_rounded, c,
                'Reason: ${record['reason']}',
                textColor: _kMuted),
          ],
        ]);
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

  // ---------------------------------------------------------------------------
  // Employee card
  // ---------------------------------------------------------------------------
  Widget _buildEmployeeCard(Map<String, dynamic> emp) {
    final present = emp['presentDays'] ?? 0;
    final late = emp['lateDays'] ?? 0;
    final absent = emp['absentDays'] ?? 0;
    final hoursText =
        '${_safeGetDouble(emp['totalHoursWorked']).toStringAsFixed(1)}h';

    final bool isPeriodicReport = _selectedFilter == 'Date Range';

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
        boxShadow: _softShadow,
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

  Widget _buildDetailItem(
    String label,
    String value,
    Color color,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    return Material(
      color: _kBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: onTap != null ? color.withOpacity(0.30) : _kLine,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 19, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: _kMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: color,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: _kMuted),
            ],
          ),
        ),
      ),
    );
  }
}