import 'package:flutter/material.dart';
import 'main.dart';
import 'productDetails.dart';
import 'inbox.dart';
import 'core/api_client.dart';
import 'core/auth_service.dart';
import 'models/models.dart';
import 'config/campus_zones.dart';

class VendorProfileScreen extends StatefulWidget {
  final String vendorName;
  final String? vendorAvatar;
  final String primaryLocation;
  final int? vendorUserId;
  final bool isOnline;
  final int? listingId;

  const VendorProfileScreen({
    super.key,
    required this.vendorName,
    this.vendorAvatar,
    this.primaryLocation = '',
    this.vendorUserId,
    this.isOnline = false,
    this.listingId,
  });

  @override
  State<VendorProfileScreen> createState() => _VendorProfileScreenState();
}

class _VendorProfileScreenState extends State<VendorProfileScreen> {
  PublicUserProfile? _profile;
  List<ListingCardResponse> _listings = [];
  bool _loadingProfile = false;
  bool _loadingListings = false;
  int? _myUserId;
  String? _myUserName;
  int? _resolvedVendorUserId;

  bool get _isOwnVendorProfile =>
      _myUserId != null &&
      ((_resolvedVendorUserId != null && _myUserId == _resolvedVendorUserId) ||
          (_profile != null && _myUserId == _profile!.id) ||
          (_myUserName != null &&
              _myUserName!.trim().isNotEmpty &&
              _myUserName!.trim().toLowerCase() ==
                  widget.vendorName.trim().toLowerCase()));

  @override
  void initState() {
    super.initState();
    _loadMyUserId();
    _initProfile();
  }

  Future<void> _loadMyUserId() async {
    final id = await authService.getUserId();
    final name = await authService.getUserName();
    if (mounted) {
      setState(() {
        _myUserId = id;
        _myUserName = name;
      });
    }
    await _loadListings();
  }

  Future<void> _initProfile() async {
    int? userId = widget.vendorUserId;
    // If userId wasn't passed directly, resolve it from the listing
    if (userId == null && widget.listingId != null) {
      try {
        final resp = await apiClient.dio.get('/listings/${widget.listingId}');
        final listing = ListingResponse.fromJson(resp.data);
        userId = listing.ownerUserId;
      } catch (_) {}
    }
    if (userId != null) {
      if (mounted) setState(() => _resolvedVendorUserId = userId);
      await _loadProfile(userId);
    }
    await _loadListings();
  }

  Future<void> _loadProfile(int userId) async {
    setState(() => _loadingProfile = true);
    try {
      final resp = await apiClient.dio.get('/users/$userId/public');
      final profile = PublicUserProfile.fromJson(resp.data);
      if (mounted) {
        setState(() {
          _profile = profile;
          _resolvedVendorUserId = profile.id;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingProfile = false);
  }

  Future<void> _loadListings() async {
    if (widget.vendorName.trim().isEmpty && _resolvedVendorUserId == null) return;
    setState(() => _loadingListings = true);
    try {
      // Use nearby feed (MUST campus centre) and filter client-side by ownerFullName,
      // since the search endpoint does full-text on listing *content*, not seller name.
      final resp = await apiClient.dio.get('/listings/nearby', queryParameters: {
        'lat': -0.6089,
        'lng': 30.6570,
        'radiusKm': 10.0,
        'size': 50,
      });
      final page = ListingPage.fromJson(resp.data);
      List<ListingCardResponse> vendorListings;
      if (_resolvedVendorUserId != null) {
        vendorListings = page.items
            .where((item) => item.ownerUserId == _resolvedVendorUserId)
            .take(6)
            .toList();
      } else {
        final name = widget.vendorName.trim().toLowerCase();
        vendorListings = page.items
            .where((item) => item.ownerFullName?.trim().toLowerCase() == name)
            .take(6)
            .toList();
      }

      // If this is my own profile and nearby filter returned nothing, use my listings endpoint.
      if (vendorListings.isEmpty && _isOwnVendorProfile) {
        try {
          final myResp = await apiClient.dio.get(
            '/listings/my',
            queryParameters: {'status': 'ACTIVE'},
          );
          final myListings = (myResp.data['items'] as List? ?? const [])
              .map((e) => ListingResponse.fromJson(e))
              .take(6)
              .map((item) => ListingCardResponse(
                    id: item.id,
                    title: item.title,
                    priceUgx: item.priceUgx,
                    currency: item.currency,
                    categoryCode: item.categoryCode,
                    description: item.description,
                    locationText: item.locationText,
                    campus: item.campus,
                    primaryImageUrl: item.primaryImageUrl,
                    createdAt: item.createdAt,
                    ownerFullName: widget.vendorName,
                    ownerUserId: item.ownerUserId,
                  ))
              .toList();
          vendorListings = myListings;
        } catch (_) {}
      }

      if (mounted) setState(() => _listings = vendorListings);
    } catch (_) {}
    if (mounted) setState(() => _loadingListings = false);
  }

  String _formatMemberSince(DateTime dt) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final campus = zoneLabel(
        null, null,
        fallback: (_profile?.campus?.isNotEmpty == true)
            ? _profile!.campus!
            : widget.primaryLocation,
      );
    final memberSince = _profile != null
        ? _formatMemberSince(_profile!.memberSince)
        : null;
    final activeCount = _profile?.activeListingsCount;

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
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Vendor Profile',
          style: TextStyle(
            color: AppColors.darkGray,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Identity Section
                  Center(
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 60,
                              backgroundColor: AppColors.darkGray,
                              backgroundImage: widget.vendorAvatar != null
                                  ? NetworkImage(widget.vendorAvatar!) as ImageProvider
                                  : null,
                              child: widget.vendorAvatar == null
                                  ? Text(
                                      widget.vendorName.isNotEmpty
                                          ? widget.vendorName[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        color: AppColors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 40,
                                      ),
                                    )
                                  : null,
                            ),
                            if (widget.isOnline)
                              Positioned(
                                bottom: 4,
                                right: 4,
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.white,
                                      width: 3,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.vendorName,
                          style: TextStyle(
                            color: AppColors.darkGray,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Verified Credentials Cards
                  if (_loadingProfile)
                    const SizedBox.shrink()
                  else ...[
                    if (campus.isNotEmpty)
                      _buildCredentialCard(
                        icon: Icons.location_on,
                        title: campus,
                        subtitle: 'Primary Location',
                        isVerified: false,
                      ),
                    if (memberSince != null) ...[
                      const SizedBox(height: 12),
                      _buildCredentialCard(
                        icon: Icons.calendar_today_outlined,
                        title: 'Since $memberSince',
                        subtitle: 'Member Since',
                        isVerified: false,
                      ),
                    ],
                    if (activeCount != null) ...[
                      const SizedBox(height: 12),
                      _buildCredentialCard(
                        icon: Icons.storefront_outlined,
                        title: '$activeCount active listing${activeCount == 1 ? '' : 's'}',
                        subtitle: 'Verified Campus Seller',
                        isVerified: true,
                      ),
                    ],
                  ],
                  const SizedBox(height: 32),
                  // Items for Sale Section
                  Text(
                    'Items for Sale',
                    style: TextStyle(
                      color: AppColors.darkGray,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_loadingListings)
                    const Center(child: CircularProgressIndicator())
                  else if (_listings.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'No active listings',
                          style: TextStyle(color: AppColors.mediumGray),
                        ),
                      ),
                    )
                  else
                    ..._listings.map(
                      (listing) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildListingTile(listing),
                      ),
                    ),
                  const SizedBox(height: 100), // Space for fixed button
                ],
              ),
            ),
          ),
          // Fixed Message Button
          if (!_isOwnVendorProfile && widget.listingId != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final id = widget.listingId;
                    if (id == null) return;
                    try {
                      final resp = await apiClient.dio.post('/conversations', data: {'listingId': id});
                      final conv = ConversationResponse.fromJson(resp.data);
                      if (!context.mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => InboxScreen(
                            conversationId: conv.id,
                            userName: widget.vendorName,
                            isOnline: widget.isOnline,
                          ),
                        ),
                      );
                    } catch (_) {}
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  icon: Icon(
                    Icons.chat_bubble_outline,
                    color: AppColors.white,
                    size: 20,
                  ),
                  label: Text(
                    'Message Vendor',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCredentialCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isVerified,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.lightGray,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: AppColors.mediumGray,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.darkGray,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.mediumGray,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (isVerified)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.teal,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check,
                color: AppColors.white,
                size: 16,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildListingTile(ListingCardResponse listing) {
    return Builder(
      builder: (context) => GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductDetailsScreen(
                listingId: listing.id,
                productTitle: listing.title,
                productDescription: listing.description ?? '',
                price: listing.priceUgx,
                imageUrl: listing.primaryImageUrl,
                vendorName: widget.vendorName,
                vendorLocation: listing.locationText ?? listing.campus ?? widget.primaryLocation,
                vendorAvatar: widget.vendorAvatar,
                ownerUserIdHint: listing.ownerUserId,
                isOwnListingHint: _isOwnVendorProfile,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: listing.primaryImageUrl != null
                    ? Image.network(
                        listing.primaryImageUrl!,
                        width: 70,
                        height: 70,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _imagePlaceholder(),
                      )
                    : _imagePlaceholder(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.title,
                      style: TextStyle(
                        color: AppColors.darkGray,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'UGX ${listing.priceUgx.toString().replaceAllMapped(
                                RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                                (Match m) => '${m[1]},',
                              )}',
                          style: TextStyle(
                            color: AppColors.teal,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'ACTIVE',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: AppColors.lightGray,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(Icons.image_not_supported, color: AppColors.mediumGray, size: 28),
    );
  }
}
