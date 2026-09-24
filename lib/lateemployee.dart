import 'dart:convert';

import 'package:attendance_app/main.dart';
import 'package:attendance_app/services/ApiClient.dart';
import 'package:attendance_app/services/apiservice.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class LateEmployeesScreen extends StatefulWidget {
  const LateEmployeesScreen({super.key});

  @override
  _LateEmployeesScreenState createState() => _LateEmployeesScreenState();
}

class _LateEmployeesScreenState extends State<LateEmployeesScreen> {
  List<dynamic> _lateEmployees = [];
  bool _isLoading = true;
  
  // Filter variables
  String _selectedFilter = 'Today';
  DateTime? _startDate;
  DateTime? _endDate;
  
  Set<int> _expandedCards = {};

  @override
  void initState() {
    super.initState();
    _loadLateEmployees();
  }

  Future<void> _loadLateEmployees() async {
    setState(() => _isLoading = true);

    try {
      final managerId = ApiService.employeeId;
      String url = '';
      
      if (_selectedFilter == 'Today') {
        url = 'report/late/today?managerId=$managerId';
      } else {
        // Date range filter
        if (_startDate == null || _endDate == null) {
          // If dates not selected, default to last 7 days
          _endDate = DateTime.now();
          _startDate = _endDate!.subtract(Duration(days: 7));
        }
        
        final startDateStr = DateFormat('yyyy-MM-dd').format(_startDate!);
        final endDateStr = DateFormat('yyyy-MM-dd').format(_endDate!);
        url = 'report/late/range?managerId=$managerId&startDate=$startDateStr&endDate=$endDateStr';
      }

      final response = await ApiClient().dio.get(url).timeout(Duration(seconds: 10));

      print('LATE RESPONSE - ${response}');
      if (response.statusCode == 200) {
        setState(() {
          _lateEmployees = response.data;
          _isLoading = false;
          _expandedCards.clear();
        });
      }
    } catch (e) {
      print('Error loading late employees: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDateRange() async {
    final DateTime? pickedStart = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Select Start Date',
    );

    if (pickedStart != null) {
      final DateTime? pickedEnd = await showDatePicker(
        context: context,
        initialDate: _endDate ?? DateTime.now(),
        firstDate: pickedStart,
        lastDate: DateTime.now(),
        helpText: 'Select End Date',
      );

      if (pickedEnd != null) {
        setState(() {
          _startDate = pickedStart;
          _endDate = pickedEnd;
        });
        _loadLateEmployees();
      }
    }
  }

  String _getFilterDisplayText() {
    if (_selectedFilter == 'Today') {
      return 'Today: ${DateFormat('MMM dd, yyyy').format(DateTime.now())}';
    } else {
      if (_startDate != null && _endDate != null) {
        return '${DateFormat('MMM dd, yyyy').format(_startDate!)} - ${DateFormat('MMM dd, yyyy').format(_endDate!)}';
      }
      return 'Select Date Range';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Late Employees',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue[700],
        actions: [
          IconButton(icon: Icon(Icons.refresh), onPressed: _loadLateEmployees),
        ],
      ),
      body: Column(
        children: [
          // Filter Section
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.grey[50],
            child: Column(
              // crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildFilterChip('Today', Icons.today),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildFilterChip('Date Range', Icons.date_range),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                if (_selectedFilter == 'Date Range')
                  InkWell(
                    onTap: _selectDateRange,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.white,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, size: 18, color: Colors.blue[700]),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _getFilterDisplayText(),
                              style: TextStyle(
                                color: (_startDate == null || _endDate == null) 
                                    ? Colors.grey 
                                    : Colors.black,
                              ),
                            ),
                          ),
                          Icon(Icons.arrow_drop_down, color: Colors.grey),
                        ],
                      ),
                    ),
                  )
                else
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.today, size: 18, color: Colors.blue[700]),
                        SizedBox(width: 8),
                        Text(_getFilterDisplayText()),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _lateEmployees.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.alarm_off, size: 64, color: Colors.grey[400]),
                            SizedBox(height: 16),
                            Text(
                              'No late employees found',
                              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                            ),
                            SizedBox(height: 8),
                            Text(
                              _selectedFilter == 'Today' 
                                  ? 'Everyone checked in on time today!' 
                                  : 'No late records in the selected date range',
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadLateEmployees,
                        child: ListView.builder(
                          padding: EdgeInsets.all(16),
                          itemCount: _lateEmployees.length,
                          itemBuilder: (context, index) {
                            final emp = _lateEmployees[index];
                            return _buildLateEmployeeCard(emp, index);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, IconData icon) {
    final isSelected = _selectedFilter == label;
    return FilterChip(
      label: Row(
        // mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.blue[700]),
          SizedBox(width: 4, height: 28,),
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedFilter = label;
          });
          if (label == 'Today') {
            _loadLateEmployees();
          } else if (label == 'Date Range' && _startDate != null && _endDate != null) {
            _loadLateEmployees();
          }
        }
      },
      selectedColor: Colors.blue[700],
      checkmarkColor: Colors.white,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontSize: 13,
      ),
    );
  }

  Widget _buildLateEmployeeCard(Map<String, dynamic> emp, int index) {
    final isExpanded = _expandedCards.contains(index);

    final lateRecords = emp['lateRecords'] as List? ?? [];
    final totalLateMinutes = emp['totalLateMinutes'] ?? 0;

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      color: Colors.white,
      elevation: 3,
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.red[100],
              child: Icon(Icons.alarm, color: Colors.red[700]),
            ),
            title: Text(
              emp['employeeName'] ?? 'Unknown',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 4),
                Text('${emp['employeeId'] ?? ''} • ${emp['department'] ?? ''}'),
                SizedBox(height: 4),
                Text(
                  'Late ${lateRecords.length} time${lateRecords.length > 1 ? 's' : ''} in selected range',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            trailing: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red),
              ),
              child: Text(
                'Total\n$totalLateMinutes min',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.red[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedCards.remove(index);
                } else {
                  _expandedCards.add(index);
                }
              });
            },
          ),
          
          // Expanded Section showing all late dates
          if (isExpanded && lateRecords.isNotEmpty)
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                border: Border(
                  top: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Late Details',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.blue[700],
                    ),
                  ),
                  SizedBox(height: 12),
                  
                  // List all late dates
                  ...lateRecords.map((record) {
                    final dateStr = record['date'] ?? '';
                    final lateByStr = record['lateBy'] ?? '00:00:00';
                    final lateMinutes = record['lateMinutes'] ?? 0;
                    
                    // Parse date
                    String formattedDate = dateStr;
                    try {
                      if (dateStr.isNotEmpty) {
                        final dateTime = DateTime.parse(dateStr);
                        formattedDate = DateFormat('EEEE, MMMM dd, yyyy').format(dateTime);
                      }
                    } catch (e) {
                      print('Date parsing error: $e');
                    }
                    
                    return Container(
                      margin: EdgeInsets.only(bottom: 12),
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, size: 16, color: Colors.blue[700]),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  formattedDate,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                                if (record['checkInTime'] != null)
                                  Text(
                                    'Check-in: ${_formatCheckInTime(record['checkInTime'])}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$lateMinutes min',
                              style: TextStyle(
                                color: Colors.red[700],
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  
                  SizedBox(height: 8),
                  _buildDetailRow(
                    icon: Icons.date_range,
                    label: 'Date Range:',
                    value: '${DateFormat('MMM dd, yyyy').format(_startDate!)} - ${DateFormat('MMM dd, yyyy').format(_endDate!)}',
                  ),
                  _buildDetailRow(
                    icon: Icons.timer,
                    label: 'Total Late:',
                    value: '$totalLateMinutes minutes across ${lateRecords.length} day(s)',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _formatCheckInTime(String? checkInTimeStr) {
    if (checkInTimeStr == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(checkInTimeStr);
      return DateFormat('hh:mm a').format(dateTime.toLocal());
    } catch (e) {
      return checkInTimeStr;
    }
  }

  Widget _buildDetailRow({required IconData icon, required String label, required String value}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          SizedBox(width: 8),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}