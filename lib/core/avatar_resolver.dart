import 'public_profile_cache.dart';

class AvatarResolver {
  Future<String?> resolveAvatarUrl(int? userId) async {
    final profile = await publicProfileCache.resolvePublicProfile(userId);
    final avatarUrl = profile?.avatarUrl?.trim();
    return (avatarUrl != null && avatarUrl.isNotEmpty) ? avatarUrl : null;
  }

  Future<Map<int, String?>> resolveAvatarUrls(Iterable<int> userIds) async {
    final profiles = await publicProfileCache.resolvePublicProfiles(userIds);
    return {
      for (final entry in profiles.entries)
        entry.key: (() {
          final avatarUrl = entry.value?.avatarUrl?.trim();
          return (avatarUrl != null && avatarUrl.isNotEmpty) ? avatarUrl : null;
        })(),
    };
  }

  void clear() {
    publicProfileCache.clear();
  }
}

final avatarResolver = AvatarResolver();
