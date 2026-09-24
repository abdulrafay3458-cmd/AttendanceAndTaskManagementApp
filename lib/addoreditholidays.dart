import 'package:attendance_app/services/apiservice.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
class HolidayForm extends StatefulWidget {
  final dynamic holiday; // null = add, not null = edit
  final VoidCallback onSave;

  const HolidayForm({super.key, this.holiday, required this.onSave});

  @override
  State<HolidayForm> createState() => _HolidayFormState();
}

class _HolidayFormState extends State<HolidayForm> {
  final TextEditingController _titleController = TextEditingController();
  late DateTime selectedDate;
  late bool isEditing;

  @override
  void initState() {
    super.initState();

    isEditing = widget.holiday != null;

    if (isEditing) {
      _titleController.text = widget.holiday.title;
      selectedDate = widget.holiday.holidayDate;
    } else {
      selectedDate = DateTime.now();
    }
  }

  Future<void> _saveHoliday() async {
    if (isEditing) {
      // Editing
      await ApiService.editHoliday(
        title: _titleController.text,
        holidayDate: selectedDate, // can still send it, but field is disabled
      );
    } else {
      // Adding
      await ApiService.saveHoliday(
        title: _titleController.text,
        holidayDate: selectedDate,
      );
    }

    widget.onSave();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isEditing ? "Edit Holiday" : "Add Holiday",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 20),

          // Holiday Title
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: "Holiday Title",
              border: OutlineInputBorder(),
            ),
          ),

          SizedBox(height: 16),

          // Date picker (disabled if editing)
          InkWell(
            onTap: isEditing
                ? null
                : () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (date != null) setState(() => selectedDate = date);
                  },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
                color: isEditing ? Colors.grey[200] : Colors.white,
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today),
                  const SizedBox(width: 10),
                  Text(DateFormat('MMM dd, yyyy').format(selectedDate)),
                ],
              ),
            ),
          ),

          SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveHoliday,
              child: Text(isEditing ? "Update Holiday" : "Save Holiday"),
            ),
          ),

          SizedBox(height: 20),
        ],
      ),
    );
  }
}