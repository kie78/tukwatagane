import 'package:flutter/material.dart';
import 'main.dart';
import 'productDetails.dart';
import 'inbox.dart';
import 'core/api_client.dart';
import 'core/auth_service.dart';
import 'core/conversation_service.dart';
import 'core/public_profile_cache.dart';
import 'core/ui/app_toast.dart';
import 'widgets/skeletons.dart';
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
  int _listingsRequestEpoch = 0;
  int? _myUserId;
  String? _myUserName;
  int? _resolvedVendorUserId;
  String _resolvedPrimaryLocation = '';

  String get _displayVendorName {
    final profileName = _profile?.fullName.trim();
    if (profileName != null && profileName.isNotEmpty) return profileName;
    return widget.vendorName;
  }

  String? get _resolvedVendorAvatarUrl {
    final profileAvatar = _profile?.avatarUrl?.trim();
    if (profileAvatar != null && profileAvatar.isNotEmpty) return profileAvatar;
    final fallbackAvatar = widget.vendorAvatar?.trim();
    if (fallbackAvatar != null && fallbackAvatar.isNotEmpty) {
      return fallbackAvatar;
    }
    return null;
  }

  bool get _isOwnVendorProfile =>
      _myUserId != null &&
      ((_resolvedVendorUserId != null && _myUserId == _resolvedVendorUserId) ||
          (_profile != null && _myUserId == _profile!.id) ||
          (_myUserName != null &&
              _myUserName!.trim().isNotEmpty &&
              _displayVendorName.trim().isNotEmpty &&
              _myUserName!.trim().toLowerCase() ==
                  _displayVendorName.trim().toLowerCase()));

  bool _isGenericLocationLabel(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'main' ||
        normalized == 'must main' ||
        normalized == 'main campus' ||
        normalized == 'campus main' ||
        normalized.contains('dummy text location');
  }

  String _pickBestLocationLabel(Iterable<String?> candidates) {
    String? fallback;
    for (final raw in candidates) {
      final value = raw?.trim() ?? '';
      if (value.isEmpty) continue;
      fallback ??= value;
      if (!_isGenericLocationLabel(value)) return value;
    }
    return fallback ?? '';
  }

  String _locationFromListings(List<ListingCardResponse> listings) {
    final candidates = <String?>[];
    for (final listing in listings) {
      candidates.add(listing.locationText);
      candidates.add(listing.campus);
    }
    return _pickBestLocationLabel(candidates);
  }

  bool _isListingOwnedByTargetSeller(
    ListingCardResponse item, {
    required int? targetOwnerUserId,
    required String sellerNameLower,
  }) {
    final ownerId = item.ownerUserId;
    final ownerName = item.ownerFullName?.trim().toLowerCase();

    if (targetOwnerUserId != null) {
      if (ownerId != null) {
        return ownerId == targetOwnerUserId;
      }
      return sellerNameLower.isNotEmpty &&
          ownerName != null &&
          ownerName == sellerNameLower;
    }

    return sellerNameLower.isNotEmpty &&
        ownerName != null &&
        ownerName == sellerNameLower;
  }

  Future<List<ListingCardResponse>> _searchActiveListingsForSeller({
    required String sellerQuery,
    required String sellerNameLower,
    required int? targetOwnerUserId,
  }) async {
    if (sellerQuery.trim().isEmpty) return const [];

    const pageSize = 100;
    var pageIndex = 0;
    var total = pageSize;
    final results = <ListingCardResponse>[];
    final seenIds = <int>{};

    while (pageIndex * pageSize < total) {
      final resp = await apiClient.dio.get(
        '/listings/search',
        queryParameters: {
          'query': sellerQuery,
          'page': pageIndex,
          'size': pageSize,
        },
      );
      final page = ListingPage.fromJson(resp.data);
      total = page.total;

      for (final item in page.items) {
        final isTargetSeller = _isListingOwnedByTargetSeller(
          item,
          targetOwnerUserId: targetOwnerUserId,
          sellerNameLower: sellerNameLower,
        );
        if (!isTargetSeller) continue;
        if (seenIds.add(item.id)) {
          results.add(item);
        }
      }

      if (page.items.isEmpty) break;
      pageIndex++;
    }

    return results;
  }

  @override
  void initState() {
    super.initState();
    _resolvedPrimaryLocation = widget.primaryLocation.trim();
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
    if (widget.listingId != null) {
      try {
        final resp = await apiClient.dio.get('/listings/${widget.listingId}');
        final listing = ListingResponse.fromJson(resp.data);
        userId ??= listing.ownerUserId;
        final listingLocation = _pickBestLocationLabel([
          listing.locationText,
          listing.campus,
          _resolvedPrimaryLocation,
        ]);
        if (listingLocation.isNotEmpty && mounted) {
          setState(() => _resolvedPrimaryLocation = listingLocation);
        }
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
    final profile = await publicProfileCache.resolvePublicProfile(userId);
    if (profile != null && mounted) {
      setState(() {
        _profile = profile;
        _resolvedVendorUserId = profile.id;
      });
    }
    if (mounted) setState(() => _loadingProfile = false);
  }

  Future<void> _loadListings() async {
    if (_displayVendorName.trim().isEmpty &&
        _resolvedVendorUserId == null &&
        widget.listingId == null) {
      return;
    }

    final requestEpoch = ++_listingsRequestEpoch;
    setState(() => _loadingListings = true);

    try {
      int? targetOwnerUserId = _resolvedVendorUserId;
      ListingCardResponse? currentListingCard;
      var resolvedPrimaryLocation = _resolvedPrimaryLocation;

      if (widget.listingId != null) {
        try {
          final currentResp = await apiClient.dio.get(
            '/listings/${widget.listingId}',
          );
          final currentListing = ListingResponse.fromJson(currentResp.data);
          targetOwnerUserId ??= currentListing.ownerUserId;
          final currentListingLocation = _pickBestLocationLabel([
            currentListing.locationText,
            currentListing.campus,
            resolvedPrimaryLocation,
          ]);
          if (currentListingLocation.isNotEmpty) {
            resolvedPrimaryLocation = currentListingLocation;
          }
          if (currentListing.status == ListingStatus.ACTIVE) {
            currentListingCard = ListingCardResponse(
              id: currentListing.id,
              title: currentListing.title,
              priceUgx: currentListing.priceUgx,
              currency: currentListing.currency,
              categoryCode: currentListing.categoryCode,
              description: currentListing.description,
              locationText: currentListing.locationText,
              campus: currentListing.campus,
              primaryImageUrl: currentListing.primaryImageUrl,
              createdAt: currentListing.createdAt,
              ownerFullName: _displayVendorName,
              ownerUserId: currentListing.ownerUserId,
            );
          }
        } catch (_) {}
      }

      double lat = -0.6089;
      double lng = 30.6570;
      try {
        final profileResp = await apiClient.dio.get('/users/profile');
        final profile = UserProfile.fromJson(profileResp.data);
        final loc = profile.registeredLocation ?? profile.alternateLocation;
        final resolvedLat = loc?.lat;
        final resolvedLng = loc?.lng;
        if (resolvedLat != null && resolvedLng != null) {
          lat = resolvedLat;
          lng = resolvedLng;
        }

        final ownRegisteredLocation = _pickBestLocationLabel([
          profile.registeredLocation?.label,
          profile.alternateLocation?.label,
        ]);
        final isOwnProfileView =
            (targetOwnerUserId != null && targetOwnerUserId == profile.id) ||
            (widget.vendorUserId != null &&
                widget.vendorUserId == profile.id) ||
            (_displayVendorName.trim().isNotEmpty &&
                profile.fullName.trim().isNotEmpty &&
                _displayVendorName.trim().toLowerCase() ==
                    profile.fullName.trim().toLowerCase());
        if (isOwnProfileView && ownRegisteredLocation.isNotEmpty) {
          resolvedPrimaryLocation = ownRegisteredLocation;
        }
      } catch (_) {}

      List<ListingCardResponse> vendorListings = [];
      final seenIds = <int>{};
      final targetName = _displayVendorName.trim().toLowerCase();
      final targetQueryName = _displayVendorName.trim();
      const pageSize = 100;
      var pageIndex = 0;
      var total = pageSize;

      while (pageIndex * pageSize < total) {
        final resp = await apiClient.dio.get(
          '/listings/feed',
          queryParameters: {
            'lat': lat,
            'lng': lng,
            'page': pageIndex,
            'size': pageSize,
          },
        );
        final page = ListingPage.fromJson(resp.data);
        total = page.total;

        for (final item in page.items) {
          final isTargetSeller = _isListingOwnedByTargetSeller(
            item,
            targetOwnerUserId: targetOwnerUserId,
            sellerNameLower: targetName,
          );
          if (!isTargetSeller) continue;
          if (seenIds.add(item.id)) {
            vendorListings.add(item);
          }
        }

        if (page.items.isEmpty) {
          break;
        }
        pageIndex++;
      }

      if (currentListingCard != null && seenIds.add(currentListingCard.id)) {
        vendorListings.insert(0, currentListingCard);
      }

      // Backfill from full-text search when feed payload is missing owner IDs
      // and the seller has more active listings than we currently resolved.
      final expectedActiveCount = _profile?.activeListingsCount;
      final shouldBackfillFromSearch =
          targetQueryName.isNotEmpty &&
          (vendorListings.length <= 1 ||
              (expectedActiveCount != null &&
                  vendorListings.length < expectedActiveCount));

      if (shouldBackfillFromSearch) {
        try {
          final searchResults = await _searchActiveListingsForSeller(
            sellerQuery: targetQueryName,
            sellerNameLower: targetName,
            targetOwnerUserId: targetOwnerUserId,
          );
          for (final item in searchResults) {
            if (seenIds.add(item.id)) {
              vendorListings.add(item);
            }
          }
        } catch (_) {}
      }

      final listingLocationLabel = _locationFromListings(vendorListings);
      if (listingLocationLabel.isNotEmpty &&
          (resolvedPrimaryLocation.isEmpty ||
              _isGenericLocationLabel(resolvedPrimaryLocation))) {
        resolvedPrimaryLocation = listingLocationLabel;
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
              .map(
                (item) => ListingCardResponse(
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
                  ownerFullName: _displayVendorName,
                  ownerUserId: item.ownerUserId,
                ),
              )
              .toList();
          vendorListings = myListings;
        } catch (_) {}
      }

      if (!mounted || requestEpoch != _listingsRequestEpoch) {
        return;
      }

      setState(() {
        if (targetOwnerUserId != null) {
          _resolvedVendorUserId = targetOwnerUserId;
        }
        if (resolvedPrimaryLocation.isNotEmpty) {
          _resolvedPrimaryLocation = resolvedPrimaryLocation;
        }
        _listings = vendorListings;
        _loadingListings = false;
      });
    } catch (_) {
      if (mounted && requestEpoch == _listingsRequestEpoch) {
        setState(() {
          _loadingListings = false;
        });
      }
    }
  }

  String _formatMemberSince(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final vendorAvatarUrl = _resolvedVendorAvatarUrl;

    final primaryLocation = _pickBestLocationLabel([
      _resolvedPrimaryLocation,
      _profile?.campus,
      widget.primaryLocation,
    ]);
    final campus = zoneLabel(null, null, fallback: primaryLocation);
    final memberSince = _profile != null
        ? _formatMemberSince(_profile!.memberSince)
        : null;
    final activeCount = _profile?.activeListingsCount;

    return Scaffold(
      backgroundColor: AppColors.of(context).lightGray,
      appBar: AppBar(
        leading: IconButton(
          icon: CircleAvatar(
            backgroundColor: AppColors.of(context).lightGray,
            child: Icon(
              Icons.arrow_back,
              color: AppColors.of(context).darkGray,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Vendor Profile',
          style: TextStyle(
            color: AppColors.of(context).darkGray,
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
                              backgroundColor: AppColors.of(context).darkGray,
                              backgroundImage: vendorAvatarUrl != null
                                  ? NetworkImage(vendorAvatarUrl)
                                        as ImageProvider
                                  : null,
                              child: vendorAvatarUrl == null
                                  ? Text(
                                      widget.vendorName.isNotEmpty
                                          ? widget.vendorName[0].toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                        color: AppColors.of(context).white,
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
                                      color: AppColors.of(context).white,
                                      width: 3,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _displayVendorName,
                          style: TextStyle(
                            color: AppColors.of(context).darkGray,
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
                        title:
                            '$activeCount active listing${activeCount == 1 ? '' : 's'}',
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
                      color: AppColors.of(context).darkGray,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_loadingListings)
                    SkeletonShimmer(
                      child: Column(
                        children: List.generate(
                          3,
                          (_) => const VendorListingTileSkeleton(),
                        ),
                      ),
                    )
                  else if (_listings.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'No active listings',
                          style: TextStyle(
                            color: AppColors.of(context).mediumGray,
                          ),
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
              child: SafeArea(
                minimum: const EdgeInsets.all(20),
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final id = widget.listingId;
                    if (id == null) return;
                    try {
                      final openResult = await conversationService
                          .getOrCreateConversation(
                            listingId: id,
                            sellerUserId: _resolvedVendorUserId,
                          );
                      if (!context.mounted) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => InboxScreen(
                            conversationId: openResult.conversationId,
                            userName: _displayVendorName,
                            avatarUrl: _resolvedVendorAvatarUrl,
                            isOnline: widget.isOnline,
                            phoneNumber: _profile?.phoneNumber,
                            counterpartUserId:
                                _resolvedVendorUserId ??
                                openResult.counterpartUserId,
                            productListingId: id,
                            armProductReferenceOnOpen: true,
                          ),
                        ),
                      );
                    } on ConversationOpenException catch (e) {
                      if (!context.mounted) return;
                      AppToast.error(context, e.message);
                    } catch (_) {
                      if (!context.mounted) return;
                      AppToast.error(
                        context,
                        'Could not open chat. Please try again.',
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.of(context).primary,
                    foregroundColor: AppColors.of(context).white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  icon: Icon(
                    Icons.chat_bubble_outline,
                    color: AppColors.of(context).white,
                    size: 20,
                  ),
                  label: Text(
                    'Message Vendor',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
        color: AppColors.of(context).white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
              color: AppColors.of(context).lightGray,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: AppColors.of(context).mediumGray,
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
                    color: AppColors.of(context).darkGray,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.of(context).mediumGray,
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
                color: AppColors.of(context).primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check,
                color: AppColors.of(context).white,
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
                vendorName: _displayVendorName,
                vendorLocation:
                    listing.locationText ??
                    listing.campus ??
                    widget.primaryLocation,
                vendorAvatar: _resolvedVendorAvatarUrl,
                ownerUserIdHint: listing.ownerUserId,
                isOwnListingHint: _isOwnVendorProfile,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.of(context).white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
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
                        color: AppColors.of(context).darkGray,
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
                          'UGX ${listing.priceUgx.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                          style: TextStyle(
                            color: AppColors.of(context).primary,
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
        color: AppColors.of(context).lightGray,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        Icons.image_not_supported,
        color: AppColors.of(context).mediumGray,
        size: 28,
      ),
    );
  }
}
