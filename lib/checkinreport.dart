import 'dart:convert';
import 'dart:io';

import 'package:attendance_app/services/ApiClient.dart';
import 'package:attendance_app/services/apiservice.dart';
import 'package:attendance_app/widgets/SizeConfig.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class CheckinReportScreen extends StatefulWidget {
  const CheckinReportScreen({super.key});

  @override
  _CheckinReportScreen createState() => _CheckinReportScreen();
}

class _CheckinReportScreen extends State<CheckinReportScreen> {
  List<dynamic> _employeeSummaries = [];
  bool _isLoading = true;
  bool _isExporting = false;

  // Filter variables
  String _selectedFilter = 'Today';
  DateTime? _startDate;
  DateTime? _endDate;

  /// Which employee is currently expanded (keyed by empCode).
  /// Only one can be expanded at a time.
  String? _expandedEmpCode;

  // Professional UI palette
  static const Color _primary = Color.fromARGB(255, 12, 86, 147);
  static const Color _pageBackground = Color(0xFFF5F7FB);
  static const Color _border = Color(0xFFE4E9F0);
  static const Color _textPrimary = Color(0xFF172033);
  static const Color _textSecondary = Color(0xFF6B7280);


  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final managerId = ApiService.empGuid;
      String url = '';

      if (_selectedFilter == 'Today') {
        final dateStr = DateTime.now().toIso8601String().split('T')[0];
        url = 'report/checkIn?date=$dateStr&managerId=$managerId';
      } else {
        final start = _startDate ?? DateTime.now();
        final end = _endDate ?? DateTime.now();

        final startStr = start.toIso8601String().split('T')[0];
        final endStr = end.toIso8601String().split('T')[0];

        // NOTE: parameter name is `endDate` — must match backend signature.
        url =
            'report/checkIn?date=$startStr&eDate=$endStr&managerId=$managerId';
      }

      debugPrint('CheckIn report URL: $url');

      final response = await ApiClient().dio.get(url);

      if (response.statusCode == 200) {
        final data = response.data;

        setState(() {
          _employeeSummaries = [];
          _expandedEmpCode = null;

          if (data is Map) {
            final summaries = data['employeeSummaries'];
            if (summaries is List) {
              _employeeSummaries = List<Map<String, dynamic>>.from(summaries);
            } else {
              debugPrint(
                  'employeeSummaries is not a List. Type: ${summaries.runtimeType}');
            }
          } else if (data is List) {
            _employeeSummaries = List<Map<String, dynamic>>.from(data);
          } else {
            debugPrint('Unexpected response type: ${data.runtimeType}');
          }

          _isLoading = false;
        });

        // Diagnostic: how many groups / unique dates did we receive?
        _debugLogGroups();
      } else {
        debugPrint('API Error: ${response.data}');
        setState(() => _isLoading = false);
      }
    } catch (e, stackTrace) {
      debugPrint('Error loading report: $e');
      debugPrint('$stackTrace');
      setState(() => _isLoading = false);
    }
  }

  /// Temporary diagnostic to help identify backend grouping issues.
  void _debugLogGroups() {
    for (final emp in _employeeSummaries) {
      if (emp is! Map<String, dynamic>) continue;
      final empCode = emp['employeeId']?.toString() ?? '?';
      final groups = _asList(emp['checkInRecords']);
      final dates = <String>{};
      for (final g in groups) {
        if (g is Map) {
          final d = g['date'];
          dates.add(d?.toString() ?? 'null');
        }
      }
      debugPrint(
          'Emp $empCode: ${groups.length} group(s), unique dates: $dates');
    }
  }

  Future<void> _exportExcelReport() async {
    setState(() => _isExporting = true);

    try {
      final managerId = ApiService.empGuid;

      String startDate;
      String endDate;
      String reportType;

      if (_selectedFilter == 'Today') {
        final todayStr = DateTime.now().toIso8601String().split('T')[0];
        startDate = todayStr;
        endDate = todayStr;
        reportType = 'today';
      } else {
        final start = _startDate ?? DateTime.now();
        final end = _endDate ?? DateTime.now();

        startDate = start.toIso8601String().split('T')[0];
        endDate = end.toIso8601String().split('T')[0];
        reportType = 'range';
      }

      final url =
          'report/getExcelReport?startDate=$startDate&endDate=$endDate&reportType=$reportType&managerId=$managerId';

      final response = await ApiClient().dio.get(
        url,
        options: Options(
          responseType: ResponseType.bytes,
        ),
      );

      if (response.statusCode == 200) {
        final directory = await getApplicationDocumentsDirectory();
        final fileName =
            'CheckInOutReport_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
        final filePath = '${directory.path}/$fileName';
        final file = File(filePath);

        await file.writeAsBytes(response.data as List<int>);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Excel report exported successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 6),
            action: SnackBarAction(
              label: 'VIEW EXCEL',
              textColor: Colors.white,
              onPressed: () => _openExportedFile(filePath),
            ),
          ),
        );
      } else {
        throw Exception('Failed to download report: ${response.statusCode}');
      }
    } on DioException catch (e, stackTrace) {
      String serverMessage = e.message ?? 'Unknown error';
      final data = e.response?.data;
      if (data is List<int>) {
        try {
          serverMessage = utf8.decode(data);
        } catch (_) {}
      } else if (data != null) {
        serverMessage = data.toString();
      }

      debugPrint(
          'Error exporting report: HTTP ${e.response?.statusCode} - $serverMessage');
      debugPrint('$stackTrace');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Export failed (${e.response?.statusCode}): $serverMessage'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('Error exporting report: $e');
      debugPrint('$stackTrace');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting report: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isExporting = false);
    }
  }

  Future<void> _openExportedFile(String filePath) async {
    final result = await OpenFilex.open(filePath);

    if (result.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open file: ${result.message}'),
          backgroundColor: Colors.red,
        ),
      );
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
        });
        _loadData();
      }
    }
  }

  static List<dynamic> _asList(dynamic value) {
    if (value is List) return value;
    if (value == null) return [];
    if (value is Map) {
      if (value.isNotEmpty) {
        debugPrint('Expected a List but got a Map with keys: ${value.keys}');
      }
      return [];
    }
    debugPrint('Expected a List but got ${value.runtimeType}: $value');
    return [];
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

  String _formatDate(dynamic raw) {
    if (raw == null) return '';
    try {
      return DateFormat('MMM dd, yyyy').format(DateTime.parse(raw.toString()));
    } catch (_) {
      return raw.toString();
    }
  }

  String _formatTime(dynamic raw) {
    if (raw == null) return '';
    try {
      return DateFormat('hh:mm a').format(DateTime.parse(raw.toString()));
    } catch (_) {
      return raw.toString();
    }
  }

  List<Map<String, dynamic>> _flattenRecords(List<dynamic> rawGroups) {
    final flattened = <Map<String, dynamic>>[];

    for (final group in rawGroups) {
      if (group is! Map) continue;
      final groupMap = Map<String, dynamic>.from(group);
      final groupDate = groupMap['date'];
      final innerRecords = _asList(groupMap['records']);

      if (innerRecords.isEmpty) {
        flattened.add({
          'attendanceDate': _formatDate(groupDate),
          '_sortDate': groupDate?.toString() ?? '',
          '_sortTime': '',
          'checkInTime': '',
          'checkOutTime': '',
          'source': '',
          'location': '',
          'statusLabel': 'ABSENT',
        });
        continue;
      }

      final sortedInner = innerRecords.whereType<Map>().toList()
        ..sort((a, b) {
          final ta = (a['checkInTime'] ?? a['checkOutTime'])?.toString() ?? '';
          final tb = (b['checkInTime'] ?? b['checkOutTime'])?.toString() ?? '';
          return ta.compareTo(tb);
        });

      for (final rec in sortedInner) {
        final recMap = Map<String, dynamic>.from(rec);
        final dateValue = groupDate ?? recMap['date'];

        final source = recMap['source']?.toString() ?? '';
        final location = recMap['location']?.toString() ?? '';

        final checkIn = recMap['checkInTime'];
        final checkOut = recMap['checkOutTime'];

        final statusLabel =
            (checkIn == null && checkOut == null) ? 'ABSENT' : 'PRESENT';

        flattened.add({
          'attendanceDate': _formatDate(dateValue),
          '_sortDate': dateValue?.toString() ?? '',
          '_sortTime': (checkIn ?? checkOut)?.toString() ?? '',
          'checkInTime': _formatTime(checkIn),
          'checkOutTime': _formatTime(checkOut),
          'source': source,
          'location': location,
          'statusLabel': statusLabel,
        });
      }
    }

    flattened.sort((a, b) {
      final da = (a['_sortDate'] ?? '') as String;
      final db = (b['_sortDate'] ?? '') as String;
      final cmp = db.compareTo(da);
      if (cmp != 0) return cmp;
      final ta = (a['_sortTime'] ?? '') as String;
      final tb = (b['_sortTime'] ?? '') as String;
      return ta.compareTo(tb);
    });

    return flattened;
  }

  List<MapEntry<String, List<Map<String, dynamic>>>> _groupByDate(
      List<Map<String, dynamic>> records) {
    final orderedKeys = <String>[];
    final map = <String, List<Map<String, dynamic>>>{};

    for (final r in records) {
      final key = (r['attendanceDate'] ?? '') as String;
      if (!map.containsKey(key)) {
        map[key] = [];
        orderedKeys.add(key);
      }
      map[key]!.add(r);
    }

    return orderedKeys.map((k) => MapEntry(k, map[k]!)).toList();
  }

  Color _statusColor(String statusLabel) {
    switch (statusLabel) {
      case 'PRESENT':
        return Colors.green;
      case 'LATE':
        return Colors.orange;
      case 'ABSENT':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Map<String, String> _buildEmployeeHeaderData(Map<String, dynamic> emp) {
    final empCode = emp['employeeId']?.toString() ?? '';
    final empName = emp['employeeName']?.toString() ?? 'Unknown';

    final rawGroups = _asList(emp['checkInRecords']);
    final records = _flattenRecords(rawGroups);

    String dateRange = '';
    if (records.isNotEmpty) {
      final newest = records.first['attendanceDate'] as String;
      final oldest = records.last['attendanceDate'] as String;

      if (oldest == newest) {
        dateRange = newest;
      } else {
        final oldParts = oldest.split(', ');
        final newParts = newest.split(', ');
        final sameYear = oldParts.length == 2 &&
            newParts.length == 2 &&
            oldParts[1] == newParts[1];

        dateRange = sameYear
            ? '${oldParts[0]} - ${newParts[0]}'
            : '$oldest - $newest';
      }
    }

    return {
      'empCode': empCode,
      'empName': empName,
      'dateRange': dateRange,
    };
  }

  void _toggleExpanded(String empCode) {
    setState(() {
      _expandedEmpCode = (_expandedEmpCode == empCode) ? null : empCode;
    });
  }

  Map<String, dynamic>? _getExpandedEmployee() {
    if (_expandedEmpCode == null) return null;
    for (final emp in _employeeSummaries) {
      if (emp is Map<String, dynamic> &&
          emp['employeeId']?.toString() == _expandedEmpCode) {
        return emp;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final expandedEmp = _getExpandedEmployee();
    final isDetailView = expandedEmp != null;

    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color.fromARGB(255, 12, 86, 147),
        titleSpacing: isDetailView ? 0 : 16,
        title: Text(
          isDetailView
              ? 'Check In/Out Detail'
              : 'Check In/Out Report',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
        actions: [
          IconButton(
            tooltip: 'Export Excel',
            icon: _isExporting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.blue[700],
                    ),
                  )
                : const Icon(Icons.file_download_outlined),
            onPressed: _isExporting ? null : _exportExcelReport,
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _isLoading ? null : _loadData,
          ),
          const SizedBox(width: 4),
        ],
        bottom: isDetailView
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(124),
                child: _buildFilterSection(),
              ),
      ),
      body: isDetailView
          ? _buildDetailBody(expandedEmp!)
          : _buildReportBody(),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildFilterChip('Today', Icons.today_rounded)),
              const SizedBox(width: 10),
              Expanded(
                child: _buildFilterChip(
                  'Date Range',
                  Icons.date_range_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: _selectedFilter == 'Date Range' ? _selectDateRange : null,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: _pageBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border),
              ),
              child: Row(
                children: [
                  Icon(
                    _selectedFilter == 'Today'
                        ? Icons.event_available_rounded
                        : Icons.calendar_month_rounded,
                    size: 18,
                    color: Colors.blue[700],
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      _getFilterDisplayText(),
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_selectedFilter == 'Date Range')
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.grey[600],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportBody() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primary, _primary.withOpacity(0.72)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: _primary.withOpacity(0.16),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(
                Icons.groups_rounded,
                color: Colors.white,
                size: 21,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Employee Attendance',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _buildCountBadge(_employeeSummaries.length),
            ],
          ),
        ),
        Expanded(
          child: _buildReportContent(),
        ),
      ],
    );
  }

  Widget _buildReportContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_employeeSummaries.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      color: Colors.blue[700],
      onRefresh: _loadData,
      child: _buildEmployeeList(),
    );
  }

  Widget _buildDetailBody(Map<String, dynamic> emp) {
    return Column(
      children: [
        _buildPinnedEmployeeHeader(emp),
        Expanded(
          child: RefreshIndicator(
            color: Colors.blue[700],
            onRefresh: _loadData,
            child: _buildExpandedDetail(emp),
          ),
        ),
      ],
    );
  }

  Widget _buildCountBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _selectedFilter == 'Today'
                      ? Icons.event_available_rounded
                      : Icons.calendar_view_day_rounded,
                  size: 38,
                  color: Colors.blue[700],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No attendance records',
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _selectedFilter == 'Today'
                    ? 'There are no check-in/out records for today.'
                    : 'No records were found for the selected date range.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeList() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _employeeSummaries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final emp = _employeeSummaries[index];
        if (emp is! Map<String, dynamic>) {
          return const SizedBox.shrink();
        }

        final header = _buildEmployeeHeaderData(emp);
        return _buildEmployeeRow(
          empCode: header['empCode'] ?? '',
          empName: header['empName'] ?? '',
          dateRange: header['dateRange'] ?? '',
          isExpanded: false,
          onTap: () => _toggleExpanded(header['empCode'] ?? ''),
        );
      },
    );
  }

  Widget _buildExpandedDetail(Map<String, dynamic> emp) {
    final rawGroups = _asList(emp['checkInRecords']);
    final records = _flattenRecords(rawGroups);
    final dateGroups = _groupByDate(records);

    debugPrint(
        'Expanded emp: ${emp['employeeId']} -> ${dateGroups.length} date group(s)');

    if (dateGroups.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Text(
              'No attendance records for this period',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: dateGroups.length,
      itemBuilder: (context, index) {
        final entry = dateGroups[index];
        return _buildDateCard(entry.key, entry.value);
      },
    );
  }

  Widget _buildPinnedEmployeeHeader(Map<String, dynamic> emp) {
    final header = _buildEmployeeHeaderData(emp);
    final name = header['empName'] ?? 'Unknown';
    final code = header['empCode'] ?? '-';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_primary, _primary.withOpacity(0.72)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.16),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.35),
              ),
            ),
            child: Text(
              name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  code,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.78),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close details',
            onPressed: () => setState(() => _expandedEmpCode = null),
            icon: const Icon(
              Icons.close_rounded,
              color: Colors.white,
              size: 21,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeRow({
    required String empCode,
    required String empName,
    required String dateRange,
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    final initials = empName.trim().isNotEmpty
        ? empName.trim().substring(0, 1).toUpperCase()
        : '?';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isExpanded ? Colors.blue.shade200 : _border,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.035),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_primary, _primary.withOpacity(0.72)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      empName.isNotEmpty ? empName : 'Unknown Employee',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(
                          Icons.badge_outlined,
                          size: 13,
                          color: _textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            empCode.isNotEmpty ? empCode : '-',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (dateRange.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxWidth: 105),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    dateRange,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.blue[800],
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.07),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerCell(String label, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  static const double _colCheckInWidth = 90;
  static const double _colCheckOutWidth = 90;
  static const double _colSourceWidth = 50;
  static const double _colLocationWidth = 300;

  double get _tableTotalWidth =>
      _colCheckInWidth +
      _colCheckOutWidth +
      _colSourceWidth +
      _colLocationWidth;

  Widget _buildDateCard(
      String dateLabel, List<Map<String, dynamic>> dayRecords) {
    final allAbsent =
        dayRecords.every((r) => (r['statusLabel'] ?? '') == 'ABSENT');
    final dayStatus = allAbsent ? 'ABSENT' : 'PRESENT';
    final statusColor = _statusColor(dayStatus);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 11),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    Icons.calendar_today_rounded,
                    size: 16,
                    color: Colors.blue[700],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    dateLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.09),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        allAbsent
                            ? Icons.cancel_outlined
                            : Icons.check_circle_outline_rounded,
                        size: 13,
                        color: statusColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dayStatus,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: _border),
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              child: SizedBox(
                width: _tableTotalWidth,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      color: _pageBackground,
                      child: Row(
                        children: [
                          _tableHeaderCell(
                            'Check In',
                            width: _colCheckInWidth,
                          ),
                          _tableHeaderCell(
                            'Check Out',
                            width: _colCheckOutWidth,
                          ),
                          _tableHeaderCell(
                            'Source',
                            width: _colSourceWidth,
                          ),
                          _tableHeaderCell(
                            'Location',
                            width: _colLocationWidth,
                          ),
                        ],
                      ),
                    ),
                    ...dayRecords.asMap().entries.map((e) {
                      final idx = e.key;
                      final r = e.value;
                      final status = r['statusLabel']?.toString() ?? '';
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: idx.isEven ? Colors.white : _pageBackground,
                          border: Border(
                            bottom: BorderSide(
                              color: _border,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            _tableCell(
                              (r['checkInTime'] ?? '').toString(),
                              width: _colCheckInWidth,
                            ),
                            _tableCell(
                              (r['checkOutTime'] ?? '').toString(),
                              width: _colCheckOutWidth,
                            ),
                            _tableCell(
                              (r['source'] ?? '').toString(),
                              width: _colSourceWidth,
                            ),
                            _tableCell(
                              (r['location'] ?? '').toString(),
                              width: _colLocationWidth,
                              align: TextAlign.left,
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableHeaderCell(String label, {required double width}) {
    return SizedBox(
      width: width,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.blue[800],
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _tableCell(
    String value, {
    required double width,
    TextAlign align = TextAlign.center,
  }) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          value.isNotEmpty ? value : '-',
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black87,
          ),
          textAlign: align,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, IconData icon) {
    final isSelected = _selectedFilter == label;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (_selectedFilter == label) return;

          setState(() => _selectedFilter = label);

          if (label == 'Today') {
            _loadData();
          } else if (label == 'Date Range' &&
              _startDate != null &&
              _endDate != null) {
            _loadData();
          }
        },
        borderRadius: BorderRadius.circular(11),
        child: Ink(
          height: 40,
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: [_primary, _primary.withOpacity(0.72)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected ? null : _pageBackground,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: isSelected ? Colors.transparent : _border,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: isSelected ? Colors.white : Colors.blue[700],
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : _textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}