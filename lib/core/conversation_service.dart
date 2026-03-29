import 'api_client.dart';
import '../models/models.dart';

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
    if (sellerUserId != null && sellerUserId > 0) {
      final existing = await _findExistingConversationWithSeller(sellerUserId);
      if (existing != null) {
        return ConversationOpenResult(
          conversationId: existing.id,
          counterpartUserId: sellerUserId,
        );
      }
    }

    final resp = await apiClient.dio.post(
      '/conversations',
      data: {'listingId': listingId},
    );
    final created = ConversationResponse.fromJson(resp.data);

    return ConversationOpenResult(
      conversationId: created.id,
      counterpartUserId: sellerUserId ?? created.posterUserId,
    );
  }

  Future<ConversationListItem?> _findExistingConversationWithSeller(
    int sellerUserId,
  ) async {
    final resp = await apiClient.dio.get(
      '/conversations',
      queryParameters: {'page': 0, 'size': 100},
    );

    final items = (resp.data['items'] as List)
        .map((e) => ConversationListItem.fromJson(e))
        .toList();

    for (final item in items) {
      if (item.counterpartUserId == sellerUserId) {
        return item;
      }
    }
    return null;
  }
}

final conversationService = ConversationService();
