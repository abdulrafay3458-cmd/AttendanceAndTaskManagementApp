import 'package:attendance_app/models/UserDevices.dart';
import 'package:attendance_app/services/apiservice.dart';
import 'package:attendance_app/widgets/SizeConfig.dart';
import 'package:flutter/material.dart';

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

class AdminDeviceRequestsScreen extends StatefulWidget {
  const AdminDeviceRequestsScreen({Key? key}) : super(key: key);

  @override
  State<AdminDeviceRequestsScreen> createState() =>
      _AdminDeviceRequestsScreenState();
}

class _AdminDeviceRequestsScreenState extends State<AdminDeviceRequestsScreen> {
  List<UserDevices> _requests = [];
  List<UserDevices> _filtered = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.fetchDeviceRegistrationRequests();
      _requests = data;
      _applyFilter(_searchController.text);
    } catch (_) {
      _showError("Failed to load requests");
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  void _applyFilter(String query) {
    final q = query.toLowerCase().trim();
    _filtered = q.isEmpty
        ? List.from(_requests)
        : _requests.where((r) {
            return r.employeeName.toLowerCase().contains(q) ||
                r.employeeId.toLowerCase().contains(q) ||
                r.employeeCode.toLowerCase().contains(q);
          }).toList();
  }

  void _filter(String query) {
    setState(() => _applyFilter(query));
  }

  Widget _dialogHeader(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: SizeConfig.f(16),
                  fontWeight: FontWeight.w800,
                  color: _kInk,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, color: _kMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmAction(UserDevices request, bool approve) async {
    final TextEditingController reasonController = TextEditingController();
    String? errorText;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              title: _dialogHeader(
                approve
                    ? Icons.verified_user_outlined
                    : Icons.block_flipped,
                approve ? "Approve Request" : "Reject Request",
                request.employeeName,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    approve
                        ? "Are you sure you want to approve this device request?"
                        : "Please provide a reason for rejection.",
                    style: const TextStyle(
                      fontSize: 14,
                      color: _kMuted,
                      height: 1.4,
                    ),
                  ),
                  if (!approve) ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: reasonController,
                      maxLines: 3,
                      style: const TextStyle(
                        color: _kInk,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: "Enter rejection reason",
                        hintStyle: TextStyle(color: _kMuted.withOpacity(0.6)),
                        errorText: errorText,
                        filled: true,
                        fillColor: _kBg,
                        contentPadding: const EdgeInsets.all(14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: _kLine),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: _kLine),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide:
                              const BorderSide(color: Colors.blue, width: 1.6),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: _kRed),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide:
                              const BorderSide(color: _kRed, width: 1.6),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: TextButton.styleFrom(foregroundColor: _kMuted),
                  child: const Text("Cancel"),
                ),
                FilledButton(
                  onPressed: () {
                    if (!approve && reasonController.text.trim().isEmpty) {
                      setStateDialog(() {
                        errorText = "Rejection reason is required";
                      });
                      return;
                    }

                    Navigator.pop(context, true);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: approve ? _kGreen : _kRed,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(approve ? "Approve" : "Reject"),
                ),
              ],
            );
          },
        );
      },
    );

    final reason = reasonController.text.trim();
    reasonController.dispose();

    if (result != true) return;

    setState(() => request.isProcessing = true);

    try {
      await ApiService.handleDeviceRegistrationRequest(
        request.employeeId,
        approve,
        reason: approve ? null : reason,
      );

      if (!mounted) return;
      setState(() {
        _requests.remove(request);
        _filtered.remove(request);
      });

      _showSnack(
        approve ? "Approved successfully" : "Rejected successfully",
        isError: false,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => request.isProcessing = false);
      _showError("Action failed");
    }
  }

  void _showSnack(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? _kRed : _kGreen,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Row(
            children: [
              Icon(
                isError
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

  void _showError(String msg) => _showSnack(msg, isError: true);

  // ---------------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: Text(
          "Device Requests",
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: SizeConfig.f(20),
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue[700],
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _load,
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _kLine),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(onRefresh: _load, child: _buildList()),
    );
  }

  Widget _buildList() {
    final hasQuery = _searchController.text.trim().isNotEmpty;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _buildBanner(),
        const SizedBox(height: 14),
        _buildSearchField(),
        const SizedBox(height: 16),
        if (_filtered.isEmpty)
          _EmptyState(
            icon: hasQuery
                ? Icons.search_off_rounded
                : Icons.phonelink_lock_rounded,
            title: hasQuery ? 'No results found' : 'No pending requests',
            subtitle: hasQuery
                ? 'Nothing matches "${_searchController.text.trim()}".'
                : 'New device registration requests will appear here.',
            actionLabel: hasQuery ? 'Clear search' : null,
            onAction: hasQuery
                ? () {
                    _searchController.clear();
                    _filter('');
                  }
                : null,
          )
        else
          ..._filtered.map(_buildRequestCard),
      ],
    );
  }

  Widget _buildBanner() {
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
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.phonelink_lock_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_requests.length} pending '
                  '${_requests.length == 1 ? 'request' : 'requests'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Approve or reject new device registrations.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _softShadow,
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _filter,
        cursorColor: Colors.blue[700],
        style: const TextStyle(color: _kInk, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: "Search by name or code",
          hintStyle: TextStyle(
            color: _kMuted.withOpacity(0.7),
            fontSize: 13.5,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: Icon(Icons.search_rounded, color: Colors.blue[700]),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, color: _kMuted),
                  onPressed: () {
                    _searchController.clear();
                    _filter('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildRequestCard(UserDevices request) {
    final device =
        '${request.deviceManufacturer} ${request.deviceModel}'.trim();
    final name = request.employeeName.trim();
    final avatarSize = SizeConfig.f(50);

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
          Row(
            children: [
              Container(
                width: avatarSize,
                height: avatarSize,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: _bannerGradient,
                  borderRadius: BorderRadius.circular(avatarSize * 0.3),
                ),
                child: Text(
                  name.isEmpty ? '?' : name.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: avatarSize * 0.4,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.employeeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: _kInk,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _Pill(
                          text: request.employeeCode,
                          icon: Icons.badge_outlined,
                          color: Colors.blue,
                        ),
                        const _Pill(
                          text: 'Pending',
                          icon: Icons.hourglass_top_rounded,
                          color: _kAmber,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _kBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _kLine),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.smartphone_rounded,
                    size: 20,
                    color: Colors.blue[700],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Requested device',
                        style: TextStyle(fontSize: 11.5, color: _kMuted),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        device.isEmpty ? '-' : device,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _kInk,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (request.isProcessing)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.blue[700],
                  ),
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmAction(request, false),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text(
                      'Reject',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kRed,
                      side: const BorderSide(color: _kRed),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _confirmAction(request, true),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text(
                      'Approve',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _kGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
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
            const SizedBox(height: 14),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(foregroundColor: Colors.blue[700]),
              child: Text(
                actionLabel!,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }
}