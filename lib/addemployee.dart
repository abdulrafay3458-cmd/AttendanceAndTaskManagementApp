import 'package:attendance_app/services/apiservice.dart';
import 'package:attendance_app/models/designation.dart';
import 'package:attendance_app/models/company.dart';
import 'package:attendance_app/models/department.dart';
import 'package:attendance_app/models/teamLead.dart';
import 'package:attendance_app/models/user_roles.dart';
import 'package:attendance_app/models/standardHourGroup.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class AddEmployee extends StatefulWidget {
  final bool isEditing;
  final Map<String, dynamic>? employeeData;
  final VoidCallback? onEmployeeUpdated;

  const AddEmployee({
    super.key,
    this.isEditing = false,
    this.employeeData,
    this.onEmployeeUpdated,
  });

  @override
  State<AddEmployee> createState() => _AddEmployeeState();
}

enum EmployeeType { permanent, probation, internship }

class _AddEmployeeState extends State<AddEmployee> {
  bool isUserActive = true;

  // ---------- Roles (multi-select) ----------
  bool _loadingRoles = false;
  List<UserRole> _roles = [];
  final Set<String> _selectedRoleIds = {}; // lowercase GUIDs

  List<Department> _departments = [];
  Department? _selectedDepartment;
  bool _loadingDepartments = true;

  List<TeamLead> _teamLeads = [];
  TeamLead? _selectedTeamLeads;
  bool _loadingTeamLeads = true;

  bool _selectedStatus = true;
  List<Designation> _designations = [];
  Designation? _selectedDesignation;
  bool _loadingDesignations = true;

  List<StandardHourGroup> _standardHours = [];
  StandardHourGroup? _selectedStandardHours;
  bool _loadingStandardHours = true;

  List<Company> _companies = [];
  Company? _selectedCompany;
  bool _loadingCompanies = true;

  bool _formSubmitted = false;
  final _formKey = GlobalKey<FormState>();
  final _employeeId = TextEditingController();
  final _zkUserId = TextEditingController();
  final _employeeFirstName = TextEditingController();
  final _employeeLastName = TextEditingController();
  final _employeeCompanyCode = TextEditingController();
  final _employeeEmail = TextEditingController();
  final _employeePhone = TextEditingController();
  final _employeeDepartment = TextEditingController();
  final _employeeLeadCode = TextEditingController();
  final _employeeDesignation = TextEditingController();
  final _employeeStandardHourGroup = TextEditingController();
  final _status = TextEditingController();
  DateTime? _employeeJoinDate;

  @override
  void initState() {
    super.initState();
    _loadDesignations();
    _fetchCompanies();
    _fetchDepartments();
    _fetchTeamLeads();
    _loadRoles();
    _loadStandardHoursGroup();

    // If in edit mode, populate fields with existing data
    if (widget.isEditing && widget.employeeData != null) {
      _populateFormWithExistingData();
    }
  }

  void _populateFormWithExistingData() {
    final data = widget.employeeData!;

    debugPrint('Employee Data received: $data');

    _employeeId.text = data['employeeId'] ?? data['EmployeeId'] ?? '';
    _zkUserId.text = data['zkUserId'] ?? data['ZkUserId'] ?? '';
    _employeeFirstName.text = data['firstName'] ?? data['FirstName'] ?? '';
    _employeeLastName.text = data['lastName'] ?? data['LastName'] ?? '';
    _employeeEmail.text = data['email'] ?? data['Email'] ?? '';
    _employeePhone.text = data['phone'] ?? data['Phone'] ?? '';

    _selectedStatus = data['isActive'] ?? data['IsActive'] ?? false;

    final appUserFlag = data['isAppUser'];
    isUserActive = appUserFlag == true || appUserFlag == 1;

    _employeeDesignation.text = (data['designationCode'] ?? '').toString();

    if (data['joinDate'] != null) {
      try {
        _employeeJoinDate = DateTime.parse(data['joinDate'].toString());
      } catch (e) {
        debugPrint('Error parsing joinDate: $e');
        _employeeJoinDate = null;
      }
    }
  }

  @override
  void dispose() {
    _employeeId.dispose();
    _zkUserId.dispose();
    _employeeFirstName.dispose();
    _employeeLastName.dispose();
    _employeeCompanyCode.dispose();
    _employeeEmail.dispose();
    _employeePhone.dispose();
    _employeeDepartment.dispose();
    _employeeLeadCode.dispose();
    _employeeDesignation.dispose();
    _employeeStandardHourGroup.dispose();
    _status.dispose();
    super.dispose();
  }

  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter $fieldName';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter email';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter phone number';
    }
    if (value.trim().length < 11) {
      return 'Please enter a valid phone number';
    }
    return null;
  }

  List<UserRole> get _selectedRoleObjects => _roles
      .where((r) => _selectedRoleIds.contains(r.id.toLowerCase()))
      .toList();

  String get _selectedRoleIdsCsv =>
      _selectedRoleObjects.map((r) => r.id).join(',');

  String get _selectedRoleNamesCsv =>
      _selectedRoleObjects.map((r) => r.name).join(',');

  Future<void> _loadDesignations() async {
    try {
      final data = await ApiService.getDesignations();
      setState(() {
        _designations = data;
        _loadingDesignations = false;
        if (widget.isEditing && widget.employeeData != null) {
          final dynamic rawDesignationCode =
              widget.employeeData!['designationCode'];

          final int? designationCode = rawDesignationCode is int
              ? rawDesignationCode
              : int.tryParse(rawDesignationCode?.toString() ?? '');

          if (designationCode != null && _designations.isNotEmpty) {
            _selectedDesignation = _designations.firstWhere(
              (d) => d.code == designationCode,
              orElse: () => _designations.first,
            );
          }
        }
      });
    } catch (e) {
      setState(() => _loadingDesignations = false);
    }
  }

  Future<void> _loadStandardHoursGroup() async {
    try {
      final data = await ApiService.getStandardHours();
      setState(() {
        _standardHours = data;
        _loadingStandardHours = false;
        if (widget.isEditing && widget.employeeData != null) {
          final dynamic rawstandardHours =
              widget.employeeData!['standardHourCode'];

          final int? standardHourGroupCode = rawstandardHours is int
              ? rawstandardHours
              : int.tryParse(rawstandardHours?.toString() ?? '');

          if (standardHourGroupCode != null && _standardHours.isNotEmpty) {
            _selectedStandardHours = _standardHours.firstWhere(
              (d) => d.id == standardHourGroupCode,
              orElse: () => _standardHours.first,
            );
          }
        }
      });
    } catch (e) {
      setState(() => _loadingStandardHours = false);
    }
  }

  Future<void> _fetchCompanies() async {
    try {
      final data = await ApiService.getCompanies();
      setState(() {
        _companies = data
            .map<Company>((json) => Company.fromJson(json))
            .toList();
        _loadingCompanies = false;

        if (widget.isEditing && widget.employeeData != null) {
          final code = widget.employeeData!['companyCode'] ??
              widget.employeeData!['CompanyCode'];
          _selectedCompany = _companies.firstWhere(
            (c) => c.code == code,
            orElse: () => _companies.first,
          );
        }
      });
    } catch (e) {
      setState(() => _loadingCompanies = false);
      debugPrint('Error fetching companies: $e');
    }
  }

  Future<void> _loadRoles() async {
    try {
      setState(() => _loadingRoles = true);

      final data = await ApiService.getUserRoles();
      final roles =
          data.map<UserRole>((json) => UserRole.fromJson(json)).toList();

      _selectedRoleIds.clear();

      if (widget.isEditing && widget.employeeData != null) {
        final raw =
            widget.employeeData!['roleId'] ?? widget.employeeData!['RoleId'];

        if (raw != null && raw.toString().trim().isNotEmpty) {
          final ids = raw
              .toString()
              .split(',')
              .map((s) => s.trim().toLowerCase())
              .where((s) => s.isNotEmpty);
          _selectedRoleIds.addAll(ids);
        }
      }

      setState(() {
        _roles = roles;
        _loadingRoles = false;
      });
    } catch (e) {
      setState(() => _loadingRoles = false);
      debugPrint('Error fetching roles: $e');
    }
  }

  Future<void> _fetchDepartments() async {
    try {
      final data = await ApiService.getDepartments();
      setState(() {
        _departments = data
            .map<Department>((json) => Department.fromJson(json))
            .toList();
        _loadingDepartments = false;

        if (widget.isEditing && widget.employeeData != null) {
          final code = widget.employeeData!['department'] ??
              widget.employeeData!['Department'];
          _selectedDepartment = _departments.firstWhere(
            (d) => d.code == code,
            orElse: () => _departments.first,
          );
        }
      });
    } catch (e) {
      setState(() => _loadingDepartments = false);
      debugPrint('Error fetching departments: $e');
    }
  }

  Future<void> _fetchTeamLeads() async {
    try {
      final data = await ApiService.getTeamLeads();
      setState(() {
        _teamLeads = data
            .map<TeamLead>((json) => TeamLead.fromJson(json))
            .toList();
        _loadingTeamLeads = false;

        if (widget.isEditing && widget.employeeData != null) {
          final code = widget.employeeData!['leadCode'] ??
              widget.employeeData!['LeadCode'];
          _selectedTeamLeads = _teamLeads.firstWhere(
            (d) => d.code == code,
            orElse: () => _teamLeads.first,
          );
        }
      });
    } catch (e) {
      setState(() => _loadingTeamLeads = false);
      debugPrint('Error fetching team Leads: $e');
    }
  }

  Future<void> _selectJoinDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _employeeJoinDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _employeeJoinDate = picked;
      });
    }
  }

  Future<void> _showRolePicker() async {
    final tempSelected = Set<String>.from(_selectedRoleIds);

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Select User Roles'),
              content: SizedBox(
                width: double.maxFinite,
                child: _roles.isEmpty
                    ? const SizedBox(
                        height: 80,
                        child: Center(child: Text('No roles available')),
                      )
                    : ListView(
                        shrinkWrap: true,
                        children: _roles.map((r) {
                          final key = r.id.toLowerCase();
                          final checked = tempSelected.contains(key);
                          return CheckboxListTile(
                            title: Text(r.name),
                            value: checked,
                            onChanged: (v) {
                              setDialogState(() {
                                if (v == true) {
                                  tempSelected.add(key);
                                } else {
                                  tempSelected.remove(key);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _selectedRoleIds
                        ..clear()
                        ..addAll(tempSelected);
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _addEmp() async {
    final bool userStatus = isUserActive ? true : false;

    if (_employeeJoinDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select join date'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (isUserActive && _selectedRoleIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one user role'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _formSubmitted = true);

    final managerId = ApiService.employeeId;

    if (managerId == null) {
      setState(() => _formSubmitted = false);
      return;
    }

    final roleIdCsv = isUserActive && _selectedRoleIds.isNotEmpty
        ? _selectedRoleIdsCsv
        : null;
    final roleNamesCsv = isUserActive ? _selectedRoleNamesCsv : '';

    try {
      final response = widget.isEditing
          ? await ApiService.editEmp(
              empCode: _employeeId.text.trim(),
              managerId: _selectedTeamLeads?.code ?? '',
              newEmpId: _employeeId.text.trim(),
              zkUserId: _zkUserId.text.trim(),
              firstName: _employeeFirstName.text.trim(),
              lastName: _employeeLastName.text.trim(),
              companyCode: _selectedCompany?.code ?? '',
              email: _employeeEmail.text.trim(),
              phone: _employeePhone.text.trim(),
              department: _selectedDepartment?.code ?? '',
              designation: _selectedDesignation?.code ?? 0,
              isActive: _selectedStatus,
              joinDate: _employeeJoinDate!.toLocal(),
              role: roleNamesCsv,
              userStatus: userStatus,
              roleId: roleIdCsv,
              standardHourCode: _selectedStandardHours?.id ?? 0,
            )
          : await ApiService.addEmp(
              managerId: _selectedTeamLeads?.code ?? '',
              zkUserId: _zkUserId.text.trim(),
              firstName: _employeeFirstName.text.trim(),
              lastName: _employeeLastName.text.trim(),
              companyCode: _selectedCompany?.code ?? '',
              email: _employeeEmail.text.trim(),
              phone: _employeePhone.text.trim(),
              department: _selectedDepartment?.code ?? '',
              designation: _selectedDesignation?.code ?? 0,
              isActive: _selectedStatus,
              joinDate: _employeeJoinDate!.toLocal(),
              role: roleNamesCsv,
              userStatus: userStatus,
              roleId: roleIdCsv,
              standardHourCode: _selectedStandardHours?.id ?? 0,
            );

      if (mounted && response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEditing
                  ? 'Employee updated successfully!'
                  : 'Employee added successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );

        if (widget.onEmployeeUpdated != null) {
          widget.onEmployeeUpdated!();
        }

        await Future.delayed(const Duration(milliseconds: 100));

        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        throw Exception(response['error'] ?? 'Operation failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _formSubmitted = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing ? 'Edit Employee' : 'Add Employee',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue[700],
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Employee Code (Hidden)
                  Visibility(
                    visible: false,
                    child: TextFormField(
                      controller: _employeeId,
                      validator: (value) =>
                          _validateRequired(value, 'employee code'),
                      decoration: InputDecoration(
                        labelText: 'Employee Code *',
                        prefixIcon: const Icon(
                          Icons.badge_outlined,
                          color: Colors.blue,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      textInputAction: TextInputAction.next,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Machine Id
                  TextFormField(
                    controller: _zkUserId,
                    validator: (value) =>
                        _validateRequired(value, 'machine id'),
                    decoration: InputDecoration(
                      labelText: 'Machine Id *',
                      prefixIcon: const Icon(
                        Icons.fingerprint,
                        color: Colors.blue,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),

                  // First Name
                  TextFormField(
                    controller: _employeeFirstName,
                    validator: (value) =>
                        _validateRequired(value, 'first name'),
                    decoration: InputDecoration(
                      labelText: 'First Name *',
                      prefixIcon: const Icon(
                        Icons.person_outline_outlined,
                        color: Colors.blue,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),

                  // Last Name
                  TextFormField(
                    controller: _employeeLastName,
                    validator: (value) =>
                        _validateRequired(value, 'last name'),
                    decoration: InputDecoration(
                      labelText: 'Last Name *',
                      prefixIcon: const Icon(
                        Icons.person_outline_outlined,
                        color: Colors.blue,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),

                  // Company Dropdown
                  _loadingCompanies
                      ? const Center(child: CircularProgressIndicator())
                      : DropdownButtonFormField<Company>(
                          value: _selectedCompany,
                          validator: (value) =>
                              value == null ? 'Please select company' : null,
                          decoration: InputDecoration(
                            labelText: 'Company *',
                            prefixIcon: const Icon(
                              Icons.business_outlined,
                              color: Colors.blue,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          items: _companies.map((c) {
                            return DropdownMenuItem(
                              value: c,
                              child: Text(c.name),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedCompany = value;
                            });
                          },
                        ),
                  const SizedBox(height: 16),

                  // Email
                  TextFormField(
                    controller: _employeeEmail,
                    validator: _validateEmail,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email *',
                      prefixIcon: const Icon(
                        Icons.email_outlined,
                        color: Colors.blue,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),

                  // Phone
                  TextFormField(
                    controller: _employeePhone,
                    validator: _validatePhone,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(11),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Phone *',
                      prefixIcon: const Icon(
                        Icons.phone_android_outlined,
                        color: Colors.blue,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),

                  // Team Leads
                  _loadingTeamLeads
                      ? const Center(child: CircularProgressIndicator())
                      : DropdownButtonFormField<TeamLead>(
                          isExpanded: true,
                          value: _selectedTeamLeads,
                          validator: (value) =>
                              value == null ? 'Please select team lead' : null,
                          decoration: InputDecoration(
                            labelText: 'Lead *',
                            prefixIcon: const Icon(
                              Icons.business_outlined,
                              color: Colors.blue,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          items: _teamLeads.map((d) {
                            return DropdownMenuItem(
                              value: d,
                              child: Text(
                                d.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedTeamLeads = value;
                            });
                          },
                        ),
                  const SizedBox(height: 16),

                  // Department
                  _loadingDepartments
                      ? const Center(child: CircularProgressIndicator())
                      : DropdownButtonFormField<Department>(
                          isExpanded: true,
                          value: _selectedDepartment,
                          validator: (value) =>
                              value == null ? 'Please select department' : null,
                          decoration: InputDecoration(
                            labelText: 'Department *',
                            prefixIcon: const Icon(
                              Icons.business_outlined,
                              color: Colors.blue,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          items: _departments.map((d) {
                            return DropdownMenuItem(
                              value: d,
                              child: Text(
                                d.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedDepartment = value;
                            });
                          },
                        ),
                  const SizedBox(height: 16),

                  // Designation
                  _loadingDesignations
                      ? const Center(child: CircularProgressIndicator())
                      : DropdownButtonFormField<Designation>(
                          isExpanded: true,
                          value: _selectedDesignation,
                          validator: (value) => value == null
                              ? 'Please select designation'
                              : null,
                          decoration: InputDecoration(
                            labelText: 'Designation *',
                            prefixIcon: const Icon(
                              Icons.cases_outlined,
                              color: Colors.blue,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          items: _designations.map((d) {
                            return DropdownMenuItem(
                              value: d,
                              child: Text(
                                d.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedDesignation = value;
                              _employeeDesignation.text = value?.name ?? '';
                            });
                          },
                        ),
                  const SizedBox(height: 16),

                  // Standard Hours
                  _loadingStandardHours
                      ? const Center(child: CircularProgressIndicator())
                      : DropdownButtonFormField<StandardHourGroup>(
                          isExpanded: true,
                          value: _selectedStandardHours,
                          validator: (value) =>
                              value == null ? 'Please select Hour Group' : null,
                          decoration: InputDecoration(
                            labelText: 'Hour Group *',
                            prefixIcon: const Icon(
                              Icons.cases_outlined,
                              color: Colors.blue,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          items: _standardHours.map((s) {
                            return DropdownMenuItem(
                              value: s,
                              child: Text(
                                s.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedStandardHours = value;
                              _employeeStandardHourGroup.text =
                                  value?.name ?? '';
                            });
                          },
                        ),
                  const SizedBox(height: 16),

                  // Join Date Picker
                  InkWell(
                    onTap: _selectJoinDate,
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Join Date *',
                        prefixIcon: const Icon(
                          Icons.calendar_today_outlined,
                          color: Colors.blue,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        errorText: _employeeJoinDate == null && _formSubmitted
                            ? 'Please select join date'
                            : null,
                      ),
                      child: Text(
                        _employeeJoinDate == null
                            ? 'Select date'
                            : DateFormat('dd/MM/yyyy')
                                .format(_employeeJoinDate!),
                        style: TextStyle(
                          color: _employeeJoinDate == null
                              ? Colors.grey
                              : Colors.black,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Active Status Switch
                  SwitchListTile(
                    title: const Text('Is Active Employee?'),
                    subtitle: Text(
                      _selectedStatus == true ? 'Active' : 'Inactive',
                    ),
                    value: _selectedStatus,
                    activeTrackColor:
                        const Color.fromARGB(255, 33, 150, 243).withOpacity(1),
                    onChanged: (value) {
                      setState(() {
                        _selectedStatus = value;
                      });
                    },
                  ),

                  if (_selectedStatus == true)
                    CheckboxListTile(
                      title: const Text('Is App User?'),
                      value: isUserActive,
                      onChanged: (value) {
                        setState(() {
                          isUserActive = value ?? false;
                          if (!isUserActive) {
                            _selectedRoleIds.clear();
                          }
                        });
                      },
                    ),

                  const SizedBox(height: 20),

                  // User Role (multi-select)
                  _loadingRoles
                      ? const Center(child: CircularProgressIndicator())
                      : FormField<Set<String>>(
                          initialValue: _selectedRoleIds,
                          validator: (_) {
                            if (isUserActive && _selectedRoleIds.isEmpty) {
                              return 'Please select at least one user role';
                            }
                            return null;
                          },
                          builder: (state) {
                            final displayText = _selectedRoleIds.isEmpty
                                ? 'Select roles'
                                : _selectedRoleObjects
                                    .map((r) => r.name)
                                    .join(', ');

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                InkWell(
                                  onTap: isUserActive
                                      ? () async {
                                          await _showRolePicker();
                                          state.didChange(_selectedRoleIds);
                                        }
                                      : null,
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      labelText: 'User Role(s) *',
                                      prefixIcon: const Icon(
                                        Icons.person_outline,
                                        color: Colors.blue,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                      filled: true,
                                      fillColor: isUserActive
                                          ? Colors.white
                                          : Colors.grey.shade200,
                                      errorText: state.errorText,
                                      suffixIcon: const Icon(
                                        Icons.arrow_drop_down,
                                      ),
                                    ),
                                    child: Text(
                                      displayText,
                                      style: TextStyle(
                                        color: _selectedRoleIds.isEmpty
                                            ? Colors.grey
                                            : Colors.black,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                  const SizedBox(height: 20),

                  // Submit Button
                  ElevatedButton(
                    onPressed: _formSubmitted ? null : _addEmp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                    child: _formSubmitted
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add),
                              const SizedBox(width: 10),
                              Text(
                                widget.isEditing
                                    ? 'Update Employee'
                                    : 'Add Employee',
                              ),
                            ],
                          ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}