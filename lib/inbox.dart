import 'package:flutter/material.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';
import 'main.dart';
import 'vendorProfile.dart';
import 'productDetails.dart';
import 'package:url_launcher/url_launcher.dart';
import 'core/api_client.dart';
import 'core/auth_service.dart';
import 'core/stomp_service.dart';
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
    this.counterpartUserId,
  });

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> with RouteAware {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<MessageResponse> _messages = [];
  int? _myUserId;
  StompUnsubscribe? _stompUnsub;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _myUserId = await authService.getUserId();
    await _loadMessages();
    _connectStomp();
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
        if (mounted) {
          setState(() => _messages.add(msg));
          _scrollToBottom();
          if (msg.senderUserId != _myUserId && unreadNotifier.value > 0) {
            unreadNotifier.value++;
          }
        }
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _stompUnsub?.call();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    _loadMessages();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    try {
      await apiClient.dio.post(
        '/conversations/${widget.conversationId}/messages',
        data: {'body': text},
      );
      // STOMP subscription will deliver the message back
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Send failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGray,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: AppColors.darkGray,
          ),
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
                      vendorAvatar: widget.avatarUrl,
                      isOnline: widget.isOnline,
                      vendorUserId: widget.counterpartUserId,
                    ),
                  ),
                );
              },
              child: Stack(
                children: [
                  if (widget.avatarUrl != null)
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: NetworkImage(widget.avatarUrl!),
                    )
                  else if (widget.businessName != null)
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.darkGray,
                      child: Icon(
                        Icons.store,
                        color: AppColors.white,
                        size: 20,
                      ),
                    )
                  else
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.lightGray,
                      child: Text(
                        widget.initials ?? '',
                        style: TextStyle(
                          color: AppColors.darkGray,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  if (widget.isOnline)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.lightGray,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
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
                      color: AppColors.darkGray,
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
            icon: const Icon(
              Icons.phone,
              color: Colors.black,
            ),
            onPressed: () async {
              final Uri phoneUri = Uri(scheme: 'tel', path: widget.phoneNumber);
              if (await canLaunchUrl(phoneUri)) {
                await launchUrl(phoneUri);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Message Thread
          Expanded(
            child: Column(
              children: [
                // Product Reference Card (if available)
                if (widget.productTitle != null &&
                    widget.productImage != null &&
                    widget.productPrice != null)
                  _buildProductReferenceCard(),
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
                            final isOutgoing = message.senderUserId == _myUserId;
                            final timeStr = _formatTime(message.createdAt);
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: isOutgoing
                                  ? _buildOutgoingMessage(message.body, timeStr, isDelivered: true)
                                  : _buildIncomingMessage(message.body, timeStr),
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
              color: AppColors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  // Text Field
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(
                          color: AppColors.lightGray,
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Enter message...',
                          hintStyle: TextStyle(
                            color: AppColors.mediumGray,
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
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.send,
                        color: AppColors.white,
                        size: 18,
                      ),
                      onPressed: _sendMessage,
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

  String _formatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Widget _buildIncomingMessage(String message, String timestamp) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.lightGray),
                ),
                child: Text(
                  message,
                  style: const TextStyle(color: AppColors.darkGray, fontSize: 14),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                timestamp,
                style: const TextStyle(color: AppColors.mediumGray, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }

  Widget _buildOutgoingMessage(
    String message,
    String timestamp, {
    bool isDelivered = false,
  }) {
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
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  message,
                  style: TextStyle(
                    color: AppColors.white,
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
                      color: AppColors.mediumGray,
                      fontSize: 11,
                    ),
                  ),
                  if (isDelivered) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.done_all,
                      size: 14,
                      color: AppColors.mediumGray,
                    ),
                  ],
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
              color: AppColors.mediumGray.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Start a conversation with ${widget.userName}',
              style: TextStyle(
                color: AppColors.darkGray,
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
                  color: AppColors.mediumGray,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (widget.phoneNumber != null) ...[
              const SizedBox(height: 4),
              Text(
                widget.phoneNumber!,
                style: TextStyle(
                  color: AppColors.mediumGray,
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

  Widget _buildProductReferenceCard() {
    return GestureDetector(
      onTap: widget.productListingId != null
          ? () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProductDetailsScreen(
                    listingId: widget.productListingId,
                    productTitle: widget.productTitle!,
                    price: widget.productPrice!,
                    imageUrl: widget.productImage,
                    vendorName: widget.userName,
                    vendorLocation: '',
                  ),
                ),
              )
          : null,
      child: Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.lightGray,
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
            child: Image.network(
              widget.productImage!,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
            ),
          ),
          // Product Details
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.productTitle!,
                    style: const TextStyle(
                      color: AppColors.darkGray,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'UGX ${widget.productPrice!.toString().replaceAllMapped(
                          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                          (Match m) => '${m[1]},',
                        )}',
                    style: const TextStyle(
                      color: AppColors.teal,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),    ),    );
  }
}


