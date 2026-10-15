import 'package:attendance_app/services/apiservice.dart';
import 'package:attendance_app/services/StandardHourGroup.dart';
import 'package:attendance_app/widgets/SizeConfig.dart';
import 'package:flutter/material.dart';

// -----------------------------------------------------------------------------
// Design tokens
// -----------------------------------------------------------------------------
const Color _kBg = Color(0xFFF5F6FA);
const Color _kInk = Color(0xFF1F2430);
const Color _kMuted = Color(0xFF7A8194);
const Color _kLine = Color(0xFFE6E8F0);
const Color _kGreen = Color(0xFF22A06B);
const Color _kRed = Color(0xFFE5484D);
const Color _kAmber = Color(0xFFE59A1F);
const Color _kTeal = Color(0xFF2F8F83);

/// Base color for gradient banners / avatars.
const Color _kGradient = Color.fromARGB(255, 12, 86, 147);

/// Accent color for pills, icon tiles and the dialog icon box.
const Color _kAccent = Colors.blue;

List<BoxShadow> get _softShadow => [
      BoxShadow(
        color: const Color(0xFF1F2430).withOpacity(0.05),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
    ];

LinearGradient get _bannerGradient => LinearGradient(
      colors: [_kGradient, _kGradient.withOpacity(0.72)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

void _snack(BuildContext context, String message, {bool isError = false}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? _kRed : _kInk,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ),
  );
}

// =============================================================================
// Screen 1: list of standard-hour groups
// =============================================================================
class Standardhour extends StatefulWidget {
  const Standardhour({super.key});

  @override
  _StandardHour createState() => _StandardHour();
}

class _StandardHour extends State<Standardhour> {
  List<StandardHourGroup> _standardHourGroup = [];
  List<StandardHourGroup> _filteredData = [];
  bool _isLoading = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadHours();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHours() async {
    setState(() => _isLoading = true);

    try {
      final data = await ApiService.getStandardHourList();
      if (!mounted) return;
      setState(() {
        _standardHourGroup =
            data.map((json) => StandardHourGroup.fromJson(json)).toList();
        _filteredData = List.from(_standardHourGroup);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _snack(context, 'Could not load standard hours: $e', isError: true);
    }
  }

  void _filterData(String query) {
    final searchLower = query.toLowerCase();
    setState(() {
      _filteredData = _standardHourGroup.where((group) {
        final codeStr = group.code.toString().toLowerCase();
        final titleStr = group.title.toLowerCase();
        return codeStr.contains(searchLower) || titleStr.contains(searchLower);
      }).toList();
    });
  }

  void _updateGroup(StandardHourGroup updated) {
    setState(() {
      final idx = _standardHourGroup.indexWhere((g) => g.code == updated.code);
      if (idx != -1) _standardHourGroup[idx] = updated;
      _filteredData = List.from(_standardHourGroup);
    });
  }

  Future<void> _openAddScreen() async {
    final blank = StandardHourGroup(code: 0, title: '', hourList: []);
    final created = await Navigator.push<StandardHourGroup>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            HourListScreen(group: blank, mode: HourListMode.add),
      ),
    );
    if (created != null && mounted) {
      await _loadHours();
    }
  }

  /// Confirm + delete a group.
  Future<void> _deleteGroup(StandardHourGroup group) async {
    final name = group.title.isNotEmpty ? group.title : 'Group ${group.code}';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => _DialogShell(
        icon: Icons.delete_outline_rounded,
        title: 'Delete Standard Hour',
        subtitle: 'Are you sure you want to delete "$name"?',
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _kRed,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final success = await ApiService.deleteStandardHourGroup(group.code);
    if (!mounted) return;

    if (success) {
      setState(() {
        _standardHourGroup.removeWhere((g) => g.code == group.code);
        _filteredData = List.from(_standardHourGroup);
      });
      _snack(context, 'Deleted successfully');
    } else {
      _snack(context, 'Failed to delete', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue[700],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search by code or title...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: _kMuted, fontSize: 15),
                ),
                style: const TextStyle(color: _kInk, fontSize: 16),
                onChanged: _filterData,
              )
            : const Text(
                'Standard Hours',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _filteredData = List.from(_standardHourGroup);
                }
              });
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredData.isEmpty
              ? const _EmptyState(
                  icon: Icons.schedule_rounded,
                  title: 'No standard hours found',
                  message: 'Tap "Add Standard Hours" to create a schedule.',
                )
              : RefreshIndicator(
                  onRefresh: _loadHours,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    itemCount: _filteredData.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                          child: Text(
                            '${_filteredData.length} schedule(s)',
                            style: const TextStyle(
                                fontSize: 13.5, color: _kMuted),
                          ),
                        );
                      }
                      return _buildGroupCard(_filteredData[index - 1]);
                    },
                  ),
                ),
      bottomNavigationBar: _BottomActionBar(
        child: FilledButton.icon(
          onPressed: _openAddScreen,
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'Add Standard Hours',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          style: _bigButton(),
        ),
      ),
    );
  }

  Widget _buildGroupCard(StandardHourGroup group) {
    final title = group.title.isNotEmpty ? group.title : 'Group ${group.code}';
    final workingDays = group.hourList
        .where((h) => h.weekDayName.toLowerCase() != 'weekend')
        .length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: _softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () async {
            final updated = await Navigator.push<StandardHourGroup>(
              context,
              MaterialPageRoute(
                builder: (context) => HourListScreen(group: group),
              ),
            );
            if (updated != null) _updateGroup(updated);
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: SizeConfig.f(50),
                  height: SizeConfig.f(50),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: _bannerGradient,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: FittedBox(
                    child: Text(
                      group.code.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _kInk,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _Pill(
                            icon: Icons.rule_rounded,
                            text: '${group.hourList.length} rules',
                            color: _kAccent,
                          ),
                          _Pill(
                            icon: Icons.work_outline_rounded,
                            text: '$workingDays working day(s)',
                            color: _kTeal,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Delete',
                  style: IconButton.styleFrom(
                    foregroundColor: _kRed,
                    backgroundColor: _kRed.withOpacity(0.08),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  onPressed: () => _deleteGroup(group),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Screen 2: add / edit the weekly hour rules
// =============================================================================
enum HourListMode { edit, add }

class HourListScreen extends StatefulWidget {
  final StandardHourGroup group;
  final HourListMode mode;

  const HourListScreen({
    super.key,
    required this.group,
    this.mode = HourListMode.edit,
  });

  @override
  State<HourListScreen> createState() => _HourListScreenState();
}

class _HourListScreenState extends State<HourListScreen> {
  late TextEditingController _titleController;
  late List<StandardHourRequest> _hourList;
  bool _isSaving = false;

  final Map<int, StandardHourRequest> _weekdayBackup = {};

  bool get _isAddMode => widget.mode == HourListMode.add;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: _isAddMode ? '' : widget.group.title,
    );

    if (_isAddMode && widget.group.hourList.isEmpty) {
      _hourList = List.generate(7, (i) {
        final day = i + 1; // 1..7
        return StandardHourRequest(
          groupCode: 0, // assigned by backend
          weekDay: day,
          weekDayName: _defaultWeekDayName(day),
          hours: '00:00',
          minutes: 0,
          timeIn: null,
          timeOut: null,
          halfDayMinutes: 0,
          halfDayHourOnLateArrival: null,
        );
      });
    } else {
      _hourList = widget.group.hourList
          .map((h) => StandardHourRequest(
                groupCode: h.groupCode,
                weekDay: h.weekDay,
                weekDayName: h.weekDayName,
                hours: h.hours,
                minutes: h.minutes,
                timeIn: h.timeIn,
                timeOut: h.timeOut,
                halfDayMinutes: h.halfDayMinutes,
                halfDayHourOnLateArrival: h.halfDayHourOnLateArrival,
              ))
          .toList();

      for (final req in _hourList) {
        if (_hasNoTime(req) && req.weekDayName.toLowerCase() != 'weekend') {
          _clearToWeekend(req);
        }
      }
    }
  }

  String _defaultWeekDayName(int day) {
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return (day >= 1 && day <= 7) ? names[day - 1] : 'Day $day';
  }

  bool _hasNoTime(StandardHourRequest req) {
    final noIn = req.timeIn == null || req.timeIn!.isEmpty;
    final noOut = req.timeOut == null || req.timeOut!.isEmpty;
    return noIn && noOut;
  }

  void _clearToWeekend(StandardHourRequest req) {
    req.weekDayName = 'Weekend';
    req.timeIn = '00:00';
    req.timeOut = '00:00';
    req.hours = '00:00';
    req.minutes = 0;
    req.halfDayMinutes = 0;
    req.halfDayHourOnLateArrival = '00:00';
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _toggleWeekend(int index) {
    final req = _hourList[index];
    final isCurrentlyWeekend = req.weekDayName.toLowerCase() == 'weekend';

    setState(() {
      if (!isCurrentlyWeekend) {
        _weekdayBackup[index] = StandardHourRequest(
          groupCode: req.groupCode,
          weekDay: req.weekDay,
          weekDayName: req.weekDayName,
          hours: req.hours,
          minutes: req.minutes,
          timeIn: req.timeIn,
          timeOut: req.timeOut,
          halfDayMinutes: req.halfDayMinutes,
          halfDayHourOnLateArrival: req.halfDayHourOnLateArrival,
        );

        _clearToWeekend(req);
      } else {
        final backup = _weekdayBackup.remove(index);
        req.weekDayName = _defaultWeekDayName(req.weekDay);
        if (backup != null) {
          req.timeIn = backup.timeIn;
          req.timeOut = backup.timeOut;
          req.hours = backup.hours;
          req.minutes = backup.minutes;
          req.halfDayMinutes = backup.halfDayMinutes;
          req.halfDayHourOnLateArrival = backup.halfDayHourOnLateArrival;
        } else {
          // Fresh weekend -> weekday restore
          req.timeIn = null;
          req.timeOut = null;
          req.hours = '00:00';
          req.minutes = 0;
          req.halfDayMinutes = 0;
          req.halfDayHourOnLateArrival = null;
        }
      }
    });
  }

  Future<void> _applyToAllDays(int sourceIndex) async {
    final src = _hourList[sourceIndex];

    if (src.weekDayName.toLowerCase() == 'weekend') {
      _snack(context, 'Cannot apply a weekend day to all days.',
          isError: true);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => _DialogShell(
        icon: Icons.copy_all_rounded,
        title: 'Apply to all days?',
        subtitle:
            'Copy ${src.weekDayName}\'s Time In, Time Out and Late Arrival '
            'to every other weekday? This will overwrite any values already '
            'set on those days.',
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: _dialogButton(),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Apply'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      for (var i = 0; i < _hourList.length; i++) {
        if (i == sourceIndex) continue;
        final target = _hourList[i];
        if (target.weekDayName.toLowerCase() == 'weekend') continue;

        target.timeIn = src.timeIn;
        target.timeOut = src.timeOut;
        target.halfDayHourOnLateArrival = src.halfDayHourOnLateArrival;
        _recalcFromTimeInOut(i);
        _recalcHalfDayFromLateArrival(i);
      }
    });

    if (!mounted) return;
    _snack(context, 'Applied ${src.weekDayName}\'s hours to all weekdays.');
  }

  Future<void> _pickTime(int index, bool isTimeIn) async {
    final current =
        isTimeIn ? _hourList[index].timeIn : _hourList[index].timeOut;
    final initial = _parseTime(current) ?? const TimeOfDay(hour: 9, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked == null) return;

    setState(() {
      final formatted = _formatTime(picked);
      if (isTimeIn) {
        _hourList[index].timeIn = formatted;
      } else {
        _hourList[index].timeOut = formatted;
      }
      // Minutes / Half Day Minutes are derived from Time In & Time Out.
      _recalcFromTimeInOut(index);
    });
  }

  TimeOfDay? _parseTime(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      final parts = value.split(':');
      return TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    } catch (_) {
      return null;
    }
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  int? _toMinutesSinceMidnight(String? value) {
    final t = _parseTime(value);
    if (t == null) return null;
    return t.hour * 60 + t.minute;
  }

  String _formatDurationHHmm(int totalMinutes) {
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  void _recalcFromTimeInOut(int index) {
    final req = _hourList[index];
    final inMin = _toMinutesSinceMidnight(req.timeIn);
    final outMin = _toMinutesSinceMidnight(req.timeOut);
    if (inMin == null || outMin == null) return;

    var total = outMin - inMin;
    if (total < 0) total += 24 * 60;

    req.minutes = total;
    req.halfDayMinutes = total ~/ 2;
    req.hours = _formatDurationHHmm(total);
  }

  void _recalcHalfDayFromLateArrival(int index) {
    final req = _hourList[index];
    final lateMin = _toMinutesSinceMidnight(req.halfDayHourOnLateArrival);
    final outMin = _toMinutesSinceMidnight(req.timeOut);
    if (lateMin == null || outMin == null) return;

    var diff = outMin - lateMin;
    if (diff < 0) diff += 24 * 60;

    req.halfDayMinutes = diff;
  }

  Future<void> _editLateArrival(int index) async {
    final req = _hourList[index];
    final controller =
        TextEditingController(text: req.halfDayHourOnLateArrival ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => _DialogShell(
        icon: Icons.warning_amber_rounded,
        title: 'Half Day Late Arrival',
        subtitle: 'Arrivals after this time count as a half day.',
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.datetime,
          decoration: InputDecoration(
            hintText: 'e.g. 10:15',
            prefixIcon: const Icon(Icons.access_time_rounded, size: 20),
            filled: true,
            fillColor: _kBg,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: _dialogButton(),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (result == null) return;
    setState(() {
      req.halfDayHourOnLateArrival = result;
      _recalcHalfDayFromLateArrival(index);
    });
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _snack(context, 'Please enter a group title.', isError: true);
      return;
    }

    setState(() => _isSaving = true);

    if (!_isAddMode) {
      for (final req in _hourList) {
        if (_hasNoTime(req) && req.weekDayName.toLowerCase() != 'weekend') {
          _clearToWeekend(req);
        }
      }
    }

    late final Map<String, dynamic> result;

    if (_isAddMode) {
      result = await ApiService.addStandardHour(
        title: title,
        hourList: _hourList,
      );
    } else {
      result = await ApiService.editStandardHour(
        code: widget.group.code,
        title: title,
        hourList: _hourList,
      );
    }

    if (mounted) setState(() => _isSaving = false);
    if (!mounted) return;

    final ok = result['success'] == true;

    if (ok) {
      final updatedGroup = StandardHourGroup(
        code: _isAddMode
            ? (result['code'] is int ? result['code'] as int : 0)
            : widget.group.code,
        title: title,
        hourList: _hourList,
      );
      _snack(context, _isAddMode ? 'Added successfully' : 'Saved successfully');
      Navigator.pop(context, updatedGroup);
    } else {
      final message = result['error']?.toString() ?? 'Failed to save';
      final friendly = message.contains('401')
          ? 'Your session has expired. Please log in again and retry.'
          : message;
      _snack(context, friendly, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue[700],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _isAddMode
              ? 'Add Standard Hours'
              : (widget.group.title.isNotEmpty
                  ? widget.group.title
                  : 'Group ${widget.group.code}'),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
      ),
      body: Column(
        children: [
          // Editable group title
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: _softShadow,
              ),
              child: TextField(
                controller: _titleController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Group Title',
                  prefixIcon: const Icon(Icons.title_rounded, size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              children: [
                Icon(Icons.touch_app_outlined,
                    size: 15, color: _kMuted.withOpacity(0.9)),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Blue tiles are editable · tap "Apply to all" to copy a day',
                    style: TextStyle(fontSize: 12, color: _kMuted),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: _hourList.isEmpty
                ? const _EmptyState(
                    icon: Icons.event_busy_rounded,
                    title: 'No hour rules',
                    message: 'No hour rules available for this group.',
                  )
                : ListView.builder(
                    itemCount: _hourList.length,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemBuilder: (context, index) =>
                        _buildDayCard(index),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomActionBar(
        child: FilledButton.icon(
          onPressed: _isSaving ? null : _save,
          icon: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check_circle_outline_rounded),
          label: Text(
            _isSaving
                ? 'Saving...'
                : (_isAddMode ? 'Add Standard Hours' : 'Save Changes'),
            style:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          style: _bigButton(),
        ),
      ),
    );
  }

  Widget _buildDayCard(int index) {
    final req = _hourList[index];
    final isWeekend = req.weekDayName.toLowerCase() == 'weekend';
    final accent = isWeekend ? _kAmber : _kAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: _softShadow,
        border: Border.all(color: accent.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: weekday name + weekend switch
          Container(
            color: accent.withOpacity(0.07),
            padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isWeekend
                        ? Icons.weekend_rounded
                        : Icons.work_outline_rounded,
                    size: 20,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        req.weekDayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15.5,
                          color: _kInk,
                        ),
                      ),
                      Text(
                        'Day ${req.weekDay}',
                        style:
                            const TextStyle(fontSize: 12, color: _kMuted),
                      ),
                    ],
                  ),
                ),
                Text(
                  isWeekend ? 'Weekend' : 'Weekday',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: accent,
                  ),
                ),
                Switch(
                  value: isWeekend,
                  activeColor: _kAmber,
                  onChanged: (_) => _toggleWeekend(index),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: isWeekend
                ? Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _kAmber.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 18, color: _kAmber),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Marked as a weekend day — hours are cleared (00:00).',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF9A6410),
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _TimeTile(
                              icon: Icons.login_rounded,
                              label: 'Time In',
                              value: req.timeIn ?? '--:--',
                              onTap: () => _pickTime(index, true),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _TimeTile(
                              icon: Icons.logout_rounded,
                              label: 'Time Out',
                              value: req.timeOut ?? '--:--',
                              onTap: () => _pickTime(index, false),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _TimeTile(
                        icon: Icons.warning_amber_rounded,
                        label: 'Late Arrival (half day after)',
                        value: req.halfDayHourOnLateArrival ?? '--:--',
                        onTap: () => _editLateArrival(index),
                        wide: true,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _AutoTile(
                              label: 'Minutes',
                              value: '${req.minutes}',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _AutoTile(
                              label: 'Half Day',
                              value: '${req.halfDayMinutes ?? 0}',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _AutoTile(
                              label: 'Hours',
                              value: req.hours,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => _applyToAllDays(index),
                          icon: const Icon(Icons.copy_all_rounded, size: 17),
                          label: const Text('Apply to all'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.blue[700],
                            backgroundColor: _kAccent.withOpacity(0.08),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Shared widgets
// =============================================================================

ButtonStyle _bigButton() => FilledButton.styleFrom(
      backgroundColor: Colors.blue[700],
      foregroundColor: Colors.white,
      disabledBackgroundColor: Colors.blue[300],
      disabledForegroundColor: Colors.white,
      minimumSize: const Size.fromHeight(52),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );

ButtonStyle _dialogButton() => FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );

class _BottomActionBar extends StatelessWidget {
  final Widget child;
  const _BottomActionBar({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1F2430).withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(top: false, child: child),
    );
  }
}

/// Tappable (editable) time tile.
class _TimeTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final bool wide;

  const _TimeTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _kAccent.withOpacity(0.06),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: wide ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _kAccent.withOpacity(0.30)),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _kAccent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: _kAccent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(fontSize: 11.5, color: _kMuted),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      value,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: _kInk,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.edit_rounded,
                  size: 14, color: _kAccent.withOpacity(0.7)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Read-only value that is derived automatically.
class _AutoTile extends StatelessWidget {
  final String label;
  final String value;

  const _AutoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: _kTeal.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kTeal.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: _kMuted),
                ),
              ),
              Icon(Icons.calculate_outlined,
                  size: 12, color: _kTeal.withOpacity(0.8)),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: _kTeal,
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogShell extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? content;
  final List<Widget> actions;

  const _DialogShell({
    required this.icon,
    required this.title,
    required this.actions,
    this.subtitle,
    this.content,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _kAccent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _kInk,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w400,
                      color: _kMuted,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      content: content == null ? null : SizedBox(width: 380, child: content),
      actions: actions,
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _Pill({required this.icon, required this.text, required this.color});

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
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _kAccent.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 38, color: _kAccent),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _kInk,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: _kMuted),
            ),
          ],
        ),
      ),
    );
  }
}