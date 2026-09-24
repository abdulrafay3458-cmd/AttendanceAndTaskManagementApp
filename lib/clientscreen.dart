import 'package:attendance_app/assigntask.dart';
import 'package:attendance_app/clientsetup.dart';
import 'package:attendance_app/services/apiservice.dart';
import 'package:attendance_app/services/clients.dart';
import 'package:flutter/material.dart';

class Clientscreen extends StatefulWidget {
  
  const Clientscreen({super.key});

  @override
  _Clientscreen createState() => _Clientscreen();
}

class _Clientscreen extends State<Clientscreen> {
  List<Clients> _client = [];
  List<Clients> _filteredClients = [];
  bool isClientActive = true;
  bool _isLoading = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadClient();

    _searchController.addListener(() {
      _filteredClientsList();
    });
  }

  Future<void> _loadClient() async {
    setState(() => _isLoading = true);

    final data = await ApiService.getClients();
    setState(() {
      _client = data.map((json) => Clients.fromJson(json)).toList();
      _filteredClients = List.from(_client);
      _isLoading = false;
    });
  }

  void _filteredClientsList() {
      final query = _searchController.text.toLowerCase().trim();
      
      if (query.isEmpty) {
        setState(() {
          _filteredClients = List.from(_client);
        });
      } else {
        setState(() {
          _filteredClients = _client.where((member) {
            return member.clientName.toLowerCase().contains(query) ||
                  member.clientCode.toLowerCase().contains(query) ||
                  member.clientEmail.toLowerCase().contains(query) ||
                  member.clientPhone.toLowerCase().contains(query);
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
      _filteredClients = List.from(_client);
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
          : _filteredClients.isEmpty
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
                    : 'No clients found',
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
              onRefresh: _loadClient,
              child: ListView.builder(
                padding: EdgeInsets.all(16),
                itemCount: _filteredClients.length,
                itemBuilder: (context, index) {
                  final clientData = _filteredClients[index];
                  return _clientName(clientData);
                },
              ),
            ),
          ],
          ),
          floatingActionButton: FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ClientSetup(),
                  ),
                );
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
      title: Text('Client List', style: TextStyle(fontWeight: FontWeight.w600),),
      backgroundColor: Colors.white,
      foregroundColor: Colors.blue[700],
      actions: [
        IconButton(
          icon: Icon(Icons.search),
          onPressed: _startSearch,
        ),
        IconButton(
          icon: Icon(Icons.refresh),
          onPressed: _loadClient,
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
          hintText: 'Search Client...',
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
            _filteredClientsList();
          },
        ),
      ],
    );
  }

  Widget _clientName(Clients client) {
    return Card(
      color: Colors.white,
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        contentPadding: EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Colors.blue[100],
          radius: 28,
          child: Text(
            client.clientName.substring(0, 1).toUpperCase(),
            style: TextStyle(
              color: Colors.blue[700],
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
        title: Text(
          client.clientName,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.badge, size: 14, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text(
                  client.clientCode,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.mail, size: 14, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text(
                  client.clientEmail,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                SizedBox(width: 4),
                Text(
                  client.clientPhone,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            SizedBox(height: 4),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert),
          color: Colors.blue.shade50,
          onSelected: (value) {
            if (value == 'assign_task') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AssignTaskScreen()),
              );
            } else if (value == 'Edit') {
            
            final clientData = {
              // 'managerId': member.managerId,
              'clientCode': client.clientCode,
              'clientName': client.clientName,
              'clientSuitNo' : client.clientSuitNo,
              'clientSteetNO' : client.clientSteetNO,
              'clientPostalCode' : client.clientPostalCode,
              'clientTown' : client.clientTown,
              'clientProvince' : client.clientProvince,
              'clientCountry': client.clientCountry,
              'clientLegalName' : client.clientLegalName,
              'clientEmail': client.clientEmail,
              'clientPhone': client.clientPhone,
              'clientIndustryCode': client.clientIndustryCode,
              'clientFax': client.clientFax,
              'clientShortName': client.clientShortName,
              'clientCountryCode': client.clientCountryCode,
              'clientGlCode': client.clientGlCode,
              'clientFiscalYear': client.clientFiscalYear,
              'clientParentCode': client.clientParentCode,
              'clientChildCode': client.clientChildCode,
              'clientStatus': client.clientStatus,
              'clientVendor': client.clientVendor,
            };

              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ClientSetup(
                  isEditing: true,
                  clientData: clientData,
                ))
              );
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'Edit',
              child: Row(
                children: [
                  Icon(
                    Icons.create_sharp,
                    size: 20,
                    color: Colors.blue[800]
                  ),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
