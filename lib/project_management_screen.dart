import 'package:attendance_app/services/apiservice.dart';
import 'package:attendance_app/services/ApiClient.dart';
import 'package:attendance_app/widgets/SizeConfig.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

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

String _initials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

String _fmtDate(DateTime? d) {
  if (d == null) return '';
  return '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
}

/// Returns the first non-empty value found under any of [keys].
String _pick(dynamic m, List<String> keys) {
  if (m is! Map) return '';
  for (final k in keys) {
    final v = m[k];
    if (v != null && v.toString().isNotEmpty) return v.toString();
  }
  return '';
}

/// Normalises whatever an ApiService call returns (a List, a Dio Response
/// wrapping a List, or a {data: [...]} map) into a plain List.
List<dynamic> _asList(dynamic v) {
  if (v is Response) v = v.data;
  if (v is Map && v['data'] is List) v = v['data'];
  return v is List ? v : <dynamic>[];
}

class ProjectManagementScreen extends StatefulWidget {
  final String companyId;
  final String currentEmployeeId;

  const ProjectManagementScreen({
    super.key,
    required this.companyId,
    required this.currentEmployeeId,
  });

  @override
  State<ProjectManagementScreen> createState() =>
      _ProjectManagementScreenState();
}

class _SimpleOption {
  final String id;
  final String name;
  final String code;
  const _SimpleOption({required this.id, required this.name, this.code = ''});

  String get label => code.isEmpty ? name : '$name ($code)';
}

/// Sentinel entry used so optional dropdowns can be cleared.
const _SimpleOption _kNone = _SimpleOption(id: '', name: '— None —');

class _ProjectManagementScreenState extends State<ProjectManagementScreen> {
  List<dynamic> _projects = [];
  List<_SimpleOption> _clientOptions = [];
  List<_SimpleOption> _teamOptions = [];
  List<_SimpleOption> _employeeOptions = [];
  bool _loadingOptions = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProjects();
    _loadOptions();
  }

  /// Runs one list-returning call. A failure in one source (e.g. employees)
  /// no longer wipes out the others (clients / teams).
  Future<List<dynamic>> _fetchList(
    Future<dynamic> Function() call,
    String label,
    List<String> errors,
  ) async {
    try {
      return _asList(await call());
    } catch (e) {
      errors.add('$label ($e)');
      return <dynamic>[];
    }
  }

  Future<void> _loadOptions() async {
    setState(() => _loadingOptions = true);

    final errors = <String>[];
    final results = await Future.wait([
      _fetchList(() => ApiService.getClients(), 'clients', errors),
      _fetchList(() => ApiService.getTeams(widget.companyId), 'teams', errors),
      _fetchList(() => ApiService.getTeamHeader(), 'employees', errors),
    ]);

    if (!mounted) return;

    final clients = results[0];
    final teams = results[1];
    final employees = results[2];

    setState(() {
      // NOTE: the existing /entity/all client list is string-keyed
      // (`code`), from before this module's GUID-keyed Client/ClientLocation
      // tables. If your migration added a real GUID id to Client, map that
      // field here instead of falling back to `code` — otherwise Project
      // creation will send a non-GUID clientId and the backend will reject it.
      _clientOptions = clients
          .map((c) => _SimpleOption(
                id: _pick(c, ['id', 'Id', 'code', 'Code']),
                name: _pick(c, ['name', 'Name']),
              ))
          .where((c) => c.id.isNotEmpty)
          .toList();

      _teamOptions = teams
          .map((t) => _SimpleOption(
                id: _pick(t, ['teamId', 'TeamId', 'id']),
                name: _pick(t, ['teamName', 'TeamName', 'name']),
              ))
          .where((t) => t.id.isNotEmpty)
          .toList();

      // getTeamHeader() returns employeeId / employeeName / employeeCode
      // (same keys TeamManagementScreen reads).
      _employeeOptions = employees
          .map((e) => _SimpleOption(
                id: _pick(e, ['employeeId', 'id', 'Id']),
                name: _pick(e, ['employeeName', 'name', 'Name']),
                code: _pick(e, ['employeeCode', 'code', 'Code']),
              ))
          .where((e) => e.id.isNotEmpty && e.name.isNotEmpty)
          .toList();

      _loadingOptions = false;
    });

    if (errors.isNotEmpty) {
      _showMessage('Could not load: ${errors.join('; ')}', isError: true);
    }
  }

  Future<void> _loadProjects() async {
    setState(() => _loading = true);
    try {
      final projects = await ApiService.getProjects();
      if (!mounted) return;
      setState(() {
        _projects = projects;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage('Could not load projects: $e', isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
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

  // ---------------------------------------------------------------------------
  // Create project
  // ---------------------------------------------------------------------------
  Future<void> _openCreateProjectDialog() async {
    if (_loadingOptions) {
      _showMessage(
        'Still loading clients/teams/employees — try again in a moment',
        isError: true,
      );
      return;
    }
    final nameController = TextEditingController();
    final descController = TextEditingController();
    DateTime? startDate;
    DateTime? endDate;
    _SimpleOption? client;
    _SimpleOption? manager;

    Future<DateTime?> pickDate(BuildContext ctx, DateTime? initial) {
      return showDatePicker(
        context: ctx,
        initialDate: initial ?? DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => _DialogShell(
          icon: Icons.create_new_folder_rounded,
          title: 'Create Project',
          subtitle: 'Set up a project under a client.',
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _OptionDropdown(
                label: 'Client',
                icon: Icons.business_rounded,
                value: client,
                options: _clientOptions,
                onSelected: (v) => setDialogState(() => client = v),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: _fieldDecoration(
                  label: 'Project Name',
                  icon: Icons.folder_open_rounded,
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
              const SizedBox(height: 14),
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
                      label: 'End Date',
                      value: endDate,
                      onTap: () async {
                        final picked =
                            await pickDate(context, endDate ?? startDate);
                        if (picked != null) {
                          setDialogState(() => endDate = picked);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _OptionDropdown(
                label: 'Project Manager (optional)',
                icon: Icons.manage_accounts_rounded,
                value: manager,
                options: _employeeOptions,
                allowNone: true,
                onSelected: (v) => setDialogState(() => manager = v),
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
                if (client == null ||
                    nameController.text.trim().isEmpty ||
                    startDate == null ||
                    endDate == null) {
                  _showMessage(
                    'Client, Project Name, Start and End Date are required',
                    isError: true,
                  );
                  return;
                }
                if (endDate!.isBefore(startDate!)) {
                  _showMessage(
                    'End Date cannot be before Start Date',
                    isError: true,
                  );
                  return;
                }

                final result = await ApiService.createProject(
                  clientId: client!.id,
                  projectName: nameController.text.trim(),
                  description: descController.text.trim(),
                  startDate: startDate!,
                  endDate: endDate!,
                  projectManagerId: manager?.id,
                  createdBy: ApiService.empGuid ?? '',
                );

                print("Project Create ${result}");

                if (!context.mounted) return;

                if (result['success'] == true) {
                  Navigator.pop(context);
                  _loadProjects();
                } else {
                  _showMessage(
                    'Could not create project: ${result['error'] ?? 'Unknown error'}',
                    isError: true,
                  );
                }
              },
              child: const Text('Save Project'),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight + 10),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppBar(
            title: Text(
              'Project Management',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
            ),
            backgroundColor: Colors.white,
            foregroundColor: const Color.fromARGB(255, 12, 86, 147),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateProjectDialog,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Project'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProjects,
              child: _projects.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        _EmptyState(
                          icon: Icons.folder_copy_outlined,
                          title: 'No projects yet',
                          message: 'Tap "New Project" to create your first one.',
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                      itemCount: _projects.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) return _buildStats();
                        return _buildProjectCard(_projects[index - 1]);
                      },
                    ),
            ),
    );
  }

  Widget _buildStats() {
    final primary = const Color.fromARGB(255, 12, 86, 147);
    final active = _projects.where((p) => p['isActive'] == true).length;
    int teams = 0;
    for (final p in _projects) {
      final c = p['teamCount'];
      if (c is num) teams += c.toInt();
    }

    Widget tile(String label, int value, IconData icon, Color color) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: _softShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(height: 10),
              Text(
                '$value',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _kInk,
                ),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 12.5, color: _kMuted),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          tile('Projects', _projects.length, Icons.folder_copy_rounded,
              primary),
          const SizedBox(width: 10),
          tile('Active', active, Icons.bolt_rounded, _kGreen),
          const SizedBox(width: 10),
          tile('Team links', teams, Icons.groups_rounded, _kBlue),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('complete') || s.contains('done')) return _kBlue;
    if (s.contains('hold') || s.contains('pause')) return _kAmber;
    if (s.contains('cancel') || s.contains('closed')) return _kRed;
    return _kGreen;
  }

  Widget _buildProjectCard(dynamic p) {
    final name = (p['projectName'] ?? '').toString();
    final status = (p['status'] ?? '').toString();
    final pm = (p['projectManagerName'] ?? '-').toString();
    final isActive = p['isActive'] == true;

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
          onTap: () => _openProjectTeams(p),
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
                          const Icon(Icons.manage_accounts_outlined,
                              size: 15, color: _kMuted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'PM: $pm',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13, color: _kMuted),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (status.isNotEmpty)
                            _Pill(
                              icon: Icons.circle,
                              iconSize: 8,
                              text: status,
                              color: _statusColor(status),
                            ),
                          _Pill(
                            icon: Icons.groups_rounded,
                            text: '${p['teamCount'] ?? 0} team(s)',
                            color: _kBlue,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: isActive,
                      onChanged: (val) async {
                        await ApiService.setProjectActive(
                            p['projectId'], val);
                        _loadProjects();
                      },
                    ),
                    Text(
                      isActive ? 'Active' : 'Inactive',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isActive ? _kGreen : _kMuted,
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

  // ---------------------------------------------------------------------------
  // Project teams sheet
  // ---------------------------------------------------------------------------
  Future<void> _openProjectTeams(dynamic project) async {
    List<dynamic> teams;
    try {
      teams = await ApiService.getProjectTeams(project['projectId']);
    } catch (e) {
      _showMessage('Could not load teams: $e', isError: true);
      return;
    }
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kBg,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                const SizedBox(height: 14),
                Row(
                  children: [
                    _InitialsAvatar(
                      name: (project['projectName'] ?? '').toString(),
                      size: 44,
                      radius: 14,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (project['projectName'] ?? '').toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: _kInk,
                            ),
                          ),
                          Text(
                            '${teams.length} team(s) assigned',
                            style: const TextStyle(
                                fontSize: 13, color: _kMuted),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      style: _filledBtn(),
                      icon: const Icon(Icons.group_add_rounded, size: 18),
                      label: const Text('Add Team'),
                      onPressed: () async {
                        final added = await _openAddTeamDialog(project);
                        if (added) {
                          final refreshed = await ApiService.getProjectTeams(
                              project['projectId']);
                          setSheetState(() => teams = refreshed);
                          _loadProjects();
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (teams.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: _EmptyState(
                      icon: Icons.groups_2_outlined,
                      title: 'No teams assigned yet',
                      message: 'Use "Add Team" to assign one.',
                      compact: true,
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: teams.length,
                      itemBuilder: (context, i) {
                        final t = teams[i];
                        final active = t['isActive'] == true;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: _softShadow,
                          ),
                          child: Row(
                            children: [
                              _InitialsAvatar(
                                name: (t['teamName'] ?? '').toString(),
                                size: 42,
                                radius: 13,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (t['teamName'] ?? '').toString(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: _kInk,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Head: ${t['teamHeadName'] ?? '-'}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 12.5, color: _kMuted),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: active,
                                onChanged: (val) async {
                                  await ApiService.setProjectTeamActive(
                                      t['projectTeamId'], val);
                                  final refreshed =
                                      await ApiService.getProjectTeams(
                                          project['projectId']);
                                  setSheetState(() => teams = refreshed);
                                },
                              ),
                              IconButton(
                                tooltip: 'Remove team',
                                style: IconButton.styleFrom(
                                  foregroundColor: _kRed,
                                  backgroundColor: _kRed.withOpacity(0.08),
                                ),
                                icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 20),
                                onPressed: () async {
                                  await ApiService.removeProjectTeam(
                                      t['projectTeamId']);
                                  final refreshed =
                                      await ApiService.getProjectTeams(
                                          project['projectId']);
                                  setSheetState(() => teams = refreshed);
                                  _loadProjects();
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _openAddTeamDialog(dynamic project) async {
    _SimpleOption? selected;
    bool added = false;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => _DialogShell(
          icon: Icons.group_add_rounded,
          title: 'Add Team to Project',
          subtitle: 'Pick a team to assign to this project.',
          content: _OptionDropdown(
            label: 'Team',
            icon: Icons.groups_rounded,
            value: selected,
            options: _teamOptions,
            onSelected: (v) => setDialogState(() => selected = v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: _filledBtn(),
              onPressed: () async {
                if (selected == null) return;
                final result = await ApiService.addProjectTeam(
                  projectId: project['projectId'],
                  teamId: selected!.id,
                  assignedBy: widget.currentEmployeeId,
                );
                if (result['success'] == true) {
                  added = true;
                  if (context.mounted) Navigator.pop(context);
                } else {
                  _showMessage('Could not add team: ${result['error']}',
                      isError: true);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    return added;
  }
}

// -----------------------------------------------------------------------------
// Shared styling helpers & small widgets
// -----------------------------------------------------------------------------

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
  );
}

ButtonStyle _filledBtn() => FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );

class _DialogShell extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget content;
  final List<Widget> actions;
  final bool scrollable;

  const _DialogShell({
    required this.icon,
    required this.title,
    required this.content,
    required this.actions,
    this.subtitle,
    this.scrollable = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = const Color.fromARGB(255, 12, 86, 147);
    final body = SizedBox(width: 400, child: content);

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
      content: scrollable ? SingleChildScrollView(child: body) : body,
      actions: actions,
    );
  }
}

/// Searchable dropdown whose popup is exactly as wide as the field.
/// Works with an empty list too (shows a hint instead of silently doing
/// nothing), and can offer a "None" entry for optional fields.
class _OptionDropdown extends StatelessWidget {
  final String label;
  final IconData icon;
  final _SimpleOption? value;
  final List<_SimpleOption> options;
  final ValueChanged<_SimpleOption?> onSelected;
  final bool allowNone;

  const _OptionDropdown({
    required this.label,
    required this.icon,
    required this.value,
    required this.options,
    required this.onSelected,
    this.allowNone = false,
  });

  @override
  Widget build(BuildContext context) {
    final primary = const Color.fromARGB(255, 12, 86, 147);
    final entries = <_SimpleOption>[
      if (allowNone) _kNone,
      ...options,
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final double fieldWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 320;

        return DropdownMenu<_SimpleOption>(
          width: fieldWidth,
          menuHeight: 280,
          label: Text(label),
          hintText: options.isEmpty ? 'Nothing to choose from' : 'Search…',
          leadingIcon: Icon(icon, size: 20),
          enableFilter: true,
          enableSearch: true,
          requestFocusOnTap: true,
          initialSelection: value,
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
          filterCallback: (list, query) {
            final q = query.trim().toLowerCase();
            if (q.isEmpty) return list;
            return list
                .where((e) => e.label.toLowerCase().contains(q))
                .toList();
          },
          dropdownMenuEntries: entries
              .map(
                (o) => DropdownMenuEntry<_SimpleOption>(
                  value: o,
                  label: o.label,
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
          onSelected: (v) =>
              onSelected(v == null || v.id.isEmpty ? null : v),
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
          value == null ? '' : _fmtDate(value),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 14.5, color: _kInk),
        ),
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
  final bool compact;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final primary = const Color.fromARGB(255, 12, 86, 147);
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 56 : 80,
          height: compact ? 56 : 80,
          decoration: BoxDecoration(
            color: primary.withOpacity(0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: compact ? 28 : 38, color: primary),
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
    );

    return Center(
      child: compact
          ? content
          : Padding(padding: const EdgeInsets.all(32), child: content),
    );
  }
}