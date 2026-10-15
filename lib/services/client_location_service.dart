// lib/services/client_location_service.dart
//
// Now talks to the real backend through ApiService.
// Screens are unchanged - same method names and return types.

import 'package:attendance_app/services/apiservice.dart';
import 'package:attendance_app/services/client_location.dart';

class ClientLocationService {
  /// Last error message from the server (shown in snackbars).
  static String lastError = '';

  // GET  Entity/location/all
  static Future<List<ClientLocation>> getClientLocations() async {
    final data = await ApiService.getClientLocations();
    return data
        .map((json) => ClientLocation.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  // POST Entity/location/add
  static Future<bool> addClientLocation(ClientLocation loc) async {
    lastError = '';
    final body = loc.toJson()..remove('clientLocationId'); // server generates it
    final res = await ApiService.addClientLocation(body);
    if (res['success'] == true) return true;
    lastError = (res['error'] ?? '').toString();
    return false;
  }

  // PUT  Entity/location/update/{id}
  static Future<bool> updateClientLocation(ClientLocation loc) async {
    lastError = '';
    final res = await ApiService.updateClientLocation(
      loc.clientLocationId,
      loc.toJson(),
    );
    if (res['success'] == true) return true;
    lastError = (res['error'] ?? '').toString();
    return false;
  }

  // DELETE Entity/location/delete/{id}
  static Future<bool> deleteClientLocation(String clientLocationId) async {
    lastError = '';
    final res = await ApiService.deleteClientLocation(clientLocationId);
    if (res['success'] == true) return true;
    lastError = (res['error'] ?? '').toString();
    return false;
  }
}