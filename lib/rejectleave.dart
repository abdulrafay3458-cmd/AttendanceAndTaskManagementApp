
import 'package:flutter/material.dart';

class RejectLeaveDialog extends StatefulWidget {
  const RejectLeaveDialog({super.key});

  @override
  _RejectLeaveDialogState createState() => _RejectLeaveDialogState();
}

class _RejectLeaveDialogState extends State<RejectLeaveDialog> {
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Reject Leave'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Please provide a reason for rejection:'),
          SizedBox(height: 16),
          TextField(
            controller: _reasonController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Reason for rejection...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_reasonController.text.trim().isNotEmpty) {
              Navigator.pop(context, _reasonController.text.trim());
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          child: Text('Reject'),
        ),
      ],
    );
  }
}
