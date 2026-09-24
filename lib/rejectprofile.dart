
import 'package:flutter/material.dart';

class RejectProfileDialog extends StatefulWidget {
  const RejectProfileDialog({super.key});

  @override
  _RejectProfileDialogState createState() => _RejectProfileDialogState();
}

class _RejectProfileDialogState extends State<RejectProfileDialog> {
  final _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Reject Profile Photo'),
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
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: Text('Reject'),
        ),
      ],
    );
  }
}
