import 'package:attendance_app/addoreditholidays.dart';
import 'package:attendance_app/models/HolidaysModel.dart';
import 'package:attendance_app/services/apiservice.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';



class HolidaySetup extends StatefulWidget {
  const HolidaySetup({super.key});

  @override
  State<HolidaySetup> createState() => _HolidaySetupState();
}

class _HolidaySetupState extends State<HolidaySetup> {
    // List<Holiday> _holidays = [];
  List<Holiday> _filteredHolidays = [];
  bool _isLoading = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  List<Holiday> holidays = [];

  @override
  void initState() {
    super.initState();
    loadHolidays();
        _searchController.addListener(() {
      _filteredSearchHolidays();
    });
  }

  Future<void> loadHolidays() async {
    final data = await ApiService.getHolidays();
    setState(() {
      holidays = data;
    });
  }

  void _showHolidayDialog({dynamic holiday}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => HolidayForm(
        holiday: holiday,
        onSave: () {
          loadHolidays();
          Navigator.pop(context);
        },
      ),
    );
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
      _filteredHolidays = List.from(holidays);
    });
  }
    void _filteredSearchHolidays() {
    final query = _searchController.text.toLowerCase().trim();
 
    if (query.isEmpty) {
      setState(() {
        _filteredHolidays = List.from(holidays);
      });
    } else {
      setState(() {
        holidays = holidays.where((member) {
          return member.title.toLowerCase().contains(query);
        }).toList();
      });
    }
  
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
 appBar: _isSearching ? _buildSearchAppBar() : _buildNormalAppBar(),

      body: holidays.isEmpty
          ? const Center(child: Text("No holidays added"))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: holidays.length,
              itemBuilder: (context, index) {
                final h = holidays[index];

                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  // color: const Color.fromARGB(255, 220, 235, 220),
                  child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color.fromARGB(255, 220, 235, 220),
          radius: 28,
          child: Text(
            h.title.substring(0, 1).toUpperCase(),
            style: TextStyle(
              color: const Color.fromARGB(255, 85, 120, 85),
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ),
                    title: Text(
                      h.title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      DateFormat('MMM dd, yyyy').format(h.holidayDate),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        _showHolidayDialog(holiday: h);
                      },
                    ),
                  ),
                );
              },
            ),

      floatingActionButton: FloatingActionButton(
        onPressed: () => _showHolidayDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
    AppBar _buildNormalAppBar() {
    return AppBar(
      title: Text('Holidays Setup', style: TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: Colors.white,
      foregroundColor: Colors.blue[700],
      actions: [
        IconButton(icon: Icon(Icons.search), onPressed: _startSearch),
        IconButton(icon: Icon(Icons.refresh), onPressed: loadHolidays),
      ],
    );
  }
    AppBar _buildSearchAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: Colors.blue[700],
      leading: IconButton(icon: Icon(Icons.arrow_back), onPressed: _stopSearch),
      title: TextField(
        controller: _searchController,
        autofocus: true,
        style: TextStyle(color: Colors.blue[700]),
        decoration: InputDecoration(
          hintText: 'Search holiday...',
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
            // Optional: You can add additional search logic here
            _filteredSearchHolidays();
          },
        ),
      ],
    );
  }
  

 
}