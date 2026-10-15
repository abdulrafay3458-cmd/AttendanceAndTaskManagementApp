import 'package:attendance_app/services/apiservice.dart';
import 'package:attendance_app/services/work_service.dart';
import 'package:flutter/material.dart';
import '../models/work_models.dart';
import 'task_work_screen.dart';

const _kBg = Color(0xFFF5F6FA);
const _kInk = Color(0xFF1F2430);
const _kMuted = Color(0xFF7A8194);
const _kLine = Color(0xFFE6E8F0);
const _kGreen = Color(0xFF22A06B);
const _kRed = Color(0xFFE5484D);
const _kAmber = Color(0xFFE59A1F);

final _baseColor = const Color.fromARGB(255, 12, 86, 147);
final _bannerGradient = LinearGradient(
  colors: [_baseColor, _baseColor.withOpacity(0.72)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

final _softShadow = [
  BoxShadow(
    color: const Color(0xFF1F2430).withOpacity(0.06),
    blurRadius: 18,
    offset: const Offset(0, 6),
  ),
];

class MyTasksScreen extends StatefulWidget {
  final WorkService service;
  final Future<void> Function()? onRemoveLeave;

  const MyTasksScreen({super.key, required this.service, this.onRemoveLeave});

  @override
  State<MyTasksScreen> createState() => _MyTasksScreenState();
}

class _MyTasksScreenState extends State<MyTasksScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  // Index 0 = Assigned, 1 = In Progress, 2 = Completed
  List<AssignmentItem>? _assigned;
  List<AssignmentItem>? _active;
  List<AssignmentItem>? _done;

  bool _loadingAssigned = false;
  bool _loadingActive = false;
  bool _loadingDone = false;

  String? _errAssigned;
  String? _errActive;
  String? _errDone;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(_onTabChanged);

    // Load ALL statuses on screen open
    _loadAssigned();
    _loadActive();
    _loadDone();
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  // ---------------------------------------------------------------- loaders
  Future<void> _loadAssigned() async {
    setState(() {
      _loadingAssigned = true;
      _errAssigned = null;
    });
    try {
      final empId = ApiService.empGuid!;
      final list = await widget.service.getMyAssignments(empId, 'Assigned');
      if (!mounted) return;
      setState(() {
        _assigned = list;
        _loadingAssigned = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errAssigned = e.toString();
        _loadingAssigned = false;
      });
    }
  }

  Future<void> _loadActive() async {
    setState(() {
      _loadingActive = true;
      _errActive = null;
    });
    try {
      final empId = ApiService.empGuid!;
      final list = await widget.service.getMyAssignments(empId, 'Inprogress');
      if (!mounted) return;
      setState(() {
        _active = list;
        _loadingActive = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errActive = e.toString();
        _loadingActive = false;
      });
    }
  }

  Future<void> _loadDone() async {
    setState(() {
      _loadingDone = true;
      _errDone = null;
    });
    try {
      final empId = ApiService.empGuid!;
      final list = await widget.service.getMyAssignments(empId, 'Completed');
      if (!mounted) return;
      setState(() {
        _done = list;
        _loadingDone = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errDone = e.toString();
        _loadingDone = false;
      });
    }
  }

  Future<void> _refreshAssigned() => _loadAssigned();
  Future<void> _refreshActive() => _loadActive();
  Future<void> _refreshDone() => _loadDone();

  Future<void> _open(AssignmentItem item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TaskWorkScreen(
          assignmentId: item.assignmentId,
          taskTitle: item.title,
          service: widget.service,
          onRemoveLeave: widget.onRemoveLeave,
        ),
      ),
    );
    if (!mounted) return;
    // Refresh all tabs — task may have moved between statuses
    await Future.wait([
      _refreshAssigned(),
      _refreshActive(),
      _refreshDone(),
    ]);
  }

  String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  // ---------------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: Text(
          'My Task',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color.fromARGB(255, 12, 86, 147),
        automaticallyImplyLeading: false,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(66),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _kBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kLine),
              ),
              child: TabBar(
                controller: _tabs,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: const Color.fromARGB(255, 12, 86, 147),
                  borderRadius: BorderRadius.circular(12),
                ),
                labelColor: Colors.white,
                unselectedLabelColor: _kMuted,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
                splashBorderRadius: BorderRadius.circular(12),
                tabs: [
                  Tab(
                    height: 38,
                    text: 'Assigned (${_assigned?.length ?? 0})',
                  ),
                  Tab(
                    height: 38,
                    text: 'In Progress (${_active?.length ?? 0})',
                  ),
                  Tab(
                    height: 38,
                    text: 'Completed (${_done?.length ?? 0})',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(controller: _tabs, children: [
        _tabBody(
          loading: _loadingAssigned,
          error: _errAssigned,
          items: _assigned,
          emptyTitle: 'No assigned tasks',
          emptySubtitle: 'New tasks assigned to you will appear here.',
          emptyIcon: Icons.assignment_outlined,
          onRetry: _refreshAssigned,
        ),
        _tabBody(
          loading: _loadingActive,
          error: _errActive,
          items: _active,
          emptyTitle: 'No tasks in progress',
          emptySubtitle: 'Tasks you start working on will show up here.',
          emptyIcon: Icons.timelapse_rounded,
          onRetry: _refreshActive,
        ),
        _tabBody(
          loading: _loadingDone,
          error: _errDone,
          items: _done,
          emptyTitle: 'No completed tasks yet',
          emptySubtitle: 'Finished tasks will be listed here.',
          emptyIcon: Icons.task_alt_rounded,
          onRetry: _refreshDone,
        ),
      ]),
    );
  }

  Widget _tabBody({
    required bool loading,
    required String? error,
    required List<AssignmentItem>? items,
    required String emptyTitle,
    required String emptySubtitle,
    required IconData emptyIcon,
    required Future<void> Function() onRetry,
  }) {
    if (loading && items == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null && items == null) {
      return _EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Could not load tasks',
        subtitle: 'Check your connection and try again.',
        actionLabel: 'Retry',
        onAction: onRetry,
      );
    }

    final list = items ?? const <AssignmentItem>[];

    return RefreshIndicator(
      onRefresh: onRetry,
      child: list.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.12),
                _EmptyState(
                  icon: emptyIcon,
                  title: emptyTitle,
                  subtitle: emptySubtitle,
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              itemCount: list.length,
              itemBuilder: (_, i) => _card(list[i]),
            ),
    );
  }

  // ---------------------------------------------------------------- card
  Color _priorityColor(String p) {
    switch (p.toLowerCase()) {
      case 'high':
      case 'urgent':
      case 'critical':
        return _kRed;
      case 'low':
        return _kGreen;
      default:
        return _kAmber;
    }
  }

  Widget _card(AssignmentItem t) {
    final overdue = t.dueDate != null &&
        !t.isCompleted &&
        t.dueDate!.isBefore(DateTime.now());
    final statusColor = t.isCompleted ? _kGreen : Colors.blue;
    final subtitle = [
      if (t.clientName.isNotEmpty) t.clientName,
      if (t.projectName.isNotEmpty) t.projectName,
    ].join('  •  ');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: _softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _open(t),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: _bannerGradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        t.isCompleted
                            ? Icons.check_rounded
                            : Icons.assignment_outlined,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            t.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _kInk,
                            ),
                          ),
                          if (subtitle.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: _kMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (t.isRunning) ...[
                      const SizedBox(width: 8),
                      const _Pill(
                        text: 'Running',
                        icon: Icons.circle,
                        iconSize: 8,
                        color: _kGreen,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _Pill(
                      text: t.status,
                      icon: t.isCompleted
                          ? Icons.check_circle_outline_rounded
                          : Icons.timelapse_rounded,
                      color: statusColor,
                    ),
                    if (t.priority.isNotEmpty)
                      _Pill(
                        text: t.priority,
                        icon: Icons.flag_outlined,
                        color: _priorityColor(t.priority),
                      ),
                    if (t.dueDate != null)
                      _Pill(
                        text: overdue
                            ? 'Overdue ${_date(t.dueDate!)}'
                            : 'Due ${_date(t.dueDate!)}',
                        icon: Icons.event_outlined,
                        color: overdue ? _kRed : _kMuted,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _HoursTile(
                        label: 'Today',
                        hours: t.todayHours,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _HoursTile(
                        label: 'Total',
                        hours: t.totalHours,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.arrow_forward_rounded,
                        size: 20,
                        color: Colors.blue[700],
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
}

// ====================================================================
// Small widgets
// ====================================================================

class _Pill extends StatelessWidget {
  final String text;
  final IconData? icon;
  final double iconSize;
  final Color color;

  const _Pill({
    required this.text,
    required this.color,
    this.icon,
    this.iconSize = 13,
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
          if (icon != null) ...[
            Icon(icon, size: iconSize, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HoursTile extends StatelessWidget {
  final String label;
  final double hours;

  const _HoursTile({required this.label, required this.hours});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kLine),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule_rounded, size: 18, color: Colors.blue[700]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: _kMuted),
                ),
                Text(
                  '${hours.toStringAsFixed(2)} h',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: _kInk,
                  ),
                ),
              ],
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
  final String subtitle;
  final String? actionLabel;
  final Future<void> Function()? onAction;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
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
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: Colors.blue[700]),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: _kInk,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: _kMuted),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(actionLabel!),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}