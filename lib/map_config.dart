// lib/map_config.dart
//
// One place to control every external map service.
// To switch provider later (or load these from your backend / remote config
// at app start), change the values here - no screen needs to be edited.

class MapConfig {
  /// Map tiles. Replace with your own / paid provider URL when you grow.
  static String tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Address search + reverse lookup (Nominatim-compatible API).
  /// Later point this at your own backend proxy, e.g. 'api.yourcompany.com'.
  static String geocoderHost = 'nominatim.openstreetmap.org';

  /// Put a real contact here - OSM asks apps to identify themselves.
  static String userAgent =
      'attendance_app/1.0 (contact: hifza.hameed@vconn.biz)';

  static String tilePackageName = 'attendance_app';

  /// false = tap-to-pin only. No search box, no address lookup,
  /// so only map tiles are requested (lowest usage / lowest risk).
  static bool enableGeocoding = true;

  /// Minimum gap between geocoder requests (OSM limit: 1 request/second).
  static const Duration geocoderGap = Duration(milliseconds: 1100);
}
