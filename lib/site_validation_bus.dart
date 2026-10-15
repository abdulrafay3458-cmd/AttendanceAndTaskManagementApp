import 'dart:async';

class SiteValidationBus {
  SiteValidationBus._();
  static final SiteValidationBus instance = SiteValidationBus._();

  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get stream => _controller.stream;

  void emit(Map<String, dynamic> data) {
    if (data['type'] == 'site_validation') {
      _controller.add(data);
    }
  }
}