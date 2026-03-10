import 'package:flutter/material.dart';
import 'main.dart';
import 'vendorProfile.dart';
import 'inbox.dart';
import 'core/api_client.dart';
import 'core/auth_service.dart';
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
  int? _ownerUserId;
  int? _myUserId;
  late String _description;

  bool get _isOwnListing =>
      _myUserId != null && _ownerUserId != null && _myUserId == _ownerUserId;

  final List<String> _images = [];

  @override
  void initState() {
    super.initState();
    _description = widget.productDescription.trim();
    // Show the primary image immediately while fetching the full listing
    if (widget.imageUrl != null) _images.add(widget.imageUrl!);
    if (widget.listingId != null) _fetchListingImages();
    authService.getUserId().then((id) {
      if (mounted) setState(() => _myUserId = id);
    });
  }

  Future<void> _fetchListingImages() async {
    bool shouldTryMyListingsFallback = _description.isEmpty;

    try {
      final resp = await apiClient.dio.get('/listings/${widget.listingId}');
      final listing = ListingResponse.fromJson(resp.data);
      final fetchedDescription = (listing.description ?? '').trim();

      if (mounted) {
        setState(() {
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

      shouldTryMyListingsFallback = fetchedDescription.isEmpty && _description.isEmpty;
    } catch (_) {
      // Endpoint may be owner-only (403); widget.imageUrl placeholder already in _images
      shouldTryMyListingsFallback = _description.isEmpty;
    }

    if (shouldTryMyListingsFallback) {
      await _loadDescriptionFromMyListings();
    }
  }

  Future<void> _loadDescriptionFromMyListings() async {
    final listingId = widget.listingId;
    if (listingId == null) return;

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
        if (description.isNotEmpty && mounted) {
          setState(() {
            _description = description;
          });
        }
        break;
      }
    } catch (_) {
      // Ignore fallback failures; UI already handles empty state.
    }
  }

  Future<void> _toggleBookmark() async {
    if (widget.listingId == null) return;
    setState(() => _isBookmarkLoading = true);
    try {
      if (_isBookmarked) {
        await apiClient.dio.delete('/bookmarks', queryParameters: {'listingId': widget.listingId});
        if (mounted) setState(() => _isBookmarked = false);
      } else {
        await apiClient.dio.post('/bookmarks', data: {'listingId': widget.listingId});
        if (mounted) setState(() => _isBookmarked = true);
      }
    } catch (_) {}
    if (mounted) setState(() => _isBookmarkLoading = false);
  }

  Future<void> _startConversation() async {
    if (widget.listingId == null) return;
    setState(() => _isChatLoading = true);
    try {
      final resp = await apiClient.dio.post('/conversations', data: {'listingId': widget.listingId});
      final conv = ConversationResponse.fromJson(resp.data);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => InboxScreen(
              conversationId: conv.id,
              userName: widget.vendorName,
              avatarUrl: widget.vendorAvatar,
              productTitle: widget.productTitle,
              productImage: widget.imageUrl,
              productPrice: widget.price,
              productListingId: widget.listingId,
            ),
          ),
        );
      }
    } catch (_) {
      // Fallback: open with a dummy conversationId of 0 (will fail to load msgs gracefully)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open chat. Please try again.')),
        );
      }
    }
    if (mounted) setState(() => _isChatLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final descriptionText = _description.trim();
    final shouldShowDescriptionToggle =
        descriptionText.length > _descriptionToggleThreshold;

    return Scaffold(
      backgroundColor: AppColors.lightGray,
      body: Stack(
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
                        color: AppColors.lightGray,
                        child: const Center(
                          child: Icon(
                            Icons.image_not_supported_outlined,
                            size: 80,
                            color: AppColors.mediumGray,
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
                                color: AppColors.lightGray,
                                child: const Center(
                                  child: Icon(
                                    Icons.image_not_supported_outlined,
                                    size: 80,
                                    color: AppColors.mediumGray,
                                  ),
                                ),
                              ),
                              loadingBuilder: (_, child, progress) {
                                if (progress == null) return child;
                                return Container(
                                  color: AppColors.lightGray,
                                  child: const Center(
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
                            color: Colors.white.withOpacity(0.9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_back,
                            color: AppColors.darkGray,
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
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _currentImageIndex == index
                                  ? AppColors.teal
                                  : AppColors.lightGray,
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
                      color: AppColors.white,
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
                              color: AppColors.darkGray,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Description
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                descriptionText.isNotEmpty
                                    ? descriptionText
                                    : 'No description provided.',
                                style: TextStyle(
                                  color: AppColors.mediumGray,
                                  fontSize: 15,
                                  height: 1.5,
                                ),
                                maxLines: shouldShowDescriptionToggle && !_isDescriptionExpanded
                                    ? 3
                                    : null,
                                overflow: shouldShowDescriptionToggle && !_isDescriptionExpanded
                                    ? TextOverflow.ellipsis
                                    : null,
                              ),
                              if (shouldShowDescriptionToggle) ...[
                                const SizedBox(height: 8),
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
                                      color: AppColors.teal,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 24),
                          // Price and Bookmark Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'UGX ${widget.price.toString().replaceAllMapped(
                                      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                                      (Match m) => '${m[1]},',
                                    )}',
                                style: TextStyle(
                                  color: AppColors.teal,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (!_isOwnListing)
                              GestureDetector(
                                onTap: _isBookmarkLoading ? null : _toggleBookmark,
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.lightGray,
                                      width: 1,
                                    ),
                                  ),
                                  child: _isBookmarkLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : Icon(
                                          _isBookmarked
                                              ? Icons.bookmark
                                              : Icons.bookmark_border,
                                          color: _isBookmarked
                                              ? AppColors.teal
                                              : AppColors.mediumGray,
                                          size: 24,
                                        ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          // Vendor Information Card
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => VendorProfileScreen(
                                    vendorName: widget.vendorName,
                                    vendorAvatar: widget.vendorAvatar,
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
                                color: AppColors.white,
                                border: Border.all(
                                  color: AppColors.lightGray,
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            child: Row(
                              children: [
                                // Avatar with Verification Badge
                                Stack(
                                  children: [
                                    widget.vendorAvatar != null
                                        ? CircleAvatar(
                                            radius: 28,
                                            backgroundImage: NetworkImage(widget.vendorAvatar!),
                                          )
                                        : CircleAvatar(
                                            radius: 28,
                                            backgroundColor: AppColors.darkGray,
                                            child: Text(
                                              widget.vendorName.isNotEmpty
                                                  ? widget.vendorName[0].toUpperCase()
                                                  : '?',
                                              style: const TextStyle(
                                                color: AppColors.white,
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
                                            color: AppColors.white,
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
                                const SizedBox(width: 12),
                                // Vendor Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.vendorName,
                                        style: TextStyle(
                                          color: AppColors.darkGray,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.location_on,
                                            size: 14,
                                            color: AppColors.mediumGray,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            widget.vendorLocation,
                                            style: TextStyle(
                                              color: AppColors.mediumGray,
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
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.star,
                                        size: 14,
                                        color: Colors.amber.shade700,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        widget.vendorRating!.toString(),
                                        style: TextStyle(
                                          color: AppColors.teal,
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
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Bottom Action Button
          if (!_isOwnListing)
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
                onPressed: _isChatLoading ? null : _startConversation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
                icon: _isChatLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: AppColors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.chat_bubble_outline, color: AppColors.white, size: 20),
                label: const Text(
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
}
