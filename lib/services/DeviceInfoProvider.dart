import 'dart:convert';
import 'package:attendance_app/models/DeviceInfoModel.dart';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:package_info_plus/package_info_plus.dart';

class DeviceInfoProvider {
  static Future<DeviceInfoModel> getDeviceInfo() async {
    final deviceInfoPlugin = DeviceInfoPlugin();
    final packageInfo = await PackageInfo.fromPlatform();

    if (kIsWeb) {
      final webInfo = await deviceInfoPlugin.webBrowserInfo;

      return DeviceInfoModel(
        androidId: webInfo.vendor ?? webInfo.userAgent ?? "web-unknown",
        manufacturer: webInfo.vendor ?? "unknown",
        model: webInfo.browserName.name,
        osVersion: webInfo.platform ?? "unknown",
        sdkInt: 0,
        appVersion: packageInfo.version,
      );
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidInfo = await deviceInfoPlugin.androidInfo;

      return DeviceInfoModel(
        androidId: androidInfo.id, // This is ANDROID_ID
        manufacturer: androidInfo.manufacturer ?? "unknown",
        model: androidInfo.model ?? "unknown",
        osVersion: androidInfo.version.release ?? "unknown",
        sdkInt: androidInfo.version.sdkInt ?? 0,
        appVersion: packageInfo.version,
      );
    }

    throw UnsupportedError("Only Android and Web are supported");
  }

  static Future<String> generateDeviceHash(DeviceInfoModel info) async {
    final raw = info.androidId + info.model + info.manufacturer;
    return sha256.convert(utf8.encode(raw)).toString();
  }
}
