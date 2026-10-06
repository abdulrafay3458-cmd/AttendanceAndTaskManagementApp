import 'package:attendance_app/services/apiservice.dart';
import 'package:flutter/material.dart';

// Screen 3 from the spec: approve/reject task requests. Accessible to
// whoever is resolved as the approver via the ReportingEmployee hierarchy
// (e.g. Raffay for Usman's requests, Usman for Yasir/Misbah/Saad's).
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
    final approvals = await ApiService.getPendingApprovals(widget.approverEmployeeId);
    setState(() {
      _approvals = approvals;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Task Approvals')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _approvals.isEmpty
              ? const Center(child: Text('No pending approvals.'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    itemCount: _approvals.length,
                    itemBuilder: (context, index) {
                      final a = _approvals[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ListTile(
                          title: Text(a['taskTitle'] ?? ''),
                          subtitle: Text(
                              '${a['projectName'] ?? ''}  •  ${a['teamName'] ?? ''}\nRequested by ${a['requestedByName'] ?? ''}'),
                          isThreeLine: true,
                          trailing: const Icon(Icons.chevron_right),
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
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

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
    final detail = await ApiService.getApprovalDetail(widget.taskApprovalId);
    setState(() {
      _detail = detail;
      _loading = false;
    });
  }

  Future<void> _approve() async {
    setState(() => _submitting = true);
    final result = await ApiService.approveTask(
      taskApprovalId: widget.taskApprovalId,
      approverId: widget.approverEmployeeId,
    );
    setState(() => _submitting = false);
    if (result['success'] == true) {
      if (mounted) Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not approve: ${result['error']}')));
    }
  }

  Future<void> _openRejectDialog() async {
    final reasonController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Task'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(labelText: 'Rejection reason (required)'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('A rejection reason is required')));
                return;
              }
              final result = await ApiService.rejectTask(
                taskApprovalId: widget.taskApprovalId,
                approverId: widget.approverEmployeeId,
                rejectionReason: reasonController.text.trim(),
              );
              if (result['success'] == true) {
                if (context.mounted) Navigator.pop(context); // dialog
                if (mounted) Navigator.pop(context); // detail screen
              } else if (context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('Could not reject: ${result['error']}')));
              }
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final assignees = (_detail['assignedEmployeeNames'] as List?) ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('Approval Details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _row('Project', _detail['projectName']),
          _row('Task', _detail['taskTitle']),
          _row('Task Type', _detail['taskTypeName']),
          _row('Description', _detail['description']),
          _row('Priority', _detail['priority']),
          _row('Start Date', _detail['startDate']),
          _row('Due Date', _detail['dueDate']),
          _row('Assigned Team', _detail['teamName']),
          _row('Assigned Employee(s)', assignees.join(', ')),
          _row('Requested By', _detail['requestedByName']),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: _submitting ? null : _approve,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.close),
                  label: const Text('Reject'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: _submitting ? null : _openRejectDialog,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String label, dynamic value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            Text('${value ?? '-'}', style: const TextStyle(fontSize: 15)),
          ],
        ),
      );
}
