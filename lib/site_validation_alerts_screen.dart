// lib/screens/site_validation_alerts_screen.dart
//
// Team Head view of unanswered / failed / late site validations for their team.
// Calls GET api/site-validations/team-alerts (SiteValidationService.getTeamAlerts).
//
//   Navigator.push(context, MaterialPageRoute(
//     builder: (_) => SiteValidationAlertsScreen(service: siteValidationService)));

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/site_validation_models.dart';
import '../services/site_validation_service.dart';

class SiteValidationAlertsScreen extends StatefulWidget {
  final SiteValidationService service;
  const SiteValidationAlertsScreen({super.key, required this.service});

  @override
  State<SiteValidationAlertsScreen> createState() => _SiteValidationAlertsScreenState();
}

class _SiteValidationAlertsScreenState extends State<SiteValidationAlertsScreen> {
  int _days = 7;
  List<SiteValidationRequest> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await widget.service.getTeamAlerts(days: _days);
      if (!mounted) return;
      setState(() {
        _items = r;
        _loading = false;
      });
    } on SiteValidationException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  String _when(DateTime? utc) =>
      utc == null ? '-' : DateFormat('dd MMM, hh:mm a').format(utc.toLocal());

  Color _statusColor(SiteValidationRequest r) {
    switch (r.status.toLowerCase()) {
      case 'expired':
        return Colors.red;
      case 'failed':
        return Colors.orange;
      default:
        return r.isLate ? Colors.amber.shade800 : Colors.green;
    }
  }

  String _statusLabel(SiteValidationRequest r) {
    final s = r.status.toLowerCase();
    if (s == 'expired') return 'No response';
    if (s == 'failed') return 'Failed';
    if (r.isLate) return 'Late response';
    return r.status;
  }

  Widget _row(String label, String value, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 96, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(
            child: Text(value.isEmpty ? '-' : value,
                style: TextStyle(fontWeight: FontWeight.w600, color: color)),
          ),
        ]),
      );

  Color? _verifyColor(String v) {
    switch (v.toLowerCase()) {
      case 'passed':
        return Colors.green;
      case 'failed':
        return Colors.red;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Site Validation Alerts'),
        actions: [
          PopupMenuButton<int>(
            tooltip: 'Period',
            icon: const Icon(Icons.filter_list),
            initialValue: _days,
            onSelected: (d) {
              _days = d;
              _load();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 1, child: Text('Last 24 hours')),
              PopupMenuItem(value: 7, child: Text('Last 7 days')),
              PopupMenuItem(value: 30, child: Text('Last 30 days')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(_error!),
                    TextButton(onPressed: _load, child: const Text('Retry')),
                  ]),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _items.isEmpty
                      ? ListView(children: [
                          const SizedBox(height: 160),
                          Center(
                            child: Text('No alerts in the last $_days day(s).',
                                style: const TextStyle(color: Colors.grey)),
                          ),
                        ])
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _items.length,
                          itemBuilder: (_, i) => _card(_items[i]),
                        ),
                ),
    );
  }

  Widget _card(SiteValidationRequest r) {
    final color = _statusColor(r);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: CircleAvatar(
            backgroundColor: color.withOpacity(0.12),
            child: Icon(Icons.report_problem_outlined, color: color),
          ),
          title: Text(r.employeeName.isEmpty ? 'Employee' : r.employeeName,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('${r.taskTitle} • ${r.projectName}\nRequested ${_when(r.requestedDateTime)}'),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(_statusLabel(r),
                style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row('Client', r.clientName),
            if (r.locationName.isNotEmpty) _row('Site', r.locationName),
            _row('Requested', _when(r.requestedDateTime)),
            _row('Respond by', _when(r.responseDueDateTime)),
            _row('Face check', r.faceVerificationStatus, color: _verifyColor(r.faceVerificationStatus)),
            _row('Location check', r.locationVerificationStatus,
                color: _verifyColor(r.locationVerificationStatus)),
            if (r.calculatedDistance != null)
              _row('Distance',
                  '${r.calculatedDistance!.round()} m (allowed ${r.allowedRadius.round()} m)'),
            _row('Attempts', '${r.attemptCount} of ${r.maxAttempts}'),
            if ((r.remarks ?? '').isNotEmpty) _row('Remarks', r.remarks!),
          ],
        ),
      ),
    );
  }
}
