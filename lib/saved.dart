import 'package:flutter/material.dart';
import 'main.dart';
import 'productDetails.dart';
import 'inbox.dart';
import 'widgets/main_nav_bar.dart';
import 'widgets/skeletons.dart';
import 'core/api_client.dart';
import 'core/auth_service.dart';
import 'core/conversation_service.dart';
import 'core/public_profile_cache.dart';
import 'core/ui/app_toast.dart';
import 'models/models.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> with RouteAware {
  List<BookmarkCardResponse> _savedItems = [];
  Map<int, String> _ownerNames = {};
  Map<int, String?> _ownerAvatars = {};
  Map<int, int> _listingOwnerIds = {};
  Map<int, ListingResponse> _listingDetails = {};
  Map<int, ListingCardResponse> _listingCards = {};
  bool _isLoading = true;
  int? _myUserId;

  @override
  void initState() {
    super.initState();
    _loadBookmarks();
    authService.getUserId().then((id) {
      if (mounted) setState(() => _myUserId = id);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    setState(() => _isLoading = true);
    try {
      final resp = await apiClient.dio.get(
        '/bookmarks',
        queryParameters: {'page': 0, 'size': 50},
      );
      final items = (resp.data['items'] as List)
          .map((e) => BookmarkCardResponse.fromJson(e))
          .toList();
      if (mounted) {
        setState(() {
          _savedItems = items;
          _ownerNames = {};
          _ownerAvatars = {};
          _listingOwnerIds = {};
          _listingDetails = {};
          _listingCards = {};
        });
      }
      await _hydrateSavedListings(items);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
    publicProfileCache.logDebugStats('SavedScreen._loadBookmarks');
  }

  Future<void> _hydrateSavedListings(List<BookmarkCardResponse> items) async {
    final listingOwnerIds = <int, int>{};
    final ownerNames = <int, String>{};
    final ownerAvatars = <int, String?>{};

    for (final item in items) {
      final ownerId = item.ownerUserId;
      if (ownerId == null) continue;

      listingOwnerIds[item.id] = ownerId;

      final ownerName = item.ownerFullName?.trim();
      if (ownerName != null && ownerName.isNotEmpty) {
        ownerNames[ownerId] = ownerName;
      }

      final ownerAvatar = item.ownerAvatarUrl?.trim();
      if (ownerAvatar != null && ownerAvatar.isNotEmpty) {
        ownerAvatars[ownerId] = ownerAvatar;
      }
    }

    final listingIdsNeedingLookup = items
        .where(
          (item) =>
              item.ownerUserId == null ||
              ((item.locationText?.trim().isEmpty ?? true) &&
                  (item.campus?.trim().isEmpty ?? true)),
        )
        .map((item) => item.id)
        .toList();

    final listingResults = await Future.wait(
      listingIdsNeedingLookup.map((listingId) async {
        try {
          final resp = await apiClient.dio.get('/listings/$listingId');
          return MapEntry(listingId, ListingResponse.fromJson(resp.data));
        } catch (_) {
          return null;
        }
      }),
    );

    final listingDetails = {
      for (final entry in listingResults)
        if (entry != null) entry.key: entry.value,
    };

    for (final entry in listingDetails.entries) {
      listingOwnerIds[entry.key] = entry.value.ownerUserId;
    }

    final ownerIds = listingOwnerIds.values.toSet();
    final unresolvedOwnerIds = ownerIds.where((id) {
      final hasName = (ownerNames[id]?.trim().isNotEmpty ?? false);
      final hasAvatar = (ownerAvatars[id]?.trim().isNotEmpty ?? false);
      return !hasName || !hasAvatar;
    }).toList();

    final profileMap = await publicProfileCache.resolvePublicProfiles(
      unresolvedOwnerIds,
    );

    for (final entry in profileMap.entries) {
      final profile = entry.value;
      if (profile == null) continue;

      if (profile.fullName.trim().isNotEmpty) {
        ownerNames[entry.key] = profile.fullName;
      }

      final avatar = profile.avatarUrl?.trim();
      if (avatar != null && avatar.isNotEmpty) {
        ownerAvatars[entry.key] = avatar;
      }
    }

    if (mounted) {
      setState(() {
        _listingCards = {};
        _listingDetails = listingDetails;
        _listingOwnerIds = listingOwnerIds;
        _ownerNames = ownerNames;
        _ownerAvatars = ownerAvatars;
      });
    }
  }

  ListingCardResponse? _resolvedListingCard(BookmarkCardResponse item) {
    return _listingCards[item.id];
  }

  ListingResponse? _resolvedListing(BookmarkCardResponse item) {
    return _listingDetails[item.id];
  }

  String _resolvedSellerName(BookmarkCardResponse item) {
    final ownerId =
        _resolvedListingCard(item)?.ownerUserId ??
        _resolvedListing(item)?.ownerUserId ??
        item.ownerUserId ??
        _listingOwnerIds[item.id];
    return _resolvedListingCard(item)?.ownerFullName ??
        item.ownerFullName ??
        _ownerNames[ownerId] ??
        '';
  }

  String _displaySellerName(BookmarkCardResponse item) {
    final sellerName = _resolvedSellerName(item).trim();
    return sellerName.isEmpty ? 'Seller' : sellerName;
  }

  int? _resolvedOwnerUserId(BookmarkCardResponse item) {
    return _resolvedListingCard(item)?.ownerUserId ??
        _resolvedListing(item)?.ownerUserId ??
        item.ownerUserId ??
        _listingOwnerIds[item.id];
  }

  String? _resolvedSellerAvatar(BookmarkCardResponse item) {
    final listingAvatar = _resolvedListingCard(item)?.ownerAvatarUrl?.trim();
    if (listingAvatar != null && listingAvatar.isNotEmpty) return listingAvatar;

    final bookmarkAvatar = item.ownerAvatarUrl?.trim();
    if (bookmarkAvatar != null && bookmarkAvatar.isNotEmpty) {
      return bookmarkAvatar;
    }

    final ownerId = _resolvedOwnerUserId(item);
    final cachedAvatar = _ownerAvatars[ownerId]?.trim();
    if (cachedAvatar != null && cachedAvatar.isNotEmpty) return cachedAvatar;

    return null;
  }

  String _resolvedLocation(BookmarkCardResponse item) {
    final listing = _resolvedListing(item);
    return listing?.locationText ??
        item.locationText ??
        listing?.campus ??
        item.campus ??
        '';
  }

  Future<void> _removeItem(int listingId) async {
    try {
      await apiClient.dio.delete(
        '/bookmarks',
        queryParameters: {'listingId': listingId},
      );
      if (mounted) {
        setState(() => _savedItems.removeWhere((item) => item.id == listingId));
        AppToast.success(context, 'Item removed from saved list.');
      }
    } catch (_) {
      if (mounted) {
        AppToast.error(context, 'Could not remove item. Please try again.');
      }
    }
  }

  Future<void> _confirmRemoveItem(BookmarkCardResponse item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text('Remove Saved Item'),
          content: Text('Remove "${item.title}" from saved items?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.of(context).primary,
                foregroundColor: AppColors.of(context).white,
              ),
              child: Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _removeItem(item.id);
    }
  }

  Future<void> _startChat(BookmarkCardResponse item) async {
    try {
      final openResult = await conversationService.getOrCreateConversation(
        listingId: item.id,
        sellerUserId: _resolvedOwnerUserId(item),
      );
      String sellerName = _displaySellerName(item);
      String? sellerPhone;
      String? sellerAvatar;
      final profile = await publicProfileCache.resolvePublicProfile(
        openResult.counterpartUserId,
      );
      if (profile != null) {
        sellerName = profile.fullName;
        sellerPhone = profile.phoneNumber;
        final avatarUrl = profile.avatarUrl?.trim();
        sellerAvatar = (avatarUrl != null && avatarUrl.isNotEmpty)
            ? avatarUrl
            : null;
      }

      sellerAvatar ??= _resolvedSellerAvatar(item);

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => InboxScreen(
            conversationId: openResult.conversationId,
            userName: sellerName,
            avatarUrl: sellerAvatar,
            isOnline: false,
            phoneNumber: sellerPhone,
            counterpartUserId:
                _resolvedOwnerUserId(item) ?? openResult.counterpartUserId,
            productTitle: item.title,
            productImage: item.primaryImageUrl,
            productPrice: item.priceUgx,
            productListingId: item.id,
            armProductReferenceOnOpen: true,
          ),
        ),
      );
    } on ConversationOpenException catch (e) {
      if (mounted) {
        AppToast.error(context, e.message);
      }
    } catch (_) {
      if (mounted) {
        AppToast.error(context, 'Could not open chat. Please try again.');
      }
    }
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
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Screen Title Row with Back Button and Count
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.pushReplacementNamed(context, '/account');
                  },
                  child: Icon(
                    Icons.arrow_back,
                    color: AppColors.of(context).darkGray,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        'Saved Items',
                        style: TextStyle(
                          color: AppColors.of(context).darkGray,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${_savedItems.length} items',
                        style: TextStyle(
                          color: AppColors.of(context).mediumGray,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Saved Items List
          Expanded(
            child: _isLoading
                ? SkeletonShimmer(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      itemCount: 4,
                      itemBuilder: (_, __) => const SavedCardSkeleton(),
                    ),
                  )
                : _savedItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bookmark_border,
                          size: 80,
                          color: AppColors.of(
                            context,
                          ).mediumGray.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Saved Items',
                          style: TextStyle(
                            color: AppColors.of(context).darkGray,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Items you bookmark will appear here',
                          style: TextStyle(
                            color: AppColors.of(context).mediumGray,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadBookmarks,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _savedItems.length,
                      itemBuilder: (context, index) {
                        return _buildSavedItemCard(_savedItems[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: const MainNavBar(currentIndex: 4),
    );
  }

  Widget _buildSavedItemCard(BookmarkCardResponse item) {
    final isAvailable = item.status == 'ACTIVE';
    final sellerName = _displaySellerName(item);
    final sellerAvatar = _resolvedSellerAvatar(item);
    final sellerInitial = sellerName.isNotEmpty
        ? sellerName.substring(0, 1).toUpperCase()
        : '?';
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
              vendorName: sellerName,
              vendorLocation: _resolvedLocation(item),
              vendorAvatar: sellerAvatar,
              ownerUserIdHint: _resolvedOwnerUserId(item),
              initiallyBookmarked: true,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: Thumbnail and Info
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thumbnail
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: item.primaryImageUrl != null
                        ? Image.network(
                            item.primaryImageUrl!,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 100,
                            height: 100,
                            color: AppColors.of(context).lightGray,
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              color: AppColors.of(context).mediumGray,
                              size: 36,
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 10,
                              backgroundColor: AppColors.of(context).lightGray,
                              backgroundImage: sellerAvatar != null
                                  ? NetworkImage(sellerAvatar)
                                  : null,
                              child: sellerAvatar == null
                                  ? Text(
                                      sellerInitial,
                                      style: TextStyle(
                                        color: AppColors.of(context).mediumGray,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                sellerName,
                                style: TextStyle(
                                  color: AppColors.of(context).darkGray,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Title
                        Text(
                          item.title,
                          style: TextStyle(
                            color: AppColors.of(context).darkGray,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        // Price
                        Text(
                          'UGX ${item.priceUgx.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                          style: TextStyle(
                            color: AppColors.of(context).primary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Location
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 14,
                              color: AppColors.of(context).mediumGray,
                            ),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                _resolvedLocation(item),
                                style: TextStyle(
                                  color: AppColors.of(context).mediumGray,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Action Row - Full Width
              Row(
                children: [
                  // Remove Button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _confirmRemoveItem(item),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.of(context).mediumGray,
                        side: BorderSide(
                          color: AppColors.of(context).lightGray,
                          width: 1,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: Icon(
                        Icons.delete_outline,
                        size: 16,
                        color: AppColors.of(context).mediumGray,
                      ),
                      label: Text(
                        'Remove',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Status Badge
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isAvailable
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          isAvailable ? 'Available' : 'Sold',
                          style: TextStyle(
                            color: isAvailable
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Chat Now Button
                  if (_myUserId == null ||
                      _resolvedOwnerUserId(item) != _myUserId)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isAvailable ? () => _startChat(item) : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isAvailable
                              ? AppColors.of(context).primary
                              : AppColors.of(context).lightGray,
                          foregroundColor: isAvailable
                              ? AppColors.of(context).white
                              : AppColors.of(context).mediumGray,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        icon: Icon(
                          Icons.chat_bubble_outline,
                          size: 16,
                          color: isAvailable
                              ? AppColors.of(context).white
                              : AppColors.of(context).mediumGray,
                        ),
                        label: Text(
                          'Chat Now',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
