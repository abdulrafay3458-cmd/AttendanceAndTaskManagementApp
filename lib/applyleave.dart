import 'package:attendance_app/models/WorkingDay.dart';
import 'package:attendance_app/models/leave_type.dart';
import 'package:attendance_app/services/apiservice.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ApplyLeaveDialog extends StatefulWidget {
  final VoidCallback onSuccess;

  const ApplyLeaveDialog({super.key, required this.onSuccess});

  @override
  _ApplyLeaveDialogState createState() => _ApplyLeaveDialogState();
}

class _ApplyLeaveDialogState extends State<ApplyLeaveDialog> {
@override
void initState() {
  super.initState();
  _initialize();
}

Future<void> _initialize() async {
  await loadWorkingDays();
  await loadHolidays();
  await _loadLeaveTypes();
}
  List<DateTime> disabledDates = [];
  List<int> weeklyOffDays = [];
  List<LeaveType> _leaveTypes = [];
  LeaveType? _selectedLeaveType;
  bool _loadingLeaveTypes = true;
  List<WorkingDay> workingDays = [];
  // String _leaveType = 'casual';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  final _reasonController = TextEditingController();
  bool _isSubmitting = false;

  final firstDayOfYear = DateTime(DateTime.now().year, 1, 1);
  final lastDayOfYear  = DateTime(DateTime.now().year, 12, 31);

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadLeaveTypes() async {
    final data = await ApiService.getLeaveTypes();
    setState(() {
      _leaveTypes = data;
      _loadingLeaveTypes = false;
    });
  }
  Future<void> loadWorkingDays() async {
  final employeeCode = ApiService.currentEmployee?.employeeId;
  final response = await ApiService.fetchWorkingDays(employeeCode);
  setState(() {
    workingDays = response;
  });

}
Future<void> loadHolidays() async {

  final response = await ApiService.getHolidays(); // your api call

  for (var h in response) {
    if (h.day == 0) {
      // weekly off
      if (h.title.toLowerCase() == "saturday") weeklyOffDays.add(DateTime.saturday);
      if (h.title.toLowerCase() == "sunday") weeklyOffDays.add(DateTime.sunday);
    } else {
      disabledDates.add(DateTime(h.year, h.month, h.day));
    }
  }


  setState(() {});
}
// int calculateLeaveDays() {
//   int days = 0;

//   for (DateTime d = _startDate;
//       !d.isAfter(_endDate);
//       d = d.add(Duration(days: 1))) {
//     if (isSelectable(d)) days++;
//   }

//   return days;
// }
double calculateLeaveDays() {

  if (workingDays.isEmpty) return 0;

  final start = DateTime(_startDate.year, _startDate.month, _startDate.day);
  final end   = DateTime(_endDate.year, _endDate.month, _endDate.day);

  double days = 0;

  for (DateTime d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {

    if (!isWorkingDay(d.weekday)) continue;

    if (disabledDates.any((x) =>
        x.year == d.year && x.month == d.month && x.day == d.day)) {
      continue;
    }

    if (_selectedLeaveType?.title.toLowerCase() == 'half day') {
      days += 0.5;
    } else {
      days += 1;
    }
  }

  return days;
}
bool isWorkingDay(int weekday) {
  final day = workingDays.firstWhere(
    (d) => d.weekDay == weekday,
    orElse: () => WorkingDay(weekDay: weekday, minutes: 0),
  );

  return day.minutes > 0;
}
// double calculateLeaveDays() {
//   double days = 0;

//   for (DateTime d = _startDate;
//       !d.isAfter(_endDate);
//       d = d.add(Duration(days: 1))) {

//     // Skip Saturday and Sunday
//     if (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday) {
//       continue;
//     }

//     if (isSelectable(d)) {
//       // If leave type is half-day, add 0.5, else 1
//       if (_selectedLeaveType != null && _selectedLeaveType!.title.toLowerCase() == 'half day') {
//         days += 0.5;
//       } else {
//         days += 1;
//       }
//     }
//   }

//   return days;
// }
// int calculateLeaveDays() {
//   int days = 0;

//   for (DateTime d = _startDate;
//       !d.isAfter(_endDate);
//       d = d.add(Duration(days: 1))) {

//     // Skip Saturday and Sunday
//     if (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday) {
//       continue;
//     }

//     if (isSelectable(d)) days++;
//   }

//   return days;
// }

  Future<void> _submitLeave() async {
    if (_selectedLeaveType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select leave type'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a reason for leave'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    // final employeeId = ApiService.employeeId;
    final empCode = ApiService.employeeId;
    if (empCode == null) return;

    final result = await ApiService.applyLeave(
      employeeId: empCode,
      leaveType: _selectedLeaveType!.code,
      startDate: _startDate,
      endDate: _endDate,
      reason: _reasonController.text.trim(),
    );

    setState(() => _isSubmitting = false);

    if (result['success'] == true) {
      Navigator.pop(context);
      widget.onSuccess();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Leave request submitted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Failed to submit leave request'),
          backgroundColor: Colors.red,
        ),
      );
    }

  }
    bool isSelectable(DateTime day) {

  // disable weekly offs
  if (weeklyOffDays.contains(day.weekday)) {
    return false;
  }

  // disable holidays
  for (var d in disabledDates) {
    if (d.year == day.year &&
        d.month == day.month &&
        d.day == day.day) {
      return false;
    }
  }

  return true;
}
  @override
  Widget build(BuildContext context) {
    // final totalDays = _endDate.difference(_startDate).inDays + 1;
    final totalDays = calculateLeaveDays();

    return Dialog(
      backgroundColor: Color.fromARGB(255, 255, 252, 252),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Apply for Leave',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 24),

            // Leave Type
            const Text(
              'Leave Type *',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            _loadingLeaveTypes
                ? const Center(child: CircularProgressIndicator())
                : DropdownButtonFormField<LeaveType>(
                    value: _selectedLeaveType,
                    validator: (value) =>
                        value == null ? 'Please select leave type' : null,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                    items: _leaveTypes.map((lt) {
                      return DropdownMenuItem<LeaveType>(
                        value: lt,
                        child: Text(lt.title, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedLeaveType = value;
                      });
                    },
                  ),
            SizedBox(height: 16),

            // Start Date
            Text('Start Date', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _startDate.isBefore(firstDayOfYear) ? firstDayOfYear : _startDate,
                  firstDate: firstDayOfYear,
                  lastDate: lastDayOfYear,
                  selectableDayPredicate: isSelectable,
                );
                if (date != null) {
                  setState(() {
                    _startDate = date;
                    if (_endDate.isBefore(_startDate)) {
                      _endDate = _startDate;
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
                      DateFormat('MMM dd, yyyy').format(_startDate.toLocal()),
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
                final lowerBound = _startDate.isBefore(firstDayOfYear)
                  ? firstDayOfYear
                  : _startDate;
                
                final initial = _endDate.isBefore(lowerBound)
                  ? lowerBound
                  : (_endDate.isAfter(lastDayOfYear) ? lastDayOfYear : _endDate);
                
                final date = await showDatePicker(
                  context: context,
                  initialDate: initial,
                  firstDate: lowerBound,
                  lastDate: lastDayOfYear,
                  selectableDayPredicate: isSelectable,
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
                    Text(DateFormat('MMM dd, yyyy').format(_endDate.toLocal())),
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Total Days
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

            // Reason
            Text('Reason', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            TextField(
              controller: _reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Enter reason for leave',
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
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: BorderSide(color: Colors.blue, width: 1),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel'),
                  ),
                ),
                SizedBox(width: 5),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _isSubmitting ? null : _submitLeave,
                    child: _isSubmitting
                        ? SizedBox(
                            width: 16,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: const Color.fromARGB(255, 255, 255, 255),
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
