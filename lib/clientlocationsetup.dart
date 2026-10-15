import 'package:attendance_app/map_location_picker.dart';
import 'package:attendance_app/services/apiservice.dart';
import 'package:attendance_app/services/client_location.dart';
import 'package:attendance_app/services/client_location_service.dart';
import 'package:flutter/material.dart';

class _ClientOption {
  final String id;
  final String name;
  final String code;
  _ClientOption(this.id, this.name, this.code);
}

class ClientLocationSetup extends StatefulWidget {
  /// null = add new, non-null = edit
  final ClientLocation? location;

  const ClientLocationSetup({super.key, this.location});

  @override
  State<ClientLocationSetup> createState() => _ClientLocationSetupState();
}

class _ClientLocationSetupState extends State<ClientLocationSetup> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  final _radiusCtrl = TextEditingController();

  List<_ClientOption> _clients = [];
  String? _selectedClientId;
  String _status = 'Active';
  bool _isActive = true;

  bool _loadingClients = true;
  bool _clientIdsMissing = false;
  bool _saving = false;

  bool get _isEditing => widget.location != null;

  @override
  void initState() {
    super.initState();
    _loadClients();

    final l = widget.location;
    if (l != null) {
      _selectedClientId = l.clientId;
      _nameCtrl.text = l.locationName;
      _addressCtrl.text = l.address;
      _latCtrl.text = l.latitude.toString();
      _lngCtrl.text = l.longitude.toString();
      _radiusCtrl.text = l.allowedRadius.toString();
      _status = l.status;
      _isActive = l.isActive;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _radiusCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    try {
      final data = await ApiService.getClients();

      final seen = <String>{};
      final list = <_ClientOption>[];
      for (final raw in data) {
        final json = Map<String, dynamic>.from(raw as Map);
        // entity/all returns: code, name, clientId
        final id = (json['clientId'] ?? json['ClientId'] ?? '').toString().trim();
        final code =
            (json['code'] ?? json['clientCode'] ?? json['entityCode'] ?? '')
                .toString();
        final name =
            (json['name'] ?? json['clientName'] ?? json['entityName'] ?? '')
                .toString();

        // skip clients without an id (and duplicates) so the dropdown never crashes
        if (id.isEmpty || id == '00000000-0000-0000-0000-000000000000') continue;
        if (!seen.add(id)) continue;
        list.add(_ClientOption(id, name.isEmpty ? code : name, code));
      }

      if (!mounted) return;
      setState(() {
        _clients = list;
        _loadingClients = false;
        _clientIdsMissing = data.isNotEmpty && list.isEmpty;
        // if editing and client no longer exists, clear selection
        if (_selectedClientId != null &&
            !_clients.any((c) => c.id == _selectedClientId)) {
          _selectedClientId = null;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingClients = false);
    }
  }

  Future<void> _pickOnMap() async {
    final result = await Navigator.push<PickedLocation>(
      context,
      MaterialPageRoute(
        builder: (_) => MapLocationPicker(
          initialLat: double.tryParse(_latCtrl.text.trim()),
          initialLng: double.tryParse(_lngCtrl.text.trim()),
          radius: double.tryParse(_radiusCtrl.text.trim()) ?? 100,
        ),
      ),
    );
    if (result == null) return;
    setState(() {
      _latCtrl.text = result.latitude.toStringAsFixed(6);
      _lngCtrl.text = result.longitude.toStringAsFixed(6);
      if (result.address.isNotEmpty) _addressCtrl.text = result.address;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final client = _clients.firstWhere((c) => c.id == _selectedClientId);

    final loc = ClientLocation(
      clientLocationId: widget.location?.clientLocationId ?? '',
      clientId: client.id,
      clientName: client.name,
      locationName: _nameCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      latitude: double.parse(_latCtrl.text.trim()),
      longitude: double.parse(_lngCtrl.text.trim()),
      allowedRadius: double.parse(_radiusCtrl.text.trim()),
      status: _status,
      isActive: _isActive,
    );

    final ok = _isEditing
        ? await ClientLocationService.updateClientLocation(loc)
        : await ClientLocationService.addClientLocation(loc);

    if (!mounted) return;
    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok
          ? (_isEditing ? 'Location updated' : 'Location added')
          : (ClientLocationService.lastError.isNotEmpty
              ? ClientLocationService.lastError
              : 'Something went wrong')),
      backgroundColor: ok ? Colors.green : Colors.red,
    ));
    if (ok) Navigator.pop(context, true);
  }

  InputDecoration _dec(String label, IconData icon, {String? suffix}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.blue[700]),
      suffixText: suffix,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blue.shade700, width: 1.5),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 12),
        child: Text(text,
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.blue[700])),
      );

  String? _requiredNumber(String? v, String label,
      {double? min, double? max, bool positive = false}) {
    if (v == null || v.trim().isEmpty) return '$label is required';
    final n = double.tryParse(v.trim());
    if (n == null) return 'Enter a valid number';
    if (positive && n <= 0) return '$label must be greater than 0';
    if (min != null && n < min) return '$label must be ≥ $min';
    if (max != null && n > max) return '$label must be ≤ $max';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Client Location' : 'Add Client Location',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue[700],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionTitle('Client'),
            _loadingClients
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : DropdownButtonFormField<String>(
                    value: _selectedClientId,
                    isExpanded: true,
                    decoration:
                        _dec('Select Client', Icons.business_center_rounded),
                    items: _clients
                        .map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(
                                  c.code.isEmpty ? c.name : '${c.name} (${c.code})',
                                  overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedClientId = v),
                    validator: (v) => v == null ? 'Please select a client' : null,
                  ),
            if (!_loadingClients && _clients.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _clientIdsMissing
                      ? 'Clients were loaded but have no ClientId. Check EntityResponse on the backend.'
                      : 'No clients found. Please create a client first.',
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            const SizedBox(height: 8),
            _sectionTitle('Location Details'),
            TextFormField(
              controller: _nameCtrl,
              decoration: _dec('Location Name', Icons.location_city),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Location name is required' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _addressCtrl,
              decoration: _dec('Address', Icons.place_outlined),
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Address is required' : null,
            ),
            const SizedBox(height: 8),
            _sectionTitle('Geo Fence'),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _pickOnMap,
                icon: const Icon(Icons.map_outlined),
                label: const Text('Pick on Map'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue[700],
                  side: BorderSide(color: Colors.blue.shade700),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _latCtrl,
                    decoration: _dec('Latitude', Icons.my_location),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                    validator: (v) =>
                        _requiredNumber(v, 'Latitude', min: -90, max: 90),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _lngCtrl,
                    decoration: _dec('Longitude', Icons.explore_outlined),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: true),
                    validator: (v) =>
                        _requiredNumber(v, 'Longitude', min: -180, max: 180),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _radiusCtrl,
              decoration:
                  _dec('Allowed Radius', Icons.radar, suffix: 'meters'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) =>
                  _requiredNumber(v, 'Allowed radius', positive: true),
            ),
            const SizedBox(height: 8),
            _sectionTitle('Status'),
            DropdownButtonFormField<String>(
              value: _status,
              decoration: _dec('Status', Icons.flag_outlined),
              items: const ['Active', 'Inactive']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() {
                _status = v ?? 'Active';
                _isActive = _status == 'Active';
              }),
            ),
            const SizedBox(height: 14),
            Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              clipBehavior: Clip.antiAlias,
              child: SwitchListTile(
                title: const Text('Is Active'),
                subtitle: const Text('Inactive locations are ignored for attendance'),
                value: _isActive,
                activeColor: Colors.blue[700],
                onChanged: (v) => setState(() {
                  _isActive = v;
                  _status = v ? 'Active' : 'Inactive';
                }),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(_isEditing ? Icons.save : Icons.add),
                label: Text(_isEditing ? 'Update Location' : 'Save Location',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}