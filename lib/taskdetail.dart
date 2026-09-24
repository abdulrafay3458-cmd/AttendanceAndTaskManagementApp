import 'package:attendance_app/services/apiservice.dart';
import 'package:attendance_app/services/taskmodel.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TaskDetailsSheet extends StatefulWidget {
  final TaskModel task;
  final VoidCallback onUpdate;

  const TaskDetailsSheet({
    super.key,
    required this.task,
    required this.onUpdate,
  });

  @override
  State<TaskDetailsSheet> createState() => _TaskDetailsSheetState();
}

class _TaskDetailsSheetState extends State<TaskDetailsSheet> {
  double overtimeHours = 0;

  void _showOvertimeDialog(BuildContext context) {
    final hourController = TextEditingController();
    final minuteController = TextEditingController();
    final reasonController = TextEditingController();
    final dateController = TextEditingController();
    DateTime? selectedDate = DateTime.now();
    bool isSaving = false;

    // Store the parent context for showing SnackBar
    final parentContext = context;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> selectDate() async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: selectedDate ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: Colors.blue,
                        onPrimary: Colors.white,
                        onSurface: Colors.black,
                      ),
                      dialogBackgroundColor: Colors.white,
                    ),
                    child: child!,
                  );
                },
              );

              if (picked != null && picked != selectedDate) {
                setDialogState(() {
                  selectedDate = picked;
                  dateController.text = DateFormat('yyyy-MM-dd').format(picked);
                });
              }
            }

            return AlertDialog(
              title: const Text("Add Overtime"),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: dateController,
                      decoration: const InputDecoration(
                        labelText: "Date",
                        hintText: "Tap to select date",
                        suffixIcon: Icon(Icons.calendar_today),
                        border: OutlineInputBorder(),
                      ),
                      readOnly: true,
                      onTap: selectDate,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a date';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: hourController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Hours",
                              hintText: "e.g 2",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: minuteController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Minutes",
                              hintText: "e.g 30",
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: reasonController,
                      maxLines: 3,
                      minLines: 2,
                      decoration: const InputDecoration(
                        labelText: "Reason (optional)",
                        hintText: "Enter reason for overtime...",
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          // Validate date
                          if (dateController.text.isEmpty) {
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              const SnackBar(
                                content: Text('Please select a date'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }

                          final h = int.tryParse(hourController.text) ?? 0;
                          final m = int.tryParse(minuteController.text) ?? 0;
                          final totalHours = h + (m / 60);

                          if (totalHours <= 0) {
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              const SnackBar(
                                content: Text('Enter a valid duration'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }

                          setDialogState(() => isSaving = true);

                          // Parse the selected date
                          DateTime overtimeDate;
                          try {
                            overtimeDate = DateFormat('yyyy-MM-dd').parse(dateController.text);
                          } catch (e) {
                            overtimeDate = DateTime.now();
                          }

                          // Send to API with the selected date
                          final result = await ApiService.addOvertime(
                            userTaskId: widget.task.id,
                            overtimeDate: overtimeDate,
                            overtimeHours: totalHours,
                            reason: reasonController.text.trim().isEmpty
                                ? null
                                : reasonController.text.trim(),
                          );

                          // Close the dialog FIRST
                          Navigator.pop(dialogContext);

                          // Check if the parent widget is still mounted
                          if (!mounted) return;

                          // Wait a tiny moment for the dialog to fully close
                          await Future.delayed(const Duration(milliseconds: 100));

                          // Now show messages using the parent context
                          if (result['success'] == true) {
                            // Update local state
                            setState(() {
                              overtimeHours += totalHours;
                            });
                            
                            // Refresh parent data
                            widget.onUpdate();
                            
                            // Show success message
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              const SnackBar(
                                content: Text('✓ Overtime added successfully'),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 3),
                              ),
                            );
                          } else {
                            // Show error message
                            ScaffoldMessenger.of(parentContext).showSnackBar(
                              SnackBar(
                                content: Text(result['error'] ?? 'Failed to save overtime'),
                                backgroundColor: Colors.red,
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text("Add"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;

    return Material(
      color: Colors.black54,
      child: Column(
        children: [
          SizedBox(height: height * 0.08),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _header(context),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _titleSection(),
                          const SizedBox(height: 18),
                          _assignedSection(),
                          const SizedBox(height: 18),
                          _descriptionSection(),
                          const SizedBox(height: 18),
                          _dateSection(),
                          const SizedBox(height: 18),
                          _timeLogsSection(context),
                          const SizedBox(height: 18),
                          _totalHoursSection(),
                          if (widget.task.status != 'completed') ...[
                            const SizedBox(height: 18),
                            _completeButton(context),
                          ]
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      height: 56,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFEAEAEA)),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const Text(
            "Task Detail",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _overtimeSection() {
    if (overtimeHours == 0) return const SizedBox();

    final minutes = (overtimeHours * 60).round();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, color: Colors.orange),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Overtime Added: ${overtimeHours.toStringAsFixed(1)}h ($minutes min)",
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.orange,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _titleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Task Title", style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 6),
        Text(
          widget.task.taskTitle,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _badge(widget.task.priority, Colors.red.shade100, Colors.red),
            const SizedBox(width: 8),
            _badge(widget.task.status, Colors.blue.shade100, Colors.blue),
          ],
        )
      ],
    );
  }

  Widget _assignedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Assigned By", style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 8),
        Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.blue,
              child: Text(
                widget.task.assignedByName.isNotEmpty
                    ? widget.task.assignedByName[0].toUpperCase()
                    : "?",
                style: const TextStyle(color: Colors.white),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              widget.task.assignedByName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }

  Widget _descriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Project Description", style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 6),
        Text(widget.task.taskDescription),
      ],
    );
  }

  Widget _dateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoRow(Icons.calendar_today,
            DateFormat('MMM dd, yyyy').format(widget.task.assignedDate)),
        _infoRow(Icons.event,
            widget.task.dueDate != null ? DateFormat('MMM dd, yyyy').format(widget.task.dueDate!) : 'No due date'),
        _infoRow(Icons.business, widget.task.clientName ?? ''),
        _infoRow(Icons.tune, widget.task.taskPreference),
      ],
    );
  }

  Widget _timeLogsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Task Logs",
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextButton.icon(
              onPressed: () => _showOvertimeDialog(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text("Add Overtime"),
            )
          ],
        ),
        const SizedBox(height: 10),
        _overtimeSection(),
        ConstrainedBox(
          constraints: const BoxConstraints(
            maxHeight: 260,
          ),
          child: ListView.builder(
            shrinkWrap: true,
            physics: const BouncingScrollPhysics(),
            itemCount: widget.task.timeLogs.length,
            itemBuilder: (context, index) {
              final log = widget.task.timeLogs[index];

              double hoursWorked = log.hoursWorked ?? 0.0;

              if (log.startTime != null &&
                  log.stopTime != null &&
                  hoursWorked == 0) {
                hoursWorked =
                    (log.stopTime!.difference(log.startTime!).inMinutes / 60);
              }

              final minutes = (hoursWorked * 60).round();

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            log.employeeCode,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Colors.blue,
                            ),
                          ),
                          Text(
                            DateFormat('MMM dd, yyyy').format(log.date),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(Icons.login, size: 12, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                log.startTime != null
                                    ? DateFormat('hh:mm a').format(log.startTime!.toLocal())
                                    : "--",
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                              const SizedBox(width: 10),
                              const Icon(Icons.logout, size: 12, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                log.stopTime != null
                                    ? DateFormat('hh:mm a').format(log.stopTime!.toLocal())
                                    : "--",
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "${hoursWorked.toStringAsFixed(1)}h",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          "$minutes min",
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _totalHoursSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "Total Hours",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            formatHours(widget.task.totalHoursWorked),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: Colors.blue.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _completeButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: () async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Complete Task'),
              content: const Text('Mark this task as completed?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Complete'),
                ),
              ],
            ),
          );

          if (confirm == true) {
            final employeeId = ApiService.employeeId;
            if (employeeId != null) {
              final result = await ApiService.completeTask(
                employeeId: employeeId,
                taskId: widget.task.id,
              );

              if (result['success'] == true) {
                Navigator.pop(context);
                widget.onUpdate();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result['error']),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          }
        },
        child: const Text(
          "Mark as Completed",
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _badge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }
}

String formatHours(double totalHours) {
  final duration = Duration(minutes: (totalHours * 60).round());
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  return '${hours}h ${minutes}m';
}