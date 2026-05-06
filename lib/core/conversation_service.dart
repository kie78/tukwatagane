import 'package:dio/dio.dart';

import 'api_client.dart';
import 'auth_service.dart';
import '../models/models.dart';

class ConversationOpenException implements Exception {
  final String message;

  const ConversationOpenException(this.message);

  @override
  String toString() => message;
}

class ConversationOpenResult {
  final int conversationId;
  final int counterpartUserId;

  const ConversationOpenResult({
    required this.conversationId,
    required this.counterpartUserId,
  });
}

class ConversationService {
  Future<ConversationOpenResult> getOrCreateConversation({
    required int listingId,
    int? sellerUserId,
  }) async {
    final resolvedSellerUserId = await _resolveSellerUserId(
      listingId: listingId,
      sellerUserId: sellerUserId,
    );

    if (resolvedSellerUserId != null) {
      final existing = await _findExistingConversationWithSeller(
        resolvedSellerUserId,
      );
      if (existing != null) {
        return ConversationOpenResult(
          conversationId: existing.id,
          counterpartUserId: resolvedSellerUserId,
        );
      }
    }

    final existingForListing = await _findExistingConversationForListing(
      listingId,
    );
    if (existingForListing != null) {
      return ConversationOpenResult(
        conversationId: existingForListing.id,
        counterpartUserId:
            resolvedSellerUserId ?? existingForListing.counterpartUserId,
      );
    }

    await _validateNewConversationTarget(listingId);

    try {
      final resp = await apiClient.dio.post(
        '/conversations',
        data: {'listingId': listingId},
      );
      final created = ConversationResponse.fromJson(resp.data);

      return ConversationOpenResult(
        conversationId: created.id,
        counterpartUserId: resolvedSellerUserId ?? created.posterUserId,
      );
    } on DioException catch (e) {
      throw ConversationOpenException(
        _extractOpenConversationMessage(e) ??
            'Could not open chat. Please try again.',
      );
    }
  }

  Future<void> _validateNewConversationTarget(int listingId) async {
    final listing = await _loadListingForValidation(listingId);
    if (listing == null) {
      throw const ConversationOpenException(
        'This listing is no longer active.',
      );
    }

    if (listing.status != ListingStatus.ACTIVE) {
      throw const ConversationOpenException(
        'This listing is no longer active.',
      );
    }

    final myUserId = await authService.getUserId();
    if (myUserId != null && listing.ownerUserId == myUserId) {
      throw const ConversationOpenException(
        "You can't message your own listing.",
      );
    }
  }

  Future<ListingResponse?> _loadListingForValidation(int listingId) async {
    try {
      final resp = await apiClient.dio.get('/listings/$listingId');
      return ListingResponse.fromJson(resp.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }

  Future<int?> _resolveSellerUserId({
    required int listingId,
    int? sellerUserId,
  }) async {
    if (sellerUserId != null && sellerUserId > 0) {
      return sellerUserId;
    }

    final existing = await _findExistingConversationForListing(listingId);
    if (existing != null) {
      return existing.counterpartUserId;
    }

    try {
      final resp = await apiClient.dio.get('/listings/$listingId');
      final listing = ListingResponse.fromJson(resp.data);
      return listing.ownerUserId;
    } catch (_) {
      return null;
    }
  }

  Future<ConversationListItem?> _findExistingConversationWithSeller(
    int sellerUserId,
  ) async {
    return _findExistingConversation(
      (item) => item.counterpartUserId == sellerUserId,
    );
  }

  Future<ConversationListItem?> _findExistingConversationForListing(
    int listingId,
  ) async {
    return _findExistingConversation((item) => item.listingId == listingId);
  }

  Future<ConversationListItem?> _findExistingConversation(
    bool Function(ConversationListItem item) matches,
  ) async {
    const pageSize = 100;
    var page = 0;

    try {
      while (true) {
        final resp = await apiClient.dio.get(
          '/conversations',
          queryParameters: {'page': page, 'size': pageSize},
        );

        final items = (resp.data['items'] as List)
            .map((e) => ConversationListItem.fromJson(e))
            .toList();
        for (final item in items) {
          if (matches(item)) {
            return item;
          }
        }

        final total = resp.data['total'] as int?;
        if (items.length < pageSize) {
          return null;
        }
        if (total != null && (page + 1) * pageSize >= total) {
          return null;
        }
        page++;
      }
    } catch (_) {
      return null;
    }
  }

  String? _extractOpenConversationMessage(DioException error) {
    final data = error.response?.data;
    if (data is Map) {
      final rawMessage = data['message'] ?? data['error'] ?? data['detail'];
      final message = rawMessage?.toString().trim();
      if (message != null && message.isNotEmpty) {
        return message;
      }
    }
    if (data is String) {
      final message = data.trim();
      if (message.isNotEmpty) {
        return message;
      }
    }
    return null;
  }
}

final conversationService = ConversationService();
