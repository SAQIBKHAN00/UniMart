import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';
import 'add_product_screen.dart';
import 'chats_list_screen.dart';
import 'profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int currentIndex = 0;

  final List<Widget> pages = const [
    HomeScreen(),
    AddProductScreen(),
    ChatsListScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: IndexedStack(index: currentIndex, children: pages),

      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(
              top: BorderSide(
                color: isDark
                    ? const Color(0xFF334155)
                    : Colors.grey.shade200,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: currentIndex,
            type: BottomNavigationBarType.fixed,
            backgroundColor: Theme.of(context).cardColor,
            elevation: 0,
            selectedItemColor: const Color(0xFF2F6BFF),
            unselectedItemColor: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
            showSelectedLabels: true,
            showUnselectedLabels: true,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
            onTap: (index) {
              setState(() {
                currentIndex = index;
              });
            },
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.add_circle_rounded),
                label: 'Sell',
              ),
              BottomNavigationBarItem(
                icon: StreamBuilder<QuerySnapshot>(
                  stream: currentUser == null
                      ? null
                      : FirebaseFirestore.instance
                          .collection('chats')
                          .where('participants', arrayContains: currentUser.uid)
                          .snapshots(),
                  builder: (context, snapshot) {
                    if (currentUser == null) return const Icon(Icons.forum_rounded);

                    int unreadCount = 0;
                    final uid = currentUser.uid;
                    if (snapshot.hasData && snapshot.data != null) {
                      for (final doc in snapshot.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        final lastMsgSenderId = data['lastMessageSenderId'] ?? '';
                        final readBy = List<String>.from(data['readBy'] ?? []);
                        final docUnread = (data['unreadCount_$uid'] as num?)?.toInt() ?? 0;

                        if (lastMsgSenderId != uid && (!readBy.contains(uid) || docUnread > 0)) {
                          unreadCount++;
                        }
                      }
                    }

                    if (unreadCount > 0) {
                      return Badge(
                        label: Text(
                          unreadCount > 9 ? '9+' : '$unreadCount',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                        ),
                        backgroundColor: const Color(0xFF2F6BFF),
                        child: const Icon(Icons.forum_rounded),
                      );
                    }

                    return const Icon(Icons.forum_rounded);
                  },
                ),
                label: 'Messages',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.person_rounded),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
