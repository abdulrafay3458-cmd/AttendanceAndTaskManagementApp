import 'package:attendance_app/services/ApiClient.dart';
import 'package:attendance_app/services/apiservice.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class LateEmployeesScreen extends StatefulWidget {
  const LateEmployeesScreen({super.key});

  @override
  State<LateEmployeesScreen> createState() => _LateEmployeesScreenState();
}

class _LateEmployeesScreenState extends State<LateEmployeesScreen> {
  // ---------------------------------------------------------------------------
  // Design tokens - aligned with dailyreport.dart
  // ---------------------------------------------------------------------------
  static const Color _kBg = Color(0xFFF5F6FA);
  static const Color _kInk = Color(0xFF1F2430);
  static const Color _kMuted = Color(0xFF7A8194);
  static const Color _kLine = Color(0xFFE6E8F0);
  static const Color _kGreen = Color(0xFF22A06B);
  static const Color _kAmber = Color(0xFFE59A1F);
  static const Color _kRed = Color(0xFFE5484D);
  static const Color _kPurple = Color(0xFF7B5CC9);
  static const Color _kAccent = Color.fromARGB(255, 12, 86, 147);
  static const Color _kGradient = Color.fromARGB(255, 12, 86, 147);

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

  List<dynamic> _lateEmployees = [];
  bool _isLoading = true;

  String _selectedFilter = 'Today';
  DateTime? _startDate;
  DateTime? _endDate;

  final Set<int> _expandedCards = {};

  @override
  void initState() {
    super.initState();
    _loadLateEmployees();
  }

  // ---------------------------------------------------------------------------
  // Data loading — always use the range endpoint so "Today" behaves exactly
  // like "Today inside a date range" (which the user confirmed works).
  // ---------------------------------------------------------------------------
  Future<void> _loadLateEmployees() async {
    if (mounted) setState(() => _isLoading = true);

    try {
      final managerId = ApiService.empGuid;

      // Resolve the effective start/end dates based on the selected filter.
      final DateTime effectiveStart;
      final DateTime effectiveEnd;

      if (_selectedFilter == 'Today') {
        final now = DateTime.now();
        effectiveStart = DateTime(now.year, now.month, now.day);
        effectiveEnd = effectiveStart;
      } else {
        // Date Range — fall back to last 7 days if not chosen yet.
        effectiveEnd = _endDate ?? DateTime.now();
        effectiveStart = _startDate ??
            effectiveEnd.subtract(const Duration(days: 7));
      }

      final startStr = DateFormat('yyyy-MM-dd').format(effectiveStart);
      final endStr = DateFormat('yyyy-MM-dd').format(effectiveEnd);

      final url =
          'report/late/range?managerId=$managerId&startDate=$startStr&endDate=$endStr';

      debugPrint('LateEmployees → GET $url');

      final response =
          await ApiClient().dio.get(url).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          _lateEmployees = response.data is List ? response.data : [];
          _isLoading = false;
          _expandedCards.clear();
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading late employees: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Unable to load late employee records.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<void> _pickStartDate() async {
  final DateTime today = DateTime.now();

  final DateTime? pickedStart = await showDatePicker(
    context: context,
    initialDate: _startDate ?? today,
    firstDate: DateTime(2020),
    lastDate: today,
    helpText: 'SELECT START DATE',
  );

  if (pickedStart == null || !mounted) return;

  // Default end date = today (clamped so it can't be before start date).
  final DateTime defaultEnd =
      today.isBefore(pickedStart) ? pickedStart : today;

  setState(() {
    _startDate = pickedStart;
    _endDate = defaultEnd;
    _selectedFilter = 'Date Range';
  });

  // Then optionally prompt for the end date so they can refine it.
  if (!mounted) return;
  await _pickEndDate();
}


Future<void> _pickEndDate() async {
  if (_startDate == null) {
    // No start date yet — restart from step 1.
    return _pickStartDate();
  }

  final DateTime today = DateTime.now();

  final DateTime? pickedEnd = await showDatePicker(
    context: context,
    initialDate: _endDate ?? today,
    firstDate: _startDate!,
    lastDate: today,
    helpText: 'SELECT END DATE',
  );

  if (pickedEnd == null || !mounted) return;

  setState(() {
    _endDate = pickedEnd;
  });

  await _loadLateEmployees();
}


Future<void> _openDateRangeFlow() async {
  if (_startDate == null) {
    // No range selected yet → start from step 1.
    await _pickStartDate();
  } else if (_endDate == null) {
    // Start date exists but no end date → jump to step 2.
    await _pickEndDate();
  } else {
    // Full range already selected → let the user edit the end date.
    await _pickEndDate();
  }
}


  // ---------------------------------------------------------------------------
  // Filter switching
  // ---------------------------------------------------------------------------
void _changeFilter(String filter) {
  if (_selectedFilter == filter) {
    // Re-tapping "Date Range" opens the range flow again.
    if (filter == 'Date Range') {
      _openDateRangeFlow();
    }
    return;
  }

  setState(() {
    _selectedFilter = filter;
    if (filter == 'Today') {
      _startDate = null;
      _endDate = null;
    }
  });

  if (filter == 'Today') {
    _loadLateEmployees();
  } else {
    // Switching to Date Range → always start with the start-date picker.
    _openDateRangeFlow();
  }
}

  String _getFilterDisplayText() {
    if (_selectedFilter == 'Today') {
      return 'Today: ${DateFormat('MMM dd, yyyy').format(DateTime.now())}';
    }

    if (_startDate != null && _endDate != null) {
      return '${DateFormat('MMM dd, yyyy').format(_startDate!)} - '
          '${DateFormat('MMM dd, yyyy').format(_endDate!)}';
    }

    if (_startDate != null) {
      return '${DateFormat('MMM dd, yyyy').format(_startDate!)} - Select End Date';
    }

    return 'Select Date Range';
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse('$value') ?? 0;
  }

  int get _totalLateEmployees => _lateEmployees.length;

  int get _totalLateRecords {
    return _lateEmployees.fold<int>(0, (total, employee) {
      final records = employee is Map ? employee['lateRecords'] : null;
      return total + (records is List ? records.length : 0);
    });
  }

  int get _totalLateMinutes {
    return _lateEmployees.fold<int>(0, (total, employee) {
      if (employee is! Map) return total;
      return total + _toInt(employee['totalLateMinutes']);
    });
  }

  String _formatMinutes(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    if (remainingMinutes == 0) return '${hours}h';
    return '${hours}h ${remainingMinutes}m';
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
          'Late Employees',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _isLoading ? null : _loadLateEmployees,
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
                ? _buildLoadingState()
                : _lateEmployees.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        color: _kAccent,
                        onRefresh: _loadLateEmployees,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                          children: [
                            _buildHeader(),
                            const SizedBox(height: 16),
                            _buildStatistics(),
                            const SizedBox(height: 24),
                            _buildSectionTitle(
                              'Late Employees',
                              '${_lateEmployees.length} employee${_lateEmployees.length == 1 ? '' : 's'}',
                            ),
                            const SizedBox(height: 10),
                            ...List.generate(
                              _lateEmployees.length,
                              (index) => _buildLateEmployeeCard(
                                _lateEmployees[index],
                                index,
                              ),
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Date range selector — aligned with dailyreport.dart
  // ---------------------------------------------------------------------------
  Widget _buildDateRangeSelector() {
    final hasRange = _startDate != null && _endDate != null;
    final hasStartOnly = _startDate != null && _endDate == null;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [_softShadow],
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
                Expanded(
                  child: _buildFilterChip('Today', Icons.today_rounded),
                ),
                Expanded(
                  child: _buildFilterChip(
                      'Date Range', Icons.date_range_rounded),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Date range row
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _selectedFilter == 'Date Range' ? _openDateRangeFlow : null,
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
                      _getDatePickerText(hasRange, hasStartOnly),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: (_selectedFilter == 'Date Range' && !hasRange)
                            ? (hasStartOnly ? _kAmber : _kMuted)
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

          // Helper hint after start date picked but before end date
        if (hasStartOnly) ...[
          const SizedBox(height: 8),
          Row(
            children: const [
              Icon(Icons.info_outline_rounded, size: 14, color: _kAmber),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Tap above to choose an end date.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: _kAmber,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
      ),
    );
  }

  String _getDatePickerText(bool hasRange, bool hasStartOnly) {
    if (_selectedFilter == 'Today') {
      return 'Today: ${DateFormat('MMM dd, yyyy').format(DateTime.now())}';
    }
    if (hasRange) {
      return '${DateFormat('MMM dd, yyyy').format(_startDate!)} - '
          '${DateFormat('MMM dd, yyyy').format(_endDate!)}';
    }
    if (hasStartOnly) {
      return '${DateFormat('MMM dd, yyyy').format(_startDate!)} - Select End Date';
    }
    return 'Select Date Range';
  }

  Widget _buildFilterChip(String label, IconData icon) {
    final isSelected = _selectedFilter == label;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _changeFilter(label),
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
            Icon(
              icon,
              size: 17,
              color: isSelected ? Colors.white : _kMuted,
            ),
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
  // Header banner
  // ---------------------------------------------------------------------------
  Widget _buildHeader() {
    return Container(
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
            child: const Icon(
              Icons.alarm_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Late Attendance',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.88),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _getFilterDisplayText(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  'LATE',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.72),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '$_totalLateRecords',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Statistics grid — matches dailyreport.dart card style
  // ---------------------------------------------------------------------------
  Widget _buildStatistics() {
    final average = _totalLateRecords == 0
        ? 0
        : (_totalLateMinutes / _totalLateRecords).round();

    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 84,
      ),
      children: [
        _buildStatCard(
          icon: Icons.groups_rounded,
          value: '$_totalLateEmployees',
          label: 'Employees',
          color: _kAccent,
        ),
        _buildStatCard(
          icon: Icons.event_busy_rounded,
          value: '$_totalLateRecords',
          label: 'Late Records',
          color: _kRed,
        ),
        _buildStatCard(
          icon: Icons.timer_rounded,
          value: _formatMinutes(_totalLateMinutes),
          label: 'Total Late',
          color: _kAmber,
        ),
        _buildStatCard(
          icon: Icons.speed_rounded,
          value: _formatMinutes(average),
          label: 'Average / Record',
          color: _kGreen,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [_softShadow],
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
                      fontSize: 20,
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
                    fontSize: 12,
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

  Widget _buildSectionTitle(String title, String trailing) {
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
            title,
            style: const TextStyle(
              color: _kInk,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: _kAccent.withOpacity(0.10),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            trailing,
            style: const TextStyle(
              color: _kAccent,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLateEmployeeCard(Map<String, dynamic> emp, int index) {
    final isExpanded = _expandedCards.contains(index);
    final lateRecords = emp['lateRecords'] is List
        ? List<dynamic>.from(emp['lateRecords'])
        : <dynamic>[];
    final totalLateMinutes = _toInt(emp['totalLateMinutes']);

    final employeeName = '${emp['employeeName'] ?? 'Unknown Employee'}'.trim();
    final employeeId = '${emp['employeeId'] ?? ''}'.trim();
    final department = '${emp['department'] ?? ''}'.trim();

    final initials = _getInitials(employeeName);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isExpanded ? _kAccent.withOpacity(0.18) : _kLine,
        ),
        boxShadow: const [_softShadow],
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(18),
                bottom: Radius.circular(isExpanded ? 0 : 18),
              ),
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
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: _bannerGradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            employeeName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _kInk,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (employeeId.isNotEmpty ||
                              department.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              [
                                if (employeeId.isNotEmpty)
                                  'ID: $employeeId',
                                if (department.isNotEmpty) department,
                              ].join(' • '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _kMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: _kRed,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${lateRecords.length} late record${lateRecords.length == 1 ? '' : 's'}',
                                style: const TextStyle(
                                  color: _kRed,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
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
                            horizontal: 9,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: _kRed.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.timer_off_rounded,
                                size: 14,
                                color: _kRed,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _formatMinutes(totalLateMinutes),
                                style: const TextStyle(
                                  color: _kRed,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 10.5,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 5),
                        Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: _kMuted,
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
            _buildExpandedDetails(
              emp: emp,
              lateRecords: lateRecords,
              totalLateMinutes: totalLateMinutes,
            ),
        ],
      ),
    );
  }

  Widget _buildExpandedDetails({
    required Map<String, dynamic> emp,
    required List<dynamic> lateRecords,
    required int totalLateMinutes,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      decoration: const BoxDecoration(
        color: Color(0xFFFAFBFD),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1, color: _kLine),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _kRed.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  color: _kRed,
                  size: 17,
                ),
              ),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'Late Details',
                  style: TextStyle(
                    color: _kInk,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${lateRecords.length} day${lateRecords.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: _kMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (lateRecords.isEmpty)
            _buildNoDetails()
          else
            ...lateRecords.asMap().entries.map(
                  (entry) => _buildLateRecordItem(
                    entry.value,
                    entry.key,
                    lateRecords.length,
                  ),
                ),
          const SizedBox(height: 4),
          _buildDetailSummary(
            totalLateMinutes: totalLateMinutes,
            recordCount: lateRecords.length,
          ),
        ],
      ),
    );
  }

  Widget _buildLateRecordItem(dynamic record, int index, int totalRecords) {
    final recordMap = record is Map ? record : <dynamic, dynamic>{};

    final dateStr = '${recordMap['date'] ?? ''}';
    final lateByStr = '${recordMap['lateBy'] ?? ''}';
    final lateMinutes = _toInt(recordMap['lateMinutes']);

    String formattedDate = dateStr;
    if (dateStr.isNotEmpty) {
      try {
        final dateTime = DateTime.parse(dateStr);
        formattedDate = DateFormat('EEE, MMM dd, yyyy').format(dateTime);
      } catch (_) {}
    }

    return Container(
      margin: EdgeInsets.only(
        bottom: index == totalRecords - 1 ? 10 : 8,
      ),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _kLine),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _kAccent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.calendar_today_rounded,
              size: 17,
              color: _kAccent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formattedDate,
                  style: const TextStyle(
                    color: _kInk,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (recordMap['checkInTime'] != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.login_rounded,
                        size: 12,
                        color: _kMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Check-in ${_formatCheckInTime('${recordMap['checkInTime']}')}',
                        style: const TextStyle(
                          color: _kMuted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
                if (lateByStr.isNotEmpty && lateByStr != '00:00:00') ...[
                  const SizedBox(height: 3),
                  Text(
                    'Late by $lateByStr',
                    style: const TextStyle(
                      color: _kMuted,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: _kRed.withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$lateMinutes min',
              style: const TextStyle(
                color: _kRed,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSummary({
    required int totalLateMinutes,
    required int recordCount,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFF8FAFF),
            Color(0xFFF5F7FB),
          ],
        ),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _kLine),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSummaryValue(
              Icons.date_range_rounded,
              'Period',
              _selectedFilter == 'Today'
                  ? DateFormat('MMM dd, yyyy').format(DateTime.now())
                  : (_startDate != null && _endDate != null
                      ? '${DateFormat('MMM dd').format(_startDate!)} - '
                          '${DateFormat('MMM dd, yyyy').format(_endDate!)}'
                      : 'Selected range'),
            ),
          ),
          Container(width: 1, height: 36, color: _kLine),
          Expanded(
            child: _buildSummaryValue(
              Icons.timer_rounded,
              'Total Late',
              '${_formatMinutes(totalLateMinutes)} • $recordCount day${recordCount == 1 ? '' : 's'}',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryValue(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          Icon(icon, size: 17, color: _kAccent),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: _kMuted,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _kInk,
                    fontSize: 10.5,
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

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Loading late attendance...',
            style: TextStyle(
              color: _kMuted,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return RefreshIndicator(
      color: _kAccent,
      onRefresh: _loadLateEmployees,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 70, 24, 24),
        children: [
          Container(
            width: 80,
            height: 80,
            margin: const EdgeInsets.symmetric(horizontal: 100),
            decoration: BoxDecoration(
              color: _kGreen.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.alarm_off_rounded,
              size: 38,
              color: _kGreen,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No late employees',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _kInk,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _selectedFilter == 'Today'
                ? 'Everyone checked in on time today.'
                : 'No late records were found in the selected date range.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _kMuted,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: FilledButton.icon(
              onPressed: _loadLateEmployees,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Refresh records'),
              style: FilledButton.styleFrom(
                backgroundColor: _kAccent,
                padding: const EdgeInsets.symmetric(
                    horizontal: 22, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDetails() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _kLine),
      ),
      child: const Text(
        'No late details available for this employee.',
        style: TextStyle(color: _kMuted, fontSize: 12),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return '${parts.first.substring(0, 1)}'
            '${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  String _formatCheckInTime(String? checkInTimeStr) {
    if (checkInTimeStr == null || checkInTimeStr.isEmpty) return 'N/A';
    try {
      final dateTime = DateTime.parse(checkInTimeStr);
      return DateFormat('hh:mm a').format(dateTime.toLocal());
    } catch (_) {
      return checkInTimeStr;
    }
  }
}