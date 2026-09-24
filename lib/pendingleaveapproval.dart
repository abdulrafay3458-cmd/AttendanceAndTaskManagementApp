import 'package:attendance_app/rejectleave.dart';
import 'package:attendance_app/services/apiservice.dart';
import 'package:attendance_app/services/leaverequestmodel.dart';
import 'package:attendance_app/widgets/SizeConfig.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PendingLeaveApprovalsScreen extends StatefulWidget {
  const PendingLeaveApprovalsScreen({super.key});

  @override
  _PendingLeaveApprovalsScreenState createState() => _PendingLeaveApprovalsScreenState();
}

class _PendingLeaveApprovalsScreenState extends State<PendingLeaveApprovalsScreen> {
  List<LeaveRequestModel> _pendingLeaves = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPendingApprovals();
  }

  Future<void> _loadPendingApprovals() async {
    setState(() => _isLoading = true);

    // final managerId = ApiService.employeeId;
    final managerId = ApiService.currentEmployee?.employeeId;
    if (managerId != null) {
      final data = await ApiService.getPendingLeaveApprovals(managerId);
      setState(() {
        _pendingLeaves = data
            .map((json) => LeaveRequestModel.fromJson(json))
            .toList();
        _isLoading = false;
      });
    }
  }

  Future<void> _approveLeave(LeaveRequestModel leave) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Approve Leave'),
        content: Text(
          'Approve ${leave.totalDays} day(s) ${leave.leaveType} leave for ${leave.employeeName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: Text('Approve'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final result = await ApiService.approveLeave(leave.id);
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(' Leave approved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadPendingApprovals();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Failed to approve'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectLeave(LeaveRequestModel leave) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => RejectLeaveDialog(),
    );

    if (reason != null && reason.isNotEmpty) {
      final result = await ApiService.rejectLeave(leave.id, reason);
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(' Leave rejected'),
            backgroundColor: Colors.orange,
          ),
        );
        _loadPendingApprovals();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Failed to reject'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Pending Leaves Approvals',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue[700],
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadPendingApprovals,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _pendingLeaves.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No pending approvals',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadPendingApprovals,
              child: ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: _pendingLeaves.length,
                itemBuilder: (context, index) {
                  final leave = _pendingLeaves[index];
                  return _buildLeaveApprovalCard(leave);
                },
              ),
            ),
    );
  }

  Widget _buildLeaveApprovalCard(LeaveRequestModel leave) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 3,
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue[100],
                  child: Text(
                    leave.employeeName.substring(0, 1).toUpperCase(),
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        leave.employeeName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        leave.employeeId,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Text(
                    leave.leaveType.toUpperCase(),
                    style: TextStyle(
                      color: Colors.orange[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            Divider(height: 24),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                SizedBox(width: 8),
                Text(
                  '${DateFormat('MMM dd').format(leave.startDate)} - ${DateFormat('MMM dd, yyyy').format(leave.endDate.toLocal())}',
                  style: TextStyle(fontSize: 14),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${leave.totalDays} day(s)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reason:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                  SizedBox(width: SizeConfig.w(100)),
                  Text(leave.reason, style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Applied: ${leave.createdAt != null ? DateFormat('MMM dd, yyyy hh:mm a').format(leave.createdAt!.toLocal()) : 'N/A'}',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _rejectLeave(leave),
                    icon: Icon(Icons.close, size: 18),
                    label: Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _approveLeave(leave),
                    icon: Icon(Icons.check, size: 18),
                    label: Text('Approve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
