import 'package:attendance_app/services/apiservice.dart';
import 'package:flutter/material.dart';

// Screen 2 from the spec: "My Projects" -> project's task list -> Create
// Task, with the Approval Required branch. Uses ApiService directly.
class TeamHeadTaskScreen extends StatefulWidget {
  final String teamHeadEmployeeId;
  final String teamId; // the Team Head's own team

  const TeamHeadTaskScreen({
    super.key,
    required this.teamHeadEmployeeId,
    required this.teamId,
  });

  @override
  State<TeamHeadTaskScreen> createState() => _TeamHeadTaskScreenState();
}

class _TeamHeadTaskScreenState extends State<TeamHeadTaskScreen> {
  List<dynamic> _projects = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() => _loading = true);
    final projects = await ApiService.getMyProjects(widget.teamHeadEmployeeId);
    setState(() {
      _projects = projects;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Projects')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _projects.isEmpty
              ? const Center(child: Text('No projects assigned to your team yet.'))
              : RefreshIndicator(
                  onRefresh: _loadProjects,
                  child: ListView.builder(
                    itemCount: _projects.length,
                    itemBuilder: (context, index) {
                      final p = _projects[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ListTile(
                          title: Text(p['projectName'] ?? ''),
                          subtitle: Text(
                              '${p['status'] ?? ''}  •  ${_fmtDate(p['startDate'])} → ${_fmtDate(p['endDate'])}'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProjectTaskListScreen(
                                project: p,
                                teamHeadEmployeeId: widget.teamHeadEmployeeId,
                                teamId: widget.teamId,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  static String _fmtDate(dynamic iso) {
    if (iso == null) return '-';
    try {
      final d = DateTime.parse(iso);
      return '${d.day}/${d.month}';
    } catch (_) {
      return '-';
    }
  }
}

class ProjectTaskListScreen extends StatefulWidget {
  final dynamic project;
  final String teamHeadEmployeeId;
  final String teamId;

  const ProjectTaskListScreen({
    super.key,
    required this.project,
    required this.teamHeadEmployeeId,
    required this.teamId,
  });

  @override
  State<ProjectTaskListScreen> createState() => _ProjectTaskListScreenState();
}

class _ProjectTaskListScreenState extends State<ProjectTaskListScreen> {
  List<dynamic> _tasks = [];
  List<dynamic> _taskTypes = [];
  List<dynamic> _teamMembers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final results = await Future.wait([
      ApiService.getProjectTasks(widget.project['projectId'], widget.teamId),
      ApiService.getTaskTypes(),
      ApiService.getTeamMembersForTeam(widget.teamId),
    ]);
    setState(() {
      _tasks = results[0];
      _taskTypes = results[1];
      _teamMembers = results[2];
      _loading = false;
    });
  }

  Future<void> _openCreateTaskDialog() async {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final remarksController = TextEditingController();
    dynamic selectedType;
    String priority = 'Medium';
    DateTime? startDate;
    DateTime? dueDate;
    final selectedEmployeeIds = <String>{};

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Create Task — ${widget.project['projectName']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Project is implicit — already selected by being on this screen.
                DropdownButtonFormField<dynamic>(
                  decoration: const InputDecoration(labelText: 'Task Type'),
                  items: _taskTypes
                      .map((t) => DropdownMenuItem(value: t, child: Text(t['taskTypeName'] ?? '')))
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedType = v),
                ),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Task Title'),
                ),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
                ),
                DropdownButtonFormField<String>(
                  value: priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: ['Low', 'Medium', 'High']
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => priority = v ?? 'Medium'),
                ),
                ListTile(
                  title: Text(startDate == null ? 'Start Date' : startDate.toString().split(' ')[0]),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setDialogState(() => startDate = picked);
                  },
                ),
                ListTile(
                  title: Text(dueDate == null ? 'Due Date' : dueDate.toString().split(' ')[0]),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setDialogState(() => dueDate = picked);
                  },
                ),
                const Align(alignment: Alignment.centerLeft, child: Text('Employee(s) — your team only')),
                ..._teamMembers.map((m) => CheckboxListTile(
                      dense: true,
                      title: Text(m['employeeName'] ?? ''),
                      value: selectedEmployeeIds.contains(m['employeeId']),
                      onChanged: (checked) => setDialogState(() {
                        if (checked == true) {
                          selectedEmployeeIds.add(m['employeeId']);
                        } else {
                          selectedEmployeeIds.remove(m['employeeId']);
                        }
                      }),
                    )),
                TextField(
                  controller: remarksController,
                  decoration: const InputDecoration(labelText: 'Remarks'),
                  maxLines: 2,
                ),
                if (selectedType != null && selectedType['approvalRequired'] == true)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'This task type requires approval — it will be sent to your '
                      'reporting head and won\'t be assigned until approved.',
                      style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (selectedType == null ||
                    titleController.text.trim().isEmpty ||
                    startDate == null ||
                    dueDate == null ||
                    selectedEmployeeIds.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Task Type, Title, dates, and at least one employee are required')));
                  return;
                }
                final result = await ApiService.createTeamHeadTask(
                  projectId: widget.project['projectId'],
                  taskTypeId: selectedType['taskTypeId'],
                  taskTitle: titleController.text.trim(),
                  description: descController.text.trim(),
                  priority: priority,
                  startDate: startDate!,
                  dueDate: dueDate!,
                  employeeIds: selectedEmployeeIds.toList(),
                  remarks: remarksController.text.trim(),
                  createdBy: widget.teamHeadEmployeeId,
                  createdByTeamId: widget.teamId,
                );
                if (result['success'] == true) {
                  if (context.mounted) Navigator.pop(context);
                  final requiresApproval = selectedType['approvalRequired'] == true;
                  _loadAll();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(requiresApproval
                          ? 'Task sent for approval — pending.'
                          : 'Task created and assigned.'),
                    ));
                  }
                } else {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Could not create task: ${result['error']}')));
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.project['projectName'] ?? 'Project')),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateTaskDialog,
        child: const Icon(Icons.add_task),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tasks.isEmpty
              ? const Center(child: Text('No tasks yet — tap + to create one.'))
              : RefreshIndicator(
                  onRefresh: _loadAll,
                  child: ListView.builder(
                    itemCount: _tasks.length,
                    itemBuilder: (context, index) {
                      final t = _tasks[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ListTile(
                          title: Text(t['taskTitle'] ?? ''),
                          subtitle: Text(
                              '${t['taskTypeName'] ?? ''}  •  ${t['assignedToNames'] ?? ''}\n${t['priority'] ?? ''} • ${t['status'] ?? ''}'),
                          isThreeLine: true,
                          trailing: _statusChip(t['status']),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: t['taskId'])),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _statusChip(String? status) {
    Color color;
    switch (status) {
      case 'PendingApproval':
        color = Colors.orange;
        break;
      case 'Rejected':
        color = Colors.red;
        break;
      case 'Completed':
        color = Colors.green;
        break;
      default:
        color = Colors.blue;
    }
    return Chip(label: Text(status ?? '', style: const TextStyle(fontSize: 11)), backgroundColor: color.withOpacity(0.15));
  }
}

class TaskDetailScreen extends StatefulWidget {
  final String taskId;
  const TaskDetailScreen({super.key, required this.taskId});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  Map<String, dynamic> _task = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final task = await ApiService.getTaskDetail(widget.taskId);
    setState(() {
      _task = task;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final assignees = (_task['assignedEmployees'] as List?) ?? [];
    final summaries = (_task['dailySummaries'] as List?) ?? [];
    final snapshots = (_task['completionSnapshotUrls'] as List?) ?? [];
    final history = (_task['history'] as List?) ?? [];
    final siteValidation = _task['siteValidation'];
    final completion = _task['completion'];

    return Scaffold(
      appBar: AppBar(title: Text(_task['taskTitle'] ?? 'Task')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(_task['taskDescription'] ?? '', style: Theme.of(context).textTheme.bodyMedium),
          const Divider(height: 24),
          _row('Type', _task['taskTypeName']),
          _row('Priority', _task['priority']),
          _row('Status', _task['status']),
          _row('Approval', _task['approvalStatus']),
          _row('Due', _task['dueDate']),
          _row('Total Hours', '${_task['totalTaskHours'] ?? 0}'),
          const Divider(height: 24),
          Text('Assigned Employees', style: Theme.of(context).textTheme.titleMedium),
          ...assignees.map((a) => ListTile(
                dense: true,
                title: Text(a['employeeName'] ?? ''),
                trailing: Text('${a['assignmentStatus']} • ${a['totalHours']}h'),
              )),
          const Divider(height: 24),
          Text('Daily Work Summaries', style: Theme.of(context).textTheme.titleMedium),
          if (summaries.isEmpty) const Text('None logged yet.'),
          ...summaries.map((s) => ListTile(
                dense: true,
                title: Text(s['workDate'] ?? ''),
                subtitle: Text(s['dailyWorkSummary'] ?? ''),
                trailing: Text('${s['dailyTotalHours']}h'),
              )),
          const Divider(height: 24),
          Text('Completion', style: Theme.of(context).textTheme.titleMedium),
          if (completion == null) const Text('Not completed yet.'),
          if (completion != null) Text(completion['finalSummary'] ?? ''),
          if (snapshots.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text('Completion Snapshot(s):'),
            ...snapshots.map((s) => Text('• $s')),
          ],
          if (siteValidation != null) ...[
            const Divider(height: 24),
            Text('Site Validation', style: Theme.of(context).textTheme.titleMedium),
            Text(
                '${siteValidation['validationStatus']} — ${siteValidation['calculatedDistance']}m (allowed ${siteValidation['allowedRadius']}m)'),
          ],
          const Divider(height: 24),
          Text('History', style: Theme.of(context).textTheme.titleMedium),
          ...history.map((h) => ListTile(dense: true, title: Text(h['event'] ?? ''), subtitle: Text(h['timestamp'] ?? ''))),
        ],
      ),
    );
  }

  Widget _row(String label, dynamic value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text('${value ?? '-'}')),
        ]),
      );
}
