import 'package:flutter/material.dart';
import 'main.dart';
import 'vendorProfile.dart';
import 'inbox.dart';

class ProductDetailsScreen extends StatefulWidget {
  final String productTitle;
  final String productDescription;
  final int price;
  final String imageUrl;
  final String vendorName;
  final String vendorLocation;
  final String vendorAvatar;
  final double vendorRating;
  final bool isVerified;

  const ProductDetailsScreen({
    super.key,
    required this.productTitle,
    required this.productDescription,
    required this.price,
    required this.imageUrl,
    required this.vendorName,
    required this.vendorLocation,
    required this.vendorAvatar,
    this.vendorRating = 4.8,
    this.isVerified = true,
  });

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  int _currentImageIndex = 0;
  bool _isDescriptionExpanded = false;
  bool _isBookmarked = false;

  final List<String> _images = [
    // Will use the main image and duplicate for demo
  ];

  @override
  void initState() {
    super.initState();
    _images.addAll([
      widget.imageUrl,
      widget.imageUrl,
      widget.imageUrl,
    ]);
  }

  @override
  Widget build(BuildContext context) {
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
                                widget.productDescription,
                                style: TextStyle(
                                  color: AppColors.mediumGray,
                                  fontSize: 15,
                                  height: 1.5,
                                ),
                                maxLines: _isDescriptionExpanded ? null : 3,
                                overflow: _isDescriptionExpanded
                                    ? null
                                    : TextOverflow.ellipsis,
                              ),
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
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _isBookmarked = !_isBookmarked;
                                  });
                                },
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
                                  child: Icon(
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
                                    CircleAvatar(
                                      radius: 28,
                                      backgroundImage: NetworkImage(
                                        widget.vendorAvatar,
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
                                        widget.vendorRating.toString(),
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
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => InboxScreen(
                        userName: widget.vendorName,
                        avatarUrl: widget.vendorAvatar,
                        isOnline: true,
                        productTitle: widget.productTitle,
                        productImage: widget.imageUrl,
                        productPrice: widget.price,
                      ),
                    ),
                  );
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
}
