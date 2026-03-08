import 'package:flutter/material.dart';
import 'main.dart';
import 'userProfile.dart';
import 'productDetails.dart';
import 'inbox.dart';
import 'widgets/main_nav_bar.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  final List<SavedItem> _savedItems = [
    SavedItem(
      id: '1',
      title: 'iPhone 12 Pro Max',
      price: 2500000,
      location: 'Kihumuro Campus',
      distance: '300m',
      imageUrl: 'https://images.unsplash.com/photo-1591337676887-a217a6970a8a?w=400',
      isAvailable: true,
    ),
    SavedItem(
      id: '2',
      title: 'Engineering Mathematics',
      price: 50000,
      location: 'Main Library',
      distance: '150m',
      imageUrl: 'https://images.unsplash.com/photo-1543002588-bfa74002ed7e?w=400',
      isAvailable: false,
    ),
    SavedItem(
      id: '4',
      title: 'Smart Watch Series 6',
      price: 850000,
      location: 'Kihumuro Campus',
      distance: '200m',
      imageUrl: 'https://images.unsplash.com/photo-1579586337278-3befd40fd17a?w=400',
      isAvailable: true,
    ),
  ];

  void _removeItem(String id) {
    setState(() {
      _savedItems.removeWhere((item) => item.id == id);
    });
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
            onPressed: () {},
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
                    'https://i.pravatar.cc/150?img=12',
                  ),
                ),
              ),
            ),
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
                    color: AppColors.darkGray,
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
                          color: AppColors.darkGray,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${_savedItems.length} items',
                        style: TextStyle(
                          color: AppColors.mediumGray,
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
            child: _savedItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bookmark_border,
                          size: 80,
                          color: AppColors.mediumGray.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Saved Items',
                          style: TextStyle(
                            color: AppColors.darkGray,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Items you bookmark will appear here',
                          style: TextStyle(
                            color: AppColors.mediumGray,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _savedItems.length,
                    itemBuilder: (context, index) {
                      return _buildSavedItemCard(_savedItems[index]);
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: const MainNavBar(currentIndex: 4),
    );
  }

  Widget _buildSavedItemCard(SavedItem item) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailsScreen(
              productTitle: item.title,
              productDescription:
                  'This is a high-quality product in excellent condition. Perfect for daily use. Comes with all original accessories and packaging. Well maintained and carefully used.',
              price: item.price,
              imageUrl: item.imageUrl,
              vendorName: 'Local Vendor',
              vendorLocation: item.location,
              vendorAvatar: 'https://i.pravatar.cc/150?img=25',
              vendorRating: 4.8,
              isVerified: true,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
                  child: Image.network(
                    item.imageUrl,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        item.title,
                        style: TextStyle(
                          color: AppColors.darkGray,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      // Price
                      Text(
                        'UGX ${item.price.toString().replaceAllMapped(
                              RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                              (Match m) => '${m[1]},',
                            )}',
                        style: TextStyle(
                          color: AppColors.teal,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Location with distance
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: AppColors.mediumGray,
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              '${item.location} - ${item.distance}',
                              style: TextStyle(
                                color: AppColors.mediumGray,
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
                    onPressed: () => _removeItem(item.id),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.mediumGray,
                      side: BorderSide(
                        color: AppColors.lightGray,
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
                      color: AppColors.mediumGray,
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
                      color: item.isAvailable
                          ? Colors.green.shade50
                          : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        item.isAvailable ? 'Available' : 'Sold',
                        style: TextStyle(
                          color: item.isAvailable
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
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: item.isAvailable ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => InboxScreen(
                            userName: 'Local Vendor',
                            avatarUrl: 'https://i.pravatar.cc/150?img=25',
                            isOnline: true,
                            productTitle: item.title,
                            productImage: item.imageUrl,
                            productPrice: item.price,
                          ),
                        ),
                      );
                    } : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: item.isAvailable
                          ? AppColors.teal
                          : AppColors.lightGray,
                      foregroundColor: item.isAvailable
                          ? AppColors.white
                          : AppColors.mediumGray,
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
                      color: item.isAvailable
                          ? AppColors.white
                          : AppColors.mediumGray,
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

class SavedItem {
  final String id;
  final String title;
  final int price;
  final String location;
  final String distance;
  final String imageUrl;
  final bool isAvailable;

  SavedItem({
    required this.id,
    required this.title,
    required this.price,
    required this.location,
    required this.distance,
    required this.imageUrl,
    required this.isAvailable,
  });
}
