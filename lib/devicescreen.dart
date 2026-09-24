import 'package:attendance_app/devicesetup.dart';
import 'package:attendance_app/services/apiservice.dart';
import 'package:attendance_app/services/devices.dart';
import 'package:flutter/material.dart';

class DeviceScreen extends StatefulWidget {
  
  const DeviceScreen({super.key});

  @override
  _DevicScreen createState() => _DevicScreen();
}

class _DevicScreen extends State<DeviceScreen> {
  List<Devices> _device = [];
  List<Devices> _filteredDevices = [];
  bool isDeviceActive= true;
  bool _isLoading = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDevices();

    _searchController.addListener(() {
      _filteredDevicesList();
    });
  }

  Future<void> _loadDevices() async {
    setState(() => _isLoading = true);

    final data = await ApiService.getDevices();
    setState(() {
      _device = data.map((json) => Devices.fromJson(json)).toList();
      _filteredDevices = List.from(_device);
      _isLoading = false;
    });
  }

  void _filteredDevicesList() {
      final query = _searchController.text.toLowerCase().trim();
      
      if (query.isEmpty) {
        setState(() {
          _filteredDevices = List.from(_device);
        });
      } else {
        setState(() {
          _filteredDevices = _device.where((member) {
            return member.Name.toLowerCase().contains(query) ||
                  member.IpAddress.toLowerCase().contains(query) ||
                  member.Location.toLowerCase().contains(query) ||
                  member.Id.toLowerCase().contains(query) ||
                  member.Port.toString().toLowerCase().contains(query) ||
                  member.MachineNumber.toString().toLowerCase().contains(query);
          }).toList();
        });
      }
    }

  void _startSearch() {
    setState(() {
      _isSearching = true;
    });
  }

  void _stopSearch() {
    setState(() {
      _isSearching = false;
      _searchController.clear();
      _filteredDevices = List.from(_device);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isSearching ? _buildSearchAppBar() : _buildNormalAppBar(),
      // appBar: AppBar(
      //   title: Text('Clients'),
      //   backgroundColor: Colors.purple[700],
      //   foregroundColor: Colors.white,
      //   actions: [
      //     IconButton(icon: Icon(Icons.refresh), onPressed: _loadClient),
      //   ],
      // ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _filteredDevices.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _searchController.text.isNotEmpty
                        ? Icons.search_off
                        : Icons.people_outline,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    _searchController.text.isNotEmpty ?
                    'No result found for "${_searchController.text}"'
                    : 'No Devices found',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  if (_searchController.text.isNotEmpty)
                  TextButton(onPressed: _stopSearch, child: Text('Clear Search')),
                ],
              ),
            )
          : Stack(
            children: [
              RefreshIndicator(
              onRefresh: _loadDevices,
              child: ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: _filteredDevices.length,
                itemBuilder: (context, index) {
                  final deviceData = _filteredDevices[index];
                  return _deviceName(deviceData);
                },
              ),
            ),
          ],
          ),
          floatingActionButton: FloatingActionButton(
          onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DeviceSetup(),
                ),
              );

              if (result == true) {
                _loadDevices(); // 🔁 refresh list
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Device added successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            backgroundColor: Colors.blue[700],
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Icon(Icons.add),
        ),


    );
  }

  AppBar _buildNormalAppBar() {
    return AppBar(
      title: Text('Device List', style: TextStyle(fontWeight: FontWeight.w600),),
      backgroundColor: Colors.white,
      foregroundColor: Colors.blue[700],
      actions: [
        IconButton(
          icon: Icon(Icons.search),
          onPressed: _startSearch,
        ),
        IconButton(
          icon: Icon(Icons.refresh),
          onPressed: _loadDevices,
        ),
      ],
    );
  }

  AppBar _buildSearchAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: Colors.blue[700],
      leading: IconButton(
        icon: Icon(Icons.arrow_back),
        onPressed: _stopSearch,
      ),
      title: TextField(
        controller: _searchController,
        autofocus: true,
        style: TextStyle(color: Colors.blue[700]),
        decoration: InputDecoration(
          hintText: 'Search Device...',
          hintStyle: TextStyle(color: Colors.blue[700]),
          border: InputBorder.none,
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
              : null,
        ),
        cursorColor: Colors.white,
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.search),
          onPressed: () {
            _filteredDevicesList();
          },
        ),
      ],
    );
  }

  Widget _deviceName(Devices device) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        contentPadding: EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Colors.blue[100],
          radius: 28,
          child: Text(
            device.Name.substring(0, 2).toUpperCase(),
            style: TextStyle(
              color: Colors.blue[700],
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              device.Name,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(width: 6),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: device.IsActive ? Colors.green : Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: 
              Text(
                device.IsActive ? 'Active' : 'Inactive',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.network_wifi, size: 14, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text(
                  device.IpAddress,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text(
                  device.Location,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.dns, size: 14, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text(
                  device.Port.toString(),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.devices, size: 14, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text(
                  device.MachineNumber.toString(),
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            SizedBox(height: 4),
          ], // add krni hain fileds
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert),
          onSelected: (value) async {
            if (value == 'Edit') {
              final deviceData = {
                'deviceId': device.Id,
                'deviceName': device.Name,
                'deviceIpAddress': device.IpAddress,
                'devicePort': device.Port,
                'deviceStatus': device.Status,
                'deviceLocation': device.Location,
                'deviceMachineNumber': device.MachineNumber,
                'deviceIsActive': device.IsActive,
                'deviceCompanyCode': device.CompanyCode,
                'deviceCanReadLogs': device.CanReadLogs,
              };

               final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DeviceSetup(
                    isEditing: true,
                    DeviceData: deviceData,
                  ),
                ),
              );
              if (result == true) {
                _loadDevices(); // refresh after edit
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Device updated successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } else if (value == 'Delete') {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text('Delete Device'),
                  content: Text('Are you sure you want to delete this device?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                try {
                  final result = await ApiService.deleteDevice(device.Id);

                  if (result['success'] == true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Device deleted successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );

                    setState(() {
                      _device.removeWhere((d) => d.Id == device.Id);
                      _filteredDevices.removeWhere((d) => d.Id == device.Id);
                    }); 
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result['error'] ?? 'Failed to delete device.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'Edit',
              child: Row(
                children: [
                  Icon(Icons.create_sharp, size: 20),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'Delete',
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

      ),
    );
  }
}
