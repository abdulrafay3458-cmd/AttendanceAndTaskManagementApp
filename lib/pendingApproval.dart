import 'package:attendance_app/overtimescreen.dart';
import 'package:attendance_app/pendingcancelleaveapproval.dart';
import 'package:attendance_app/pendingleaveapproval.dart';
import 'package:flutter/material.dart';

class PendingApprovalScreen extends StatelessWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Pending Approval',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue[700],
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildCard(
              context,
              'Pending Leaves Approvals',
              Icons.pending_actions,
              const Color.fromARGB(255, 245, 215, 220),
              const Color.fromARGB(255, 120, 80, 95),
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PendingLeaveApprovalsScreen(),
                  ),
                );
              },
            ),
            _buildCard(
              context,
              'Cancel Leave Approvals',
              Icons.cancel,
              const Color.fromARGB(255, 190, 230, 225),
              const Color.fromARGB(255, 60, 105, 110),
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => PendingCancelLeaveApprovalsScreen()),
                );
              },
            ),
            _buildCard(
              context,
              'Overtime Approvals',
              Icons.timelapse_rounded,
              const Color.fromARGB(255, 216, 190, 230),
              const Color.fromARGB(255, 110, 60, 109),
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => OverTimeScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    Color foreColor,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color, color.withOpacity(0.7)],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: foreColor),
              SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: foreColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
