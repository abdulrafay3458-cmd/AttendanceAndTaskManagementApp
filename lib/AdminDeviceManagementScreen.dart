import 'package:attendance_app/models/UserDevices.dart';
import 'package:attendance_app/services/apiservice.dart';
import 'package:flutter/material.dart';

class AdminDeviceManagementScreen extends StatefulWidget {
  const AdminDeviceManagementScreen({Key? key}) : super(key: key);

  @override
  State<AdminDeviceManagementScreen> createState() =>
      _AdminDeviceManagementScreenState();
}

class _AdminDeviceManagementScreenState
    extends State<AdminDeviceManagementScreen> {
  List<UserDevices> _devices = [];
  List<UserDevices> _filtered = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() => _isLoading = true);

    try {
      final data = await ApiService.fetchAllDevices();
      _devices = data;
      _filtered = data;
    } catch (_) {
      _showError("Failed to load devices");
    }

    setState(() => _isLoading = false);
  }

  void _filter(String query) {
    setState(() {
      _filtered = _devices.where((d) {
        return d.employeeName.toLowerCase().contains(query.toLowerCase()) ||
            d.employeeCode.toLowerCase().contains(query.toLowerCase());
      }).toList();
    });
  }

  Future<void> _confirmRemove(UserDevices device) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Remove Device"),
        content: Text("Remove registered device for ${device.employeeName}?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Remove"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => device.isRemoving = true);

    try {
      await ApiService.removeDevice(device.employeeCode);

      setState(() {
        _devices.remove(device);
        _filtered.remove(device);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Device removed successfully"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (_) {
      device.isRemoving = false;
      _showError("Failed to remove device");
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Registered Devices")),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search by name or code",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onChanged: _filter,
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                ? const Center(child: Text("No registered devices"))
                : RefreshIndicator(
                    onRefresh: _loadDevices,
                    child: ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        final device = _filtered[index];

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.smartphone,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  const SizedBox(width: 14),

                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          device.employeeName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text("Code: ${device.employeeCode}"),
                                        Text(
                                          "Device: ${device.deviceManufacturer} ${device.deviceModel}",
                                        ),
                                      ],
                                    ),
                                  ),

                                  device.isRemoving
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : IconButton(
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            color: Colors.red,
                                          ),
                                          onPressed: () =>
                                              _confirmRemove(device),
                                        ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
