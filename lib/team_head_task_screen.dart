import 'package:attendance_app/services/apiservice.dart';
import 'package:attendance_app/services/client_location.dart';
import 'package:attendance_app/services/client_location_service.dart';
import 'package:flutter/material.dart';

// Screen 2 from the spec: "My Projects" -> project's task list -> Create
// Task, with the Approval Required branch. Uses ApiService directly.

// -----------------------------------------------------------------------------
// Design tokens & helpers
// -----------------------------------------------------------------------------
const Color _kBg = Color(0xFFF5F6FA);
const Color _kInk = Color(0xFF1F2430);
const Color _kMuted = Color(0xFF7A8194);
const Color _kLine = Color(0xFFE6E8F0);
const Color _kGreen = Color(0xFF22A06B);
const Color _kRed = Color(0xFFE5484D);
const Color _kAmber = Color(0xFFE59A1F);
const Color _kBlue = Color(0xFF3F6FB5);

List<BoxShadow> get _softShadow => [
      BoxShadow(
        color: const Color(0xFF1F2430).withOpacity(0.05),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
    ];

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

/// "05 Mar 2026" from a DateTime.
String _fmtDateTime(DateTime? d) {
  if (d == null) return '';
  return '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';
}

/// Formats an ISO string as "05 Mar 2026" (optionally with time). Falls back
/// to the raw value if it can't be parsed, and to "-" if empty.
String _fmtAny(dynamic v, {bool withTime = false}) {
  if (v == null || v.toString().isEmpty) return '-';
  try {
    var d = DateTime.parse(v.toString());
    if (d.isUtc) d = d.toLocal();
    final date = _fmtDateTime(d);
    if (!withTime) return date;
    return '$date, ${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    return v.toString();
  }
}

Color _statusColor(String? status) {
  switch (status) {
    case 'PendingApproval':
      return _kAmber;
    case 'Rejected':
      return _kRed;
    case 'Completed':
      return _kGreen;
    default:
      return _kBlue;
  }
}

String _statusLabel(String? status) {
  if (status == null || status.isEmpty) return '-';
  // "PendingApproval" -> "Pending Approval"
  return status.replaceAllMapped(
    RegExp(r'(?<=[a-z])(?=[A-Z])'),
    (_) => ' ',
  );
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

AppBar _appBar(String title) => AppBar(
  backgroundColor: Colors.white,
  foregroundColor: const Color.fromARGB(255, 12, 86, 147),
  title: Text(
    title,
    style: TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 17,
    ),
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
// Screen 1: My Projects
// =============================================================================
class TeamHeadTaskScreen extends StatefulWidget {
  final String teamHeadEmployeeId;
  final String teamId; // the Team Head's own team
  final List<dynamic>? allTeams;
  const TeamHeadTaskScreen({
    super.key,
    required this.teamHeadEmployeeId,
    required this.teamId,
    this.allTeams,
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
    try {
      final projects =
          await ApiService.getMyProjects(widget.teamHeadEmployeeId);
      print("Team Head Projects: ${projects}");
      if (!mounted) return;
      setState(() {
        _projects = projects;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack(context, 'Could not load projects: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: _appBar('My Projects'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProjects,
              child: _projects.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        _EmptyState(
                          icon: Icons.folder_off_outlined,
                          title: 'No projects yet',
                          message:
                              'No projects assigned to your team yet.',
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                      itemCount: _projects.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return Padding(
                            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                            child: Text(
                              '${_projects.length} project(s) assigned to your team',
                              style: const TextStyle(
                                  fontSize: 13.5, color: _kMuted),
                            ),
                          );
                        }
                        return _buildProjectCard(_projects[index - 1]);
                      },
                    ),
            ),
    );
  }

  Widget _buildProjectCard(dynamic p) {
    final name = (p['projectName'] ?? '').toString();
    final status = (p['status'] ?? '').toString();

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
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProjectTaskListScreen(
                project: p,
                teamHeadEmployeeId: widget.teamHeadEmployeeId,
                teamId: widget.teamId,
                 allTeams: widget.allTeams,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                _InitialsAvatar(name: name, size: 52, radius: 16),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _kInk,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.date_range_rounded,
                              size: 15, color: _kMuted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${_fmtAny(p['startDate'])}  →  ${_fmtAny(p['endDate'])}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13, color: _kMuted),
                            ),
                          ),
                        ],
                      ),
                      if (status.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _Pill(
                          icon: Icons.circle,
                          iconSize: 8,
                          text: _statusLabel(status),
                          color: _statusColor(status),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: _kMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Screen 2: Project task list + Create Task
// =============================================================================
class ProjectTaskListScreen extends StatefulWidget {
  final dynamic project;
  final String teamHeadEmployeeId;
  final String teamId;
    final List<dynamic>? allTeams;

  const ProjectTaskListScreen({
    super.key,
    required this.project,
    required this.teamHeadEmployeeId,
    required this.teamId,
        this.allTeams,
  });

  @override
  State<ProjectTaskListScreen> createState() => _ProjectTaskListScreenState();
}

class _ProjectTaskListScreenState extends State<ProjectTaskListScreen> {
  List<dynamic> _tasks = [];
  List<dynamic> _taskTypes = [];
  List<dynamic> _teamMembers = [];
  bool _loading = true;

  List<ClientLocation> _clientLocations = [];
  String _clientName = '';

  /// The project JSON carries the client id (backend: TeamHeadProjectResponse.ClientId).
  String get _projectClientId => (widget.project['clientId'] ?? '').toString();

  /// True for the task type named "On Site" ("Onsite", "On-Site" also match).
  static bool _isOnSiteType(dynamic type) {
    if (type == null) return false;
    final n = (type['taskTypeName'] ?? '')
        .toString()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z]'), '');
    return n == 'onsite';
  }

  Future<String> _lookupClientName(String clientId) async {
    try {
      final clients = await ApiService.getClients();
      for (final c in clients) {
        final id = (c['clientId'] ?? '').toString().toLowerCase();
        if (id == clientId) {
          return (c['name'] ?? c['clientName'] ?? '').toString();
        }
      }
    } catch (_) {}
    return '';
  }
 final Map<String, String> _memberTeamMap = {};
   List<dynamic> get _allTeams => widget.allTeams ?? [
    {'teamId': widget.teamId, 'teamName': ''}
  ];
  @override
  void initState() {
    super.initState();
    _loadAll();
  }
Widget _buildMemberTile(
  dynamic m,
  Set<String> selectedEmployeeIds,
  void Function(void Function()) setDialogState,
) {
  final id = m['employeeId'].toString();
  final name = (m['employeeName'] ?? '').toString();
  final checked = selectedEmployeeIds.contains(id);
  return CheckboxListTile(
    dense: true,
    controlAffinity: ListTileControlAffinity.trailing,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    secondary: _InitialsAvatar(name: name, size: 34, radius: 17),
    title: Text(
      name,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        color: _kInk,
      ),
    ),
    value: checked,
    onChanged: (v) => setDialogState(() {
      if (v == true) {
        selectedEmployeeIds.add(id);
      } else {
        selectedEmployeeIds.remove(id);
      }
    }),
  );
}
  // Future<void> _loadAll() async {
  //   setState(() => _loading = true);
  //   try {
  //     final results = await Future.wait([
  //       ApiService.getProjectTasks(widget.project['projectId'], widget.teamId),
  //       ApiService.getTaskTypes(),
  //       ApiService.getTeamMembersForTeam(widget.teamId),
  //     ]);
  //     if (!mounted) return;
  //     setState(() {
  //       _tasks = results[0];
  //       _taskTypes = results[1];
  //       _teamMembers = results[2];
  //       _loading = false;
  //     });
  //   } catch (e) {
  //     if (!mounted) return;
  //     setState(() => _loading = false);
  //     _snack(context, 'Could not load tasks: $e', isError: true);
  //   }
  // }
Future<void> _loadAll() async {
  setState(() => _loading = true);
  try {
    // Load tasks, task types, and members from EVERY team in parallel
    final memberFutures = _allTeams
        .map((t) => ApiService.getTeamMembersForTeam(t['teamId'].toString()))
        .toList();

    final results = await Future.wait([
      ApiService.getProjectTasks(widget.project['projectId'], widget.teamId),
      ApiService.getTaskTypes(),
      ClientLocationService.getClientLocations(),
      ...memberFutures, // 👈 spread — one future per team
    ]);
    final clientId = _projectClientId.toLowerCase();
      final allLocations = (results[2] as List).cast<ClientLocation>();
      final mine = allLocations
          .where((l) => l.isActive && l.clientId.toLowerCase() == clientId)
          .toList()
        ..sort((a, b) => a.locationName
            .toLowerCase()
            .compareTo(b.locationName.toLowerCase()));

      // client name: project data -> location data -> client list
      var name = (widget.project['clientName'] ?? '').toString();
      if (name.isEmpty && mine.isNotEmpty) name = mine.first.clientName;
      if (name.isEmpty && clientId.isNotEmpty) {
        name = await _lookupClientName(clientId);
      }

    if (!mounted) return;

    // Merge all team members, dedup by employeeId, tag team
    final merged = <String, Map<String, dynamic>>{};
    final teamMap = <String, String>{};

    for (var i = 0; i < _allTeams.length; i++) {
      final teamId = _allTeams[i]['teamId'].toString();
      final teamName = (_allTeams[i]['teamName'] ?? '').toString();
      final members = results[3 + i] as List<dynamic>;

      for (final m in members) {
        final id = m['employeeId'].toString();
        // First team wins if employee is in multiple teams
        if (!merged.containsKey(id)) {
          merged[id] = {
            ...Map<String, dynamic>.from(m),
            'teamId': teamId,
            'teamName': teamName,
          };
          teamMap[id] = teamId;
        }
      }
    }

    setState(() {
      _tasks = results[0];
      _taskTypes = results[1];
      _teamMembers = merged.values.toList();
      _clientLocations = mine;
        _clientName = name;
      _memberTeamMap
        ..clear()
        ..addAll(teamMap);
      _loading = false;
    });
  } catch (e) {
    if (!mounted) return;
    setState(() => _loading = false);
    _snack(context, 'Could not load tasks: $e', isError: true);
  }
}




  // Future<void> _openCreateTaskDialog() async {
  //   final titleController = TextEditingController();
  //   final descController = TextEditingController();
  //   final remarksController = TextEditingController();
  //   dynamic selectedType;
  //   String priority = 'Medium';
  //   DateTime? startDate;
  //   DateTime? dueDate;
  //   final selectedEmployeeIds = <String>{};

  //   Future<DateTime?> pickDate(BuildContext ctx, DateTime? initial) {
  //     return showDatePicker(
  //       context: ctx,
  //       initialDate: initial ?? DateTime.now(),
  //       firstDate: DateTime(2020),
  //       lastDate: DateTime(2100),
  //     );
  //   }

  //   await showDialog(
  //     context: context,
  //     builder: (context) => StatefulBuilder(
  //       builder: (context, setDialogState) => _DialogShell(
  //         icon: Icons.add_task_rounded,
  //         title: 'Create Task',
  //         subtitle: '${widget.project['projectName'] ?? ''}',
  //         content: Column(
  //           mainAxisSize: MainAxisSize.min,
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             // Project is implicit — already selected by being on this screen.
  //             _TaskTypeDropdown(
  //               taskTypes: _taskTypes,
  //               onSelected: (v) => setDialogState(() => selectedType = v),
  //             ),
  //             const SizedBox(height: 14),
  //             TextField(
  //               controller: titleController,
  //               textCapitalization: TextCapitalization.sentences,
  //               decoration: _fieldDecoration(
  //                 label: 'Task Title',
  //                 icon: Icons.title_rounded,
  //               ),
  //             ),
  //             const SizedBox(height: 14),
  //             TextField(
  //               controller: descController,
  //               maxLines: 3,
  //               minLines: 2,
  //               textCapitalization: TextCapitalization.sentences,
  //               decoration: _fieldDecoration(
  //                 label: 'Description',
  //                 icon: Icons.notes_rounded,
  //               ),
  //             ),
  //             const SizedBox(height: 16),
  //             const _FieldLabel('Priority'),
  //             const SizedBox(height: 8),
  //             Row(
  //               children: ['Low', 'Medium', 'High'].map((p) {
  //                 final selected = priority == p;
  //                 final color = _priorityColor(p);
  //                 return Expanded(
  //                   child: Padding(
  //                     padding: EdgeInsets.only(right: p == 'High' ? 0 : 8),
  //                     child: InkWell(
  //                       borderRadius: BorderRadius.circular(12),
  //                       onTap: () => setDialogState(() => priority = p),
  //                       child: AnimatedContainer(
  //                         duration: const Duration(milliseconds: 150),
  //                         padding: const EdgeInsets.symmetric(vertical: 11),
  //                         alignment: Alignment.center,
  //                         decoration: BoxDecoration(
  //                           color: selected
  //                               ? color.withOpacity(0.14)
  //                               : _kBg,
  //                           borderRadius: BorderRadius.circular(12),
  //                           border: Border.all(
  //                             color: selected ? color : Colors.transparent,
  //                             width: 1.4,
  //                           ),
  //                         ),
  //                         child: Text(
  //                           p,
  //                           style: TextStyle(
  //                             fontWeight: FontWeight.w600,
  //                             fontSize: 13.5,
  //                             color: selected ? color : _kMuted,
  //                           ),
  //                         ),
  //                       ),
  //                     ),
  //                   ),
  //                 );
  //               }).toList(),
  //             ),
  //             const SizedBox(height: 16),
  //             Row(
  //               children: [
  //                 Expanded(
  //                   child: _DateField(
  //                     label: 'Start Date',
  //                     value: startDate,
  //                     onTap: () async {
  //                       final picked = await pickDate(context, startDate);
  //                       if (picked != null) {
  //                         setDialogState(() => startDate = picked);
  //                       }
  //                     },
  //                   ),
  //                 ),
  //                 const SizedBox(width: 12),
  //                 Expanded(
  //                   child: _DateField(
  //                     label: 'Due Date',
  //                     value: dueDate,
  //                     onTap: () async {
  //                       final picked =
  //                           await pickDate(context, dueDate ?? startDate);
  //                       if (picked != null) {
  //                         setDialogState(() => dueDate = picked);
  //                       }
  //                     },
  //                   ),
  //                 ),
  //               ],
  //             ),
  //             const SizedBox(height: 16),
  //             Row(
  //               children: [
  //                 const Expanded(child: _FieldLabel('Employee(s) — your team only')),
  //                 if (selectedEmployeeIds.isNotEmpty)
  //                   _Pill(
  //                     icon: Icons.check_rounded,
  //                     text: '${selectedEmployeeIds.length} selected',
  //                     color: const Color.fromARGB(255, 12, 86, 147),
  //                   ),
  //               ],
  //             ),
  //             const SizedBox(height: 8),
  //             Container(
  //               constraints: const BoxConstraints(maxHeight: 200),
  //               decoration: BoxDecoration(
  //                 color: _kBg,
  //                 borderRadius: BorderRadius.circular(14),
  //               ),
  //               child: _teamMembers.isEmpty
  //                   ? const Padding(
  //                       padding: EdgeInsets.all(16),
  //                       child: Text(
  //                         'No team members found.',
  //                         style: TextStyle(color: _kMuted, fontSize: 13.5),
  //                       ),
  //                     )
  //                   : ListView.builder(
  //                       shrinkWrap: true,
  //                       padding: const EdgeInsets.symmetric(vertical: 4),
  //                       itemCount: _teamMembers.length,
  //                       itemBuilder: (context, i) {
  //                         final m = _teamMembers[i];
  //                         final id = m['employeeId'].toString();
  //                         final name = (m['employeeName'] ?? '').toString();
  //                         final checked = selectedEmployeeIds.contains(id);
  //                         return CheckboxListTile(
  //                           dense: true,
  //                           controlAffinity: ListTileControlAffinity.trailing,
  //                           shape: RoundedRectangleBorder(
  //                             borderRadius: BorderRadius.circular(10),
  //                           ),
  //                           secondary: _InitialsAvatar(
  //                               name: name, size: 34, radius: 17),
  //                           title: Text(
  //                             name,
  //                             style: const TextStyle(
  //                               fontWeight: FontWeight.w600,
  //                               color: _kInk,
  //                             ),
  //                           ),
  //                           value: checked,
  //                           onChanged: (v) => setDialogState(() {
  //                             if (v == true) {
  //                               selectedEmployeeIds.add(id);
  //                             } else {
  //                               selectedEmployeeIds.remove(id);
  //                             }
  //                           }),
  //                         );
  //                       },
  //                     ),
  //             ),
  //             const SizedBox(height: 14),
  //             TextField(
  //               controller: remarksController,
  //               maxLines: 3,
  //               minLines: 2,
  //               textCapitalization: TextCapitalization.sentences,
  //               decoration: _fieldDecoration(
  //                 label: 'Remarks',
  //                 icon: Icons.sticky_note_2_outlined,
  //               ),
  //             ),
  //             if (selectedType != null &&
  //                 selectedType['approvalRequired'] == true)
  //               Container(
  //                 margin: const EdgeInsets.only(top: 14),
  //                 padding: const EdgeInsets.all(12),
  //                 decoration: BoxDecoration(
  //                   color: _kAmber.withOpacity(0.12),
  //                   borderRadius: BorderRadius.circular(12),
  //                 ),
  //                 child: const Row(
  //                   crossAxisAlignment: CrossAxisAlignment.start,
  //                   children: [
  //                     Icon(Icons.info_outline_rounded,
  //                         size: 18, color: _kAmber),
  //                     SizedBox(width: 8),
  //                     Expanded(
  //                       child: Text(
  //                         'This task type requires approval — it will be sent to your '
  //                         'reporting head and won\'t be assigned until approved.',
  //                         style: TextStyle(
  //                           color: Color(0xFF9A6410),
  //                           fontWeight: FontWeight.w600,
  //                           fontSize: 13,
  //                           height: 1.35,
  //                         ),
  //                       ),
  //                     ),
  //                   ],
  //                 ),
  //               ),
  //           ],
  //         ),
  //         actions: [
  //           TextButton(
  //             onPressed: () => Navigator.pop(context),
  //             child: const Text('Cancel'),
  //           ),
  //           FilledButton(
  //             style: _filledBtn(),
  //             onPressed: () async {
  //               if (selectedType == null ||
  //                   titleController.text.trim().isEmpty ||
  //                   startDate == null ||
  //                   dueDate == null ||
  //                   selectedEmployeeIds.isEmpty) {
  //                 _snack(
  //                   context,
  //                   'Task Type, Title, dates, and at least one employee are required',
  //                   isError: true,
  //                 );
  //                 return;
  //               }
  //               if (dueDate!.isBefore(startDate!)) {
  //                 _snack(context, 'Due Date cannot be before Start Date',
  //                     isError: true);
  //                 return;
  //               }
  //               final result = await ApiService.createTeamHeadTask(
  //                 projectId: widget.project['projectId'],
  //                 taskTypeId: selectedType['taskTypeId'],
  //                 taskTitle: titleController.text.trim(),
  //                 description: descController.text.trim(),
  //                 priority: priority,
  //                 startDate: startDate!,
  //                 dueDate: dueDate!,
  //                 employeeIds: selectedEmployeeIds.toList(),
  //                 remarks: remarksController.text.trim(),
  //                 createdBy: widget.teamHeadEmployeeId,
  //                 createdByTeamId: widget.teamId,
  //               );
  //               if (result['success'] == true) {
  //                 if (context.mounted) Navigator.pop(context);
  //                 final requiresApproval =
  //                     selectedType['approvalRequired'] == true;
  //                 _loadAll();
  //                 if (mounted) {
  //                   _snack(
  //                     this.context,
  //                     requiresApproval
  //                         ? 'Task sent for approval — pending.'
  //                         : 'Task created and assigned.',
  //                   );
  //                 }
  //               } else {
  //                 _snack(
  //                   context,
  //                   'Could not create task: ${result['error']}',
  //                   isError: true,
  //                 );
  //               }
  //             },
  //             child: const Text('Save'),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }
 Future<void> _openCreateTaskDialog() async {
  final titleController = TextEditingController();
  final descController = TextEditingController();
  final remarksController = TextEditingController();
  final clientNameController = TextEditingController(text: _clientName);

  dynamic selectedType;
  String priority = 'Medium';
  DateTime? startDate;
  DateTime? dueDate;
  final selectedEmployeeIds = <String>{};
  String? selectedLocationId;

  Future<DateTime?> pickDate(BuildContext ctx, DateTime? initial) {
    return showDatePicker(
      context: ctx,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
  }

  // 👈 group members by team for display
  Map<String, List<dynamic>> groupByTeam() {
    final grouped = <String, List<dynamic>>{};
    for (final m in _teamMembers) {
      final teamName = (m['teamName'] ?? 'Unnamed team').toString();
      grouped.putIfAbsent(teamName, () => []).add(m);
    }
    return grouped;
  }

  try {
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => _DialogShell(
          icon: Icons.add_task_rounded,
          title: 'Create Task',
          subtitle: '${widget.project['projectName'] ?? ''}',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TaskTypeDropdown(
                taskTypes: _taskTypes,
                onSelected: (v) => setDialogState(() => selectedType = v),
              ),
              const SizedBox(height: 14),

              if (_isOnSiteType(selectedType)) ...[
                TextField(
                  controller: clientNameController,
                  enabled: false,
                  style: const TextStyle(fontSize: 14.5, color: _kMuted),
                  decoration: _fieldDecoration(
                    label: 'Client',
                    icon: Icons.business_center_outlined,
                  ),
                ),
                const SizedBox(height: 14),
                if (_projectClientId.isEmpty)
                  const _WarningBox(
                    icon: Icons.link_off_rounded,
                    message:
                        'This project is not linked to a client, so no locations '
                        'can be shown.',
                  )
                else if (_clientLocations.isEmpty)
                  const _WarningBox(
                    icon: Icons.location_off_outlined,
                    message:
                        'No locations are set up for this client yet. Ask an '
                        'admin to add one in Admin > Client Locations.',
                  )
                else ...[
                  DropdownButtonFormField<String>(
                    value: selectedLocationId,
                    isExpanded: true,
                    decoration: _fieldDecoration(
                      label: 'Client Location',
                      icon: Icons.location_on_outlined,
                    ),
                    items: _clientLocations
                        .map(
                          (l) => DropdownMenuItem<String>(
                            value: l.clientLocationId,
                            child: Text(
                              l.locationName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setDialogState(() => selectedLocationId = v),
                  ),
                  if (selectedLocationId != null)
                    Builder(builder: (_) {
                      final sel = _clientLocations
                          .where(
                              (l) => l.clientLocationId == selectedLocationId)
                          .toList();
                      if (sel.isEmpty) return const SizedBox.shrink();
                      final l = sel.first;
                      return Padding(
                        padding: const EdgeInsets.only(top: 8, left: 4),
                        child: Text(
                          '${l.address.isEmpty ? '' : '${l.address}\n'}'
                          'Allowed radius: ${l.allowedRadius.toStringAsFixed(0)} m',
                          style: const TextStyle(
                              fontSize: 12.5, color: _kMuted, height: 1.35),
                        ),
                      );
                    }),
                ],
                const SizedBox(height: 14),
              ],

              TextField(
                controller: titleController,
                textCapitalization: TextCapitalization.sentences,
                decoration: _fieldDecoration(
                  label: 'Task Title',
                  icon: Icons.title_rounded,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: descController,
                maxLines: 3,
                minLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: _fieldDecoration(
                  label: 'Description',
                  icon: Icons.notes_rounded,
                ),
              ),
              const SizedBox(height: 16),
              const _FieldLabel('Priority'),
              const SizedBox(height: 8),
              Row(
                children: ['Low', 'Medium', 'High'].map((p) {
                  final selected = priority == p;
                  final color = _priorityColor(p);
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: p == 'High' ? 0 : 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setDialogState(() => priority = p),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected
                                ? color.withOpacity(0.14)
                                : _kBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected ? color : Colors.transparent,
                              width: 1.4,
                            ),
                          ),
                          child: Text(
                            p,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                              color: selected ? color : _kMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _DateField(
                      label: 'Start Date',
                      value: startDate,
                      onTap: () async {
                        final picked = await pickDate(context, startDate);
                        if (picked != null) {
                          setDialogState(() => startDate = picked);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DateField(
                      label: 'Due Date',
                      value: dueDate,
                      onTap: () async {
                        final picked =
                            await pickDate(context, dueDate ?? startDate);
                        if (picked != null) {
                          setDialogState(() => dueDate = picked);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 👈 Employees — all teams, grouped by team name
              Row(
                children: [
                  const Expanded(
                    child: _FieldLabel('Employee(s) — across all your teams'),
                  ),
                  if (selectedEmployeeIds.isNotEmpty)
                    _Pill(
                      icon: Icons.check_rounded,
                      text: '${selectedEmployeeIds.length} selected',
                      color: const Color.fromARGB(255, 12, 86, 147),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 260),
                decoration: BoxDecoration(
                  color: _kBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: _teamMembers.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'No team members found.',
                          style: TextStyle(color: _kMuted, fontSize: 13.5),
                        ),
                      )
                    : ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        children: [
                          for (final entry in groupByTeam().entries) ...[
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(14, 10, 14, 4),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.groups_rounded,
                                    size: 14,
                                    color: Colors.blue[700],
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    entry.key.isEmpty ? 'Team' : entry.key,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.blue[700],
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            for (final m in entry.value)
                              _buildMemberTile(m, selectedEmployeeIds,
                                  setDialogState),
                          ],
                        ],
                      ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: remarksController,
                maxLines: 3,
                minLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: _fieldDecoration(
                  label: 'Remarks',
                  icon: Icons.sticky_note_2_outlined,
                ),
              ),
              if (selectedType != null &&
                  selectedType['approvalRequired'] == true)
                Container(
                  margin: const EdgeInsets.only(top: 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _kAmber.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 18, color: _kAmber),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This task type requires approval — it will be sent to your '
                          'reporting head and won\'t be assigned until approved.',
                          style: TextStyle(
                            color: Color(0xFF9A6410),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: _filledBtn(),
              onPressed: () async {
                if (selectedType == null ||
                    titleController.text.trim().isEmpty ||
                    startDate == null ||
                    dueDate == null ||
                    selectedEmployeeIds.isEmpty) {
                  _snack(
                    context,
                    'Task Type, Title, dates, and at least one employee are required',
                    isError: true,
                  );
                  return;
                }
                if (_isOnSiteType(selectedType) && selectedLocationId == null) {
                  _snack(
                    context,
                    'Please select a client location for an On Site task',
                    isError: true,
                  );
                  return;
                }
                if (dueDate!.isBefore(startDate!)) {
                  _snack(context, 'Due Date cannot be before Start Date',
                      isError: true);
                  return;
                }

                // 👈 split employees by their team
                final assignmentsByTeam = <String, List<String>>{};
                for (final empId in selectedEmployeeIds) {
                  final tid = _memberTeamMap[empId] ?? widget.teamId;
                  assignmentsByTeam.putIfAbsent(tid, () => []).add(empId);
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
                  assignmentsByTeam: assignmentsByTeam, // 👈 NEW
                  remarks: remarksController.text.trim(),
                  createdBy: widget.teamHeadEmployeeId,
                  createdByTeamId: widget.teamId,
                  clientLocationId:
                      _isOnSiteType(selectedType) ? selectedLocationId : null,
                );

                if (!context.mounted) return;

                if (result['success'] == true) {
                  Navigator.pop(context);
                  final requiresApproval =
                      selectedType['approvalRequired'] == true;
                  _loadAll();
                  if (mounted) {
                    _snack(
                      this.context,
                      requiresApproval
                          ? 'Task sent for approval — pending.'
                          : 'Task created and assigned.',
                    );
                  }
                } else {
                  _snack(
                    context,
                    'Could not create task: ${result['error']}',
                    isError: true,
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  } finally {
    
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: _appBar(widget.project['projectName'] ?? 'Project'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateTaskDialog,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('New Task'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                itemCount: _tasks.isEmpty ? 2 : _tasks.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) return _buildProjectHeader();
                  if (_tasks.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: _EmptyState(
                        icon: Icons.checklist_rounded,
                        title: 'No tasks yet',
                        message: 'Tap "New Task" to create one.',
                      ),
                    );
                  }
                  return _buildTaskCard(_tasks[index - 1]);
                },
              ),
            ),
    );
  }

  Widget _buildProjectHeader() {
    final primary = const Color.fromARGB(255, 12, 86, 147);
    final status = (widget.project['status'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary, primary.withOpacity(0.72)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
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
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.date_range_rounded,
                        size: 15, color: Colors.white.withOpacity(0.85)),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        '${_fmtAny(widget.project['startDate'])}  →  ${_fmtAny(widget.project['endDate'])}',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.88),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
   
           
              if (_clientName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.business_center_outlined,
                          size: 15, color: Colors.white.withOpacity(0.85)),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          _clientName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.88),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (status.isNotEmpty)
            _Pill(
              icon: Icons.circle,
              iconSize: 8,
              text: _statusLabel(status),
              color: _statusColor(status),
              solid: true,
            ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(dynamic t) {
    final status = t['status']?.toString();
    final priority = t['priority']?.toString() ?? '';
    final assignees = (t['assignedToNames'] ?? '').toString();
    final typeName = (t['taskTypeName'] ?? '').toString();

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
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TaskDetailScreen(taskId: t['taskId']),
            ),
          ),
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
                        (t['taskTitle'] ?? '').toString(),
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
                      icon: Icons.circle,
                      iconSize: 8,
                      text: _statusLabel(status),
                      color: _statusColor(status),
                    ),
                  ],
                ),
                if (typeName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    typeName,
                    style: const TextStyle(fontSize: 13, color: _kMuted),
                  ),
                ],
                const SizedBox(height: 12),
                const Divider(height: 1, color: _kLine),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.people_alt_outlined,
                        size: 16, color: _kMuted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        assignees.isEmpty ? 'Unassigned' : assignees,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, color: _kInk),
                      ),
                    ),
                    if (priority.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      _Pill(
                        icon: Icons.flag_rounded,
                        text: priority,
                        color: _priorityColor(priority),
                      ),
                    ],
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
// Screen 3: Task detail
// =============================================================================
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
    try {
      final task = await ApiService.getTaskDetail(widget.taskId);
      if (!mounted) return;
      setState(() {
        _task = task;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack(context, 'Could not load task: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: _kBg,
        appBar: _appBar('Task Details'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final primary = const Color.fromARGB(255, 12, 86, 147);
    final assignees = (_task['assignedEmployees'] as List?) ?? [];
    final summaries = (_task['dailySummaries'] as List?) ?? [];
    final snapshots = (_task['completionSnapshotUrls'] as List?) ?? [];
    final history = (_task['history'] as List?) ?? [];
    final siteValidation = _task['siteValidation'];
    final completion = _task['completion'];
    final status = _task['status']?.toString();
    final priority = _task['priority']?.toString() ?? '';
    final description = (_task['taskDescription'] ?? '').toString();

    return Scaffold(
      backgroundColor: _kBg,
      appBar: _appBar('Task Details'),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            // ---------------------------------------------------- header
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primary, primary.withOpacity(0.72)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: primary.withOpacity(0.28),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (_task['taskTitle'] ?? 'Task').toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 13.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Pill(
                        icon: Icons.circle,
                        iconSize: 8,
                        text: _statusLabel(status),
                        color: _statusColor(status),
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

            // ---------------------------------------------------- overview
            _SectionCard(
              title: 'Overview',
              icon: Icons.info_outline_rounded,
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.category_outlined,
                    label: 'Type',
                    value: '${_task['taskTypeName'] ?? '-'}',
                  ),
                   if ((_task['clientName']?.toString() ?? '').isNotEmpty)
                  _InfoRow(
                    icon: Icons.business_outlined,
                    label: 'Client',
                    value: _task['clientName'].toString(),
                  ),

                // Show Client Location only if it exists
                if ((_task['clientLocationName']?.toString() ?? '').isNotEmpty)
                  _InfoRow(
                    icon: Icons.location_on_outlined,
                    label: 'Client Location',
                    value: _task['clientLocationName'].toString(),
                  ),
                  _InfoRow(
                    icon: Icons.flag_outlined,
                    label: 'Priority',
                    value: '${_task['priority'] ?? '-'}',
                  ),
                  _InfoRow(
                    icon: Icons.timelapse_rounded,
                    label: 'Status',
                    value: _statusLabel(status),
                  ),
                  _InfoRow(
                    icon: Icons.verified_outlined,
                    label: 'Approval',
                    value: _statusLabel(_task['approvalStatus']?.toString()),
                  ),
                  _InfoRow(
                    icon: Icons.event_rounded,
                    label: 'Due',
                    value: _fmtAny(_task['dueDate']),
                  ),
                  _InfoRow(
                    icon: Icons.schedule_rounded,
                    label: 'Total Hours',
                    value: '${_task['totalTaskHours'] ?? 0}',
                    last: true,
                  ),
                ],
              ),
            ),

            // ---------------------------------------------------- assignees
            _SectionCard(
              title: 'Assigned Employees',
              icon: Icons.people_alt_rounded,
              count: assignees.length,
              child: assignees.isEmpty
                  ? const _MutedText('No one assigned yet.')
                  : Column(
                      children: assignees.map((a) {
                        final name = (a['employeeName'] ?? '').toString();
                        final st = a['assignmentStatus']?.toString();
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              _InitialsAvatar(
                                  name: name, size: 38, radius: 19),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: _kInk,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${a['totalHours'] ?? 0}h logged',
                                      style: const TextStyle(
                                          fontSize: 12.5, color: _kMuted),
                                    ),
                                  ],
                                ),
                              ),
                              _Pill(
                                icon: Icons.circle,
                                iconSize: 8,
                                text: _statusLabel(st),
                                color: _statusColor(st),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),

            // ---------------------------------------------------- summaries
            _SectionCard(
              title: 'Daily Work Summaries',
              icon: Icons.edit_note_rounded,
              count: summaries.length,
              child: summaries.isEmpty
                  ? const _MutedText('None logged yet.')
                  : Column(
                      children: [
                        for (var i = 0; i < summaries.length; i++) ...[
                          if (i > 0)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Divider(height: 1, color: _kLine),
                            ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _fmtAny(summaries[i]['workDate']),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: _kInk,
                                      ),
                                    ),
                                  ),
                                  _Pill(
                                    icon: Icons.schedule_rounded,
                                    text:
                                        '${summaries[i]['dailyTotalHours']}h',
                                    color: _kBlue,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                (summaries[i]['dailyWorkSummary'] ?? '')
                                    .toString(),
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  color: _kMuted,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
            ),

            // ---------------------------------------------------- completion
            _SectionCard(
              title: 'Completion',
              icon: Icons.task_alt_rounded,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (completion == null)
                    const _MutedText('Not completed yet.')
                  else
                    Text(
                      (completion['finalSummary'] ?? '').toString(),
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: _kInk,
                        height: 1.4,
                      ),
                    ),
                  if (snapshots.isNotEmpty) ...[
  const SizedBox(height: 12),
  const _FieldLabel('Completion Snapshot(s)'),
  const SizedBox(height: 6),
  for (final s in snapshots)
    Builder(builder: (_) {
      debugPrint('SNAPSHOT RAW: $s');
      debugPrint('SNAPSHOT URL: ${ApiService.resolveFileUrl('$s')}');
      return const SizedBox.shrink();
    }),
  Wrap(
    spacing: 8,
    runSpacing: 8,
    children: snapshots.map((s) {
      final url = ApiService.resolveFileUrl('$s');
      return GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                backgroundColor: Colors.black,
                iconTheme: const IconThemeData(color: Colors.white),
              ),
              body: Center(
                child: InteractiveViewer(
                  child: Image.network(
                    url,
                    headers: ApiService.getHeaders(), // drop if files are public
                    fit: BoxFit.contain,
                    loadingBuilder: (c, child, p) => p == null
                        ? child
                        : const CircularProgressIndicator(),
                    errorBuilder: (c, e, st) => const Icon(
                      Icons.broken_image,
                      color: Colors.white,
                      size: 64,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            url,
            headers: ApiService.getHeaders(), // drop if files are public
            width: 90,
            height: 90,
            fit: BoxFit.cover,
            loadingBuilder: (c, child, p) {
              if (p == null) return child;
              return Container(
                width: 90,
                height: 90,
                color: Colors.grey.shade200,
                child: const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            },
            errorBuilder: (c, e, st) => Container(
              width: 90,
              height: 90,
              color: Colors.grey.shade200,
              child: const Icon(Icons.broken_image, color: Colors.grey),
            ),
          ),
        ),
      );
    }).toList(),
  ),
],
                ],
              ),
            ),

            // ---------------------------------------------------- site check
            if (siteValidation != null)
              _SectionCard(
                title: 'Site Validation',
                icon: Icons.location_on_outlined,
                child: Builder(builder: (context) {
                  final vs =
                      (siteValidation['validationStatus'] ?? '').toString();
                  final lower = vs.toLowerCase();
                  final bad = lower.contains('fail') ||
                      lower.contains('invalid') ||
                      lower.contains('out');
                  final color = bad ? _kRed : _kGreen;
                  return Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          bad
                              ? Icons.wrong_location_rounded
                              : Icons.where_to_vote_rounded,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              vs,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: color,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${siteValidation['calculatedDistance']}m '
                              '(allowed ${siteValidation['allowedRadius']}m)',
                              style: const TextStyle(
                                  fontSize: 13, color: _kMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
              ),

            // ---------------------------------------------------- history
            _SectionCard(
              title: 'History',
              icon: Icons.history_rounded,
              count: history.length,
              child: history.isEmpty
                  ? const _MutedText('No history yet.')
                  : Column(
                      children: [
                        for (var i = 0; i < history.length; i++)
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  width: 18,
                                  child: Column(
                                    children: [
                                      const SizedBox(height: 4),
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: primary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      if (i != history.length - 1)
                                        Expanded(
                                          child: Container(
                                            width: 2,
                                            color: _kLine,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      bottom:
                                          i == history.length - 1 ? 0 : 14,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          (history[i]['event'] ?? '')
                                              .toString(),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: _kInk,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _fmtAny(history[i]['timestamp'],
                                              withTime: true),
                                          style: const TextStyle(
                                              fontSize: 12.5,
                                              color: _kMuted),
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
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Shared widgets
// =============================================================================

InputDecoration _fieldDecoration({required String label, IconData? icon}) {
  return InputDecoration(
    labelText: label,
    prefixIcon: icon == null ? null : Icon(icon, size: 20),
    filled: true,
    fillColor: _kBg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
     disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
  );
}

ButtonStyle _filledBtn() => FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
class _WarningBox extends StatelessWidget {
  final IconData icon;
  final String message;

  const _WarningBox({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kAmber.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: _kAmber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF9A6410),
                fontWeight: FontWeight.w600,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
    final color = const Color.fromARGB(255, 12, 86, 147);

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
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
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
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
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
      content: SingleChildScrollView(
        child: SizedBox(width: 400, child: content),
      ),
      actions: actions,
    );
  }
}

/// Searchable task-type dropdown; popup width matches the field.
class _TaskTypeDropdown extends StatelessWidget {
  final List<dynamic> taskTypes;
  final ValueChanged<dynamic> onSelected;

  const _TaskTypeDropdown({
    required this.taskTypes,
    required this.onSelected,
  });

  String _label(dynamic t) => (t['taskTypeName'] ?? '').toString();

  @override
  Widget build(BuildContext context) {
    final primary = const Color.fromARGB(255, 12, 86, 147);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double fieldWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 320;

        return DropdownMenu<dynamic>(
          width: fieldWidth,
          menuHeight: 260,
          label: const Text('Task Type'),
          hintText: taskTypes.isEmpty ? 'No task types loaded' : 'Select type',
          leadingIcon: const Icon(Icons.category_outlined, size: 20),
          enableFilter: true,
          enableSearch: true,
          requestFocusOnTap: true,
          textStyle: const TextStyle(fontSize: 14.5, color: _kInk),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: _kBg,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: primary, width: 1.5),
            ),
          ),
          menuStyle: MenuStyle(
            backgroundColor: const MaterialStatePropertyAll(Colors.white),
            surfaceTintColor:
                const MaterialStatePropertyAll(Colors.transparent),
            elevation: const MaterialStatePropertyAll(6),
            padding: const MaterialStatePropertyAll(
              EdgeInsets.symmetric(vertical: 6),
            ),
            minimumSize: MaterialStatePropertyAll(Size(fieldWidth, 0)),
            maximumSize:
                MaterialStatePropertyAll(Size(fieldWidth, double.infinity)),
            shape: MaterialStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: _kLine),
              ),
            ),
          ),
          filterCallback: (entries, query) {
            final q = query.trim().toLowerCase();
            if (q.isEmpty) return entries;
            return entries
                .where((e) => e.label.toLowerCase().contains(q))
                .toList();
          },
          dropdownMenuEntries: taskTypes
              .map(
                (t) => DropdownMenuEntry<dynamic>(
                  value: t,
                  label: _label(t),
                  trailingIcon: t['approvalRequired'] == true
                      ? const Icon(Icons.verified_user_outlined,
                          size: 16, color: _kAmber)
                      : null,
                  style: ButtonStyle(
                    shape: MaterialStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    textStyle: const MaterialStatePropertyAll(
                      TextStyle(fontSize: 14),
                    ),
                  ),
                ),
              )
              .toList(),
          onSelected: onSelected,
        );
      },
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: InputDecorator(
        isEmpty: value == null,
        decoration: _fieldDecoration(
          label: label,
          icon: Icons.calendar_today_rounded,
        ),
        child: Text(
          value == null ? '' : _fmtDateTime(value),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14.5, color: _kInk),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: _kMuted,
      ),
    );
  }
}

class _MutedText extends StatelessWidget {
  final String text;
  const _MutedText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 13.5, color: _kMuted));
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
    final primary = const Color.fromARGB(255, 12, 86, 147);

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
                  color: primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: primary),
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
                    color: primary.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: primary,
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
    final primary = const Color.fromARGB(255, 12, 86, 147);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary, primary.withOpacity(0.65)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
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

  /// White background (for use on the gradient headers).
  final bool solid;

  const _Pill({
    required this.icon,
    required this.text,
    required this.color,
    this.iconSize = 14,
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
          Icon(icon, size: iconSize, color: color),
          const SizedBox(width: 5),
          Text(
            text,
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
    final primary = const Color.fromARGB(255, 12, 86, 147);
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
                color: primary.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 38, color: primary),
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