import 'package:attendance_app/services/apiservice.dart';
import 'package:attendance_app/widgets/SizeConfig.dart';
import 'package:flutter/material.dart';

// Screen 3 from the spec: approve/reject task requests. Accessible to
// whoever is resolved as the approver via the ReportingEmployee hierarchy
// (e.g. Raffay for Usman's requests, Usman for Yasir/Misbah/Saad's).

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

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _initials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

/// "05 Mar 2026" from an ISO string; falls back to the raw value / "-".
String _fmtAny(dynamic v) {
  if (v == null || v.toString().isEmpty) return '-';
  try {
    final d = DateTime.parse(v.toString());
    return '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';
  } catch (_) {
    return v.toString();
  }
}

Color _priorityColor(String? p) {
  switch ((p ?? '').toLowerCase()) {
    case 'high':
      return _kRed;
    case 'low':
      return _kGreen;
    default:
      return _kAmber;
  }
}

AppBar _appBar(BuildContext context, String title) => AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color.fromARGB(255, 12, 86, 147),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
      ),
    );

void _snack(BuildContext context, String message, {bool isError = false}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? _kRed : _kInk,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ),
  );
}

// =============================================================================
// Screen 1: pending approvals list
// =============================================================================
class TaskApprovalScreen extends StatefulWidget {
  final String approverEmployeeId;
  const TaskApprovalScreen({super.key, required this.approverEmployeeId});

  @override
  State<TaskApprovalScreen> createState() => _TaskApprovalScreenState();
}

class _TaskApprovalScreenState extends State<TaskApprovalScreen> {
  List<dynamic> _approvals = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final approvals =
          await ApiService.getPendingApprovals(widget.approverEmployeeId);
      if (!mounted) return;
      setState(() {
        _approvals = approvals;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack(context, 'Could not load approvals: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: _appBar(context, 'Task Approvals'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _approvals.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        _EmptyState(
                          icon: Icons.task_alt_rounded,
                          title: 'All caught up',
                          message: 'No pending approvals.',
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                      itemCount: _approvals.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) return _buildBanner();
                        return _buildApprovalCard(_approvals[index - 1]);
                      },
                    ),
            ),
    );
  }

  Widget _buildBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
                  '${_approvals.length} pending',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Review task requests from your team and approve or reject them.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.88),
                    fontSize: 13.5,
                    height: 1.35,
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
            child: const Icon(Icons.fact_check_rounded,
                color: Colors.white, size: 30),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalCard(dynamic a) {
    final requestedBy = (a['requestedByName'] ?? '').toString();
    final project = (a['projectName'] ?? '').toString();
    final team = (a['teamName'] ?? '').toString();

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
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ApprovalDetailScreen(
                  taskApprovalId: a['taskApprovalId'],
                  approverEmployeeId: widget.approverEmployeeId,
                ),
              ),
            );
            _load();
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        (a['taskTitle'] ?? '').toString(),
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
                    const _Pill(
                      icon: Icons.hourglass_top_rounded,
                      text: 'Pending',
                      color: _kAmber,
                    ),
                  ],
                ),
                if (project.isNotEmpty || team.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (project.isNotEmpty)
                        _Pill(
                          icon: Icons.folder_open_rounded,
                          text: project,
                          color: _kAccent,
                        ),
                      if (team.isNotEmpty)
                        _Pill(
                          icon: Icons.groups_rounded,
                          text: team,
                          color: _kGradient,
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                const Divider(height: 1, color: _kLine),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _InitialsAvatar(
                      name: requestedBy,
                      size: SizeConfig.f(30),
                      radius: 15,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Requested by',
                            style: TextStyle(fontSize: 11.5, color: _kMuted),
                          ),
                          Text(
                            requestedBy.isEmpty ? '-' : requestedBy,
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
                    const Icon(Icons.chevron_right_rounded, color: _kMuted),
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

// =============================================================================
// Screen 2: approval detail (approve / reject)
// =============================================================================
class ApprovalDetailScreen extends StatefulWidget {
  final String taskApprovalId;
  final String approverEmployeeId;

  const ApprovalDetailScreen({
    super.key,
    required this.taskApprovalId,
    required this.approverEmployeeId,
  });

  @override
  State<ApprovalDetailScreen> createState() => _ApprovalDetailScreenState();
}

class _ApprovalDetailScreenState extends State<ApprovalDetailScreen> {
  Map<String, dynamic> _detail = {};
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final detail = await ApiService.getApprovalDetail(widget.taskApprovalId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack(context, 'Could not load details: $e', isError: true);
    }
  }

  Future<void> _approve() async {
    setState(() => _submitting = true);
    final result = await ApiService.approveTask(
      taskApprovalId: widget.taskApprovalId,
      approverId: widget.approverEmployeeId,
    );
    if (mounted) setState(() => _submitting = false);
    if (result['success'] == true) {
      if (mounted) Navigator.pop(context);
    } else if (mounted) {
      _snack(context, 'Could not approve: ${result['error']}', isError: true);
    }
  }

  Future<void> _openRejectDialog() async {
    final reasonController = TextEditingController();
    bool busy = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => _DialogShell(
          icon: Icons.cancel_outlined,
          title: 'Reject Task',
          subtitle: 'Tell the requester why this task was rejected.',
          content: TextField(
            controller: reasonController,
            maxLines: 4,
            minLines: 3,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: 'Rejection reason (required)',
              alignLabelWithHint: true,
              filled: true,
              fillColor: _kBg,
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _kRed,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: busy
                  ? null
                  : () async {
                      if (reasonController.text.trim().isEmpty) {
                        _snack(context, 'A rejection reason is required',
                            isError: true);
                        return;
                      }
                      setDialogState(() => busy = true);
                      final result = await ApiService.rejectTask(
                        taskApprovalId: widget.taskApprovalId,
                        approverId: widget.approverEmployeeId,
                        rejectionReason: reasonController.text.trim(),
                      );
                      if (result['success'] == true) {
                        if (context.mounted) Navigator.pop(context); // dialog
                        if (mounted) Navigator.pop(this.context); // detail
                      } else if (context.mounted) {
                        setDialogState(() => busy = false);
                        _snack(context, 'Could not reject: ${result['error']}',
                            isError: true);
                      }
                    },
              child: const Text('Reject'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: _kBg,
        appBar: _appBar(context, 'Approval Details'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final assignees = (_detail['assignedEmployeeNames'] as List?) ?? [];
    final priority = (_detail['priority'] ?? '').toString();
    final description = (_detail['description'] ?? '').toString();
    final requestedBy = (_detail['requestedByName'] ?? '').toString();

    return Scaffold(
      backgroundColor: _kBg,
      appBar: _appBar(context, 'Approval Details'),
      bottomNavigationBar: _buildActionBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // ------------------------------------------------------- header
          Container(
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
                Text(
                  (_detail['taskTitle'] ?? '-').toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  (_detail['projectName'] ?? '-').toString(),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.88),
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    const _Pill(
                      icon: Icons.hourglass_top_rounded,
                      text: 'Awaiting approval',
                      color: _kAmber,
                      solid: true,
                    ),
                    if (priority.isNotEmpty)
                      _Pill(
                        icon: Icons.flag_rounded,
                        text: priority,
                        color: _priorityColor(priority),
                        solid: true,
                      ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ------------------------------------------------------- details
          _SectionCard(
            title: 'Task Details',
            icon: Icons.info_outline_rounded,
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.category_outlined,
                  label: 'Task Type',
                  value: '${_detail['taskTypeName'] ?? '-'}',
                ),
                _InfoRow(
                  icon: Icons.folder_open_rounded,
                  label: 'Project',
                  value: '${_detail['projectName'] ?? '-'}',
                ),
                _InfoRow(
                  icon: Icons.groups_rounded,
                  label: 'Assigned Team',
                  value: '${_detail['teamName'] ?? '-'}',
                ),
                _InfoRow(
                  icon: Icons.play_circle_outline_rounded,
                  label: 'Start Date',
                  value: _fmtAny(_detail['startDate']),
                ),
                _InfoRow(
                  icon: Icons.event_rounded,
                  label: 'Due Date',
                  value: _fmtAny(_detail['dueDate']),
                  last: true,
                ),
              ],
            ),
          ),

          _SectionCard(
            title: 'Description',
            icon: Icons.notes_rounded,
            child: Text(
              description.isEmpty ? '-' : description,
              style: const TextStyle(
                fontSize: 14,
                color: _kInk,
                height: 1.45,
              ),
            ),
          ),

          _SectionCard(
            title: 'Assigned Employee(s)',
            icon: Icons.people_alt_rounded,
            count: assignees.length,
            child: assignees.isEmpty
                ? const Text('-',
                    style: TextStyle(fontSize: 14, color: _kMuted))
                : Column(
                    children: assignees.map((n) {
                      final name = '$n';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            _InitialsAvatar(
                              name: name,
                              size: SizeConfig.f(34),
                              radius: 17,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: _kInk,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),

          _SectionCard(
            title: 'Requested By',
            icon: Icons.person_outline_rounded,
            child: Row(
              children: [
                _InitialsAvatar(
                  name: requestedBy,
                  size: SizeConfig.f(34),
                  radius: 17,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    requestedBy.isEmpty ? '-' : requestedBy,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _kInk,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F2430).withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.close_rounded),
                label: const Text('Reject'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kRed,
                  side: const BorderSide(color: _kRed),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _submitting ? null : _openRejectDialog,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded),
                label: const Text('Approve'),
                style: FilledButton.styleFrom(
                  backgroundColor: _kGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _submitting ? null : _approve,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Shared widgets
// =============================================================================

class _DialogShell extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget content;
  final List<Widget> actions;

  const _DialogShell({
    required this.icon,
    required this.title,
    required this.content,
    required this.actions,
    this.subtitle,
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
        crossAxisAlignment: CrossAxisAlignment.start,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _kInk,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w400,
                      color: _kMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(width: 380, child: content),
      actions: actions,
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final int? count;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
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
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: _kInk,
                  ),
                ),
              ),
              if (count != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: _kAccent.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _kAccent,
                    ),
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
  final String text;
  final Color color;

  /// White background (for use on the gradient header).
  final bool solid;

  const _Pill({
    required this.icon,
    required this.text,
    required this.color,
    this.solid = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: solid ? Colors.white : color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
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