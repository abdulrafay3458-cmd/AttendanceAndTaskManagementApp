import 'package:attendance_app/services/apiservice.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CancelLeaveDialog extends StatefulWidget {
  final int leaveId;
  final VoidCallback onSuccess;

  const CancelLeaveDialog({
    super.key,
    required this.leaveId,
    required this.onSuccess,
  });

  @override
  _CancelLeaveDialogState createState() => _CancelLeaveDialogState();
}

class _CancelLeaveDialogState extends State<CancelLeaveDialog> {
  DateTimeRange? _leaveRange;
  DateTime? _startDate;
  DateTime? _endDate;
  final _reasonController = TextEditingController();
  bool _isSubmitting = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLeaveData();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadLeaveData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await ApiService.getLeaveCancelData(no: widget.leaveId);
      if (data != null) {
        setState(() {
          _leaveRange = data;
          _startDate = data.start;
          _endDate = data.end;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load leave data'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (error) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading leave data: ${error.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _submitRequest() async {
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait for dates to load'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_endDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End date cannot be before start date'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a reason for cancel leave..'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final empCode = ApiService.employeeId;
    if (empCode == null) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Employee ID not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // try {
    //   final isSuccess = await ApiService.cancelSingleDayLeave(
    //     employeeId: empCode,
    //     startDate: _startDate!,
    //     endDate: _endDate!,
    //     reason: _reasonController.text.trim(),
    //   );

    //   if (isSuccess) {
    //     Navigator.pop(context);
    //     ScaffoldMessenger.of(context).showSnackBar(
    //       const SnackBar(
    //         content: Text('Leave cancelled successfully'),
    //         backgroundColor: Colors.green,
    //       ),
    //     );
    //     widget.onSuccess();
    //   } else {
    //     setState(() => _isSubmitting = false);
        
    //     ScaffoldMessenger.of(context).showSnackBar(
    //       const SnackBar(
    //         content: Text('Failed to cancel leave. Please try again.'),
    //         backgroundColor: Colors.red,
    //       ),
    //     );
    //   }
    // } catch (error) {
    //   setState(() => _isSubmitting = false);
      
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     SnackBar(
    //       content: Text('An error occurred: ${error.toString()}'),
    //       backgroundColor: Colors.red,
    //     ),
    //   );
    // }
  }

  @override
  Widget build(BuildContext context) {
    final totalDays = _startDate != null && _endDate != null 
      ? _endDate!.difference(_startDate!).inDays + 1
      : 0;
    if (_isLoading) {
      return Dialog(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading leave data...'),
            ],
          ),
        ),
      );
    }

    if (_startDate == null || _endDate == null) {
      return Dialog(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 48),
              SizedBox(height: 16),
              Text('Could not load leave data', 
                style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('Please try again later'),
              SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Close'),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _loadLeaveData,
                      child: Text('Retry'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cancel Leave',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 24),

            // Start Date
            Text('Start Date', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final maxStartDate = _leaveRange?.end ?? DateTime.now().add(Duration(days: 365));
                
                final date = await showDatePicker(
                  context: context,
                  initialDate: _startDate!,
                  firstDate: DateTime.now(),
                  lastDate: maxStartDate,
                );
                if (date != null) {
                  setState(() {
                    _startDate = date;
                    if (_endDate!.isBefore(date)) {
                      _endDate = date;
                    }
                  });
                }
              },
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[100],
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: Colors.blue),
                    SizedBox(width: 12),
                    Text(
                      DateFormat('MMM dd, yyyy').format(_startDate!.toLocal()),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // End Date
            Text('End Date', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final maxEndDate = _leaveRange?.end ?? DateTime.now().add(Duration(days: 365));
                
                final date = await showDatePicker(
                  context: context,
                  initialDate: _endDate!,
                  firstDate: _startDate!,
                  lastDate: maxEndDate,
                  selectableDayPredicate: (day) {
                    return !day.isBefore(_startDate!);
                  },
                );
                if (date != null) {
                  setState(() {
                    _endDate = date;
                  });
                }
              },
              child: Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[100],
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: Colors.blue),
                    SizedBox(width: 12),
                    Text(
                      DateFormat('MMM dd, yyyy').format(_endDate!.toLocal()),
                    ),
                  ],
                ),
              ),
            ),

            // Total Days
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule, color: Colors.blue[700]),
                  SizedBox(width: 8),
                  Text(
                    'Total: $totalDays day(s)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 16),

            if (_leaveRange != null) ...[
              Text(
                'Original Leave Dates',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[50],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'From: ${DateFormat('MMM dd, yyyy').format(_leaveRange!.start.toLocal())}',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    Text(
                      'To: ${DateFormat('MMM dd, yyyy').format(_leaveRange!.end.toLocal())}',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
            ],

            // Reason
            Text('Reason', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            TextField(
              controller: _reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter reason for cancellation',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),

            SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel'),
                  ),
                ),
                SizedBox(width: 5),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitRequest,
                    child: _isSubmitting
                        ? SizedBox(
                            width: 16,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text('Submit'),
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