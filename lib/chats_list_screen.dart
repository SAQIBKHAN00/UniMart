import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';

class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({super.key});

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatRelativeTime(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  Future<void> _deleteChat(String chatId, String counterpartName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Conversation'),
          content: Text('Are you sure you want to remove the conversation with $counterpartName?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      try {
        final chatRef = FirebaseFirestore.instance.collection('chats').doc(chatId);
        // Remove current user from participants
        await chatRef.update({
          'participants': FieldValue.arrayRemove([currentUser.uid]),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Conversation removed')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete chat: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('My Messages', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_outline_rounded, size: 56, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Please log in to view messages',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Log in to your account to chat with buyers and sellers on campus.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Messages',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22),
        ),
      ),
      body: Column(
        children: [
          // Search Input Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.toLowerCase().trim();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search chats, products or names...',
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF2F6BFF)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 20),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
            ),
          ),

          // Realtime list of user's active chats
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .where('participants', arrayContains: currentUser.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final rawDocs = snapshot.data?.docs ?? [];

                if (rawDocs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2F6BFF).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.forum_outlined,
                              size: 56,
                              color: Color(0xFF2F6BFF),
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'No active conversations yet',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'When you contact a seller or a buyer contacts you, your chats will appear here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Filter and sort docs client-side
                final docs = rawDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  if (_searchQuery.isEmpty) return true;

                  final pTitle = (data['productTitle'] ?? '').toString().toLowerCase();
                  final bName = (data['buyerName'] ?? '').toString().toLowerCase();
                  final sName = (data['sellerName'] ?? '').toString().toLowerCase();
                  final lastMsg = (data['lastMessage'] ?? '').toString().toLowerCase();

                  return pTitle.contains(_searchQuery) ||
                      bName.contains(_searchQuery) ||
                      sName.contains(_searchQuery) ||
                      lastMsg.contains(_searchQuery);
                }).toList();

                docs.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;

                  final aTime = aData['lastMessageTime'] as Timestamp? ?? aData['updatedAt'] as Timestamp?;
                  final bTime = bData['lastMessageTime'] as Timestamp? ?? bData['updatedAt'] as Timestamp?;

                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  return bTime.compareTo(aTime);
                });

                if (docs.isEmpty) {
                  return const Center(
                    child: Text('No conversations match your search.', style: TextStyle(color: Colors.grey)),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final docChatId = doc.id;
                    final productId = data['productId'] ?? '';
                    final productTitle = data['productTitle'] ?? 'Product';
                    final productPrice = data['productPrice'] ?? '';
                    final productImage = data['productImage'] ?? '';
                    final sellerId = data['sellerId'] ?? '';
                    final sellerName = data['sellerName'] ?? 'Seller';
                    final buyerId = data['buyerId'] ?? '';
                    final buyerName = data['buyerName'] ?? 'Buyer';
                    final lastMessage = data['lastMessage'] ?? 'No messages';
                    final lastMessageSenderId = data['lastMessageSenderId'] ?? '';

                    final isSeller = currentUser.uid == sellerId;
                    final counterpartName = isSeller
                        ? (buyerName.isNotEmpty ? buyerName : 'Buyer')
                        : (sellerName.isNotEmpty ? sellerName : 'Seller');
                    final counterpartRole = isSeller ? 'Buyer' : 'Seller';

                    DateTime? time;
                    if (data['lastMessageTime'] is Timestamp) {
                      time = (data['lastMessageTime'] as Timestamp).toDate();
                    } else if (data['updatedAt'] is Timestamp) {
                      time = (data['updatedAt'] as Timestamp).toDate();
                    }

                    final timeAgo = _formatRelativeTime(time);
                    final isMeLastSender = lastMessageSenderId == currentUser.uid;

                    // Read status calculation
                    final readBy = List<String>.from(data['readBy'] ?? []);
                    final unreadCount = (data['unreadCount_${currentUser.uid}'] as num?)?.toInt() ?? 0;
                    final isUnread = !isMeLastSender && (!readBy.contains(currentUser.uid) || unreadCount > 0);

                    return Dismissible(
                      key: Key(docChatId),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) async {
                        await _deleteChat(docChatId, counterpartName);
                        return false;
                      },
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
                      ),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                chatId: docChatId,
                                productId: productId,
                                productTitle: productTitle,
                                productPrice: productPrice,
                                productImage: productImage,
                                sellerId: sellerId,
                                sellerName: sellerName,
                                buyerId: buyerId,
                                buyerName: buyerName,
                              ),
                            ),
                          );
                        },
                        onLongPress: () => _deleteChat(docChatId, counterpartName),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark
                                ? (isUnread ? const Color(0xFF1E293B) : const Color(0xFF0F172A))
                                : (isUnread ? const Color(0xFFEFF6FF) : Colors.white),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isUnread
                                  ? const Color(0xFF2F6BFF).withValues(alpha: 0.4)
                                  : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                              width: isUnread ? 1.5 : 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              // Product Image Avatar with counter part badge
                              Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: productImage.isNotEmpty
                                        ? Image.network(
                                            productImage,
                                            width: 58,
                                            height: 58,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => Container(
                                              width: 58,
                                              height: 58,
                                              color: Colors.grey.shade200,
                                              child: const Icon(Icons.broken_image_rounded, size: 24, color: Colors.grey),
                                            ),
                                          )
                                        : Container(
                                            width: 58,
                                            height: 58,
                                            color: Colors.grey.shade200,
                                            child: const Icon(Icons.image, size: 28),
                                          ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                      child: CircleAvatar(
                                        radius: 10,
                                        backgroundColor: isSeller
                                            ? const Color(0xFF10B981)
                                            : const Color(0xFF2F6BFF),
                                        child: Text(
                                          counterpartName.isNotEmpty
                                              ? counterpartName[0].toUpperCase()
                                              : 'U',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  counterpartName,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontWeight: isUnread ? FontWeight.w900 : FontWeight.bold,
                                                    fontSize: 15,
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
                                                      ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                                      : const Color(0xFF2F6BFF).withValues(alpha: 0.12),
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
                                        ),
                                        if (timeAgo.isNotEmpty)
                                          Text(
                                            timeAgo,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isUnread
                                                  ? const Color(0xFF2F6BFF)
                                                  : (isDark ? Colors.grey.shade400 : Colors.grey.shade500),
                                              fontWeight: isUnread ? FontWeight.bold : FontWeight.w500,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      '$productTitle • Rs $productPrice',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        if (isMeLastSender)
                                          const Padding(
                                            padding: EdgeInsets.only(right: 4),
                                            child: Icon(
                                              Icons.done_all_rounded,
                                              size: 14,
                                              color: Color(0xFF2F6BFF),
                                            ),
                                          ),
                                        Expanded(
                                          child: Text(
                                            lastMessage,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: isUnread
                                                  ? (isDark ? Colors.white : Colors.black87)
                                                  : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                                              fontWeight: isUnread ? FontWeight.w700 : FontWeight.normal,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        if (isUnread) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF2F6BFF),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Text(
                                              unreadCount > 0 ? '$unreadCount' : '',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: Colors.grey.shade400,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
