import 'package:attendance_app/applyleave.dart';
import 'package:attendance_app/cancel_leave_days_dialog.dart';
import 'package:attendance_app/services/apiservice.dart';
import 'package:attendance_app/services/leaverequestmodel.dart';
import 'package:attendance_app/widgets/SizeConfig.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class LeaveScreen extends StatefulWidget {
  const LeaveScreen({super.key});

  @override
  _LeaveScreenState createState() => _LeaveScreenState();
}

class _LeaveScreenState extends State<LeaveScreen> {
  List<LeaveRequestModel> _leaveRequests = [];
  Map<String, dynamic> _leaveStats = {};
  bool _isLoading = true;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadLeaveRequests();
    _loadLeaveStatistics();
  }

  Future<void> _loadLeaveRequests() async {
    setState(() => _isLoading = true);

    final empCode = ApiService.employeeId;
    if (empCode == null || empCode.isEmpty) {
      print('Employee code is null');
      setState(() => _isLoading = false);
      return;
    }

    final data = await ApiService.getLeaveRequests(empCode);
    setState(() {
      _leaveRequests = data;
      _isLoading = false;
    });
  }

  Future<void> _loadLeaveStatistics() async {
    setState(() => _isLoadingStats = true);

    final empCode = ApiService.employeeId;
    if (empCode == null || empCode.isEmpty) {
      print('Employee code is null for stats');
      setState(() => _isLoadingStats = false);
      return;
    }

    final stats = await ApiService.getLeaveStatistics(empCode);
    setState(() {
      _leaveStats = stats;
      _isLoadingStats = false;
    });
  }

  void _showApplyLeaveDialog() {
    showDialog(
      context: context,
      builder: (context) => ApplyLeaveDialog(
        onSuccess: () {
          _loadLeaveRequests();
          _loadLeaveStatistics(); // Refresh stats after applying leave
        },
      ),
    );
  }

  Future<void> _openCancelLeaveDialog(LeaveRequestModel leave) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => CancelLeaveDaysDialog(leave: leave),
    );

    if (result == true) {
      _loadLeaveRequests();
      _loadLeaveStatistics(); // Refresh stats after cancelling leave
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Leave Request',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: SizeConfig.f(20),
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue[700],
        elevation: 0,
        actions: [
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.refresh_outlined),
            onPressed: () {
              _loadLeaveRequests();
              _loadLeaveStatistics();
            },
            tooltip: 'Refresh',
            iconSize: 22,
          ),
        ],
      ),
      body: _isLoading || _isLoadingStats
          ? Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await _loadLeaveRequests();
                await _loadLeaveStatistics();
              },
              child: ListView(
                padding: EdgeInsets.all(16),
                children: [
                  // Dashboard Section
                  _buildDashboardSection(),
                  SizedBox(height: 24),
                  
                  // Leave Requests Section
                  _leaveRequests.isEmpty
                      ? _buildEmptyState()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Leave History',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                            SizedBox(height: 12),
                            ..._leaveRequests.map((leave) => _buildLeaveCard(leave)).toList(),
                          ],
                        ),
                ],
              ),
            ),
      floatingActionButton: _leaveRequests.isEmpty
      ? null
      : FloatingActionButton.extended(
        onPressed: _showApplyLeaveDialog,
        icon: Icon(Icons.add),
        label: Text('Apply Leave'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildDashboardSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Leave Dashboard',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildDashboardCard(
                title: 'Total Leaves',
                value: _leaveStats['totalLeaves']?.toString() ?? '0',
                color: Colors.blue,
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _buildDashboardCard(
                title: 'Availed Leave(s)',
                value: _leaveStats['yearlyAvailed']?.toString() ?? '0',
                color: Colors.orange,
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: _buildDashboardCard(
                title: 'Available Leave(s)',
                value: _leaveStats['availableLeaves']?.toString() ?? '0',
                color: Colors.green,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDashboardCard({
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: SizeConfig.f(24),
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No leave requests',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _showApplyLeaveDialog,
            icon: Icon(Icons.add),
            label: Text('Apply for Leave'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(213, 25, 118, 210),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(LeaveRequestModel leave) {
    Color statusColor;
    IconData statusIcon;

    switch (leave.status) {
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case 'submitted':
        statusColor = Colors.blue.shade700;
        statusIcon = Icons.pending;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.pending;
    }

    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: 16, color: statusColor),
          const SizedBox(width: 4),
          Text(
            leave.status.toUpperCase(),
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveCard(LeaveRequestModel leave) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          13,
          7,
          16
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    leave.leaveType.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildStatusChip(leave),
                      const SizedBox(width: 2),
                      PopupMenuButton<String>(
                        color: Colors.white,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        iconSize: 20,
                        icon: const Icon(Icons.more_vert),
                        onSelected: (value) {
                          if (value == 'cancel' && leave.status == 'approved') {
                            _openCancelLeaveDialog(leave);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'cancel',
                            enabled: leave.status == 'approved',
                            child: Text(
                              'Cancel Leave',
                              style: TextStyle(
                                color: leave.status == 'approved'
                                    ? Colors.black
                                    : Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                SizedBox(width: 8),
                Text(
                  '${DateFormat('MMM dd, yyyy').format(leave.startDate.toLocal())} - ${DateFormat('MMM dd, yyyy').format(leave.endDate.toLocal())}',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.schedule, size: 16, color: Colors.grey),
                    SizedBox(width: 8),
                    Text(
                      '${leave.totalDays} day(s)',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
            
            if (leave.reason.isNotEmpty) ...[
              Divider(height: 20),
              Text(
                'Reason:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 4),
              Text(leave.reason, style: TextStyle(fontSize: 14)),
            ],
            if (leave.status == 'rejected' && leave.rejectionReason != '') ...[
              Divider(height: 20),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rejection Reason:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.red[700],
                      ),
                    ),
                    SizedBox(width: SizeConfig.w(100)),
                    Text(
                      leave.rejectionReason ?? "",
                      style: TextStyle(fontSize: 13, color: Colors.red[900]),
                    ),
                  ],
                ),
              ),
            ],
            SizedBox(height: 8),
            Text(
              'Applied: ${leave.createdAt != null ? DateFormat('MMM dd, yyyy').format(leave.createdAt!.toLocal()) : 'N/A'}',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}