import 'package:flutter/material.dart';
import 'main.dart';
import 'userProfile.dart';
import 'browse.dart';
import 'search.dart';
import 'sell.dart';
import 'chat.dart';
import 'account.dart';
import 'saved.dart';

class MyListingsScreen extends StatefulWidget {
  const MyListingsScreen({super.key});

  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen> {
  int _currentIndex = 4;
  String _selectedFilter = 'All';

  final List<ListingItem> _allListings = [
    ListingItem(
      id: '1',
      title: 'Vintage Nike Air Max 90',
      description: 'Rare colorway, excellent condition, size 10',
      location: 'Kampala',
      price: 145000,
      imageUrl: 'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=400',
      status: ListingStatus.active,
    ),
    ListingItem(
      id: '2',
      title: 'iPhone X',
      description: '64GB, Space Gray, unlocked, no scratches',
      location: 'Nakawa',
      price: 800000,
      imageUrl: 'https://images.unsplash.com/photo-1510557880182-3d4d3cba35a5?w=400',
      status: ListingStatus.sold,
    ),
    ListingItem(
      id: '3',
      title: 'L-Shaped Sofa Set',
      description: 'Modern design, gray fabric, 5 seater',
      location: 'Entebbe',
      price: 350000,
      imageUrl: 'https://images.unsplash.com/photo-1555041469-a586c61ea9bc?w=400',
      status: ListingStatus.deleted,
    ),
    ListingItem(
      id: '4',
      title: 'MacBook Pro 2019',
      description: '13-inch, 256GB SSD, 8GB RAM, i5',
      location: 'Kampala',
      price: 2500000,
      imageUrl: 'https://images.unsplash.com/photo-1517336714731-489689fd1ca8?w=400',
      status: ListingStatus.active,
    ),
    ListingItem(
      id: '5',
      title: 'Canon EOS 80D Camera',
      description: 'DSLR with 18-55mm lens, excellent condition',
      location: 'Kampala',
      price: 1200000,
      imageUrl: 'https://images.unsplash.com/photo-1502920917128-1aa500764cbd?w=400',
      status: ListingStatus.sold,
    ),
  ];

  List<ListingItem> get _filteredListings {
    if (_selectedFilter == 'All') {
      return _allListings;
    } else if (_selectedFilter == 'Active') {
      return _allListings.where((item) => item.status == ListingStatus.active).toList();
    } else if (_selectedFilter == 'Sold') {
      return _allListings.where((item) => item.status == ListingStatus.sold).toList();
    } else if (_selectedFilter == 'Deleted') {
      return _allListings.where((item) => item.status == ListingStatus.deleted).toList();
    }
    return _allListings;
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
                    'https://i.pravatar.cc/150?img=47',
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
          // Screen Title with Back Button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => AccountScreen()),
                    );
                  },
                  child: Icon(
                    Icons.arrow_back,
                    color: AppColors.darkGray,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'My Listings',
                  style: TextStyle(
                    color: AppColors.darkGray,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          // Status Filter Tabs
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildFilterChip('All'),
                const SizedBox(width: 8),
                _buildFilterChip('Active'),
                const SizedBox(width: 8),
                _buildFilterChip('Sold'),
                const SizedBox(width: 8),
                _buildFilterChip('Deleted'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Listings
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filteredListings.length,
              itemBuilder: (context, index) {
                return _buildListingCard(_filteredListings[index]);
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => BrowseScreen()),
            );
          } else if (index == 1) {
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

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.teal : AppColors.white,
          border: Border.all(
            color: isSelected ? AppColors.teal : AppColors.lightGray,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.white : AppColors.darkGray,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildListingCard(ListingItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
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
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    item.imageUrl,
                    width: 80,
                    height: 80,
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // Description
                      Text(
                        item.description,
                        style: TextStyle(
                          color: AppColors.mediumGray,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // Location
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: AppColors.mediumGray,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            item.location,
                            style: TextStyle(
                              color: AppColors.mediumGray,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Price
                      Text(
                        'UGX ${item.price.toString().replaceAllMapped(
                              RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                              (Match m) => '${m[1]},',
                            )}',
                        style: TextStyle(
                          color: item.status == ListingStatus.sold
                              ? AppColors.mediumGray
                              : item.status == ListingStatus.deleted
                                  ? Colors.red
                                  : AppColors.teal,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          decoration: item.status == ListingStatus.deleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Actions Row - Full Width
            if (item.status == ListingStatus.deleted)
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.restore,
                      label: 'Restore',
                      onTap: () {
                        _showConfirmationDialog(
                          context: context,
                          title: 'Restore Listing',
                          message: 'Do you want to restore this listing?',
                          onConfirm: () {
                            setState(() {
                              item.status = ListingStatus.active;
                            });
                          },
                        );
                      },
                      hasBorder: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.close,
                      label: 'Purge',
                      onTap: () {
                        _showConfirmationDialog(
                          context: context,
                          title: 'Purge Listing',
                          message: 'This will permanently delete this listing. Continue?',
                          onConfirm: () {
                            setState(() {
                              _allListings.removeWhere((listing) => listing.id == item.id);
                            });
                          },
                        );
                      },
                      hasBorder: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Status Badge
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          'DELETED',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.edit_outlined,
                      label: 'Edit',
                      onTap: item.status == ListingStatus.sold ? null : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SellScreen(
                              editingItemId: item.id,
                              editingTitle: item.title,
                              editingPrice: item.price.toString(),
                              editingCategory: null, // You can add category to ListingItem if needed
                              editingDescription: item.description,
                              editingLocation: item.location,
                              editingImageUrl: item.imageUrl,
                            ),
                          ),
                        );
                      },
                      isDisabled: item.status == ListingStatus.sold,
                      hasBorder: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.delete_outline,
                      label: 'Delete',
                      onTap: item.status == ListingStatus.sold
                          ? null
                          : () {
                              _showConfirmationDialog(
                                context: context,
                                title: 'Delete Listing',
                                message: 'Are you sure you want to delete this listing?',
                                onConfirm: () {
                                  setState(() {
                                    item.status = ListingStatus.deleted;
                                  });
                                },
                              );
                            },
                      isDisabled: item.status == ListingStatus.sold,
                      hasBorder: true,
                    ),
                  ),
                  if (item.status == ListingStatus.active) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildActionButton(
                        icon: Icons.check_circle_outline,
                        label: 'Sell',
                        onTap: () {
                          _showConfirmationDialog(
                            context: context,
                            title: 'Mark as Sold',
                            message: 'Mark this listing as sold?',
                            onConfirm: () {
                              setState(() {
                                item.status = ListingStatus.sold;
                              });
                            },
                          );
                        },
                        hasBorder: true,
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  // Status Badge
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: item.status == ListingStatus.active
                            ? AppColors.lightGray
                            : AppColors.lightGray,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          item.status == ListingStatus.active
                              ? 'ACTIVE'
                              : 'SOLD',
                          style: TextStyle(
                            color: AppColors.teal,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool isDisabled = false,
    bool hasBorder = false,
  }) {
    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 8,
        ),
        decoration: hasBorder
            ? BoxDecoration(
                color: Colors.transparent,
                border: Border.all(
                  color: isDisabled
                      ? AppColors.lightGray
                      : AppColors.mediumGray.withOpacity(0.3),
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(6),
              )
            : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isDisabled
                  ? AppColors.mediumGray.withOpacity(0.4)
                  : AppColors.mediumGray,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: isDisabled
                      ? AppColors.mediumGray.withOpacity(0.4)
                      : AppColors.mediumGray,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showConfirmationDialog({
    required BuildContext context,
    required String title,
    required String message,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            title,
            style: TextStyle(
              color: AppColors.darkGray,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: Text(
            message,
            style: TextStyle(
              color: AppColors.mediumGray,
              fontSize: 15,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text(
                'No',
                style: TextStyle(
                  color: AppColors.mediumGray,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onConfirm();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.teal,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: Text(
                'Yes',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        );
      },
    );
  }
}

enum ListingStatus {
  active,
  sold,
  deleted,
}

class ListingItem {
  final String id;
  final String title;
  final String description;
  final String location;
  final int price;
  final String imageUrl;
  ListingStatus status;

  ListingItem({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.price,
    required this.imageUrl,
    required this.status,
  });
}
