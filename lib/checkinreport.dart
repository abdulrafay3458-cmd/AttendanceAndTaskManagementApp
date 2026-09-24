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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final managerId = ApiService.employeeId;
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
      final managerId = ApiService.employeeId;

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
      appBar: AppBar(
        title: Text(
          isDetailView ? 'Check In/Out Detail' : 'Check In/Out Report',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue[700],
        leading: isDetailView
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() => _expandedEmpCode = null);
                },
              )
            : null,
        actions: [
          IconButton(
            icon: _isExporting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.blue[700],
                    ),
                  )
                : const Icon(Icons.file_download),
            onPressed: _isExporting ? null : _exportExcelReport,
            tooltip: 'Export Excel Report',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[50],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: _buildFilterChip('Today', Icons.today)),
                    const SizedBox(width: 12),
                    Expanded(
                        child:
                            _buildFilterChip('Date Range', Icons.date_range)),
                  ],
                ),
                const SizedBox(height: 12),
                if (_selectedFilter == 'Date Range')
                  InkWell(
                    onTap: _selectDateRange,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 18, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _getFilterDisplayText(),
                              style: TextStyle(
                                color:
                                    (_startDate == null || _endDate == null)
                                        ? Colors.grey
                                        : Colors.black,
                              ),
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down,
                              color: Colors.grey),
                        ],
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.today, size: 18, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Text(_getFilterDisplayText()),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Global column header
          Container(
            color: Colors.blue[700],
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                _headerCell('Emp Code', flex: 2),
                _headerCell('Emp Name', flex: 4),
                _headerCell('Date', flex: 3),
              ],
            ),
          ),

          // Pinned employee header — only visible when one is expanded
          if (isDetailView) _buildPinnedEmployeeHeader(expandedEmp!),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _employeeSummaries.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _selectedFilter == 'Today'
                                  ? Icons.check_circle
                                  : Icons.calendar_view_day,
                              size: 64,
                              color: Colors.green,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No records found',
                              style: TextStyle(
                                  fontSize: 18, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: isDetailView
                            ? _buildExpandedDetail(expandedEmp)
                            : _buildEmployeeList(),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeList() {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _employeeSummaries.length,
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
    return Material(
      color: const Color.fromARGB(255, 255, 252, 252),
      elevation: 4,
      child: InkWell(
        onTap: () {
          setState(() => _expandedEmpCode = null);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const Icon(
                Icons.keyboard_arrow_down,
                color: Color.fromARGB(255, 0, 0, 0),
                size: 20,
              ),
              const SizedBox(width: 4),
              Expanded(
                flex: 2,
                child: Text(
                  header['empCode'] ?? '-',
                  style: const TextStyle(
                    color: Color.fromARGB(255, 0, 0, 0),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    header['empName'] ?? '-',
                    style: const TextStyle(
                      color: Color.fromARGB(255, 0, 0, 0),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    header['dateRange'] ?? '-',
                    style: const TextStyle(
                      color: Color.fromARGB(255, 0, 0, 0),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        ),
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
    return Material(
      color: const Color.fromARGB(255, 249, 252, 255),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: const Color.fromARGB(255, 249, 252, 255)!
                    .withOpacity(0.4),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isExpanded
                    ? Icons.keyboard_arrow_down
                    : Icons.keyboard_arrow_right,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 4),
              Expanded(
                flex: 2,
                child: Text(
                  empCode.isNotEmpty ? empCode : '-',
                  style: const TextStyle(
                    color: Color.fromARGB(255, 1, 1, 1),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    empName.isNotEmpty ? empName : '-',
                    style: const TextStyle(
                      color: Color.fromARGB(255, 1, 1, 1),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    dateRange.isNotEmpty ? dateRange : '-',
                    style: const TextStyle(
                      color: Color.fromARGB(255, 1, 1, 1),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
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

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    dateLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  dayStatus,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: _statusColor(dayStatus),
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const ClampingScrollPhysics(),
            child: SizedBox(
              width: _tableTotalWidth,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    color: Colors.blue[50],
                    child: Row(
                      children: [
                        _tableHeaderCell('Check In', width: _colCheckInWidth),
                        _tableHeaderCell('Check Out',
                            width: _colCheckOutWidth),
                        _tableHeaderCell('Source', width: _colSourceWidth),
                        _tableHeaderCell('Location',
                            width: _colLocationWidth),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  ...dayRecords.asMap().entries.map((e) {
                    final idx = e.key;
                    final r = e.value;
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color:
                            idx.isEven ? Colors.white : Colors.grey[50],
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey.shade200,
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
                          ),
                        ],
                      ),
                    );
                  }),
                ],
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

  Widget _tableCell(String value, {required double width}) {
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
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, IconData icon) {
    final isSelected = _selectedFilter == label;
    return FilterChip(
      label: Row(
        children: [
          Icon(icon,
              size: 16, color: isSelected ? Colors.white : Colors.blue[700]),
          const SizedBox(width: 4, height: 28),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedFilter = label;
          });
          if (label == 'Today') {
            _loadData();
          } else if (label == 'Date Range' &&
              _startDate != null &&
              _endDate != null) {
            _loadData();
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
}