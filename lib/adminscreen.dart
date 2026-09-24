import 'package:attendance_app/AdminDeviceManagementScreen.dart';
import 'package:attendance_app/UserDeviceRequestAdminScreen.dart';
import 'package:attendance_app/HolidaySetup.dart';
import 'package:attendance_app/applyprofiledialogue.dart';
import 'package:attendance_app/clientscreen.dart';
import 'package:attendance_app/devicescreen.dart';
import 'package:attendance_app/teamscreen.dart';
import 'package:attendance_app/widgets/SizeConfig.dart';
import 'package:flutter/material.dart';

class Adminscreen extends StatelessWidget {
  const Adminscreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Admin Panel',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: SizeConfig.f(20),
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue[700],
        elevation: 0,
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
              'Employees',
              Icons.person,
              const Color.fromARGB(255, 190, 230, 225),
              const Color.fromARGB(255, 60, 105, 110),
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => MyTeamScreen()),
                );
              },
            ),

            _buildManagerCard(
              context,
              'Client Setup',
              Icons.business_center_rounded,
              const Color.fromARGB(255, 245, 235, 210),
              const Color.fromARGB(255, 120, 95, 70),
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => Clientscreen()),
                );
              },
            ),

            _buildManagerCard(
              context,
              'User Device Approval',
              Icons.mobile_friendly,
              const Color(0xFFEFFCFB),
              const Color(0xFF145E5A),
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AdminDeviceRequestsScreen(),
                  ),
                );
              },
            ),

            _buildManagerCard(
              context,
              'User Devices',
              Icons.smartphone,
              const Color.fromARGB(255, 241, 236, 172),
              const Color.fromARGB(255, 77, 77, 22),
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AdminDeviceManagementScreen(),
                  ),
                );
              },
            ),

            _buildManagerCard(
              context,
              'Profile Photo Approval',
              Icons.check_circle_outlined,
              const Color.fromARGB(255, 245, 215, 220),
              const Color.fromARGB(255, 120, 80, 95),
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ApproveProfilePic()),
                );
              },
            ),
             _buildManagerCard(
              context,
              'Holiday Setup',
              Icons.celebration,
const Color.fromARGB(255, 220, 235, 220),
const Color.fromARGB(255, 85, 120, 85),
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => HolidaySetup()),
                );
              },
            ),

            _buildManagerCard(
              context,
              'Devices',
              Icons.devices,
              const Color.fromARGB(255, 215, 225, 240),
              const Color.fromARGB(255, 80, 95, 120),
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => DeviceScreen()),
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
    Color bgcolor,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(SizeConfig.f(10)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: bgcolor,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: color),
              SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
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
