import 'package:attendance_app/services/clients.dart';
import 'package:attendance_app/services/teammember.dart';
import 'package:flutter/material.dart';
import 'package:attendance_app/services/apiservice.dart';
import 'package:intl/intl.dart';

class EditTaskScreen extends StatefulWidget {
  final Map<String, dynamic> taskData;

  const EditTaskScreen({super.key, required this.taskData});

  @override
  _EditTaskScreenState createState() => _EditTaskScreenState();
}

class _EditTaskScreenState extends State<EditTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _dueDateController;
  final TextEditingController _searchController = TextEditingController();

  DateTime? _selectedDueDate;
  String _selectedPriority = 'medium';
  String _selectedPreference = 'office';
  String? _selectedClient;
  String? _selectedClientName;

  bool _isLoading = false;
  bool _isSaving = false;
  bool _loadingClients = false;

  List<TeamMember> _teamMembers = [];
  List<TeamMember> _filteredMembers = [];
  List<TeamMember> _selectedMembers = [];
  List<Clients> _clientList = [];

  final List<String> _priorityOptions = ['low', 'medium', 'high'];

  @override
  void initState() {
    super.initState();
    _initializeData();
    _loadTeamMembers();
    _loadClients();
    _searchController.addListener(_filterMembers);
  }

  void _initializeData() {
    _titleController = TextEditingController(
      text: widget.taskData['taskTitle'] ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.taskData['taskDescription'] ?? '',
    );
    _dueDateController = TextEditingController();

    _selectedPriority = widget.taskData['priority']?.toString() ?? 'medium';
    _selectedPreference =
        (widget.taskData['taskPreference']?.toString().isNotEmpty == true)
        ? widget.taskData['taskPreference']!.toString()
        : 'office';

    _selectedClient = widget.taskData['clientCode']?.toString();
    _selectedClientName = widget.taskData['clientName']?.toString();
    print('Selected Client: $_selectedClient');

    if (widget.taskData['dueDate'] != null) {
      if (widget.taskData['dueDate'] is String) {
        _selectedDueDate = DateTime.parse(widget.taskData['dueDate']);
      } else if (widget.taskData['dueDate'] is DateTime) {
        _selectedDueDate = widget.taskData['dueDate'];
      }
      if (_selectedDueDate != null) {
        _dueDateController.text = DateFormat(
          'yyyy-MM-dd',
        ).format(_selectedDueDate!);
      }
    }
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

      // Pre-select the member that was already assigned to this task
      final assignedToId = widget.taskData['assignedTo']?.toString();
      if (assignedToId != null && assignedToId.isNotEmpty) {
        final existing = data.firstWhere(
          (m) => m.employeeId == assignedToId,
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
            leadCode: '',
          ),
        );

        if (existing.employeeId.isNotEmpty) {
          setState(() {
            _selectedMembers = [existing];
          });
        }
      }
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadClients() async {
    setState(() => _loadingClients = true);
    try {
      final data = await ApiService.getClients();
      setState(() {
        _clientList = data.map((json) => Clients.fromJson(json)).toList();
      });
    } catch (e) {
      print('Error loading clients: $e');
    } finally {
      setState(() => _loadingClients = false);
    }
  }

  void _filterMembers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredMembers = _teamMembers.where((member) {
        return member.name.toLowerCase().contains(query) ||
            member.employeeId.toLowerCase().contains(query) ||
            member.department.toLowerCase().contains(query);
      }).toList();
    });
  }

  void _toggleMemberSelection(TeamMember member) {
    setState(() {
      if (_selectedMembers.any((m) => m.employeeId == member.employeeId)) {
        _selectedMembers.removeWhere(
          (m) => m.employeeId == member.employeeId,
        );
      } else {
        _selectedMembers.add(member);
      }
    });
  }

  void _removeSelectedMember(TeamMember member) {
    setState(() {
      _selectedMembers.removeWhere((m) => m.employeeId == member.employeeId);
    });
  }

  Future<void> _selectDueDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate ?? DateTime.now().add(Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (picked != null && picked != _selectedDueDate) {
      setState(() {
        _selectedDueDate = picked;
        _dueDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _updateTask() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select at least one team member'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final assignedToIds =
          _selectedMembers.map((m) => m.employeeId).toList();

      final updatedTask = {
        'taskId': widget.taskData['taskId'],
        'assignedBy': widget.taskData['assignedBy'],
        'assignedTo': assignedToIds, // <-- now a LIST
        'taskTitle': _titleController.text.trim(),
        'taskDescription': _descriptionController.text.trim(),
        'taskPreference': _selectedPreference,
        'dueDate': _selectedDueDate?.toIso8601String(),
        'priority': _selectedPriority,
        'clientCode': _selectedClient,
      };

      final success = await ApiService.updateTask(updatedTask);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Task updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update task'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error updating task: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An error occurred: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _dueDateController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildHiddenInfoSection() {
    return Card(
      elevation: 1,
      margin: EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Task Information',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: Colors.blue[700],
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.info, size: 16, color: Colors.grey[600]),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      Text(
                        (widget.taskData['status'] ?? 'N/A')
                            .replaceAll('_', ' ')
                            .toUpperCase(),
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hours Worked',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      Text(
                        '${widget.taskData['totalHoursWorked']?.toStringAsFixed(1) ?? '0.0'} hours',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person_outline, size: 16, color: Colors.grey[600]),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Assigned By',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      Text(
                        widget.taskData['assignedByName'] ?? 'N/A',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_month, size: 16, color: Colors.grey[600]),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Assigned Date',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      Text(
                        widget.taskData['assignedDate'] != null
                            ? DateFormat('MMM dd, yyyy').format(
                                DateTime.parse(widget.taskData['assignedDate']),
                              )
                            : 'N/A',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Task'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue[700],
        elevation: 1,
        actions: [
          if (_isSaving)
            Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHiddenInfoSection(),
                    SizedBox(height: 8),

                    // ---------------- TASK TITLE ----------------
                    Text(
                      'Task Title *',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 8),
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        hintText: 'Enter task title',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter task title';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: 16),

                    // ---------------- DESCRIPTION ----------------
                    Text(
                      'Description',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 8),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        hintText: 'Enter task description',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                      ),
                      maxLines: 4,
                      keyboardType: TextInputType.multiline,
                    ),
                    SizedBox(height: 16),

                    // ---------------- ASSIGN TO (MULTI) ----------------
                    Text(
                      'Assign To *',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 8),

                    // Selected member chips
                    if (_selectedMembers.isNotEmpty) ...[
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey[50],
                        ),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _selectedMembers.map((member) {
                            return Chip(
                              label: Text(member.name),
                              deleteIcon: Icon(Icons.close, size: 18),
                              onDeleted: () => _removeSelectedMember(member),
                              backgroundColor: Colors.blue[50],
                              labelStyle: TextStyle(color: Colors.blue[800]),
                              deleteIconColor: Colors.blue[800],
                            );
                          }).toList(),
                        ),
                      ),
                      SizedBox(height: 8),
                    ],

                    // Search field
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search members by name, ID, or department',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
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

                    // Members list with checkboxes
                    Container(
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _filteredMembers.isEmpty
                          ? Center(
                              child: Text(
                                'No members found',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _filteredMembers.length,
                              itemBuilder: (context, index) {
                                final member = _filteredMembers[index];
                                final isSelected = _selectedMembers.any(
                                  (m) => m.employeeId == member.employeeId,
                                );

                                return CheckboxListTile(
                                  title: Text(
                                    member.name,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  subtitle: Text(
                                    '${member.employeeId} • ${member.department}',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  value: isSelected,
                                  onChanged: (_) =>
                                      _toggleMemberSelection(member),
                                  secondary: CircleAvatar(
                                    backgroundColor: isSelected
                                        ? Colors.blue
                                        : Colors.grey,
                                    child: Text(
                                      member.name.isNotEmpty
                                          ? member.name[0].toUpperCase()
                                          : '?',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  activeColor: Colors.blue,
                                );
                              },
                            ),
                    ),
                    SizedBox(height: 16),

                    // ---------------- PRIORITY ----------------
                    Text(
                      'Priority *',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[400]!),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedPriority,
                          isExpanded: true,
                          items: _priorityOptions.map((priority) {
                            return DropdownMenuItem<String>(
                              value: priority,
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  priority.toUpperCase(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _selectedPriority = newValue;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    SizedBox(height: 16),

                    // ---------------- TASK PREFERENCE ----------------
                    Text(
                      'Task Preference',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[400]!),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedPreference,
                          isExpanded: true,
                          items: [
                            DropdownMenuItem(
                              value: 'office',
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text('Office'),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'client',
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text('Client Side'),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'home',
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text('Work From Home'),
                              ),
                            ),
                          ],
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                _selectedPreference = newValue;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    SizedBox(height: 16),

                    // ---------------- DUE DATE ----------------
                    Text(
                      'Due Date',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 8),
                    TextFormField(
                      controller: _dueDateController,
                      decoration: InputDecoration(
                        hintText: 'Select due date',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      readOnly: true,
                      onTap: () => _selectDueDate(context),
                    ),
                    SizedBox(height: 16),

                    // ---------------- CLIENT ----------------
                    Text(
                      'Client',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                    SizedBox(height: 8),
                    _loadingClients
                        ? Container(
                            padding: EdgeInsets.all(16),
                            alignment: Alignment.center,
                            child: CircularProgressIndicator(),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[400]!),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedClient ?? '',
                                isExpanded: true,
                                hint: Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12),
                                  child: Text('Select client'),
                                ),
                                items: _buildClientDropdownItems(),
                                onChanged: (String? newValue) {
                                  setState(() {
                                    _selectedClient = newValue;
                                    if (newValue != null && newValue.isNotEmpty) {
                                      final client = _clientList.firstWhere(
                                        (c) => c.clientCode == newValue,
                                        orElse: () => _clientList.first,
                                      );
                                      _selectedClientName = client.clientName;
                                    } else {
                                      _selectedClient = '';
                                      _selectedClientName = null;
                                    }
                                  });
                                },
                              ),
                            ),
                          ),
                    SizedBox(height: 24),

                    // ---------------- UPDATE BUTTON ----------------
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _updateTask,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 24,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 1,
                          shadowColor: Colors.blue[700]!.withOpacity(0.2),
                        ),
                        child: _isSaving
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Updating Task...',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.save, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Update Task',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    SizedBox(height: 12),

                    // ---------------- CANCEL BUTTON ----------------
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _isSaving
                            ? null
                            : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey[700],
                          padding: EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 24,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: Colors.grey[300]!,
                            width: 1.5,
                          ),
                          backgroundColor: Colors.grey[50],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.close, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Cancel',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  List<DropdownMenuItem<String>> _buildClientDropdownItems() {
    final items = <DropdownMenuItem<String>>[];

    items.add(
      DropdownMenuItem<String>(
        value: '',
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('No client'),
        ),
      ),
    );

    final seenCodes = <String>{};
    for (final client in _clientList) {
      final code = client.clientCode;
      if (code.isNotEmpty && !seenCodes.contains(code)) {
        seenCodes.add(code);
        items.add(
          DropdownMenuItem<String>(
            value: code,
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    client.clientName.isNotEmpty
                        ? client.clientShortName != null &&
                                  client.clientShortName!.isNotEmpty
                              ? '${client.clientName} (${client.clientShortName!})'
                              : client.clientName
                        : 'Unknown',
                    style: TextStyle(fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    return items;
  }
}