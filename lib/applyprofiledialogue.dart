import 'dart:convert';
import 'dart:typed_data';
import 'package:attendance_app/models/approvepic.dart';
import 'package:attendance_app/rejectprofile.dart';
import 'package:attendance_app/services/apiservice.dart';
import 'package:attendance_app/models/employeeprofilemodel.dart';
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

class ApproveProfilePic extends StatefulWidget {
  const ApproveProfilePic({super.key});

  @override
  _ApproveProfilePic createState() => _ApproveProfilePic();
}

class _ApproveProfilePic extends State<ApproveProfilePic> {
  List<EmployeeProfileModel> _empProfile = [];
  bool _isLoading = true;
  bool _hasError = false;

  // Decoded image cache (profile.code -> bytes) so we don't decode on every build.
  final Map<dynamic, Uint8List?> _imageCache = {};

  @override
  void initState() {
    super.initState();
    _loadPendingApprovals();
  }

  Future<void> _loadPendingApprovals() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    final empId = ApiService.currentEmployee?.employeeId;
    if (empId == null) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      return;
    }

    try {
      final data = await ApiService.getEmployeeProfileData(empId);
      if (!mounted) return;
      setState(() {
        _empProfile = data;
        _imageCache.clear();
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

  void _snack(String message, {bool isError = false}) {
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
                  message,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
  }

  Future<void> _rejectPhoto(
    EmployeeProfileModel profile,
    String reason,
  ) async {
    final result = await ApiService.approveProfilePic(
      profile.code,
      ApprovePicModel(
        code: profile.code,
        employeeCode: profile.employeeId!,
        adminCode: ApiService.currentEmployee!.employeeId,
        approveDate: null,
        status: false,
        rejectionDate: DateTime.now(),
        rejectionReason: reason,
        historyStatus: true,
        companyCode: profile.companyCode,
      ),
    );

    if (!mounted) return;

    if (result['success'] == true) {
      _snack('Profile photo rejected successfully');
      setState(() {
        _empProfile.removeWhere((p) => p.code == profile.code);
      });
    } else {
      _snack(result['error'] ?? 'Failed to reject', isError: true);
    }
  }

  Uint8List? _imageDecoder(String value) {
    try {
      if (value.isEmpty) return null;

      return base64Decode(value);
    } catch (e) {
      debugPrint('Invalid base64 image: $e');
      return null;
    }
  }

  Uint8List? _imageFor(EmployeeProfileModel profile) {
    return _imageCache.putIfAbsent(
      profile.code,
      () => _imageDecoder(profile.faceImage),
    );
  }

  Future<void> _approvePhoto(EmployeeProfileModel profile) async {
    final imageBytes = _imageFor(profile);

    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.face_retouching_natural,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Review Profile Picture',
                    style: TextStyle(
                      fontSize: SizeConfig.f(16),
                      fontWeight: FontWeight.w800,
                      color: _kInk,
                    ),
                  ),
                  const Text(
                    'Approve or reject this photo',
                    style: TextStyle(fontSize: 12.5, color: _kMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: imageBytes != null
                      ? Image.memory(imageBytes, fit: BoxFit.cover)
                      : Container(
                          color: _kBg,
                          child: const Icon(
                            Icons.person_rounded,
                            size: 72,
                            color: _kMuted,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              profile.employeeName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _kInk,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Approve profile image for this employee?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: _kMuted.withOpacity(0.95),
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                Navigator.pop(dialogContext); // close approve dialog

                final reason = await showDialog<String>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const RejectProfileDialog(),
                );

                if (reason != null && reason.isNotEmpty) {
                  await _rejectPhoto(profile, reason);
                }
              },
              icon: const Icon(Icons.close_rounded, size: 18),
              label: const Text('Reject'),
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
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Approve'),
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
    );

    if (confirm != true) return;

    final result = await ApiService.approveProfilePic(
      profile.code,
      ApprovePicModel(
        code: profile.code,
        employeeCode: profile.employeeId!,
        adminCode: ApiService.currentEmployee!.employeeId,
        approveDate: profile.approveDate,
        status: true,
        rejectionDate: null,
        rejectionReason: '',
        historyStatus: true,
        companyCode: profile.companyCode,
      ),
    );

    if (!mounted) return;

    if (result['success'] == true) {
      _snack('Profile photo approved successfully');
      _loadPendingApprovals();
    } else {
      _snack(result['error'] ?? 'Failed to approve', isError: true);
    }
  }

  // ---------------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: Text(
          'Approve Profile Picture',
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadPendingApprovals,
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
        title: 'Could not load requests',
        subtitle: 'Check your connection and try again.',
        actionLabel: 'Retry',
        onAction: _loadPendingApprovals,
      );
    }

    if (_empProfile.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadPendingApprovals,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.2),
            const _EmptyState(
              icon: Icons.task_alt_rounded,
              title: 'No pending approvals',
              subtitle: 'New profile picture requests will appear here.',
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPendingApprovals,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        itemCount: _empProfile.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) return _buildBanner();
          return _buildProfileApprove(_empProfile[index - 1]);
        },
      ),
    );
  }

  Widget _buildBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
              Icons.face_retouching_natural,
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
                  '${_empProfile.length} pending '
                  '${_empProfile.length == 1 ? 'request' : 'requests'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Review each photo before approving.',
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

  Widget _buildProfileApprove(EmployeeProfileModel profile) {
    final bytes = _imageFor(profile);
    final avatarSize = SizeConfig.f(56);
    final name = profile.employeeName.trim();
    final initials = name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();

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
              // Photo thumbnail (falls back to initials)
              Container(
                width: avatarSize,
                height: avatarSize,
                clipBehavior: Clip.antiAlias,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: bytes == null ? _bannerGradient : null,
                  borderRadius: BorderRadius.circular(avatarSize * 0.3),
                ),
                child: bytes != null
                    ? Image.memory(
                        bytes,
                        width: avatarSize,
                        height: avatarSize,
                        fit: BoxFit.cover,
                      )
                    : Text(
                        initials,
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
                      profile.employeeName,
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
                          text: profile.employeeCode,
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
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.calendar_today_outlined,
                    size: 15,
                    color: Colors.blue[700],
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Submitted',
                  style: TextStyle(fontSize: 12.5, color: _kMuted),
                ),
                const Spacer(),
                Text(
                  DateFormat('MMM dd, yyyy').format(profile.requestDate),
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: _kInk,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _approvePhoto(profile),
              icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
              label: const Text(
                'Review Photo',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
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