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
  bool _showMap = true;
  ListingCardResponse? _selectedMarkerItem;
  LatLng? _userLocation;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      // Use registered location from profile (collected at sign-up)
      double lat = -0.6089, lng = 30.6570;
      try {
        final profileResp = await apiClient.dio.get('/users/profile');
        final profile = UserProfile.fromJson(profileResp.data);
        final loc = profile.registeredLocation ?? profile.alternateLocation;
        final regLat = loc?.lat;
        final regLng = loc?.lng;
        if (regLat != null && regLng != null) {
          lat = regLat;
          lng = regLng;
          if (mounted) setState(() => _userLocation = LatLng(lat, lng));
        }
      } catch (_) {}

      final resp = await apiClient.dio.get('/listings/nearby', queryParameters: {
        'lat': lat,
        'lng': lng,
        'radiusKm': 50.0,
        if (widget.categoryCode != null) 'categoryCode': widget.categoryCode,
        'page': 0,
        'size': 50,
      });
      final page = ListingPage.fromJson(resp.data);
      if (mounted) setState(() => _listings = page.items);
    } on DioException catch (e) {
      debugPrint('CategoryListings load error: $e');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGray,
      appBar: AppBar(
        leading: IconButton(
          icon: CircleAvatar(
            backgroundColor: AppColors.lightGray,
            child: Icon(
              Icons.arrow_back,
              color: AppColors.darkGray,
            ),
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
          : _listings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inbox_outlined, size: 64, color: AppColors.mediumGray),
                      const SizedBox(height: 16),
                      Text(
                        'No listings in ${widget.categoryName}',
                        style: const TextStyle(color: AppColors.mediumGray),
                      ),
                    ],
                  ),
                )
              : _showMap ? _buildMapView() : RefreshIndicator(
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
                                vendorLocation: zoneLabel(item.lat, item.lng, fallback: item.locationText ?? ''),
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
                                      zoneLabel(item.lat, item.lng, fallback: item.locationText ?? ''),
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.mediumGray),
                                    ),
                                    Text(_timeAgo(item.createdAt),
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.mediumGray)),
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
              onTap: () => setState(() => _selectedMarkerItem = item),
            ))
        .toSet();

    final allMarkers = <Marker>{
      ...listingMarkers,
      if (_userLocation != null)
        Marker(
          markerId: const MarkerId('_user'),
          position: _userLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'You are here'),
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
                '${_listings.length} listing${_listings.length == 1 ? '' : 's'} in ${widget.categoryName}',
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
              vendorLocation: zoneLabel(item.lat, item.lng, fallback: item.locationText ?? ''),
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
                  ? Image.network(item.primaryImageUrl!, width: 64, height: 64, fit: BoxFit.cover)
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
