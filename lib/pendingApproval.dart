import 'package:attendance_app/overtimescreen.dart';
import 'package:attendance_app/pendingcancelleaveapproval.dart';
import 'package:attendance_app/pendingleaveapproval.dart';
import 'package:attendance_app/widgets/SizeConfig.dart';
import 'package:flutter/material.dart';

const Color _kBg = Color(0xFFF5F6FA);
const Color _kInk = Color(0xFF1F2430);
const Color _kMuted = Color(0xFF7A8194);

class _ApprovalItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ApprovalItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class PendingApprovalScreen extends StatelessWidget {
  const PendingApprovalScreen({super.key});

  void _go(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    // Cards per row: 2 on phones, 3 on small tablets, 4 on large screens.
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 900 ? 4 : (width >= 600 ? 3 : 2);

    final items = <_ApprovalItem>[
      _ApprovalItem(
        title: 'Leave Approvals',
        subtitle: 'Pending leave requests',
        icon: Icons.pending_actions_rounded,
        color: const Color(0xFFD1496A),
        onTap: () => _go(context, PendingLeaveApprovalsScreen()),
      ),
      _ApprovalItem(
        title: 'Cancel Leave',
        subtitle: 'Cancellation requests',
        icon: Icons.event_busy_rounded,
        color: const Color(0xFF2F8F83),
        onTap: () => _go(context, PendingCancelLeaveApprovalsScreen()),
      ),
      // _ApprovalItem(
      //   title: 'Overtime',
      //   subtitle: 'Overtime approvals',
      //   icon: Icons.timelapse_rounded,
      //   color: const Color(0xFF8B4FC9),
      //   onTap: () => _go(context, OverTimeScreen()),
      // ),
    ];

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Pending Approvals',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color.fromARGB(255, 12, 86, 147),
      ),
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 9, 20, 4),
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
                (context, i) => _buildCard(items[i]),
                childCount: items.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildCard(_ApprovalItem item) {
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