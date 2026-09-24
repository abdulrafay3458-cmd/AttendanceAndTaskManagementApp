import 'package:attendance_app/models/leavecancelapproval.dart';
import 'package:attendance_app/rejectleave.dart';
import 'package:attendance_app/services/apiservice.dart';
import 'package:attendance_app/widgets/SizeConfig.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PendingCancelLeaveApprovalsScreen extends StatefulWidget {
  const PendingCancelLeaveApprovalsScreen({super.key});

  @override
  _PendingCancelLeaveApprovalsScreenState createState() => _PendingCancelLeaveApprovalsScreenState();
}

class _PendingCancelLeaveApprovalsScreenState extends State<PendingCancelLeaveApprovalsScreen> {
  List<LeavecancelapprovalModel> _pendingCancelLeaves = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPendingApprovals();
  }

  // Get All Request
  Future<void> _loadPendingApprovals() async {
  setState(() => _isLoading = true);

  final managerId = ApiService.currentEmployee?.employeeId;
  print('Manager ID for fetching: $managerId');
  
  if (managerId != null && managerId.isNotEmpty) {
    try {
      print('Starting API call...');
      final data = await ApiService.getPendingCancelLeaveApprovals(managerId);

      List<LeavecancelapprovalModel> parsedLeaves = [];
      
      for (int i = 0; i < data.length; i++) {
        try {
          print('Parsing item $i: ${data[i]}');
          final leave = LeavecancelapprovalModel.fromJson(data[i]);
          parsedLeaves.add(leave);
          print('Successfully parsed item $i');
        } catch (e) {
          print('Error parsing item $i: $e');
        }
      }
      
      setState(() {
        _pendingCancelLeaves = parsedLeaves;
        _isLoading = false;
      });
      
      // Force a rebuild
      if (mounted) {
        setState(() {});
      }
      
    } catch (e, stackTrace) {
      print('Fatal error in _loadPendingApprovals: $e');
      print('Stack trace: $stackTrace');
      setState(() {
        _pendingCancelLeaves = [];
        _isLoading = false;
      });
    }
  } else {
    print('Invalid manager ID: $managerId');
    setState(() => _isLoading = false);
  }
}

  // Approve Leave Request
  Future<void> _approveRequest(LeavecancelapprovalModel leaveCancel) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel Leave Request.', style: TextStyle(fontWeight: FontWeight.w800, fontSize: SizeConfig.f(16)),),
        content: Text(
          'Approve ${leaveCancel.leaveDate} leave for ${leaveCancel.employeeName}?',
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
      final result = await ApiService.approveCancelRequest(leaveCancel.id);
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(' Leave Cancel Request approved successfully'),
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

  // Reject Leave Request
  Future<void> _rejectRequest(LeavecancelapprovalModel leave) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => RejectLeaveDialog(),
    );

    if (reason != null && reason.isNotEmpty) {
      final result = await ApiService.rejectLeaveCancelRequest(leave.id, reason);
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(' Leave Cancel Request Rejected'),
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
          'Cancel Leaves Requests',
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
          : _pendingCancelLeaves.isEmpty
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
                itemCount: _pendingCancelLeaves.length,
                itemBuilder: (context, index) {
                  final leave = _pendingCancelLeaves[index];
                  return _buildLeaveApprovalCard(leave);
                },
              ),
            ),
    );
  }

  Widget _buildLeaveApprovalCard(LeavecancelapprovalModel leave) {
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
                        leave.employeeCode,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Divider(height: 24),
          Row(
            children: [
              // Icon(Icons.event_outlined, size: 18, color: Colors.grey.shade600),
               Icon(Icons.calendar_today, size: 16, color: Colors.grey),
              const SizedBox(width: 8),

              Text(
                DateFormat('EEE, dd MMM yyyy').format(leave.leaveDate),
                style: const TextStyle(
                  fontSize: 14,
                  // fontWeight: FontWeight.w500,
                ),
              ),

              const Spacer(),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "1 day",
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w600,
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
                  Text(
                    leave.purpose ?? 'No reason provided',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Applied: ${DateFormat('dd - MMM - yyyy').format(leave.submissionDate)}',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _rejectRequest(leave),
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
                    onPressed: () => _approveRequest(leave),
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
