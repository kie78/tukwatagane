import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:dio/dio.dart';
import 'main.dart';
import 'userProfile.dart';
import 'productDetails.dart';
import 'vendorProfile.dart';
import 'inbox.dart';
import 'saved.dart';

import 'widgets/main_nav_bar.dart';
import 'core/api_client.dart';
import 'core/avatar_resolver.dart';
import 'core/auth_service.dart';
import 'core/public_profile_cache.dart';
import 'core/ui/app_toast.dart';
import 'models/models.dart';
import 'config/campus_zones.dart';

class BrowseScreen extends StatefulWidget {
  const BrowseScreen({super.key});

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  List<ListingCardResponse> _listings = [];
  Map<int, String?> _ownerAvatars = {};
  String? _myFullName;
  String? _myAvatarUrl;
  bool _isLoading = true;
  Set<int> _bookmarkedIds = {};

  @override
  void initState() {
    super.initState();
    bookmarkUpdateNotifier.addListener(_onBookmarkUpdate);
    _loadFeed();
    _bootstrapUnread();
  }

  @override
  void dispose() {
    bookmarkUpdateNotifier.removeListener(_onBookmarkUpdate);
    super.dispose();
  }

  void _onBookmarkUpdate() {
    _loadBookmarkedIds();
  }

  Future<void> _loadBookmarkedIds() async {
    try {
      final resp = await apiClient.dio.get(
        '/bookmarks',
        queryParameters: {'page': 0, 'size': 200},
      );
      final ids = (resp.data['items'] as List)
          .map((e) => e['id'] as int)
          .toSet();
      if (mounted) setState(() => _bookmarkedIds = ids);
    } catch (_) {}
  }

  Future<void> _bootstrapUnread() async {
    try {
      final resp = await apiClient.dio.get(
        '/conversations',
        queryParameters: {'page': 0, 'size': 50},
      );
      final items = (resp.data['items'] as List)
          .map((e) => ConversationListItem.fromJson(e))
          .toList();
      unreadNotifier.value = items.fold(0, (sum, c) => sum + c.unreadCount);
    } catch (_) {}
  }

  Future<void> _loadFeed() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      // Use registered location from profile (collected at sign-up)
      double lat = -0.5950, lng = 30.5970;
      String? myFullName = _myFullName;
      String? myAvatarUrl = _myAvatarUrl;
      try {
        final profileResp = await apiClient.dio.get('/users/profile');
        final profile = UserProfile.fromJson(profileResp.data);
        myFullName = profile.fullName;
        final avatar = profile.avatarUrl?.trim();
        myAvatarUrl = (avatar != null && avatar.isNotEmpty) ? avatar : null;
        final loc = profile.registeredLocation ?? profile.alternateLocation;
        final regLat = loc?.lat;
        final regLng = loc?.lng;
        if (regLat != null && regLng != null) {
          lat = regLat;
          lng = regLng;
        }
      } catch (_) {}

      final resp = await apiClient.dio.get(
        '/listings/feed',
        queryParameters: {'lat': lat, 'lng': lng, 'page': 0, 'size': 20},
      );
      final page = ListingPage.fromJson(resp.data);

      final directOwnerAvatars = <int, String?>{};
      for (final item in page.items) {
        final ownerId = item.ownerUserId;
        final avatarUrl = item.ownerAvatarUrl?.trim();
        if (ownerId == null || avatarUrl == null || avatarUrl.isEmpty) {
          continue;
        }
        directOwnerAvatars[ownerId] = avatarUrl;
      }

      final ownerIds = page.items
          .map((item) => item.ownerUserId)
          .whereType<int>()
          .toSet();
      final unresolvedOwnerIds = ownerIds
          .where((id) => !directOwnerAvatars.containsKey(id))
          .toSet();
      final resolvedOwnerAvatars = await avatarResolver.resolveAvatarUrls(
        unresolvedOwnerIds,
      );
      final ownerAvatars = <int, String?>{
        ...resolvedOwnerAvatars,
        ...directOwnerAvatars,
      };

      if (mounted) {
        setState(() {
          _listings = page.items;
          _ownerAvatars = ownerAvatars;
          _myFullName = myFullName;
          _myAvatarUrl = myAvatarUrl;
        });
      }
    } on DioException catch (_) {
      // silently keep empty list on error
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
    publicProfileCache.logDebugStats('BrowseScreen._loadFeed');
    _loadBookmarkedIds();
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
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset('assets/images/logo.jpg', width: 40, height: 40),
          ),
        ),
        title: const Text(
          'Tukwatagane',
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
                MaterialPageRoute(builder: (context) => const SavedScreen()),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UserProfileScreen(),
                  ),
                );
              },
              child: CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.darkGray,
                backgroundImage: _myAvatarUrl != null
                    ? NetworkImage(_myAvatarUrl!)
                    : null,
                child: _myAvatarUrl == null
                    ? Text(
                        (_myFullName?.trim().isNotEmpty == true)
                            ? _myFullName!.trim()[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      )
                    : null,
              ),
            ),
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
                    Icons.storefront_outlined,
                    size: 64,
                    color: AppColors.mediumGray,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No listings yet',
                    style: TextStyle(color: AppColors.mediumGray),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _loadFeed,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reload'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadFeed,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                itemCount: _listings.length,
                itemBuilder: (context, index) {
                  final item = _listings[index];
                  return ProductCard(
                    listingId: item.id,
                    productId: item.id.toString(),
                    sellerName: item.ownerFullName ?? 'Seller',
                    sellerAvatar:
                        item.ownerAvatarUrl ?? _ownerAvatars[item.ownerUserId],
                    timestamp: _timeAgo(item.createdAt),
                    productTitle: item.title,
                    price: item.priceUgx.toString(),
                    location: zoneLabel(
                      item.lat,
                      item.lng,
                      fallback: item.locationText ?? '',
                    ),
                    imageUrl: item.primaryImageUrl,
                    isNew: DateTime.now().difference(item.createdAt).inDays < 1,
                    ownerUserId: item.ownerUserId,
                    description: item.description,
                    myFullName: _myFullName,
                    initiallyBookmarked: _bookmarkedIds.contains(item.id),
                  );
                },
              ),
            ),
      bottomNavigationBar: const MainNavBar(currentIndex: 0),
    );
  }
}

class ProductCard extends StatefulWidget {
  final int listingId;
  final String productId;
  final String sellerName;
  final String? sellerAvatar;
  final String timestamp;
  final String productTitle;
  final String price;
  final String location;
  final String? imageUrl;
  final bool isNew;
  final int? ownerUserId;
  final String? description;
  final String? myFullName;
  final bool initiallyBookmarked;

  const ProductCard({
    super.key,
    required this.listingId,
    required this.productId,
    required this.sellerName,
    this.sellerAvatar,
    required this.timestamp,
    required this.productTitle,
    required this.price,
    required this.location,
    this.imageUrl,
    this.isNew = false,
    this.ownerUserId,
    this.description,
    this.myFullName,
    this.initiallyBookmarked = false,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _isBookmarked = false;
  bool _isBookmarkLoading = false;
  int? _myUserId;

  @override
  void initState() {
    super.initState();
    _isBookmarked = widget.initiallyBookmarked;
    authService.getUserId().then((id) {
      if (mounted) setState(() => _myUserId = id);
    });
  }

  @override
  void didUpdateWidget(covariant ProductCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isBookmarkLoading &&
        oldWidget.initiallyBookmarked != widget.initiallyBookmarked) {
      _isBookmarked = widget.initiallyBookmarked;
    }
  }

  bool get _isOwnListing =>
      (_myUserId != null &&
          widget.ownerUserId != null &&
          _myUserId == widget.ownerUserId) ||
      ((widget.myFullName ?? '').trim().isNotEmpty &&
          widget.sellerName.trim().toLowerCase() ==
              widget.myFullName!.trim().toLowerCase());

  void _toggleBookmark() async {
    if (_isBookmarkLoading) return;
    setState(() {
      _isBookmarkLoading = true;
      _isBookmarked = !_isBookmarked;
    });
    try {
      if (_isBookmarked) {
        await apiClient.dio.post(
          '/bookmarks',
          data: {'listingId': widget.listingId},
        );
      } else {
        await apiClient.dio.delete(
          '/bookmarks',
          queryParameters: {'listingId': widget.listingId},
        );
      }
      bookmarkUpdateNotifier.value++;
      if (mounted) {
        AppToast.success(
          context,
          _isBookmarked ? 'Added to saved items' : 'Removed from saved items',
        );
      }
    } catch (_) {
      // Revert on failure
      if (mounted) {
        setState(() => _isBookmarked = !_isBookmarked);
        AppToast.error(context, 'Could not update saved item. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isBookmarkLoading = false);
    }
  }

  void _shareProduct() async {
    final String shareText =
        '''
${widget.productTitle}
UGX ${widget.price}
📍 ${widget.location}

Check out this item on Tukwatagane!

🔗 tukwatagane://product/${widget.productId}
    ''';

    try {
      await Share.share(shareText, subject: widget.productTitle);
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Error sharing: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailsScreen(
              listingId: widget.listingId,
              productTitle: widget.productTitle,
              productDescription: widget.description ?? '',
              price: int.parse(widget.price.replaceAll(',', '')),
              imageUrl: widget.imageUrl,
              vendorName: widget.sellerName,
              vendorLocation: widget.location,
              vendorAvatar: widget.sellerAvatar,
              initiallyBookmarked: _isBookmarked,
              ownerUserIdHint: widget.ownerUserId,
              isOwnListingHint: _isOwnListing,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Seller Header
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => VendorProfileScreen(
                            vendorName: widget.sellerName,
                            vendorAvatar: widget.sellerAvatar,
                            primaryLocation: widget.location,
                            vendorUserId: widget.ownerUserId,
                            listingId: widget.listingId,
                          ),
                        ),
                      );
                    },
                    child: widget.sellerAvatar != null
                        ? CircleAvatar(
                            radius: 20,
                            backgroundImage: NetworkImage(widget.sellerAvatar!),
                          )
                        : CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.darkGray,
                            child: Text(
                              widget.sellerName.isNotEmpty
                                  ? widget.sellerName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: AppColors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.sellerName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.darkGray,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          widget.timestamp,
                          style: const TextStyle(
                            color: AppColors.mediumGray,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Product Image
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: widget.imageUrl != null
                        ? Image.network(
                            widget.imageUrl!,
                            height: 250,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              height: 250,
                              width: double.infinity,
                              color: AppColors.lightGray,
                              child: const Center(
                                child: Icon(
                                  Icons.image_not_supported_outlined,
                                  color: AppColors.mediumGray,
                                  size: 64,
                                ),
                              ),
                            ),
                          )
                        : Container(
                            height: 250,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: AppColors.lightGray,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                color: AppColors.mediumGray,
                                size: 64,
                              ),
                            ),
                          ),
                  ),
                  if (widget.isNew)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.darkGray.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'New',
                          style: TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Product Details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.productTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkGray,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'UGX ${widget.price}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.teal,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: AppColors.teal,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.location,
                        style: const TextStyle(
                          color: AppColors.mediumGray,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Action Buttons
                  if (!_isOwnListing)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              try {
                                final resp = await apiClient.dio.post(
                                  '/conversations',
                                  data: {'listingId': widget.listingId},
                                );
                                final conv = ConversationResponse.fromJson(
                                  resp.data,
                                );
                                String? sellerPhone;
                                final profile = await publicProfileCache
                                    .resolvePublicProfile(conv.posterUserId);
                                sellerPhone = profile?.phoneNumber;
                                if (!context.mounted) return;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => InboxScreen(
                                      conversationId: conv.id,
                                      userName: widget.sellerName,
                                      avatarUrl: widget.sellerAvatar,
                                      isOnline: false,
                                      phoneNumber: sellerPhone,
                                      counterpartUserId:
                                          widget.ownerUserId ??
                                          conv.posterUserId,
                                      productTitle: widget.productTitle,
                                      productImage: widget.imageUrl,
                                      productPrice: int.parse(
                                        widget.price.replaceAll(',', ''),
                                      ),
                                      productListingId: widget.listingId,
                                    ),
                                  ),
                                );
                              } catch (_) {}
                            },
                            icon: const Icon(
                              Icons.message,
                              size: 18,
                              color: AppColors.white,
                            ),
                            label: const Text('Message'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.teal,
                              foregroundColor: AppColors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.lightGray,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: IconButton(
                            icon: const Icon(
                              Icons.share,
                              color: AppColors.darkGray,
                            ),
                            onPressed: _shareProduct,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.lightGray,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: IconButton(
                            icon: Icon(
                              _isBookmarked
                                  ? Icons.bookmark
                                  : Icons.bookmark_border,
                              color: _isBookmarked
                                  ? Colors.black
                                  : AppColors.darkGray,
                            ),
                            onPressed: _toggleBookmark,
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
    );
  }
}
