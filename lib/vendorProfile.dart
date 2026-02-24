import 'package:flutter/material.dart';
import 'main.dart';
import 'productDetails.dart';
import 'inbox.dart';

class VendorProfileScreen extends StatelessWidget {
  final String vendorName;
  final String vendorAvatar;
  final String primaryLocation;
  final String registrationNumber;
  final String email;
  final bool isOnline;

  const VendorProfileScreen({
    super.key,
    required this.vendorName,
    required this.vendorAvatar,
    this.primaryLocation = 'Kihumuro Campus',
    this.registrationNumber = '2023/BIT/216/PS',
    this.email = 'eric@must.ac.ug',
    this.isOnline = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGray,
      appBar: AppBar(
        leading: IconButton(
          icon: CircleAvatar(
            backgroundColor: AppColors.lightGray,
            child: Icon(
              Icons.arrow_back,
              color: AppColors.darkGray,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Vendor Profile',
          style: TextStyle(
            color: AppColors.darkGray,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Identity Section
                  Center(
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 60,
                              backgroundImage: NetworkImage(vendorAvatar),
                            ),
                            if (isOnline)
                              Positioned(
                                bottom: 4,
                                right: 4,
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.white,
                                      width: 3,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          vendorName,
                          style: TextStyle(
                            color: AppColors.darkGray,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Verified Credentials Cards
                  _buildCredentialCard(
                    icon: Icons.location_on,
                    title: primaryLocation,
                    subtitle: 'Primary Location',
                    isVerified: false,
                  ),
                  const SizedBox(height: 12),
                  _buildCredentialCard(
                    icon: Icons.badge_outlined,
                    title: registrationNumber,
                    subtitle: 'Reg Number',
                    isVerified: false,
                  ),
                  const SizedBox(height: 12),
                  _buildCredentialCard(
                    icon: Icons.verified_user,
                    title: email,
                    subtitle: 'Email (University verified)',
                    isVerified: true,
                  ),
                  const SizedBox(height: 32),
                  // Items for Sale Section
                  Text(
                    'Items for Sale',
                    style: TextStyle(
                      color: AppColors.darkGray,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildProductTile(
                    title: 'Cotton Linen Shirt',
                    price: 25000,
                    imageUrl: 'https://images.unsplash.com/photo-1596755094514-f87e34085b2c?w=400',
                  ),
                  const SizedBox(height: 12),
                  _buildProductTile(
                    title: '1TB External Hard Drive',
                    price: 180000,
                    imageUrl: 'https://images.unsplash.com/photo-1531492746076-161ca9bcad58?w=400',
                  ),
                  const SizedBox(height: 100), // Space for fixed button
                ],
              ),
            ),
          ),
          // Fixed Message Button
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
                        userName: vendorName,
                        avatarUrl: vendorAvatar,
                        isOnline: isOnline,
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

  Widget _buildCredentialCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isVerified,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.lightGray,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: AppColors.mediumGray,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.darkGray,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.mediumGray,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (isVerified)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.teal,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check,
                color: AppColors.white,
                size: 16,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProductTile({
    required String title,
    required int price,
    required String imageUrl,
  }) {
    return Builder(
      builder: (context) => GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductDetailsScreen(
                productTitle: title,
                productDescription:
                    'This is a high-quality product in excellent condition. Perfect for daily use. Comes with all original accessories and packaging. Well maintained and carefully used.',
                price: price,
                imageUrl: imageUrl,
                vendorName: vendorName,
                vendorLocation: primaryLocation,
                vendorAvatar: vendorAvatar,
                vendorRating: 4.8,
                isVerified: true,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              imageUrl,
              width: 70,
              height: 70,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.darkGray,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'UGX ${price.toString().replaceAllMapped(
                            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                            (Match m) => '${m[1]},',
                          )}',
                      style: TextStyle(
                        color: AppColors.teal,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'ACTIVE',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
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
      ),
    );
  }
}
