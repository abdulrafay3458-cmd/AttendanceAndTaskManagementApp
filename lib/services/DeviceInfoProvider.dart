import 'dart:convert';
import 'dart:io';
import 'package:attendance_app/models/DeviceInfoModel.dart';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

class DeviceInfoProvider {
  static Future<DeviceInfoModel> getDeviceInfo() async {
    final deviceInfoPlugin = DeviceInfoPlugin();
    final packageInfo = await PackageInfo.fromPlatform();

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfoPlugin.androidInfo;

      return DeviceInfoModel(
        androidId: androidInfo.id, // This is ANDROID_ID
        manufacturer: androidInfo.manufacturer ?? "unknown",
        model: androidInfo.model ?? "unknown",
        osVersion: androidInfo.version.release ?? "unknown",
        sdkInt: androidInfo.version.sdkInt ?? 0,
        appVersion: packageInfo.version,
      );
    } else {
      throw UnsupportedError("Only Android supported");
    }
  }

  static Future<String> generateDeviceHash(DeviceInfoModel info) async {
    final raw = info.androidId + info.model + info.manufacturer;
    return sha256.convert(utf8.encode(raw)).toString();
  }
}
