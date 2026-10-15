import 'dart:convert';

import 'package:attendance_app/main.dart';
import 'package:attendance_app/services/ApiClient.dart';
import 'package:attendance_app/services/apiservice.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class AbsentEmployeesScreen extends StatefulWidget {
  const AbsentEmployeesScreen({super.key});

  @override
  _AbsentEmployeesScreenState createState() => _AbsentEmployeesScreenState();
}

class _AbsentEmployeesScreenState extends State<AbsentEmployeesScreen> {
  List<dynamic> _absentEmployees = [];
  bool _isLoading = true;
  
  // Filter variables
  String _selectedFilter = 'Today';
  DateTime? _startDate;
  DateTime? _endDate;
  
  // Expanded state for accordion
  Set<int> _expandedCards = {};

  @override
  void initState() {
    super.initState();
    _loadAbsentEmployees();
  }

  Future<void> _loadAbsentEmployees() async {
    setState(() => _isLoading = true);

    try {
      final managerId = ApiService.empGuid;
      String url = '';
      
      if (_selectedFilter == 'Today') {
        url = 'report/absent/today?managerId=$managerId';
      } else {
        // Date range filter
        if (_startDate == null || _endDate == null) {
          // If dates not selected, default to last 7 days
          _endDate = DateTime.now();
          _startDate = _endDate!.subtract(Duration(days: 7));
        }
        
        final startDateStr = DateFormat('yyyy-MM-dd').format(_startDate!);
        final endDateStr = DateFormat('yyyy-MM-dd').format(_endDate!);
        url = 'report/absent/range?managerId=$managerId&startDate=$startDateStr&endDate=$endDateStr';
      }

      final response = await ApiClient().dio.get(url).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        setState(() {
          _absentEmployees = response.data;
          _isLoading = false;
          _expandedCards.clear(); // Reset expanded state on new data
        });
      } else {
        print('Error response: ${response.data}');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading absent employees: $e');
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
        });
        _loadAbsentEmployees();
      }
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

  // Professional UI
  static const Color _primary = Color.fromARGB(255, 12, 86, 147);
  static const Color _pageBg = Color(0xFFF5F7FB);
  static const Color _textPrimary = Color(0xFF172033);
  static const Color _textSecondary = Color(0xFF687386);
  static const Color _border = Color(0xFFE4E9F0);

  LinearGradient get _primaryGradient => const LinearGradient(
        colors: [_primary, Color(0xFF0C568F)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  @override
  Widget build(BuildContext context) {
    final hasRange = _startDate != null && _endDate != null;

    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color.fromARGB(255, 12, 86, 147),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Absent Employees',
                    style: TextStyle(
                        color: const Color.fromARGB(255, 12, 86, 147),
                        fontSize: 17,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _isLoading ? null : _loadAbsentEmployees,
            icon: _isLoading
                ? const SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Attendance filter',
                          style: TextStyle(
                              color: _textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                      const Spacer(),
                      if (_selectedFilter == 'Date Range' && hasRange)
                        Text(
                          '${_startDate!.difference(_endDate!).inDays.abs() + 1} days',
                          style: const TextStyle(
                              color: _primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: _pageBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                            child: _buildFilterOption(
                                'Today', Icons.today_rounded)),
                        Expanded(
                            child: _buildFilterOption(
                                'Date Range', Icons.date_range_rounded)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _selectedFilter == 'Date Range'
                        ? InkWell(
                            key: const ValueKey('range'),
                            borderRadius: BorderRadius.circular(13),
                            onTap: _selectDateRange,
                            child: _buildDateSelector(),
                          )
                        : _buildTodaySelector(),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: _primary))
                : _absentEmployees.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        color: _primary,
                        onRefresh: _loadAbsentEmployees,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: _absentEmployees.length,
                          itemBuilder: (context, index) {
                            final emp = _absentEmployees[index];
                            return _buildAbsentEmployeeCard(emp, index);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterOption(String label, IconData icon) {
    final selected = _selectedFilter == label;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: 44,
      decoration: BoxDecoration(
        gradient: selected ? _primaryGradient : null,
        color: selected ? null : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: _primary.withOpacity(.18),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          if (_selectedFilter == label) return;
          setState(() => _selectedFilter = label);
          if (label == 'Today') {
            _loadAbsentEmployees();
          } else if (label == 'Date Range') {
            // Open the date picker immediately when Date Range is selected.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _selectedFilter == 'Date Range') {
                _selectDateRange();
              }
            });
          }
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 17, color: selected ? Colors.white : _primary),
            const SizedBox(width: 7),
            Text(label,
                style: TextStyle(
                    color: selected ? Colors.white : _textSecondary,
                    fontSize: 13,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    final active = _startDate != null && _endDate != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: _pageBg,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.calendar_month_rounded,
                color: _primary, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Selected date range',
                    style: TextStyle(
                        color: _textSecondary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  active ? _getFilterDisplayText() : 'Choose start and end dates',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: active ? _textPrimary : _textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: _textSecondary),
        ],
      ),
    );
  }

  Widget _buildTodaySelector() {
    return Container(
      key: const ValueKey('today'),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F8F4),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFD8EBDD)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.event_available_rounded,
                color: Colors.green, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              DateFormat('EEEE, MMM dd, yyyy').format(DateTime.now()),
              style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700),
            ),
          ),
          const Icon(Icons.check_circle_rounded,
              color: Colors.green, size: 20),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final today = _selectedFilter == 'Today';
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(.035),
                  blurRadius: 22,
                  offset: const Offset(0, 8))
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  today
                      ? Icons.verified_user_rounded
                      : Icons.event_available_rounded,
                  color: Colors.green,
                  size: 38,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                today ? 'Everyone is present' : 'No absent records',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 7),
              Text(
                today
                    ? 'All employees have checked in today.'
                    : 'There are no absences in the selected date range.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: _textSecondary, fontSize: 13, height: 1.45),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAbsentEmployeeCard(Map<String, dynamic> emp, int index) {
    final isExpanded = _expandedCards.contains(index);
    final absentRecords = emp['absentRecords'] as List? ?? [];
    final totalAbsentDays = emp['totalAbsentDays'] ?? absentRecords.length;

    if (absentRecords.isEmpty && _selectedFilter != 'Today') {
      return const SizedBox.shrink();
    }

    final employeeName = emp['employeeName']?.toString() ?? 'Unknown';
    final employeeId = emp['employeeId']?.toString() ?? '';
    final department = emp['department']?.toString() ?? '';
    final initial = employeeName.trim().isNotEmpty
        ? employeeName.trim()[0].toUpperCase()
        : '?';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isExpanded ? _primary.withOpacity(.35) : _border,
          width: isExpanded ? 1.2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isExpanded ? .07 : .035),
            blurRadius: isExpanded ? 18 : 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedCards.remove(index);
                  } else {
                    _expandedCards.add(index);
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: _primaryGradient,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initial,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(employeeName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: _textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  employeeId.isEmpty ? 'Employee' : employeeId,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: _textSecondary,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                              if (department.isNotEmpty) ...[
                                const Padding(
                                  padding:
                                      EdgeInsets.symmetric(horizontal: 6),
                                  child: Text('•',
                                      style:
                                          TextStyle(color: _textSecondary)),
                                ),
                                Flexible(
                                  child: Text(
                                    department,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: _textSecondary,
                                        fontSize: 11.5),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(.08),
                            borderRadius: BorderRadius.circular(20),
                            border:
                                Border.all(color: Colors.red.withOpacity(.18)),
                          ),
                          child: Text(
                            _selectedFilter == 'Today'
                                ? 'ABSENT'
                                : '$totalAbsentDays ${totalAbsentDays == 1 ? 'day' : 'days'}',
                            style: const TextStyle(
                                color: Color(0xFFD64545),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: _textSecondary,
                          size: 21,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 430),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: _buildExpandedAbsentDetails(
                    absentRecords,
                    totalAbsentDays,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExpandedAbsentDetails(
      List absentRecords, dynamic totalAbsentDays) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _pageBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(.09),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.event_busy_rounded,
                    color: Color(0xFFD64545), size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Absence details',
                    style: TextStyle(
                        color: _textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800)),
              ),
              if (_selectedFilter == 'Date Range')
                _buildSmallStatusPill(
                    '$totalAbsentDays ${totalAbsentDays == 1 ? 'day' : 'days'}'),
            ],
          ),
          const SizedBox(height: 14),
          if (_selectedFilter == 'Today') ...[
            _buildInfoTile(
              Icons.calendar_today_rounded,
              'Date',
              DateFormat('EEEE, MMMM dd, yyyy').format(DateTime.now()),
            ),
            const SizedBox(height: 8),
            _buildInfoTile(
              Icons.login_rounded,
              'Status',
              'No check-in recorded',
              valueColor: const Color(0xFFD64545),
            ),
          ] else ...[
            const Text('Absent dates',
                style: TextStyle(
                    color: _textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (absentRecords.isEmpty)
              _buildInfoTile(
                  Icons.info_outline_rounded,
                  'Records',
                  'No absent records for this period')
            else
              ...absentRecords.map((record) {
                final recordDate = record['date']?.toString() ?? '';
                String formattedDate = recordDate;
                try {
                  if (recordDate.isNotEmpty) {
                    formattedDate = DateFormat('EEEE, MMMM dd, yyyy')
                        .format(DateTime.parse(recordDate));
                  }
                } catch (_) {}

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: _border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                            color: Color(0xFFD64545), shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(formattedDate,
                            style: const TextStyle(
                                color: _textPrimary,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600)),
                      ),
                      _buildSmallStatusPill('ABSENT'),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 4),
            _buildInfoTile(
              Icons.date_range_rounded,
              'Selected range',
              '${DateFormat('MMM dd, yyyy').format(_startDate!)} - ${DateFormat('MMM dd, yyyy').format(_endDate!)}',
            ),
            const SizedBox(height: 8),
            _buildInfoTile(
              Icons.event_busy_rounded,
              'Total absent',
              '$totalAbsentDays ${totalAbsentDays == 1 ? 'day' : 'days'}',
              valueColor: const Color(0xFFD64545),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value,
      {Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _primary, size: 17),
          const SizedBox(width: 10),
          SizedBox(
            width: 88,
            child: Text(label,
                style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    color: valueColor ?? _textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallStatusPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(text,
          style: const TextStyle(
              color: Color(0xFFD64545),
              fontSize: 9.5,
              fontWeight: FontWeight.w800)),
    );
  }

}
