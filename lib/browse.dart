import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cross_file/cross_file.dart';
import 'package:share_plus/share_plus.dart';
import 'package:dio/dio.dart';
import 'main.dart';
import 'userProfile.dart';
import 'productDetails.dart';
import 'vendorProfile.dart';
import 'inbox.dart';
import 'saved.dart';

import 'widgets/main_nav_bar.dart';
import 'widgets/skeletons.dart';
import 'core/api_client.dart';
import 'core/avatar_resolver.dart';
import 'core/conversation_service.dart';
import 'core/auth_service.dart';
import 'core/public_profile_cache.dart';
import 'core/unread_service.dart';
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
  bool _isOpeningDeepLink = false;
  int? _lastOpenedDeepLinkListingId;
  Set<int> _bookmarkedIds = {};

  @override
  void initState() {
    super.initState();
    bookmarkUpdateNotifier.addListener(_onBookmarkUpdate);
    pendingProductDeepLinkNotifier.addListener(_onPendingDeepLinkChanged);
    _loadFeed();
    _bootstrapUnread();
  }

  @override
  void dispose() {
    bookmarkUpdateNotifier.removeListener(_onBookmarkUpdate);
    pendingProductDeepLinkNotifier.removeListener(_onPendingDeepLinkChanged);
    super.dispose();
  }

  void _onBookmarkUpdate() {
    _loadBookmarkedIds();
  }

  void _onPendingDeepLinkChanged() {
    unawaited(_openPendingDeepLink());
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
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[BrowseScreen._loadBookmarkedIds] Failed: $e');
      }
    }
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
      final fallback = items.fold(0, (sum, c) => sum + c.unreadCount);
      unreadNotifier.value = await unreadService.refreshUnreadCount(
        fallbackCount: fallback,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[BrowseScreen._bootstrapUnread] Failed: $e');
      }
    }
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
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[BrowseScreen._loadFeed] Profile bootstrap failed: $e');
        }
      }

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
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint('[BrowseScreen._loadFeed] Feed request failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
    publicProfileCache.logDebugStats('BrowseScreen._loadFeed');
    await _loadBookmarkedIds();
    await _openPendingDeepLink();
  }

  Future<void> _openPendingDeepLink() async {
    final listingId = pendingProductDeepLinkNotifier.value;
    if (!mounted || listingId == null || _isLoading || _isOpeningDeepLink) {
      return;
    }
    if (_lastOpenedDeepLinkListingId == listingId) return;

    _isOpeningDeepLink = true;
    try {
      ListingCardResponse? matchedListing;
      for (final item in _listings) {
        if (item.id == listingId) {
          matchedListing = item;
          break;
        }
      }

      if (matchedListing != null) {
        _pushProductDetails(
          listingId: matchedListing.id,
          productTitle: matchedListing.title,
          productDescription: matchedListing.description ?? '',
          price: matchedListing.priceUgx,
          imageUrl: matchedListing.primaryImageUrl,
          vendorName: matchedListing.ownerFullName ?? 'Seller',
          vendorLocation: zoneLabel(
            matchedListing.lat,
            matchedListing.lng,
            fallback: matchedListing.locationText ?? '',
          ),
          vendorAvatar:
              matchedListing.ownerAvatarUrl ??
              _ownerAvatars[matchedListing.ownerUserId],
          ownerUserIdHint: matchedListing.ownerUserId,
          initiallyBookmarked: _bookmarkedIds.contains(matchedListing.id),
        );
      } else {
        final resp = await apiClient.dio.get('/listings/$listingId');
        final listing = ListingResponse.fromJson(resp.data);
        final profile = await publicProfileCache.resolvePublicProfile(
          listing.ownerUserId,
        );

        if (!mounted) return;

        _pushProductDetails(
          listingId: listing.id,
          productTitle: listing.title,
          productDescription: listing.description ?? '',
          price: listing.priceUgx,
          imageUrl: listing.primaryImageUrl,
          vendorName: profile?.fullName ?? 'Seller',
          vendorLocation:
              listing.locationText ?? listing.campus ?? 'MUST Campus',
          vendorAvatar: profile?.avatarUrl,
          ownerUserIdHint: listing.ownerUserId,
          initiallyBookmarked: _bookmarkedIds.contains(listing.id),
        );
      }

      _lastOpenedDeepLinkListingId = listingId;
      pendingProductDeepLinkNotifier.value = null;
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint('[BrowseScreen._openPendingDeepLink] Failed: $e');
      }
      pendingProductDeepLinkNotifier.value = null;
      if (mounted) {
        AppToast.error(context, 'Could not open the shared product.');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[BrowseScreen._openPendingDeepLink] Failed: $e');
      }
      pendingProductDeepLinkNotifier.value = null;
      if (mounted) {
        AppToast.error(context, 'Could not open the shared product.');
      }
    } finally {
      _isOpeningDeepLink = false;
    }
  }

  void _pushProductDetails({
    required int listingId,
    required String productTitle,
    required String productDescription,
    required int price,
    required String? imageUrl,
    required String vendorName,
    required String vendorLocation,
    required String? vendorAvatar,
    required int? ownerUserIdHint,
    required bool initiallyBookmarked,
  }) {
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailsScreen(
          listingId: listingId,
          productTitle: productTitle,
          productDescription: productDescription,
          price: price,
          imageUrl: imageUrl,
          vendorName: vendorName,
          vendorLocation: vendorLocation,
          vendorAvatar: vendorAvatar,
          initiallyBookmarked: initiallyBookmarked,
          ownerUserIdHint: ownerUserIdHint,
        ),
      ),
    );
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
      backgroundColor: AppColors.of(context).lightGray,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset('assets/images/logo.jpg', width: 40, height: 40),
          ),
        ),
        title: Text(
          'Tukwatagane',
          style: TextStyle(
            color: AppColors.of(context).darkGray,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.bookmark_border,
              color: AppColors.of(context).mediumGray,
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
                backgroundColor: AppColors.of(context).darkGray,
                backgroundImage: _myAvatarUrl != null
                    ? NetworkImage(_myAvatarUrl!)
                    : null,
                child: _myAvatarUrl == null
                    ? Text(
                        (_myFullName?.trim().isNotEmpty == true)
                            ? _myFullName!.trim()[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: AppColors.of(context).white,
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
          ? SkeletonShimmer(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                itemCount: 3,
                itemBuilder: (_, __) => const ProductCardSkeleton(),
              ),
            )
          : _listings.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.storefront_outlined,
                    size: 64,
                    color: AppColors.of(context).mediumGray,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No listings yet',
                    style: TextStyle(color: AppColors.of(context).mediumGray),
                  ),
                  SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _loadFeed,
                    icon: Icon(Icons.refresh),
                    label: Text('Refresh'),
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
  bool _isMessageLoading = false;
  bool _isSharing = false;
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
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ProductCard._toggleBookmark] Failed: $e');
      }
      // Revert on failure
      if (mounted) {
        setState(() => _isBookmarked = !_isBookmarked);
        AppToast.error(
          context,
          'Could not update saved item. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isBookmarkLoading = false);
    }
  }

  Future<XFile?> _buildShareImageFile() async {
    final imageUrl = widget.imageUrl?.trim();
    if (imageUrl == null || imageUrl.isEmpty) return null;

    try {
      final response = await apiClient.dio.get<List<int>>(
        imageUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) return null;

      final uri = Uri.tryParse(imageUrl);
      final rawName = uri?.pathSegments.isNotEmpty == true
          ? uri!.pathSegments.last
          : 'listing_${widget.listingId}.jpg';
      final sanitizedName = rawName.contains('.') ? rawName : '$rawName.jpg';
      final file = File('${Directory.systemTemp.path}/$sanitizedName');
      await file.writeAsBytes(bytes, flush: true);
      return XFile(file.path);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ProductCard._buildShareImageFile] Failed: $e');
      }
      return null;
    }
  }

  void _shareProduct() async {
    if (_isSharing) return;

    setState(() => _isSharing = true);
    final deepLink = Uri(
      scheme: 'tukwatagane',
      host: 'product',
      path: '/${widget.productId}',
    ).toString();
    final shareText = [
      'Check out these listings in Tukwatagane',
      '',
      widget.productTitle,
      'UGX ${widget.price}',
      widget.sellerName,
      widget.location,
      '',
      deepLink,
    ].join('\n');

    try {
      final shareImage = await _buildShareImageFile();
      if (shareImage != null) {
        await Share.shareXFiles(
          [shareImage],
          text: shareText,
          subject: widget.productTitle,
        );
      } else {
        await Share.share(shareText, subject: widget.productTitle);
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Error sharing: $e');
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _openConversation() async {
    if (_isMessageLoading) return;

    setState(() => _isMessageLoading = true);
    try {
      final openResult = await conversationService.getOrCreateConversation(
        listingId: widget.listingId,
        sellerUserId: widget.ownerUserId,
      );
      final profile = await publicProfileCache.resolvePublicProfile(
        openResult.counterpartUserId,
      );
      final sellerPhone = profile?.phoneNumber;
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => InboxScreen(
            conversationId: openResult.conversationId,
            userName: widget.sellerName,
            avatarUrl: widget.sellerAvatar,
            isOnline: false,
            phoneNumber: sellerPhone,
            counterpartUserId:
                widget.ownerUserId ?? openResult.counterpartUserId,
            productTitle: widget.productTitle,
            productImage: widget.imageUrl,
            productPrice: int.parse(widget.price.replaceAll(',', '')),
            productListingId: widget.listingId,
            armProductReferenceOnOpen: true,
          ),
        ),
      );
    } on ConversationOpenException catch (e) {
      if (mounted) {
        AppToast.error(context, e.message);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ProductCard._openConversation] Failed: $e');
      }
      if (mounted) {
        AppToast.error(context, 'Could not open chat. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _isMessageLoading = false);
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
                            backgroundColor: AppColors.of(context).darkGray,
                            child: Text(
                              widget.sellerName.isNotEmpty
                                  ? widget.sellerName[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: AppColors.of(context).white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.sellerName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.of(context).darkGray,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          widget.timestamp,
                          style: TextStyle(
                            color: AppColors.of(context).mediumGray,
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
                              color: AppColors.of(context).lightGray,
                              child: Center(
                                child: Icon(
                                  Icons.image_not_supported_outlined,
                                  color: AppColors.of(context).mediumGray,
                                  size: 64,
                                ),
                              ),
                            ),
                          )
                        : Container(
                            height: 250,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: AppColors.of(context).lightGray,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.image_not_supported_outlined,
                                color: AppColors.of(context).mediumGray,
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
                          color: AppColors.of(
                            context,
                          ).darkGray.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'New',
                          style: TextStyle(
                            color: AppColors.of(context).white,
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
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.of(context).darkGray,
                      fontSize: 18,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'UGX ${widget.price}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.of(context).primary,
                      fontSize: 20,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: AppColors.of(context).primary,
                        size: 16,
                      ),
                      SizedBox(width: 4),
                      Text(
                        widget.location,
                        style: TextStyle(
                          color: AppColors.of(context).mediumGray,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  // Action Buttons
                  if (!_isOwnListing)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isMessageLoading
                                ? null
                                : _openConversation,
                            icon: _isMessageLoading
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: AppColors.of(context).white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    Icons.message,
                                    size: 18,
                                    color: AppColors.of(context).white,
                                  ),
                            label: Text('Message'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.of(context).primary,
                              foregroundColor: AppColors.of(context).white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.of(context).lightGray,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.share,
                              color: AppColors.of(context).darkGray,
                            ),
                            onPressed: _shareProduct,
                          ),
                        ),
                        SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.of(context).lightGray,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: IconButton(
                            icon: Icon(
                              _isBookmarked
                                  ? Icons.bookmark
                                  : Icons.bookmark_border,
                              color: _isBookmarked
                                  ? AppColors.of(context).primary
                                  : AppColors.of(context).darkGray,
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
