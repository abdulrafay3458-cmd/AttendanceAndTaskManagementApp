import 'package:attendance_app/services/apiservice.dart';
import 'package:attendance_app/widgets/SizeConfig.dart';
import 'package:flutter/material.dart';
import 'package:attendance_app/models/company.dart';
import 'package:flutter/services.dart';

class DeviceSetup extends StatefulWidget {
  final bool isEditing;
  final Map<String, dynamic>? DeviceData;

  const DeviceSetup({super.key, this.isEditing = false, this.DeviceData});

  @override
  State<DeviceSetup> createState() => _DeviceSetup();
}

class _DeviceSetup extends State<DeviceSetup> {
  bool _formSubmitted = false;
  final _formKey = GlobalKey<FormState>();
  final _deviceId = TextEditingController();
  final _deviceName = TextEditingController();
  final _devicePort = TextEditingController();
  final _deviceIpAddress = TextEditingController();
  final _deviceLocation = TextEditingController();
  final _deviceStatus = TextEditingController();
  final _deviceLastAsync = TextEditingController();
  final _deviceMachineNumber = TextEditingController();
  final _deviceCompanyCode = TextEditingController();
  bool isDeviceActive = true;
  bool isDeviceCanReadLogs = true;

  List<Company> _companies = [];
  Company? _selectedCompany;
  bool _loadingCompanies = true;

  @override
  void initState() {
    super.initState();
    _fetchCompanies();

    // If in edit mode, populate fields with existing data
    if (widget.isEditing && widget.DeviceData != null) {
      _populateFormWithExistingData();
    }
  }

  void _populateFormWithExistingData() {
    final data = widget.DeviceData!;

    _deviceId.text = data['deviceId'].toString();
    _deviceName.text = data['deviceName'] ?? '';
    _deviceIpAddress.text = data['deviceIpAddress'] ?? '';
    _deviceLocation.text = data['deviceLocation'] ?? '';
    _deviceStatus.text = data['deviceStatus'] ?? '';
    _devicePort.text = data['devicePort'].toString();
    _deviceCompanyCode.text = data['deviceCompanyCode'] ?? '';
    isDeviceActive = data['deviceIsActive'] ?? false;
    isDeviceCanReadLogs = data['deviceCanReadLogs'] ?? false;
    _deviceMachineNumber.text = data['deviceMachineNumber'].toString();
  }

  @override
  void dispose() {
    _deviceId.dispose();
    _deviceName.dispose();
    _deviceIpAddress.dispose();
    _deviceLocation.dispose();
    _devicePort.dispose();
    _deviceStatus.dispose();
    _deviceLastAsync.dispose();
    _deviceMachineNumber.dispose();
    super.dispose();
  }

  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter $fieldName';
    }
    return null;
  }

  // String? _validateEmail(String? value) {
  //   if (value == null || value.trim().isEmpty) {
  //     return 'Please enter email';
  //   }
  //   final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
  //   if (!emailRegex.hasMatch(value.trim())) {
  //     return 'Please enter a valid email';
  //   }
  //   return null;
  // }

  // String? _validatePhone(String? value) {
  //   if (value == null || value.trim().isEmpty) {
  //     return 'Please enter phone number';
  //   }
  //   if (value.trim().length < 11) {
  //     return 'Please enter a valid phone number';
  //   }
  //   return null;
  // }

  Future<void> _fetchCompanies() async {
    try {
      final data = await ApiService.getCompanies(); // implement API call
      setState(() {
        _companies = data
            .map<Company>((json) => Company.fromJson(json))
            .toList();
        _loadingCompanies = false;

        // Preselect existing company if editing
        if (widget.isEditing && widget.DeviceData != null) {
          final code =
              widget.DeviceData!['companyCode'] ??
              widget.DeviceData!['CompanyCode'];
          _selectedCompany = _companies.firstWhere(
            (c) => c.code == code,
            orElse: () => _companies.first,
          );
        }
      });
    } catch (e) {
      setState(() => _loadingCompanies = false);
      print('Error fetching companies: $e');
    }
  }

  Future<void> _addDevice() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _formSubmitted = true);

    try {
      final data = await ApiService.addDevice(
        deviceName: _deviceName.text.trim(),
        deviceIpAddress: _deviceIpAddress.text.trim(),
        deviceLocation: _deviceLocation.text.trim(),
        devicePort: _devicePort.text.trim(),
        deviceMachineNumber: _deviceMachineNumber.text.trim(),
        isDeviceActive: isDeviceActive,
        CanReadLogs: isDeviceCanReadLogs,
        deviceCompanyCode: _selectedCompany?.code ?? '',
      );

      if (data['success'] == true && mounted) {
        Navigator.pop(context, true); // ✅ pop ONCE and notify parent
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['error'] ?? 'Device could not be added.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _formSubmitted = false);
      }
    }
  }

  Future<void> _editDevice() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _formSubmitted = true);

    try {
      final data = await ApiService.editDevice(
        deviceId: _deviceId.text.trim(),
        deviceName: _deviceName.text.trim(),
        deviceIpAddress: _deviceIpAddress.text.trim(),
        deviceLocation: _deviceLocation.text.trim(),
        devicePort: _devicePort.text.trim(),
        deviceStatus: _deviceStatus.text.trim(),
        deviceMachineNumber: _deviceMachineNumber.text.trim(),
        isDeviceActive: isDeviceActive,
        CanReadLogs: !isDeviceActive ? false : isDeviceCanReadLogs,
        deviceCompanyCode: _deviceCompanyCode.text.trim(),
      );

      if (data['success'] == true && mounted) {
        Navigator.pop(context, true); // notify parent
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['error'] ?? 'Device could not be updated.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
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
          widget.isEditing ? 'Edit Device' : 'Add Device',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: SizeConfig.f(20),
          ),
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
                  // Client Code
                  // TextFormField(
                  //   controller: _deviceId,
                  //   inputFormatters: [
                  //     LengthLimitingTextInputFormatter(4),
                  //   ],
                  //   validator: (value) => _validateRequired(value, 'Device id'),
                  //   decoration: InputDecoration(
                  //     labelText: 'Device Id *',
                  //     prefixIcon: const Icon(
                  //       Icons.business_center_outlined,
                  //       color: Color.fromARGB(255, 176, 39, 110),
                  //     ),
                  //     border: OutlineInputBorder(
                  //       borderRadius: BorderRadius.circular(12),
                  //       borderSide: BorderSide(color: Color.fromARGB(255, 176, 39, 110)),
                  //     ),
                  //     filled: true,
                  //     fillColor: Colors.white,
                  //   ),
                  //   textInputAction: TextInputAction.next,
                  // ),
                  const SizedBox(height: 16),

                  // Client Name
                  TextFormField(
                    controller: _deviceName,
                    validator: (value) =>
                        _validateRequired(value, 'device name'),
                    decoration: InputDecoration(
                      labelText: 'Device Name *',
                      prefixIcon: const Icon(
                        Icons.abc_rounded,
                        color: Colors.blue,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.blue),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),

                  // Client Suit No
                  TextFormField(
                    controller: _deviceIpAddress,
                    validator: (value) =>
                        _validateRequired(value, 'ip Address'),
                    decoration: InputDecoration(
                      labelText: 'IP Address *',
                      prefixIcon: const Icon(
                        Icons.apartment,
                        color: Colors.blue,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.blue),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),

                  // Client Steet No
                  TextFormField(
                    controller: _deviceMachineNumber,
                    validator: (value) =>
                        _validateRequired(value, 'machine no'),
                    decoration: InputDecoration(
                      labelText: 'Machine Number *',
                      prefixIcon: const Icon(
                        Icons.streetview,
                        color: Colors.blue,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.blue),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),

                  // Client Postal Code
                  TextFormField(
                    controller: _deviceLocation,
                    validator: (value) =>
                        _validateRequired(value, 'device location'),
                    decoration: InputDecoration(
                      labelText: 'Device Location *',
                      prefixIcon: const Icon(
                        Icons.local_post_office,
                        color: Colors.blue,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.blue),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),

                  // Client Town / City
                  TextFormField(
                    controller: _devicePort,
                    validator: (value) => _validateRequired(value, 'port no'),
                    decoration: InputDecoration(
                      labelText: 'Port No *',
                      prefixIcon: const Icon(
                        Icons.location_city,
                        color: Colors.blue,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.blue),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  _loadingCompanies
                      ? const Center(child: CircularProgressIndicator())
                      : DropdownButtonFormField<Company>(
                          initialValue: _selectedCompany,
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

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.star_outline_sharp,
                            color: Colors.blue[700],
                            size: 18,
                          ),
                          SizedBox(width: SizeConfig.w(5)),
                          Text(
                            'Device Status',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(width: SizeConfig.w(40)),
                          Text(
                            _deviceStatus.text, // value from backend
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                      // const SizedBox(height: 6),
                      // Text(
                      //   _deviceStatus.text, // value from backend
                      //   style: const TextStyle(
                      //     fontSize: 16,
                      //     fontWeight: FontWeight.w600,
                      //     color: Colors.black,
                      //   ),
                      // ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Client Status CheckBox
                  SwitchListTile(
                    title: const Text('Active Device'),
                    subtitle: Text(isDeviceActive ? 'Active' : 'Inactive'),
                    value: isDeviceActive,
                    activeTrackColor:
                        const Color.fromARGB(255, 33, 150, 243).withOpacity(1), // track
                    onChanged: (value) {
                      setState(() {
                        isDeviceActive = value;
                      });
                    },
                  ),

                  // AnimatedSwitcher(
                  //   duration: const Duration(milliseconds: 300),
                  //   child: isDeviceActive
                  //       ? CheckboxListTile(
                  //           key: const ValueKey('isDeviceCanReadLogs'),
                  //           title: const Text('Enable Log Reading'),
                  //           value: isDeviceCanReadLogs,
                  //           onChanged: (value) {
                  //             setState(() {
                  //               isDeviceCanReadLogs = value ?? false;
                  //             });
                  //           },
                  //         )
                  //       : const SizedBox.shrink(),
                  // ),

                  // 👇 Visible ONLY when isDeviceActive == true
                  if (isDeviceActive)
                    CheckboxListTile(
                      title: const Text('Enable Client Access'),
                      value: isDeviceCanReadLogs,
                      onChanged: (value) {
                        setState(() {
                          isDeviceCanReadLogs = value ?? false;
                        });
                      },
                    ),
                  const SizedBox(height: 30),

                  if (widget.isEditing) ...[] else ...[],
                  // Submit Button
                  if (widget.isEditing)
                    ElevatedButton(
                      onPressed: _formSubmitted ? null : _editDevice,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
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
                              children: const [
                                Text('Update Device'),
                              ],
                            ),
                    )
                  else
                    ElevatedButton(
                      onPressed: _formSubmitted ? null : _addDevice,
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
                              children: const [
                                Text('Add Device'),
                              ],
                            ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
