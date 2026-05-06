import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'main.dart';
import 'vendorProfile.dart';
import 'productDetails.dart';
import 'package:url_launcher/url_launcher.dart';
import 'core/api_client.dart';
import 'core/avatar_resolver.dart';
import 'core/auth_service.dart';
import 'core/api_exception.dart';
import 'core/message_realtime_service.dart';
import 'core/public_profile_cache.dart';
import 'core/stomp_service.dart';
import 'core/unread_service.dart';
import 'core/ui/app_toast.dart';
import 'models/models.dart';

class InboxScreen extends StatefulWidget {
  final int conversationId;
  final String userName;
  final String? avatarUrl;
  final bool isOnline;
  final String? businessName;
  final String? initials;
  final String? phoneNumber;
  final String? productTitle;
  final String? productImage;
  final int? productPrice;
  final int? productListingId;
  final bool armProductReferenceOnOpen;
  final int? counterpartUserId;

  const InboxScreen({
    super.key,
    required this.conversationId,
    required this.userName,
    this.avatarUrl,
    this.isOnline = false,
    this.businessName,
    this.initials,
    this.phoneNumber,
    this.productTitle,
    this.productImage,
    this.productPrice,
    this.productListingId,
    this.armProductReferenceOnOpen = false,
    this.counterpartUserId,
  });

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _ReferencedListingPreview {
  final int listingId;
  final String title;
  final String? imageUrl;
  final int? price;

  const _ReferencedListingPreview({
    required this.listingId,
    required this.title,
    this.imageUrl,
    this.price,
  });
}

class _InboxScreenState extends State<InboxScreen> with RouteAware {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<MessageResponse> _messages = [];
  final Map<int, _ReferencedListingPreview> _referencedListingPreviews = {};
  final Set<int> _loadingReferencedListingIds = <int>{};
  int? _myUserId;
  int? _pendingReferencedListingId;
  StompUnsubscribe? _stompUnsub;
  int _tempMsgId = -1; // local counter for optimistic message IDs
  int _pendingEchos = 0; // optimistic messages awaiting STOMP confirmation
  bool _markingAsRead = false;
  bool _refreshingUnread = false;
  Timer? _unreadRefreshDebounce;

  String? _resolvedAvatarUrl;
  String? _resolvedPhoneNumber;

  String get _displayInitials {
    final provided = widget.initials?.trim();
    if (provided != null && provided.isNotEmpty) {
      return provided.toUpperCase();
    }

    final parts = widget.userName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.characters.first.toUpperCase();
    }
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  String? get _effectiveAvatarUrl {
    final resolved = _resolvedAvatarUrl?.trim();
    if (resolved != null && resolved.isNotEmpty) return resolved;
    final provided = widget.avatarUrl?.trim();
    if (provided != null && provided.isNotEmpty) return provided;
    return null;
  }

  String? get _effectivePhoneNumber {
    final resolved = _resolvedPhoneNumber?.trim();
    if (resolved != null && resolved.isNotEmpty) return resolved;
    final provided = widget.phoneNumber?.trim();
    if (provided != null && provided.isNotEmpty) return provided;
    return null;
  }

  @override
  void initState() {
    super.initState();
    openConversationNotifier.value = widget.conversationId;
    // Record that the user is visiting this conversation now.
    // This clears the unread dot for this thread in the chat list.
    conversationVisitedAt[widget.conversationId] = DateTime.now();
    conversationReadStateNotifier.value++;
    messageRealtimeService.markConversationRead(widget.conversationId);
    _pendingReferencedListingId = widget.armProductReferenceOnOpen
        ? widget.productListingId
        : null;
    _resolvedAvatarUrl = widget.avatarUrl;
    _resolvedPhoneNumber = widget.phoneNumber;
    _init();
  }

  Future<void> _init() async {
    _myUserId = await authService.getUserId();
    await _loadCounterpartContact();
    _seedInitialReferencedListingPreview();
    await _loadMessages();
    await _markAsReadAndRefreshUnread();
    _connectStomp();
  }

  void _seedInitialReferencedListingPreview() {
    final listingId = widget.productListingId;
    if (listingId == null) return;

    final title = widget.productTitle?.trim();
    final imageUrl = widget.productImage?.trim();
    final hasSeedData =
        (title != null && title.isNotEmpty) ||
        (imageUrl != null && imageUrl.isNotEmpty) ||
        widget.productPrice != null;

    if (hasSeedData) {
      _referencedListingPreviews[listingId] = _ReferencedListingPreview(
        listingId: listingId,
        title: (title != null && title.isNotEmpty) ? title : 'Listing',
        imageUrl: (imageUrl != null && imageUrl.isNotEmpty) ? imageUrl : null,
        price: widget.productPrice,
      );
    }

    final preview = _referencedListingPreviews[listingId];
    final needsBackfill =
        preview == null ||
        preview.title.trim().isEmpty ||
        preview.imageUrl == null ||
        preview.imageUrl!.trim().isEmpty ||
        preview.price == null;
    if (needsBackfill) {
      unawaited(_ensureReferencedListingLoaded(listingId));
    }
  }

  Future<void> _markAsReadAndRefreshUnread() async {
    if (_markingAsRead) return;
    _markingAsRead = true;
    try {
      await apiClient.dio.patch(
        '/conversations/${widget.conversationId}/messages/mark-as-read',
      );
    } catch (_) {
      // Keep UI responsive even if mark-as-read fails.
    }

    if (!mounted) {
      _markingAsRead = false;
      return;
    }

    messageRealtimeService.markConversationRead(widget.conversationId);
    conversationVisitedAt[widget.conversationId] = DateTime.now();
    conversationReadStateNotifier.value++;
    await _refreshUnreadNow(forceRefresh: true);

    _markingAsRead = false;
  }

  Future<void> _refreshUnreadNow({bool forceRefresh = false}) async {
    if (_refreshingUnread || !mounted) return;
    _refreshingUnread = true;
    try {
      final count = await unreadService.refreshUnreadCount(
        fallbackCount: unreadNotifier.value,
        forceRefresh: forceRefresh,
      );
      messageRealtimeService.setServerUnreadCount(count);
    } catch (_) {}
    _refreshingUnread = false;
  }

  void _scheduleUnreadRefresh({
    Duration delay = const Duration(milliseconds: 350),
  }) {
    _unreadRefreshDebounce?.cancel();
    _unreadRefreshDebounce = Timer(delay, () {
      _refreshUnreadNow();
    });
  }

  Future<void> _loadCounterpartContact() async {
    final existingPhone = _resolvedPhoneNumber?.trim();
    final existingAvatar = _resolvedAvatarUrl?.trim();
    if ((existingAvatar != null && existingAvatar.isNotEmpty) &&
        (existingPhone != null && existingPhone.isNotEmpty)) {
      return;
    }

    final profile = await publicProfileCache.resolvePublicProfile(
      widget.counterpartUserId,
    );
    if (!mounted) return;
    final avatar = profile?.avatarUrl?.trim();
    final phoneNumber = profile?.phoneNumber?.trim();
    if ((avatar != null && avatar.isNotEmpty) ||
        (phoneNumber != null && phoneNumber.isNotEmpty)) {
      setState(() {
        if (avatar != null && avatar.isNotEmpty) {
          _resolvedAvatarUrl = avatar;
        }
        if (phoneNumber != null && phoneNumber.isNotEmpty) {
          _resolvedPhoneNumber = phoneNumber;
        }
      });
      return;
    }

    if (existingAvatar == null || existingAvatar.isEmpty) {
      final resolvedAvatar = await avatarResolver.resolveAvatarUrl(
        widget.counterpartUserId,
      );
      if (!mounted) return;
      final fallbackAvatar = resolvedAvatar?.trim();
      if (fallbackAvatar != null && fallbackAvatar.isNotEmpty) {
        setState(() => _resolvedAvatarUrl = fallbackAvatar);
      }
    }
  }

  Future<void> _ensureReferencedListingLoaded(int listingId) async {
    if (_loadingReferencedListingIds.contains(listingId)) return;
    _loadingReferencedListingIds.add(listingId);
    try {
      final resp = await apiClient.dio.get('/listings/$listingId');
      final listing = ListingResponse.fromJson(resp.data);
      final fetchedImageUrl = listing.images.isNotEmpty
          ? listing.images.first.secureUrl
          : listing.primaryImageUrl?.trim();
      if (mounted) {
        setState(() {
          final existing = _referencedListingPreviews[listingId];
          _referencedListingPreviews[listingId] = _ReferencedListingPreview(
            listingId: listingId,
            title: existing?.title.trim().isNotEmpty == true
                ? existing!.title
                : listing.title,
            imageUrl: existing?.imageUrl?.trim().isNotEmpty == true
                ? existing!.imageUrl
                : fetchedImageUrl,
            price: existing?.price ?? listing.priceUgx,
          );
        });
      }
    } catch (_) {
      // Keep chat usable even if referenced listing preview fails to load.
    } finally {
      _loadingReferencedListingIds.remove(listingId);
    }
  }

  void _primeReferencedListings(Iterable<MessageResponse> messages) {
    for (final message in messages) {
      final listingId = message.referencedListingId;
      if (listingId != null) {
        unawaited(_ensureReferencedListingLoaded(listingId));
      }
    }
  }

  Future<void> _loadMessages() async {
    try {
      final resp = await apiClient.dio.get(
        '/conversations/${widget.conversationId}/messages',
        queryParameters: {'limit': 50},
      );
      final items = (resp.data['items'] as List)
          .map((e) => MessageResponse.fromJson(e))
          .toList();
      _primeReferencedListings(items);
      if (mounted) {
        setState(() => _messages = items);
        _scrollToBottom();
      }
    } catch (_) {}
  }

  void _connectStomp() async {
    final token = await apiClient.readToken();
    if (token == null) return;
    await stompService.connect(token: token);
    _stompUnsub = stompService.subscribeToConversation(
      conversationId: widget.conversationId,
      onMessage: (msg) {
        if (!mounted) return;
        if (msg.senderUserId == _myUserId && _pendingEchos > 0) {
          // Replace the matching optimistic message with the confirmed one
          setState(() {
            final idx = _messages.indexWhere(
              (m) =>
                  m.id < 0 &&
                  m.body == msg.body &&
                  m.referencedListingId == msg.referencedListingId,
            );
            if (idx >= 0) {
              _messages[idx] = msg;
            } else {
              _messages.add(msg);
            }
          });
          messageRealtimeService.setLatestMessage(widget.conversationId, msg);
          _primeReferencedListings([msg]);
          conversationVisitedAt[widget.conversationId] = msg.createdAt;
          conversationReadStateNotifier.value++;
          messageRealtimeService.markConversationRead(widget.conversationId);
          _pendingEchos--;
        } else if (msg.senderUserId != _myUserId) {
          setState(() => _messages.add(msg));
          messageRealtimeService.setLatestMessage(widget.conversationId, msg);
          _primeReferencedListings([msg]);
          conversationVisitedAt[widget.conversationId] = DateTime.now();
          conversationReadStateNotifier.value++;
          messageRealtimeService.markConversationRead(widget.conversationId);
          _scrollToBottom();
          _scheduleUnreadRefresh();
          conversationUpdateNotifier.value++;
        }
        // own-echo with no pending: silently drop (already shown)
      },
    );
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String? get _normalizedPhoneNumber {
    final phoneNumber = _effectivePhoneNumber;
    if (phoneNumber == null || phoneNumber.isEmpty) return null;
    return phoneNumber.replaceAll(RegExp(r'\s+'), '');
  }

  Future<void> _openDialer() async {
    final phoneNumber = _normalizedPhoneNumber;
    if (phoneNumber == null) {
      if (!mounted) return;
      AppToast.info(context, 'This seller has no phone number available.');
      return;
    }

    final phoneUri = Uri.parse('tel:$phoneNumber');

    try {
      final didLaunch = await launchUrl(
        phoneUri,
        mode: LaunchMode.externalApplication,
      );
      if (!didLaunch && mounted) {
        AppToast.error(context, 'Could not open the phone app.');
      }
    } catch (_) {
      if (!mounted) return;
      AppToast.error(context, 'Could not open the phone app.');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    if (openConversationNotifier.value == widget.conversationId) {
      openConversationNotifier.value = null;
    }
    routeObserver.unsubscribe(this);
    _stompUnsub?.call();
    _unreadRefreshDebounce?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadMessages();
    _markAsReadAndRefreshUnread();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    final referencedListingId = _pendingReferencedListingId;

    // Optimistically add to UI immediately
    final tempId = _tempMsgId--;
    final optimistic = MessageResponse(
      id: tempId,
      conversationId: widget.conversationId,
      senderUserId: _myUserId ?? 0,
      body: text,
      referencedListingId: referencedListingId,
      createdAt: DateTime.now(),
    );
    setState(() => _messages.add(optimistic));
    _primeReferencedListings([optimistic]);
    _pendingEchos++;
    _scrollToBottom();
    conversationUpdateNotifier.value++;

    try {
      await apiClient.dio.post(
        '/conversations/${widget.conversationId}/messages',
        data: {
          'body': text,
          if (referencedListingId != null)
            'referencedListingId': referencedListingId,
        },
      );
      if (mounted) {
        setState(() => _pendingReferencedListingId = null);
      } else {
        _pendingReferencedListingId = null;
      }
      // STOMP will echo the confirmed message back; handled in _connectStomp
    } on DioException catch (e) {
      _pendingEchos--;
      if (mounted) {
        setState(() => _messages.removeWhere((m) => m.id == tempId));
        AppToast.fromApiException(context, ApiException.fromDio(e));
      }
    } catch (e) {
      _pendingEchos--;
      if (mounted) {
        setState(() => _messages.removeWhere((m) => m.id == tempId));
        AppToast.error(context, 'Failed to send message. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = _effectiveAvatarUrl;
    final referencedListingId = _pendingReferencedListingId;

    return Scaffold(
      backgroundColor: AppColors.of(context).lightGray,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.of(context).darkGray),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Row(
          children: [
            // Avatar with online status
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VendorProfileScreen(
                      vendorName: widget.userName,
                      vendorAvatar: avatarUrl,
                      isOnline: widget.isOnline,
                      listingId: widget.productListingId,
                      vendorUserId: widget.counterpartUserId,
                    ),
                  ),
                );
              },
              child: Stack(
                children: [
                  if (avatarUrl != null)
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: NetworkImage(avatarUrl),
                    )
                  else if (widget.businessName != null)
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.of(context).darkGray,
                      child: Icon(
                        Icons.store,
                        color: AppColors.of(context).white,
                        size: 20,
                      ),
                    )
                  else
                    _buildLetterAvatar(radius: 20),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Text Stack
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.userName,
                    style: TextStyle(
                      color: AppColors.of(context).darkGray,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.phone, color: AppColors.of(context).primary),
            onPressed: _openDialer,
          ),
        ],
      ),
      body: Column(
        children: [
          // Message Thread
          Expanded(
            child: Column(
              children: [
                // Messages or Empty State
                Expanded(
                  child: _messages.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            final isOutgoing =
                                message.senderUserId == _myUserId;
                            final timeStr = _formatTime(message.createdAt);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _buildMessageItem(
                                message,
                                timeStr,
                                isOutgoing: isOutgoing,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          // Message Input Area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.of(context).white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (referencedListingId != null) ...[
                    _buildPendingReferencedListingBanner(referencedListingId),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      // Text Field
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.of(context).white,
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(
                              color: AppColors.of(context).lightGray,
                              width: 1,
                            ),
                          ),
                          child: TextField(
                            controller: _messageController,
                            decoration: InputDecoration(
                              hintText: 'Enter message...',
                              hintStyle: TextStyle(
                                color: AppColors.of(context).mediumGray,
                                fontSize: 14,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Send Button
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.of(context).primary,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.send,
                            color: AppColors.of(context).white,
                            size: 18,
                          ),
                          onPressed: _sendMessage,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final hour = local.hour > 12
        ? local.hour - 12
        : (local.hour == 0 ? 12 : local.hour);
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Widget _buildMessageItem(
    MessageResponse message,
    String timestamp, {
    required bool isOutgoing,
  }) {
    return Column(
      crossAxisAlignment: isOutgoing
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        if (message.referencedListingId != null) ...[
          _buildInlineReferencedListingCard(
            message.referencedListingId!,
            isOutgoing: isOutgoing,
          ),
          const SizedBox(height: 8),
        ],
        isOutgoing
            ? _buildOutgoingMessage(message.body, timestamp)
            : _buildIncomingMessage(message.body, timestamp),
      ],
    );
  }

  Widget _buildIncomingMessage(String message, String timestamp) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLetterAvatar(radius: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.of(context).white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.of(context).lightGray),
                ),
                child: Text(
                  message,
                  style: TextStyle(
                    color: AppColors.of(context).darkGray,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                timestamp,
                style: TextStyle(
                  color: AppColors.of(context).mediumGray,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 24),
      ],
    );
  }

  Widget _buildOutgoingMessage(String message, String timestamp) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.of(context).primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  message,
                  style: TextStyle(
                    color: AppColors.of(context).white,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    timestamp,
                    style: TextStyle(
                      color: AppColors.of(context).mediumGray,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: AppColors.of(context).mediumGray.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Start a conversation with ${widget.userName}',
              style: TextStyle(
                color: AppColors.of(context).darkGray,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (widget.businessName != null) ...[
              const SizedBox(height: 8),
              Text(
                widget.businessName!,
                style: TextStyle(
                  color: AppColors.of(context).mediumGray,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (_effectivePhoneNumber != null) ...[
              const SizedBox(height: 4),
              Text(
                _effectivePhoneNumber!,
                style: TextStyle(
                  color: AppColors.of(context).mediumGray,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInlineReferencedListingCard(
    int listingId, {
    required bool isOutgoing,
  }) {
    final preview = _referencedListingPreviews[listingId];
    final fallbackTitle =
        listingId == widget.productListingId &&
            widget.productTitle != null &&
            widget.productTitle!.trim().isNotEmpty
        ? widget.productTitle!.trim()
        : 'Loading listing...';
    final imageUrl = preview?.imageUrl;
    final title = (preview?.title.trim().isNotEmpty == true)
        ? preview!.title
        : fallbackTitle;
    final price =
        preview?.price ??
        (listingId == widget.productListingId ? widget.productPrice : null);

    return Align(
      alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailsScreen(
              listingId: listingId,
              productTitle: title,
              price: price ?? 0,
              imageUrl: imageUrl,
              vendorName: widget.userName,
              vendorAvatar: _effectiveAvatarUrl,
              vendorLocation: '',
              ownerUserIdHint: widget.counterpartUserId,
            ),
          ),
        ),
        child: Container(
          width: 260,
          decoration: BoxDecoration(
            color: AppColors.of(context).white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.of(context).lightGray,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              // Product Image
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
                child: imageUrl != null && imageUrl.trim().isNotEmpty
                    ? Image.network(
                        imageUrl,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _imagePlaceholder(),
                      )
                    : _imagePlaceholder(),
              ),
              // Product Details
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: AppColors.of(context).darkGray,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (price != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'UGX ${price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                          style: TextStyle(
                            color: AppColors.of(context).primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPendingReferencedListingBanner(int listingId) {
    final preview = _referencedListingPreviews[listingId];
    final fallbackTitle =
        listingId == widget.productListingId &&
            widget.productTitle != null &&
            widget.productTitle!.trim().isNotEmpty
        ? widget.productTitle!.trim()
        : 'Loading listing...';
    final imageUrl =
        preview?.imageUrl ??
        (listingId == widget.productListingId
            ? widget.productImage?.trim()
            : null);
    final title = (preview?.title.trim().isNotEmpty == true)
        ? preview!.title
        : fallbackTitle;
    final price =
        preview?.price ??
        (listingId == widget.productListingId ? widget.productPrice : null);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.of(context).lightGray,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.of(context).lightGray, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          width: 42,
                          height: 42,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => SizedBox(
                            width: 42,
                            height: 42,
                            child: _imagePlaceholder(),
                          ),
                        )
                      : SizedBox(
                          width: 42,
                          height: 42,
                          child: _imagePlaceholder(),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.of(context).darkGray,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (price != null)
                        Text(
                          'UGX ${price.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                          style: TextStyle(
                            color: AppColors.of(context).primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() => _pendingReferencedListingId = null);
            },
            icon: Icon(
              Icons.close,
              color: AppColors.of(context).mediumGray,
              size: 18,
            ),
            tooltip: 'Remove product reference',
          ),
        ],
      ),
    );
  }

  Widget _buildLetterAvatar({required double radius}) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.of(context).lightGray,
      child: Text(
        _displayInitials,
        style: TextStyle(
          color: AppColors.of(context).darkGray,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.7,
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      width: 80,
      height: 80,
      color: AppColors.of(context).lightGray,
      child: Icon(
        Icons.image_not_supported_outlined,
        color: AppColors.of(context).mediumGray,
        size: 32,
      ),
    );
  }
}
