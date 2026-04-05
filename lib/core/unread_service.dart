import 'api_client.dart';

class UnreadService {
  static const Duration _minRefreshInterval = Duration(milliseconds: 400);
  static const Duration _networkTimeout = Duration(seconds: 6);

  int? _lastKnownCount;
  DateTime? _lastFetchedAt;
  Future<int?>? _inFlightFetch;

  /// Coerces any num-like value to int, returning null for anything else.
  static int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  /// Recursively searches a JSON structure for the first integer-like value
  /// associated with a known unread-count key, then falls back to the first
  /// integer-like value found anywhere in the tree.
  static int? _extractUnreadCount(dynamic data) {
    if (data == null) return null;
    final quick = _asInt(data);
    if (quick != null) return quick;

    if (data is Map) {
      for (final key in const ['count', 'unreadCount', 'total', 'unread']) {
        final v = _asInt(data[key]);
        if (v != null) return v;
      }
      // Recurse into nested maps
      for (final v in data.values) {
        final r = _extractUnreadCount(v);
        if (r != null) return r;
      }
    }

    if (data is List) {
      for (final v in data) {
        final r = _extractUnreadCount(v);
        if (r != null) return r;
      }
    }

    return null;
  }

  Future<int?> fetchUnreadSummary() async {
    final resp = await apiClient.dio
        .get('/messages/unread-summary')
        .timeout(_networkTimeout);
    return _extractUnreadCount(resp.data);
  }

  bool _isCacheFresh() {
    final fetchedAt = _lastFetchedAt;
    if (fetchedAt == null) return false;
    return DateTime.now().difference(fetchedAt) < _minRefreshInterval;
  }

  Future<int?> _fetchAndCache() async {
    try {
      final count = await fetchUnreadSummary();
      if (count != null) {
        _lastKnownCount = count;
        _lastFetchedAt = DateTime.now();
      }
      return count;
    } finally {
      _inFlightFetch = null;
    }
  }

  Future<int> refreshUnreadCount({
    required int fallbackCount,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _lastKnownCount != null && _isCacheFresh()) {
      return _lastKnownCount!;
    }

    final inFlight = _inFlightFetch;
    if (!forceRefresh && inFlight != null) {
      final count = await inFlight;
      return count ?? _lastKnownCount ?? fallbackCount;
    }

    final fetchFuture = _fetchAndCache();
    _inFlightFetch = fetchFuture;

    try {
      final count = await fetchFuture;
      if (count != null) return count;
    } catch (_) {}

    return _lastKnownCount ?? fallbackCount;
  }
}

final unreadService = UnreadService();
