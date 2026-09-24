class DeviceInfoModel {
  final String androidId;
  final String manufacturer;
  final String model;
  final String osVersion;
  final int sdkInt;
  final String appVersion;

  DeviceInfoModel({
    required this.androidId,
    required this.manufacturer,
    required this.model,
    required this.osVersion,
    required this.sdkInt,
    required this.appVersion,
  });

  Map<String, dynamic> toJson() => {
        "androidId": androidId,
        "manufacturer": manufacturer,
        "model": model,
        "osVersion": osVersion,
        "sdkInt": sdkInt,
        "appVersion": appVersion,
      };
}