import 'package:attendance_app/assigntask.dart';
import 'package:attendance_app/pendingApproval.dart';
import 'package:attendance_app/teamscreen.dart';
import 'package:attendance_app/teamtask.dart';
import 'package:attendance_app/widgets/SizeConfig.dart';
import 'package:flutter/material.dart';

const Color _kBg = Color(0xFFF5F6FA);
const Color _kInk = Color(0xFF1F2430);
const Color _kMuted = Color(0xFF7A8194);

class _PanelItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _PanelItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class ManagerPanel extends StatelessWidget {
  const ManagerPanel({super.key});

  void _go(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    // Cards per row: 2 on phones, 3 on small tablets, 4 on large screens.
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 900 ? 5 : (width >= 600 ? 3 : 3);

    final items = <_PanelItem>[
      _PanelItem(
        title: 'Pending Approvals',
        subtitle: 'Leave & requests',
        icon: Icons.approval_rounded,
        color: const Color(0xFF2F86A6),
        onTap: () => _go(context, PendingApprovalScreen()),
      ),
      _PanelItem(
        title: 'Assign Task',
        subtitle: 'Create & delegate',
        icon: Icons.assignment_add,
        color: const Color(0xFFD9733F),
        onTap: () => _go(context, AssignTaskScreen()),
      ),
      _PanelItem(
        title: 'Team Tasks',
        subtitle: 'Track progress',
        icon: Icons.task_alt_rounded,
        color: const Color(0xFF4F9A5B),
        onTap: () => _go(context, TeamTasksScreen()),
      ),
      _PanelItem(
        title: 'My Team',
        subtitle: 'View your people',
        icon: Icons.people_alt_rounded,
        color: const Color(0xFF7B5CC9),
        onTap: () => _go(context, MyTeamScreen()),
      ),
    ];

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: Text(
          'Manager Panel',
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
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Text(
                'Quick Actions',
                style: TextStyle(
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
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                mainAxisExtent: 148,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) => _buildManagerCard(items[i]),
                childCount: items.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildManagerCard(_PanelItem item) {
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
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: item.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(item.icon, color: item.color, size: 26),
                    ),
                    Icon(
                      Icons.arrow_outward_rounded,
                      size: 18,
                      color: _kMuted.withOpacity(0.7),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: _kInk,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: _kMuted),
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
                  'Manage your team',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Approve requests, assign work and keep track of your team.',
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
              Icons.supervisor_account_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }
}