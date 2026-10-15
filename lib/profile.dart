import 'dart:convert';
import 'dart:io';

import 'package:attendance_app/ChangePasswordPage.dart';
import 'package:attendance_app/login.dart';
import 'package:attendance_app/models/applyimage.dart';
import 'package:attendance_app/services/apiservice.dart';
import 'package:attendance_app/services/imageregistration.dart';
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

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // image registration part
  File? _profileImage;
  bool _isUploading = false;
  bool isApproved = false;
  String? _pendingApprovalImage;

  // Loading state
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;

  bool needToRegisterDevice =
      ApiService.currentEmployee?.isDeviceRegistered == true ? false : true;

  final ProfileImageService _imageService = ProfileImageService();

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  void _snack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? _kRed : _kGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _loadProfileData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      await checkImageApprovalStatus();

      // Add a small delay to show loader (optional, remove if not needed)
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Failed to load profile data';
      });
      print('Error loading profile: $e');
    }
  }

  Future<void> checkImageApprovalStatus() async {
    final employee = ApiService.currentEmployee;
    if (employee == null) return;

    try {
      final approved = await ApiService.getImageApprovalStatus(
        employee.employeeId,
      );

      if (!mounted) return;
      setState(() {
        isApproved = approved;

        if (isApproved) {
          _pendingApprovalImage = null;
        }
      });
    } catch (e) {
      print('Error checking approval status: $e');
      rethrow;
    }
  }

  void _captureImage() async {
    await ProfileImageService.openFrontCamera(
      context: context,
      onImageCaptured: (file) async {
        final bytes = await file.readAsBytes();
        final base64Image = base64Encode(bytes);

        setState(() {
          _isUploading = true;
          _pendingApprovalImage = base64Image;
        });
        final  aa  =  ApiService.empGuid;
        if (aa == null || aa.isEmpty) {
          print('Employee GUID is null or empty');
          return;
        }
        final success = await ApiService.getNewProfileRequest(
          ApplyImageModel(
            employeeCode:aa,
            faceImage: base64Image,
            companyCode: ApiService.currentEmployee!.companyGuid,
          ),
        );

        if (success['success'] == true) {
          await checkImageApprovalStatus();
          _snack('Image sent for approval');
        } else {
          setState(() {
            _pendingApprovalImage = null;
          });
          _snack('Image approval failed.', isError: true);
        }

        if (mounted) {
          setState(() {
            _isUploading = false;
          });
        }
      },
    );
  }

  ImageProvider? _getProfileImage() {
    final employee = ApiService.currentEmployee;

    if (isApproved == false) {
      _pendingApprovalImage = "true";
    }

    if (isApproved == true &&
        employee?.faceImageBase64 != null &&
        employee!.faceImageBase64!.isNotEmpty) {
      try {
        return MemoryImage(base64Decode(employee.faceImageBase64!.trim()));
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  bool _shouldShowCameraIcon() {
    final employee = ApiService.currentEmployee;

    if (_pendingApprovalImage != null) {
      return false;
    }

    return isApproved != true ||
        employee?.faceImageBase64 == null ||
        employee!.faceImageBase64!.isEmpty;
  }

  String _getDisplayText(String? value) {
    if (_isLoading) return 'Loading...';
    if (value == null || value.isEmpty) return 'Not Available';
    return value;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final employee = ApiService.currentEmployee;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color.fromARGB(255, 12, 86, 147),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Loading profile data...',
                    style: TextStyle(color: _kMuted),
                  ),
                ],
              ),
            )
          : _hasError
              ? _buildError()
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  child: Column(
                    children: [
                      _buildHeader(employee),
                      const SizedBox(height: 20),
                      _buildInfoSection(
                        'Personal Information',
                        Icons.person_outline_rounded,
                        [
                          _buildInfoTile(
                            Icons.email_outlined,
                            'Email',
                            _getDisplayText(employee?.email),
                          ),
                          _buildInfoTile(
                            Icons.business_outlined,
                            'Department',
                            _getDisplayText(employee?.department),
                          ),
                          _buildInfoTile(
                            Icons.work_outline_rounded,
                            'Designation',
                            _getDisplayText(employee?.designation),
                          ),
                          _buildInfoTile(
                            Icons.verified_outlined,
                            'Profile Image Status',
                            isApproved == true
                                ? 'Approved'
                                : _pendingApprovalImage != null
                                    ? 'Pending Approval'
                                    : 'Not Uploaded',
                            last: true,
                          ),
                        ],
                      ),
                      _buildInfoSection(
                        'App Information',
                        Icons.phone_android_rounded,
                        [
                          _buildInfoTile(
                            Icons.phone_android_rounded,
                            'Platform',
                            Platform.isAndroid ? 'Android' : 'iOS',
                          ),
                          _buildInfoTile(
                            Icons.wifi_rounded,
                            'Status',
                            'Connected',
                            last: true,
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: _softShadow,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildActionTile(
                                icon: Icons.lock_reset_rounded,
                                label: 'Reset Password',
                                color: _kAccent,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ChangePasswordPage(),
                                    ),
                                  );
                                },
                              ),
                              _buildActionTile(
                                icon: Icons.logout_rounded,
                                label: 'Logout',
                                color: _kRed,
                                last: true,
                                onTap: () async {
                                  await ApiService.clearCredentials();
                                  if (mounted) {
                                    Navigator.pushAndRemoveUntil(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const LoginScreen(),
                                      ),
                                      (route) => false,
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                     ],
                  ),
                ),
    );
  }

  Widget _buildError() {
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
                color: _kRed.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded,
                  size: 38, color: _kRed),
            ),
            const SizedBox(height: 14),
            Text(
              _errorMessage ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _kInk,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadProfileData,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                backgroundColor: _kAccent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header banner with avatar
  // ---------------------------------------------------------------------------
  Widget _buildHeader(dynamic employee) {
    final profileImage = _getProfileImage();
    final pending = _pendingApprovalImage != null && isApproved != true;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
      decoration: BoxDecoration(
        gradient: _bannerGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _kGradient.withOpacity(0.30),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _isUploading ? null : _showImageAlert,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.25),
                  ),
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    backgroundImage: profileImage,
                    child: _shouldShowCameraIcon()
                        ? Icon(
                            Icons.camera_alt_rounded,
                            size: SizeConfig.w(10),
                            color: Colors.blue[700],
                          )
                        : (!isApproved)
                            ? Icon(
                                Icons.person_rounded,
                                size: SizeConfig.w(18),
                                color: Colors.blue[700],
                              )
                            : null,
                  ),
                ),
                if (isApproved == true && profileImage != null)
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: _softShadow,
                      ),
                      child: Icon(Icons.edit_rounded,
                          size: 16, color: Colors.blue[700]),
                    ),
                  ),
                if (pending)
                  Positioned(
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _kAmber,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Pending',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                if (_isUploading)
                  Container(
                    width: 108,
                    height: 108,
                    decoration: const BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            employee?.name?.toUpperCase() ?? 'Not Available',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.20),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.badge_outlined,
                    size: 14, color: Colors.white),
                const SizedBox(width: 6),
                Text(
                  employee?.employeeId ?? 'Not Available',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (pending) ...[
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.hourglass_top_rounded,
                      size: 14, color: _kAmber),
                  SizedBox(width: 6),
                  Text(
                    'Image pending manager approval',
                    style: TextStyle(
                      color: _kAmber,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Dialogs
  // ---------------------------------------------------------------------------
  void _showImageAlert() {
    if (_pendingApprovalImage != null && isApproved != true) {
      showDialog(
        context: context,
        builder: (context) => _DialogShell(
          icon: Icons.hourglass_top_rounded,
          title: 'Image Pending Approval',
          subtitle: 'Your profile image is waiting for manager approval.',
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return;
    }

    if (!needToRegisterDevice) {
      showDialog(
        context: context,
        builder: (context) => _DialogShell(
          icon: Icons.camera_alt_rounded,
          title: 'Profile Image',
          subtitle:
              'Image updates require admin approval. Manual check-in/check-out is unavailable.',
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel',
                  style: TextStyle(color: _kMuted)),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.camera_alt_outlined, size: 18),
              label: const Text('Capture Image'),
              onPressed: () {
                Navigator.of(context).pop();
                _captureImage();
              },
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => _DialogShell(
          icon: Icons.phone_android_rounded,
          title: 'Profile Image',
          subtitle:
              'Please register your device to access the profile image feature.',
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Sections & tiles
  // ---------------------------------------------------------------------------
  Widget _buildInfoSection(
      String title, IconData icon, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: _softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _kAccent.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: _kAccent),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: _kInk,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value,
      {bool last = false}) {
    final muted = value == 'Loading...' || value == 'Not Available';

    Color? statusColor;
    if (label == 'Profile Image Status') {
      statusColor = value == 'Approved'
          ? _kGreen
          : (value == 'Pending Approval' ? _kAmber : _kMuted);
    } else if (label == 'Status' && value == 'Connected') {
      statusColor = _kGreen;
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _kAccent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: _kAccent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(fontSize: 12, color: _kMuted),
                    ),
                    const SizedBox(height: 2),
                    statusColor != null
                        ? Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                value,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            value,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: muted ? _kMuted : _kInk,
                            ),
                          ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!last) const Divider(height: 1, color: _kLine),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool last = false,
  }) {
    return Column(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: color == _kRed ? _kRed : _kInk,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: _kMuted),
              ],
            ),
          ),
        ),
        if (!last) const Divider(height: 1, color: _kLine),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Shared dialog frame
// -----------------------------------------------------------------------------
class _DialogShell extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> actions;

  const _DialogShell({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actions,
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
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: SizeConfig.f(17),
                  fontWeight: FontWeight.w700,
                  color: _kInk,
                ),
              ),
            ),
          ),
        ],
      ),
      content: Text(
        subtitle,
        style: const TextStyle(fontSize: 14, color: _kMuted, height: 1.4),
      ),
      actions: actions,
    );
  }
}