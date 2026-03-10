// ─────────────────────────────────────────────────────
// AUTH
// ─────────────────────────────────────────────────────

class AuthUser {
  final int id;
  final String fullName;
  final String email;
  final String registrationNumber;
  final String? phoneNumber;

  const AuthUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.registrationNumber,
    this.phoneNumber,
  });

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
        id: j['id'],
        fullName: j['fullName'],
        email: j['email'],
        registrationNumber: j['registrationNumber'],
        phoneNumber: j['phoneNumber'],
      );
}

class AuthResponse {
  final String token;
  final AuthUser user;

  const AuthResponse({required this.token, required this.user});

  factory AuthResponse.fromJson(Map<String, dynamic> j) => AuthResponse(
        token: j['token'],
        user: AuthUser.fromJson(j['user']),
      );
}

// ─────────────────────────────────────────────────────
// USERS
// ─────────────────────────────────────────────────────

class LocationDto {
  final String? label;
  final double? lat;
  final double? lng;

  const LocationDto({this.label, this.lat, this.lng});

  Map<String, dynamic> toJson() => {'label': label, 'lat': lat, 'lng': lng};

  factory LocationDto.fromJson(Map<String, dynamic> j) => LocationDto(
        label: j['label'],
        lat: j['lat']?.toDouble(),
        lng: j['lng']?.toDouble(),
      );
}

class UserProfile {
  final int id;
  final String fullName;
  final String email;
  final String registrationNumber;
  final String? phoneNumber;
  final String? campus;
  final String? avatarUrl;
  final LocationDto? registeredLocation;
  final LocationDto? alternateLocation;

  const UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.registrationNumber,
    this.phoneNumber,
    this.campus,
    this.avatarUrl,
    this.registeredLocation,
    this.alternateLocation,
  });

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        id: j['id'],
        fullName: j['fullName'],
        email: j['email'],
        registrationNumber: j['registrationNumber'],
        phoneNumber: j['phoneNumber'],
        campus: j['campus'],
        avatarUrl: j['avatarUrl'],
        registeredLocation: j['registeredLocation'] != null
            ? LocationDto.fromJson(j['registeredLocation'])
            : null,
        alternateLocation: j['alternateLocation'] != null
            ? LocationDto.fromJson(j['alternateLocation'])
            : null,
      );
}

class PublicUserProfile {
  final int id;
  final String fullName;
  final String? campus;
  final int activeListingsCount;
  final DateTime memberSince;
  final String? email;
  final String? phoneNumber;

  const PublicUserProfile({
    required this.id,
    required this.fullName,
    this.campus,
    required this.activeListingsCount,
    required this.memberSince,
    this.email,
    this.phoneNumber,
  });

  factory PublicUserProfile.fromJson(Map<String, dynamic> j) =>
      PublicUserProfile(
        id: j['id'],
        fullName: j['fullName'],
        campus: j['campus'],
        activeListingsCount: j['activeListingsCount'],
        memberSince: DateTime.parse(j['memberSince']),
        email: j['email'],
        phoneNumber: j['phoneNumber'],
      );
}

// ─────────────────────────────────────────────────────
// LISTINGS
// ─────────────────────────────────────────────────────

enum ListingStatus { PENDING, ACTIVE, SOLD, DELETED }

class ListingActions {
  final bool canEdit;
  final bool canMarkSold;
  final bool canDelete;
  final bool canRestore;
  final bool canPurge;

  const ListingActions({
    required this.canEdit,
    required this.canMarkSold,
    required this.canDelete,
    required this.canRestore,
    required this.canPurge,
  });

  factory ListingActions.fromJson(Map<String, dynamic> j) => ListingActions(
        canEdit: j['canEdit'] ?? false,
        canMarkSold: j['canMarkSold'] ?? false,
        canDelete: j['canDelete'] ?? false,
        canRestore: j['canRestore'] ?? false,
        canPurge: j['canPurge'] ?? false,
      );
}

class ListingImageResponse {
  final int id;
  final String publicId;
  final String secureUrl;
  final int? width;
  final int? height;
  final int? bytes;
  final String? format;
  final DateTime createdAt;

  const ListingImageResponse({
    required this.id,
    required this.publicId,
    required this.secureUrl,
    this.width,
    this.height,
    this.bytes,
    this.format,
    required this.createdAt,
  });

  factory ListingImageResponse.fromJson(Map<String, dynamic> j) =>
      ListingImageResponse(
        id: j['id'],
        publicId: j['publicId'],
        secureUrl: j['secureUrl'],
        width: j['width'],
        height: j['height'],
        bytes: j['bytes'],
        format: j['format'],
        createdAt: DateTime.parse(j['createdAt']),
      );
}

class ListingResponse {
  final int id;
  final int ownerUserId;
  final String title;
  final int priceUgx;
  final String currency;
  final String categoryCode;
  final String? description;
  final String? locationText;
  final String? campus;
  final ListingStatus status;
  final ListingActions actions;
  final DateTime createdAt;
  final String? primaryImageUrl;
  final List<ListingImageResponse> images;

  const ListingResponse({
    required this.id,
    required this.ownerUserId,
    required this.title,
    required this.priceUgx,
    required this.currency,
    required this.categoryCode,
    this.description,
    this.locationText,
    this.campus,
    required this.status,
    required this.actions,
    required this.createdAt,
    this.primaryImageUrl,
    required this.images,
  });

  factory ListingResponse.fromJson(Map<String, dynamic> j) => ListingResponse(
        id: j['id'],
        ownerUserId: j['ownerUserId'],
        title: j['title'],
        priceUgx: j['priceUgx'],
        currency: j['currency'],
        categoryCode: j['categoryCode'],
        description: j['description'],
        locationText: j['locationText'],
        campus: j['campus'],
        status: ListingStatus.values.byName(j['status']),
        actions: ListingActions.fromJson(j['actions'] ?? {}),
        createdAt: DateTime.parse(j['createdAt']),
        primaryImageUrl: j['primaryImageUrl'],
        images: (j['images'] as List? ?? [])
            .map((e) => ListingImageResponse.fromJson(e))
            .toList(),
      );
}

class ListingCardResponse {
  final int id;
  final String title;
  final int priceUgx;
  final String currency;
  final String categoryCode;
  final String? description;
  final String? locationText;
  final String? campus;
  final String? primaryImageUrl;
  final DateTime createdAt;
  final double? distanceMeters;
  final String? ownerFullName;
  final int? ownerUserId;
  final double? lat;
  final double? lng;

  const ListingCardResponse({
    required this.id,
    required this.title,
    required this.priceUgx,
    required this.currency,
    required this.categoryCode,
    this.description,
    this.locationText,
    this.campus,
    this.primaryImageUrl,
    required this.createdAt,
    this.distanceMeters,
    this.ownerFullName,
    this.ownerUserId,
    this.lat,
    this.lng,
  });

  factory ListingCardResponse.fromJson(Map<String, dynamic> j) =>
      ListingCardResponse(
        id: j['id'],
        title: j['title'],
        priceUgx: j['priceUgx'],
        currency: j['currency'],
        categoryCode: j['categoryCode'],
        description: j['description'],
        locationText: j['locationText'],
        campus: j['campus'],
        primaryImageUrl: j['primaryImageUrl'],
        createdAt: DateTime.parse(j['createdAt']),
        distanceMeters: j['distanceMeters']?.toDouble(),
        ownerFullName: j['ownerFullName'],
        ownerUserId: j['ownerUserId'],
        lat: j['lat']?.toDouble(),
        lng: j['lng']?.toDouble(),
      );
}

class ListingPage {
  final List<ListingCardResponse> items;
  final int page;
  final int size;
  final int total;

  const ListingPage({
    required this.items,
    required this.page,
    required this.size,
    required this.total,
  });

  factory ListingPage.fromJson(Map<String, dynamic> j) => ListingPage(
        items: (j['items'] as List)
            .map((e) => ListingCardResponse.fromJson(e))
            .toList(),
        page: j['page'],
        size: j['size'],
        total: j['total'],
      );
}

// ─────────────────────────────────────────────────────
// CATEGORIES
// ─────────────────────────────────────────────────────

class CategoryResponse {
  final String code;
  final String displayName;
  final String? coverImageUrl;
  final int activeListingCount;
  final String? badge;

  const CategoryResponse({
    required this.code,
    required this.displayName,
    this.coverImageUrl,
    required this.activeListingCount,
    this.badge,
  });

  factory CategoryResponse.fromJson(Map<String, dynamic> j) => CategoryResponse(
        code: j['code'],
        displayName: j['displayName'],
        coverImageUrl: j['coverImageUrl'],
        activeListingCount: j['activeListingCount'],
        badge: j['badge'],
      );
}

// ─────────────────────────────────────────────────────
// BOOKMARKS
// ─────────────────────────────────────────────────────

class BookmarkCardResponse {
  final int id;
  final String title;
  final int priceUgx;
  final String currency;
  final String categoryCode;
  final String? description;
  final String? locationText;
  final String? campus;
  final String? primaryImageUrl;
  final DateTime createdAt;
  final String status;
  final DateTime bookmarkedAt;
  final double? distanceMeters;
  final int? ownerUserId;

  const BookmarkCardResponse({
    required this.id,
    required this.title,
    required this.priceUgx,
    required this.currency,
    required this.categoryCode,
    this.description,
    this.locationText,
    this.campus,
    this.primaryImageUrl,
    required this.createdAt,
    required this.status,
    required this.bookmarkedAt,
    this.distanceMeters,
    this.ownerUserId,
  });

  factory BookmarkCardResponse.fromJson(Map<String, dynamic> j) =>
      BookmarkCardResponse(
        id: j['id'],
        title: j['title'],
        priceUgx: j['priceUgx'],
        currency: j['currency'],
        categoryCode: j['categoryCode'],
        description: j['description'],
        locationText: j['locationText'],
        campus: j['campus'],
        primaryImageUrl: j['primaryImageUrl'],
        createdAt: DateTime.parse(j['createdAt']),
        status: j['status'],
        bookmarkedAt: DateTime.parse(j['bookmarkedAt']),
        distanceMeters: j['distanceMeters']?.toDouble(),
        ownerUserId: j['ownerUserId'],
      );
}

// ─────────────────────────────────────────────────────
// CONVERSATIONS & MESSAGES
// ─────────────────────────────────────────────────────

class ConversationResponse {
  final int id;
  final int listingId;
  final String listingTitle;
  final int inquirerUserId;
  final int posterUserId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ConversationResponse({
    required this.id,
    required this.listingId,
    required this.listingTitle,
    required this.inquirerUserId,
    required this.posterUserId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ConversationResponse.fromJson(Map<String, dynamic> j) =>
      ConversationResponse(
        id: j['id'],
        listingId: j['listingId'],
        listingTitle: j['listingTitle'],
        inquirerUserId: j['inquirerUserId'],
        posterUserId: j['posterUserId'],
        createdAt: DateTime.parse(j['createdAt']),
        updatedAt: DateTime.parse(j['updatedAt']),
      );
}

class ConversationListItem {
  final int id;
  final int listingId;
  final String listingTitle;
  final int counterpartUserId;
  final String counterpartFullName;
  final String counterpartEmail;
  final String? counterpartPhoneNumber;
  final String? counterpartLocationText;
  final String? lastMessageBody;
  final DateTime? lastMessageAt;
  final bool counterpartActiveNow;
  final int unreadCount;

  const ConversationListItem({
    required this.id,
    required this.listingId,
    required this.listingTitle,
    required this.counterpartUserId,
    required this.counterpartFullName,
    required this.counterpartEmail,
    this.counterpartPhoneNumber,
    this.counterpartLocationText,
    this.lastMessageBody,
    this.lastMessageAt,
    required this.counterpartActiveNow,
    this.unreadCount = 0,
  });

  factory ConversationListItem.fromJson(Map<String, dynamic> j) =>
      ConversationListItem(
        id: j['id'],
        listingId: j['listingId'],
        listingTitle: j['listingTitle'],
        counterpartUserId: j['counterpartUserId'],
        counterpartFullName: j['counterpartFullName'],
        counterpartEmail: j['counterpartEmail'],
        counterpartPhoneNumber: j['counterpartPhoneNumber'],
        counterpartLocationText: j['counterpartLocationText'],
        lastMessageBody: j['lastMessageBody'],
        lastMessageAt: j['lastMessageAt'] != null
            ? DateTime.parse(j['lastMessageAt'])
            : null,
        counterpartActiveNow: j['counterpartActiveNow'] ?? false,
        unreadCount: (j['unreadCount'] as int?) ?? 0,
      );
}

class MessageResponse {
  final int id;
  final int conversationId;
  final int senderUserId;
  final String body;
  final DateTime createdAt;

  const MessageResponse({
    required this.id,
    required this.conversationId,
    required this.senderUserId,
    required this.body,
    required this.createdAt,
  });

  factory MessageResponse.fromJson(Map<String, dynamic> j) => MessageResponse(
        id: j['id'],
        conversationId: j['conversationId'],
        senderUserId: j['senderUserId'],
        body: j['body'],
        createdAt: DateTime.parse(j['createdAt']),
      );
}

// ─────────────────────────────────────────────────────
// GEO & LOCATIONS
// ─────────────────────────────────────────────────────

class LocationCheckResponse {
  final String zoneName;
  final String zoneTag;
  final String accessType;
  final int listingCount;
  final String? previousZoneTag;

  const LocationCheckResponse({
    required this.zoneName,
    required this.zoneTag,
    required this.accessType,
    required this.listingCount,
    this.previousZoneTag,
  });

  factory LocationCheckResponse.fromJson(Map<String, dynamic> j) =>
      LocationCheckResponse(
        zoneName: j['zoneName'],
        zoneTag: j['zoneTag'],
        accessType: j['accessType'],
        listingCount: j['listingCount'],
        previousZoneTag: j['previousZoneTag'],
      );
}

// ─────────────────────────────────────────────────────
// CLOUDINARY
// ─────────────────────────────────────────────────────

class CloudinarySignatureResponse {
  final String cloudName;
  final String apiKey;
  final int timestamp;
  final String signature;
  final Map<String, String> params;

  const CloudinarySignatureResponse({
    required this.cloudName,
    required this.apiKey,
    required this.timestamp,
    required this.signature,
    required this.params,
  });

  factory CloudinarySignatureResponse.fromJson(Map<String, dynamic> j) =>
      CloudinarySignatureResponse(
        cloudName: j['cloudName'],
        apiKey: j['apiKey'],
        timestamp: j['timestamp'],
        signature: j['signature'],
        params: (j['params'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, v.toString())) ??
            {},
      );
}
