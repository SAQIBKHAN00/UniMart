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

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text("Favorites"),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2F6BFF), Color(0xFF6A92FF)],
            ),
          ),
        ),
        foregroundColor: Colors.white,
      ),
      body: user == null
          ? const Center(child: Text("Login to see your favorites"))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("users")
                  .doc(user.uid)
                  .collection("favorites")
                  .orderBy("savedAt", descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No favorites saved yet"));
                }

                final favorites = snapshot.data!.docs;

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: favorites.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final favorite =
                        favorites[index].data() as Map<String, dynamic>;

                    final productId = favorites[index].id;

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),

                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child:
                              favorite["image"] != null &&
                                  favorite["image"] != ""
                              ? Image.network(
                                  favorite["image"],
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  width: 64,
                                  height: 64,
                                  color: const Color(0xFFF0F4FA),
                                  child: const Icon(
                                    Icons.image_outlined,
                                    color: Color(0xFF7A8799),
                                  ),
                                ),
                        ),

                        title: Text(
                          favorite["title"] ?? "",
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),

                        subtitle: Text(
                          "Rs ${favorite["price"] ?? ""}",
                          style: const TextStyle(
                            color: Color(0xFF2F6BFF),
                            fontWeight: FontWeight.w700,
                          ),
                        ),

                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProductDetailScreen(
                                productId: productId,
                                title: favorite["title"] ?? "",
                                description: favorite["description"] ?? "",
                                price: favorite["price"] ?? "",
                                image: favorite["image"] ?? "",
                              ),
                            ),
                          );
                        },

                        trailing: IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          onPressed: () async {
                            await removeFavorite(
                              userId: user.uid,
                              productId: productId,
                            );

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Removed from favorites"),
                                ),
                              );
                            }
                          },
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
