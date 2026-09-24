import 'package:attendance_app/models/overtime_approval_model.dart';
import 'package:attendance_app/rejectleave.dart';
import 'package:attendance_app/services/apiservice.dart';
import 'package:attendance_app/widgets/SizeConfig.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OverTimeScreen extends StatefulWidget {
  const OverTimeScreen({super.key});

  @override
  _OverTimeScreenScreenState createState() => _OverTimeScreenScreenState();
}

class _OverTimeScreenScreenState extends State<OverTimeScreen> {
  List<OvertimeApprovalModel> _overtimeData = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOvertimeData();
  }

  // Get All Requests
  Future<void> _loadOvertimeData() async {
    setState(() => _isLoading = true);

    final managerId = ApiService.currentEmployee?.employeeId;
    print('Manager ID for fetching: $managerId');

    if (managerId != null && managerId.isNotEmpty) {
      try {
        print('Starting API call...');
        final data = await ApiService.getOverTimeApprovals(managerId);

        List<OvertimeApprovalModel> parsedOvertime = [];

        for (int i = 0; i < data.length; i++) {
          try {
            final overtime = OvertimeApprovalModel.fromJson(data[i]);
            parsedOvertime.add(overtime);
          } catch (e) {
            print('Error parsing item $i: $e');
          }
        }

        setState(() {
          _overtimeData = parsedOvertime;
          _isLoading = false;
        });
      } catch (e, stackTrace) {
        print('Fatal error in _loadOvertimeData: $e');
        print('Stack trace: $stackTrace');
        setState(() {
          _overtimeData = [];
          _isLoading = false;
        });
      }
    } else {
      print('Invalid manager ID: $managerId');
      setState(() => _isLoading = false);
    }
  }

  // Approve Overtime Request
  Future<void> _approveRequest(OvertimeApprovalModel overtime) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Overtime Request',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: SizeConfig.f(16)),
        ),
        content: Text(
          'Approve ${overtime.formattedOvertime} hrs overtime for ${overtime.employeeName} '
          'on ${DateFormat('dd MMM yyyy').format(overtime.overtimeDate)}?',
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
      final result = await ApiService.approveOvertimeRequest(overtime.userTaskId);
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Overtime request approved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadOvertimeData();
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

  // Reject Overtime Request
  Future<void> _rejectRequest(OvertimeApprovalModel overtime) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => RejectLeaveDialog(),
    );

    if (reason != null && reason.isNotEmpty) {
      final result = await ApiService.rejectOvertimeRequest(overtime.userTaskId, reason);
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Overtime request rejected'),
            backgroundColor: Colors.orange,
          ),
        );
        _loadOvertimeData();
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
          'Overtime Requests',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue[700],
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadOvertimeData,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _overtimeData.isEmpty
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
                  onRefresh: _loadOvertimeData,
                  child: ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: _overtimeData.length,
                    itemBuilder: (context, index) {
                      final overtime = _overtimeData[index];
                      return _buildOvertimeApprovalCard(overtime);
                    },
                  ),
                ),
    );
  }

  Widget _buildOvertimeApprovalCard(OvertimeApprovalModel overtime) {
    final initial = overtime.employeeName.isNotEmpty
        ? overtime.employeeName.substring(0, 1).toUpperCase()
        : '?';

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
                    initial,
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
                        overtime.employeeName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        overtime.employeeId,
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
                Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  DateFormat('EEE, dd MMM yyyy').format(overtime.overtimeDate),
                  style: const TextStyle(fontSize: 14),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    overtime.formattedOvertime,
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
              width: double.infinity,
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
                  SizedBox(height: 4),
                  Text(
                    overtime.reason,
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _rejectRequest(overtime),
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
                    onPressed: () => _approveRequest(overtime),
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
