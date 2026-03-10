import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// KML coordinates are lng,lat — converted here to LatLng(lat, lng).
// Source: KIhumuro Zones.kmz (root of project)

class CampusZone {
  final String name;
  final String tag;
  final List<LatLng> points;

  const CampusZone({required this.name, required this.tag, required this.points});
}

const List<CampusZone> campusZones = [
  CampusZone(
    name: 'Kihumuro zone',
    tag: 'kihumuro_main',
    points: [
      LatLng(-0.5919473, 30.5933968),
      LatLng(-0.5966678, 30.5905858),
      LatLng(-0.5974402, 30.6011215),
      LatLng(-0.5943934, 30.6012073),
    ],
  ),
  CampusZone(
    name: 'Mile 4 zone',
    tag: 'mile_4',
    points: [
      LatLng(-0.5983348, 30.6093997),
      LatLng(-0.5994559, 30.6115830),
      LatLng(-0.5985333, 30.6120229),
      LatLng(-0.5977501, 30.6101453),
    ],
  ),
  CampusZone(
    name: 'Path hostel zone',
    tag: 'path_hostel',
    points: [
      LatLng(-0.5944472, 30.6105812),
      LatLng(-0.5941092, 30.6073357),
      LatLng(-0.5944579, 30.6073250),
      LatLng(-0.5949997, 30.6104149),
    ],
  ),
  CampusZone(
    name: 'Mama Belinda zone',
    tag: 'mama_belinda',
    points: [
      LatLng(-0.5935245, 30.6108645),
      LatLng(-0.5940395, 30.6132677),
      LatLng(-0.5932778, 30.6133643),
      LatLng(-0.5922586, 30.6110790),
    ],
  ),
  CampusZone(
    name: 'Mile 5 zone',
    tag: 'mile_5',
    points: [
      LatLng(-0.5831127, 30.6109449),
      LatLng(-0.5834990, 30.6102958),
      LatLng(-0.5853281, 30.6107143),
      LatLng(-0.5850921, 30.6114921),
    ],
  ),
  CampusZone(
    name: 'Mirrors zone',
    tag: 'mirrors',
    points: [
      LatLng(-0.6017127, 30.6170087),
      LatLng(-0.6025710, 30.6182828),
      LatLng(-0.6013292, 30.6180870),
    ],
  ),
  CampusZone(
    name: 'Mile 3 Zone A',
    tag: 'mile_3_a',
    points: [
      LatLng(-0.6073286, 30.6290089),
      LatLng(-0.6056657, 30.6270133),
      LatLng(-0.6043890, 30.6253396),
      LatLng(-0.6041101, 30.6240951),
      LatLng(-0.6054189, 30.6233441),
      LatLng(-0.6072106, 30.6256830),
      LatLng(-0.6082727, 30.6279789),
    ],
  ),
  CampusZone(
    name: 'Mile 3 zone B',
    tag: 'mile_3_b',
    points: [
      LatLng(-0.6047216, 30.6219815),
      LatLng(-0.6067814, 30.6189238),
      LatLng(-0.6089271, 30.6195246),
      LatLng(-0.6114697, 30.6230115),
      LatLng(-0.6081868, 30.6276034),
      LatLng(-0.6072535, 30.6255864),
    ],
  ),
  CampusZone(
    name: 'Kiyanja zone',
    tag: 'kiyanja',
    points: [
      LatLng(-0.6119066, 30.6372884),
      LatLng(-0.6105334, 30.6380394),
      LatLng(-0.6089349, 30.6388655),
      LatLng(-0.6086023, 30.6390801),
      LatLng(-0.6081517, 30.6365266),
      LatLng(-0.6083770, 30.6345740),
      LatLng(-0.6108231, 30.6341770),
    ],
  ),
  CampusZone(
    name: 'Ruharo zone',
    tag: 'ruharo',
    points: [
      LatLng(-0.6087281, 30.6290447),
      LatLng(-0.6098653, 30.6316732),
      LatLng(-0.6079878, 30.6333791),
      LatLng(-0.6065288, 30.6300532),
    ],
  ),
];

/// Returns the zone tag (e.g. 'kihumuro_main') if (lat, lng) falls inside
/// any zone polygon, otherwise returns null.
String? zoneTagOf(double? lat, double? lng) {
  if (lat == null || lng == null) return null;
  for (final zone in campusZones) {
    if (_pointInPolygon(lat, lng, zone.points)) return zone.tag;
  }
  return null;
}

/// Returns the zone name if (lat, lng) falls inside any zone polygon,
/// otherwise returns [fallback]. Pass locationText/campus as [fallback].
String zoneLabel(double? lat, double? lng, {String fallback = ''}) {
  if (lat == null || lng == null) return fallback;
  for (final zone in campusZones) {
    if (_pointInPolygon(lat, lng, zone.points)) return zone.name;
  }
  return fallback;
}

/// Returns the approximate centroid of the zone with the given name,
/// or null if the zone is not found.
({double lat, double lng})? zoneCentroid(String zoneName) {
  for (final zone in campusZones) {
    if (zone.name == zoneName) {
      final lat = zone.points.map((p) => p.latitude).reduce((a, b) => a + b) /
          zone.points.length;
      final lng = zone.points.map((p) => p.longitude).reduce((a, b) => a + b) /
          zone.points.length;
      return (lat: lat, lng: lng);
    }
  }
  return null;
}

/// Ray-casting algorithm for point-in-polygon.
bool _pointInPolygon(double lat, double lng, List<LatLng> polygon) {
  bool inside = false;
  int j = polygon.length - 1;
  for (int i = 0; i < polygon.length; j = i++) {
    final xi = polygon[i].longitude, yi = polygon[i].latitude;
    final xj = polygon[j].longitude, yj = polygon[j].latitude;
    if (((yi > lat) != (yj > lat)) &&
        (lng < (xj - xi) * (lat - yi) / (yj - yi) + xi)) {
      inside = !inside;
    }
  }
  return inside;
}

Set<Polygon> buildZonePolygons() {
  return campusZones.asMap().entries.map((entry) {
    final i = entry.key;
    final zone = entry.value;
    // Cycle through a set of teal-ish colours with semi-transparency
    final hue = (180 + i * 24) % 360;
    final fillColor = HSLColor.fromAHSL(0.18, hue.toDouble(), 0.6, 0.45).toColor();
    final strokeColor = HSLColor.fromAHSL(0.85, hue.toDouble(), 0.7, 0.35).toColor();
    return Polygon(
      polygonId: PolygonId(zone.tag),
      points: zone.points,
      fillColor: fillColor,
      strokeColor: strokeColor,
      strokeWidth: 2,
    );
  }).toSet();
}
