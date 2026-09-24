import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/leaverequestmodel.dart';
import '../services/apiservice.dart';

class CancelLeaveDaysDialog extends StatefulWidget {
  final LeaveRequestModel leave;

  const CancelLeaveDaysDialog({super.key, required this.leave});

  @override
  State<CancelLeaveDaysDialog> createState() => _CancelLeaveDaysDialogState();
}

class _CancelLeaveDaysDialogState extends State<CancelLeaveDaysDialog> {
  final TextEditingController _reasonController = TextEditingController();
  String? _errorText;
  final Set<DateTime> selectedDates = {};
  bool _isLoading = false;

  DateTime _normalize(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  List<DateTime> get leaveDates =>
      widget.leave.availableDates.map((d) => _normalize(d)).toList();

  Future<void> _cancelSelectedDays() async {
    if (selectedDates.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final success = await ApiService.cancelLeaveDays(
        employeeId: ApiService.employeeId!,
        leaveId: widget.leave.id,
        selectedDates: selectedDates.toList(),
        reason: _reasonController.text.trim(),
      );

      if (!mounted) return;
      setState(() => _isLoading = false);
      Navigator.pop(context, success);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      Navigator.pop(context, false);
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Height of the software keyboard (0 when not visible).
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: SingleChildScrollView(
          // Ensures the TextField scrolls into view above the keyboard.
          padding: EdgeInsets.only(bottom: bottomInset + 24),
          keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Cancel Leave',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              // Cap the list so the dialog never grows taller than
              // the screen; the rest scrolls inside this list.
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.35,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: leaveDates.length,
                  itemBuilder: (context, index) {
                    final date = leaveDates[index];
                    final isSelected = selectedDates.contains(date);

                    return CheckboxListTile(
                      value: isSelected,
                      activeColor: Colors.red,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            selectedDates.add(date);
                          } else {
                            selectedDates.remove(date);
                          }
                        });
                      },
                      title: Text(
                        DateFormat('EEE, MMM dd yyyy').format(date),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Reason",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),

              const SizedBox(height: 6),

              TextField(
                controller: _reasonController,
                maxLines: 3,
                // Ensures the field scrolls into view when focused.
                scrollPadding: const EdgeInsets.only(bottom: 24),
                decoration: InputDecoration(
                  hintText: "Why are you cancelling these leave days?",
                  errorText: _errorText,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        BorderSide(color: Theme.of(context).primaryColor),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading || selectedDates.isEmpty
                      ? null
                      : _cancelSelectedDays,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.red.shade200,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Cancel Selected Days',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}