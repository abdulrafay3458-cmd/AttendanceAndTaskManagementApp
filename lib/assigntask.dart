import 'package:attendance_app/models/Priority.dart';
import 'package:attendance_app/services/apiservice.dart';
import 'package:attendance_app/services/clients.dart';
import 'package:attendance_app/services/teammember.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AssignTaskScreen extends StatefulWidget {
  final String? empCode;
  const AssignTaskScreen({super.key, this.empCode});

  @override
  _AssignTaskScreenState createState() => _AssignTaskScreenState();
}

class _AssignTaskScreenState extends State<AssignTaskScreen> {
  List<Priority> _priorities = [];
  Priority? _selectedPriority;
  DateTime _dueDate = DateTime.now();

  List<TeamMember> _teamMembers = [];
  List<Clients> _clientList = [];
  List<TeamMember> _selectedMembers = []; // Changed from single to list
  Clients? _selectedClient;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _showClientError = false;

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _priority = 'medium';
  String _taskpreference = 'office';

  // Search functionality
  final TextEditingController _searchController = TextEditingController();
  List<TeamMember> _filteredMembers = [];

  @override
  void initState() {
    super.initState();
    _loadTeamMembers();
    _loadClients();
    loadPriorities();
    _searchController.addListener(_filterMembers);
  }

  void _filterMembers() {
    String query = _searchController.text.toLowerCase();
    setState(() {
      _filteredMembers = _teamMembers.where((member) {
        return member.name.toLowerCase().contains(query) ||
            member.employeeId.toLowerCase().contains(query) ||
            member.department.toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> _loadTeamMembers() async {
    setState(() => _isLoading = true);

    final managerId = ApiService.employeeId;
    if (managerId != null) {
      final data = await ApiService.getTeamMembers(managerId);
      setState(() {
        _teamMembers = data;
        _filteredMembers = data;
        _isLoading = false;
      });
      
      // Handle pre-selected member from widget.empCode
      if (widget.empCode != null && widget.empCode!.isNotEmpty) {
        final member = data.firstWhere(
          (m) => m.employeeId == widget.empCode,
          orElse: () => TeamMember(
            employeeId: '',
            machineId: '',
            name: '',
            companyCode: '',
            email: '',
            phone: '',
            department: '',
            designation: '',
            designationCode: 0,
            isActive: false,
            isAppUser: false,
            role: '',
            roleId: '',
            standardHourCode: 0,
            joinDate: '',
            leadCode: ''
          ),
        );

        if (member.employeeId.isNotEmpty) {
          setState(() {
            _selectedMembers = [member];
          });
        }
      }
    }
  }

  Future<void> loadPriorities() async {
    _priorities = await ApiService.getPriorities();
    setState(() {});
  }

  void _updateDueDate(Priority p) {
    final avgHours = ((p.minHours + p.maxHours) / 2);
    final newDate = DateTime.now().add(Duration(minutes: (avgHours * 60).round()));

    setState(() {
      _selectedPriority = p;
      _priority = p.title.toLowerCase();
      _dueDate = newDate;
    });
  }

  Future<void> _loadClients() async {
    try {
      final data = await ApiService.getClients();
      setState(() {
        _clientList = data.map((json) => Clients.fromJson(json)).toList();
      });
    } catch (e) {
      print('Error loading clients: $e');
    }
  }

  void _toggleMemberSelection(TeamMember member) {
    setState(() {
      if (_selectedMembers.contains(member)) {
        _selectedMembers.remove(member);
      } else {
        _selectedMembers.add(member);
      }
    });
  }

  void _removeSelectedMember(TeamMember member) {
    setState(() {
      _selectedMembers.remove(member);
    });
  }

  Future<void> _assignTask() async {
  setState(() {
    _showClientError = false;
  });

  if (_titleController.text.trim().isEmpty) {
    _showSnackBar('Please enter task title', Colors.red);
    return;
  }

  if (_selectedMembers.isEmpty) {
    _showSnackBar('Please select at least one team member', Colors.red);
    return;
  }

  if (_selectedClient == null) {
    setState(() => _showClientError = true);
    _showSnackBar('Please select a client', Colors.red);
    return;
  }

  setState(() => _isSubmitting = true);

  final managerId = ApiService.employeeId;
  if (managerId == null) {
    setState(() => _isSubmitting = false);
    return;
  }

  List<String> assignedToIds = _selectedMembers.map((member) => member.employeeId).toList();

  final result = await ApiService.assignTaskToMultiple(
    assignedBy: managerId,
    assignedToList: assignedToIds,
    taskTitle: _titleController.text.trim(),
    taskDescription: _descriptionController.text.trim(),
    dueDate: _dueDate,
    priority: _priority,
    taskPreference: _taskpreference,
    client: _selectedClient!.clientCode,
  );

  setState(() => _isSubmitting = false);

  if (result['success'] == true) {
    Navigator.pop(context);
    _showSnackBar(
      'Task assigned to ${_selectedMembers.length} member(s) successfully',
      Colors.green,
    );
  } else {
    _showSnackBar(
      result['error'] ?? 'Failed to assign task to members',
      Colors.red,
    );
  }
}

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Assign Task',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue[700],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Selected Members Chips
                  if (_selectedMembers.isNotEmpty) ...[
                    Text(
                      'Selected Members (${_selectedMembers.length})',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey[50],
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _selectedMembers.map((member) {
                          return Chip(
                            label: Text('${member.name}'),
                            deleteIcon: Icon(Icons.close, size: 18),
                            onDeleted: () => _removeSelectedMember(member),
                            backgroundColor: Colors.blue[50],
                            labelStyle: TextStyle(color: Colors.blue[800]),
                            deleteIconColor: Colors.blue[800],
                          );
                        }).toList(),
                      ),
                    ),
                    SizedBox(height: 20),
                  ],

                  // Assign To Section
                  Text(
                    'Assign To',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  
                  // Search Field
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search members by name, ID, or department',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      prefixIcon: Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _filterMembers();
                              },
                            )
                          : null,
                    ),
                  ),
                  SizedBox(height: 8),

                  // Members List with Checkboxes
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListView.builder(
                      itemCount: _filteredMembers.length,
                      itemBuilder: (context, index) {
                        final member = _filteredMembers[index];
                        final isSelected = _selectedMembers.contains(member);
                        
                        return CheckboxListTile(
                          title: Text(
                            member.name,
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            '${member.employeeId} • ${member.department}',
                            style: TextStyle(fontSize: 12),
                          ),
                          value: isSelected,
                          onChanged: (_) => _toggleMemberSelection(member),
                          secondary: CircleAvatar(
                            backgroundColor: isSelected ? Colors.blue : Colors.grey,
                            child: Text(
                              member.name[0].toUpperCase(),
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          activeColor: Colors.blue,
                        );
                      },
                    ),
                  ),

                  SizedBox(height: 20),

                  // Task Title
                  Text(
                    'Task Title',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      hintText: 'Enter task title',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                  ),

                  SizedBox(height: 20),

                  // Priority
                  Text(
                    'Priority',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  DropdownButtonFormField<Priority>(
                    value: _selectedPriority,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                    items: _priorities.map((p) {
                      return DropdownMenuItem(
                        value: p,
                        child: Text(
                          "${p.title.toUpperCase()} (${p.minHours}-${p.maxHours} hrs)",
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        _updateDueDate(value);
                      }
                    },
                  ),

                  SizedBox(height: 20),

                  // Task Preference
                  Text(
                    'Task Preference',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _taskpreference,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                    items: [
                      DropdownMenuItem(value: 'office', child: Text('Office')),
                      DropdownMenuItem(
                        value: 'client',
                        child: Text('Client Side'),
                      ),
                      DropdownMenuItem(
                        value: 'home',
                        child: Text('Work From Home'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _taskpreference = value!;
                      });
                    },
                  ),

                  SizedBox(height: 20),

                  // Clients
                  Text(
                    'Clients',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _showClientError && _selectedClient == null
                            ? Colors.red 
                            : Colors.grey[300]!,
                        width: _showClientError && _selectedClient == null ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey[100],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Clients>(
                        isExpanded: true,
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        hint: Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'Select Client',
                            style: TextStyle(
                              color: _showClientError && _selectedClient == null 
                                  ? Colors.red[700] 
                                  : Colors.grey[600],
                            ),
                          ),
                        ),
                        value: _selectedClient,
                        items: _clientList.map((client) {
                          return DropdownMenuItem<Clients>(
                            value: client,
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 9),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        client.clientName,
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        "  ●  ",
                                        style: TextStyle(fontSize: 9),
                                      ),
                                      Text(
                                        client.clientCode,
                                        style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (Clients? value) {
                          setState(() {
                            _selectedClient = value;
                            if (value != null) {
                              _showClientError = false;
                            }
                          });
                        },
                      ),
                    ),
                  ),
                  if (_showClientError && _selectedClient == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 12),
                      child: Text(
                        'Client is required',
                        style: TextStyle(color: Colors.red[700], fontSize: 12),
                      ),
                    ),

                  SizedBox(height: 20),

                  // Due Date
                  Text('Due Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: _dueDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(Duration(days: 365)),
                      );
                      if (pickedDate == null) return;

                      final pickedTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(_dueDate),
                      );
                      if (pickedTime == null) return;

                      final newDateTime = DateTime(
                        pickedDate.year,
                        pickedDate.month,
                        pickedDate.day,
                        pickedTime.hour,
                        pickedTime.minute,
                      );

                      setState(() => _dueDate = newDateTime);
                    },
                    child: Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.grey[100],
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, color: Colors.blue),
                          SizedBox(width: 12),
                          Text(
                            DateFormat('MMM dd, yyyy  hh:mm a').format(_dueDate),
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 20),

                  // Description
                  Text(
                    'Description',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  TextField(
                    controller: _descriptionController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Enter task description',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                  ),

                  SizedBox(height: 20),

                  // Submit Button
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _assignTask,
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: Colors.blue[700],
                    ),
                    child: _isSubmitting
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.send, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'Assign Task to ${_selectedMembers.length} Member${_selectedMembers.length != 1 ? 's' : ''}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}