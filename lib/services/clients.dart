class Clients {
  final String clientCode;
  final String clientName;
  final String clientSuitNo;
  final String clientSteetNO;
  final String clientPostalCode;
  final String clientTown;
  final String clientLegalName;
  final String clientProvince;
  final String clientCountry;
  final String clientEmail;
  final String clientPhone;
  final String? clientIndustryCode;
  final String? clientFax;
  final String? clientShortName;
  final String? clientCountryCode;
  final String? clientGlCode;
  final String? clientFiscalYear;
  final String? clientParentCode;
  final String? clientChildCode;
  final bool clientStatus;
  final bool clientVendor;

  Clients({
    required this.clientCode,
    required this.clientName,
    required this.clientSuitNo,
    required this.clientSteetNO,
    required this.clientPostalCode,
    required this.clientTown,
    required this.clientLegalName,
    required this.clientProvince,
    required this.clientCountry,
    required this.clientEmail,
    required this.clientPhone,
    this.clientIndustryCode,
    this.clientFax,
    this.clientShortName,
    this.clientCountryCode,
    this.clientGlCode,
    this.clientFiscalYear,
    this.clientParentCode,
    this.clientChildCode,
    required this.clientStatus,
    required this.clientVendor
  });

  factory Clients.fromJson(Map<String, dynamic> json) {
    return Clients(
      clientCode: json['code'] ?? json['Code'] ?? '',
      clientName: json['name'] ?? json['Name'] ?? '',
      clientSuitNo: json['suitNo'] ?? json['SuitNo'] ?? '',
      clientSteetNO: json['steetNO'] ?? json['SteetNO'] ?? '',
      clientPostalCode: json['postalCode'] ?? json['PostalCode'] ?? '',
      clientTown: json['town'] ?? json['Town'] ?? '',
      clientProvince: json['province'] ?? json['Province'] ?? '',
      clientCountry: json['country'] ?? json['Country'] ?? '',
      clientEmail: json['email'] ?? json['Email'] ?? '',
      clientLegalName: json['legalName'] ?? json['LegalName'] ?? '',
      clientPhone: json['phone'] ?? json['Phone'] ?? '',
      clientIndustryCode: json['industryCode'] ?? json['IndustryCode'] ?? '',
      clientFax: json['fax'] ?? json['Fax'] ?? '',
      clientShortName: json['shortName'] ?? json['ShortName'] ?? '',
      clientCountryCode: json['countryCode'] ?? json['CountryCode'] ?? '',
      clientGlCode: json['glCode'] ?? json['GlCode'] ?? '',
      clientFiscalYear: json['fiscalYear'] ?? json['FiscalYear'] ?? '',
      clientParentCode: json['parentCode'] ?? json['ParentCode'] ?? '',
      clientChildCode: json['childCode'] ?? json['ChildCode'] ?? '',
      clientStatus: _parseBool(json['status']),
      clientVendor: _parseBool(json['vendor']),
    );
  }
  
  static bool _parseBool(dynamic value){
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

  @override
  bool operator ==(Object other) {
    // TODO: implement ==
    return other is Clients &&
    runtimeType == other.runtimeType &&
    clientCode == other.clientCode;
  }

  @override
  // TODO: implement hashCode
  int get hashCode => clientCode.hashCode;

  @override
  String toString() {
    return 'Clients(clientCode: $clientCode, clientName: $clientName)';
  }
}