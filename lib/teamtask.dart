import 'package:attendance_app/services/apiservice.dart';
import 'package:attendance_app/services/taskmodel.dart';
import 'package:attendance_app/edittaskscreen.dart';
import 'package:attendance_app/taskdetail.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TeamTasksScreen extends StatefulWidget {
  const TeamTasksScreen({super.key});

  @override
  _TeamTasksScreenState createState() => _TeamTasksScreenState();
}

class _TeamTasksScreenState extends State<TeamTasksScreen>
    with SingleTickerProviderStateMixin {
  List<TaskModel> _allTasks = [];
  List<TaskModel> _filteredTasks = [];
  bool _isLoading = true;
  late TabController _tabController;
  String _currentFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadTeamTasks();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      setState(() {
        switch (_tabController.index) {
          case 0:
            _currentFilter = 'all';
            break;
          case 1:
            _currentFilter = 'assigned';
            break;
          case 2:
            _currentFilter = 'in_progress';
            break;
          case 3:
            _currentFilter = 'completed';
            break;
          case 4:
            _currentFilter = 'overdue';
            break;
        }
        _filterTasks();
      });
    }
  }

  Future<void> _loadTeamTasks() async {
    setState(() => _isLoading = true);

    final teamLeadId = ApiService.employeeId;
    if (teamLeadId != null) {
      final data = await ApiService.getTeamTasks(teamLeadId);
      setState(() {
        _allTasks = data;
        _filterTasks();
        _isLoading = false;
      });
    }
  }

  void _filterTasks() {
    setState(() {
      switch (_currentFilter) {
        case 'all':
          _filteredTasks = _allTasks;
          break;
        case 'assigned':
          _filteredTasks = _allTasks
              .where((task) => task.status == 'assigned')
              .toList();
          break;
        case 'in_progress':
          _filteredTasks = _allTasks
              .where((task) => task.status == 'in_progress')
              .toList();
          break;
        case 'completed':
          _filteredTasks = _allTasks
              .where((task) => task.status == 'completed')
              .toList();
          break;
        case 'overdue':
          _filteredTasks = _allTasks.where((task) {
            if (task.dueDate == null || task.status == 'completed') {
              return false;
            }
            return task.dueDate!.isBefore(DateTime.now());
          }).toList();
          break;
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Team Task', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue[700],
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _loadTeamTasks),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.blue[700],
          labelColor: Colors.blue[700],
          unselectedLabelColor: const Color.fromARGB(255, 44, 44, 44),
          tabs: [
            Tab(text: 'All (${_allTasks.length})'),
            Tab(
              text:
                  'Assigned (${_allTasks.where((t) => t.status == 'assigned').length})',
            ),
            Tab(
              text:
                  'In Progress (${_allTasks.where((t) => t.status == 'in_progress').length})',
            ),
            Tab(
              text:
                  'Completed (${_allTasks.where((t) => t.status == 'completed').length})',
            ),
            Tab(
              text:
                  'Overdue (${_allTasks.where((t) => t.dueDate != null && t.dueDate!.isBefore(DateTime.now()) && t.status != 'completed').length})',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _filteredTasks.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.task_alt, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No tasks in this category',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadTeamTasks,
              child: ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: _filteredTasks.length,
                itemBuilder: (context, index) {
                  final task = _filteredTasks[index];
                  return _buildTeamTaskCard(task);
                },
              ),
            ),
    );
  }

  Widget _buildTeamTaskCard(TaskModel task) {
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

    Color statusColor;
    IconData statusIcon;
    switch (task.status) {
      case 'completed':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'in_progress':
        statusColor = Colors.blue;
        statusIcon = Icons.pending;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.assignment;
    }

    final isOverdue =
        task.dueDate != null &&
        task.dueDate!.isBefore(DateTime.now()) &&
        task.status != 'completed';

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
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
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      decoration: task.status == 'completed'
                          ? TextDecoration.lineThrough
                          : null,
                    ),
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
                    task.priority.toUpperCase(),
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
            Row(
              children: [
                Icon(Icons.person, size: 16, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text(
                  task.assignedToName,
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
                SizedBox(width: 16),
                Icon(statusIcon, size: 16, color: statusColor),
                SizedBox(width: 4),
                Text(
                  task.status.replaceAll('_', ' ').toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (task.dueDate != null) ...[
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: isOverdue ? Colors.red : Colors.grey[600],
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Due: ${DateFormat('MMM dd, yyyy').format(task.dueDate!.toLocal())}',
                    style: TextStyle(
                      fontSize: 13,
                      color: isOverdue ? Colors.red : Colors.grey[700],
                      fontWeight: isOverdue ? FontWeight.bold : null,
                    ),
                  ),
                  if (isOverdue) ...[
                    SizedBox(width: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'OVERDUE',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.blue),
                SizedBox(width: 4),
                Text(
                  'Total: ${formatHours(task.totalHoursWorked ?? 0.00)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                    fontSize: 13,
                  ),
                ),
                Spacer(),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                  onSelected: (value) async {
                    if (value == 'edit_task') {
                      final taskData = {
                        'taskId': task.id,
                        'taskTitle': task.taskTitle,
                        'taskDescription': task.taskDescription,
                        'assignedTo': task.assignedTo,
                        'assignedToName': task.assignedToName,
                        'priority': task.priority,
                        'status': task.status,
                        'dueDate': task.dueDate?.toIso8601String(),
                        'totalHoursWorked': task.totalHoursWorked,
                        'assignedBy': task.assignedBy,
                        'assignedByName': task.assignedByName,
                        'assignedDate': task.assignedDate.toIso8601String(),
                        'taskPreference': task.taskPreference,
                        'clientCode': task.clientCode,
                        'clientName': task.clientName
                      };

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              EditTaskScreen(taskData: taskData),
                        ),
                      ).then((_) => _loadTeamTasks());
                    } else if (value == 'delete_task') {
                      final confirmDelete = await showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('Delete Task'),
                          content: Text(
                            'Are you sure you want to delete "${task.taskTitle}"? This action cannot be undone.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                      );

                      if (confirmDelete == true) {
                        // Call API to delete task
                        final success = await ApiService.deleteTask(
                          task.id,
                          task.assignedBy,
                        );

                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Task deleted successfully'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          // Refresh the task list
                          _loadTeamTasks();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to delete task'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'edit_task',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('Edit Task'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete_task',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (task.taskDescription.isNotEmpty) ...[
              Divider(height: 20),
              Text(
                task.taskDescription,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            SizedBox(height: 12),
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
                      TaskDetailsSheet(task: task, onUpdate: _loadTeamTasks),
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 36),
              ),
              child: Text('View Details'),
            ),
          ],
        ),
      ),
    );
  }
}

String formatHours(double totalHours) {
  final duration = Duration(minutes: (totalHours * 60).round());
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  return '${hours}h ${minutes}m';
}
