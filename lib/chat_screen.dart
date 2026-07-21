import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'product_detail_screen.dart';

class ChatScreen extends StatefulWidget {
  final String? chatId;
  final String productId;
  final String productTitle;
  final String productPrice;
  final String productImage;
  final String sellerId;
  final String sellerName;
  final String? buyerId;
  final String? buyerName;

  const ChatScreen({
    super.key,
    this.chatId,
    required this.productId,
    required this.productTitle,
    required this.productPrice,
    required this.productImage,
    required this.sellerId,
    required this.sellerName,
    this.buyerId,
    this.buyerName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isSending = false;
  bool _isUploadingImage = false;
  bool _showQuickReplies = true;

  late String activeChatId;
  late String currentUserId;
  late String currentUserName;

  String _resolvedBuyerId = '';
  String _resolvedBuyerName = '';
  String _resolvedSellerId = '';
  String _resolvedSellerName = '';
  String _resolvedProductTitle = '';
  String _resolvedProductPrice = '';
  String _resolvedProductImage = '';

  StreamSubscription<DocumentSnapshot>? _chatDocSubscription;

  final List<String> _quickReplies = [
    "Is this still available?",
    "Is the price negotiable?",
    "Where can we meet on campus?",
    "What is the condition of the item?",
    "Can you share more photos?",
  ];

  @override
  void initState() {
    super.initState();
    final currentUser = FirebaseAuth.instance.currentUser;
    currentUserId = currentUser?.uid ?? '';
    currentUserName = (currentUser?.displayName?.trim().isNotEmpty == true)
        ? currentUser!.displayName!.trim()
        : (currentUser?.email?.split('@').first ?? 'Student');

    _resolvedSellerId = widget.sellerId.isNotEmpty ? widget.sellerId : '';
    _resolvedSellerName = widget.sellerName.trim().isNotEmpty
        ? widget.sellerName.trim()
        : 'Seller';
    _resolvedProductTitle = widget.productTitle;
    _resolvedProductPrice = widget.productPrice;
    _resolvedProductImage = widget.productImage;

    // Determine initial buyer details accurately
    if (widget.buyerId != null && widget.buyerId!.isNotEmpty) {
      _resolvedBuyerId = widget.buyerId!;
      _resolvedBuyerName = (widget.buyerName != null && widget.buyerName!.isNotEmpty)
          ? widget.buyerName!
          : (currentUserId == _resolvedBuyerId ? currentUserName : 'Buyer');
    } else {
      _resolvedBuyerId = currentUserId == _resolvedSellerId ? '' : currentUserId;
      _resolvedBuyerName = currentUserId == _resolvedSellerId ? 'Buyer' : currentUserName;
    }

    // Determine deterministic chat ID
    if (widget.chatId != null && widget.chatId!.isNotEmpty) {
      activeChatId = widget.chatId!;
    } else {
      final bId = _resolvedBuyerId.isNotEmpty ? _resolvedBuyerId : currentUserId;
      final ids = [bId, widget.sellerId]..sort();
      activeChatId = '${ids[0]}_${ids[1]}_${widget.productId}';
    }

    _listenToChatDocAndMarkRead();
  }

  @override
  void dispose() {
    _chatDocSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _listenToChatDocAndMarkRead() {
    if (activeChatId.isEmpty) return;

    final chatDocRef = FirebaseFirestore.instance.collection('chats').doc(activeChatId);

    // Mark chat as read for current user when screen is open
    _markChatAsRead(chatDocRef);

    _chatDocSubscription = chatDocRef.snapshots().listen((snapshot) {
      if (!mounted || !snapshot.exists) return;

      final data = snapshot.data();
      if (data == null) return;

      setState(() {
        final bId = data['buyerId'] as String?;
        final bName = data['buyerName'] as String?;
        final sId = data['sellerId'] as String?;
        final sName = data['sellerName'] as String?;
        final pTitle = data['productTitle'] as String?;
        final pPrice = data['productPrice'] as String?;
        final pImage = data['productImage'] as String?;

        if (bId != null && bId.isNotEmpty) _resolvedBuyerId = bId;
        if (bName != null && bName.isNotEmpty) _resolvedBuyerName = bName;
        if (sId != null && sId.isNotEmpty) _resolvedSellerId = sId;
        if (sName != null && sName.isNotEmpty) _resolvedSellerName = sName;
        if (pTitle != null && pTitle.isNotEmpty) _resolvedProductTitle = pTitle;
        if (pPrice != null && pPrice.isNotEmpty) _resolvedProductPrice = pPrice;
        if (pImage != null && pImage.isNotEmpty) _resolvedProductImage = pImage;
      });

      // Maintain read status while user is on this screen
      _markChatAsRead(chatDocRef);
    });
  }

  Future<void> _markChatAsRead(DocumentReference chatDocRef) async {
    if (currentUserId.isEmpty) return;
    try {
      await chatDocRef.set({
        'readBy': FieldValue.arrayUnion([currentUserId]),
        'unreadCount_$currentUserId': 0,
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _sendMessage({
    String? textMessage,
    bool isOffer = false,
    String? offerPrice,
    String? imageUrl,
    String type = 'text',
  }) async {
    final text = textMessage ?? _messageController.text.trim();
    if ((text.isEmpty && imageUrl == null) || currentUserId.isEmpty) return;

    if (textMessage == null && imageUrl == null) {
      _messageController.clear();
    }

    setState(() => _isSending = true);

    try {
      final effectiveBuyerId = _resolvedBuyerId.isNotEmpty
          ? _resolvedBuyerId
          : (currentUserId == _resolvedSellerId ? '' : currentUserId);

      final effectiveBuyerName = _resolvedBuyerName.isNotEmpty
          ? _resolvedBuyerName
          : (currentUserId == effectiveBuyerId ? currentUserName : 'Buyer');

      final effectiveSellerId = _resolvedSellerId.isNotEmpty
          ? _resolvedSellerId
          : widget.sellerId;

      final effectiveSellerName = _resolvedSellerName.isNotEmpty
          ? _resolvedSellerName
          : widget.sellerName;

      final chatDocRef =
          FirebaseFirestore.instance.collection('chats').doc(activeChatId);

      // Create unique list of participant IDs
      final participantIds = <String>{
        effectiveSellerId,
        if (effectiveBuyerId.isNotEmpty) effectiveBuyerId,
        currentUserId,
      }.where((id) => id.isNotEmpty).toList();

      final now = DateTime.now();

      final recipientId = currentUserId == effectiveSellerId
          ? effectiveBuyerId
          : effectiveSellerId;

      final lastMsgText = isOffer
          ? '💰 Counter Offer: Rs $offerPrice'
          : (imageUrl != null ? '📷 Shared a photo' : text);

      // Update parent chat doc cleanly without overwriting buyerId
      await chatDocRef.set({
        'chatId': activeChatId,
        'productId': widget.productId,
        'productTitle': _resolvedProductTitle.isNotEmpty ? _resolvedProductTitle : widget.productTitle,
        'productPrice': _resolvedProductPrice.isNotEmpty ? _resolvedProductPrice : widget.productPrice,
        'productImage': _resolvedProductImage.isNotEmpty ? _resolvedProductImage : widget.productImage,
        'sellerId': effectiveSellerId,
        'sellerName': effectiveSellerName,
        'buyerId': effectiveBuyerId,
        'buyerName': effectiveBuyerName,
        'lastMessage': lastMsgText,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': currentUserId,
        'participants': FieldValue.arrayUnion(participantIds),
        'readBy': [currentUserId],
        'updatedAt': FieldValue.serverTimestamp(),
        if (recipientId.isNotEmpty) 'unreadCount_$recipientId': FieldValue.increment(1),
      }, SetOptions(merge: true));

      // Add message to subcollection
      await chatDocRef.collection('messages').add({
        'senderId': currentUserId,
        'senderName': currentUserName,
        'text': text,
        'type': type,
        'isOffer': isOffer,
        'offerPrice': offerPrice,
        'offerStatus': isOffer ? 'pending' : null,
        'imageUrl': imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'localTimestamp': now.millisecondsSinceEpoch,
        'isRead': false,
      });

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _handleOfferDecision(String messageId, String offerPrice, bool accept) async {
    try {
      final chatDocRef = FirebaseFirestore.instance.collection('chats').doc(activeChatId);
      final msgRef = chatDocRef.collection('messages').doc(messageId);

      final status = accept ? 'accepted' : 'declined';
      await msgRef.update({
        'offerStatus': status,
      });

      final statusText = accept
          ? '🎉 OFFER ACCEPTED: Rs $offerPrice for "$_resolvedProductTitle"'
          : '❌ OFFER DECLINED: Rs $offerPrice for "$_resolvedProductTitle"';

      // Send system message notification into chat
      await chatDocRef.collection('messages').add({
        'senderId': 'system',
        'senderName': 'UniMart System',
        'text': statusText,
        'type': 'system',
        'createdAt': FieldValue.serverTimestamp(),
        'localTimestamp': DateTime.now().millisecondsSinceEpoch,
      });

      await chatDocRef.set({
        'lastMessage': statusText,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': currentUserId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update offer: $e')),
        );
      }
    }
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    try {
      final XFile? file = await _imagePicker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1024,
      );

      if (file == null) return;

      setState(() => _isUploadingImage = true);

      String imageUrl = '';

      try {
        final ref = FirebaseStorage.instance
            .ref()
            .child('chat_images/$activeChatId/${DateTime.now().millisecondsSinceEpoch}.jpg');

        await ref.putFile(File(file.path));
        imageUrl = await ref.getDownloadURL();
      } catch (_) {
        // Safe base64 fallback so photo sharing never breaks even without storage rules
        final bytes = await file.readAsBytes();
        imageUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      }

      await _sendMessage(
        textMessage: '📷 Shared a photo',
        imageUrl: imageUrl,
        type: 'image',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to select image: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Wrap(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2F6BFF).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.photo_camera_rounded, color: Color(0xFF2F6BFF)),
                  ),
                  title: const Text('Take Photo with Camera', style: TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndUploadImage(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.photo_library_rounded, color: Color(0xFF10B981)),
                  ),
                  title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAndUploadImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _openProductDetails() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          productId: widget.productId,
          title: _resolvedProductTitle.isNotEmpty ? _resolvedProductTitle : widget.productTitle,
          description: '',
          price: _resolvedProductPrice.isNotEmpty ? _resolvedProductPrice : widget.productPrice,
          image: _resolvedProductImage.isNotEmpty ? _resolvedProductImage : widget.productImage,
          sellerId: _resolvedSellerId.isNotEmpty ? _resolvedSellerId : widget.sellerId,
          sellerName: _resolvedSellerName.isNotEmpty ? _resolvedSellerName : widget.sellerName,
        ),
      ),
    );
  }

  void _showOfferModal() {
    final offerController = TextEditingController(
      text: _resolvedProductPrice.isNotEmpty ? _resolvedProductPrice : widget.productPrice,
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2F6BFF).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.local_offer_rounded,
                        color: Color(0xFF2F6BFF),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Make an Offer',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Propose your target purchase price',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _resolvedProductImage.isNotEmpty
                            ? Image.network(
                                _resolvedProductImage,
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  width: 44,
                                  height: 44,
                                  color: Colors.grey.shade300,
                                  child: const Icon(Icons.broken_image_rounded, size: 20),
                                ),
                              )
                            : Container(width: 44, height: 44, color: Colors.grey.shade300, child: const Icon(Icons.image)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _resolvedProductTitle.isNotEmpty ? _resolvedProductTitle : widget.productTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              'Listed Price: Rs ${_resolvedProductPrice.isNotEmpty ? _resolvedProductPrice : widget.productPrice}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: offerController,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'Your Offer Price',
                    hintText: 'Enter price (e.g. 4500)',
                    prefixText: 'Rs ',
                    prefixStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2F6BFF),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF2F6BFF), width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2F6BFF),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      final price = offerController.text.trim();
                      if (price.isNotEmpty) {
                        Navigator.pop(context);
                        _sendMessage(
                          textMessage: '💰 COUNTER OFFER: Rs $price for "${_resolvedProductTitle.isNotEmpty ? _resolvedProductTitle : widget.productTitle}"',
                          isOffer: true,
                          offerPrice: price,
                          type: 'offer',
                        );
                      }
                    },
                    child: const Text(
                      'Send Counter Offer',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showFullscreenImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            children: [
              InteractiveViewer(
                child: Center(
                  child: imageUrl.startsWith('data:image')
                      ? Image.memory(base64Decode(imageUrl.split(',').last))
                      : Image.network(imageUrl),
                ),
              ),
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _formatDateHeader(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dt.year, dt.month, dt.day);

    if (target == today) return 'Today';
    if (target == today.subtract(const Duration(days: 1))) return 'Yesterday';

    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSeller = currentUserId == (_resolvedSellerId.isNotEmpty ? _resolvedSellerId : widget.sellerId);
    
    final counterpartName = isSeller
        ? (_resolvedBuyerName.isNotEmpty ? _resolvedBuyerName : 'Buyer')
        : (_resolvedSellerName.isNotEmpty ? _resolvedSellerName : 'Seller');
    final counterpartRole = isSeller ? 'Buyer' : 'Seller';

    final pTitle = _resolvedProductTitle.isNotEmpty ? _resolvedProductTitle : widget.productTitle;
    final pPrice = _resolvedProductPrice.isNotEmpty ? _resolvedProductPrice : widget.productPrice;
    final pImage = _resolvedProductImage.isNotEmpty ? _resolvedProductImage : widget.productImage;

    return Scaffold(
      appBar: AppBar(
        elevation: 0.5,
        titleSpacing: 0,
        title: InkWell(
          onTap: _openProductDetails,
          child: Row(
            children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: const Color(0xFF2F6BFF).withValues(alpha: 0.15),
                child: Text(
                  counterpartName.isNotEmpty ? counterpartName[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    color: Color(0xFF2F6BFF),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            counterpartName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isSeller
                                ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                : const Color(0xFF2F6BFF).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            counterpartRole,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isSeller
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFF2F6BFF),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      pTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded, color: Color(0xFF2F6BFF)),
            tooltip: 'View Product Details',
            onPressed: _openProductDetails,
          ),
          IconButton(
            icon: Icon(
              _showQuickReplies ? Icons.lightbulb : Icons.lightbulb_outline,
              color: const Color(0xFF2F6BFF),
            ),
            tooltip: 'Toggle Quick Replies',
            onPressed: () {
              setState(() => _showQuickReplies = !_showQuickReplies);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Sticky Product Summary Banner
          GestureDetector(
            onTap: _openProductDetails,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFDBEAFE),
                  ),
                ),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: pImage.isNotEmpty
                        ? Image.network(
                            pImage,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              width: 44,
                              height: 44,
                              color: Colors.grey.shade300,
                              child: const Icon(Icons.broken_image_rounded, size: 20),
                            ),
                          )
                        : Container(
                            width: 44,
                            height: 44,
                            color: Colors.grey.shade300,
                            child: const Icon(Icons.image, size: 24),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Rs $pPrice',
                          style: const TextStyle(
                            color: Color(0xFF2F6BFF),
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _showOfferModal,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2F6BFF),
                      side: const BorderSide(color: Color(0xFF2F6BFF)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.local_offer_rounded, size: 14),
                    label: const Text(
                      'Offer',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Realtime Stream of Messages
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(activeChatId)
                  .collection('messages')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2F6BFF).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 48,
                              color: Color(0xFF2F6BFF),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Start conversation with $counterpartName',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            isSeller
                                ? 'Buyers can send messages or price offers here.'
                                : 'Ask questions or make an offer to begin negotiating!',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final messageId = doc.id;
                    final senderId = data['senderId'] ?? '';
                    final isMe = senderId == currentUserId;
                    final isSystem = senderId == 'system' || data['type'] == 'system';
                    final isOffer = data['isOffer'] == true || data['type'] == 'offer';
                    final isImage = data['type'] == 'image' || data['imageUrl'] != null;
                    final offerStatus = data['offerStatus'] ?? 'pending';
                    final offerPrice = data['offerPrice'] ?? '';

                    // Resolve timestamp gracefully
                    DateTime messageTime;
                    if (data['createdAt'] is Timestamp) {
                      messageTime = (data['createdAt'] as Timestamp).toDate();
                    } else if (data['localTimestamp'] != null) {
                      messageTime = DateTime.fromMillisecondsSinceEpoch(data['localTimestamp']);
                    } else {
                      messageTime = DateTime.now();
                    }

                    // Date header calculation for reverse list
                    bool showDateHeader = false;
                    if (index == docs.length - 1) {
                      showDateHeader = true;
                    } else {
                      final prevData = docs[index + 1].data() as Map<String, dynamic>;
                      DateTime prevTime;
                      if (prevData['createdAt'] is Timestamp) {
                        prevTime = (prevData['createdAt'] as Timestamp).toDate();
                      } else if (prevData['localTimestamp'] != null) {
                        prevTime = DateTime.fromMillisecondsSinceEpoch(prevData['localTimestamp']);
                      } else {
                        prevTime = DateTime.now();
                      }

                      if (messageTime.day != prevTime.day ||
                          messageTime.month != prevTime.month ||
                          messageTime.year != prevTime.year) {
                        showDateHeader = true;
                      }
                    }

                    return Column(
                      children: [
                        if (showDateHeader)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF334155)
                                      : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _formatDateHeader(messageTime),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.grey.shade300
                                        : Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ),
                          ),

                        // System notification banner
                        if (isSystem)
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : Colors.grey.shade300,
                              ),
                            ),
                            child: Text(
                              data['text'] ?? '',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        else
                          Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.78,
                              ),
                              child: isOffer
                                  ? _buildOfferCard(
                                      context: context,
                                      messageId: messageId,
                                      data: data,
                                      isMe: isMe,
                                      isSeller: isSeller,
                                      offerStatus: offerStatus,
                                      offerPrice: offerPrice,
                                      timeStr: _formatTime(messageTime),
                                      isDark: isDark,
                                    )
                                  : _buildStandardBubble(
                                      context: context,
                                      data: data,
                                      isMe: isMe,
                                      isImage: isImage,
                                      timeStr: _formatTime(messageTime),
                                      isDark: isDark,
                                    ),
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // Uploading indicator bar
          if (_isUploadingImage)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFF2F6BFF).withValues(alpha: 0.1),
              child: const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2F6BFF)),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Uploading image...',
                    style: TextStyle(fontSize: 13, color: Color(0xFF2F6BFF), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),

          // Quick Replies Chips
          if (_showQuickReplies)
            Container(
              height: 40,
              margin: const EdgeInsets.only(top: 4, bottom: 4),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: _quickReplies.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final reply = _quickReplies[index];
                  return ActionChip(
                    backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    side: BorderSide(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                    label: Text(
                      reply,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey.shade200 : Colors.grey.shade800,
                      ),
                    ),
                    onPressed: () => _sendMessage(textMessage: reply),
                  );
                },
              ),
            ),

          // Message input bar
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_photo_alternate_rounded, color: Color(0xFF2F6BFF)),
                    onPressed: _showImagePickerOptions,
                    tooltip: 'Attach Image',
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: null,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFF1F5F9),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF2F6BFF),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.send_rounded, color: Colors.white),
                      onPressed: () => _sendMessage(),
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

  Widget _buildStandardBubble({
    required BuildContext context,
    required Map<String, dynamic> data,
    required bool isMe,
    required bool isImage,
    required String timeStr,
    required bool isDark,
  }) {
    final isRead = data['isRead'] == true;

    return Container(
      padding: EdgeInsets.all(isImage ? 6 : 14),
      decoration: BoxDecoration(
        color: isMe
            ? const Color(0xFF2F6BFF)
            : (isDark ? const Color(0xFF334155) : Colors.white),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(isMe ? 20 : 4),
          bottomRight: Radius.circular(isMe ? 4 : 20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isImage && data['imageUrl'] != null) ...[
            GestureDetector(
              onTap: () => _showFullscreenImage(data['imageUrl']),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: data['imageUrl'].toString().startsWith('data:image')
                    ? Image.memory(
                        base64Decode(data['imageUrl'].toString().split(',').last),
                        width: 220,
                        height: 200,
                        fit: BoxFit.cover,
                      )
                    : Image.network(
                        data['imageUrl'],
                        width: 220,
                        height: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 220,
                          height: 200,
                          color: Colors.grey.shade300,
                          child: const Center(
                            child: Icon(Icons.broken_image_rounded, size: 48, color: Colors.grey),
                          ),
                        ),
                      ),
              ),
            ),
            if ((data['text'] ?? '').toString().isNotEmpty && data['text'] != '📷 Shared a photo')
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 6, right: 6),
                child: Text(
                  data['text'],
                  style: TextStyle(
                    color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
                  ),
                ),
              ),
          ] else ...[
            Text(
              data['text'] ?? '',
              style: TextStyle(
                color: isMe
                    ? Colors.white
                    : (isDark ? Colors.white : Colors.black87),
                fontSize: 15,
                height: 1.3,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                timeStr,
                style: TextStyle(
                  fontSize: 10,
                  color: isMe
                      ? Colors.white.withValues(alpha: 0.8)
                      : Colors.grey.shade500,
                ),
              ),
              if (isMe) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.done_all_rounded,
                  size: 14,
                  color: isRead
                      ? const Color(0xFF6EE7B7) // Light green check mark when read
                      : Colors.white.withValues(alpha: 0.9),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOfferCard({
    required BuildContext context,
    required String messageId,
    required Map<String, dynamic> data,
    required bool isMe,
    required bool isSeller,
    required String offerStatus,
    required String offerPrice,
    required String timeStr,
    required bool isDark,
  }) {
    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (offerStatus == 'accepted') {
      statusColor = const Color(0xFF10B981);
      statusLabel = 'ACCEPTED';
      statusIcon = Icons.check_circle_rounded;
    } else if (offerStatus == 'declined') {
      statusColor = Colors.red.shade600;
      statusLabel = 'DECLINED';
      statusIcon = Icons.cancel_rounded;
    } else {
      statusColor = const Color(0xFFF59E0B);
      statusLabel = 'PENDING';
      statusIcon = Icons.hourglass_top_rounded;
    }

    // Current user can make decision if they didn't send the offer
    final canDecide = !isMe && offerStatus == 'pending';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFFFFFBEB), const Color(0xFFFEF3C7)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.local_offer_rounded, color: statusColor, size: 18),
                  const SizedBox(width: 6),
                  const Text(
                    'PRICE OFFER',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Rs $offerPrice',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF78350F),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isMe
                ? 'You proposed Rs $offerPrice for this product.'
                : '${data['senderName'] ?? 'Counterpart'} offered Rs $offerPrice.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey.shade300 : const Color(0xFF92400E),
            ),
          ),

          if (canDecide) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade600,
                      side: BorderSide(color: Colors.red.shade400),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _handleOfferDecision(messageId, offerPrice, false),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _handleOfferDecision(messageId, offerPrice, true),
                    child: const Text('Accept Offer'),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              timeStr,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
