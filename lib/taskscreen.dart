import 'dart:io';

import 'package:attendance_app/main.dart';
import 'package:attendance_app/models/AssignedTaskModel.dart';
import 'package:attendance_app/services/apiservice.dart';
import 'package:attendance_app/taskdetail.dart'; // StopTaskDialog
import 'package:attendance_app/widgets/SizeConfig.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

// -----------------------------------------------------------------------------
// Design tokens
// -----------------------------------------------------------------------------
const Color _kBg = Color(0xFFF5F6FA);
const Color _kInk = Color(0xFF1F2430);
const Color _kMuted = Color(0xFF7A8194);
const Color _kLine = Color(0xFFE6E8F0);
const Color _kGreen = Color(0xFF22A06B);
const Color _kRed = Color(0xFFE5484D);
const Color _kAmber = Color(0xFFE59A1F);

/// Base color for gradient banners / avatars.
const Color _kGradient = Color.fromARGB(255, 12, 86, 147);

/// Accent color for pills, icon tiles and the dialog icon box.
const Color _kAccent = Colors.blue;

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

String _initials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

Color _priorityColor(String p) {
  switch (p.toLowerCase()) {
    case 'high':
      return _kRed;
    case 'low':
      return _kGreen;
    default:
      return _kAmber;
  }
}

/// Days from today to the due date (negative = overdue). Null if no due date.
int? _daysUntilDue(AssignedTaskModel t) {
  final due = t.dueDate?.toLocal();
  if (due == null) return null;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return DateTime(due.year, due.month, due.day).difference(today).inDays;
}

bool _isOverdue(AssignedTaskModel t) {
  final d = _daysUntilDue(t);
  return d != null && d < 0 && !t.isCompleted;
}

bool _isDueSoon(AssignedTaskModel t) {
  final d = _daysUntilDue(t);
  return d != null && d >= 0 && d <= 7 && !t.isCompleted;
}

String _fmtDate(DateTime? d) =>
    d == null ? '-' : DateFormat('MMM dd, yyyy').format(d.toLocal());

String formatHours(double totalHours) {
  final duration = Duration(minutes: (totalHours * 60).round());
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  return '${hours}h ${minutes}m';
}

enum _TaskFilter { all, overdue, dueSoon }

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  _TasksScreenState createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  List<AssignedTaskModel> _tasks = [];
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  String? _busyTaskId;
  _TaskFilter _filter = _TaskFilter.all;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  void _snack(String message, {bool isError = false, Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color ?? (isError ? _kRed : _kInk),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    final employeeId = ApiService.empGuid;
    if (employeeId == null) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Employee not found. Please log in again.';
      });
      return;
    }

    try {
      final tasks = await ApiService.getAssignedTasks(employeeId);

      // The backend query can return the same task more than once
      // (one row per matching team / membership) - keep the first of each.
      final seen = <String>{};
      final unique = tasks.where((t) => seen.add(t.taskId)).toList();

      // Soonest due date first; tasks without a due date last.
      unique.sort((a, b) {
        if (a.dueDate == null && b.dueDate == null) return 0;
        if (a.dueDate == null) return 1;
        if (b.dueDate == null) return -1;
        return a.dueDate!.compareTo(b.dueDate!);
      });

      if (!mounted) return;
      setState(() {
        _tasks = unique;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Could not load tasks';
      });
      print('Error loading tasks: $e');
    }
  }

  List<AssignedTaskModel> get _visibleTasks {
    switch (_filter) {
      case _TaskFilter.overdue:
        return _tasks.where(_isOverdue).toList();
      case _TaskFilter.dueSoon:
        return _tasks.where(_isDueSoon).toList();
      case _TaskFilter.all:
        return _tasks;
    }
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
        foregroundColor: Colors.blue[700],
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Text(
          'All Tasks',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: SizeConfig.f(20),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadTasks,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hasError
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _loadTasks,
                  child: _tasks.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 120),
                            _EmptyState(
                              icon: Icons.task_alt_rounded,
                              title: 'No active tasks',
                              message: 'Tasks assigned to you will show up here.',
                            ),
                          ],
                        )
                      : _buildList(),
                ),
    );
  }

  Widget _buildList() {
    final visible = _visibleTasks;

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      itemCount: visible.isEmpty ? 3 : visible.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) return _buildBanner();
        if (index == 1) return _buildFilters();
        if (visible.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(top: 24),
            child: _EmptyState(
              icon: Icons.filter_alt_off_rounded,
              title: 'Nothing here',
              message: 'No tasks match this filter.',
            ),
          );
        }
        return _buildTaskCard(visible[index - 2]);
      },
    );
  }

  Widget _buildError() {
    return Center(
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
              child: const Icon(Icons.error_outline_rounded,
                  size: 38, color: _kRed),
            ),
            const SizedBox(height: 14),
            Text(
              _errorMessage ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _kInk,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Check your connection and try again.',
              style: TextStyle(fontSize: 13.5, color: _kMuted),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadTasks,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                backgroundColor: _kAccent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBanner() {
    final overdue = _tasks.where(_isOverdue).length;
    final dueSoon = _tasks.where(_isDueSoon).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_tasks.length} task(s)',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$overdue overdue  •  $dueSoon due this week',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.88),
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.20),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.checklist_rounded,
                color: Colors.white, size: 30),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    Widget chip(String label, _TaskFilter value, int count) {
      final selected = _filter == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => setState(() => _filter = value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? _kAccent : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: selected ? null : _softShadow,
            ),
            child: Text(
              '$label ($count)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : _kMuted,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            chip('All', _TaskFilter.all, _tasks.length),
            chip('Overdue', _TaskFilter.overdue,
                _tasks.where(_isOverdue).length),
            chip('Due this week', _TaskFilter.dueSoon,
                _tasks.where(_isDueSoon).length),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Task card
  // ---------------------------------------------------------------------------
  Widget _buildTaskCard(AssignedTaskModel task) {
    final priorityColor = _priorityColor(task.priority);
    final busy = _busyTaskId == task.taskId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: _softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _showDetails(task),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title + priority
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _kInk,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _Pill(
                      icon: Icons.flag_rounded,
                      text: task.priority,
                      color: priorityColor,
                    ),
                  ],
                ),

                if (task.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    task.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: _kMuted,
                      height: 1.4,
                    ),
                  ),
                ],

                // Team / status pills
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (task.teamName.isNotEmpty)
                      _Pill(
                        icon: Icons.groups_rounded,
                        text: task.teamName,
                        color: _kAccent,
                      ),
                    if (task.isRunning)
                      const _Pill(
                        icon: Icons.circle,
                        iconSize: 8,
                        text: 'Running',
                        color: _kGreen,
                      ),
                    if (task.isCompleted)
                      const _Pill(
                        icon: Icons.check_circle_rounded,
                        text: 'Completed',
                        color: _kAmber,
                      ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(height: 1, color: _kLine),
                const SizedBox(height: 12),

                // Assigned by + dates
                Row(
                  children: [
                    _InitialsAvatar(
                      name: task.assignedBy,
                      size: SizeConfig.f(30),
                      radius: 15,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Assigned by',
                            style: TextStyle(fontSize: 11.5, color: _kMuted),
                          ),
                          Text(
                            task.assignedBy.isEmpty ? '-' : task.assignedBy,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: _kInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildDueLabel(task),
                  ],
                ),

                if (task.startDate != null || task.dueDate != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.date_range_rounded,
                          size: 15, color: _kMuted),
                      const SizedBox(width: 6),
                      Text(
                        '${_fmtDate(task.startDate)}  →  ${_fmtDate(task.dueDate)}',
                        style: const TextStyle(fontSize: 12.5, color: _kMuted),
                      ),
                    ],
                  ),
                ],

                if (task.totalHoursWorked > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined,
                          size: 15, color: _kAccent),
                      const SizedBox(width: 6),
                      Text(
                        'Total: ${formatHours(task.totalHoursWorked)}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: _kAccent,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 14),

                // Actions
                Row(
                  children: [
                    if (!task.isCompleted) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: busy
                              ? null
                              : (task.isRunning
                                  ? () => _stopTask(task)
                                  : () => _handleStartTask(task)),
                          icon: busy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : Icon(
                                  task.isRunning
                                      ? Icons.stop_rounded
                                      : Icons.play_arrow_rounded,
                                  size: 18,
                                ),
                          label: Text(task.isRunning ? 'Stop' : 'Start'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                                task.isRunning ? _kRed : _kGreen,
                            side: BorderSide(
                              color: (task.isRunning ? _kRed : _kGreen)
                                  .withOpacity(0.6),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _showDetails(task),
                        icon: const Icon(Icons.visibility_outlined, size: 18),
                        label: const Text('View Details'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDueLabel(AssignedTaskModel task) {
    final days = _daysUntilDue(task);
    if (days == null || task.isCompleted) return const SizedBox.shrink();

    late final String text;
    late final Color color;
    if (days < 0) {
      text = 'Overdue ${-days}d';
      color = _kRed;
    } else if (days == 0) {
      text = 'Due today';
      color = _kAmber;
    } else if (days == 1) {
      text = 'Due tomorrow';
      color = _kAmber;
    } else {
      text = 'Due in ${days}d';
      color = _kMuted;
    }

    return _Pill(icon: Icons.event_rounded, text: text, color: color);
  }

  // ---------------------------------------------------------------------------
  // Details sheet
  // ---------------------------------------------------------------------------
  void _showDetails(AssignedTaskModel task) {
    final priorityColor = _priorityColor(task.priority);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kBg,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _kLine,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      task.title,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: _kInk,
                      ),
                    ),
                  ),
                  IconButton(
                    style: IconButton.styleFrom(
                        backgroundColor: Colors.white),
                    icon: const Icon(Icons.close_rounded, color: _kInk),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _Pill(
                    icon: Icons.flag_rounded,
                    text: task.priority,
                    color: priorityColor,
                  ),
                  if (task.teamName.isNotEmpty)
                    _Pill(
                      icon: Icons.groups_rounded,
                      text: task.teamName,
                      color: _kAccent,
                    ),
                  if (task.isRunning)
                    const _Pill(
                      icon: Icons.circle,
                      iconSize: 8,
                      text: 'Running',
                      color: _kGreen,
                    ),
                  if (task.isCompleted)
                    const _Pill(
                      icon: Icons.check_circle_rounded,
                      text: 'Completed',
                      color: _kAmber,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _SheetCard(
                title: 'Description',
                icon: Icons.notes_rounded,
                child: Text(
                  task.description.isEmpty
                      ? 'No description provided.'
                      : task.description,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: task.description.isEmpty ? _kMuted : _kInk,
                  ),
                ),
              ),
              Column(
                children: [
                  _SheetCard(
                    title: 'Details',
                    icon: Icons.info_outline_rounded,
                    child: Column(
                      children: [
                        _InfoRow(
                          icon: Icons.person_outline_rounded,
                          label: 'Assigned by',
                          value: task.assignedBy.isEmpty ? '-' : task.assignedBy,
                        ),
                        _InfoRow(
                          icon: Icons.groups_rounded,
                          label: 'Team',
                          value: task.teamName.isEmpty ? '-' : task.teamName,
                        ),
                        _InfoRow(
                          icon: Icons.play_circle_outline_rounded,
                          label: 'Start date',
                          value: _fmtDate(task.startDate),
                        ),
                        _InfoRow(
                          icon: Icons.event_rounded,
                          label: 'Due date',
                          value: _fmtDate(task.dueDate),
                          last: task.totalHoursWorked <= 0,
                        ),
                        if (task.totalHoursWorked > 0)
                          _InfoRow(
                            icon: Icons.timer_outlined,
                            label: 'Total time',
                            value: formatHours(task.totalHoursWorked),
                            last: true,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _showCompleteDialog(context),
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      label: const Text('Mark as Complete'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  // Snapshot Dialog
  Future<void> _showCompleteDialog(BuildContext context) async {
    final ImagePicker picker = ImagePicker();
    final TextEditingController summaryController = TextEditingController();

    XFile? snapshot;
    bool isSubmitting = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> attachSnapshot() async {
              try {
                final XFile? photo = await picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 70,
                );

                if (photo != null) {
                  setState(() => snapshot = photo);
                }
              } catch (e) {
                if (!context.mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Unable to capture photo: $e'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }

            Future<void> submit() async {
              final summary = summaryController.text.trim();

              if (summary.isEmpty || snapshot == null || isSubmitting) {
                return;
              }

              setState(() => isSubmitting = true);

              try {
                // TODO: Call your API here.
                // await _taskRepo.markComplete(
                //   task.id,
                //   summary: summary,
                //   snapshot: File(snapshot!.path),
                // );

                await Future.delayed(const Duration(seconds: 1));

                if (!context.mounted) return;

                Navigator.of(dialogContext).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Task marked as complete'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Color(0xFF16845B),
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;

                setState(() => isSubmitting = false);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed: $e'),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: const Color(0xFFB42318),
                  ),
                );
              }
            }

            final bool canComplete =
                summaryController.text.trim().isNotEmpty &&
                snapshot != null &&
                !isSubmitting;

            const Color primary = Color.fromARGB(255, 12, 86, 147);
            const Color textPrimary = Color(0xFF172033);
            const Color textSecondary = Color(0xFF667085);
            const Color surface = Color(0xFFF8FAFC);
            const Color borderColor = Color(0xFFE4E7EC);

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 440,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 32,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // HEADER
                        Container(
                          padding: const EdgeInsets.fromLTRB(
                            24,
                            24,
                            18,
                            22,
                          ),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color.fromARGB(255, 12, 86, 147),
                                Color.fromARGB(255, 6, 94, 167),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [

                              // Header icon
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(
                                    alpha: 0.16,
                                  ),
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(
                                    color: Colors.white.withValues(
                                      alpha: 0.2,
                                    ),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.task_alt_rounded,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),

                              const SizedBox(width: 14),

                              // Header title
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Complete Task',
                                      style: TextStyle(
                                        fontSize: 21,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        letterSpacing: -0.4,
                                      ),
                                    ),
                                    SizedBox(height: 5),
                                    Text(
                                      'Document your work before finishing.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        height: 1.4,
                                        color: Color(0xFFE0EAFF),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Close button
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: isSubmitting
                                      ? null
                                      : () {
                                          Navigator.of(
                                            dialogContext,
                                          ).pop();
                                        },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 23,
                                      color: isSubmitting
                                          ? Colors.white.withValues(
                                              alpha: 0.4,
                                            )
                                          : Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // FORM CONTENT
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            22,
                            24,
                            22,
                            22,
                          ),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.stretch,
                            children: [
                              // WORK SUMMARY
                              Row(
                                children: [
                                  const Icon(
                                    Icons.notes_rounded,
                                    size: 19,
                                    color: primary,
                                  ),
                                  const SizedBox(width: 8),

                                  const Expanded(
                                    child: Text(
                                      'Work Summary',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: textPrimary,
                                      ),
                                    ),
                                  ),

                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF4E5),
                                      borderRadius:
                                          BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'Required',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFFB54708),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 10),

                              TextField(
                                controller: summaryController,
                                minLines: 3,
                                maxLines: 5,
                                maxLength: 500,
                                enabled: !isSubmitting,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                textInputAction:
                                    TextInputAction.newline,
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  hintText:
                                      'Describe the work completed, results, '
                                      'or any important observations...',
                                  hintStyle: const TextStyle(
                                    fontSize: 13,
                                    height: 1.5,
                                    color: Color(0xFF98A2B3),
                                  ),
                                  filled: true,
                                  fillColor: surface,
                                  counterStyle: const TextStyle(
                                    fontSize: 11,
                                    color: textSecondary,
                                  ),
                                  contentPadding:
                                      const EdgeInsets.all(14),

                                  enabledBorder:
                                      OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(14),
                                    borderSide:
                                        const BorderSide(
                                      color: borderColor,
                                    ),
                                  ),

                                  focusedBorder:
                                      OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(14),
                                    borderSide:
                                        const BorderSide(
                                      color: primary,
                                      width: 1.5,
                                    ),
                                  ),

                                  disabledBorder:
                                      OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(14),
                                    borderSide:
                                        const BorderSide(
                                      color: borderColor,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 22),
                              // COMPLETION EVIDENCE
                              Row(
                                children: [
                                  const Icon(
                                    Icons.photo_camera_outlined,
                                    size: 19,
                                    color: primary,
                                  ),

                                  const SizedBox(width: 8),

                                  const Expanded(
                                    child: Text(
                                      'Completion Evidence',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: textPrimary,
                                      ),
                                    ),
                                  ),

                                  Container(
                                    padding:
                                        const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF4E5),
                                      borderRadius:
                                          BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'Required',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFFB54708),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 10),
                              // PHOTO PREVIEW
                              if (snapshot != null) ...[
                                ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(14),
                                  child: Stack(
                                    children: [
                                      Image.file(
                                        File(snapshot!.path),
                                        height: 190,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      ),

                                      Positioned(
                                        top: 10,
                                        right: 10,
                                        child: Container(
                                          padding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 7,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                const Color(0xFF16845B),
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: const Row(
                                            mainAxisSize:
                                                MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.check_circle_rounded,
                                                color: Colors.white,
                                                size: 14,
                                              ),
                                              SizedBox(width: 5),
                                              Text(
                                                'Photo attached',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 11,
                                                  fontWeight:
                                                      FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 10),
                              ] else
                                Container(
                                  padding:
                                      const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 22,
                                  ),
                                  decoration: BoxDecoration(
                                    color: surface,
                                    borderRadius:
                                        BorderRadius.circular(14),
                                    border: Border.all(
                                      color: borderColor,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 54,
                                        height: 54,
                                        decoration: BoxDecoration(
                                          color:
                                              const Color(0xFFE8F0FF),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        child: const Icon(
                                          Icons.add_a_photo_outlined,
                                          size: 26,
                                          color: primary,
                                        ),
                                      ),

                                      const SizedBox(height: 12),

                                      const Text(
                                        'Add a completion photo',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: textPrimary,
                                        ),
                                      ),

                                      const SizedBox(height: 5),

                                      const Text(
                                        'Capture the completed work using your camera.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 12,
                                          height: 1.5,
                                          color: textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              // CAPTURE PHOTO
                              const SizedBox(height: 14),
                              OutlinedButton.icon(
                                onPressed:
                                    isSubmitting
                                        ? null
                                        : attachSnapshot,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: primary,
                                  minimumSize:
                                      const Size.fromHeight(46),
                                  side: const BorderSide(
                                    color: Color(0xFFB8CCFF),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12),
                                  ),
                                ),
                                icon: Icon(
                                  snapshot == null
                                      ? Icons.camera_alt_rounded
                                      : Icons.refresh_rounded,
                                  size: 19,
                                ),
                                label: Text(
                                  snapshot == null
                                      ? 'Capture Photo'
                                      : 'Retake Photo',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),

                              // COMPLETE BUTTON
                              SizedBox(
                                height: 50,
                                child: FilledButton(
                                  onPressed:
                                      canComplete ? submit : null,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: primary,
                                    disabledBackgroundColor:
                                        const Color(0xFFE4E7EC),
                                    foregroundColor: Colors.white,
                                    disabledForegroundColor:
                                        const Color(0xFF98A2B3),
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(13),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      if (isSubmitting) ...[
                                        const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child:
                                              CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                      ] else ...[
                                        const Icon(
                                          Icons
                                              .check_circle_outline_rounded,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                      ],

                                      Text(
                                        isSubmitting
                                            ? 'Submitting...'
                                            : 'Mark Task as Complete',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    summaryController.dispose();
  }

  // Start / stop logic
  // ---------------------------------------------------------------------------
  Future<bool> _showLeaveConfirmDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => _DialogShell(
            icon: Icons.beach_access_rounded,
            title: 'Leave Marked',
            message: 'Your leave is marked today. '
                'This task will be counted as extra work hours.\n'
                'Start anyway?',
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 22, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Yes'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _handleStartTask(AssignedTaskModel task) async {
    // If task is NOT client-side -> start directly
    if (task.taskPreference != 'client') {
      await _startTask(task);
      return;
    }

    setState(() => _busyTaskId = task.taskId);
    try {
      // 1. Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          _snack('Location permission required', isError: true);
          return;
        }
      }

      // 2. Get agent current location
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 3. Send location to backend for validation
      final isAllowed = await ApiService.validateTaskLocation(
        taskId: task.taskId,
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (!isAllowed) {
        _snack('You must be near the client location to start this task',
            isError: true);
        return;
      }
    } catch (e) {
      _snack('Unable to verify location', isError: true);
      return;
    } finally {
      if (mounted) setState(() => _busyTaskId = null);
    }

    // 4. Allowed -> Start task
    await _startTask(task);
  }

  Future<void> _startTask(AssignedTaskModel task) async {
    final employeeId = ApiService.empGuid;
    final companyCode = ApiService.currentEmployee?.companyCode;
    if (employeeId == null || companyCode == null) return;

    setState(() => _busyTaskId = task.taskId);
    try {
      // Check Leave
      final isLeave = await ApiService.isOnLeave(employeeId, companyCode);

      if (isLeave) {
        final proceed = await _showLeaveConfirmDialog();
        if (!proceed) return;
      }
      print('Task Data: ${task.taskId}');
      final result = await ApiService.startTask(
        employeeId: employeeId,
        taskId: task.taskId,
      );

      if (result['success'] == true) {
        final taskData = result['task'];

        // Check leave status
        final bool onLeave =
            await ApiService.isOnLeave(employeeId, companyCode);

        _snack('Task started!', color: _kGreen);

        final bool isExtra = taskData?['isExtraHours'] == true;
        if (!onLeave && isExtra && mounted) {
          showDialog(
            context: context,
            builder: (context) => _DialogShell(
              icon: Icons.warning_amber_rounded,
              title: 'Extra Hours Warning',
              message: 'This task will be considered as extra work hours '
                  'because you are starting it after check-out.',
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        await _loadTasks();
      } else {
        _snack('Failed to start task', isError: true);
      }
    } finally {
      if (mounted) setState(() => _busyTaskId = null);
    }
  }

  Future<void> _stopTask(AssignedTaskModel task) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => StopTaskDialog(),
    );

    if (result == null) return;

    final employeeId = ApiService.empGuid!;
    if (employeeId == null) return;

    setState(() => _busyTaskId = task.taskId);
    try {
      final response = await ApiService.stopTask(
        employeeId: employeeId,
        taskId: task.taskId,
        notes: result,
      );

      if (response['success'] == true) {
        final todayHours = (response['todayHours'] as num?)?.toDouble() ?? 0;
        _snack('Task stopped! Today: ${todayHours.toStringAsFixed(1)}h',
            color: _kAccent);
        await _loadTasks();
      } else {
        _snack(response['error']?.toString() ?? 'Failed to stop task',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _busyTaskId = null);
    }
  }
}

// =============================================================================
// Shared widgets
// =============================================================================

class _DialogShell extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final List<Widget> actions;

  const _DialogShell({
    required this.icon,
    required this.title,
    required this.message,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      title: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _kAccent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _kInk,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        message,
        style: const TextStyle(fontSize: 14, color: _kMuted, height: 1.4),
      ),
      actions: actions,
    );
  }
}

class _SheetCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SheetCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
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
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _kAccent.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: _kAccent),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: _kInk,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool last;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _kMuted),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontSize: 13.5, color: _kMuted)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: _kInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  final String name;
  final double size;
  final double radius;

  const _InitialsAvatar({
    required this.name,
    this.size = 44,
    this.radius = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: _bannerGradient,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        _initials(name),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.34,
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final double iconSize;
  final String text;
  final Color color;

  const _Pill({
    required this.icon,
    required this.text,
    required this.color,
    this.iconSize = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            maxLines: 1,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _kAccent.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 38, color: _kAccent),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _kInk,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: _kMuted),
            ),
          ],
        ),
      ),
    );
  }
}