import 'package:attendance_app/models/UserDevices.dart';
import 'package:attendance_app/services/apiservice.dart';
import 'package:flutter/material.dart';

class AdminDeviceRequestsScreen extends StatefulWidget {
  const AdminDeviceRequestsScreen({Key? key}) : super(key: key);

  @override
  State<AdminDeviceRequestsScreen> createState() =>
      _AdminDeviceRequestsScreenState();
}

class _AdminDeviceRequestsScreenState extends State<AdminDeviceRequestsScreen> {
  List<UserDevices> _requests = [];
  List<UserDevices> _filtered = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.fetchDeviceRegistrationRequests();
      _requests = data;
      _filtered = data;
    } catch (_) {
      _showError("Failed to load requests");
    }
    setState(() => _isLoading = false);
  }

  // void _filter(String query) {
  //   setState(() {
  //     _filtered = _requests
  //         .where(
  //           (r) => r.employeeName.toLowerCase().contains(query.toLowerCase()),
  //           //      ||
  //           // r.deviceHash
  //           //     .toLowerCase()
  //           //     .contains(query.toLowerCase())
  //         )
  //         .toList();
  //   });
  // }

  void _filter(String query) {
    setState(() {
      _filtered = _requests.where((r) {
        return r.employeeName.toLowerCase().contains(query.toLowerCase()) ||
            r.employeeCode.toLowerCase().contains(query.toLowerCase());
      }).toList();
    });
  }

  Future<void> _confirmAction(UserDevices request, bool approve) async {
    final TextEditingController reasonController = TextEditingController();
    String? errorText;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(approve ? "Approve Request" : "Reject Request"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    approve
                        ? "Are you sure you want to approve this request?"
                        : "Please provide a reason for rejection.",
                  ),

                  if (!approve) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: reasonController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: "Enter rejection reason",
                        errorText: errorText,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (!approve && reasonController.text.trim().isEmpty) {
                      setStateDialog(() {
                        errorText = "Rejection reason is required";
                      });
                      return;
                    }

                    Navigator.pop(context, true);
                  },
                  child: const Text("Confirm"),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true) return;

    setState(() => request.isProcessing = true);

    try {
      await ApiService.handleDeviceRegistrationRequest(
        request.employeeCode,
        approve,
        reason: approve ? null : reasonController.text.trim(),
      );

      setState(() {
        _requests.remove(request);
        _filtered.remove(request);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve ? "Approved successfully" : "Rejected successfully",
          ),
          backgroundColor: approve ? Colors.green : Colors.red,
        ),
      );
    } catch (_) {
      setState(() => request.isProcessing = false);
      _showError("Action failed");
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
      appBar: AppBar(title: const Text("Device Requests")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search by name or code",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: _filter,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                ? const Center(child: Text("No pending requests"))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      itemCount: _filtered.length,
                      itemBuilder: (context, index) {
                        final request = _filtered[index];

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          child: Card(
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: const Icon(
                                Icons.smartphone,
                                color: Colors.blue,
                              ),
                              title: Text(
                                request.employeeName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Code: ${request.employeeCode}"),
                                  Text(
                                    "Device: ${request.deviceManufacturer} ${request.deviceModel}",
                                  ),
                                ],
                              ),
                              trailing: request.isProcessing
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.check_circle,
                                            color: Colors.green,
                                          ),
                                          onPressed: () =>
                                              _confirmAction(request, true),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.cancel,
                                            color: Colors.red,
                                          ),
                                          onPressed: () =>
                                              _confirmAction(request, false),
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
