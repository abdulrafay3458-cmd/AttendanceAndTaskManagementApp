import 'dart:convert';

import 'package:attendance_app/main.dart';
import 'package:attendance_app/services/ApiClient.dart';
import 'package:attendance_app/services/apiservice.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class AbsentEmployeesScreen extends StatefulWidget {
  const AbsentEmployeesScreen({super.key});

  @override
  _AbsentEmployeesScreenState createState() => _AbsentEmployeesScreenState();
}

class _AbsentEmployeesScreenState extends State<AbsentEmployeesScreen> {
  List<dynamic> _absentEmployees = [];
  bool _isLoading = true;
  
  // Filter variables
  String _selectedFilter = 'Today';
  DateTime? _startDate;
  DateTime? _endDate;
  
  // Expanded state for accordion
  Set<int> _expandedCards = {};

  @override
  void initState() {
    super.initState();
    _loadAbsentEmployees();
  }

  Future<void> _loadAbsentEmployees() async {
    setState(() => _isLoading = true);

    try {
      final managerId = ApiService.employeeId;
      String url = '';
      
      if (_selectedFilter == 'Today') {
        url = 'report/absent/today?managerId=$managerId';
      } else {
        // Date range filter
        if (_startDate == null || _endDate == null) {
          // If dates not selected, default to last 7 days
          _endDate = DateTime.now();
          _startDate = _endDate!.subtract(Duration(days: 7));
        }
        
        final startDateStr = DateFormat('yyyy-MM-dd').format(_startDate!);
        final endDateStr = DateFormat('yyyy-MM-dd').format(_endDate!);
        url = 'report/absent/range?managerId=$managerId&startDate=$startDateStr&endDate=$endDateStr';
      }

      final response = await ApiClient().dio.get(url).timeout(Duration(seconds: 10));

      if (response.statusCode == 200) {
        setState(() {
          _absentEmployees = response.data;
          _isLoading = false;
          _expandedCards.clear(); // Reset expanded state on new data
        });
      } else {
        print('Error response: ${response.data}');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading absent employees: $e');
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
        _loadAbsentEmployees();
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
          'Absent Employees',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue[700],
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadAbsentEmployees,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Section
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.grey[50],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                SizedBox(height: 12),
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
                : _absentEmployees.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _selectedFilter == 'Today' 
                                  ? Icons.check_circle 
                                  : Icons.calendar_view_day,
                              size: 64, 
                              color: Colors.green,
                            ),
                            SizedBox(height: 16),
                            Text(
                              _selectedFilter == 'Today'
                                  ? 'Everyone present today!'
                                  : 'No absent records found',
                              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                            ),
                            SizedBox(height: 8),
                            Text(
                              _selectedFilter == 'Today'
                                  ? 'All employees checked in'
                                  : 'No absences in the selected date range',
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadAbsentEmployees,
                        child: ListView.builder(
                          padding: EdgeInsets.all(16),
                          itemCount: _absentEmployees.length,
                          itemBuilder: (context, index) {
                            final emp = _absentEmployees[index];
                            return _buildAbsentEmployeeCard(emp, index);
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
            _loadAbsentEmployees();
          } else if (label == 'Date Range' && _startDate != null && _endDate != null) {
            _loadAbsentEmployees();
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

  Widget _buildAbsentEmployeeCard(Map<String, dynamic> emp, int index) {
    final isExpanded = _expandedCards.contains(index);
    
    final absentRecords = emp['absentRecords'] as List? ?? [];
    final totalAbsentDays = emp['totalAbsentDays'] ?? absentRecords.length;

    if (absentRecords.isEmpty && _selectedFilter != 'Today') {
      return SizedBox.shrink();
    }

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      color: Colors.white,
      elevation: 3,
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.deepOrange[100],
              child: Icon(Icons.person_off, color: Colors.deepOrange[700]),
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
                if (_selectedFilter == 'Today') ...[
                  SizedBox(height: 4),
                  Text(
                    'No check-in recorded',
                    style: TextStyle(fontSize: 12, color: Colors.red),
                  ),
                ] else ...[
                  SizedBox(height: 4),
                  Text(
                    'Absent $totalAbsentDays day${totalAbsentDays > 1 ? 's' : ''} in selected range',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
            trailing: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.deepOrange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.deepOrange),
              ),
              child: Text(
                _selectedFilter == 'Today' 
                    ? 'ABSENT' 
                    : '$totalAbsentDays day${totalAbsentDays > 1 ? 's' : ''}',
                style: TextStyle(
                  color: Colors.deepOrange[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
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
          
          // Expanded Section (Accordion)
          if (isExpanded)
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
                    'Absent Details',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.deepOrange[700],
                    ),
                  ),
                  SizedBox(height: 12),
                  
                  if (_selectedFilter == 'Today') ...[
                    _buildDetailRow(
                      icon: Icons.calendar_today,
                      label: 'Date:',
                      value: DateFormat('EEEE, MMMM dd, yyyy').format(DateTime.now()),
                    ),
                    _buildDetailRow(
                      icon: Icons.info_outline,
                      label: 'Status:',
                      value: 'No check-in recorded',
                    ),
                  ] else ...[
                    // Date Range Details - List all absent dates
                    Text(
                      'Absent Dates:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    SizedBox(height: 8),
                    
                    if (absentRecords.isEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'No absent records for this period',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      )
                    else
                      Column(
                        children: absentRecords.map((record) {
                          final recordDate = record['date'] ?? '';
                          
                          String formattedDate = recordDate;
                          try {
                            if (recordDate.isNotEmpty) {
                              final dateTime = DateTime.parse(recordDate);
                              formattedDate = DateFormat('EEEE, MMMM dd, yyyy').format(dateTime);
                            }
                          } catch (e) {
                            print('Date parsing error: $e');
                          }
                          
                          return Container(
                            margin: EdgeInsets.only(bottom: 8),
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.circle, size: 8, color: Colors.deepOrange[400]),
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
                                      Text(
                                        'No check-in recorded',
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.deepOrange[50],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'ABSENT',
                                    style: TextStyle(
                                      color: Colors.deepOrange[700],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      
                    SizedBox(height: 12),
                    _buildDetailRow(
                      icon: Icons.date_range,
                      label: 'Selected Range:',
                      value: '${DateFormat('MMM dd, yyyy').format(_startDate!)} - ${DateFormat('MMM dd, yyyy').format(_endDate!)}',
                    ),
                    _buildDetailRow(
                      icon: Icons.calendar_today,
                      label: 'Total Absent Days:',
                      value: '$totalAbsentDays day${totalAbsentDays > 1 ? 's' : ''}',
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
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