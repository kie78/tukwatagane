import 'package:flutter/material.dart';
import 'main.dart';
import 'productDetails.dart';
import 'inbox.dart';
import 'widgets/main_nav_bar.dart';
import 'core/api_client.dart';
import 'core/auth_service.dart';
import 'models/models.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> with RouteAware {
  List<BookmarkCardResponse> _savedItems = [];
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
      final resp = await apiClient.dio.get('/bookmarks', queryParameters: {'page': 0, 'size': 50});
      final items = (resp.data['items'] as List)
          .map((e) => BookmarkCardResponse.fromJson(e))
          .toList();
      if (mounted) setState(() => _savedItems = items);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _removeItem(int listingId) async {
    try {
      await apiClient.dio.delete('/bookmarks', queryParameters: {'listingId': listingId});
      if (mounted) {
        setState(() => _savedItems.removeWhere((item) => item.id == listingId));
      }
    } catch (_) {}
  }

  Future<void> _startChat(BookmarkCardResponse item) async {
    try {
      final resp = await apiClient.dio.post('/conversations', data: {'listingId': item.id});
      final conv = ConversationResponse.fromJson(resp.data);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => InboxScreen(
            conversationId: conv.id,
            userName: 'Seller',
            isOnline: false,
            productTitle: item.title,
            productImage: item.primaryImageUrl,
            productPrice: item.priceUgx,
            productListingId: item.id,
          ),
        ),
      );
    } catch (_) {}
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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _savedItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.bookmark_border,
                          size: 80,
                          color: AppColors.mediumGray.withValues(alpha: 0.5),
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
              vendorName: '',
              vendorLocation: item.campus ?? item.locationText ?? '',
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
                        color: AppColors.lightGray,
                        child: const Icon(
                          Icons.image_not_supported_outlined,
                          color: AppColors.mediumGray,
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
                        'UGX ${item.priceUgx.toString().replaceAllMapped(
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
                              item.campus ?? item.locationText ?? 'MUST Campus',
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
                if (_myUserId == null || item.ownerUserId != _myUserId)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isAvailable ? () => _startChat(item) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isAvailable
                          ? AppColors.teal
                          : AppColors.lightGray,
                      foregroundColor: isAvailable
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
                      color: isAvailable
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
