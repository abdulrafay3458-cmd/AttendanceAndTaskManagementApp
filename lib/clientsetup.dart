import 'package:attendance_app/services/apiservice.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ClientSetup extends StatefulWidget {

  final bool isEditing;
  final Map<String, dynamic>? clientData;


  const ClientSetup({
    super.key,
    this.isEditing = false,
    this.clientData,
  });

  @override
  State<ClientSetup> createState() => _ClientSetup();
}

class _ClientSetup extends State<ClientSetup> {
  bool _formSubmitted = false;
  final _formKey = GlobalKey<FormState>();
  bool isClientActive = true;
  final _clientCode = TextEditingController();
  final _clientName = TextEditingController();
  final _clientSuitNo = TextEditingController();
  final _clientSteetNO = TextEditingController();
  final _clientPostalCode = TextEditingController();
  final _clientTown = TextEditingController();
  final _clientProvince = TextEditingController();
  final _clientCountry = TextEditingController();
  final _clientEmail = TextEditingController();
  final _clientLegalName = TextEditingController();
  final _clientPhone = TextEditingController();
  final _clientIndustryCode = TextEditingController();
  final _clientFax = TextEditingController();
  final _clientShortName = TextEditingController();
  final _clientCountryCode = TextEditingController();
  final _clientGlCode = TextEditingController();
  final _clientFiscalYear = TextEditingController();
  final _clientParentCode = TextEditingController();
  final _clientChildCode = TextEditingController();
  bool _clientVendor = false;

  @override
    void initState() {
      super.initState();
      
      // If in edit mode, populate fields with existing data
      if (widget.isEditing && widget.clientData != null) {
        _populateFormWithExistingData();
      }
    }
  
  void _populateFormWithExistingData() {
    final data = widget.clientData!;

    _clientCode.text = data['clientCode'] ?? '';
    _clientName.text = data['clientName'] ?? '';
    _clientSuitNo.text = data['clientSuitNo'] ?? '';
    _clientSteetNO.text = data['clientSteetNO'] ?? '';
    _clientPostalCode.text = data['clientPostalCode'] ?? '';
    _clientTown.text = data['clientTown'] ?? '';
    _clientProvince.text = data['clientProvince'] ?? '';
    _clientCountry.text = data['clientCountry'] ?? '';
    _clientEmail.text = data['clientEmail'] ?? '';
    _clientLegalName.text = data['clientLegalName'] ?? '';
    _clientPhone.text = data['clientPhone'] ?? '';
    _clientIndustryCode.text = data['clientIndustryCode'] ?? '';
    _clientFax.text = data['clientFax'] ?? '';
    _clientShortName.text = data['clientShortName'] ?? '';
    _clientCountryCode.text = data['clientCountryCode'] ?? '';
    _clientGlCode.text = data['clientGlCode'] ?? '';
    _clientFiscalYear.text = data['clientFiscalYear'] ?? '';
    _clientParentCode.text = data['clientParentCode'] ?? '';
    _clientChildCode.text = data['clientChildCode'] ?? '';
  }

  @override
  void dispose() {
    _clientCode.dispose();
    _clientName.dispose();
    _clientSuitNo.dispose();
    _clientSteetNO.dispose();
    _clientPostalCode.dispose();
    _clientTown.dispose();
    _clientProvince.dispose();
    _clientCountry.dispose();
    _clientEmail.dispose();
    _clientPhone.dispose();
    _clientIndustryCode.dispose();
    _clientFax.dispose();
    _clientShortName.dispose();
    _clientCountryCode.dispose();
    _clientLegalName.dispose();
    _clientGlCode.dispose();
    _clientFiscalYear.dispose();
    _clientParentCode.dispose();
    _clientChildCode.dispose();
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

  Future<void> _addClient() async {
    // Validate form
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _formSubmitted = true);

    try {
      final data = await ApiService.addClient(
        clientCode: _clientCode.text,
        clientName: _clientName.text.trim(),
        clientSuitNo: _clientSuitNo.text.trim(),
        clientSteetNO: _clientSteetNO.text.trim(),
        clientPostalCode: _clientPostalCode.text.trim(),
        clientTown: _clientTown.text.trim(),
        clientProvince: _clientProvince.text.trim(),
        clientCountry: _clientCountry.text.trim(),
        clientEmail: _clientEmail.text.trim(),
        clientPhone: _clientPhone.text.trim(),
        clientIndustryCode: _clientIndustryCode.text.trim(),
        clientFax: _clientFax.text.trim(),
        clientLegalName: _clientLegalName.text.trim(),
        clientShortName: _clientShortName.text.trim(),
        clientCountryCode: _clientCountryCode.text.trim(),
        clientGlCode: _clientGlCode.text.trim(),
        clientFiscalYear: _clientFiscalYear.text.trim(),
        clientParentCode: _clientParentCode.text.trim(),
        clientChildCode: _clientChildCode.text.trim(),
        clientStatus: isClientActive,
        clientVendor: _clientVendor,
      );
      
      if (data['success'] == true) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Client added successfully!'),
              backgroundColor: Colors.green,
            ),
          );

          await Future.delayed(const Duration(milliseconds: 500));
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['error'] ?? 'Client could not be added. Please try again later.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    finally {
      if (mounted) {
        setState(() => _formSubmitted = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Client' : 'Add Client'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
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
                  TextFormField(
                    controller: _clientCode,
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(4),
                    ],
                    validator: (value) => _validateRequired(value, 'client code'),
                    decoration: InputDecoration(
                      labelText: 'Client Code *',
                      prefixIcon: const Icon(
                        Icons.business_center_outlined,
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

                  // Client Name
                  TextFormField(
                    controller: _clientName,
                    validator: (value) => _validateRequired(value, 'client name'),
                    decoration: InputDecoration(
                      labelText: 'Client Name *',
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
                    controller: _clientSuitNo,
                    validator: (value) => _validateRequired(value, 'suit no'),
                    decoration: InputDecoration(
                      labelText: 'Suit No / Appartment No *',
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
                    controller: _clientSteetNO,
                    validator: (value) => _validateRequired(value, 'street no'),
                    decoration: InputDecoration(
                      labelText: 'Street Number *',
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
                    controller: _clientPostalCode,
                    validator: (value) => _validateRequired(value, 'postal code'),
                    decoration: InputDecoration(
                      labelText: 'Postal Code *',
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
                    controller: _clientTown,
                    validator: (value) => _validateRequired(value, 'town'),
                    decoration: InputDecoration(
                      labelText: 'Town / City *',
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

                  // Client Province
                  TextFormField(
                    controller: _clientProvince,
                    validator: (value) => _validateRequired(value, 'province'),
                    decoration: InputDecoration(
                      labelText: 'Province *',
                      prefixIcon: const Icon(
                        Icons.location_on,
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

                  // Client Country
                  TextFormField(
                    controller: _clientCountry,
                    validator: (value) => _validateRequired(value, 'country'),
                    decoration: InputDecoration(
                      labelText: 'Country *',
                      prefixIcon: const Icon(
                        Icons.flag,
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

                  // Client Email
                  TextFormField(
                    controller: _clientEmail,
                    validator: _validateEmail,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Client Email *',
                      prefixIcon: const Icon(Icons.email_outlined, color: Colors.blue,),
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

                  // Phone
                  TextFormField(
                    controller: _clientPhone,
                    validator: _validatePhone,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(11),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Phone *',
                      prefixIcon: const Icon(Icons.phone_android_outlined, color: Colors.blue),
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

                  // Industry Code
                  TextFormField(
                    controller: _clientIndustryCode,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(8),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Industry Code',
                      prefixIcon: const Icon(Icons.business_outlined, color: Colors.blue),
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

                  // FAX
                  TextFormField(
                    controller: _clientFax,
                    decoration: InputDecoration(
                      labelText: 'Fax',
                      prefixIcon: const Icon(Icons.fax_outlined, color: Colors.blue),
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

                  // Short Name
                  TextFormField(
                    controller: _clientShortName,
                    decoration: InputDecoration(
                      labelText: 'Client Short Name',
                      prefixIcon: const Icon(Icons.business, color: Colors.blue),
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

                   TextFormField(
                    controller: _clientLegalName,
                    decoration: InputDecoration(
                      labelText: 'Client Legal Name',
                      prefixIcon: const Icon(Icons.business, color: Colors.blue),
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

                  // Country Code
                  TextFormField(
                    controller: _clientCountryCode,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Client Country Code',
                      prefixIcon: const Icon(Icons.emoji_flags_rounded, color: Colors.blue),
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

                  // Gl Code
                  TextFormField(
                    controller: _clientGlCode,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(2),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Gl Code',
                      prefixIcon: const Icon(Icons.receipt_long_rounded, color: Colors.blue),
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

                  // Fiscal Year
                  TextFormField(
                    controller: _clientFiscalYear,
                    decoration: InputDecoration(
                      labelText: 'Fiscal Year End',
                      prefixIcon: const Icon(Icons.calendar_month_rounded, color: Colors.blue),
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

                  // Parent Code
                  TextFormField(
                    controller: _clientParentCode,
                    decoration: InputDecoration(
                      labelText: 'Parent Code',
                      prefixIcon: const Icon(Icons.apartment_rounded, color: Colors.blue),
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

                  // Child Code
                  TextFormField(
                    controller: _clientChildCode,
                    decoration: InputDecoration(
                      labelText: 'Child Code',
                      prefixIcon: const Icon(Icons.corporate_fare_rounded, color: Colors.blue),
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

                  // Client Status CheckBox
                  SwitchListTile(
                    title: const Text('Client Status'),
                    subtitle: Text(isClientActive ? 'Active' : 'Inactive'),
                    value: isClientActive,
                    activeTrackColor:
                        Colors.blue.withOpacity(1), // track
                    onChanged: (value) {
                      setState(() {
                        isClientActive = value;
                      });
                    },
                  ),
                  const SizedBox(height: 30),

                  // Vendor CheckBox
                  SwitchListTile(
                    title: const Text('Vendor'),
                    subtitle: Text(isClientActive ? 'Active' : 'Inactive'),
                    value: _clientVendor,
                    activeTrackColor:
                        Colors.blue.withOpacity(1), // track
                    onChanged: (value) {
                      setState(() {
                        _clientVendor = value;
                      });
                    },
                  ),
                  const SizedBox(height: 30),

                  if(widget.isEditing) ...[
                    
                  ] else ...[

                  ],
                  // Submit Button
                  ElevatedButton(
                    onPressed:_addClient,
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
                            children: [
                              Icon(Icons.add),
                              SizedBox(width: 10),
                              Text(widget.isEditing ? 'Edit Client' : 'Add Client'),
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