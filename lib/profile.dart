import 'dart:convert';
import 'dart:io';

import 'package:attendance_app/ChangePasswordPage.dart';
import 'package:attendance_app/login.dart';
import 'package:attendance_app/models/applyimage.dart';
import 'package:attendance_app/services/apiservice.dart';
import 'package:attendance_app/services/imageregistration.dart';
import 'package:attendance_app/widgets/SizeConfig.dart';
import 'package:flutter/material.dart';

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

  Future<void> _loadProfileData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      await checkImageApprovalStatus();

      // Add a small delay to show loader (optional, remove if not needed)
      await Future.delayed(const Duration(milliseconds: 500));

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
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

        final success = await ApiService.getNewProfileRequest(
          ApplyImageModel(
            employeeCode: ApiService.currentEmployee!.employeeId,
            faceImage: base64Image,
            companyCode: ApiService.currentEmployee!.companyCode,
          ),
        );

        if (success['success'] == true) {
          await checkImageApprovalStatus();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Image sent for approval'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          setState(() {
            _pendingApprovalImage = null;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Image approval failed.'),
                backgroundColor: Colors.red,
              ),
            );
          }
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

  @override
  Widget build(BuildContext context) {
    final employee = ApiService.currentEmployee;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading profile data...'),
                ],
              ),
            )
          : _hasError
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage ?? 'Something went wrong',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loadProfileData,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(25, 118, 210, 1),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(30),
                        bottomRight: Radius.circular(30),
                      ),
                    ),
                    child: Column(
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: _isUploading ? null : _showImageAlert,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundColor: Colors.white,
                                backgroundImage: _getProfileImage(),
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
                              if (isApproved == true &&
                                  _getProfileImage() != null)
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: _showImageAlert,
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: const Color.fromARGB(
                                          255,
                                          255,
                                          255,
                                          255,
                                        ),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.edit,
                                        size: 16,
                                        color: Colors.blue[700],
                                      ),
                                    ),
                                  ),
                                ),
                              if (_pendingApprovalImage != null &&
                                  isApproved != true)
                                Positioned(
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'Pending',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              if (_isUploading)
                                Container(
                                  width: 100,
                                  height: 100,
                                  decoration: const BoxDecoration(
                                    color: Colors.black45,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          employee?.name?.toUpperCase() ?? 'Not Available',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          employee?.employeeId ?? 'Not Available',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        if (_pendingApprovalImage != null && isApproved != true)
                          const SizedBox(height: 8),
                        if (_pendingApprovalImage != null && isApproved != true)
                          const Text(
                            'Image pending manager approval',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildInfoSection('Personal Information', [
                    _buildInfoTile(
                      Icons.email,
                      'Email',
                      _getDisplayText(employee?.email),
                    ),
                    _buildInfoTile(
                      Icons.business,
                      'Department',
                      _getDisplayText(employee?.department),
                    ),
                    _buildInfoTile(
                      Icons.work,
                      'Designation',
                      _getDisplayText(employee?.designation),
                    ),
                    _buildInfoTile(
                      Icons.verified,
                      'Profile Image Status',
                      isApproved == true
                          ? 'Approved'
                          : _pendingApprovalImage != null
                          ? 'Pending Approval'
                          : 'Not Uploaded',
                    ),
                  ]),
                  const SizedBox(height: 16),
                  _buildInfoSection('App Information', [
                    _buildInfoTile(
                      Icons.phone_android,
                      'Platform',
                      Platform.isAndroid ? 'Android' : 'iOS',
                    ),
                    _buildInfoTile(Icons.verified_user, 'Status', 'Connected'),
                  ]),
                  const SizedBox(height: 24),
                  _buildInfoSection('App Settings', []),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChangePasswordPage(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.lightBlue,
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.lock_reset_sharp, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'Reset Password',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        ElevatedButton(
                          onPressed: () async {
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
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.logout, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'Logout',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Padding(
                  //   padding: const EdgeInsets.all(24),
                  //   child: ElevatedButton(
                  //     onPressed: () async {
                  //       await ApiService.clearCredentials();
                  //       if (mounted) {
                  //         Navigator.pushAndRemoveUntil(
                  //           context,
                  //           MaterialPageRoute(
                  //             builder: (context) => const LoginScreen(),
                  //           ),
                  //           (route) => false,
                  //         );
                  //       }
                  //     },
                  //     style: ElevatedButton.styleFrom(
                  //       backgroundColor: Colors.red,
                  //       minimumSize: const Size(double.infinity, 50),
                  //     ),
                  //     child: const Row(
                  //       mainAxisAlignment: MainAxisAlignment.center,
                  //       children: [
                  //         Icon(Icons.logout, color: Colors.white),
                  //         SizedBox(width: 8),
                  //         Text(
                  //           'Logout',
                  //           style: TextStyle(
                  //             fontSize: 16,
                  //             color: Colors.white,
                  //             fontWeight: FontWeight.bold,
                  //           ),
                  //         ),
                  //       ],
                  //     ),
                  //   ),
                  // ),
                  // const SizedBox(height: 24),
                  // _buildInfoSection('App Settings', []),
                  // Padding(
                  //   padding: const EdgeInsets.all(24),
                  //   child: ElevatedButton(
                  //     onPressed: () async {
                  //       if (mounted) {
                  //         Navigator.pushReplacement(
                  //           context,
                  //           MaterialPageRoute(
                  //             builder: (context) => ChangePasswordPage(),
                  //           ),
                  //         );
                  //       }
                  //     },
                  //     style: ElevatedButton.styleFrom(
                  //       backgroundColor: Colors.lightBlue,
                  //       minimumSize: const Size(double.infinity, 50),
                  //     ),
                  //     child: const Row(
                  //       mainAxisAlignment: MainAxisAlignment.center,
                  //       children: [
                  //         Icon(Icons.lock_reset_rounded, color: Colors.white),
                  //         SizedBox(width: 8),
                  //         Text(
                  //           'Reset Password',
                  //           style: TextStyle(
                  //             fontSize: 16,
                  //             color: Colors.white,
                  //             fontWeight: FontWeight.bold,
                  //           ),
                  //         ),
                  //       ],
                  //     ),
                  //   ),
                  // ),
                ],
              ),
            ),
    );
  }

  void _showImageAlert() {
    final employee = ApiService.currentEmployee;

    if (_pendingApprovalImage != null && isApproved != true ) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Image Pending Approval',
            style: TextStyle(
              fontSize: SizeConfig.f(16),
              fontWeight: FontWeight.w700,
            ),
          ),
          content: const Text(
            'Your profile image is waiting for manager approval.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
      return;
    }

    if (!needToRegisterDevice) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Profile Image'),
          content: const Text(
            'Image updates require admin approval. Manual check-in/check-out is unavailable.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _captureImage();
              },
              child: const Text('Capture Image'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      );    
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Profile Image'),
          content: const Text(
            'Please register your device to access the profile image feature.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      );    
    }
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue[700]),
      title: Text(label, style: const TextStyle(fontSize: 12)),
      subtitle: Text(
        value,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: value == 'Loading...' || value == 'Not Available'
              ? Colors.grey
              : null,
        ),
      ),
    );
  }
}
