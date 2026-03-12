import 'dart:ui' as ui;
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

class _ZonePolygonStyle {
  final Color fillColor;
  final Color strokeColor;

  const _ZonePolygonStyle({
    required this.fillColor,
    required this.strokeColor,
  });
}

const Map<String, _ZonePolygonStyle> _zonePolygonStyles = {
  'kihumuro_main': _ZonePolygonStyle(
    fillColor: Color(0x3343A047),
    strokeColor: Color(0xCC2E7D32),
  ),
  'mile_4': _ZonePolygonStyle(
    fillColor: Color(0x33FB8C00),
    strokeColor: Color(0xCCEF6C00),
  ),
  'path_hostel': _ZonePolygonStyle(
    fillColor: Color(0x334285F4),
    strokeColor: Color(0xCC1565C0),
  ),
  'mama_belinda': _ZonePolygonStyle(
    fillColor: Color(0x33E53935),
    strokeColor: Color(0xCCB71C1C),
  ),
  'mile_5': _ZonePolygonStyle(
    fillColor: Color(0x338E24AA),
    strokeColor: Color(0xCC6A1B9A),
  ),
  'mirrors': _ZonePolygonStyle(
    fillColor: Color(0x3300ACC1),
    strokeColor: Color(0xCC00838F),
  ),
  'mile_3_a': _ZonePolygonStyle(
    fillColor: Color(0x33C0CA33),
    strokeColor: Color(0xCC9E9D24),
  ),
  'mile_3_b': _ZonePolygonStyle(
    fillColor: Color(0x338D6E63),
    strokeColor: Color(0xCC5D4037),
  ),
  'kiyanja': _ZonePolygonStyle(
    fillColor: Color(0x33008F7A),
    strokeColor: Color(0xCC00695C),
  ),
  'ruharo': _ZonePolygonStyle(
    fillColor: Color(0x335C6BC0),
    strokeColor: Color(0xCC3949AB),
  ),
};

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

LatLng _topLeftVertex(List<LatLng> points) {
  var minLng = points.first.longitude;
  var maxLng = points.first.longitude;
  var minLat = points.first.latitude;
  var maxLat = points.first.latitude;

  for (final point in points.skip(1)) {
    if (point.longitude < minLng) minLng = point.longitude;
    if (point.longitude > maxLng) maxLng = point.longitude;
    if (point.latitude < minLat) minLat = point.latitude;
    if (point.latitude > maxLat) maxLat = point.latitude;
  }

  final lngRange = (maxLng - minLng).abs();
  final latRange = (maxLat - minLat).abs();

  return points.reduce((best, point) {
    final bestDx = lngRange == 0 ? 0.0 : (best.longitude - minLng) / lngRange;
    final bestDy = latRange == 0 ? 0.0 : (maxLat - best.latitude) / latRange;
    final pointDx = lngRange == 0 ? 0.0 : (point.longitude - minLng) / lngRange;
    final pointDy = latRange == 0 ? 0.0 : (maxLat - point.latitude) / latRange;
    final bestScore = bestDx * bestDx + bestDy * bestDy;
    final pointScore = pointDx * pointDx + pointDy * pointDy;

    if (pointScore < bestScore) return point;
    if (pointScore > bestScore) return best;
    if (point.latitude > best.latitude) return point;
    if (point.latitude < best.latitude) return best;
    if (point.longitude < best.longitude) return point;
    return best;
  });
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

_ZonePolygonStyle _fallbackZonePolygonStyle(String tag) {
  final seed = tag.codeUnits.fold<int>(0, (sum, unit) => sum + unit);
  final hue = (seed * 37) % 360;
  return _ZonePolygonStyle(
    fillColor: HSLColor.fromAHSL(0.18, hue.toDouble(), 0.62, 0.46).toColor(),
    strokeColor: HSLColor.fromAHSL(0.85, hue.toDouble(), 0.72, 0.34).toColor(),
  );
}

Color zoneAccentColor(String tag) {
  final style = _zonePolygonStyles[tag] ?? _fallbackZonePolygonStyle(tag);
  return style.strokeColor;
}

/// Builds a text-label [Marker] for every campus zone, positioned at the
/// zone's first vertex. The label bitmap matches the style of Google Maps'
/// own street labels (white text, dark outline, 12 sp × devicePixelRatio).
Future<Set<Marker>> buildZoneLabelMarkers(double devicePixelRatio) async {
  final markers = <Marker>{};
  for (final zone in campusZones) {
    final icon = await _buildZoneLabelBitmap(zone.name, devicePixelRatio);
    markers.add(Marker(
      markerId: MarkerId('zone_label_${zone.tag}'),
      position: _topLeftVertex(zone.points),
      icon: icon,
      anchor: const Offset(1.0, 1.0),
      zIndex: 1.0,
      consumeTapEvents: false,
    ));
  }
  return markers;
}

Future<BitmapDescriptor> _buildZoneLabelBitmap(
    String text, double px) async {
  // 12 sp matches Google Maps street/district label size.
  final fontSize = 12.0 * px;
  final hPad = 6.0 * px;
  final vPad = 3.0 * px;
  final radius = 4.0 * px;
  final stemRunX = 18.0 * px;
  final stemRunY = 14.0 * px;
  final stemW = 2.5 * px;
  final tipSize = 6.0 * px;
  const bgAlpha = 0.78;
  const bgColor = Color(0xFF000000);

  // Measure text first to size the canvas.
  final textPainter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  final labelW = textPainter.width + hPad * 2;
  final labelH = textPainter.height + vPad * 2;
  // Bitmap: pill sits up-left of the anchored vertex; stem runs down-right to it.
  final totalW = labelW + stemRunX;
  final totalH = labelH + stemRunY;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  final paint = Paint()
    ..color = bgColor.withValues(alpha: bgAlpha)
    ..style = PaintingStyle.fill;

  // Rounded pill in the upper-left, outside the polygon.
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, labelW, labelH),
      Radius.circular(radius),
    ),
    paint,
  );

  // Diagonal stem from the pill's lower-right edge to the anchored vertex.
  final stemPaint = Paint()
    ..color = bgColor.withValues(alpha: bgAlpha)
    ..style = PaintingStyle.stroke
    ..strokeWidth = stemW
    ..strokeCap = StrokeCap.round;
  final stemStart = Offset(labelW - radius, labelH - radius * 0.8);
  final stemEnd = Offset(totalW - tipSize * 0.75, totalH - tipSize * 0.75);
  canvas.drawLine(stemStart, stemEnd, stemPaint);

  // Tip triangle at the bottom-right corner — this exact corner is the anchor.
  final tipPath = Path()
    ..moveTo(totalW, totalH)
    ..lineTo(totalW - tipSize, totalH)
    ..lineTo(totalW, totalH - tipSize)
    ..close();
  canvas.drawPath(tipPath, paint);

  textPainter.paint(canvas, Offset(hPad, vPad));

  final picture = recorder.endRecording();
  final img = await picture.toImage(totalW.ceil(), totalH.ceil());
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
}

Set<Polygon> buildZonePolygons() {
  return campusZones.map((zone) {
    final style = _zonePolygonStyles[zone.tag] ?? _fallbackZonePolygonStyle(zone.tag);
    return Polygon(
      polygonId: PolygonId(zone.tag),
      points: zone.points,
      fillColor: style.fillColor,
      strokeColor: style.strokeColor,
      strokeWidth: 2,
    );
  }).toSet();
}
