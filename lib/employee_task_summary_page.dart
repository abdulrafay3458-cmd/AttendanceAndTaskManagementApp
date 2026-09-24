import 'package:attendance_app/models/extra_task_report.dart';
import 'package:attendance_app/models/task_time_log_response.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:attendance_app/widgets/SizeConfig.dart';
import 'package:attendance_app/services/apiservice.dart';
import 'package:attendance_app/models/task_report.dart';
import 'package:attendance_app/models/task_export_request.dart';

class EmployeeTaskSummaryPage extends StatefulWidget {
  const EmployeeTaskSummaryPage({super.key});

  @override
  State<EmployeeTaskSummaryPage> createState() =>
      _EmployeeTaskSummaryPageState();
}

enum CompletionFilter { all, onTime, late }

class _EmployeeTaskSummaryPageState extends State<EmployeeTaskSummaryPage>
    with SingleTickerProviderStateMixin {
  late Future<List<EmployeeTaskReport>> future;
  late String _currentPeriod;

  // Filter variables
  String _selectedFilter = 'Today';
  DateTime? _startDate;
  DateTime? _endDate;
  String _dateBreakdown = 'Day'; // Day, Month, Year

  EmployeeTaskReport? _selectedEmployee;
  Map<String, List<TaskReport>> _groupedTasks = {};
  final Set<String> _expandedEmployees = {};

  final String managerId = ApiService.currentEmployee!.employeeId;

  CompletionFilter _completionFilter = CompletionFilter.all;
  bool _showFilterMenu = false;

  @override
  void initState() {
    super.initState();
    _currentPeriod = _getCurrentPeriod();
    future = _loadData();
  }

  bool _isTaskCompletedOnTime(TaskReport task) {
    if (task.completedAt == null || task.taskDueDate == null) return false;
    return !task.completedAt!.isAfter(task.taskDueDate!);
  }

  bool _isTaskCompletedLate(TaskReport task) {
    if (task.completedAt == null || task.taskDueDate == null) return false;
    return task.completedAt!.isAfter(task.taskDueDate!);
  }

  bool _shouldShowTask(TaskReport task) {
    switch (_completionFilter) {
      case CompletionFilter.all:
        return true;
      case CompletionFilter.onTime:
        return _isTaskCompletedOnTime(task);
      case CompletionFilter.late:
        return _isTaskCompletedLate(task);
    }
  }

  List<TaskReport> _filterTasks(List<TaskReport> tasks) {
    return tasks.where(_shouldShowTask).toList();
  }

  String _getFilterDisplayText() {
    switch (_completionFilter) {
      case CompletionFilter.all:
        return 'All';
      case CompletionFilter.onTime:
        return 'On Time';
      case CompletionFilter.late:
        return 'Late';
    }
  }

  IconData _getFilterIcon() {
    switch (_completionFilter) {
      case CompletionFilter.all:
        return Icons.filter_list;
      case CompletionFilter.onTime:
        return Icons.check_circle;
      case CompletionFilter.late:
        return Icons.warning;
    }
  }

  Color _getFilterColor() {
    switch (_completionFilter) {
      case CompletionFilter.all:
        return Colors.white;
      case CompletionFilter.onTime:
        return Colors.blue.shade700;
      case CompletionFilter.late:
        return Colors.blue.shade700;
    }
  }

  Widget _buildFilterChip() {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: _completionFilter != CompletionFilter.all,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getFilterIcon(),
              size: 18,
              color: _completionFilter != CompletionFilter.all 
                  ? Colors.white 
                  : _getFilterColor(),
            ),
            const SizedBox(width: 4),
            Text(
              _getFilterDisplayText(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600
              ),
            ),
          ],
        ),
        onSelected: (selected) {
          setState(() {
            _showFilterMenu = true;
          });
          _showFilterDialog();
        },
        selectedColor: _getFilterColor(),
        showCheckmark: false,
        backgroundColor: Colors.blue[700],
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: const StadiumBorder(
          side: BorderSide(color: Colors.transparent),
        ),
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Filter Tasks'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.filter_list, color: Colors.grey),
                title: const Text('All'),
                onTap: () {
                  setState(() {
                    _completionFilter = CompletionFilter.all;
                    _showFilterMenu = false;
                  });
                  Navigator.pop(context);
                },
                selected: _completionFilter == CompletionFilter.all,
                selectedTileColor: Colors.grey.shade100,
              ),
              ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: const Text('On Time'),
                onTap: () {
                  setState(() {
                    _completionFilter = CompletionFilter.onTime;
                    _showFilterMenu = false;
                  });
                  Navigator.pop(context);
                },
                selected: _completionFilter == CompletionFilter.onTime,
                selectedTileColor: Colors.green.shade50,
              ),
              ListTile(
                leading: const Icon(Icons.warning, color: Colors.orange),
                title: const Text('Late'),
                onTap: () {
                  setState(() {
                    _completionFilter = CompletionFilter.late;
                    _showFilterMenu = false;
                  });
                  Navigator.pop(context);
                },
                selected: _completionFilter == CompletionFilter.late,
                selectedTileColor: Colors.orange.shade50,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }
  
  void _resetToCurrentPeriod() {
    setState(() {
      _selectedFilter = 'Today';
      _startDate = null;
      _endDate = null;
      _currentPeriod = _getCurrentPeriod();
      future = _loadData();
      _clearSelection();
    });
  }

  void _clearSelection() {
    _selectedEmployee = null;
    _groupedTasks = {};
    _expandedEmployees.clear();
    _completionFilter = CompletionFilter.all;
  }

  void _refreshData() {
    setState(() {
      future = _loadData();
      _clearSelection();
    });
  }

  String _getCurrentPeriod() {
    if (_selectedFilter == 'Today') {
      return '${DateFormat('EEEE, MMMM dd, yyyy').format(DateTime.now())}';
    } else {
      if (_startDate != null && _endDate != null) {
        return '${DateFormat('MMM dd, yyyy').format(_startDate!)} - ${DateFormat('MMM dd, yyyy').format(_endDate!)}';
      }
      return 'Select Date Range';
    }
  }

  Future<List<EmployeeTaskReport>> _loadData() async {
  DateTime start, end;
  
  if (_selectedFilter == 'Today') {
    start = DateTime.now();
    end = DateTime.now();
  } else {
    start = _startDate ?? DateTime.now().subtract(const Duration(days: 7));
    end = _endDate ?? DateTime.now();
  }
  
  return await ApiService.getDateRangeReport(start, end, managerId);
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
          _selectedFilter = 'Date Range';
          _currentPeriod = _getCurrentPeriod();
        });
        _refreshData();
      }
    }
  }

  void _handleExportSelection(String value) async {
  final parts = value.split('_');
  if (parts.length != 2) return;

  final action = parts[0];
  final scope = parts[1];

  ExportRequest request;

  if (_selectedFilter == 'Today') {
    final today = DateTime.now();
    request = ExportRequest(
      startDate: today,
      endDate: today,
      managerId: managerId,
      employeeId: scope == 'selected' ? _selectedEmployee?.employeeCode : null,
    );
  } else {
    if (_startDate == null || _endDate == null) {
      _showSnackBar('Please select a date range first');
      return;
    }
    
    request = ExportRequest(
      startDate: _startDate!,
      endDate: _endDate!,
      managerId: managerId,
      employeeId: scope == 'selected' ? _selectedEmployee?.employeeCode : null,
      viewType: _dateBreakdown,
    );
  }

  // Show loading dialog
  if (context.mounted) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Opening report...',
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            Text(
              'This may take a few seconds',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  final success = await ApiService.exportTaskReport(
    request,
    share: action == 'share',
  );

  if (context.mounted) Navigator.pop(context);

  if (success) {
    String employeeText = scope == 'selected'
        ? _selectedEmployee!.employeeName
        : 'All employees';
    String actionText = action == 'share' ? 'shared' : 'opened';
    
    String periodText;
    if (_selectedFilter == 'Today') {
      periodText = ' (Today: ${DateFormat('MMM dd, yyyy').format(DateTime.now())})';
    } else {
      periodText = ' (${DateFormat('MMM dd').format(_startDate!)} - ${DateFormat('MMM dd').format(_endDate!)})';
    }

    _showSnackBar(
      'Report $actionText successfully for $employeeText$periodText',
    );
  } else {
    _showSnackBar('Export failed. Please try again.');
  }
}

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.blue.shade700,
      ),
    );
  }

  Map<String, List<TaskReport>> _groupTasksByDate(List<TaskReport> tasks) {
    final Map<String, List<TaskReport>> grouped = {};

    for (final task in tasks) {
      final Map<String, List<TaskTimeLogResponse>> logsByDate = {};

      for (final log in task.timeLogs) {
        try {
          final dateKey = DateFormat('yyyy-MM-dd').format(
            DateTime.parse(log.startTime),
          );
          logsByDate.putIfAbsent(dateKey, () => []).add(log);
        } catch (e) {
          continue;
        }
      }

      logsByDate.forEach((dateKey, logs) {
        grouped.putIfAbsent(dateKey, () => []).add(
          TaskReport(
            taskid: task.taskid,
            taskTitle: task.taskTitle,
            taskStatus: task.taskStatus,
            taskPriority: task.taskPriority,
            taskDueDate: task.taskDueDate,
            completedAt: task.completedAt,
            timeLogs: logs,
          ),
        );
      });
    }

    return grouped;
  }

  double _calculateEmployeeTotalHours(EmployeeTaskReport employee) {
    return employee.tasks.fold<double>(
      0,
      (sum, task) => sum + _calculateTaskTotalHours(task),
    );
  }

  double _calculateTaskTotalHours(TaskReport task) {
    return task.timeLogs.fold<double>(
      0,
      (sum, log) => sum + log.hoursWorked,
    );
  }

  double _calculateLogsHours(Iterable<TaskTimeLogResponse> logs) {
    return logs.fold<double>(
      0,
      (sum, log) => sum + log.hoursWorked,
    );
  }

  String _getEmployeeInitials(String name) {
    if (name.trim().isEmpty) return '';
    
    final parts = name.trim().split(RegExp(r'\s+'));
    
    if (parts.length == 1) return parts[0][0].toUpperCase();
    
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Color _getEmployeeAvatarColor(EmployeeTaskReport employee) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.cyan,
    ];
    
    return colors[employee.employeeCode.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: FutureBuilder<List<EmployeeTaskReport>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    "Loading reports...",
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Colors.red,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Error loading data",
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ),
            );
          }

          final employees = snapshot.data ?? [];

          return Row(
            children: [
              // Left panel - Employee list
              Container(
                width: MediaQuery.of(context).size.width * 0.25,
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border(
                    right: BorderSide(color: Colors.grey.shade200, width: 1),
                  ),
                ),
                child: _buildEmployeeList(employees),
              ),

              // Right panel - Summary view
              Expanded(
                child: Container(
                  color: Colors.white,
                  child: Column(
                    children: [
                      if (_selectedEmployee != null) _buildEmployeeHeader(),
                      Expanded(
                        child: employees.isEmpty
                            ? _buildNoDataView(
                                message:
                                    'No task records found for selected period',
                                subtitle: 'Try selecting a different period',
                              )
                            : _buildSummaryView(employees),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: Colors.blue[700],
      elevation: 0,
      centerTitle: false,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Task Report",
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: SizeConfig.f(18),
              color: Colors.blue[700],
            ),
          ),
          const SizedBox(height: 2),
          // Text(
          //   _currentPeriod,
          //   style: TextStyle(
          //     fontSize: 12,
          //     color: Colors.blue[700]?.withOpacity(0.7),
          //   ),
          // ),
        ],
      ),
      actions: [
        // IconButton(
        //   icon: const Icon(Icons.calendar_month_outlined),
        //   onPressed: () => _showFilterOptions(),
        //   tooltip: 'Select Filter',
        //   iconSize: 22,
        // ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.download),
          tooltip: 'Export Report',
          onSelected: _handleExportSelection,
          itemBuilder: (context) => _buildExportMenuItems(),
        ),
        _buildFilterChip(),
        IconButton(
          icon: const Icon(Icons.refresh_outlined),
          onPressed: _refreshData,
          tooltip: 'Refresh',
          iconSize: 22,
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(140),
        child: Container(
          // margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: _buildFilterBar(),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
  return Container(
    padding: const EdgeInsets.all(16),
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
        if (_selectedFilter == 'Date Range')
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _selectDateRange,
                  child: Container(
                    width: double.infinity,
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
                            _getDateRangeText(),
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
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _dateBreakdown,
                    isDense: true,
                    icon: const Icon(Icons.arrow_drop_down, size: 18),
                    items: ['Day', 'Month', 'Year'].map((option) {
                      return DropdownMenuItem(
                        value: option,
                        child: Text(option, style: const TextStyle(fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _dateBreakdown = value);
                      }
                    },
                  ),
                ),
              ),
            ],
          )
        else
          Container(
            width: double.infinity,
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
  );
}

 Widget _buildFilterChipOption(String label, IconData icon) {
  final isSelected = _selectedFilter == label;
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
        setState(() {
          _selectedFilter = label;
        });
        if (label == 'Today') {
          _startDate = null;
          _endDate = null;
          _refreshData();
        } else if (label == 'Date Range' && _startDate != null && _endDate != null) {
          _refreshData();
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

  String _getDateRangeText() {
  if (_startDate != null && _endDate != null) {
    return '${DateFormat('MMM dd, yyyy').format(_startDate!)} - ${DateFormat('MMM dd, yyyy').format(_endDate!)}';
  }
  return 'Select Date Range';
}

String _getTodayDisplayText() {
  return 'Today: ${DateFormat('MMM dd, yyyy').format(DateTime.now())}';
}


  void _showFilterOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Filter',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.today, color: Colors.blue),
                title: const Text('Today'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _selectedFilter = 'Today';
                    _startDate = null;
                    _endDate = null;
                  });
                  _refreshData();
                },
              ),
              ListTile(
                leading: const Icon(Icons.date_range, color: Colors.blue),
                title: const Text('Date Range'),
                onTap: () {
                  Navigator.pop(context);
                  _selectDateRange();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  List<PopupMenuEntry<String>> _buildExportMenuItems() {
    final items = <PopupMenuEntry<String>>[
      const PopupMenuItem(
        value: 'view_all',
        child: ListTile(
          leading: Icon(Icons.visibility, color: Colors.blue),
          title: Text('View Report'),
          subtitle: Text('All Employees - Open in Excel/Sheets'),
          dense: true,
        ),
      ),
    ];

    if (_selectedEmployee != null) {
      items.addAll([
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'view_selected',
          child: ListTile(
            leading: Icon(Icons.visibility, color: Colors.green),
            title: Text('View Report'),
            subtitle: Text(_selectedEmployee!.employeeName),
            dense: true,
          ),
        ),
      ]);
    } else {
      items.addAll([
        const PopupMenuDivider(),
        const PopupMenuItem(
          enabled: false,
          child: ListTile(
            leading: Icon(Icons.person_outline, color: Colors.grey),
            title: Text('Select an employee first'),
            dense: true,
          ),
        ),
      ]);
    }
    
    return items;
  }

  Widget _buildEmployeeHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _getEmployeeAvatarColor(_selectedEmployee!),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _getEmployeeInitials(_selectedEmployee!.employeeName),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedEmployee!.employeeName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                Text(
                  _selectedEmployee!.employeeCode,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Text(
              "${formatHours(_calculateEmployeeTotalHours(_selectedEmployee!))} total",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.blue.shade700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeList(List<EmployeeTaskReport> employees) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Employees",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: employees.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 40,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "No employees",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: employees.length,
                  itemBuilder: (context, index) => _buildEmployeeListItem(
                    employees[index],
                    index == employees.length - 1,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildEmployeeListItem(EmployeeTaskReport employee, bool isLast) {
    final isSelected = _selectedEmployee?.employeeCode == employee.employeeCode;

    return Column(
      children: [
        Material(
          color: isSelected ? Colors.blue.shade50 : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: () => setState(() {
              if (isSelected) {
                _selectedEmployee = null;
                _groupedTasks = {};
              } else {
                _selectedEmployee = employee;
                _groupedTasks = _groupTasksByDate(employee.tasks);
              }
            }),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _getEmployeeAvatarColor(employee),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _getEmployeeInitials(employee.employeeName),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (isSelected)
                    Container(
                      width: 7,
                      alignment: Alignment.centerRight,
                      child: Icon(
                        Icons.check_circle,
                        size: 16,
                        color: Colors.blue.shade700,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 16,
            color: Colors.grey.shade200,
          ),
      ],
    );
  }

  Widget _buildSummaryView(List<EmployeeTaskReport> employees) {
    if (_selectedEmployee == null) {
      return _buildOverallSummary(employees);
    } else {
      return _buildEmployeeDetailView();
    }
  }

  Widget _buildOverallSummary(List<EmployeeTaskReport> employees) {
    final allTasks = employees.expand((emp) => emp.tasks).toList();

    // For date range view, we need to group by date
    if (_selectedFilter == 'Today') {
      return _buildTodayView(allTasks, employees);
    } else {
      return _buildDateRangeView(allTasks, employees);
    }
  }

  Widget _buildTodayView(List<TaskReport> allTasks, List<EmployeeTaskReport> employees) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          alignment: Alignment.center,
          child: Text(
            'Today\'s Tasks',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: _buildDaySummaryWithEmployee(today, allTasks, employees),
        ),
      ],
    );
  }

  Widget _buildDateRangeView(List<TaskReport> allTasks, List<EmployeeTaskReport> employees) {
    if (_startDate == null || _endDate == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.date_range, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Select a date range',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _selectDateRange,
              child: const Text('Select Dates'),
            ),
          ],
        ),
      );
    }

    switch (_dateBreakdown) {
      case 'Month':
        return _buildMonthBreakdownView(allTasks, employees);
      case 'Year':
        return _buildYearBreakdownView(allTasks, employees);
      default:
        return _buildDayBreakdownView(allTasks, employees);
    }
  }

  // ── Day breakdown ──────────────────────────────
  Widget _buildDayBreakdownView(List<TaskReport> allTasks, List<EmployeeTaskReport> employees) {
    final dates = <String>[];
    for (var day = _startDate!;
         day.isBefore(_endDate!.add(const Duration(days: 1)));
         day = day.add(const Duration(days: 1))) {
      dates.add(DateFormat('yyyy-MM-dd').format(day));
    }

    return Column(
      children: [
        const SizedBox(height: 5),
        Expanded(
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: dates.length,
            itemBuilder: (context, index) {
              final dateKey = dates[index];
              return Container(
                width: MediaQuery.of(context).size.width * 0.4,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            DateFormat('E').format(DateTime.parse(dateKey)),
                            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                          ),
                          Text(
                            DateFormat('dd').format(DateTime.parse(dateKey)),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SizedBox(
                        height: 300,
                        child: _buildDaySummaryWithEmployee(dateKey, allTasks, employees),
                      ),
                    ),
                    _buildDayFooter(
                      _calculateTotalHoursForDate(dateKey, allTasks),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Month breakdown ──────────────────
  Widget _buildMonthBreakdownView(List<TaskReport> allTasks, List<EmployeeTaskReport> employees) {
    // Collect unique year-month keys within the range
    final months = <String>[];
    var cursor = DateTime(_startDate!.year, _startDate!.month, 1);
    final endMonth = DateTime(_endDate!.year, _endDate!.month, 1);
    while (!cursor.isAfter(endMonth)) {
      months.add(DateFormat('yyyy-MM').format(cursor));
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }

    return Column(
      children: [
        const SizedBox(height: 5),
        Expanded(
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: months.length,
            itemBuilder: (context, index) {
              final monthKey = months[index];
              final monthDate = DateTime.parse('$monthKey-01');
              return Container(
                width: MediaQuery.of(context).size.width * 0.4,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            DateFormat('MMM').format(monthDate),
                            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                          ),
                          Text(
                            DateFormat('yyyy').format(monthDate),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SizedBox(
                        height: 300,
                        child: _buildPeriodSummaryWithEmployee(
                          allTasks,
                          employees,
                          (DateTime logDate) => DateFormat('yyyy-MM').format(logDate) == monthKey,
                        ),
                      ),
                    ),
                    _buildDayFooter(
                      _calculateTotalHoursForPeriod(allTasks,
                          (DateTime d) => DateFormat('yyyy-MM').format(d) == monthKey),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Year breakdown ──────────────────────
  Widget _buildYearBreakdownView(List<TaskReport> allTasks, List<EmployeeTaskReport> employees) {
    final years = <String>[];
    for (var y = _startDate!.year; y <= _endDate!.year; y++) {
      years.add(y.toString());
    }

    return Column(
      children: [
        const SizedBox(height: 5),
        Expanded(
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: years.length,
            itemBuilder: (context, index) {
              final yearKey = years[index];
              return Container(
                width: MediaQuery.of(context).size.width * 0.4,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Year',
                            style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                          ),
                          Text(
                            yearKey,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SizedBox(
                        height: 300,
                        child: _buildPeriodSummaryWithEmployee(
                          allTasks,
                          employees,
                          (DateTime logDate) => logDate.year.toString() == yearKey,
                        ),
                      ),
                    ),
                    _buildDayFooter(
                      _calculateTotalHoursForPeriod(allTasks,
                          (DateTime d) => d.year.toString() == yearKey),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodNavigationBar({
    required VoidCallback onPrevious,
    required VoidCallback onNext,
    required String periodText,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: onPrevious,
          ),
          Text(
            periodText,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: onNext,
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard({
    required TaskReport task,
    required double hours,
    Color? backgroundColor,
    String? employeeInitials,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: (backgroundColor ?? Colors.blue.shade100).withOpacity(0.5),
          ),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.taskTitle,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatHours(hours),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.black.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Status indicator
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: task.statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      task.displayStatus,
                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (employeeInitials != null)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Colors.grey.shade300,
                      width: 0.5,
                    ),
                  ),
                  child: Text(
                    employeeInitials,
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Map<String, String> _findEmployeeForTask(
    TaskReport task,
    List<EmployeeTaskReport> employees,
  ) {
    for (var emp in employees) {
      if (emp.tasks.any((t) => t.taskid == task.taskid)) {
        return {
          'name': emp.employeeName,
          'initials': _getEmployeeInitials(emp.employeeName),
        };
      }
    }
    return {'name': 'Unknown', 'initials': ''};
  }

  List<TaskTimeLogResponse> _filterLogsByDate(
    TaskReport task,
    bool Function(DateTime) condition,
  ) {
    return task.timeLogs.where((log) {
      try {
        return condition(DateTime.parse(log.startTime));
      } catch (e) {
        return false;
      }
    }).toList();
  }

  Widget _buildDaySummaryWithEmployee(
    String dateKey,
    List<TaskReport> allTasks,
    List<EmployeeTaskReport> employees,
  ) {
    final relevantTasks = allTasks.where((task) {
      return task.timeLogs.any((log) {
        try {
          return DateFormat('yyyy-MM-dd').format(
                DateTime.parse(log.startTime),
              ) ==
              dateKey;
        } catch (e) {
          return false;
        }
      });
    }).where(_shouldShowTask).toList();

    if (relevantTasks.isEmpty) {
      return Center(
        child: Text(
          "No tasks",
          style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(4),
      itemCount: relevantTasks.length,
      itemBuilder: (context, index) {
        final task = relevantTasks[index];
        final filteredLogs = _filterLogsByDate(
          task,
          (date) => DateFormat('yyyy-MM-dd').format(date) == dateKey,
        );
        final taskHours = _calculateLogsHours(filteredLogs);
        final filteredTask = TaskReport(
          taskid: task.taskid,
          taskTitle: task.taskTitle,
          taskStatus: task.taskStatus,
          taskPriority: task.taskPriority,
          taskDueDate: task.taskDueDate,
          completedAt: task.completedAt,
          timeLogs: filteredLogs,
        );
        final employeeInfo = _findEmployeeForTask(task, employees);

        return _buildTaskCard(
          task: filteredTask,
          hours: taskHours,
          backgroundColor: Colors.blue.shade50,
          employeeInitials: employeeInfo['initials'],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TaskDetailView(
                task: filteredTask,
                employeeName: employeeInfo['name']!,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDayFooter(double totalHours) {
    return Container(
      width: double.infinity,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      child: Text(
        formatHours(totalHours),
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }

  Widget _buildEmployeeDetailView() {
    if (_selectedEmployee == null) return const SizedBox();

    final tasks = _selectedEmployee!.tasks;
    final filteredTasks = _filterTasks(tasks);

    if (filteredTasks.isEmpty) {
      String message;
      if (tasks.isEmpty) {
        message = 'No task records found for ${_selectedEmployee!.employeeName}';
      } else {
        message = 'No ${_getFilterDisplayText().toLowerCase()} tasks found for ${_selectedEmployee!.employeeName}';
      }

      return _buildNoDataView(
        message: message,
        subtitle: _completionFilter != CompletionFilter.all
            ? 'Try changing or clearing the filter'
            : 'in ${_getCurrentPeriod()}',
      );
    }

    // For Date Range, apply the same breakdown columns as the overall view
    if (_selectedFilter == 'Date Range' && _startDate != null && _endDate != null) {
      final singleEmployeeList = [_selectedEmployee!];
      switch (_dateBreakdown) {
        case 'Month':
          return _buildMonthBreakdownView(filteredTasks, singleEmployeeList);
        case 'Year':
          return _buildYearBreakdownView(filteredTasks, singleEmployeeList);
        default:
          return _buildDayBreakdownView(filteredTasks, singleEmployeeList);
      }
    }

    // Today — flat list (original behaviour)
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredTasks.length,
      itemBuilder: (context, index) {
        final task = filteredTasks[index];
        return _buildTaskCard(
          task: task,
          hours: _calculateTaskTotalHours(task),
          backgroundColor: Colors.blue.shade50,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TaskDetailView(
                task: task,
                employeeName: _selectedEmployee!.employeeName,
              ),
            ),
          ),
        );
      },
    );
  }

  // Calculation methods
  double _calculateTotalHoursForDate(
    String dateKey,
    List<TaskReport> allTasks,
  ) {
    double total = 0;
    
    for (final task in allTasks) {
      total += _calculateLogsHours(
        _filterLogsByDate(
          task,
          (date) => DateFormat('yyyy-MM-dd').format(date) == dateKey,
        ),
      );
    }
    
    return total;
  }

  // Generic period total (used by Month and Year breakdowns)
  double _calculateTotalHoursForPeriod(
    List<TaskReport> allTasks,
    bool Function(DateTime) condition,
  ) {
    double total = 0;
    for (final task in allTasks) {
      total += _calculateLogsHours(_filterLogsByDate(task, condition));
    }
    return total;
  }

  // Generic period task list (used by Month and Year breakdowns)
  Widget _buildPeriodSummaryWithEmployee(
    List<TaskReport> allTasks,
    List<EmployeeTaskReport> employees,
    bool Function(DateTime) condition,
  ) {
    final relevantTasks = allTasks.where((task) {
      return task.timeLogs.any((log) {
        try {
          return condition(DateTime.parse(log.startTime));
        } catch (e) {
          return false;
        }
      });
    }).where(_shouldShowTask).toList();

    if (relevantTasks.isEmpty) {
      return Center(
        child: Text(
          "No tasks",
          style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(4),
      itemCount: relevantTasks.length,
      itemBuilder: (context, index) {
        final task = relevantTasks[index];
        final filteredLogs = _filterLogsByDate(task, condition);
        final taskHours = _calculateLogsHours(filteredLogs);
        final filteredTask = TaskReport(
          taskid: task.taskid,
          taskTitle: task.taskTitle,
          taskStatus: task.taskStatus,
          taskPriority: task.taskPriority,
          taskDueDate: task.taskDueDate,
          completedAt: task.completedAt,
          timeLogs: filteredLogs,
        );
        final employeeInfo = _findEmployeeForTask(task, employees);

        return _buildTaskCard(
          task: filteredTask,
          hours: taskHours,
          backgroundColor: Colors.blue.shade50,
          employeeInitials: employeeInfo['initials'],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TaskDetailView(
                task: filteredTask,
                employeeName: employeeInfo['name']!,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoDataView({required String message, String? subtitle}) {
    String filterMessage = '';
    if (_completionFilter != CompletionFilter.all) {
      filterMessage = ' with "${_getFilterDisplayText()}" filter';
    }
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _completionFilter != CompletionFilter.all 
                  ? _getFilterIcon() 
                  : Icons.calendar_today,
              size: 48,
              color: _completionFilter != CompletionFilter.all 
                  ? _getFilterColor().withOpacity(0.5)
                  : Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            message + filterMessage,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (_completionFilter != CompletionFilter.all)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _completionFilter = CompletionFilter.all;
                });
              },
              icon: const Icon(Icons.clear),
              label: const Text('Clear Filter'),
            )
          else if (_selectedFilter == 'Date Range' && (_startDate == null || _endDate == null))
            ElevatedButton(
              onPressed: _selectDateRange,
              child: const Text('Select Date Range'),
            )
          else
            Text(
              'Try selecting a different period',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
            ),
        ],
      ),
    );
  }
}

class TaskDetailView extends StatelessWidget {
  final TaskReport task;
  final String employeeName;

  const TaskDetailView({
    super.key,
    required this.task,
    required this.employeeName,
  });

  String _formatDate(String isoTime) {
    try {
      return DateFormat('MMM dd, yyyy').format(DateTime.parse(isoTime));
    } catch (e) {
      return isoTime;
    }
  }

  String _formatTime(String isoTime) {
    try {
      return DateFormat('hh:mm a').format(DateTime.parse(isoTime));
    } catch (e) {
      return isoTime;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.taskTitle,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
            Text(
              employeeName,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary Card
            Card(
              color: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryItem(
                      icon: Icons.access_time,
                      label: "Total Logs",
                      value: "${task.timeLogs.length}",
                      color: Colors.blue[700]!,
                    ),
                    Container(
                      height: 40,
                      width: 1,
                      color: Colors.grey.shade300,
                    ),
                    _buildSummaryItem(
                      icon: Icons.timer,
                      label: "Total Hours",
                      value: formatHours(
                        task.timeLogs.fold<double>(0, (sum, log) => sum + log.hoursWorked),
                      ),
                      color: Colors.blue.shade700,
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),

            Text(
              "Task Details",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color:Colors.blue[700],),
            ),
            const SizedBox(height: 12),
            
            // Task Details Section (if available)
            if (task.taskDueDate != null || task.completedAt != null) ...[
              _buildTaskDetailsSection(),
              const SizedBox(height: 20),
            ],
            
            // Time Logs Header
            Text(
              "Time Logs",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.blue[700],),
            ),
            const SizedBox(height: 12),
            
            // Time Logs List
            if (task.timeLogs.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "No time logs available",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...task.timeLogs.map((log) => _buildTimeLogItem(log)),
          ],
        ),
      ),
    );
  }

 Widget _buildTaskDetailsSection() {
  return Card(
    color: Colors.white,
    elevation: 1,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Priority
          if (task.taskPriority.isNotEmpty) ...[
            _buildDetailRow(
              icon: Icons.flag,
              label: "Priority",
              value: task.taskPriority.capitalize(),
              valueColor: _getPriorityColor(task.taskPriority),
            ),
            const SizedBox(height: 8),
          ],
          
          // if (task.taskPriority.isNotEmpty) ...[
          //   _buildDetailRow(
          //     icon: Icons.flag,
          //     label: "Priority",
          //     value: task.taskPriority.capitalize(),
          //     valueColor: _getPriorityColor(task.taskPriority),
          //   ),
          //   const SizedBox(height: 8),
          // ],

          // Due Date
          if (task.taskDueDate != null) ...[
            _buildDetailRow(
              icon: Icons.event,
              label: "Due Date",
              value: _formatDate(task.taskDueDate!.toIso8601String()),
              valueColor: task.taskDueDate!.isBefore(DateTime.now()) 
                  ? Colors.red 
                  : Colors.grey.shade800,
            ),
            const SizedBox(height: 8),
          ],
          
          if (task.completedAt != null) ...[
            if (task.taskDueDate != null && task.completedAt!.isAfter(task.taskDueDate!)) ...[
              _buildDetailRow(
                icon: Icons.warning_amber,
                label: "Late Completed",
                value: _getLateCompletionText(),
                valueColor: Colors.orange,
              ),
              const SizedBox(height: 4),
              _buildDetailRow(
                icon: Icons.access_time,
                label: "Delay",
                value: _getDelayDuration(),
                valueColor: Colors.red,
              ),
              const SizedBox(height: 4),
              _buildDetailRow(
                icon: Icons.check_circle,
                label: "Completed On",
                value: "${_formatDate(task.completedAt!.toIso8601String())} at ${_formatTime(task.completedAt!.toIso8601String())}",
                valueColor: Colors.green,
              ),
            ] else ...[
              _buildDetailRow(
                icon: Icons.check_circle,
                label: task.taskDueDate != null ? "Completed (On Time)" : "Completed",
                value: "${_formatDate(task.completedAt!.toIso8601String())} at ${_formatTime(task.completedAt!.toIso8601String())}",
                valueColor: Colors.green,
              ),
            ],
          ],
        ],
      ),
    ),
  );
}

String _getLateCompletionText() {
  if (task.completedAt == null || task.taskDueDate == null) return '';
  
  final completed = task.completedAt!;
  final dueDate = task.taskDueDate!;
  
  if (completed.isAfter(dueDate)) {
    return 'Completed after due date';
  }
  return 'Completed on time';
}

String _getDelayDuration() {
  if (task.completedAt == null || task.taskDueDate == null) return '';
  
  final completed = task.completedAt!;
  final dueDate = task.taskDueDate!;
  
  if (!completed.isAfter(dueDate)) return 'No delay';
  
  final difference = completed.difference(dueDate);
  
  if (difference.inDays > 0) {
    return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ${_formatHoursMinutes(difference)}';
  } else if (difference.inHours > 0) {
    return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ${_formatMinutes(difference)}';
  } else if (difference.inMinutes > 0) {
    return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
  } else {
    return 'Less than a minute';
  }
}

String _formatHoursMinutes(Duration duration) {
  final hours = duration.inHours % 24;
  final minutes = duration.inMinutes % 60;
  
  if (hours > 0 && minutes > 0) {
    return '$hours hour${hours > 1 ? 's' : ''} $minutes minute${minutes > 1 ? 's' : ''}';
  } else if (hours > 0) {
    return '$hours hour${hours > 1 ? 's' : ''}';
  } else if (minutes > 0) {
    return '$minutes minute${minutes > 1 ? 's' : ''}';
  }
  return '';
}

String _formatMinutes(Duration duration) {
  final minutes = duration.inMinutes % 60;
  return minutes > 0 ? '$minutes minute${minutes > 1 ? 's' : ''}' : '';
}

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.blue[700]),
        const SizedBox(width: 12),
        Text(
          "$label:",
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: valueColor,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey.shade700;
    }
  }

  Widget _buildTimeLogItem(TaskTimeLogResponse log) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (log.notes.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.note,
                    size: 16,
                    color: Colors.blue[700],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      log.notes,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade800,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.calendar_today,
                  size: 16,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(log.startTime),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.play_arrow,
                                size: 12,
                                color: Colors.green.shade700,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                _formatTime(log.startTime),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.stop,
                                size: 12,
                                color: Colors.red.shade700,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                _formatTime(log.stopTime),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Hours badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue.shade500,
                      Colors.blue.shade400,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  formatHours(log.hoursWorked),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

String formatHours(double hours) {
  final totalMinutes = (hours * 60).round();
  if (totalMinutes < 60) {
    return '${totalMinutes}m';
  }
  final h = totalMinutes ~/ 60;
  final m = totalMinutes % 60;
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}