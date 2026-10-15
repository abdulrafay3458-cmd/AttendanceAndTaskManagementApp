// lib/services/client_location.dart

class ClientLocation {
  final String clientLocationId;
  final String clientId;
  final String clientName; // display only (joined from Client table)
  final String locationName;
  final String address;
  final double latitude;
  final double longitude;
  final double allowedRadius; // in meters
  final String status;
  final DateTime? createdDate;
  final bool isActive;

  ClientLocation({
    required this.clientLocationId,
    required this.clientId,
    this.clientName = '',
    required this.locationName,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.allowedRadius,
    required this.status,
    this.createdDate,
    required this.isActive,
  });

  factory ClientLocation.fromJson(Map<String, dynamic> json) {
    double toD(dynamic v) => v == null ? 0 : double.tryParse('$v') ?? 0;
    return ClientLocation(
      clientLocationId: (json['clientLocationId'] ?? '').toString(),
      clientId: (json['clientId'] ?? '').toString(),
      clientName: (json['clientName'] ?? '').toString(),
      locationName: (json['locationName'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      latitude: toD(json['latitude']),
      longitude: toD(json['longitude']),
      allowedRadius: toD(json['allowedRadius']),
      status: (json['status'] ?? 'Active').toString(),
      createdDate: json['createdDate'] != null
          ? DateTime.tryParse(json['createdDate'].toString())
          : null,
      isActive: json['isActive'] == true || json['isActive'] == 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'clientLocationId': clientLocationId,
        'clientId': clientId,
        'locationName': locationName,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'allowedRadius': allowedRadius,
        'status': status,
        'isActive': isActive,
      };
}
