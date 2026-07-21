import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'product_detail_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  Future<void> removeFavorite({
    required String userId,
    required String productId,
  }) async {
    if (productId.isEmpty) return;

    await FirebaseFirestore.instance
        .collection("users")
        .doc(userId)
        .collection("favorites")
        .doc(productId)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Saved Favorites",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22),
        ),
      ),
      body: user == null
          ? const Center(child: Text("Login to view your saved favorites"))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("users")
                  .doc(user.uid)
                  .collection("favorites")
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
                              color: Colors.red.shade400.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.favorite_border_rounded,
                              size: 56,
                              color: Colors.red.shade400,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            "No favorites saved yet",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            "Tap the heart icon on any product to save it here!",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Client-side sort by savedAt descending
                final favorites = List<QueryDocumentSnapshot>.from(rawDocs);
                favorites.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aTime = aData['savedAt'] as Timestamp?;
                  final bTime = bData['savedAt'] as Timestamp?;
                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  return bTime.compareTo(aTime);
                });

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: favorites.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final favorite = favorites[index].data() as Map<String, dynamic>;
                    final productId = favorites[index].id;

                    final title = favorite["title"] ?? "Product";
                    final price = favorite["price"] ?? "0";
                    final desc = favorite["description"] ?? "";
                    final image = favorite["image"] ?? "";
                    final condition = favorite["condition"] ?? "Like New";
                    final campus = favorite["campus"] ?? "Campus";
                    final sellerId = favorite["sellerId"] ?? "";
                    final sellerName = favorite["sellerName"] ?? "Student Seller";
                    final isNegotiable = favorite["isNegotiable"] == true;

                    return InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProductDetailScreen(
                              productId: productId,
                              title: title,
                              description: desc,
                              price: price,
                              image: image,
                              sellerId: sellerId,
                              sellerName: sellerName,
                              condition: condition,
                              campus: campus,
                              isNegotiable: isNegotiable,
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
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
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: image.isNotEmpty
                                  ? Image.network(
                                      image,
                                      width: 66,
                                      height: 66,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        width: 66,
                                        height: 66,
                                        color: Colors.grey.shade200,
                                        child: const Icon(Icons.broken_image_rounded, size: 28, color: Colors.grey),
                                      ),
                                    )
                                  : Container(
                                      width: 66,
                                      height: 66,
                                      color: Colors.grey.shade200,
                                      child: const Icon(Icons.image, size: 30, color: Colors.grey),
                                    ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Rs $price",
                                    style: const TextStyle(
                                      color: Color(0xFF2F6BFF),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "$condition • $campus",
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.favorite_rounded, color: Colors.red.shade600),
                              tooltip: 'Remove Favorite',
                              onPressed: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                await removeFavorite(
                                  userId: user.uid,
                                  productId: productId,
                                );

                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Text("Removed from saved favorites"),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
