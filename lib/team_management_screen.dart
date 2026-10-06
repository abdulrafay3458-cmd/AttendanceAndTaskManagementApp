import 'package:attendance_app/models/org_structure_model.dart';
import 'package:attendance_app/services/apiservice.dart';
import 'package:attendance_app/widgets/SizeConfig.dart';
import 'package:flutter/material.dart';

// -----------------------------------------------------------------------------
// Design tokens
// -----------------------------------------------------------------------------
const Color _kBg = Color(0xFFF5F6FA);
const Color _kInk = Color(0xFF1F2430);
const Color _kMuted = Color(0xFF7A8194);
const Color _kLine = Color(0xFFE6E8F0);
const Color _kGreen = Color(0xFF22A06B);
const Color _kRed = Color(0xFFE5484D);

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

class TeamManagementScreen extends StatefulWidget {
  final String companyId;
  final String currentEmployeeId;
  final String currentEmployeeCode;

  const TeamManagementScreen({
    super.key,
    required this.companyId,
    required this.currentEmployeeId,
    required this.currentEmployeeCode,
  });

  @override
  State<TeamManagementScreen> createState() => _TeamManagementScreenState();
}

class _TeamManagementScreenState extends State<TeamManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loadingTeams = true;
  List<TeamModel> _teams = [];
  List<_EmployeeOption> _employeeOptions = [];

  String _formatDate(DateTime? date) {
    if (date == null) return 'Not specified';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Future<bool?> _showRemoveConfirmation(
    BuildContext context,
    String employeeName,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return _DialogShell(
          icon: Icons.person_remove_alt_1_rounded,
          iconColor: _kRed,
          title: 'Remove Team Member?',
          subtitle:
              'Are you sure you want to remove $employeeName from this team?',
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _kRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));

    _loadTeams();
    _loadEmployeeOptions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTeams() async {
    setState(() => _loadingTeams = true);
    try {
      final teams = await ApiService.getOrgTeams(widget.companyId);
      setState(() {
        _teams = teams;
        _loadingTeams = false;
      });
    } catch (e) {
      setState(() => _loadingTeams = false);
      if (mounted) _showError('Could not load teams: $e');
    }
  }

  Future<void> _loadEmployeeOptions() async {
    try {
      final List<dynamic> data = await ApiService.getTeamHeader();

      setState(() {
        _employeeOptions = data
            .map((e) => _EmployeeOption(
                  id: (e['employeeId'] ?? '').toString(),
                  name: (e['employeeName'] ?? '').toString(),
                  code: (e['employeeCode'] ?? '').toString(),
                ))
            .where((e) => e.id.isNotEmpty && e.name.isNotEmpty)
            .toList();
      });
    } catch (e) {
      if (mounted) {
        _showError('Could not load team head list: $e');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _kRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _openCreateTeamDialog() async {
    final nameController = TextEditingController();
    _EmployeeOption? selectedHead;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => _DialogShell(
          icon: Icons.groups_rounded,
          iconColor: Colors.white,
          title: 'Create Team',
          subtitle: 'Give your team a name and pick who leads it.',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                decoration: _fieldDecoration(
                  label: 'Team Name',
                  icon: Icons.badge_outlined,
                ),
              ),
              const SizedBox(height: 14),
              _SearchableEmployeeDropdown(
                label: 'Team Head',
                value: selectedHead,
                options: _employeeOptions,
                onSelected: (value) {
                  setDialogState(() {
                    selectedHead = value;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: _filledBtn(context),
              onPressed: () async {
                if (nameController.text.trim().isEmpty ||
                    selectedHead == null) {
                  _showError('Team name and Team Head are required');
                  return;
                }
                try {
                  await ApiService.createOrgTeam(
                    companyId: widget.companyId,
                    teamName: nameController.text.trim(),
                    teamHeadId: selectedHead!.id,
                    createdByEmployeeCode: widget.currentEmployeeCode,
                  );
                  if (context.mounted) Navigator.pop(context);
                  _loadTeams();
                } catch (e) {
                  _showError('Could not create team: $e');
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Colors.blue;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue[700],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Teams & Reporting Hierarchy',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Container(
            height: 48,
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: _softShadow,
            ),
            child: TabBar(
              controller: _tabController,
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(10),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: _kMuted,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              splashBorderRadius: BorderRadius.circular(10),
              tabs: const [
                Tab(
                  height: 40,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.groups_rounded, size: 18),
                      SizedBox(width: 6),
                      Text('Teams'),
                    ],
                  ),
                ),
                Tab(
                  height: 40,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.account_tree_rounded, size: 18),
                      SizedBox(width: 6),
                      Text('Hierarchy'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: _openCreateTeamDialog,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Team'),
            )
          : null,
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTeamsTab(),
          _ReportingHierarchyTab(
            currentEmployeeId: widget.currentEmployeeId,
            employeeOptions: _employeeOptions,
            onError: _showError,
          ),
        ],
      ),
    );
  }

  Widget _buildTeamsTab() {
    if (_loadingTeams) return const Center(child: CircularProgressIndicator());
    if (_teams.isEmpty) {
      return const _EmptyState(
        icon: Icons.groups_2_outlined,
        title: 'No teams yet',
        message: 'Tap "New Team" to create your first one.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTeams,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        itemCount: _teams.length,
        itemBuilder: (context, index) {
          final team = _teams[index];
          return _buildTeamCard(team);
        },
      ),
    );
  }

  Widget _buildTeamCard(TeamModel team) {
    final primary = Colors.blue;

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
          onTap: () => _openTeamMembers(team),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                _InitialsAvatar(name: team.teamName, size: 52, radius: 16),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        team.teamName,
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
                          const Icon(Icons.workspace_premium_outlined,
                              size: 15, color: _kMuted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              team.teamHeadName ?? '-',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 13, color: _kMuted),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _Pill(
                        icon: Icons.people_alt_rounded,
                        text: '${team.memberCount} member(s)',
                        color: primary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Add member',
                  icon: const Icon(Icons.person_add_alt_rounded, size: 20),
                  onPressed: () => _openAddMemberDialog(team),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openAddMemberDialog(TeamModel team) async {
    _EmployeeOption? selected;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => _DialogShell(
          icon: Icons.person_add_alt_1_rounded,
          iconColor: Colors.white,
          title: 'Add member',
          subtitle: 'Add someone to ${team.teamName}.',
          content: _SearchableEmployeeDropdown(
            label: 'Employee',
            value: selected,
            options: _employeeOptions,
            onSelected: (value) {
              setDialogState(() {
                selected = value;
              });
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: _filledBtn(context),
              onPressed: () async {
                if (selected == null) return;
                try {
                  await ApiService.addOrgTeamMember(
                    teamId: team.teamId,
                    employeeId: selected!.id,
                  );
                  if (context.mounted) Navigator.pop(context);
                  _loadTeams();
                } catch (e) {
                  _showError('Could not add member: $e');
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openTeamMembers(TeamModel team) async {
    List<TeamMemberRecord> members = [];
    try {
      members = await ApiService.getOrgTeamMembers(team.teamId);
    } catch (e) {
      _showError('Could not load members: $e');
      return;
    }
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kBg,
      showDragHandle: false,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
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
                  _InitialsAvatar(name: team.teamName, size: SizeConfig.f(27), radius: 14),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          team.teamName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: _kInk,
                          ),
                        ),
                        Text(
                          '${members.length} member(s)',
                          style: const TextStyle(
                              fontSize: 13, color: _kMuted),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.close_rounded, color: _kInk),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (members.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: _EmptyState(
                    icon: Icons.person_search_outlined,
                    title: 'No members yet',
                    message:
                        'Use the add button on the team card to add people.',
                    compact: true,
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: members.length,
                    itemBuilder: (context, index) {
                      final m = members[index];
                      final displayName = m.employeeName ??
                          m.employeeCode ??
                          'Unknown Employee';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: _softShadow,
                        ),
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            dividerColor: Colors.transparent,
                          ),
                          child: ExpansionTile(
                            shape: const Border(),
                            collapsedShape: const Border(),
                            tilePadding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 2),
                            leading: _InitialsAvatar(
                                name: displayName, size: SizeConfig.f(33), radius: 21),
                            title: Text(
                              displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: _kInk,
                              ),
                            ),
                            subtitle: m.employeeCode != null
                                ? Text(
                                    'Code: ${m.employeeCode}',
                                    style: const TextStyle(
                                        fontSize: 12.5, color: _kMuted),
                                  )
                                : null,
                            trailing: _StatusDot(active: m.status),
                            childrenPadding:
                                const EdgeInsets.fromLTRB(14, 0, 14, 12),
                            children: [
                              const Divider(height: 1, color: _kLine),
                              const SizedBox(height: 12),
                              _InfoRow(
                                icon: Icons.calendar_today_rounded,
                                label: 'Effective From',
                                value: _formatDate(m.effeciveFrom),
                              ),
                              const SizedBox(height: 10),
                              _InfoRow(
                                icon: Icons.event_rounded,
                                label: 'Effective To',
                                value: _formatDate(m.effectiveTo),
                              ),
                              const SizedBox(height: 10),
                              _InfoRow(
                                icon: m.status
                                    ? Icons.check_circle_rounded
                                    : Icons.cancel_rounded,
                                iconColor: m.status ? _kGreen : _kRed,
                                label: 'Status',
                                value: m.status ? 'Active' : 'Inactive',
                              ),
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  style: TextButton.styleFrom(
                                    foregroundColor: _kRed,
                                    backgroundColor:
                                        _kRed.withOpacity(0.08),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.remove_circle_outline_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Remove Member'),
                                  onPressed: () async {
                                    final confirmed =
                                        await _showRemoveConfirmation(
                                      context,
                                      m.employeeName ??
                                          m.employeeCode ??
                                          'this member',
                                    );

                                    if (confirmed != true) return;

                                    try {
                                      await ApiService.removeTeamMember(
                                        m.teamMemberId,
                                      );
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                      }
                                      _loadTeams();
                                    } catch (e) {
                                      if (context.mounted) {
                                        _showError(
                                          'Could not remove member: $e',
                                        );
                                      }
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmployeeOption {
  final String id;
  final String name;
  final String code;
  _EmployeeOption({
    required this.id,
    required this.name,
    required this.code,
  });
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
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: const Color.fromARGB(255, 70, 120, 229).withOpacity(0.0),
      ),
    ),
  );
}

ButtonStyle _filledBtn(BuildContext context) => FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );

/// Consistent modern dialog frame.
class _DialogShell extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final Widget? content;
  final List<Widget> actions;

  const _DialogShell({
    required this.icon,
    required this.title,
    required this.actions,
    this.iconColor,
    this.subtitle,
    this.content,
  });

  @override
  Widget build(BuildContext context) {
    final boxColor = Colors.blue;
    // 👇 Honor iconColor; default to white for contrast on the blue box.
    final effectiveIconColor = iconColor ?? Colors.white;

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
              color: boxColor,
              borderRadius: BorderRadius.circular(14),
            ),
            // 👇 Was `color: color` (same as box) → invisible. Now uses override.
            child: Icon(icon, color: effectiveIconColor, size: 22),
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
      content: content == null
          ? null
          : SizedBox(width: 380, child: content),
      actions: actions,
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
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary, primary.withOpacity(0.72)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.30),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
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

  const _Pill({required this.icon, required this.text, required this.color});

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
          Icon(icon, size: 14, color: color),
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

class _StatusDot extends StatelessWidget {
  final bool active;
  const _StatusDot({required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? _kGreen : _kRed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        active ? 'Active' : 'Inactive',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor ?? _kMuted),
        const SizedBox(width: 10),
        Text(
          '$label:',
          style: const TextStyle(
            fontSize: 13.5,
            color: _kMuted,
          ),
        ),
        const SizedBox(width: 6),
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
    final primary = Colors.blue;
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

    if (compact) return Center(child: content);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: content,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final int count;

  const _SectionHeader({
    required this.title,
    required this.count,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Colors.blue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _kInk,
                ),
              ),
            ),
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
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: const TextStyle(fontSize: 12.5, color: _kMuted),
          ),
        ],
      ],
    );
  }
}

/// Searchable employee dropdown.
class _SearchableEmployeeDropdown extends StatelessWidget {
  final String label;
  final _EmployeeOption? value;
  final List<_EmployeeOption> options;
  final ValueChanged<_EmployeeOption?> onSelected;

  const _SearchableEmployeeDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double fieldWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 320;

        return DropdownMenu<_EmployeeOption>(
          width: fieldWidth,
          menuHeight: 280,
          label: Text(label),
          hintText: 'Search by name or code',
          leadingIcon: const Icon(Icons.search_rounded, size: 20),
          enableFilter: true,
          enableSearch: true,
          requestFocusOnTap: true,
          initialSelection: value,
          textStyle: const TextStyle(fontSize: 14.5, color: _kInk),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: _kBg,
            isDense: false,
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
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 1.5,
              ),
            ),
          ),
          menuStyle: MenuStyle(
            backgroundColor: const MaterialStatePropertyAll(Colors.white),
            surfaceTintColor:
                const MaterialStatePropertyAll(Colors.transparent),
            elevation: const MaterialStatePropertyAll(6),
            shadowColor: MaterialStatePropertyAll(
              const Color.fromARGB(255, 23, 45, 98).withOpacity(0.18),
            ),
            padding: const MaterialStatePropertyAll(
              EdgeInsets.symmetric(vertical: 6),
            ),
            minimumSize: MaterialStatePropertyAll(Size(fieldWidth, 0)),
            maximumSize: MaterialStatePropertyAll(
              Size(fieldWidth, double.infinity),
            ),
            shape: MaterialStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: _kLine),
              ),
            ),
          ),
          filterCallback: (entries, query) {
            final search = query.trim().toLowerCase();
            if (search.isEmpty) return entries;

            return entries.where((entry) {
              final employee = entry.value;
              if (employee == null) return false;
              final name = employee.name.toLowerCase();
              final code = employee.code.toLowerCase();
              return name.contains(search) || code.contains(search);
            }).toList();
          },
          dropdownMenuEntries: options
              .map(
                (employee) => DropdownMenuEntry<_EmployeeOption>(
                  value: employee,
                  label: '${employee.name} (${employee.code})',
                  leadingIcon: const Icon(Icons.person_outline_rounded,
                      size: 20),
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

// -----------------------------------------------------------------------------
// Reporting Hierarchy tab
// -----------------------------------------------------------------------------

class _ReportingHierarchyTab extends StatefulWidget {
  final String currentEmployeeId;
  final List<_EmployeeOption> employeeOptions;
  final void Function(String) onError;

  const _ReportingHierarchyTab({
    required this.currentEmployeeId,
    required this.employeeOptions,
    required this.onError,
  });

  @override
  State<_ReportingHierarchyTab> createState() =>
      _ReportingHierarchyTabState();
}

class _ReportingHierarchyTabState extends State<_ReportingHierarchyTab> {
  List<SubordinateModel> _directReports = [];
  List<SubordinateModel> _allSubordinates = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final direct =
          await ApiService.getDirectReports(widget.currentEmployeeId);
      final all =
          await ApiService.getAllSubordinates(widget.currentEmployeeId);
      setState(() {
        _directReports = direct;
        _allSubordinates = all;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      widget.onError('Could not load reporting hierarchy: $e');
    }
  }

  Future<void> _openSetManagerDialog() async {
    _EmployeeOption? employee;
    _EmployeeOption? manager;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => _DialogShell(
          icon: Icons.person,
          iconColor: Colors.white,
          title: 'Set Reporting Relationship',
          subtitle: 'Choose an employee and who they report to.',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SearchableEmployeeDropdown(
                label: 'Employee',
                value: employee,
                options: widget.employeeOptions,
                onSelected: (value) {
                  setDialogState(() {
                    employee = value;
                  });
                },
              ),
              const SizedBox(height: 14),
              _SearchableEmployeeDropdown(
                label: 'Reports To',
                value: manager,
                options: widget.employeeOptions,
                onSelected: (value) {
                  setDialogState(() {
                    manager = value;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: _filledBtn(context),
              onPressed: () async {
                if (employee == null || manager == null) return;
                try {
                  await ApiService.setReportingRelationship(
                    employeeId: employee!.id,
                    reportingToEmployeeId: manager!.id,
                  );
                  if (context.mounted) Navigator.pop(context);
                  _load();
                } catch (e) {
                  widget.onError('Could not set relationship: $e');
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSubordinateHierarchy() {
    final Map<String, List<SubordinateModel>> childrenByManager = {};

    for (final employee in _allSubordinates) {
      final managerId = employee.directManagerId.trim().toLowerCase();
      if (managerId.isEmpty) continue;
      childrenByManager.putIfAbsent(managerId, () => []);
      childrenByManager[managerId]!.add(employee);
    }

    final List<Widget> widgets = [];
    final Set<String> renderedEmployeeIds = {};

    void addEmployeeTree(SubordinateModel employee, int indentLevel) {
      final employeeId = employee.employeeId.trim().toLowerCase();

      if (employeeId.isNotEmpty && renderedEmployeeIds.contains(employeeId)) {
        return;
      }
      if (employeeId.isNotEmpty) renderedEmployeeIds.add(employeeId);

      widgets.add(_buildHierarchyTile(employee, indentLevel: indentLevel));

      final children =
          childrenByManager[employeeId] ?? const <SubordinateModel>[];
      for (final child in children) {
        addEmployeeTree(child, indentLevel + 1);
      }
    }

    for (final directReport in _directReports) {
      addEmployeeTree(directReport, 0);
    }

    for (final employee in _allSubordinates) {
      final employeeId = employee.employeeId.trim().toLowerCase();
      if (employeeId.isEmpty || renderedEmployeeIds.contains(employeeId)) {
        continue;
      }
      addEmployeeTree(
        employee,
        employee.depth > 0 ? employee.depth - 1 : 0,
      );
    }

    return widgets;
  }

  Widget _buildHierarchyTile(
    SubordinateModel employee, {
    required int indentLevel,
  }) {
    final primary = Colors.blue;
    final isRoot = indentLevel == 0;
    final double indent = (indentLevel > 6 ? 6 : indentLevel) * 20.0;

    return Padding(
      padding: EdgeInsets.only(left: indent, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (!isRoot) ...[
            Container(
              width: 14,
              height: 2,
              decoration: BoxDecoration(
                color: primary.withOpacity(0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border(
                  left: BorderSide(
                    color: isRoot ? primary : primary.withOpacity(0.35),
                    width: 3,
                  ),
                ),
                boxShadow: _softShadow,
              ),
              child: Row(
                children: [
                  _InitialsAvatar(
                    name: employee.employeeName,
                    size: SizeConfig.f(33),
                    radius: 19,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          employee.employeeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: _kInk,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          employee.employeeCode,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12.5, color: _kMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'L${employee.depth}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: primary,
                      ),
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

  Widget _buildActionCard() {
    final primary = Colors.blue;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary, primary.withOpacity(0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.30),
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
                const Text(
                  'Reporting lines',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_directReports.length} direct  •  ${_allSubordinates.length} total under you',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: _openSetManagerDialog,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: primary,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: const Text('Set'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _buildActionCard(),
          const SizedBox(height: 24),
          _SectionHeader(
            title: 'Your Direct Reports',
            count: _directReports.length,
          ),
          const SizedBox(height: 12),
          if (_directReports.isEmpty)
            const _EmptyState(
              icon: Icons.person_outline_rounded,
              title: 'No direct reports',
              message: 'Nobody reports to you yet.',
              compact: true,
            )
          else
            ..._directReports.map(
              (s) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: _softShadow,
                ),
                child: Row(
                  children: [
                    _InitialsAvatar(
                        name: s.employeeName, size: SizeConfig.f(33), radius: 19),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.employeeName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: _kInk,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            s.employeeCode,
                            style: const TextStyle(
                                fontSize: 12.5, color: _kMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 24),
          _SectionHeader(
            title: 'Everyone Under You',
            count: _allSubordinates.length,
            subtitle:
                'Includes indirect reports — e.g. your Team Heads\' own team members.',
          ),
          const SizedBox(height: 12),
          if (_allSubordinates.isEmpty)
            const _EmptyState(
              icon: Icons.account_tree_outlined,
              title: 'Nothing to show',
              message: 'No one is in your reporting tree yet.',
              compact: true,
            )
          else
            ..._buildSubordinateHierarchy(),
        ],
      ),
    );
  }
}