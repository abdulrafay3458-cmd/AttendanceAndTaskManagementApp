import 'package:attendance_app/AdminDeviceManagementScreen.dart';
import 'package:attendance_app/UserDeviceRequestAdminScreen.dart';
import 'package:attendance_app/HolidaySetup.dart';
import 'package:attendance_app/applyprofiledialogue.dart';
import 'package:attendance_app/clientscreen.dart';
import 'package:attendance_app/devicescreen.dart';
import 'package:attendance_app/project_management_screen.dart';
import 'package:attendance_app/services/apiservice.dart';
import 'package:attendance_app/task_approval_screen.dart';
import 'package:attendance_app/team_head_task_screen.dart';
import 'package:attendance_app/team_management_screen.dart';
import 'package:attendance_app/teamscreen.dart';
import 'package:attendance_app/widgets/SizeConfig.dart';
import 'package:flutter/material.dart';

const Color _kBg = Color(0xFFF5F6FA);
const Color _kInk = Color(0xFF1F2430);
const Color _kMuted = Color(0xFF7A8194);

class _AdminItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _AdminItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class _AdminSection {
  final String title;
  final List<_AdminItem> items;
  const _AdminSection(this.title, this.items);
}

class Adminscreen extends StatelessWidget {
  final String companyId;
  final String currentEmployeeId;
  final String currentEmployeeCode;

  const Adminscreen({
    super.key,
    required this.companyId,
    required this.currentEmployeeId,
    required this.currentEmployeeCode,
  });

  void _go(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final resolvedCompanyId = ApiService.companyId ?? '';
    final resolvedEmployeeId = ApiService.empGuid ?? '';
    final resolvedEmployeeCode = ApiService.employeeId ?? '';

    final sections = <_AdminSection>[
      // Cards Data
      _AdminSection('People & Teams', [
        _AdminItem(
          title: 'Employees',
          subtitle: 'View and manage staff',
          icon: Icons.people_alt_rounded,
          color: const Color(0xFF2F8F83),
          onTap: () => _go(context, MyTeamScreen()),
        ),
        _AdminItem(
          title: 'Team Hierarchy',
          subtitle: 'Teams & reporting lines',
          icon: Icons.account_tree_rounded,
          color: const Color(0xFF8B4FC9),
          onTap: () => _go(
            context,
            TeamManagementScreen(
              companyId: resolvedCompanyId,
              currentEmployeeId: resolvedEmployeeId,
              currentEmployeeCode: resolvedEmployeeCode,
            ),
          ),
        ),
        _AdminItem(
          title: 'Client Setup',
          subtitle: 'Manage client records',
          icon: Icons.business_center_rounded,
          color: const Color(0xFFC77D2E),
          onTap: () => _go(context, Clientscreen()),
        ),
      ]),
      _AdminSection('Devices', [
        _AdminItem(
          title: 'Device Approval',
          subtitle: 'Review user requests',
          icon: Icons.mobile_friendly_rounded,
          color: const Color(0xFF145E5A),
          onTap: () => _go(context, AdminDeviceRequestsScreen()),
        ),
        _AdminItem(
          title: 'User Devices',
          subtitle: 'Registered phones',
          icon: Icons.smartphone_rounded,
          color: const Color(0xFF9A8A12),
          onTap: () => _go(context, AdminDeviceManagementScreen()),
        ),
        _AdminItem(
          title: 'Devices',
          subtitle: 'Attendance devices',
          icon: Icons.devices_rounded,
          color: const Color(0xFF3F6FB5),
          onTap: () => _go(context, DeviceScreen()),
        ),
      ]),
      _AdminSection('Approvals & Setup', [
        _AdminItem(
          title: 'Projects',
          subtitle: 'Create & assign teams',
          icon: Icons.work_outline_rounded,
          color: const Color(0xFF4F9A5B),
          onTap: () => _go(
            context,
            ProjectManagementScreen(
              companyId: resolvedCompanyId,
              currentEmployeeId: resolvedEmployeeId,
            ),
          ),
        ),
        _AdminItem(
          title: 'My Team Tasks',
          subtitle: 'Projects & tasks for your team',
          icon: Icons.assignment_ind_rounded,
          color: const Color(0xFF4F9A5B),
          onTap: () async {
            // TeamHeadTaskScreen needs a specific teamId, not just the employee —
            // resolve which team this employee heads first.
            final myTeams = await ApiService.getTeamsHeadedBy(resolvedCompanyId, resolvedEmployeeId);
            if (myTeams.isEmpty) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('You are not set as a Team Head for any team.')),
                );
              }
              return;
            }
            if (context.mounted) {
              _go(
                context,
                TeamHeadTaskScreen(
                  teamHeadEmployeeId: resolvedEmployeeId,
                  teamId: myTeams.first['teamId'], // if an employee can head >1 team, add a picker here
                ),
              );
            }
          },
        ),
        _AdminItem(
          title: 'Task Approvals',
          subtitle: 'Approve or reject requests',
          icon: Icons.fact_check_rounded,
          color: const Color(0xFF4F9A5B),
          onTap: () => _go(context, TaskApprovalScreen(approverEmployeeId: resolvedEmployeeId)),
        ),
      ]),
    ];

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: Text(
          'Admin Panel',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: SizeConfig.f(20),
            color: Colors.blue[700],
          ),
        ),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: _HeaderBanner()),
          for (final section in sections) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Text(
                  section.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _kInk,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  mainAxisExtent: 130,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _buildManagerCard(section.items[i]),
                  childCount: section.items.length,
                ),
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _buildManagerCard(_AdminItem item) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F2430).withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: item.onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 35,
                      height: 35,
                      decoration: BoxDecoration(
                        color: item.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(item.icon, color: item.color, size: 18),
                    ),
                    Icon(
                      Icons.arrow_outward_rounded,
                      size: 11,
                      color: _kMuted.withOpacity(0.7),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  item.title,
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.clip,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _kInk,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 9.5, color: _kMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderBanner extends StatelessWidget {
  const _HeaderBanner();

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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'System Setup',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Manage people, devices and approvals from one place.',
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
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }
}