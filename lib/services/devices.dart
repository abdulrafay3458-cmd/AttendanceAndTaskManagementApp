class Devices {
  final String Id;
  final String Name;
  final String IpAddress;
  final int Port;
  final String Location;
  final String Status;
  final DateTime? LastSync;
  final int MachineNumber;
  final String CompanyCode;
  final bool IsActive;
  final bool CanReadLogs;

  Devices({
    required this.Id,
    required this.Name,
    required this.IpAddress,
    required this.Port,
    required this.Location,
    required this.Status,
    required this.LastSync,
    required this.MachineNumber,
    required this.CompanyCode,
    required this.IsActive,
    required this.CanReadLogs,
  });

  factory Devices.fromJson(Map<String, dynamic> json) {
    return Devices(
      Id: json['deviceId']?.toString() ?? json['DeviceId']?.toString() ?? '',
      Name: json['deviceName'] ?? json['DeviceName'] ?? '',
      IpAddress: json['ipAddress'] ?? json['IpAddress'] ?? '',
      Port: _parseInt(json['port'] ?? json['Port']),
      Location: json['location'] ?? json['Location'] ?? '',
      CompanyCode: json['companyCode'] ?? json['CompanyCode'] ?? '',
      Status: json['status'] ?? json['Status'] ?? '',
      LastSync: _parseDateTime(json['lastSync'] ?? json['LastSync']),
      MachineNumber: _parseInt(json['machineNumber'] ?? json['MachineNumber']),
      IsActive: _parseBool(json['isActive'] ?? json['IsActive']),
      CanReadLogs: _parseBool(json['canReadLogs'] ?? json['CanReadLogs']),
    );
  }

  static bool _parseBool(dynamic value) {
    if (value == null) return false;

    if (value is bool) return value;

    if (value is int) return value == 1;

    if (value is String) {
      return value.toLowerCase() == 'true' ||
          value == '1' ||
          value.toLowerCase() == 'yes' ||
          value.toLowerCase() == 'active';
    }

    return false;
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null || value.toString().isEmpty) return null;
    return DateTime.tryParse(value.toString());
  }

  // @override
  // bool operator ==(Object other) {
  //   // TODO: implement ==
  //   return other is Devices &&
  //   runtimeType == other.runtimeType &&
  //   clientCode == other.clientCode;
  // }

  // @override
  // // TODO: implement hashCode
  // int get hashCode => clientCode.hashCode;

  // @override
  // String toString() {
  //   return 'Clients(clientCode: $clientCode, clientName: $clientName)';
  // }
}
