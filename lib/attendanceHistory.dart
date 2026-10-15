import 'package:attendance_app/models/AttendanceRecord.dart';
import 'package:attendance_app/services/apiservice.dart';
import 'package:attendance_app/widgets/SizeConfig.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  _AttendanceHistoryScreenState createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  List<AttendanceRecord> _records = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  String formatHoursToHHMM(String hoursString) {
    try {
      final time = double.parse(hoursString);
      final totalMinutes = (time * 60).round();
      final hours = totalMinutes ~/ 60;
      final minutes = totalMinutes % 60;
      return '${hours}h ${minutes}m';
    } catch (e) {
      return '0h 0m';
    }
  }

  double _hoursOf(AttendanceRecord r) =>
      double.tryParse(r.totalHours ?? '') ?? 0;

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    final employeeId = ApiService.employeeId;
    if (employeeId == null) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      return;
    }

    try {
      final records = await ApiService.getAttendanceHistory(employeeId);
      if (!mounted) return;
      setState(() {
        _records = records;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
      });
    }
  }

  // ---------------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: Text(
          'Attendance History',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color.fromARGB(255, 12, 86, 147),
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadHistory,
            tooltip: 'Refresh',
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _kLine),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_hasError) {
      return _EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Could not load history',
        subtitle: 'Check your connection and try again.',
        actionLabel: 'Retry',
        onAction: _loadHistory,
      );
    }
    if (_records.isEmpty) {
      return const _EmptyState(
        icon: Icons.event_busy_rounded,
        title: 'No attendance records',
        subtitle: 'Your check-ins will show up here.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadHistory,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        itemCount: _records.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) return _buildSummary();
          return _buildRecordCard(_records[index - 1]);
        },
      ),
    );
  }

  // -------------------------------------------------------------- summary
  Widget _buildSummary() {
    // final present = _records.where((r) => r.status != 'absent').length;
    final totalHours = _records.fold<double>(0, (s, r) => s + _hoursOf(r));
    final totalMinutes = (totalHours * 60).round();

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(20),
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
      child: Row(
        children: [
          _SummaryStat(
            icon: Icons.event_note_rounded,
            value: '${_records.length}',
            label: 'Records',
          ),
          _divider(),
          // _SummaryStat(
          //   icon: Icons.check_circle_outline_rounded,
          //   value: '$present',
          //   label: 'Present',
          // ),
          // _divider(),
          _SummaryStat(
            icon: Icons.schedule_rounded,
            value: '${totalMinutes ~/ 60}h ${totalMinutes % 60}m',
            label: 'Total hours',
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        color: Colors.white.withOpacity(0.25),
      );

  // ----------------------------------------------------------- record card
  Color _statusColor(String? status) {
    switch ((status ?? '').toLowerCase()) {
      case 'on time':
        return _kGreen;
      case 'absent':
        return _kRed;
      default:
        return _kAmber;
    }
  }

  Widget _buildRecordCard(AttendanceRecord record) {
    final date = record.attendanceDate?.toLocal();
    final statusColor = _statusColor(record.status);
    final hasTotal = (record.totalHours ?? '').isNotEmpty;
    final hasLocation = (record.location ?? '').isNotEmpty;
    final hasSource = (record.checkInSource ?? '').isNotEmpty;
    final isDevice = record.checkInSource?.toLowerCase() == 'zkteco';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: _softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: date tile + title + status pill
          Row(
            children: [
              Container(
                width: 50,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  gradient: _bannerGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Text(
                      date != null ? DateFormat('d').format(date) : '--',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      date != null
                          ? DateFormat('MMM').format(date).toUpperCase()
                          : '',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      date != null ? DateFormat('EEEE').format(date) : '-',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: _kInk,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      date != null ? DateFormat('MMM d, yyyy').format(date) : '',
                      style: const TextStyle(fontSize: 12.5, color: _kMuted),
                    ),
                  ],
                ),
              ),
              if ((record.status ?? '').isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    record.status!.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Check-in / check-out tiles
          Row(
            children: [
              Expanded(
                child: _TimeTile(
                  icon: Icons.login_rounded,
                  label: 'Check-in',
                  color: _kGreen,
                  time: record.checkInTime,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TimeTile(
                  icon: Icons.logout_rounded,
                  label: 'Check-out',
                  color: _kRed,
                  time: record.checkOutTime,
                ),
              ),
            ],
          ),

          // Footer chips
          if (hasTotal || hasLocation || hasSource) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (hasTotal)
                  _InfoChip(
                    icon: Icons.timer_outlined,
                    text: formatHoursToHHMM(record.totalHours ?? ''),
                    color: Colors.blue,
                    bold: true,
                  ),
                if (hasLocation)
                  _InfoChip(
                    icon: Icons.location_on_outlined,
                    text: record.location!,
                    color: _kMuted,
                  ),
                if (hasSource)
                  _InfoChip(
                    icon: isDevice
                        ? Icons.fingerprint
                        : Icons.phone_android_rounded,
                    text: isDevice
                        ? (record.deviceName ?? 'Device')
                        : (record.checkInSource ?? 'N/A'),
                    color: _kMuted,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ====================================================================
// Small widgets
// ====================================================================

class _SummaryStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _SummaryStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final DateTime? time;

  const _TimeTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kLine),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11.5, color: _kMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  time != null
                      ? DateFormat('hh:mm a').format(time!.toLocal())
                      : '--:--',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    color: _kInk,
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

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final bool bold;

  const _InfoChip({
    required this.icon,
    required this.text,
    required this.color,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              ),
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
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
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
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: Colors.blue[700]),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: _kInk,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: _kMuted),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(actionLabel!),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}