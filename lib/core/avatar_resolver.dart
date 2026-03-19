import 'dart:async';

import 'api_client.dart';
import '../models/models.dart';

class AvatarResolver {
  final Map<int, _AvatarCacheEntry> _cache = {};
  final Map<int, Future<String?>> _inFlight = {};

  static const Duration _ttl = Duration(minutes: 10);

  Future<String?> resolveAvatarUrl(int? userId) {
    if (userId == null || userId <= 0) return Future.value(null);

    final cached = _cache[userId];
    if (cached != null && !cached.isExpired) {
      return Future.value(cached.avatarUrl);
    }

    final pending = _inFlight[userId];
    if (pending != null) return pending;

    final request = _fetchAndCache(userId);
    _inFlight[userId] = request;
    request.whenComplete(() => _inFlight.remove(userId));
    return request;
  }

  Future<Map<int, String?>> resolveAvatarUrls(Iterable<int> userIds) async {
    final normalized = userIds.where((id) => id > 0).toSet().toList();
    if (normalized.isEmpty) return {};

    final futures = <int, Future<String?>>{};
    for (final id in normalized) {
      futures[id] = resolveAvatarUrl(id);
    }

    final entries = await Future.wait(
      futures.entries.map((entry) async {
        final avatarUrl = await entry.value;
        return MapEntry(entry.key, avatarUrl);
      }),
    );

    return {for (final entry in entries) entry.key: entry.value};
  }

  Future<String?> _fetchAndCache(int userId) async {
    try {
      final resp = await apiClient.dio.get('/users/$userId/public');
      final profile = PublicUserProfile.fromJson(resp.data);
      final avatarUrl = profile.avatarUrl?.trim();
      final resolved = (avatarUrl != null && avatarUrl.isNotEmpty)
          ? avatarUrl
          : null;
      _cache[userId] = _AvatarCacheEntry(
        avatarUrl: resolved,
        expiresAt: DateTime.now().add(_ttl),
      );
      return resolved;
    } catch (_) {
      _cache[userId] = _AvatarCacheEntry(
        avatarUrl: null,
        expiresAt: DateTime.now().add(const Duration(minutes: 2)),
      );
      return null;
    }
  }

  void clear() {
    _cache.clear();
    _inFlight.clear();
  }
}

class _AvatarCacheEntry {
  final String? avatarUrl;
  final DateTime expiresAt;

  const _AvatarCacheEntry({required this.avatarUrl, required this.expiresAt});

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

final avatarResolver = AvatarResolver();
