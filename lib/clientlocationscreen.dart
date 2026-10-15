import 'package:attendance_app/clientlocationsetup.dart';
import 'package:attendance_app/services/client_location.dart';
import 'package:attendance_app/services/client_location_service.dart';
import 'package:flutter/material.dart';

class ClientLocationScreen extends StatefulWidget {
  const ClientLocationScreen({super.key});

  @override
  State<ClientLocationScreen> createState() => _ClientLocationScreenState();
}

class _ClientLocationScreenState extends State<ClientLocationScreen> {
  List<ClientLocation> _locations = [];
  List<ClientLocation> _filtered = [];
  bool _isLoading = true;
  bool _isSearching = false;
  String _statusFilter = 'All'; // All / Active / Inactive
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final data = await ClientLocationService.getClientLocations();
    if (!mounted) return;
    setState(() {
      _locations = data;
      _isLoading = false;
    });
    _applyFilters();
  }

  void _applyFilters() {
    final q = _searchController.text.toLowerCase().trim();
    setState(() {
      _filtered = _locations.where((l) {
        final matchesSearch = q.isEmpty ||
            l.locationName.toLowerCase().contains(q) ||
            l.address.toLowerCase().contains(q) ||
            l.clientName.toLowerCase().contains(q);
        final matchesStatus = _statusFilter == 'All' ||
            (_statusFilter == 'Active' && l.isActive) ||
            (_statusFilter == 'Inactive' && !l.isActive);
        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  void _startSearch() => setState(() => _isSearching = true);

  void _stopSearch() {
    setState(() => _isSearching = false);
    _searchController.clear();
    _applyFilters();
  }

  Future<void> _openSetup({ClientLocation? location}) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ClientLocationSetup(location: location),
      ),
    );
    if (changed == true) _load();
  }

  Future<void> _confirmDelete(ClientLocation loc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Location'),
        content: Text('Are you sure you want to delete "${loc.locationName}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final success =
        await ClientLocationService.deleteClientLocation(loc.clientLocationId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(success
          ? 'Location deleted'
          : (ClientLocationService.lastError.isNotEmpty
              ? ClientLocationService.lastError
              : 'Failed to delete location')),
      backgroundColor: success ? Colors.green : Colors.red,
    ));
    if (success) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isSearching ? _buildSearchAppBar() : _buildNormalAppBar(),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openSetup(),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: ['All', 'Active', 'Inactive'].map((s) {
          final selected = _statusFilter == s;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(s),
              selected: selected,
              selectedColor: Colors.blue[100],
              labelStyle: TextStyle(
                color: selected ? Colors.blue[800] : Colors.grey[700],
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
              onSelected: (_) {
                _statusFilter = s;
                _applyFilters();
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_filtered.isEmpty) {
      final searching = _searchController.text.isNotEmpty;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(searching ? Icons.search_off : Icons.location_off_outlined,
                size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              searching
                  ? 'No result found for "${_searchController.text}"'
                  : 'No client locations found',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            if (searching)
              TextButton(onPressed: _stopSearch, child: const Text('Clear Search')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filtered.length,
        itemBuilder: (_, i) => _locationCard(_filtered[i]),
      ),
    );
  }

  AppBar _buildNormalAppBar() {
    return AppBar(
      title: const Text('Client Locations',
          style: TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: Colors.white,
      foregroundColor: Colors.blue[700],
      actions: [
        IconButton(icon: const Icon(Icons.search), onPressed: _startSearch),
        IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
      ],
    );
  }

  AppBar _buildSearchAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: Colors.blue[700],
      leading: IconButton(
          icon: const Icon(Icons.arrow_back), onPressed: _stopSearch),
      title: TextField(
        controller: _searchController,
        autofocus: true,
        style: TextStyle(color: Colors.blue[700]),
        cursorColor: Colors.blue[700],
        decoration: InputDecoration(
          hintText: 'Search location, address or client...',
          hintStyle: TextStyle(color: Colors.blue[300]),
          border: InputBorder.none,
        ),
      ),
      actions: [
        if (_searchController.text.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () => _searchController.clear(),
          ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Expanded(
            child: Text(text,
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ),
        ],
      ),
    );
  }

  Widget _locationCard(ClientLocation loc) {
    final statusColor = loc.isActive ? Colors.green : Colors.red;

    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        onTap: () => _openSetup(location: loc),
        leading: CircleAvatar(
          backgroundColor: Colors.blue[100],
          radius: 28,
          child: Icon(Icons.location_on, color: Colors.blue[700], size: 26),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(loc.locationName,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                loc.isActive ? 'Active' : 'Inactive',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            _infoRow(Icons.business_center_rounded, loc.clientName),
            _infoRow(Icons.place_outlined, loc.address),
            _infoRow(Icons.my_location,
                '${loc.latitude.toStringAsFixed(5)}, ${loc.longitude.toStringAsFixed(5)}'),
            _infoRow(Icons.radar,
                'Allowed radius: ${loc.allowedRadius.toStringAsFixed(0)} m'),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          color: Colors.blue.shade50,
          onSelected: (value) {
            if (value == 'Edit') {
              _openSetup(location: loc);
            } else if (value == 'Delete') {
              _confirmDelete(loc);
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'Edit',
              child: Row(children: [
                Icon(Icons.create_sharp, size: 20, color: Colors.blue[800]),
                const SizedBox(width: 8),
                const Text('Edit'),
              ]),
            ),
            const PopupMenuItem(
              value: 'Delete',
              child: Row(children: [
                Icon(Icons.delete_outline, size: 20, color: Colors.red),
                SizedBox(width: 8),
                Text('Delete', style: TextStyle(color: Colors.red)),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}