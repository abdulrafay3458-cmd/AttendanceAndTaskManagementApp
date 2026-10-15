import 'package:attendance_app/addemployee.dart';
// import 'package:attendance_app/assigntask.dart';
import 'package:attendance_app/services/apiservice.dart';
import 'package:attendance_app/services/teammember.dart';
import 'package:attendance_app/widgets/SizeConfig.dart';
import 'package:flutter/material.dart';

const _kBg = Color(0xFFF5F6FA);
const _kInk = Color(0xFF1F2430);
const _kMuted = Color(0xFF7A8194);
const _kLine = Color(0xFFE6E8F0);
const _kGreen = Color(0xFF22A06B);
const _kRed = Color(0xFFE5484D);

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

class MyTeamScreen extends StatefulWidget {
  const MyTeamScreen({super.key});

  @override
  _MyTeamScreenState createState() => _MyTeamScreenState();
}

class _MyTeamScreenState extends State<MyTeamScreen> {
  List<TeamMember> _teamMembers = [];
  List<TeamMember> _filteredMembers = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  // Role GUID (lowercase) -> Role name
  Map<String, String> _roleIdToName = {};

  List<String> get role {
    final roles = ApiService.currentEmployee?.role ?? [];
    return roles.map((r) => r.toString().toLowerCase()).toList();
  }

  bool get _isAdmin => role.contains('admin');
  bool get _isManager => role.contains('manager');

  @override
  void initState() {
    super.initState();
    _loadRoleLookup();
    _loadTeamMembers();
    _searchController.addListener(_filterTeamMembers);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRoleLookup() async {
    try {
      final roles = await ApiService.getUserRoles();
      if (!mounted) return;
      setState(() {
        _roleIdToName = {
          for (final r in roles) r.id.toLowerCase(): r.name,
        };
      });
    } catch (e) {
      debugPrint('Failed to load role lookup: $e');
    }
  }

  /// Parses a comma-separated list of role GUIDs and returns role names.
  List<String> _resolveRoleNames(String? roleIdCsv) {
    if (roleIdCsv == null || roleIdCsv.trim().isEmpty) return [];
    return roleIdCsv
        .split(',')
        .map((s) => s.trim().toLowerCase())
        .where((id) => id.isNotEmpty)
        .map((id) => _roleIdToName[id] ?? id)
        .toList();
  }

  Future<void> _loadTeamMembers() async {
    if (!mounted) return;

    setState(() => _isLoading = true);
    final managerId = ApiService.empGuid;

    if (managerId != null) {
      try {
        await Future.delayed(const Duration(milliseconds: 500));

        final data = await ApiService.getTeamMembers(managerId);

        // Deduplicate by employeeId (keep first occurrence)
        final Map<String, TeamMember> uniqueById = {};
        for (final member in data) {
          final key = member.employeeId.trim().toLowerCase();
          final existing = uniqueById[key];
          if (existing == null) {
            uniqueById[key] = member;
          } else {
            // Merge roleId CSV if backend returns one row per role
            final mergedRoleId = _mergeCsv(existing.roleId, member.roleId);
            final mergedRole = _mergeCsv(existing.role, member.role);
            uniqueById[key] = existing.copyWith(
              roleId: mergedRoleId,
              role: mergedRole,
            );
          }
        }
        final uniqueMembers = uniqueById.values.toList();

        if (mounted) {
          setState(() {
            _teamMembers = uniqueMembers;
            _isLoading = false;
          });
          _filterTeamMembers();
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showSnack('Failed to load team members: $e', isError: true);
        }
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Merge two comma-separated strings into a unique CSV.
  String _mergeCsv(String? a, String? b) {
    final set = <String>{};
    void addAll(String? s) {
      if (s == null) return;
      for (final part in s.split(',')) {
        final t = part.trim();
        if (t.isNotEmpty) set.add(t);
      }
    }

    addAll(a);
    addAll(b);
    return set.join(',');
  }

  void _filterTeamMembers() {
    final query = _searchController.text.toLowerCase().trim();

    setState(() {
      if (query.isEmpty) {
        _filteredMembers = List.from(_teamMembers);
      } else {
        _filteredMembers = _teamMembers.where((member) {
          final roleNames =
              _resolveRoleNames(member.roleId).join(' ').toLowerCase();
          return member.name.toLowerCase().contains(query) ||
              member.employeeId.toLowerCase().contains(query) ||
              member.email.toLowerCase().contains(query) ||
              member.department.toLowerCase().contains(query) ||
              roleNames.contains(query);
        }).toList();
      }
    });
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? _kRed : _kGreen,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Text(
            message,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      );
  }

  Future<void> _openAddEmployee() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEmployee(
          isEditing: false,
          onEmployeeUpdated: () {
            _loadTeamMembers();
          },
        ),
      ),
    );

    if (result == true) {
      await _loadTeamMembers();
    }
  }

  Future<void> _openEditEmployee(TeamMember member) async {
    final nameParts = member.name.trim().split(" ");
    final firstName = nameParts.isNotEmpty ? nameParts[0] : "";
    final lastName =
        nameParts.length > 1 ? nameParts.sublist(1).join(" ") : "";

    final employeeData = {
      'employeeId': member.employeeId,
      'zkUserId': member.machineId,
      'firstName': firstName,
      'lastName': lastName,
      'email': member.email,
      'phone': member.phone,
      'department': member.department,
      'designationName': member.designation,
      'designationCode': member.designationCode,
      'companyCode': member.companyCode,
      'standardHourCode': member.standardHourCode,
      'leadCode': member.leadCode,
      'leadId': member.leadId,
      'joinDate': member.joinDate,
      'isActive': member.isActive,
      'isAppUser': member.isAppUser,
      'roleId': member.roleId,
      'role': member.role,
    };

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEmployee(
          isEditing: true,
          employeeData: employeeData,
          onEmployeeUpdated: () {
            _loadTeamMembers();
          },
        ),
      ),
    );

    if (result == true) {
      await _loadTeamMembers();
    }
  }

  // ---------------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: Text(
          'Employees',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color.fromARGB(255, 12, 86, 147),
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadTeamMembers,
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _kLine),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadTeamMembers,
              child: _buildList(),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddEmployee,
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text(
          'Add',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildList() {
    final hasQuery = _searchController.text.trim().isNotEmpty;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        _buildBanner(),
        const SizedBox(height: 14),
        _buildSearchField(),
        const SizedBox(height: 16),
        if (_filteredMembers.isEmpty)
          _EmptyState(
            icon: hasQuery
                ? Icons.search_off_rounded
                : Icons.groups_2_outlined,
            title: hasQuery
                ? 'No results found'
                : 'No team members found',
            subtitle: hasQuery
                ? 'Nothing matches "${_searchController.text.trim()}".'
                : 'Tap Add to create your first team member.',
            actionLabel: hasQuery ? 'Clear search' : null,
            onAction: hasQuery ? _searchController.clear : null,
          )
        else
          ..._filteredMembers.map(_buildTeamMemberCard),
      ],
    );
  }

  // --------------------------------------------------------------- banner
  Widget _buildBanner() {
    final active = _teamMembers.where((m) => m.isActive == true).length;
    final departments = _teamMembers
        .map((m) => m.department.trim())
        .where((d) => d.isNotEmpty)
        .toSet()
        .length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: _bannerGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _baseColor.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _BannerStat(
            icon: Icons.groups_rounded,
            value: '${_teamMembers.length}',
            label: 'Members',
          ),
          _vDivider(),
          _BannerStat(
            icon: Icons.verified_user_outlined,
            value: '$active',
            label: 'Active',
          ),
          _vDivider(),
          _BannerStat(
            icon: Icons.apartment_rounded,
            value: '$departments',
            label: 'Departments',
          ),
        ],
      ),
    );
  }

  Widget _vDivider() => Container(
        width: 1,
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        color: Colors.white.withOpacity(0.25),
      );

  // --------------------------------------------------------------- search
  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _softShadow,
      ),
      child: TextField(
        controller: _searchController,
        cursorColor: Colors.blue[700],
        style: const TextStyle(color: _kInk, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: 'Search name, ID, email, department or role',
          hintStyle: TextStyle(
            color: _kMuted.withOpacity(0.7),
            fontSize: 13.5,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(Icons.search_rounded, color: Colors.blue[700]),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, color: _kMuted),
                  onPressed: _searchController.clear,
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  // ----------------------------------------------------------------- card
  Widget _buildTeamMemberCard(TeamMember member) {
    final roleNames = _resolveRoleNames(member.roleId);
    final canAct = _isAdmin || _isManager;
    final avatarSize = SizeConfig.f(52);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: _softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InitialsAvatar(name: member.name, size: avatarSize),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: _kInk,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      member.designation,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: _kMuted),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _Pill(
                          text: member.employeeCode,
                          icon: Icons.badge_outlined,
                          color: Colors.blue,
                        ),
                        if (member.isActive == true)
                          const _Pill(text: 'Active', color: _kGreen)
                        else if (member.isActive == false)
                          const _Pill(text: 'Inactive', color: _kRed),
                      ],
                    ),
                  ],
                ),
              ),
              if (canAct)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: _kMuted),
                  color: Colors.white,
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  onSelected: (value) {
                    if (value == 'Edit') {
                      _openEditEmployee(member);
                    }
                  },
                  itemBuilder: (context) => [
                    if (_isAdmin)
                      const PopupMenuItem(
                        value: 'Edit',
                        child: _MenuRow(
                          icon: Icons.edit_outlined,
                          label: 'Edit',
                        ),
                      ),
                    // if (_isManager)
                    //   const PopupMenuItem(
                    //     value: 'assign_task',
                    //     child: _MenuRow(
                    //       icon: Icons.assignment_add,
                    //       label: 'Assign Task',
                    //     ),
                    //   ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kLine),
            ),
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.business_outlined,
                  text: member.department,
                ),
                const SizedBox(height: 8),
                _InfoRow(icon: Icons.email_outlined, text: member.email),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// Small widgets
// ====================================================================

class _InitialsAvatar extends StatelessWidget {
  final String name;
  final double size;

  const _InitialsAvatar({required this.name, required this.size});

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+'));
    var initials = '?';
    if (name.trim().isNotEmpty) {
      initials = parts.first[0];
      if (parts.length > 1) initials += parts.last[0];
    }

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: _bannerGradient,
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Text(
        initials.toUpperCase(),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.36,
        ),
      ),
    );
  }
}

class _BannerStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _BannerStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color color;

  const _Pill({required this.text, required this.color, this.icon});

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
            Icon(icon, size: 13, color: color),
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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: Colors.blue[700]),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text.isEmpty ? '-' : text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              color: _kInk,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MenuRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.blue[700]),
        const SizedBox(width: 10),
        Text(
          label,
          style: const TextStyle(
            color: _kInk,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
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
            const SizedBox(height: 14),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(foregroundColor: Colors.blue[700]),
              child: Text(
                actionLabel!,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }
}