import 'package:flutter/material.dart';
import 'main.dart';
import 'vendorProfile.dart';
import 'package:url_launcher/url_launcher.dart';

class InboxScreen extends StatefulWidget {
  final String userName;
  final String? avatarUrl;
  final bool isOnline;
  final String? businessName;
  final String? initials;
  final String? phoneNumber;
  final String? productTitle;
  final String? productImage;
  final int? productPrice;

  const InboxScreen({
    super.key,
    required this.userName,
    this.avatarUrl,
    required this.isOnline,
    this.businessName,
    this.initials,
    this.phoneNumber = '+256700000000',
    this.productTitle,
    this.productImage,
    this.productPrice,
  });

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_messageController.text.trim().isNotEmpty) {
      setState(() {
        _messages.add(
          ChatMessage(
            text: _messageController.text.trim(),
            timestamp: _formatCurrentTime(),
            isOutgoing: true,
          ),
        );
        _messageController.clear();
      });
      // Scroll to bottom after sending message
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
  }

  String _formatCurrentTime() {
    final now = DateTime.now();
    final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
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
                      vendorAvatar: widget.avatarUrl ?? 'https://i.pravatar.cc/150?img=25',
                      isOnline: widget.isOnline,
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
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _buildOutgoingMessage(
                                message.text,
                                message.timestamp,
                                isDelivered: true,
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
              'Start a conversation with vendor',
              style: TextStyle(
                color: AppColors.darkGray,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Wandegeya • Kampala',
              style: TextStyle(
                color: AppColors.mediumGray,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'vendor@must.ac.ug',
              style: TextStyle(
                color: AppColors.mediumGray,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductReferenceCard() {
    return Container(
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
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final String timestamp;
  final bool isOutgoing;

  ChatMessage({
    required this.text,
    required this.timestamp,
    required this.isOutgoing,
  });
}
