import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Profile Screen')),
    );
  }
}

class FrontCameraScreen extends StatelessWidget {
  final CameraController controller;
  final Function(File) onImageCaptured;

  const FrontCameraScreen({
    super.key,
    required this.controller,
    required this.onImageCaptured,
  });

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

return Scaffold(
  backgroundColor: Colors.black,
  body: Stack(
    children: [
      SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover, // 🔥 KEY FIX
          child: SizedBox(
            width: controller.value.previewSize!.height,
            height: controller.value.previewSize!.width,
            child: CameraPreview(controller),
          ),
        ),
      ),

      Positioned(
        bottom: 30,
        left: 0,
        right: 0,
        child: Center(
          child: FloatingActionButton(
            child: const Icon(Icons.camera),
            onPressed: () async {
              final image = await controller.takePicture();
              onImageCaptured(File(image.path));
              Navigator.pop(context);
            },
          ),
        ),
      ),
    ],
  ),
);


  }
}
