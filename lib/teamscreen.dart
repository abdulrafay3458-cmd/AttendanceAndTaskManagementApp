import 'package:attendance_app/addemployee.dart';
import 'package:attendance_app/assigntask.dart';
import 'package:attendance_app/services/apiservice.dart';
import 'package:attendance_app/services/teammember.dart';
import 'package:attendance_app/widgets/SizeConfig.dart';
import 'package:flutter/material.dart';

class MyTeamScreen extends StatefulWidget {
  const MyTeamScreen({super.key});

  @override
  _MyTeamScreenState createState() => _MyTeamScreenState();
}

class _MyTeamScreenState extends State<MyTeamScreen> {
  List<TeamMember> _teamMembers = [];
  List<TeamMember> _filteredMembers = [];
  bool _isLoading = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  // Role GUID (lowercase) -> Role name
  Map<String, String> _roleIdToName = {};

  List<String> get role {
    final roles = ApiService.currentEmployee?.role ?? [];
    return roles.map((r) => r.toString().toLowerCase()).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadRoleLookup();
    _loadTeamMembers();

    _searchController.addListener(() {
      _filterTeamMembers();
    });
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
    final managerId = ApiService.employeeId;

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
            _filteredMembers = List.from(_teamMembers);
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load team members: $e')),
          );
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

    if (query.isEmpty) {
      setState(() {
        _filteredMembers = List.from(_teamMembers);
      });
    } else {
      setState(() {
        _filteredMembers = _teamMembers.where((member) {
          final roleNames = _resolveRoleNames(member.roleId).join(' ').toLowerCase();
          return member.name.toLowerCase().contains(query) ||
              member.employeeId.toLowerCase().contains(query) ||
              member.email.toLowerCase().contains(query) ||
              member.department.toLowerCase().contains(query) ||
              roleNames.contains(query);
        }).toList();
      });
    }
  }

  void _startSearch() {
    setState(() {
      _isSearching = true;
    });
  }

  void _stopSearch() {
    setState(() {
      _isSearching = false;
      _searchController.clear();
      _filteredMembers = List.from(_teamMembers);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isSearching ? _buildSearchAppBar() : _buildNormalAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredMembers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _searchController.text.isNotEmpty
                            ? Icons.search_off
                            : Icons.people_outline,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchController.text.isNotEmpty
                            ? 'No results found for "${_searchController.text}"'
                            : 'No team members found',
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      if (_searchController.text.isNotEmpty)
                        TextButton(
                          onPressed: _stopSearch,
                          child: const Text('Clear Search'),
                        ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadTeamMembers,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredMembers.length,
                    itemBuilder: (context, index) {
                      final member = _filteredMembers[index];
                      return _buildTeamMemberCard(member);
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
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
        },
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
        child: const Icon(Icons.add),
      ),
    );
  }

  AppBar _buildNormalAppBar() {
    return AppBar(
      title: const Text('My Team', style: TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: Colors.white,
      foregroundColor: Colors.blue[700],
      actions: [
        IconButton(icon: const Icon(Icons.search), onPressed: _startSearch),
        IconButton(icon: const Icon(Icons.refresh), onPressed: _loadTeamMembers),
      ],
    );
  }

  AppBar _buildSearchAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: Colors.blue[700],
      leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _stopSearch),
      title: TextField(
        controller: _searchController,
        autofocus: true,
        style: TextStyle(color: Colors.blue[700]),
        decoration: InputDecoration(
          hintText: 'Search employees...',
          hintStyle: TextStyle(color: Colors.blue[700]),
          border: InputBorder.none,
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
              : null,
        ),
        cursorColor: Colors.blue[700],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () {
            _filterTeamMembers();
          },
        ),
      ],
    );
  }

  Widget _buildTeamMemberCard(TeamMember member) {
    final roleNames = _resolveRoleNames(member.roleId);

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Colors.blue[100],
          radius: 28,
          child: Text(
            member.name.isNotEmpty
                ? member.name.substring(0, 1).toUpperCase()
                : '?',
            style: TextStyle(
              color: Colors.blue[700],
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
        title: Text(
          member.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.badge, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  member.employeeId,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.work, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  member.designation,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.business, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  member.department,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.email, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    member.email,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          color: Colors.blue.shade50,
          onSelected: (value) async {
            if (value == 'assign_task') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      AssignTaskScreen(empCode: member.employeeId),
                ),
              );
            } else if (value == 'Edit') {
              final nameParts = member.name.trim().split(" ");
              final firstName = nameParts.isNotEmpty ? nameParts[0] : "";
              final lastName = nameParts.length > 1
                  ? nameParts.sublist(1).join(" ")
                  : "";

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
          },
          itemBuilder: (context) => [
            if (role.contains('admin'))
              const PopupMenuItem(
                value: 'Edit',
                child: Row(
                  children: [
                    Icon(
                      Icons.create_sharp,
                      size: 20,
                      color: Colors.blue,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Edit',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ],
                ),
              ),
            if (role.contains('manager'))
              const PopupMenuItem(
                value: 'assign_task',
                child: Row(
                  children: [
                    Icon(
                      Icons.assignment_add,
                      size: 20,
                      color: Colors.blue,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Assign Task',
                      style: TextStyle(color: Colors.blue),
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