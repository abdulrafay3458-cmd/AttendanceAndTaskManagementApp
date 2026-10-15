import 'dart:async';
import 'dart:io';
import 'dart:ui' show FontFeature;
import 'package:attendance_app/services/apiservice.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../models/work_models.dart';
import '../services/work_service.dart';
import '../widgets/app_date.dart';
import 'package:attendance_app/main.dart' show AttendanceActionScreen;

const _kBg = Color(0xFFF5F6FA);
const _kInk = Color(0xFF1F2430);
const _kMuted = Color(0xFF7A8194);
const _kLine = Color(0xFFE6E8F0);
const _kGreen = Color(0xFF22A06B);
const _kRed = Color(0xFFE5484D);
const _kAmber = Color(0xFFE59A1F);

final _baseColor = const Color.fromARGB(255, 12, 86, 147);
final _bannerGradient = LinearGradient(
  colors: [_baseColor, _baseColor.withOpacity(0.72)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

final _softShadow = [
  BoxShadow(
    color: const Color(0xFF1F2430).withOpacity(0.06),
    blurRadius: 18,
    offset: const Offset(0, 6),
  ),
];

const _tabularFigures = [FontFeature.tabularFigures()];

class TaskWorkScreen extends StatefulWidget {
  final String assignmentId;
  final String taskTitle;
  final WorkService service;

  /// Wire this to your existing "remove leave" action. When provided and the employee is on
  /// leave, the banner shows a "Remove leave" button. It must complete once the leave is removed.
  final Future<void> Function()? onRemoveLeave;

  const TaskWorkScreen({
    super.key,
    required this.assignmentId,
    required this.taskTitle,
    required this.service,
    this.onRemoveLeave,
  });

  @override
  State<TaskWorkScreen> createState() => _TaskWorkScreenState();
}

class _TaskWorkScreenState extends State<TaskWorkScreen> {
  WorkState? _state;
  String? _loadError;
  bool _busy = false;

  final _summaryCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  final _picker = ImagePicker();
  final empId = ApiService.empGuid!;
  bool _editingSummary = false;
  bool _dirty = false;

  /// Optimistic running flag. `null` means "trust the server".
  /// Set to `true`/`false` the instant the user taps Start/Stop, then
  /// cleared once `_load()` returns fresh state (or rolled back on error).
  bool? _optimisticRunning;

  Timer? _ticker;
  Duration _elapsed = Duration.zero;

  String get _id => widget.assignmentId;

  /// Effective "is the session running?" — optimistic value wins while pending.
  bool get _isRunning => _optimisticRunning ?? (_state?.isRunning ?? false);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _summaryCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  // ---------- data ----------
  Future<void> _load() async {
    try {
      final s = await widget.service.getState(_id, empId);
      if (!mounted) return;
      if (s.serverNow != null)
        ServerClock.sync(s.serverNow!); // keep timer on server time
      setState(() {
        _state = s;
        _loadError = null;
        // Server state confirmed — drop optimistic override.
        _optimisticRunning = null;
        if (!_dirty) {
          _summaryCtrl.text = s.todaySummary;
          _remarksCtrl.text = s.todayRemarks;
        }
      });
      _syncTicker();
    } on WorkException catch (e) {
      if (mounted) setState(() => _loadError = e.message);
    } catch (e) {
      if (mounted) setState(() => _loadError = 'Could not load task.');
    }
  }

  void _syncTicker() {
    _ticker?.cancel();
    // Use optimistic flag if present, otherwise server truth.
    final running = _isRunning;
    final start = running
        ? (_state?.openSessionStart ?? DateTime.now().toUtc())
        : null;
    if (start == null) {
      if (mounted) setState(() => _elapsed = Duration.zero);
      return;
    }
    void tick() {
      if (!mounted) return;
      final d = ServerClock.nowUtc.difference(start);
      setState(
        () => _elapsed = d.isNegative ? Duration.zero : d,
      ); // display only; server owns real hours
    }

    tick();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  // ---------- start flow ----------
  /// Returns true if the employee has checked in today (prompting face check-in if not).
  Future<bool> _ensureCheckedIn() async {
    final att = await ApiService.getTodayAttendance(empId);
    print('ATT: id=${att?.employeeCode} checkIn=${att?.checkInTime}');
    if (att?.checkInTime != null) return true;
    if (!mounted) return false;

    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Check-in required'),
        content: const Text(
          'You need to mark your attendance before starting a task.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Check in now'),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return false;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AttendanceActionScreen(isCheckOut: false, onSuccess: () {}),
      ),
    );

    // The attendance screen pops on both success and failure, so re-verify with the server.
    final after = await ApiService.getTodayAttendance(empId);
    if (after?.checkInTime == null) {
      _toast('Attendance was not marked. Please try again.', error: true);
      return false;
    }

    if (!mounted) return false;
    await _showCheckInMarkedDialog(after!.checkInTime);
    return true;
  }

  Future<void> _showCheckInMarkedDialog(dynamic checkIn) {
    final DateTime? dt = checkIn is DateTime
        ? checkIn
        : DateTime.tryParse(checkIn.toString());
    final timeText = dt == null ? checkIn.toString() : _hm12(dt.toLocal());

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 40),
        title: const Text('Check-in marked'),
        content: Text(
          'Your attendance was not marked today, so your face check-in has been recorded at $timeText.\n\n'
          'Your task will start now.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _hm12(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    final ap = t.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ap';
  }

  Future<void> _startSession() async {
    if (_busy) return;

    setState(() => _busy = true);
    bool checkedIn;
    try {
      checkedIn = await _ensureCheckedIn(); // opens face check-in if needed
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!checkedIn) return;

    final pos = await _getPosition();
    if (pos == null) return;

    await _run(
      () =>
          widget.service.startSession(_id, empId, pos.latitude, pos.longitude),
      success: 'Session started.',
    );
  }

  /// Runs an action, shows server rule messages, then refreshes state.
  Future<bool> _run(Future<void> Function() action, {String? success}) async {
    if (_busy) return false;
    setState(() => _busy = true);
    var ok = false;
    bool checkedIn;
    try {
      checkedIn = await _ensureCheckedIn(); // opens face check-in if needed
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!checkedIn) return false;
    try {
      await action();
      ok = true;
      if (success != null) _toast(success);
      await _load();
    } on WorkException catch (e) {
      _toast(e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    return ok;
  }

  /// Start/Stop with optimistic UI. Flips the button + timer instantly,
  /// then reconciles with the server. Rolls back on failure.
  Future<void> _toggleSession() async {
    if (_busy || _state == null) return;
    final wasRunning = _isRunning;
    final pos = await _getPosition();
    if (pos == null) return;
    // 1) Optimistic flip
    setState(() {
      _optimisticRunning = !wasRunning;
    });
    _syncTicker();

    // 2) Fire the request
    final ok = await _run(
      () => wasRunning
          ? widget.service.stopSession(_id, empId)
          : widget.service.startSession(
              _id,
              empId,
              pos.latitude,
              pos.longitude,
            ),
      success: wasRunning ? 'Session stopped.' : 'Session started.',
    );

    // 3) If the request failed, force a reload to roll back the optimistic state.
    // (_run already calls _load() on success, which clears _optimisticRunning.)
    if (!ok && mounted) {
      setState(() => _optimisticRunning = null);
      await _load();
    }
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: error ? _kRed : _kGreen,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Row(
            children: [
              Icon(
                error
                    ? Icons.error_outline
                    : Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  msg,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
  }

  // ---------- helpers ----------
  Future<File?> _takePhoto() async {
    final x = await _picker.pickImage(
      source: ImageSource.camera, // camera only: no gallery uploads as evidence
      imageQuality: 70,
      maxWidth: 1280,
    );
    return x == null ? null : File(x.path);
  }

  Future<Position?> _getPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      _toast('Turn on location services.', error: true);
      return null;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied)
      perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      _toast('Location permission is required.', error: true);
      return null;
    }
    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  Duration _secs(double hours) => Duration(seconds: (hours * 3600).round());

  String _hm(DateTime utc) {
    final l = utc.toLocal();
    return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }

  String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Color _priorityColor(String p) {
    switch (p.toLowerCase()) {
      case 'high':
      case 'urgent':
      case 'critical':
        return _kRed;
      case 'low':
        return _kGreen;
      default:
        return _kAmber;
    }
  }

  // ---------- actions ----------
  Future<void> _removeLeave() async {
    final cb = widget.onRemoveLeave;
    if (cb == null) return;
    await _run(() async {
      try {
        await cb();
      } catch (e) {
        throw WorkException(e.toString());
      }
    }, success: 'Leave removed.');
  }

  // Future<void> _validateSite() async {
  //   final pos = await _getPosition();
  //   if (pos == null) return;
  //   final photo = await _takePhoto();
  //   if (photo == null) return;
  //   await _run(
  //     () => widget.service.validateSite(
  //       _id,
  //       empId,
  //       pos.latitude,
  //       pos.longitude,
  //       photo,
  //     ),
  //     success: 'Site validated.',
  //   );
  // }
Future<void> _validateSite() async {
  final pos = await _getPosition();
  if (pos == null) return;
 
  // Face-detection capture (liveness challenge) instead of the plain camera
  final photo = await Navigator.push<File>(
    context,
    MaterialPageRoute(
      builder: (_) => AttendanceActionScreen(
        isCheckOut: false,
        onSuccess: () {},
        captureOnly: true,
        title: 'Site validation',
      ),
    ),
  );
  if (photo == null) return; // user backed out
 
  await _run(() => widget.service.validateSite(_id, empId, pos.latitude, pos.longitude, photo),
      success: 'Site validated.');
}
  Future<void> _saveSummary() async {
    if (_summaryCtrl.text.trim().isEmpty) {
      _toast('Write what you worked on today.', error: true);
      return;
    }
    final ok = await _run(
      () => widget.service.saveDailySummary(
        _id,
        empId,
        _state!.todayDate,
        _summaryCtrl.text.trim(),
        _remarksCtrl.text.trim(),
      ),
      success: 'Daily summary saved.',
    );
    if (ok && mounted) {
      setState(() {
        _editingSummary = false;
        _dirty = false;
      });
    }
  }

  void _cancelEdit() {
    final s = _state!;
    setState(() {
      _summaryCtrl.text = s.todaySummary;
      _remarksCtrl.text = s.todayRemarks;
      _editingSummary = false;
      _dirty = false;
    });
  }

  Future<void> _openComplete() async {
    final s = _state!;
    final finalCtrl = TextEditingController();
    final remarksCtrl = TextEditingController();
    File? photo;

    final result = await showModalBottomSheet<_CompleteResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) =>
          _CompleteSheet(state: s, onTakePhoto: _takePhoto, onToast: _toast),
    );

    if (result == null) return;
    final ok = await _run(
      () => widget.service.complete(
        _id,
        empId,
        result.summary,
        result.remarks,
        result.photo,
      ),
      success: 'Task completed.',
    );
    if (ok && mounted) Navigator.pop(context, true);

    finalCtrl.dispose();
    remarksCtrl.dispose();
  }

  InputDecoration _fieldDec(String label) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: c, width: w),
    );
    return InputDecoration(
      labelText: label,
      alignLabelWithHint: true,
      labelStyle: const TextStyle(color: _kMuted, fontWeight: FontWeight.w500),
      floatingLabelStyle: TextStyle(
        color: Colors.blue[700],
        fontWeight: FontWeight.w600,
      ),
      filled: true,
      fillColor: _kBg,
      contentPadding: const EdgeInsets.all(16),
      border: border(_kLine),
      enabledBorder: border(_kLine),
      focusedBorder: border(Colors.blue, 1.6),
    );
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final s = _state;
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: Text(
          widget.taskTitle,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color.fromARGB(255, 12, 86, 147),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _busy ? null : _load,
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _kLine),
        ),
      ),
      body: _loadError != null
          ? _ErrorState(message: _loadError!, onRetry: _load)
          : s == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    children: [
                      _taskCard(s),
                      if (s.onLeaveToday && !s.isCompleted) ...[
                        const SizedBox(height: 14),
                        _leaveBanner(),
                      ],
                      if (s.siteValidationRequired) ...[
                        const SizedBox(height: 14),
                        _siteCard(s),
                      ],
                      const SizedBox(height: 14),
                      _timerCard(s),
                      const SizedBox(height: 14),
                      _sessionsCard(s),
                      const SizedBox(height: 14),
                      _summaryCard(s),
                      if (s.history.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _historyCard(s),
                      ],
                    ],
                  ),
                ),
                if (_busy)
                  const Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(minHeight: 3),
                  ),
              ],
            ),
      bottomNavigationBar:
          (s == null ||
              s.isCompleted ||
              _loadError != null ||
              s.status.toLowerCase() == 'assigned')
          ? null
          : _bottomBar(s),
    );
  }

  Widget _bottomBar(WorkState s) {
    final disabled = _busy || _isRunning;
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: _kLine)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F2430).withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isRunning)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Stop the running session before completing.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _kMuted, fontSize: 12.5),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: const Text(
                'Complete my task',
                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _kGreen,
                disabledBackgroundColor: _kLine,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: disabled ? null : _openComplete,
            ),
          ),
        ],
      ),
    );
  }

  // Shared card shell
  Widget _card({required Widget child, EdgeInsets? padding}) => Container(
    padding: padding ?? const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: _softShadow,
    ),
    child: child,
  );

  Widget _cardTitle(IconData icon, String title, {Widget? trailing}) => Row(
    children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: Colors.blue[700]),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: _kInk,
          ),
        ),
      ),
      if (trailing != null) trailing,
    ],
  );

  // Task details
  Widget _taskCard(WorkState s) {
    final t = s.task;
    final overdue =
        t.dueDate != null &&
        !s.isCompleted &&
        t.dueDate!.isBefore(DateTime.now());
    final sub = [
      if (t.clientName.isNotEmpty) t.clientName,
      if (t.projectName.isNotEmpty) t.projectName,
    ].join('  •  ');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: _bannerGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _baseColor.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  s.isCompleted
                      ? Icons.check_rounded
                      : Icons.assignment_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.title.isEmpty ? widget.taskTitle : t.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (sub.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        sub,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _GlassPill(
                text: s.status,
                icon: s.isCompleted
                    ? Icons.check_circle_outline_rounded
                    : Icons.timelapse_rounded,
              ),
              if (t.priority.isNotEmpty)
                _GlassPill(
                  text: 'Priority: ${t.priority}',
                  icon: Icons.flag_outlined,
                ),
              if (t.taskTypeName.isNotEmpty)
                _GlassPill(text: t.taskTypeName, icon: Icons.category_outlined),
              if (t.dueDate != null)
                _GlassPill(
                  text: overdue
                      ? 'Overdue ${_date(t.dueDate!)}'
                      : 'Due ${_date(t.dueDate!)}',
                  icon: Icons.event_outlined,
                  highlight: overdue,
                ),
            ],
          ),
          if (t.description.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                t.description,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.92),
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // On leave: Start is blocked until the leave is removed
  Widget _leaveBanner() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _kAmber.withOpacity(0.10),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _kAmber.withOpacity(0.35)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _kAmber.withOpacity(0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.beach_access_rounded,
                color: _kAmber,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'You are marked on leave today. You cannot start this task unless you remove your leave.',
                style: TextStyle(color: _kInk, fontSize: 13.5, height: 1.4),
              ),
            ),
          ],
        ),
        if (widget.onRemoveLeave != null) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _busy ? null : _removeLeave,
              icon: const Icon(Icons.event_available_outlined, size: 18),
              style: FilledButton.styleFrom(
                backgroundColor: _kAmber,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              label: const Text('Remove leave'),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _siteCard(WorkState s) {
    final ok = s.siteValidatedToday;
    final color = ok ? _kGreen : _kAmber;
    return _card(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              ok ? Icons.verified_rounded : Icons.location_off_outlined,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ok ? 'Site validated today' : 'Site validation required',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    color: _kInk,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  ok
                      ? 'You can start work.'
                      : 'Be at the client location, then validate to unlock Start.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: _kMuted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (!ok && !s.isCompleted) ...[
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _busy ? null : _validateSite,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Validate'),
            ),
          ],
        ],
      ),
    );
  }

  // Current session timer + today's live total
  Widget _timerCard(WorkState s) {
    final running = _isRunning;
    final siteBlocked = s.siteValidationRequired && !s.siteValidatedToday;
    final startDisabled = _busy || s.onLeaveToday || siteBlocked;
    final live = running ? _elapsed : Duration.zero;
    final todayLive = _secs(s.todayHours) + live;
    final totalLive = _secs(s.totalHours) + live;

    String? hint;
    if (!running && !s.isCompleted) {
      if (s.onLeaveToday) {
        hint = 'Start is disabled while you are on leave.';
      } else if (siteBlocked) {
        hint = 'Validate your site first.';
      }
    }

    // If we optimistically flipped to running but the server hasn't yet told
    // us the start time, fall back to "now" for display.
    final startedAt = s.openSessionStart ?? DateTime.now().toUtc();

    return _card(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: running ? _kGreen : _kMuted.withOpacity(0.5),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                running ? 'CURRENT SESSION' : 'NO SESSION RUNNING',
                style: const TextStyle(
                  fontSize: 11.5,
                  letterSpacing: 1.3,
                  color: _kMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _fmt(_elapsed),
            style: TextStyle(
              fontSize: 46,
              fontWeight: FontWeight.w800,
              fontFeatures: _tabularFigures,
              color: running ? _kGreen : _kInk,
            ),
          ),
          if (running)
            Text(
              'Started at ${_hm(startedAt)}',
              style: const TextStyle(color: _kMuted, fontSize: 13),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _TimeTile(
                  label: 'Today total',
                  value: _fmt(todayLive),
                  strong: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TimeTile(
                  label: 'This task total',
                  value: _fmt(totalLive),
                ),
              ),
            ],
          ),
          if (!s.isCompleted) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: running
                  ? FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: _kRed,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.stop_rounded),
                      label: const Text(
                        'Stop',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      onPressed: _busy ? null : _toggleSession,
                    )
                  : FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.blue,
                        disabledBackgroundColor: _kLine,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.play_arrow_rounded),
                      label: const Text(
                        'Start',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      onPressed: startDisabled ? null : _toggleSession,
                    ),
            ),
          ],
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: _kAmber,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      hint,
                      style: const TextStyle(color: _kAmber, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Today's sessions, including the running one (live)
  Widget _sessionsCard(WorkState s) {
    final running = _isRunning;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(
            Icons.history_toggle_off_rounded,
            "Today's sessions (${s.todaySessions.length})",
          ),
          const SizedBox(height: 12),
          if (s.todaySessions.isEmpty && !running)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No sessions yet.', style: TextStyle(color: _kMuted)),
            ),
          if (running && !s.todaySessions.any((w) => w.isRunning))
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _kGreen.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _kGreen.withOpacity(0.35)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.play_circle_fill_rounded,
                    size: 22,
                    color: _kGreen,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${_hm(s.openSessionStart ?? DateTime.now().toUtc())} – running',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: _kInk,
                      ),
                    ),
                  ),
                  Text(
                    _fmt(_elapsed),
                    style: const TextStyle(
                      fontFeatures: _tabularFigures,
                      fontWeight: FontWeight.w800,
                      color: _kGreen,
                    ),
                  ),
                ],
              ),
            ),
          for (final w in s.todaySessions)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: w.isRunning ? _kGreen.withOpacity(0.08) : _kBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: w.isRunning ? _kGreen.withOpacity(0.35) : _kLine,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    w.isRunning
                        ? Icons.play_circle_fill_rounded
                        : Icons.timer_outlined,
                    size: 22,
                    color: w.isRunning ? _kGreen : Colors.blue[700],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${_hm(w.start)} – ${w.isRunning ? 'running' : _hm(w.end!)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: _kInk,
                      ),
                    ),
                  ),
                  Text(
                    w.isRunning
                        ? _fmt(_elapsed)
                        : '${w.hours.toStringAsFixed(2)} h',
                    style: TextStyle(
                      fontFeatures: _tabularFigures,
                      fontWeight: FontWeight.w800,
                      color: w.isRunning ? _kGreen : _kInk,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Today's summary: read view when saved, form when empty or editing
  Widget _summaryCard(WorkState s) {
    final hasSaved = s.todaySummary.isNotEmpty;
    final showForm = !s.isCompleted && (!hasSaved || _editingSummary);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(
            Icons.edit_note_rounded,
            "Today's summary",
            trailing: (hasSaved && !showForm)
                ? const _Pill(
                    text: 'Saved',
                    icon: Icons.check_circle_rounded,
                    color: _kGreen,
                  )
                : null,
          ),
          const SizedBox(height: 14),
          if (showForm) ...[
            TextField(
              controller: _summaryCtrl,
              maxLines: 3,
              onChanged: (_) => _dirty = true,
              style: const TextStyle(color: _kInk, fontWeight: FontWeight.w600),
              decoration: _fieldDec('What did you work on today? *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _remarksCtrl,
              maxLines: 2,
              onChanged: (_) => _dirty = true,
              style: const TextStyle(color: _kInk, fontWeight: FontWeight.w600),
              decoration: _fieldDec('Remarks (optional)'),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (hasSaved)
                  TextButton(
                    onPressed: _busy ? null : _cancelEdit,
                    style: TextButton.styleFrom(foregroundColor: _kMuted),
                    child: const Text('Cancel'),
                  ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: (_busy || s.todaySessions.isEmpty)
                      ? null
                      : _saveSummary,
                  icon: const Icon(Icons.save_outlined, size: 18),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  label: const Text('Save summary'),
                ),
              ],
            ),
            if (s.todaySessions.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  "Start a session before writing today's summary.",
                  style: TextStyle(color: _kMuted, fontSize: 12.5),
                ),
              ),
          ] else if (hasSaved) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _kBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _kLine),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.todaySummary,
                    style: const TextStyle(
                      color: _kInk,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                  if (s.todayRemarks.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Remarks: ${s.todayRemarks}',
                      style: const TextStyle(
                        color: _kMuted,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!s.isCompleted)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue[700],
                  ),
                  onPressed: () => setState(() => _editingSummary = true),
                ),
              ),
          ] else
            const Text(
              'No summary written for today.',
              style: TextStyle(color: _kMuted),
            ),
        ],
      ),
    );
  }

  Widget _historyCard(WorkState s) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: _softShadow,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          iconColor: Colors.blue[700],
          collapsedIconColor: _kMuted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: _cardTitle(
            Icons.event_note_rounded,
            'Previous days (${s.history.length})',
          ),
          children: [
            for (final h in s.history)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _kBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _kLine),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            h.workDate,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: _kInk,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            h.summary.isEmpty
                                ? 'No summary written'
                                : h.summary,
                            style: const TextStyle(
                              color: _kMuted,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    _Pill(
                      text: '${h.hours.toStringAsFixed(2)} h',
                      icon: Icons.schedule_rounded,
                      color: Colors.blue,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CompleteResult {
  final String summary;
  final String remarks;
  final File? photo;
  const _CompleteResult({
    required this.summary,
    required this.remarks,
    required this.photo,
  });
}

class _CompleteSheet extends StatefulWidget {
  final WorkState state;
  final Future<File?> Function() onTakePhoto;
  final void Function(String msg, {bool error}) onToast;

  const _CompleteSheet({
    required this.state,
    required this.onTakePhoto,
    required this.onToast,
  });

  @override
  State<_CompleteSheet> createState() => _CompleteSheetState();
}

class _CompleteSheetState extends State<_CompleteSheet> {
  final _finalCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  File? _photo;

  @override
  void dispose() {
    // Disposes only after the sheet is fully removed from the tree.
    _finalCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  InputDecoration _dec(String label) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: c, width: w),
    );
    return InputDecoration(
      labelText: label,
      alignLabelWithHint: true,
      labelStyle: const TextStyle(color: _kMuted, fontWeight: FontWeight.w500),
      floatingLabelStyle: TextStyle(
        color: Colors.blue[700],
        fontWeight: FontWeight.w600,
      ),
      filled: true,
      fillColor: _kBg,
      contentPadding: const EdgeInsets.all(16),
      border: border(_kLine),
      enabledBorder: border(_kLine),
      focusedBorder: border(Colors.blue, 1.6),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.task_alt_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Complete task',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: _kInk,
                        ),
                      ),
                      Text(
                        'Add a final summary to close this task',
                        style: TextStyle(fontSize: 12.5, color: _kMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _finalCtrl,
              maxLines: 4,
              style: const TextStyle(color: _kInk, fontWeight: FontWeight.w600),
              decoration: _dec('Final summary *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _remarksCtrl,
              maxLines: 2,
              style: const TextStyle(color: _kInk, fontWeight: FontWeight.w600),
              decoration: _dec('Completion remarks'),
            ),
            if (s.completionSnapshotRequired) ...[
              const SizedBox(height: 12),
              if (_photo != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(
                      _photo!,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: Text(
                    _photo == null
                        ? 'Take completion snapshot *'
                        : 'Retake snapshot',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue[700],
                    side: BorderSide(color: Colors.blue.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    final p = await widget.onTakePhoto();
                    if (p != null && mounted) setState(() => _photo = p);
                  },
                ),
              ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.check_rounded),
                style: FilledButton.styleFrom(
                  backgroundColor: _kGreen,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  if (_finalCtrl.text.trim().isEmpty) {
                    widget.onToast('Final summary is required.', error: true);
                    return;
                  }
                  if (s.completionSnapshotRequired && _photo == null) {
                    widget.onToast(
                      'A completion snapshot is required.',
                      error: true,
                    );
                    return;
                  }
                  Navigator.pop(
                    context,
                    _CompleteResult(
                      summary: _finalCtrl.text.trim(),
                      remarks: _remarksCtrl.text.trim(),
                      photo: _photo,
                    ),
                  );
                },
                label: const Text(
                  'Submit',
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ====================================================================
// Small widgets
// ====================================================================

class _Pill extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color color;

  const _Pill({required this.text, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pill used on top of the gradient banner.
class _GlassPill extends StatelessWidget {
  final String text;
  final IconData icon;
  final bool highlight;

  const _GlassPill({
    required this.text,
    required this.icon,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: highlight
            ? _kRed.withOpacity(0.9)
            : Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11.5,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  final String label;
  final String value;
  final bool strong;

  const _TimeTile({
    required this.label,
    required this.value,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11.5, color: _kMuted)),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
              fontFeatures: _tabularFigures,
              color: strong ? _kInk : _kMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_off_rounded,
                size: 44,
                color: Colors.blue[700],
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Could not load task',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: _kInk,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: _kMuted),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
