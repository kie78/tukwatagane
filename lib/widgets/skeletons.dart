import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../main.dart';

/// Wraps [child] in a shimmer animation so all skeleton items animate in sync.
class SkeletonShimmer extends StatelessWidget {
  final Widget child;
  const SkeletonShimmer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.of(context).lightGray,
      highlightColor: const Color(0xFFF7FAFC),
      child: child,
    );
  }
}

/// Skeleton for [ProductCard] — tall card used in browse, categoryListings,
/// and searchResults.
class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.of(context).white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Seller header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.of(context).lightGray,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _pill(context, width: 100, height: 12),
                    const SizedBox(height: 6),
                    _pill(context, width: 60, height: 10),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Image
            Container(
              height: 250,
              decoration: BoxDecoration(
                color: AppColors.of(context).lightGray,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 16),
            _pill(context, width: 200, height: 16),
            const SizedBox(height: 8),
            _pill(context, width: 100, height: 20),
            const SizedBox(height: 8),
            _pill(context, width: 140, height: 12),
            const SizedBox(height: 16),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.of(context).lightGray,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _squareButton(context),
                const SizedBox(width: 8),
                _squareButton(context),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(BuildContext context, {required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.of(context).lightGray,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }

  Widget _squareButton(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.of(context).lightGray,
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}

/// Skeleton for the saved-item card (horizontal: 100×100 thumb + info stubs).
class SavedCardSkeleton extends StatelessWidget {
  const SavedCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.of(context).white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.of(context).lightGray,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _pill(context, width: 80, height: 12),
                  const SizedBox(height: 8),
                  _pill(context, width: double.infinity, height: 14),
                  const SizedBox(height: 6),
                  _pill(context, width: 100, height: 14),
                  const SizedBox(height: 6),
                  _pill(context, width: 120, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(BuildContext context, {required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.of(context).lightGray,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

/// Skeleton for the myListings card (horizontal: 80×80 thumb + info stubs).
class MyListingCardSkeleton extends StatelessWidget {
  const MyListingCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.of(context).white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.of(context).lightGray,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _pill(context, width: double.infinity, height: 14),
                  const SizedBox(height: 6),
                  _pill(context, width: 160, height: 12),
                  const SizedBox(height: 6),
                  _pill(context, width: 100, height: 12),
                  const SizedBox(height: 8),
                  _pill(context, width: 80, height: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(BuildContext context, {required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.of(context).lightGray,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

/// Skeleton for a vendor profile listing tile (70×70 thumb + title/price row).
class VendorListingTileSkeleton extends StatelessWidget {
  const VendorListingTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.of(context).white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: AppColors.of(context).lightGray,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _pill(context, width: double.infinity, height: 14),
                const SizedBox(height: 6),
                _pill(context, width: 160, height: 14),
                const SizedBox(height: 8),
                _pill(context, width: 80, height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(BuildContext context, {required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.of(context).lightGray,
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

/// Full-page skeleton for [UserProfileScreen] while the profile data loads.
class UserProfileSkeleton extends StatelessWidget {
  const UserProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.of(context).lightGray,
      appBar: AppBar(),
      body: SkeletonShimmer(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // "Profile" heading stub
              Container(
                width: 120,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.of(context).white,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 24),
              // Avatar circle
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.of(context).white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Name stub
              Center(
                child: Container(
                  width: 160,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppColors.of(context).white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Sub-line stub
              Center(
                child: Container(
                  width: 100,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.of(context).white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Info rows
              for (int i = 0; i < 4; i++) ...[
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.of(context).white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: const SizedBox(height: 60),
    );
  }
}

/// Skeleton for a category card in the 2-column grid (matches [CategoryCard]).
class CategoryCardSkeleton extends StatelessWidget {
  const CategoryCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.of(context).lightGray,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Text stubs at the bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 100,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.of(context).mediumGray,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 60,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.of(context).mediumGray,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton for a chat conversation tile.
class ChatTileSkeleton extends StatelessWidget {
  const ChatTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.of(context).white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.of(context).lightGray,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 120,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.of(context).lightGray,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.of(context).lightGray,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
