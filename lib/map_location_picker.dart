import 'dart:async';
import 'dart:convert';

import 'package:attendance_app/map_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Result returned when the user confirms a spot on the map.
class PickedLocation {
  final double latitude;
  final double longitude;
  final String address;
  PickedLocation(this.latitude, this.longitude, this.address);
}

class _SearchResult {
  final String name;
  final LatLng point;
  _SearchResult(this.name, this.point);
}

/// Throttled + cached access to the geocoder (respects the 1 req/sec limit).
class _Geocoder {
  static final Map<String, String> _reverseCache = {};
  static final Map<String, List<_SearchResult>> _searchCache = {};
  static DateTime _nextSlot = DateTime.fromMillisecondsSinceEpoch(0);

  /// Waits its turn so requests are never closer than MapConfig.geocoderGap.
  static Future<http.Response> _get(Uri uri) async {
    final now = DateTime.now();
    final slot = _nextSlot.isAfter(now) ? _nextSlot : now;
    _nextSlot = slot.add(MapConfig.geocoderGap);
    final wait = slot.difference(now);
    if (wait > Duration.zero) await Future.delayed(wait);
    return http.get(uri, headers: {'User-Agent': MapConfig.userAgent});
  }

  static Future<String> reverse(LatLng p) async {
    final key = '${p.latitude.toStringAsFixed(5)},${p.longitude.toStringAsFixed(5)}';
    if (_reverseCache.containsKey(key)) return _reverseCache[key]!;
    try {
      final uri = Uri.https(MapConfig.geocoderHost, '/reverse', {
        'format': 'jsonv2',
        'lat': '${p.latitude}',
        'lon': '${p.longitude}',
      });
      final res = await _get(uri);
      if (res.statusCode == 200) {
        final addr = (jsonDecode(res.body)['display_name'] ?? '').toString();
        _reverseCache[key] = addr;
        return addr;
      }
    } catch (_) {}
    return '';
  }

  static Future<List<_SearchResult>> search(String query) async {
    final key = query.toLowerCase().trim();
    if (_searchCache.containsKey(key)) return _searchCache[key]!;
    final uri = Uri.https(MapConfig.geocoderHost, '/search',
        {'format': 'jsonv2', 'q': query, 'limit': '5'});
    final res = await _get(uri);
    if (res.statusCode != 200) throw Exception('search failed');
    final list = (jsonDecode(res.body) as List)
        .map((e) => _SearchResult(
              e['display_name'].toString(),
              LatLng(double.parse(e['lat']), double.parse(e['lon'])),
            ))
        .toList();
    _searchCache[key] = list;
    return list;
  }
}

class MapLocationPicker extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;

  /// Allowed radius in meters, drawn as a circle around the marker.
  final double radius;

  const MapLocationPicker({
    super.key,
    this.initialLat,
    this.initialLng,
    this.radius = 100,
  });

  @override
  State<MapLocationPicker> createState() => _MapLocationPickerState();
}

class _MapLocationPickerState extends State<MapLocationPicker> {
  final MapController _map = MapController();
  final TextEditingController _searchCtrl = TextEditingController();

  LatLng? _point;
  String _address = '';
  bool _loadingAddress = false;
  bool _searching = false;
  List<_SearchResult> _results = [];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  LatLng get _startCenter {
    if (widget.initialLat != null && widget.initialLng != null) {
      return LatLng(widget.initialLat!, widget.initialLng!);
    }
    return const LatLng(20, 0); // world view until we find the user
  }

  double get _startZoom =>
      (widget.initialLat != null && widget.initialLng != null) ? 16 : 2;

  void _onMapReady() {
    if (widget.initialLat != null && widget.initialLng != null) {
      _select(LatLng(widget.initialLat!, widget.initialLng!), moveMap: false);
    } else {
      _goToMyLocation(silent: true);
    }
  }

  Future<void> _select(LatLng p, {bool moveMap = true, double zoom = 16}) async {
    setState(() {
      _point = p;
      _results = [];
      _loadingAddress = true;
    });
    if (moveMap) _map.move(p, zoom);

    // Reverse geocode: coordinates -> address
    final address = MapConfig.enableGeocoding ? await _Geocoder.reverse(p) : '';

    // ignore if the user already tapped somewhere else
    if (!mounted || _point != p) return;
    setState(() {
      _address = address;
      _loadingAddress = false;
    });
  }

  Future<void> _search() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _searching = true);

    try {
      _results = await _Geocoder.search(q);
      if (_results.isEmpty) _toast('No places found');
    } catch (_) {
      _toast('Search failed. Check your internet connection.');
    }
    if (mounted) setState(() => _searching = false);
  }

  Future<void> _goToMyLocation({bool silent = false}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (!silent) _toast('Please turn on location services');
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (!silent) _toast('Location permission denied');
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      _select(LatLng(pos.latitude, pos.longitude));
    } catch (_) {
      if (!silent) _toast('Could not get current location');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _confirm() {
    if (_point == null) return;
    Navigator.pop(
      context,
      PickedLocation(_point!.latitude, _point!.longitude, _address),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Location',
            style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue[700],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: _startCenter,
              initialZoom: _startZoom,
              onMapReady: _onMapReady,
              onTap: (_, point) => _select(point, moveMap: false),
            ),
            children: [
              TileLayer(
                urlTemplate: MapConfig.tileUrl,
                userAgentPackageName: MapConfig.tilePackageName,
              ),
              if (_point != null)
                CircleLayer(circles: [
                  CircleMarker(
                    point: _point!,
                    radius: widget.radius,
                    useRadiusInMeter: true,
                    color: Colors.blue.withOpacity(0.15),
                    borderColor: Colors.blue.shade700,
                    borderStrokeWidth: 2,
                  ),
                ]),
              if (_point != null)
                MarkerLayer(markers: [
                  Marker(
                    point: _point!,
                    width: 48,
                    height: 48,
                    alignment: Alignment.topCenter,
                    child: const Icon(Icons.location_on,
                        size: 48, color: Colors.red),
                  ),
                ]),
              const RichAttributionWidget(attributions: [
                TextSourceAttribution('© OpenStreetMap contributors'),
              ]),
            ],
          ),

          // Search bar + results (hidden in tap-only mode)
          if (MapConfig.enableGeocoding)
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Column(
              children: [
                Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
                  child: TextField(
                    controller: _searchCtrl,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      hintText: 'Search address or place...',
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: Icon(Icons.search, color: Colors.blue[700]),
                      suffixIcon: _searching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
                            )
                          : IconButton(
                              icon: const Icon(Icons.arrow_forward),
                              onPressed: _search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                if (_results.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    constraints: const BoxConstraints(maxHeight: 220),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(blurRadius: 6, color: Colors.black26)
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) => ListTile(
                        dense: true,
                        leading:
                            Icon(Icons.place_outlined, color: Colors.blue[700]),
                        title: Text(_results[i].name,
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        onTap: () => _select(_results[i].point),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // My location button
          Positioned(
            right: 12,
            bottom: 190,
            child: FloatingActionButton.small(
              heroTag: 'myLoc',
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue[700],
              onPressed: () => _goToMyLocation(),
              child: const Icon(Icons.my_location),
            ),
          ),

          // Bottom info card
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_point == null)
                      Text('Tap on the map to drop a pin',
                          style: TextStyle(color: Colors.grey[700]))
                    else ...[
                      Row(
                        children: [
                          Icon(Icons.place, size: 18, color: Colors.blue[700]),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _loadingAddress
                                  ? 'Finding address...'
                                  : (_address.isEmpty
                                      ? (MapConfig.enableGeocoding
                                          ? 'Address not found'
                                          : 'Pin dropped')
                                      : _address),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_point!.latitude.toStringAsFixed(6)}, ${_point!.longitude.toStringAsFixed(6)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: (_point == null || _loadingAddress)
                            ? null
                            : _confirm,
                        icon: const Icon(Icons.check),
                        label: const Text('Confirm Location'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
