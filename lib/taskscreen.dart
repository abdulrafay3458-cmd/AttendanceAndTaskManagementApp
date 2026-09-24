import 'package:attendance_app/main.dart';
import 'package:attendance_app/models/AttendanceRecord.dart';
import 'package:attendance_app/services/apiservice.dart';
import 'package:attendance_app/services/taskmodel.dart';
import 'package:attendance_app/taskdetail.dart';
import 'package:attendance_app/widgets/SizeConfig.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  _TasksScreenState createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  var _tasks = [];
  bool _isLoading = true;
  AttendanceRecord? _todayAttendance;
  List<TaskModel> _activeTasks = [];

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);

    final employeeId = ApiService.employeeId;
    if (employeeId != null) {
      final tasks = await ApiService.getActiveTasks(employeeId);
      setState(() {
        _tasks = tasks;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'All Tasks',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: SizeConfig.f(20),
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue[700],
        elevation: 0,
        actions: [IconButton(icon: Icon(Icons.refresh), onPressed: _loadTasks)],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _tasks.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.task_alt, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No active tasks',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadTasks,
              child: ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: _tasks.length,
                itemBuilder: (context, index) {
                  final task = _tasks[index];
                  return _buildTaskCard(task);
                },
              ),
            ),
    );
  }

  Widget _buildTaskCard(TaskModel task) {
    final logs = task.timeLogs;
    bool isRunning = false;
    bool isInProgress = false;

    if (task.status == "in_progress") {
      isInProgress = true;
    }

    // Safer null and empty check
    if (logs.isNotEmpty) {
      final lastLog = logs.last;
      isRunning = lastLog.startTime != null && lastLog.stopTime == null;
    }

    Color priorityColor;
    switch (task.priority) {
      case 'high':
        priorityColor = Colors.red;
        break;
      case 'low':
        priorityColor = Colors.green;
        break;
      default:
        priorityColor = Colors.orange;
    }

    return Card(
      color: Colors.white,
      margin: EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.taskTitle,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: priorityColor),
                  ),
                  child: Text(
                    (task.priority).toUpperCase(),
                    style: TextStyle(
                      color: priorityColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              task.taskDescription,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 8),
            Text(
              'Assigned by: ${task.assignedByName}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            if (task.dueDate != null) ...[
              SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                  SizedBox(width: 4),
                  Text(
                    'Due: ${DateFormat('MMM dd, yyyy').format(task.dueDate!.toLocal())}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
            SizedBox(height: 12),
            Row(
              children: [
                // SHOW ONLY IF TASK NOT RUNNING
                if (task.status != "in_progress") ...[
                  Icon(Icons.access_time, size: 16, color: Colors.blue),
                  SizedBox(width: 4),
                  Text(
                    'Total Duration: ${formatHours(task.totalHoursWorked ?? 0.00)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  Spacer(),
                ] else ...[
                  Spacer(),
                ],

                // STATUS BADGE
                if (task.status == "in_progress") ...[
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Running',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (task.status == "completed") ...[
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Completed',
                          style: TextStyle(
                            color: Colors.orange,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            // Row(
            //   children: [
            //     Icon(Icons.access_time, size: 16, color: Colors.blue),
            //     SizedBox(width: 4),
            //     Text(
            //       'Total Duration: ${formatHours(task.totalHoursWorked ?? 0.00)}',
            //       // 'Total: ${(task.totalHoursWorked).toStringAsFixed(1)}',
            //       style: TextStyle(
            //         fontWeight: FontWeight.bold,
            //         color: Colors.blue,
            //       ),
            //     ),
            //     Spacer(),
            //     if (task.status == "in_progress") ...[
            //       Container(
            //         padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            //         decoration: BoxDecoration(
            //           color: Colors.green.withOpacity(0.1),
            //           borderRadius: BorderRadius.circular(8),
            //         ),
            //         child: Row(
            //           mainAxisSize: MainAxisSize.min,
            //           children: [
            //             Container(
            //               width: 8,
            //               height: 8,
            //               decoration: BoxDecoration(
            //                 color: Colors.green,
            //                 shape: BoxShape.circle,
            //               ),
            //             ),
            //             SizedBox(width: 4),
            //             Text(
            //               'Running',
            //               style: TextStyle(
            //                 color: Colors.green,
            //                 fontSize: 12,
            //                 fontWeight: FontWeight.bold,
            //               ),
            //             ),
            //           ],
            //         ),
            //       ),
            //     ] else if (task.status == "completed") ...[
            //       Container(
            //         padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            //         decoration: BoxDecoration(
            //           color: Colors.orange.withOpacity(0.1),
            //           borderRadius: BorderRadius.circular(8),
            //         ),
            //         child: Row(
            //           mainAxisSize: MainAxisSize.min,
            //           children: [
            //             Container(
            //               width: 8,
            //               height: 8,
            //               decoration: BoxDecoration(
            //                 color: Colors.orange,
            //                 shape: BoxShape.circle,
            //               ),
            //             ),
            //             SizedBox(width: 4),
            //             Text(
            //               'Completed',
            //               style: TextStyle(
            //                 color: Colors.orange,
            //                 fontSize: 12,
            //                 fontWeight: FontWeight.bold,
            //               ),
            //             ),
            //           ],
            //         ),
            //       ),
            //     ],
            //   ],
            // ),
            SizedBox(height: 12),
            if (task.status != "completed") ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isInProgress
                          ? () => _stopTask(task)
                          : () => _handleStartTask(task),
                      icon: Icon(
                        isInProgress ? Icons.stop : Icons.play_arrow,
                        size: 16,
                      ),
                      label: Text(
                        isInProgress ? 'Stop' : 'Start',
                        style: TextStyle(fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isInProgress
                            ? Colors.red
                            : Colors.green,
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                        ),
                        builder: (context) =>
                            TaskDetailsSheet(task: task, onUpdate: _loadTasks),
                      );
                    },
                    style: ElevatedButton.styleFrom(minimumSize: Size(120, 40)),
                    child: Text('View Details'),
                  ),
                ],
              ),
            ] else ...[
              ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    builder: (context) =>
                        TaskDetailsSheet(task: task, onUpdate: _loadTasks),
                  );
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(SizeConfig.w(100), 40),
                ),
                child: Text('View Details'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final employeeId = ApiService.employeeId;
    if (employeeId != null) {
      final attendance = await ApiService.getTodayAttendance(employeeId);
      final tasks = await ApiService.getActiveTasks(employeeId);
      final filteredTasks = tasks
          .where((task) => task.status == 'in_progress')
          .toList();

      setState(() {
        _todayAttendance = attendance;
        _activeTasks = filteredTasks;
        _isLoading = false;
      });
    }
  }

  Future<bool> _showLeaveConfirmDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return AlertDialog(
              title: Text("Leave Marked"),
              content: Text(
                "Your leave is marked today. "
                " This task will be counted as extra work hours.\n"
                "Start anyway?",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text("No"),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text("Yes"),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> _handleStartTask(TaskModel task) async {
    // If task is NOT client-side → start directly
    if (task.taskPreference != 'client') {
      await _startTask(task);
      return;
    }

    try {
      // 1. Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          _showError('Location permission required');
          return;
        }
      }

      // 2. Get agent current location
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 3. Send location to backend for validation
      final isAllowed = await ApiService.validateTaskLocation(
        taskId: task.id,
        latitude: position.latitude,
        longitude: position.longitude,
      );
      
      if (!isAllowed) {
        _showError('You must be near the client location to start this task');
        return;
      }

      // 4. Allowed → Start task
      await _startTask(task);
    } catch (e) {
      _showError('Unable to verify location');
    }
  }

  Future<void> _startTask(TaskModel task) async {
    // final employeeId = ApiService.employeeId;
    // if (employeeId == null) return;
    final employeeId = ApiService.employeeId;
    final companyCode = ApiService.currentEmployee?.companyCode;
    if (employeeId == null || companyCode == null) return;
    // Check Leave
    final isLeave = await ApiService.isOnLeave(employeeId, companyCode);

    if (isLeave) {
      final proceed = await _showLeaveConfirmDialog();

      if (!proceed) return;
    }
    final result = await ApiService.startTask(
      employeeId: employeeId,
      taskId: task.id,
    );

    if (result['success'] == true) {
      final taskData = result['task'];

      // Check leave status
      final bool onLeave = await ApiService.isOnLeave(employeeId, companyCode);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Task started!'),
          backgroundColor: Colors.green,
        ),
      );

      final bool isExtra = taskData?['isExtraHours'] == true;
      if (!onLeave && isExtra) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('⚠️ Extra Hours Warning'),
            content: const Text(
              'This task will be considered as extra work hours '
              'because you are starting it after check-out.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      await _loadTasks();
    } else {
      // ❌ Failed to start task
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start task'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _stopTask(TaskModel task) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => StopTaskDialog(),
    );

    if (result == null) return;

    final employeeId = ApiService.employeeId;
    if (employeeId == null) return;

    final response = await ApiService.stopTask(
      employeeId: employeeId,
      taskId: task.id,
      notes: result,
    );

    if (response['success'] == true) {
      final todayHours = response['todayHours'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Task stopped! Today: ${todayHours.toStringAsFixed(1)}h',
          ),
          backgroundColor: Colors.blue,
        ),
      );
      await _loadTasks();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['error'] ?? 'Failed to stop task'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

String formatHours(double totalHours) {
  final duration = Duration(minutes: (totalHours * 60).round());
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  return '${hours}h ${minutes}m';
}
