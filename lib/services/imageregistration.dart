import 'dart:io';
import 'package:attendance_app/ProfileScreen.dart';
import 'package:attendance_app/services/apiservice.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

typedef OnImageUploaded = void Function(bool success);

class ProfileImageService {
  File? _previousImage;

  /// Opens the front camera and navigates to camera screen
  static Future<void> openFrontCamera({
    required BuildContext context,
    required Function(File file) onImageCaptured,
  }) async {
    final cameras = await availableCameras();

    final frontCamera = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
    );

    final controller = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    await controller.initialize();

    if (!context.mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FrontCameraScreen(
          controller: controller,
          onImageCaptured: onImageCaptured,
        ),
      ),
    );
  }

  /// Uploads image and returns success status
  Future<bool> uploadImage({
    required File file,
    required BuildContext context,
    File? currentImage,
  }) async {
    _previousImage = currentImage;

    bool isUploading = true;

    // Show temporary image if needed
    // You can also use a callback to update UI in the calling widget

    final success = await ApiService.uploadProfileImage(
      file: file,
      name: ApiService.currentEmployee!.name,
      personId: ApiService.currentEmployee!.employeeId,
    );

    isUploading = false;

    if (!context.mounted) return false;

    // Return old image if failed
    if (!success) {
      return false;
    }

    return true;
  }
}
