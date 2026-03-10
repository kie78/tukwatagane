import 'package:flutter/material.dart';
import 'main.dart';
import 'sell.dart';
import 'saved.dart';
import 'widgets/main_nav_bar.dart';
import 'core/api_client.dart';
import 'models/models.dart';

class MyListingsScreen extends StatefulWidget {
  const MyListingsScreen({super.key});

  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen> with RouteAware {
  String _selectedFilter = 'All';
  List<ListingResponse> _allListings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
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
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final resp = await apiClient.dio.get('/listings/my', queryParameters: {'status': 'ALL'});
      final items = (resp.data['items'] as List)
          .map((e) => ListingResponse.fromJson(e))
          .toList();
      if (mounted) setState(() => _allListings = items);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  List<ListingResponse> get _filteredListings {
    if (_selectedFilter == 'All') return _allListings;
    if (_selectedFilter == 'Active') return _allListings.where((item) => item.status == ListingStatus.ACTIVE).toList();
    if (_selectedFilter == 'Sold') return _allListings.where((item) => item.status == ListingStatus.SOLD).toList();
    if (_selectedFilter == 'Deleted') return _allListings.where((item) => item.status == ListingStatus.DELETED).toList();
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
                    Navigator.pushReplacementNamed(context, '/account');
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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredListings.length,
                      itemBuilder: (context, index) {
                        return _buildListingCard(_filteredListings[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: const MainNavBar(currentIndex: 4),
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

  Widget _buildListingCard(ListingResponse item) {
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
                  child: item.primaryImageUrl != null
                    ? Image.network(
                        item.primaryImageUrl!,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        width: 80,
                        height: 80,
                        color: AppColors.lightGray,
                        child: const Icon(
                          Icons.image_not_supported_outlined,
                          color: AppColors.mediumGray,
                          size: 28,
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      // Description
                      Text(
                        item.description ?? '',
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
                            item.locationText ?? item.campus ?? 'MUST Campus',
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
                        'UGX ${item.priceUgx.toString().replaceAllMapped(
                              RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                              (Match m) => '${m[1]},',
                            )}',
                        style: TextStyle(
                          color: item.status == ListingStatus.SOLD
                              ? AppColors.mediumGray
                              : item.status == ListingStatus.DELETED
                                  ? Colors.red
                                  : AppColors.teal,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          decoration: item.status == ListingStatus.DELETED
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
            if (item.status == ListingStatus.DELETED)
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
                          onConfirm: () async {
                            try {
                              await apiClient.dio.post('/listings/${item.id}/restore');
                              _load();
                            } catch (_) {}
                          },
                        );
                      },
                      color: Color(0xFFF57C00),
                      hasBorder: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.delete_forever,
                      label: 'Purge',
                      onTap: () {
                        _showConfirmationDialog(
                          context: context,
                          title: 'Purge Listing',
                          message: 'This will permanently delete this listing. Continue?',
                          onConfirm: () async {
                            try {
                              await apiClient.dio.post('/listings/${item.id}/purge');
                              _load();
                            } catch (_) {}
                          },
                        );
                      },
                      color: Color(0xFFB71C1C),
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
                            color: Color(0xFFD32F2F),
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
                      onTap: item.status == ListingStatus.SOLD ? null : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SellScreen(
                              editingItemId: item.id.toString(),
                              editingTitle: item.title,
                              editingPrice: item.priceUgx.toString(),
                              editingCategory: null,
                              editingDescription: item.description,
                              editingLocation: item.locationText ?? item.campus,
                              editingImageUrl: item.primaryImageUrl,
                            ),
                          ),
                        );
                      },
                      color: Color(0xFF1976D2),
                      isDisabled: item.status == ListingStatus.SOLD,
                      hasBorder: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.delete_outline,
                      label: 'Delete',
                      onTap: item.status == ListingStatus.SOLD
                          ? null
                          : () {
                              _showConfirmationDialog(
                                context: context,
                                title: 'Delete Listing',
                                message: 'Are you sure you want to delete this listing?',
                                onConfirm: () async {
                                  try {
                                    await apiClient.dio.post('/listings/${item.id}/delete');
                                    _load();
                                  } catch (_) {}
                                },
                              );
                            },
                      color: Color(0xFFD32F2F),
                      isDisabled: item.status == ListingStatus.SOLD,
                      hasBorder: true,
                    ),
                  ),
                  if (item.status == ListingStatus.ACTIVE) ...[
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
                            onConfirm: () async {
                              try {
                                await apiClient.dio.post('/listings/${item.id}/sold');
                                _load();
                              } catch (_) {}
                            },
                          );
                        },
                        color: Color(0xFF2E7D32),
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
                        color: item.status == ListingStatus.ACTIVE
                            ? Color(0xFFE8F5E9)
                            : Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          item.status == ListingStatus.ACTIVE
                              ? 'ACTIVE'
                              : 'SOLD',
                          style: TextStyle(
                            color: item.status == ListingStatus.ACTIVE
                                ? Color(0xFF2E7D32)
                                : AppColors.mediumGray,
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
    required Color color,
    bool isDisabled = false,
    bool hasBorder = false,
  }) {
    final effectiveColor = isDisabled ? AppColors.mediumGray.withOpacity(0.4) : color;
    
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
                      : effectiveColor.withOpacity(0.5),
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
              color: effectiveColor,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: effectiveColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
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

