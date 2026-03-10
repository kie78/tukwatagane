import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'main.dart';
import 'saved.dart';
import 'productDetails.dart';
import 'widgets/main_nav_bar.dart';
import 'core/api_client.dart';
import 'core/api_exception.dart';
import 'models/models.dart';
import 'config/campus_zones.dart';

class SearchResultsScreen extends StatefulWidget {
  final String searchQuery;

  const SearchResultsScreen({
    super.key,
    required this.searchQuery,
  });

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  List<ListingCardResponse> _listings = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _showMap = false;
  ListingCardResponse? _selectedMarkerItem;
  LatLng? _userLocation;
  Set<Marker> _zoneLabelMarkers = {};

  @override
  void initState() {
    super.initState();
    _loadAndLabel();
    _loadUserLocation();
  }

  Future<void> _loadAndLabel() async {
    await Future.wait([
      _search(),
      _buildZoneLabelMarkers(),
    ]);
  }

  Future<void> _loadUserLocation() async {
    try {
      final resp = await apiClient.dio.get('/users/profile');
      final profile = UserProfile.fromJson(resp.data);
      final loc = profile.registeredLocation ?? profile.alternateLocation;
      if (loc?.lat != null && loc?.lng != null && mounted) {
        setState(() => _userLocation = LatLng(loc!.lat!, loc.lng!));
      }
    } catch (_) {}
  }

  Future<void> _search() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final resp = await apiClient.dio.get('/listings/search', queryParameters: {
        'query': widget.searchQuery,
        'page': 0,
        'size': 20,
      });
      final page = ListingPage.fromJson(resp.data);
      if (mounted) setState(() => _listings = page.items);
    } on DioException catch (e) {
      final ex = ApiException.fromDio(e);
      if (mounted) setState(() => _errorMessage = ex.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Future<BitmapDescriptor> _createZoneLabelBitmap(String label, double pixelRatio) async {
    // All base values are in logical pixels to match Google Maps label size (~12lp)
    final double fontSize = 12.0 * pixelRatio;
    final double paddingH = 8.0 * pixelRatio;
    final double paddingV = 4.0 * pixelRatio;
    final double stemLen = 20.0 * pixelRatio;
    final double dotR = 3.0 * pixelRatio;

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: const Color(0xFFFFFFFF),
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final pillW = textPainter.width + paddingH * 2;
    final pillH = textPainter.height + paddingV * 2;
    final totalH = pillH + stemLen + dotR * 2;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..color = const Color(0xCC263238);

    // Pill
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, pillW, pillH), Radius.circular(6 * pixelRatio)),
      paint,
    );
    // Label
    textPainter.paint(canvas, Offset(paddingH, paddingV));
    // Stem
    canvas.drawLine(
      Offset(pillW / 2, pillH),
      Offset(pillW / 2, pillH + stemLen),
      Paint()
        ..color = const Color(0xCC263238)
        ..strokeWidth = 1.5 * pixelRatio
        ..strokeCap = StrokeCap.round,
    );
    // Anchor dot
    canvas.drawCircle(Offset(pillW / 2, pillH + stemLen + dotR), dotR, paint);

    final picture = recorder.endRecording();
    final img = await picture.toImage(pillW.ceil(), totalH.ceil());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  Future<void> _buildZoneLabelMarkers() async {
    final pixelRatio = WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    final markers = <Marker>{};
    for (final zone in campusZones) {
      // Anchor at the topmost vertex (highest on screen = max latitude)
      final topVertex = zone.points
          .reduce((a, b) => a.latitude > b.latitude ? a : b);
      final shortName = zone.name
          .replaceAllMapped(
            RegExp(r'\s+[Zz]one(\s+[A-Z])?\b'),
            (m) => m.group(1) ?? '',
          )
          .trim();
      final icon = await _createZoneLabelBitmap(shortName, pixelRatio);
      markers.add(Marker(
        markerId: MarkerId('zone_label_${zone.tag}'),
        position: topVertex,
        icon: icon,
        flat: false,
        anchor: const Offset(0.5, 1.0),
        consumeTapEvents: false,
        zIndex: 0.5,
      ));
    }
    if (mounted) setState(() => _zoneLabelMarkers = markers);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGray,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: AppColors.darkGray,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Search Results',
          style: TextStyle(
            color: AppColors.darkGray,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.bookmark_border,
              color: AppColors.mediumGray,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SavedScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
              : _listings.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.search_off, size: 64, color: AppColors.mediumGray),
                          const SizedBox(height: 16),
                          Text(
                            'No results for "${widget.searchQuery}"',
                            style: const TextStyle(color: AppColors.mediumGray),
                          ),
                        ],
                      ),
                    )
                  : _showMap ? _buildMapView() : RefreshIndicator(
                      onRefresh: _search,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _listings.length,
                        itemBuilder: (context, index) {
                          final item = _listings[index];
                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProductDetailsScreen(
                                    listingId: item.id,
                                    productTitle: item.title,
                                    productDescription: item.description ?? '',
                                    price: item.priceUgx,
                                    imageUrl: item.primaryImageUrl,
                                    vendorName: item.ownerFullName ?? '',
                                    vendorLocation: zoneLabel(item.lat, item.lng, fallback: item.campus ?? item.locationText ?? ''),
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: item.primaryImageUrl != null
                                        ? Image.network(
                                            item.primaryImageUrl!,
                                            width: 80,
                                            height: 80,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => Container(
                                              width: 80,
                                              height: 80,
                                              color: AppColors.lightGray,
                                              child: const Icon(
                                                Icons.image_not_supported_outlined,
                                                color: AppColors.mediumGray,
                                                size: 28,
                                              ),
                                            ),
                                          )
                                        : Container(
                                            width: 80,
                                            height: 80,
                                            color: AppColors.lightGray,
                                            child: const Icon(
                                              Icons.image_not_supported_outlined,
                                              color: AppColors.mediumGray,
                                              size: 28,
                                            ),
                                          ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item.title,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.darkGray)),
                                        const SizedBox(height: 4),
                                        Text('UGX ${item.priceUgx}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.darkGray)),
                                        const SizedBox(height: 4),
                                        Text(
                                          zoneLabel(item.lat, item.lng, fallback: item.campus ?? item.locationText ?? ''),
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.mediumGray),
                                        ),
                                        Text(
                                          _timeAgo(item.createdAt),
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.mediumGray),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
      floatingActionButton: !_isLoading && _errorMessage == null && _listings.isNotEmpty
          ? _buildTogglePill()
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: const MainNavBar(currentIndex: 1),
    );
  }

  Widget _buildTogglePill() {
    return GestureDetector(
      onTap: () => setState(() {
        _showMap = !_showMap;
        _selectedMarkerItem = null;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.darkGray,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _showMap ? Icons.list : Icons.map_outlined,
              color: AppColors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              _showMap ? 'List View' : 'Map View',
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _campusCenter = LatLng(-0.6089, 30.6570);

  Widget _buildMapView() {
    final listingMarkers = _listings
        .where((item) => item.lat != null && item.lng != null)
        .map((item) => Marker(
              markerId: MarkerId(item.id.toString()),
              position: LatLng(item.lat!, item.lng!),
              zIndex: 1.5,
              onTap: () => setState(() => _selectedMarkerItem = item),
            ))
        .toSet();

    final allMarkers = <Marker>{
      ...listingMarkers,
      ..._zoneLabelMarkers,
      if (_userLocation != null)
        Marker(
          markerId: const MarkerId('_user'),
          position: _userLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'You are here'),
          zIndex: 2.0,
        ),
    };

    final cameraTarget = _userLocation ?? _campusCenter;

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: cameraTarget,
            zoom: 15.5,
          ),
          markers: allMarkers,
          polygons: buildZonePolygons(),
          myLocationButtonEnabled: false,
          zoomControlsEnabled: true,
          onTap: (_) => setState(() => _selectedMarkerItem = null),
        ),
        Positioned(
          top: 8,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_listings.length} listing${_listings.length == 1 ? '' : 's'} near MUST campus',
                style: const TextStyle(fontSize: 12, color: AppColors.mediumGray),
              ),
            ),
          ),
        ),
        if (_selectedMarkerItem != null)
          Positioned(
            bottom: 80,
            left: 16,
            right: 16,
            child: _buildMarkerCard(_selectedMarkerItem!),
          ),
      ],
    );
  }

  Widget _buildMarkerCard(ListingCardResponse item) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailsScreen(
              listingId: item.id,
              productTitle: item.title,
              productDescription: item.description ?? '',
              price: item.priceUgx,
              imageUrl: item.primaryImageUrl,
              vendorName: item.ownerFullName ?? '',
              vendorLocation: zoneLabel(item.lat, item.lng, fallback: item.campus ?? item.locationText ?? ''),
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: item.primaryImageUrl != null
                  ? Image.network(
                      item.primaryImageUrl!,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 64,
                        height: 64,
                        color: AppColors.lightGray,
                        child: const Icon(Icons.image_not_supported_outlined, color: AppColors.mediumGray),
                      ),
                    )
                  : Container(
                      width: 64,
                      height: 64,
                      color: AppColors.lightGray,
                      child: const Icon(Icons.image_not_supported_outlined, color: AppColors.mediumGray),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.darkGray),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'UGX ${item.priceUgx}',
                    style: const TextStyle(color: AppColors.darkGray, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.mediumGray),
          ],
        ),
      ),
    );
  }
}
