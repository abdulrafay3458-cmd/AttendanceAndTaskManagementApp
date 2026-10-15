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

const _kBg = Color(0xFFF5F6FA);
const _kInk = Color(0xFF1F2430);
const _kMuted = Color(0xFF7A8194);
const _kLine = Color(0xFFE6E8F0);
const _kGreen = Color(0xFF22A06B);
const _kRed = Color(0xFFE5484D);

final _baseColor = const Color.fromARGB(255, 12, 86, 147);
final _bannerGradient = LinearGradient(
  colors: [_baseColor, _baseColor.withOpacity(0.72)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

final _softShadow = [
  BoxShadow(
    color: const Color(0xFF1F2430).withOpacity(0.06),
    blurRadius: 18,
    offset: const Offset(0, 6),
  ),
];

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

  bool _formSubmitted = false; // request in flight
  bool _triedSubmit = false; // user pressed save at least once
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

    if (widget.isEditing && widget.employeeData != null) {
      _populateFormWithExistingData();
    }
  }

  void _populateFormWithExistingData() {
    final data = widget.employeeData!;

    debugPrint('Employee Data received: $data');

    String s(dynamic v) => v?.toString() ?? '';

    _employeeId.text = s(data['employeeId'] ?? data['EmployeeId']);
    _zkUserId.text = s(data['zkUserId'] ?? data['ZkUserId']);
    _employeeFirstName.text = s(data['firstName'] ?? data['FirstName']);
    _employeeLastName.text = s(data['lastName'] ?? data['LastName']);
    _employeeEmail.text = s(data['email'] ?? data['Email']);
    _employeePhone.text = s(data['phone'] ?? data['Phone']);

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

  String get _selectedRoleNamesCsv =>
      _selectedRoleObjects.map((r) => r.name).join(',');

  List<String>? get _selectedRoleIdList =>
      _selectedRoleIds.isEmpty ? null : _selectedRoleIds.toList();

  Future<void> _loadDesignations() async {
    try {
      final data = await ApiService.getDesignations();
      if (!mounted) return;
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
      if (!mounted) return;
      setState(() => _loadingDesignations = false);
    }
  }

  Future<void> _loadStandardHoursGroup() async {
    try {
      final data = await ApiService.getStandardHours();
      if (!mounted) return;
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
      if (!mounted) return;
      setState(() => _loadingStandardHours = false);
    }
  }

  Future<void> _fetchCompanies() async {
    try {
      final data = await ApiService.getCompanies();
      if (!mounted) return;
      setState(() {
        _companies =
            data.map<Company>((json) => Company.fromJson(json)).toList();
        _loadingCompanies = false;

        if (widget.isEditing &&
            widget.employeeData != null &&
            _companies.isNotEmpty) {
          final code = widget.employeeData!['companyCode'] ??
              widget.employeeData!['CompanyCode'];
          _selectedCompany = _companies.firstWhere(
            (c) => c.code == code,
            orElse: () => _companies.first,
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
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

      if (!mounted) return;
      setState(() {
        _roles = roles;
        _loadingRoles = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingRoles = false);
      debugPrint('Error fetching roles: $e');
    }
  }

  Future<void> _fetchDepartments() async {
    try {
      final data = await ApiService.getDepartments();
      if (!mounted) return;
      setState(() {
        _departments =
            data.map<Department>((json) => Department.fromJson(json)).toList();
        _loadingDepartments = false;

        if (widget.isEditing &&
            widget.employeeData != null &&
            _departments.isNotEmpty) {
          final code = widget.employeeData!['department'] ??
              widget.employeeData!['Department'];
          _selectedDepartment = _departments.firstWhere(
            (d) => d.code == code,
            orElse: () => _departments.first,
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingDepartments = false);
      debugPrint('Error fetching departments: $e');
    }
  }

  Future<void> _fetchTeamLeads() async {
    try {
      final data = await ApiService.getTeamLeads();
      if (!mounted) return;
      setState(() {
        _teamLeads =
            data.map<TeamLead>((json) => TeamLead.fromJson(json)).toList();
        _loadingTeamLeads = false;

        if (widget.isEditing &&
            widget.employeeData != null &&
            _teamLeads.isNotEmpty) {
          final code = widget.employeeData!['leadId'] ??
              widget.employeeData!['LeadId'];
          _selectedTeamLeads = _teamLeads.firstWhere(
            (d) => d.id == code,
            orElse: () => _teamLeads.first,
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
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
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: Colors.blue[700],
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _employeeJoinDate = picked;
      });
    }
  }

  // ------------------------------------------------------------ dialogs
  Widget _dialogHeader(IconData icon, String title, {String? subtitle}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _kInk,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12.5, color: _kMuted),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showRolePicker() async {
    final tempSelected = Set<String>.from(_selectedRoleIds);

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              contentPadding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              title: _dialogHeader(
                Icons.admin_panel_settings_outlined,
                'Select User Roles',
                subtitle: '${tempSelected.length} selected',
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: _roles.isEmpty
                    ? const SizedBox(
                        height: 80,
                        child: Center(
                          child: Text(
                            'No roles available',
                            style: TextStyle(color: _kMuted),
                          ),
                        ),
                      )
                    : ListView(
                        shrinkWrap: true,
                        children: _roles.map((r) {
                          final key = r.id.toLowerCase();
                          final checked = tempSelected.contains(key);
                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: checked
                                  ? Colors.blue.withOpacity(0.08)
                                  : _kBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: checked
                                    ? Colors.blue.withOpacity(0.5)
                                    : _kLine,
                              ),
                            ),
                            child: CheckboxListTile(
                              dense: true,
                              activeColor: Colors.blue[700],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              title: Text(
                                r.name,
                                style: const TextStyle(
                                  color: _kInk,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
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
                            ),
                          );
                        }).toList(),
                      ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(foregroundColor: _kMuted),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _selectedRoleIds
                        ..clear()
                        ..addAll(tempSelected);
                    });
                    Navigator.pop(ctx);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _onSavePressed() async {
    setState(() => _triedSubmit = true);
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      _showSnack('Please fix the highlighted fields', isError: true);
      return;
    }
    await _addEmp();
  }

  Future<void> _addEmp() async {
    final bool userStatus = isUserActive;

    if (_employeeJoinDate == null) {
      _showSnack('Please select join date', isError: true);
      return;
    }

    if (isUserActive && _selectedRoleIds.isEmpty) {
      _showSnack('Please select at least one user role', isError: true);
      return;
    }

    final managerId = ApiService.employeeId;
    if (managerId == null) return;

    setState(() => _formSubmitted = true);

    final List<String>? roleIdList =
        (isUserActive && _selectedRoleIds.isNotEmpty)
            ? _selectedRoleIds.toList()
            : null;

    final roleNamesCsv = isUserActive ? _selectedRoleNamesCsv : '';

    try {
      final response = widget.isEditing
          ? await ApiService.editEmp(
              managerId: _selectedTeamLeads?.id ?? '',
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
              roleId: roleIdList,
              standardHourCode: _selectedStandardHours?.id ?? 0,
            )
          : await ApiService.addEmp(
              managerId: _selectedTeamLeads?.id ?? '',
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
              roleId: roleIdList,
              standardHourCode: _selectedStandardHours?.id ?? 0,
            );

      if (!mounted) return;

      if (response['success'] != true) {
        throw Exception(response['error'] ?? 'Operation failed');
      }

      final String? serverMessage =
          (response['message'] ?? response['data'])?.toString().trim();

      final String? credentials = response['credentials']?.toString() ??
          ((serverMessage?.contains('Password:') ?? false)
              ? serverMessage
              : null);

      if (credentials != null && credentials.isNotEmpty) {
        await _showCredentialsDialog(credentials);
      } else {
        _showSnack(
          (serverMessage != null && serverMessage.isNotEmpty)
              ? serverMessage
              : (widget.isEditing
                  ? 'Employee updated successfully'
                  : 'Employee added successfully'),
        );
      }

      widget.onEmployeeUpdated?.call();

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showSnack(
        e.toString().replaceFirst('Exception: ', ''),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _formSubmitted = false);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? _kRed : _kGreen,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Row(
            children: [
              Icon(
                isError
                    ? Icons.error_outline
                    : Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
  }

  Future<void> _showCredentialsDialog(String credentials) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        title: _dialogHeader(
          Icons.key_rounded,
          widget.isEditing ? 'User created' : 'Employee created',
          subtitle: 'Share these login details securely',
        ),
        content: Container(
          width: double.maxFinite,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _kBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kLine),
          ),
          child: SelectableText(
            credentials,
            style: const TextStyle(
              color: _kInk,
              fontWeight: FontWeight.w600,
              height: 1.5,
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: credentials));
              _showSnack('Copied to clipboard');
            },
            style: TextButton.styleFrom(foregroundColor: Colors.blue[700]),
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.blue[700],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------- field helpers
  InputDecoration _dec(
    String label,
    IconData icon, {
    String? hint,
    String? errorText,
    bool enabled = true,
    Widget? suffix,
  }) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c, width: w),
        );

    return InputDecoration(
      labelText: label,
      hintText: hint,
      errorText: errorText,
      labelStyle: const TextStyle(color: _kMuted, fontWeight: FontWeight.w500),
      hintStyle: TextStyle(color: _kMuted.withOpacity(0.6)),
      floatingLabelStyle:
          TextStyle(color: Colors.blue[700], fontWeight: FontWeight.w600),
      prefixIcon: Padding(
        padding: const EdgeInsets.all(10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(enabled ? 0.10 : 0.05),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: enabled ? Colors.blue[700] : _kMuted,
            size: 20,
          ),
        ),
      ),
      suffixIcon: suffix,
      filled: true,
      fillColor: enabled ? _kBg : _kLine.withOpacity(0.5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: border(_kLine),
      enabledBorder: border(_kLine),
      disabledBorder: border(_kLine),
      focusedBorder: border(Colors.blue, 1.6),
      errorBorder: border(_kRed),
      focusedErrorBorder: border(_kRed, 1.6),
    );
  }

  Widget _text({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? formatters,
    TextInputAction action = TextInputAction.next,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: formatters,
      textInputAction: action,
      style: const TextStyle(color: _kInk, fontWeight: FontWeight.w600),
      decoration: _dec(label, icon, hint: hint),
    );
  }

  Widget _loadingField(String label) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kLine),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.blue[700],
            ),
          ),
          const SizedBox(width: 14),
          Text(
            'Loading ${label.toLowerCase()}...',
            style: const TextStyle(color: _kMuted, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required IconData icon,
    required bool loading,
    required T? value,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T?> onChanged,
    required String errorMessage,
  }) {
    if (loading) return _loadingField(label);

    return DropdownButtonFormField<T>(
      isExpanded: true,
      value: value,
      validator: (v) => v == null ? errorMessage : null,
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: _kMuted),
      dropdownColor: Colors.white,
      borderRadius: BorderRadius.circular(16),
      style: const TextStyle(
        color: _kInk,
        fontWeight: FontWeight.w600,
        fontSize: 15,
      ),
      decoration: _dec(label, icon),
      items: items
          .map(
            (d) => DropdownMenuItem<T>(
              value: d,
              child: Text(
                itemLabel(d),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _gap() => const SizedBox(height: 14);

  // ---------------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: Text(
          widget.isEditing ? 'Edit Employee' : 'Add Employee',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue[700],
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _kLine),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildBanner(),
                const SizedBox(height: 16),

                // ---------------- Personal ----------------
                _Section(
                  icon: Icons.person_outline_rounded,
                  title: 'Personal Information',
                  children: [
                    _text(
                      controller: _employeeFirstName,
                      label: 'First Name *',
                      icon: Icons.person_outline_rounded,
                      validator: (v) => _validateRequired(v, 'first name'),
                    ),
                    _gap(),
                    _text(
                      controller: _employeeLastName,
                      label: 'Last Name *',
                      icon: Icons.person_outline_rounded,
                      validator: (v) => _validateRequired(v, 'last name'),
                    ),
                    _gap(),
                    _text(
                      controller: _employeeEmail,
                      label: 'Email *',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: _validateEmail,
                    ),
                    _gap(),
                    _text(
                      controller: _employeePhone,
                      label: 'Phone *',
                      icon: Icons.phone_android_outlined,
                      keyboardType: TextInputType.phone,
                      formatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11),
                      ],
                      validator: _validatePhone,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ---------------- Work ----------------
                _Section(
                  icon: Icons.work_outline_rounded,
                  title: 'Work Details',
                  children: [
                    _text(
                      controller: _zkUserId,
                      label: 'Machine Id *',
                      icon: Icons.fingerprint,
                      validator: (v) => _validateRequired(v, 'machine id'),
                    ),
                    _gap(),
                    _dropdown<Company>(
                      label: 'Company *',
                      icon: Icons.business_outlined,
                      loading: _loadingCompanies,
                      value: _selectedCompany,
                      items: _companies,
                      itemLabel: (c) => c.name,
                      errorMessage: 'Please select company',
                      onChanged: (v) => setState(() => _selectedCompany = v),
                    ),
                    _gap(),
                    _dropdown<TeamLead>(
                      label: 'Lead *',
                      icon: Icons.supervisor_account_outlined,
                      loading: _loadingTeamLeads,
                      value: _selectedTeamLeads,
                      items: _teamLeads,
                      itemLabel: (d) => d.name,
                      errorMessage: 'Please select team lead',
                      onChanged: (v) =>
                          setState(() => _selectedTeamLeads = v),
                    ),
                    _gap(),
                    _dropdown<Department>(
                      label: 'Department *',
                      icon: Icons.apartment_rounded,
                      loading: _loadingDepartments,
                      value: _selectedDepartment,
                      items: _departments,
                      itemLabel: (d) => d.name,
                      errorMessage: 'Please select department',
                      onChanged: (v) =>
                          setState(() => _selectedDepartment = v),
                    ),
                    _gap(),
                    _dropdown<Designation>(
                      label: 'Designation *',
                      icon: Icons.cases_outlined,
                      loading: _loadingDesignations,
                      value: _selectedDesignation,
                      items: _designations,
                      itemLabel: (d) => d.name,
                      errorMessage: 'Please select designation',
                      onChanged: (v) {
                        setState(() {
                          _selectedDesignation = v;
                          _employeeDesignation.text = v?.name ?? '';
                        });
                      },
                    ),
                    _gap(),
                    _dropdown<StandardHourGroup>(
                      label: 'Hour Group *',
                      icon: Icons.schedule_rounded,
                      loading: _loadingStandardHours,
                      value: _selectedStandardHours,
                      items: _standardHours,
                      itemLabel: (s) => s.name,
                      errorMessage: 'Please select Hour Group',
                      onChanged: (v) {
                        setState(() {
                          _selectedStandardHours = v;
                          _employeeStandardHourGroup.text = v?.name ?? '';
                        });
                      },
                    ),
                    _gap(),
                    _buildJoinDate(),
                  ],
                ),
                const SizedBox(height: 16),

                // ---------------- Access ----------------
                _Section(
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'Status & Access',
                  children: [
                    _SwitchTile(
                      icon: Icons.verified_user_outlined,
                      title: 'Active employee',
                      subtitle: _selectedStatus ? 'Active' : 'Inactive',
                      value: _selectedStatus,
                      onChanged: (v) => setState(() => _selectedStatus = v),
                    ),
                    if (_selectedStatus) ...[
                      const SizedBox(height: 10),
                      _SwitchTile(
                        icon: Icons.smartphone_rounded,
                        title: 'App user',
                        subtitle: isUserActive
                            ? 'Can sign in to the app'
                            : 'No app access',
                        value: isUserActive,
                        onChanged: (v) {
                          setState(() {
                            isUserActive = v;
                            if (!isUserActive) _selectedRoleIds.clear();
                          });
                        },
                      ),
                    ],
                    _gap(),
                    _buildRoleField(),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomInset),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: _kLine)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1F2430).withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: _buildSubmitButton(),
      ),
    );
  }

  // ---------------------------------------------------------------- parts
  Widget _buildBanner() {
    final fullName =
        '${_employeeFirstName.text} ${_employeeLastName.text}'.trim();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: _bannerGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _baseColor.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              widget.isEditing
                  ? Icons.manage_accounts_rounded
                  : Icons.person_add_alt_1_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isEditing
                      ? (fullName.isEmpty ? 'Edit employee' : fullName)
                      : 'New employee',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.isEditing
                      ? 'Update the details below and save.'
                      : 'Fill in the details to add a team member.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinDate() {
    final showError = _employeeJoinDate == null && _triedSubmit;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _selectJoinDate,
      child: InputDecorator(
        decoration: _dec(
          'Join Date *',
          Icons.calendar_today_outlined,
          errorText: showError ? 'Please select join date' : null,
          suffix: const Icon(Icons.keyboard_arrow_down_rounded, color: _kMuted),
        ),
        child: Text(
          _employeeJoinDate == null
              ? 'Select date'
              : DateFormat('dd MMM yyyy').format(_employeeJoinDate!),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: _employeeJoinDate == null
                ? _kMuted.withOpacity(0.7)
                : _kInk,
          ),
        ),
      ),
    );
  }

  Widget _buildRoleField() {
    if (_loadingRoles) return _loadingField('roles');

    return FormField<Set<String>>(
      initialValue: _selectedRoleIds,
      validator: (_) {
        if (isUserActive && _selectedRoleIds.isEmpty) {
          return 'Please select at least one user role';
        }
        return null;
      },
      builder: (state) {
        final selected = _selectedRoleObjects;

        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isUserActive
              ? () async {
                  await _showRolePicker();
                  state.didChange(_selectedRoleIds);
                }
              : null,
          child: InputDecorator(
            decoration: _dec(
              'User Role(s) *',
              Icons.shield_outlined,
              enabled: isUserActive,
              errorText: state.errorText,
              suffix: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: isUserActive ? _kMuted : _kLine,
              ),
            ),
            child: selected.isEmpty
                ? Text(
                    isUserActive ? 'Select roles' : 'Not an app user',
                    style: TextStyle(
                      fontSize: 15,
                      color: _kMuted.withOpacity(0.7),
                    ),
                  )
                : Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final r in selected)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            r.name,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildSubmitButton() {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: _formSubmitted ? 0.75 : 1,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: _bannerGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _baseColor.withOpacity(0.30),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _formSubmitted ? null : _onSavePressed,
            child: Center(
              child: _formSubmitted
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          widget.isEditing
                              ? Icons.check_rounded
                              : Icons.person_add_alt_1_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          widget.isEditing
                              ? 'Update Employee'
                              : 'Add Employee',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ====================================================================
// Small widgets
// ====================================================================

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;

  const _Section({
    required this.icon,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: _softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: Colors.blue[700]),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _kInk,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kLine),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: Colors.blue[700]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    color: _kInk,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12.5, color: _kMuted),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: Colors.blue,
          ),
        ],
      ),
    );
  }
}