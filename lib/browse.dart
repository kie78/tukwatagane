import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'main.dart';
import 'search.dart';
import 'sell.dart';
import 'chat.dart';
import 'account.dart';
import 'userProfile.dart';
import 'productDetails.dart';
import 'vendorProfile.dart';
import 'inbox.dart';
import 'saved.dart';
import 'config/bookmarks_service.dart';

class BrowseScreen extends StatefulWidget {
  const BrowseScreen({super.key});

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGray,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/images/logo.jpg',
              width: 40,
              height: 40,
            ),
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
                MaterialPageRoute(
                  builder: (context) => const SavedScreen(),
                ),
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
                backgroundColor: AppColors.lightGray,
                child: CircleAvatar(
                  radius: 16,
                  backgroundImage: NetworkImage(
                    'https://i.pravatar.cc/150?img=5',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        itemCount: 5,
        itemBuilder: (context, index) {
          return ProductCard(
            productId: 'product_$index',
            sellerName: index == 0 ? 'Sarah Namukasa' : 'John Doe',
            sellerAvatar: 'https://i.pravatar.cc/150?img=${index + 1}',
            timestamp: '${index + 2} hours ago',
            productTitle: index == 0
                ? 'Vintage Denim Jacket'
                : 'Product Item ${index + 1}',
            price: '${45000 + (index * 5000)}',
            location: 'Wandegeya • Kampala',
            imageUrl: 'https://picsum.photos/400/300?random=$index',
            isNew: index == 0,
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => SearchScreen()),
            );
          } else if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => SellScreen()),
            );
          } else if (index == 3) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => ChatScreen()),
            );
          } else if (index == 4) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => AccountScreen()),
            );
          }
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.white,
        selectedItemColor: AppColors.teal,
        unselectedItemColor: AppColors.mediumGray,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          height: 1.0,
        ),
        unselectedLabelStyle: const TextStyle(
          height: 1.0,
        ),
        iconSize: 24,
        elevation: 0,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.list_alt_outlined),
            activeIcon: Icon(Icons.list_alt),
            label: 'Browse',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.search),
            activeIcon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.add_circle_outline,
              color: _currentIndex == 2
                  ? AppColors.teal
                  : AppColors.mediumGray,
            ),
            activeIcon: Icon(Icons.add_circle, color: AppColors.teal),
            label: 'Sell',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Chat',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.account_circle_outlined),
            activeIcon: Icon(Icons.account_circle),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}

class ProductCard extends StatefulWidget {
  final String productId;
  final String sellerName;
  final String sellerAvatar;
  final String timestamp;
  final String productTitle;
  final String price;
  final String location;
  final String imageUrl;
  final bool isNew;

  const ProductCard({
    super.key,
    required this.productId,
    required this.sellerName,
    required this.sellerAvatar,
    required this.timestamp,
    required this.productTitle,
    required this.price,
    required this.location,
    required this.imageUrl,
    this.isNew = false,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  final BookmarksService _bookmarksService = BookmarksService();
  late bool _isBookmarked;

  @override
  void initState() {
    super.initState();
    _isBookmarked = _bookmarksService.isBookmarked(widget.productId);
  }

  void _toggleBookmark() {
    setState(() {
      _bookmarksService.toggleBookmark(widget.productId);
      _isBookmarked = _bookmarksService.isBookmarked(widget.productId);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isBookmarked ? 'Added to bookmarks' : 'Removed from bookmarks',
        ),
        backgroundColor: _isBookmarked ? AppColors.teal : AppColors.mediumGray,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _shareProduct() async {
    final String shareText = '''
${widget.productTitle}
UGX ${widget.price}
📍 ${widget.location}

Check out this item on Tukwatagane!

🔗 tukwatagane://product/${widget.productId}
    ''';

    try {
      await Share.share(
        shareText,
        subject: widget.productTitle,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
              productTitle: widget.productTitle,
              productDescription:
                  'This is a high-quality product in excellent condition. Perfect for daily use. Comes with all original accessories and packaging. Well maintained and carefully used.',
              price: int.parse(widget.price.replaceAll(',', '')),
              imageUrl: widget.imageUrl,
              vendorName: widget.sellerName,
              vendorLocation: widget.location,
              vendorAvatar: widget.sellerAvatar,
              vendorRating: 4.8,
              isVerified: true,
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
              color: Colors.black.withOpacity(0.05),
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
                        ),
                      ),
                    );
                  },
                  child: CircleAvatar(
                    radius: 20,
                    backgroundImage: NetworkImage(widget.sellerAvatar),
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
                  child: Image.network(
                    widget.imageUrl,
                    height: 250,
                    width: double.infinity,
                    fit: BoxFit.cover,
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
                        color: AppColors.darkGray.withOpacity(0.8),
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
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => InboxScreen(
                                userName: widget.sellerName,
                                avatarUrl: widget.sellerAvatar,
                                isOnline: true,
                                productTitle: widget.productTitle,
                                productImage: widget.imageUrl,
                                productPrice: int.parse(widget.price.replaceAll(',', '')),
                              ),
                            ),
                          );
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
                          _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                          color: _isBookmarked ? Colors.black : AppColors.darkGray,
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
