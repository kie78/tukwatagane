import 'package:flutter/material.dart';
import 'main.dart';
import 'userProfile.dart';
import 'categoryListings.dart';
import 'searchResults.dart';
import 'saved.dart';
import 'widgets/main_nav_bar.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch() {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SearchResultsScreen(searchQuery: query),
        ),
      );
    }
  }

  final List<CategoryItem> categories = [
    CategoryItem(
      name: 'Electronics',
      itemCount: '120 Items',
      imageUrl: 'https://images.unsplash.com/photo-1498049794561-7780e7231661?w=400',
      badge: 'HOT',
      badgeColor: AppColors.teal,
      badgeTextColor: Color(0xFF2D3748),
    ),
    CategoryItem(
      name: 'Baked Goods',
      itemCount: '200+ Items',
      imageUrl: 'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=400',
      highlightCount: true,
    ),
    CategoryItem(
      name: 'Clothing and Footwear',
      itemCount: '350 Items',
      imageUrl: 'https://images.unsplash.com/photo-1445205170230-053b83016050?w=400',
      badge: 'SALE',
      badgeColor: Colors.white,
      badgeTextColor: Color(0xFF2D3748),
    ),
    CategoryItem(
      name: 'Fast Food',
      itemCount: '42 Items',
      imageUrl: 'https://images.unsplash.com/photo-1561758033-d89a9ad46330?w=400',
      highlightCount: true,
    ),
    CategoryItem(
      name: 'Drinks and Beverages',
      itemCount: '60 Items',
      imageUrl: 'https://images.unsplash.com/photo-1544145945-f90425340c7e?w=400',
      highlightCount: true,
    ),
    CategoryItem(
      name: 'Jewelry and Accessories',
      itemCount: '100+ Items',
      imageUrl: 'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?w=400',
      highlightCount: true,
    ),
  ];

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
                backgroundColor: Color(0xFFD4C5B9),
                child: Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Search Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: TextField(
                controller: _searchController,
                onSubmitted: (value) => _performSearch(),
                decoration: InputDecoration(
                  hintText: 'Search for products...',
                  hintStyle: const TextStyle(color: AppColors.mediumGray),
                  prefixIcon: const Icon(Icons.search, color: AppColors.mediumGray),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send, color: AppColors.teal),
                    onPressed: _performSearch,
                  ),
                  filled: true,
                  fillColor: AppColors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.lightGray),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.lightGray),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.teal),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
          // Main Heading
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Text(
                'Discover by Category',
                style: TextStyle(
                  color: AppColors.darkGray,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // Category Grid
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.85,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CategoryListingsScreen(
                            categoryName: categories[index].name,
                            hasListings: false,
                          ),
                        ),
                      );
                    },
                    child: CategoryCard(category: categories[index]),
                  );
                },
                childCount: categories.length,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const MainNavBar(currentIndex: 1),
    );
  }
}

class CategoryItem {
  final String name;
  final String itemCount;
  final String imageUrl;
  final String? badge;
  final Color? badgeColor;
  final Color? badgeTextColor;
  final bool highlightCount;

  CategoryItem({
    required this.name,
    required this.itemCount,
    required this.imageUrl,
    this.badge,
    this.badgeColor,
    this.badgeTextColor,
    this.highlightCount = false,
  });
}

class CategoryCard extends StatelessWidget {
  final CategoryItem category;

  const CategoryCard({
    super.key,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background Image
            Image.network(
              category.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: AppColors.mediumGray,
                  child: Icon(
                    Icons.image,
                    color: Colors.white,
                    size: 48,
                  ),
                );
              },
            ),
            // Dark Gradient Overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.7),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
            // Badge (if any)
            if (category.badge != null)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: category.badgeColor ?? AppColors.teal,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    category.badge!,
                    style: TextStyle(
                      color: category.badgeTextColor ?? Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            // Category Info
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      category.name,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      category.itemCount,
                      style: TextStyle(
                        color: category.highlightCount
                            ? AppColors.teal
                            : Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
