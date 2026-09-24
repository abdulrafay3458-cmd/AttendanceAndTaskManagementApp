class Chart {
  // final String type;
  final int onTime;
  final int late;
 
  Chart({
    // required this.type,
    required this.onTime,
    required this.late,
  });
 
  factory Chart.fromJson(Map<String, dynamic> json) {
    return Chart(
      // type: json['type'] as String,
      onTime: json['onTime'] as int,
      late: json['late'] as int,
    );
  }
 
  Map<String, dynamic> toJson() {
    return {
      // 'Type': type,
      'OnTime': onTime,
      'Late': late,
    };
  }
 
  @override
  String toString() {
    return 'Chart(onTime: $onTime, late: $late)';
  }
}