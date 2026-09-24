import 'package:attendance_app/assigntask.dart';
import 'package:attendance_app/pendingApproval.dart';
import 'package:attendance_app/teamscreen.dart';
import 'package:attendance_app/teamtask.dart';
import 'package:flutter/material.dart';

class ManagerPanel extends StatelessWidget {
  const ManagerPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Manager Panel',
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
            _buildManagerCard(
              context,
              'Pending Approvals',
              Icons.approval,
              Color.fromARGB(255, 160, 215, 235),
              Color.fromARGB(255, 55, 105, 125),
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PendingApprovalScreen(),
                  ),
                );
              },
            ),

            _buildManagerCard(
              context,
              'Assign Task',
              Icons.assignment_add,
              Color.fromARGB(255, 240, 185, 160),
              Color.fromARGB(255, 120, 85, 70),
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AssignTaskScreen()),
                );
              },
            ),
            _buildManagerCard(
              context,
              'Team Tasks',
              Icons.task_alt,
              Color.fromARGB(255, 205, 230, 195),
              Color.fromARGB(255, 85, 120, 75),
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => TeamTasksScreen()),
                );
              },
            ),
            _buildManagerCard(
              context,
              'My Team',
              Icons.people,
              Color.fromARGB(255, 225, 215, 240),
              Color.fromARGB(255, 95, 80, 125),
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => MyTeamScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManagerCard(
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
