import 'package:attendance_app/absentemployee.dart';
import 'package:attendance_app/checkinreport.dart';
import 'package:attendance_app/dailyreport.dart';
import 'package:attendance_app/employee_task_summary_page.dart';
import 'package:attendance_app/employeereport.dart';
import 'package:attendance_app/lateemployee.dart';
import 'package:attendance_app/models/employee.dart';
import 'package:attendance_app/services/apiservice.dart';
import 'package:flutter/material.dart';

const Color _kBg = Color(0xFFF5F6FA);
const Color _kInk = Color(0xFF1F2430);
const Color _kMuted = Color(0xFF7A8194);

class _ReportItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ReportItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  _ReportsScreenState createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  Employee? get employee => ApiService.currentEmployee;

  void _go(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final roles = employee?.role.map((r) => r.toLowerCase()).toList() ?? [];
    final isManager = roles.contains('manager');

    // Cards per row: 2 on phones, 3 on small tablets, 4 on large screens.
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 900 ? 5 : (width >= 600 ? 3 : 3);

    final myReports = <_ReportItem>[
      _ReportItem(
        title: 'Attendance',
        subtitle: 'Your attendance report',
        icon: Icons.document_scanner_rounded,
        color: const Color(0xFF4F9A5B),
        onTap: () => _go(Employeereport()),
      ),
    ];

    final teamReports = <_ReportItem>[
      _ReportItem(
        title: 'Team Attendance',
        subtitle: 'Daily team overview',
        icon: Icons.groups_rounded,
        color: const Color(0xFF2F86A6),
        onTap: () => _go(DailyReportScreen()),
      ),
      _ReportItem(
        title: 'Late Employees',
        subtitle: 'Late arrivals',
        icon: Icons.alarm_rounded,
        color: const Color(0xFFD9733F),
        onTap: () => _go(LateEmployeesScreen()),
      ),
      _ReportItem(
        title: 'Absent Employees',
        subtitle: 'Who is not in today',
        icon: Icons.person_off_rounded,
        color: const Color(0xFF3F6FB5),
        onTap: () => _go(AbsentEmployeesScreen()),
      ),
      _ReportItem(
        title: 'Check In/Out',
        subtitle: 'Punch time records',
        icon: Icons.lock_clock_rounded,
        color: const Color(0xFF9A8A12),
        onTap: () => _go(CheckinReportScreen()),
      ),
      _ReportItem(
        title: 'Task Report',
        subtitle: 'Task summary by employee',
        icon: Icons.work_history_rounded,
        color: const Color(0xFF7B5CC9),
        onTap: () => _go(EmployeeTaskSummaryPage()),
      ),
    ];

    final sections = <MapEntry<String, List<_ReportItem>>>[
      MapEntry('My Reports', myReports),
      if (isManager) MapEntry('Team Reports', teamReports),
    ];

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: Text(
          'Reports',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color.fromARGB(255, 12, 86, 147),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _HeaderBanner(isManager: isManager)),
          for (final section in sections) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Text(
                  section.key,
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
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  mainAxisExtent: 148,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) => _buildReportCard(section.value[i]),
                  childCount: section.value.length,
                ),
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildReportCard(_ReportItem item) {
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
  final bool isManager;
  const _HeaderBanner({required this.isManager});

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
                  'Insights & Reports',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isManager
                      ? 'Track attendance, lateness, absences and tasks across your team.'
                      : 'Review your attendance records.',
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
              Icons.insights_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }
}