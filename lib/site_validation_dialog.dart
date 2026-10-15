// lib/widgets/site_validation_dialog.dart
//
// "Site Validation Required" dialog. Flow when the employee taps VALIDATE:
//   1. live camera photo (camera only: no gallery)   2. current GPS
//   3. POST to the API, which does face check + distance + radius and is the final authority
// Failures show the server's message inline and the employee can retry while attempts remain.

import 'dart:async';
import 'dart:io';
import 'package:attendance_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models/site_validation_models.dart';
import '../services/site_validation_service.dart';

/// Returns true when the employee validated successfully.
Future<bool?> showSiteValidationDialog(
  BuildContext context, {
  required SiteValidationService service,
  required SiteValidationRequest request,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false, // must use the buttons
    builder: (_) => SiteValidationDialog(service: service, request: request),
  );
}

class SiteValidationDialog extends StatefulWidget {
  final SiteValidationService service;
  final SiteValidationRequest request;

  const SiteValidationDialog({super.key, required this.service, required this.request});

  @override
  State<SiteValidationDialog> createState() => _SiteValidationDialogState();
}

class _SiteValidationDialogState extends State<SiteValidationDialog> {
  late SiteValidationRequest _req = widget.request;
  final _picker = ImagePicker();

  // Countdown uses the server's "seconds remaining" + a local stopwatch, not the phone's clock.
  final Stopwatch _watch = Stopwatch()..start();
  late int _baseSeconds = _req.secondsRemaining;
  Timer? _timer;
  bool _refreshedAtZero = false;

  bool _busy = false;
  bool _success = false;
  String? _error;
  SiteValidationResult? _result;

  int get _remaining {
    final left = _baseSeconds - _watch.elapsed.inSeconds;
    return left < 0 ? 0 : left;
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (_remaining == 0 && !_refreshedAtZero && !_success) {
        _refreshedAtZero = true;
        _refresh(); // let the server say whether late answers are still accepted
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final r = await widget.service.getById(_req.id);
      if (!mounted) return;
      setState(() {
        _req = r;
        _baseSeconds = r.secondsRemaining;
        _watch
          ..reset()
          ..start();
        _refreshedAtZero = r.secondsRemaining == 0;
      });
    } on SiteValidationException {
      // keep what we have; the next action will surface the server's message
    }
  }

  // ---------------------------------------------------------------- steps
  Future<File?> _takePhoto() async {
    // Face-detection camera (liveness challenge); returns the captured photo, or null if the user backs out
    return Navigator.of(context).push<File>(
      MaterialPageRoute(
        builder: (_) => AttendanceActionScreen(
          isCheckOut: false,
          onSuccess: () {},
          captureOnly: true,
          title: 'Site validation',
        ),
      ),
    );
  }

  Future<Position?> _getPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      setState(() => _error = 'Turn on location services and try again.');
      return null;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      setState(() => _error = 'Location permission is required to validate your presence.');
      return null;
    }
    try {
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (pos.isMocked) {
        // Client-side hint only. The server remains the final authority.
        setState(() => _error = 'Mock location detected. Turn it off and try again.');
        return null;
      }
      return pos;
    } catch (_) {
      setState(() => _error = 'Could not get your current location. Move to an open area and retry.');
      return null;
    }
  }

  Future<void> _validate() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final photo = await _takePhoto();
      if (photo == null) {
        if (_error == null && mounted) setState(() => _error = 'A live photo is required to validate.');
        return;
      }
      final pos = await _getPosition();
      if (pos == null) return;

      final result = await widget.service.validate(_req.id, pos.latitude, pos.longitude, photo);
      if (!mounted) return;
      setState(() {
        _success = true;
        _result = result;
      });
      Future.delayed(const Duration(milliseconds: 1800), () {
        if (mounted) Navigator.of(context).pop(true);
      });
    } on SiteValidationException catch (e) {
      if (mounted) setState(() => _error = e.message);
      await _refresh(); // attempts left / still allowed?
    } finally {
      if (mounted && !_success) setState(() => _busy = false);
    }
  }

  // ---------------------------------------------------------------- UI
  String _clock(DateTime? utc) =>
      utc == null ? '-' : DateFormat('hh:mm a').format(utc.toLocal());

  String _mmss(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 74, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(value.isEmpty ? '-' : value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final canTry = _req.isPending && _req.canValidate && !_busy && !_success;
    final timeUp = _remaining == 0;

    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Row(children: [
          Icon(_success ? Icons.verified : Icons.my_location,
              color: _success ? Colors.green : Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(_success ? 'Presence validated' : 'Site Validation Required')),
        ]),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (_success) ...[
              Text(
                _result == null
                    ? 'Your presence was verified.'
                    : 'You are ${_result!.calculatedDistance.round()} m from the site '
                        '(allowed ${_result!.allowedRadius.round()} m).',
              ),
              if (_result?.isLate == true)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('Recorded as a late response.', style: TextStyle(color: Colors.orange)),
                ),
            ] else ...[
              const Text('Please verify your current presence.'),
              const SizedBox(height: 10),
              _row('Task', _req.taskTitle),
              _row('Project', _req.projectName),
              _row('Client', _req.clientName),
              if (_req.locationName.isNotEmpty) _row('Site', _req.locationName),
              _row('Started', _clock(_req.workStartedAt)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: (timeUp ? Colors.red : Colors.blue).shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  Icon(Icons.timer_outlined, size: 18, color: timeUp ? Colors.red : Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      timeUp ? 'Response time is over' : 'Respond within ${_mmss(_remaining)}',
                      style: TextStyle(color: timeUp ? Colors.red.shade700 : Colors.blue.shade800),
                    ),
                  ),
                ]),
              ),
              if (_req.attemptCount > 0 && _req.isPending)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Attempts left: ${_req.attemptsLeft}', style: const TextStyle(color: Colors.grey)),
                ),
              if (!_req.isPending)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _req.status.toLowerCase() == 'validated'
                        ? 'This request was already validated.'
                        : 'This request is no longer open (${_req.status}).',
                    style: const TextStyle(color: Colors.orange),
                  ),
                ),
              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.error_outline, size: 18, color: Colors.red.shade700),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: TextStyle(color: Colors.red.shade800))),
                  ]),
                ),
            ],
          ]),
        ),
        actions: _success
            ? [TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Done'))]
            : [
                TextButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(false),
                  child: const Text('Close'),
                ),
                FilledButton.icon(
                  onPressed: canTry ? _validate : null,
                  icon: _busy
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.camera_alt),
                  label: Text(_busy ? 'Checking...' : (_error == null ? 'VALIDATE' : 'TRY AGAIN')),
                ),
              ],
      ),
    );
  }
}
