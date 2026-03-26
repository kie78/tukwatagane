import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api_client.dart';
import '../models/models.dart';

class PublicProfileCache {
  final Map<int, _PublicProfileCacheEntry> _cache = {};
  final Map<int, Future<PublicUserProfile?>> _inFlight = {};

  int _cacheHits = 0;
  int _cacheMisses = 0;
  int _inFlightJoins = 0;
  int _networkFetches = 0;

  static const Duration _ttl = Duration(minutes: 10);
  static const Duration _errorTtl = Duration(minutes: 2);

  Future<PublicUserProfile?> resolvePublicProfile(int? userId) {
    if (userId == null || userId <= 0) return Future.value(null);

    final cached = _cache[userId];
    if (cached != null && !cached.isExpired) {
      _cacheHits++;
      _logDebugStatsIfNeeded();
      return Future.value(cached.profile);
    }

    final pending = _inFlight[userId];
    if (pending != null) {
      _inFlightJoins++;
      _logDebugStatsIfNeeded();
      return pending;
    }

    _cacheMisses++;
    _logDebugStatsIfNeeded();

    final request = _fetchAndCache(userId);
    _inFlight[userId] = request;
    request.whenComplete(() => _inFlight.remove(userId));
    return request;
  }

  Future<Map<int, PublicUserProfile?>> resolvePublicProfiles(
    Iterable<int> userIds,
  ) async {
    final normalized = userIds.where((id) => id > 0).toSet().toList();
    if (normalized.isEmpty) return {};

    final entries = await Future.wait(
      normalized.map((id) async {
        final profile = await resolvePublicProfile(id);
        return MapEntry(id, profile);
      }),
    );

    return {for (final entry in entries) entry.key: entry.value};
  }

  Future<PublicUserProfile?> _fetchAndCache(int userId) async {
    _networkFetches++;
    try {
      final resp = await apiClient.dio.get('/users/$userId/public');
      final profile = PublicUserProfile.fromJson(resp.data);
      _cache[userId] = _PublicProfileCacheEntry(
        profile: profile,
        expiresAt: DateTime.now().add(_ttl),
      );
      return profile;
    } catch (_) {
      _cache[userId] = _PublicProfileCacheEntry(
        profile: null,
        expiresAt: DateTime.now().add(_errorTtl),
      );
      return null;
    } finally {
      _logDebugStatsIfNeeded();
    }
  }

  String debugStats() {
    final resolvedFromMemory = _cacheHits + _inFlightJoins;
    final totalResolutions = resolvedFromMemory + _cacheMisses;
    final hitRate = totalResolutions == 0
        ? 0
        : ((resolvedFromMemory * 100) ~/ totalResolutions);
    return 'PublicProfileCache(stats: hits=$_cacheHits, joins=$_inFlightJoins, misses=$_cacheMisses, fetches=$_networkFetches, hitRate=${hitRate}%)';
  }

  void logDebugStats([String context = '']) {
    if (!kDebugMode) return;
    final prefix = context.trim().isEmpty ? '' : '[$context] ';
    debugPrint('$prefix${debugStats()}');
  }

  void resetDebugStats() {
    _cacheHits = 0;
    _cacheMisses = 0;
    _inFlightJoins = 0;
    _networkFetches = 0;
  }

  void _logDebugStatsIfNeeded() {
    if (!kDebugMode) return;
    final samples = _cacheHits + _cacheMisses + _inFlightJoins;
    if (samples > 0 && samples % 20 == 0) {
      debugPrint(debugStats());
    }
  }

  void clear() {
    _cache.clear();
    _inFlight.clear();
    resetDebugStats();
  }
}

class _PublicProfileCacheEntry {
  final PublicUserProfile? profile;
  final DateTime expiresAt;

  const _PublicProfileCacheEntry({
    required this.profile,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

final publicProfileCache = PublicProfileCache();
