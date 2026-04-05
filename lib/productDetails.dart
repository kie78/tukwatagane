import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'main.dart';
import 'vendorProfile.dart';
import 'inbox.dart';
import 'core/api_client.dart';
import 'core/auth_service.dart';
import 'core/conversation_service.dart';
import 'core/public_profile_cache.dart';
import 'core/ui/app_toast.dart';
import 'models/models.dart';

class ProductDetailsScreen extends StatefulWidget {
  final int? listingId;
  final String productTitle;
  final String productDescription;
  final int price;
  final String? imageUrl;
  final String vendorName;
  final String vendorLocation;
  final String? vendorAvatar;
  final double? vendorRating;
  final bool isVerified;
  final bool initiallyBookmarked;
  final int? ownerUserIdHint;
  final bool? isOwnListingHint;

  const ProductDetailsScreen({
    super.key,
    this.listingId,
    required this.productTitle,
    this.productDescription = '',
    required this.price,
    this.imageUrl,
    required this.vendorName,
    required this.vendorLocation,
    this.vendorAvatar,
    this.vendorRating,
    this.isVerified = false,
    this.initiallyBookmarked = false,
    this.ownerUserIdHint,
    this.isOwnListingHint,
  });

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  static const int _descriptionToggleThreshold = 180;

  int _currentImageIndex = 0;
  bool _isDescriptionExpanded = false;
  bool _isBookmarked = false;
  bool _isBookmarkLoading = false;
  bool _isChatLoading = false;
  bool _isListingLoading = false;
  bool _isListingUnavailable = false;
  int? _ownerUserId;
  int? _myUserId;
  String? _myUserName;
  bool _viewerIdentityLoaded = false;
  String? _ownerPhoneNumber;
  String? _resolvedVendorAvatarUrl;
  String? _listingStatusMessage;
  late String _description;

  bool get _isOwnListingByName {
    final myUserName = _myUserName?.trim().toLowerCase();
    final vendorName = widget.vendorName.trim().toLowerCase();
    return myUserName != null &&
        myUserName.isNotEmpty &&
        vendorName.isNotEmpty &&
        myUserName == vendorName;
  }

  bool get _isOwnListing =>
      widget.isOwnListingHint == true ||
      (_myUserId != null &&
          _ownerUserId != null &&
          _myUserId == _ownerUserId) ||
      _isOwnListingByName;

  bool get _showSellerActions =>
      _viewerIdentityLoaded && !_isOwnListing && !_isListingUnavailable;

  final List<String> _images = [];

  @override
  void initState() {
    super.initState();
    _isBookmarked = widget.initiallyBookmarked;
    _ownerUserId = widget.ownerUserIdHint;
    _resolvedVendorAvatarUrl = widget.vendorAvatar;
    _description = widget.productDescription.trim();
    _isListingLoading = widget.listingId != null;
    // Show the primary image immediately while fetching the full listing
    if (widget.imageUrl != null) _images.add(widget.imageUrl!);
    if (widget.listingId != null) _fetchListingImages();
    _loadBookmarkState();
    _loadViewerIdentity();
  }

  Future<void> _loadViewerIdentity() async {
    final userId = await authService.getUserId();
    final userName = await authService.getUserName();
    if (mounted) {
      setState(() {
        _myUserId = userId;
        _myUserName = userName;
        _viewerIdentityLoaded = true;
      });
    }
  }

  Future<void> _loadBookmarkState() async {
    final listingId = widget.listingId;
    if (listingId == null) return;

    try {
      const pageSize = 200;
      var pageIndex = 0;
      var total = pageSize;
      var isBookmarked = false;

      while (pageIndex * pageSize < total && !isBookmarked) {
        final resp = await apiClient.dio.get(
          '/bookmarks',
          queryParameters: {'page': pageIndex, 'size': pageSize},
        );
        final items = resp.data['items'] as List? ?? const [];
        total = (resp.data['total'] as int?) ?? items.length;

        isBookmarked = items.any((raw) {
          if (raw is! Map) return false;
          final rawId = raw['id'];
          final id = rawId is int
              ? rawId
              : int.tryParse(rawId?.toString() ?? '');
          return id == listingId;
        });

        if (items.isEmpty) break;
        pageIndex++;
      }

      if (mounted && !_isBookmarkLoading) {
        setState(() => _isBookmarked = isBookmarked);
      }
    } catch (_) {}
  }

  Future<void> _fetchListingImages() async {
    final listingId = widget.listingId;
    if (listingId == null) return;

    if (mounted) {
      setState(() {
        _isListingLoading = true;
        _isListingUnavailable = false;
        _listingStatusMessage = null;
      });
    }

    try {
      final resp = await apiClient.dio.get('/listings/$listingId');
      final listing = ListingResponse.fromJson(resp.data);
      final fetchedDescription = (listing.description ?? '').trim();

      await _fetchOwnerPhone(listing.ownerUserId);
      if (mounted) {
        setState(() {
          _isListingUnavailable = false;
          _ownerUserId = listing.ownerUserId;
          if (fetchedDescription.isNotEmpty) {
            _description = fetchedDescription;
          }
          final urls = listing.images.map((img) => img.secureUrl).toList();
          if (urls.isNotEmpty) {
            _images.clear();
            _images.addAll(urls);
            _currentImageIndex = 0;
          } else if (listing.primaryImageUrl != null && _images.isEmpty) {
            _images.add(listing.primaryImageUrl!);
          }
        });
      }
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 404) {
        final foundInMyListings = await _loadDescriptionFromMyListings();
        if (mounted) {
          setState(() {
            _isListingUnavailable = !foundInMyListings;
            if (!foundInMyListings) {
              _listingStatusMessage = 'This listing is no longer active.';
            }
          });
        }
      } else if (mounted) {
        setState(() {
          _listingStatusMessage =
              'Could not refresh listing details. Showing available information.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _listingStatusMessage =
              'Could not refresh listing details. Showing available information.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isListingLoading = false;
        });
      }
    }
  }

  Future<void> _fetchOwnerPhone(int ownerUserId) async {
    final profile = await publicProfileCache.resolvePublicProfile(ownerUserId);
    if (profile == null || !mounted) return;

    setState(() {
      _ownerPhoneNumber = profile.phoneNumber;
      final avatarUrl = profile.avatarUrl?.trim();
      if (avatarUrl != null && avatarUrl.isNotEmpty) {
        _resolvedVendorAvatarUrl = avatarUrl;
      }
    });
  }

  Future<bool> _loadDescriptionFromMyListings() async {
    final listingId = widget.listingId;
    if (listingId == null) return false;

    try {
      final resp = await apiClient.dio.get(
        '/listings/my',
        queryParameters: {'status': 'ALL'},
      );
      final items = resp.data['items'] as List? ?? const [];

      for (final raw in items) {
        if (raw is! Map) continue;

        final rawId = raw['id'];
        final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
        if (id != listingId) continue;

        final description = (raw['description'] ?? '').toString().trim();
        final ownerIdRaw = raw['ownerUserId'];
        final ownerId = ownerIdRaw is int
            ? ownerIdRaw
            : int.tryParse(ownerIdRaw?.toString() ?? '');
        final primaryImageUrl = (raw['primaryImageUrl'] ?? '')
            .toString()
            .trim();

        if (ownerId != null) {
          await _fetchOwnerPhone(ownerId);
        }

        if (mounted) {
          setState(() {
            _ownerUserId ??= ownerId;
            if (description.isNotEmpty) {
              _description = description;
            }
            if (_images.isEmpty && primaryImageUrl.isNotEmpty) {
              _images.add(primaryImageUrl);
            }
          });
        }
        return true;
      }

      return false;
    } catch (_) {
      // Ignore fallback failures; UI already handles unavailable state.
      return false;
    }
  }

  Future<void> _toggleBookmark() async {
    if (widget.listingId == null) return;
    setState(() => _isBookmarkLoading = true);
    try {
      if (_isBookmarked) {
        await apiClient.dio.delete(
          '/bookmarks',
          queryParameters: {'listingId': widget.listingId},
        );
        if (mounted) setState(() => _isBookmarked = false);
      } else {
        await apiClient.dio.post(
          '/bookmarks',
          data: {'listingId': widget.listingId},
        );
        if (mounted) setState(() => _isBookmarked = true);
      }
      bookmarkUpdateNotifier.value++;
      if (mounted) {
        AppToast.success(
          context,
          _isBookmarked ? 'Added to saved items' : 'Removed from saved items',
        );
      }
    } catch (_) {
      if (mounted) {
        AppToast.error(
          context,
          'Could not update saved item. Please try again.',
        );
      }
    }
    if (mounted) setState(() => _isBookmarkLoading = false);
  }

  Future<void> _startConversation() async {
    if (widget.listingId == null) return;
    setState(() => _isChatLoading = true);
    try {
      final openResult = await conversationService.getOrCreateConversation(
        listingId: widget.listingId!,
        sellerUserId: _ownerUserId,
      );
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => InboxScreen(
              conversationId: openResult.conversationId,
              userName: widget.vendorName,
              avatarUrl: _resolvedVendorAvatarUrl ?? widget.vendorAvatar,
              phoneNumber: _ownerPhoneNumber,
              counterpartUserId: _ownerUserId ?? openResult.counterpartUserId,
              productTitle: widget.productTitle,
              productImage: widget.imageUrl,
              productPrice: widget.price,
              productListingId: widget.listingId,
              armProductReferenceOnOpen: true,
            ),
          ),
        );
      }
    } catch (_) {
      // Fallback: open with a dummy conversationId of 0 (will fail to load msgs gracefully)
      if (mounted) {
        AppToast.error(context, 'Could not open chat. Please try again.');
      }
    }
    if (mounted) setState(() => _isChatLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final descriptionText = _description.trim();
    final shouldShowDescriptionToggle =
        descriptionText.length > _descriptionToggleThreshold;
    final listingStatusMessage = _listingStatusMessage?.trim();
    final hasListingStatusMessage =
        listingStatusMessage != null && listingStatusMessage.isNotEmpty;
    final vendorAvatarUrl =
        (_resolvedVendorAvatarUrl?.trim().isNotEmpty == true)
        ? _resolvedVendorAvatarUrl
        : widget.vendorAvatar;

    return Scaffold(
      backgroundColor: AppColors.of(context).lightGray,
      body: SafeArea(
        top: true,
        bottom: false,
        child: Stack(
          children: [
            // Main Content
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image Gallery
                  Stack(
                    children: [
                      // Image
                      if (_images.isEmpty)
                        Container(
                          height: 400,
                          width: double.infinity,
                          color: AppColors.of(context).lightGray,
                          child: Center(
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              size: 80,
                              color: AppColors.of(context).mediumGray,
                            ),
                          ),
                        )
                      else
                        SizedBox(
                          height: 400,
                          width: double.infinity,
                          child: PageView.builder(
                            itemCount: _images.length,
                            onPageChanged: (index) {
                              setState(() {
                                _currentImageIndex = index;
                              });
                            },
                            itemBuilder: (context, index) {
                              return Image.network(
                                _images[index],
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (_, __, ___) => Container(
                                  color: AppColors.of(context).lightGray,
                                  child: Center(
                                    child: Icon(
                                      Icons.image_not_supported_outlined,
                                      size: 80,
                                      color: AppColors.of(context).mediumGray,
                                    ),
                                  ),
                                ),
                                loadingBuilder: (_, child, progress) {
                                  if (progress == null) return child;
                                  return Container(
                                    color: AppColors.of(context).lightGray,
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      // Back Button
                      Positioned(
                        top: 50,
                        left: 16,
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.arrow_back,
                              color: AppColors.of(context).darkGray,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                      // Page Indicators
                      if (_images.isNotEmpty)
                        Positioned(
                          bottom: 20,
                          left: 0,
                          right: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              _images.length,
                              (index) => Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _currentImageIndex == index
                                      ? AppColors.of(context).primary
                                      : AppColors.of(context).lightGray,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  // Product Information Section
                  Transform.translate(
                    offset: const Offset(0, -24),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.of(context).white,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Product Title
                            Text(
                              widget.productTitle,
                              style: TextStyle(
                                color: AppColors.of(context).darkGray,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 12),
                            if (_isListingLoading) ...[
                              const LinearProgressIndicator(),
                              SizedBox(height: 12),
                            ],
                            if (hasListingStatusMessage) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _isListingUnavailable
                                      ? Colors.orange.shade50
                                      : Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _isListingUnavailable
                                        ? Colors.orange.shade200
                                        : Colors.red.shade200,
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      _isListingUnavailable
                                          ? Icons.info_outline
                                          : Icons.wifi_off,
                                      size: 18,
                                      color: _isListingUnavailable
                                          ? Colors.orange.shade700
                                          : Colors.red.shade700,
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        listingStatusMessage,
                                        style: TextStyle(
                                          color: _isListingUnavailable
                                              ? Colors.orange.shade900
                                              : Colors.red.shade900,
                                          fontSize: 13,
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 16),
                            ] else
                              SizedBox(height: 16),
                            // Description
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  descriptionText.isNotEmpty
                                      ? descriptionText
                                      : 'No description provided.',
                                  style: TextStyle(
                                    color: AppColors.of(context).mediumGray,
                                    fontSize: 15,
                                    height: 1.5,
                                  ),
                                  maxLines:
                                      shouldShowDescriptionToggle &&
                                          !_isDescriptionExpanded
                                      ? 3
                                      : null,
                                  overflow:
                                      shouldShowDescriptionToggle &&
                                          !_isDescriptionExpanded
                                      ? TextOverflow.ellipsis
                                      : null,
                                ),
                                if (shouldShowDescriptionToggle) ...[
                                  SizedBox(height: 8),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _isDescriptionExpanded =
                                            !_isDescriptionExpanded;
                                      });
                                    },
                                    child: Text(
                                      _isDescriptionExpanded
                                          ? 'Show Less'
                                          : 'Read More',
                                      style: TextStyle(
                                        color: AppColors.of(context).primary,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            SizedBox(height: 24),
                            // Price and Bookmark Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'UGX ${widget.price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                                  style: TextStyle(
                                    color: AppColors.of(context).primary,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (_showSellerActions)
                                  GestureDetector(
                                    onTap: _isBookmarkLoading
                                        ? null
                                        : _toggleBookmark,
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppColors.of(context).white,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: AppColors.of(context).lightGray,
                                          width: 1,
                                        ),
                                      ),
                                      child: _isBookmarkLoading
                                          ? SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : Icon(
                                              _isBookmarked
                                                  ? Icons.bookmark
                                                  : Icons.bookmark_border,
                                              color: _isBookmarked
                                                  ? AppColors.of(context).primary
                                                  : AppColors.of(context).mediumGray,
                                              size: 24,
                                            ),
                                    ),
                                  ),
                              ],
                            ),
                            SizedBox(height: 24),
                            // Vendor Information Card
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => VendorProfileScreen(
                                      vendorName: widget.vendorName,
                                      vendorAvatar: vendorAvatarUrl,
                                      primaryLocation: widget.vendorLocation,
                                      vendorUserId: _ownerUserId,
                                      listingId: widget.listingId,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.of(context).white,
                                  border: Border.all(
                                    color: AppColors.of(context).lightGray,
                                    width: 1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    // Avatar with Verification Badge
                                    Stack(
                                      children: [
                                        vendorAvatarUrl != null
                                            ? CircleAvatar(
                                                radius: 28,
                                                backgroundImage: NetworkImage(
                                                  vendorAvatarUrl,
                                                ),
                                              )
                                            : CircleAvatar(
                                                radius: 28,
                                                backgroundColor:
                                                    AppColors.of(context).darkGray,
                                                child: Text(
                                                  widget.vendorName.isNotEmpty
                                                      ? widget.vendorName[0]
                                                            .toUpperCase()
                                                      : '?',
                                                  style: TextStyle(
                                                    color: AppColors.of(context).white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 18,
                                                  ),
                                                ),
                                              ),
                                        if (widget.isVerified)
                                          Positioned(
                                            bottom: 0,
                                            right: 0,
                                            child: Container(
                                              padding: const EdgeInsets.all(2),
                                              decoration: BoxDecoration(
                                                color: AppColors.of(context).white,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                Icons.verified,
                                                color: Colors.blue,
                                                size: 16,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    SizedBox(width: 12),
                                    // Vendor Info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            widget.vendorName,
                                            style: TextStyle(
                                              color: AppColors.of(context).darkGray,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.location_on,
                                                size: 14,
                                                color: AppColors.of(context).mediumGray,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                widget.vendorLocation,
                                                style: TextStyle(
                                                  color: AppColors.of(context).mediumGray,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Rating Badge
                                    if (widget.vendorRating != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.shade50,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.star,
                                              size: 14,
                                              color: Colors.amber.shade700,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              widget.vendorRating!.toString(),
                                              style: TextStyle(
                                                color: AppColors.of(context).primary,
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Bottom Action Button
            if (_showSellerActions)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.of(context).white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _isChatLoading ? null : _startConversation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.of(context).primary,
                      foregroundColor: AppColors.of(context).white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 0,
                    ),
                    icon: _isChatLoading
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: AppColors.of(context).white,
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(
                            Icons.chat_bubble_outline,
                            color: AppColors.of(context).white,
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
      ),
    );
  }
}
