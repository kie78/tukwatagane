import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'main.dart';
import 'saved.dart';
import 'productDetails.dart';
import 'widgets/main_nav_bar.dart';
import 'core/api_client.dart';
import 'models/models.dart';
import 'config/campus_zones.dart';

class CategoryListingsScreen extends StatefulWidget {
  final String categoryName;
  final String? categoryCode;
  final bool hasListings;

  const CategoryListingsScreen({
    super.key,
    required this.categoryName,
    this.categoryCode,
    this.hasListings = false,
  });

  @override
  State<CategoryListingsScreen> createState() => _CategoryListingsScreenState();
}

class _CategoryListingsScreenState extends State<CategoryListingsScreen> {
  List<ListingCardResponse> _listings = [];
  bool _isLoading = true;
  bool _showMap = false;
  Map<String, List<ListingCardResponse>> _zoneListings = {};
  String? _selectedZoneTag;
  Set<Marker> _zonePinMarkers = {};
  int _currentCardPage = 0;
  late final PageController _cardPageCtrl = PageController();
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _cardPageCtrl.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final feedOrigin = await _resolveFeedOrigin();
      final items = await _loadCategoryListings(feedOrigin);
      if (mounted) setState(() => _listings = items);
      await _rebuildZonePins();
    } on DioException catch (e) {
      debugPrint('CategoryListings load error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<LatLng> _resolveFeedOrigin() async {
    try {
      final profileResp = await apiClient.dio.get('/users/profile');
      final profile = UserProfile.fromJson(profileResp.data);
      final loc = profile.registeredLocation ?? profile.alternateLocation;
      if (loc?.lat != null && loc?.lng != null) {
        return LatLng(loc!.lat!, loc.lng!);
      }
    } catch (_) {}
    return _campusCenter;
  }

  Future<List<ListingCardResponse>> _loadCategoryListings(LatLng origin) async {
    const pageSize = 100;
    final matches = <ListingCardResponse>[];
    var pageIndex = 0;
    var total = pageSize;

    while (pageIndex * pageSize < total) {
      final resp = await apiClient.dio.get(
        '/listings/feed',
        queryParameters: {
          'lat': origin.latitude,
          'lng': origin.longitude,
          'page': pageIndex,
          'size': pageSize,
        },
      );
      final page = ListingPage.fromJson(resp.data);
      total = page.total;

      matches.addAll(
        page.items.where(
          (item) =>
              widget.categoryCode == null ||
              item.categoryCode == widget.categoryCode,
        ),
      );

      if (page.items.isEmpty) break;
      pageIndex++;
    }

    return matches;
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  /// Groups listings by campus zone. Uses locationText (the zone name saved
  /// at post time) as primary key, falling back to coordinate-based lookup.
  Map<String, List<ListingCardResponse>> _groupIntoZones(
    List<ListingCardResponse> listings,
  ) {
    final map = <String, List<ListingCardResponse>>{};
    for (final item in listings) {
      String? tag;
      if (item.locationText != null && item.locationText!.isNotEmpty) {
        for (final zone in campusZones) {
          if (zone.name == item.locationText) {
            tag = zone.tag;
            break;
          }
        }
      }
      tag ??= zoneTagOf(item.lat, item.lng);
      if (tag != null) map.putIfAbsent(tag, () => []).add(item);
    }
    return map;
  }

  Future<void> _rebuildZonePins() async {
    if (!mounted) return;
    final zoneMap = _groupIntoZones(_listings);
    if (mounted) setState(() => _zoneListings = zoneMap);
    final px =
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    final markers = <Marker>{};
    for (final entry in zoneMap.entries) {
      final tag = entry.key;
      final items = entry.value;
      final zone = campusZones.firstWhere(
        (z) => z.tag == tag,
        orElse: () => campusZones.first,
      );
      final centroid = LatLng(
        zone.points.map((p) => p.latitude).reduce((a, b) => a + b) /
            zone.points.length,
        zone.points.map((p) => p.longitude).reduce((a, b) => a + b) /
            zone.points.length,
      );
      final icon = await _buildListingPinBitmap(items.length, px);
      markers.add(
        Marker(
          markerId: MarkerId('zone_pin_$tag'),
          position: centroid,
          icon: icon,
          zIndex: 2.0,
          anchor: const Offset(0.5, 1.0),
          onTap: () => _focusZone(tag),
        ),
      );
    }
    markers.addAll(await buildZoneLabelMarkers(px));
    if (mounted) setState(() => _zonePinMarkers = markers);
    _fitCameraToZones();
  }

  void _fitCameraToZones() {
    if (_mapController == null || _zoneListings.isEmpty) return;
    final centroids = _zoneListings.keys.map((tag) {
      final zone = campusZones.firstWhere(
        (z) => z.tag == tag,
        orElse: () => campusZones.first,
      );
      return LatLng(
        zone.points.map((p) => p.latitude).reduce((a, b) => a + b) /
            zone.points.length,
        zone.points.map((p) => p.longitude).reduce((a, b) => a + b) /
            zone.points.length,
      );
    }).toList();
    if (centroids.isEmpty) return;
    if (centroids.length == 1) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(centroids.first, 16.0),
      );
      return;
    }
    final bounds = centroids.fold<LatLngBounds?>(
      null,
      (acc, p) => acc == null
          ? LatLngBounds(southwest: p, northeast: p)
          : LatLngBounds(
              southwest: LatLng(
                p.latitude < acc.southwest.latitude
                    ? p.latitude
                    : acc.southwest.latitude,
                p.longitude < acc.southwest.longitude
                    ? p.longitude
                    : acc.southwest.longitude,
              ),
              northeast: LatLng(
                p.latitude > acc.northeast.latitude
                    ? p.latitude
                    : acc.northeast.latitude,
                p.longitude > acc.northeast.longitude
                    ? p.longitude
                    : acc.northeast.longitude,
              ),
            ),
    )!;
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  Future<BitmapDescriptor> _buildListingPinBitmap(int count, double px) async {
    final w = 44.0 * px;
    final bodyH = 44.0 * px;
    final stemH = 12.0 * px;
    final totalH = bodyH + stemH;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const orange = Color(0xFFFF6B35);

    // Shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(px, px, w - 2 * px, bodyH - px),
        Radius.circular(10 * px),
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.22)
        ..maskFilter = ui.MaskFilter.blur(ui.BlurStyle.normal, 4 * px),
    );
    // Pin body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, w, bodyH),
        Radius.circular(10 * px),
      ),
      Paint()..color = orange,
    );
    // Stem triangle
    final stemPath = Path()
      ..moveTo(w * 0.35, bodyH - px)
      ..lineTo(w * 0.5, totalH)
      ..lineTo(w * 0.65, bodyH - px)
      ..close();
    canvas.drawPath(stemPath, Paint()..color = orange);

    // Price-tag icon
    final iconSize = 22.0 * px;
    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.local_offer.codePoint),
        style: TextStyle(
          fontFamily: Icons.local_offer.fontFamily,
          package: Icons.local_offer.fontPackage,
          color: Colors.white,
          fontSize: iconSize,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    iconPainter.layout();
    iconPainter.paint(
      canvas,
      Offset((w - iconPainter.width) / 2, (bodyH - iconPainter.height) / 2),
    );

    // Count badge (shown when zone has more than one listing)
    if (count > 1) {
      final badgeR = 9.0 * px;
      final badgeX = w - badgeR - 1.5 * px;
      final badgeY = badgeR + 1.5 * px;
      canvas.drawCircle(
        Offset(badgeX, badgeY),
        badgeR,
        Paint()..color = Colors.white,
      );
      final countPainter = TextPainter(
        text: TextSpan(
          text: count > 9 ? '9+' : count.toString(),
          style: TextStyle(
            color: orange,
            fontSize: 8.5 * px,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      countPainter.layout();
      countPainter.paint(
        canvas,
        Offset(
          badgeX - countPainter.width / 2,
          badgeY - countPainter.height / 2,
        ),
      );
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(w.ceil(), totalH.ceil());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGray,
      appBar: AppBar(
        leading: IconButton(
          icon: CircleAvatar(
            backgroundColor: AppColors.lightGray,
            child: Icon(Icons.arrow_back, color: AppColors.darkGray),
          ),
          onPressed: () {
            Navigator.pushReplacementNamed(context, '/search');
          },
        ),
        title: Text(
          widget.categoryName,
          style: TextStyle(
            color: AppColors.darkGray,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.bookmark_border,
              color: AppColors.mediumGray,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SavedScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _listings.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.inbox_outlined,
                    size: 64,
                    color: AppColors.mediumGray,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No listings in ${widget.categoryName}',
                    style: const TextStyle(color: AppColors.mediumGray),
                  ),
                ],
              ),
            )
          : _showMap
          ? _buildMapView()
          : RefreshIndicator(
              onRefresh: _load,
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
                            vendorLocation: zoneLabel(
                              item.lat,
                              item.lng,
                              fallback: item.locationText ?? '',
                            ),
                            vendorAvatar: item.ownerAvatarUrl,
                            ownerUserIdHint: item.ownerUserId,
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
                                Text(
                                  item.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.darkGray,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'UGX ${item.priceUgx}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.darkGray,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  zoneLabel(
                                    item.lat,
                                    item.lng,
                                    fallback: item.locationText ?? '',
                                  ),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.mediumGray,
                                  ),
                                ),
                                Text(
                                  _timeAgo(item.createdAt),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.mediumGray,
                                  ),
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
      floatingActionButton: !_isLoading && _listings.isNotEmpty
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
        _selectedZoneTag = null;
        _currentCardPage = 0;
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
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: const CameraPosition(
            target: _campusCenter,
            zoom: 15.5,
          ),
          markers: _zonePinMarkers,
          polygons: buildZonePolygons(),
          myLocationButtonEnabled: false,
          zoomControlsEnabled: true,
          onMapCreated: (c) {
            _mapController = c;
            _fitCameraToZones();
          },
          onTap: (_) => setState(() => _selectedZoneTag = null),
        ),
        Positioned(
          top: 8,
          left: 0,
          right: 0,
          child: Center(
            child: GestureDetector(
              onTap: _showZoneSummaryModal,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${_listings.length} listing${_listings.length == 1 ? '' : 's'} in ${widget.categoryName}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.mediumGray,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.expand_more,
                      size: 16,
                      color: AppColors.mediumGray,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_selectedZoneTag != null) _buildZoneCarousel(),
      ],
    );
  }

  String _zoneNameForTag(String tag) {
    return campusZones
        .firstWhere((zone) => zone.tag == tag, orElse: () => campusZones.first)
        .name;
  }

  List<MapEntry<String, List<ListingCardResponse>>> _sortedZoneListings() {
    final entries = _zoneListings.entries
        .where((entry) => entry.value.isNotEmpty)
        .toList();
    entries.sort((a, b) {
      final countCompare = b.value.length.compareTo(a.value.length);
      if (countCompare != 0) return countCompare;
      return _zoneNameForTag(a.key).compareTo(_zoneNameForTag(b.key));
    });
    return entries;
  }

  LatLngBounds _zoneBounds(String tag) {
    final zone = campusZones.firstWhere(
      (zone) => zone.tag == tag,
      orElse: () => campusZones.first,
    );

    return zone.points.fold<LatLngBounds>(
      LatLngBounds(southwest: zone.points.first, northeast: zone.points.first),
      (bounds, point) => LatLngBounds(
        southwest: LatLng(
          point.latitude < bounds.southwest.latitude
              ? point.latitude
              : bounds.southwest.latitude,
          point.longitude < bounds.southwest.longitude
              ? point.longitude
              : bounds.southwest.longitude,
        ),
        northeast: LatLng(
          point.latitude > bounds.northeast.latitude
              ? point.latitude
              : bounds.northeast.latitude,
          point.longitude > bounds.northeast.longitude
              ? point.longitude
              : bounds.northeast.longitude,
        ),
      ),
    );
  }

  Future<void> _focusZone(String tag) async {
    setState(() {
      _selectedZoneTag = tag;
      _currentCardPage = 0;
    });
    if (_cardPageCtrl.hasClients) {
      _cardPageCtrl.jumpToPage(0);
    }

    if (_mapController == null) return;

    final bounds = _zoneBounds(tag);
    final latSpan = (bounds.northeast.latitude - bounds.southwest.latitude)
        .abs();
    final lngSpan = (bounds.northeast.longitude - bounds.southwest.longitude)
        .abs();

    if (latSpan < 0.0003 && lngSpan < 0.0003) {
      final center = LatLng(
        (bounds.northeast.latitude + bounds.southwest.latitude) / 2,
        (bounds.northeast.longitude + bounds.southwest.longitude) / 2,
      );
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(center, 17.0),
      );
      return;
    }

    await _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 88),
    );
  }

  Future<void> _showZoneSummaryModal() async {
    final zoneEntries = _sortedZoneListings();
    if (zoneEntries.isEmpty) return;

    final visibleRows = zoneEntries.length < 4 ? zoneEntries.length : 4;
    const rowHeight = 56.0;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.16),
      builder: (dialogContext) {
        return SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 56, 16, 0),
              child: Material(
                color: Colors.transparent,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 420),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      decoration: BoxDecoration(
                        color: AppColors.white.withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.white.withValues(alpha: 0.42),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'By location',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.darkGray,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.of(dialogContext).pop(),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.white.withValues(
                                      alpha: 0.56,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.all(6),
                                  child: const Icon(
                                    Icons.close,
                                    size: 16,
                                    color: AppColors.mediumGray,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: rowHeight * visibleRows,
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: zoneEntries.length > 4
                                  ? const ClampingScrollPhysics()
                                  : const NeverScrollableScrollPhysics(),
                              itemCount: zoneEntries.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final entry = zoneEntries[index];
                                final listingCount = entry.value.length;
                                return GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    Navigator.of(dialogContext).pop();
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          if (mounted) {
                                            _focusZone(entry.key);
                                          }
                                        });
                                  },
                                  child: SizedBox(
                                    height: rowHeight,
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: zoneAccentColor(entry.key),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            _zoneNameForTag(entry.key),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.darkGray,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          '$listingCount',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.darkGray,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          listingCount == 1
                                              ? 'listing'
                                              : 'listings',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.mediumGray,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMarkerCard(ListingCardResponse item) {
    final sellerName = item.ownerFullName?.trim().isNotEmpty == true
        ? item.ownerFullName!.trim()
        : 'Seller';
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
              vendorLocation: zoneLabel(
                item.lat,
                item.lng,
                fallback: item.locationText ?? '',
              ),
              vendorAvatar: item.ownerAvatarUrl,
              ownerUserIdHint: item.ownerUserId,
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: item.primaryImageUrl != null
                  ? Image.network(
                      item.primaryImageUrl!,
                      width: 88,
                      height: 88,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 88,
                      height: 88,
                      color: AppColors.lightGray,
                      child: const Icon(
                        Icons.image_not_supported_outlined,
                        color: AppColors.mediumGray,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 88,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkGray,
                            fontSize: 16,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          sellerName,
                          style: const TextStyle(
                            color: AppColors.mediumGray,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'UGX ${item.priceUgx.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                            style: const TextStyle(
                              color: AppColors.darkGray,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _timeAgo(item.createdAt),
                          style: const TextStyle(
                            color: AppColors.mediumGray,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right,
                          color: AppColors.mediumGray,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoneCarousel() {
    final items = _zoneListings[_selectedZoneTag!] ?? [];
    if (items.isEmpty) return const SizedBox.shrink();
    final zoneName = campusZones
        .firstWhere(
          (z) => z.tag == _selectedZoneTag!,
          orElse: () => campusZones.first,
        )
        .name;
    return Positioned(
      bottom: 80,
      left: 12,
      right: 12,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.darkGray,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$zoneName · ${items.length} listing${items.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _selectedZoneTag = null),
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.darkGray,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(5),
                  child: const Icon(
                    Icons.close,
                    color: AppColors.white,
                    size: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 124,
            child: PageView.builder(
              controller: _cardPageCtrl,
              itemCount: items.length,
              onPageChanged: (i) => setState(() => _currentCardPage = i),
              itemBuilder: (_, i) => _buildMarkerCard(items[i]),
            ),
          ),
          if (items.length > 1) _buildPageDots(items.length),
        ],
      ),
    );
  }

  Widget _buildPageDots(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        count,
        (i) => AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
          width: i == _currentCardPage ? 16.0 : 6.0,
          height: 6.0,
          decoration: BoxDecoration(
            color: i == _currentCardPage
                ? AppColors.darkGray
                : AppColors.mediumGray,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }
}
