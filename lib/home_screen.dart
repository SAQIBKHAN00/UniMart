import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_product_screen.dart';
import 'product_detail_screen.dart';
import 'login_screen.dart';
import 'my_products_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String searchText = "";
  String selectedCategory = "All";

  final TextEditingController searchController = TextEditingController();
  final FocusNode searchFocusNode = FocusNode();
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    searchFocusNode.dispose();
    searchController.dispose();
    super.dispose();
  }

  void updateSearchText(String value) {
    _searchDebounce?.cancel();

    _searchDebounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;

      setState(() {
        searchText = value.toLowerCase().trim();
      });
    });
  }

  Widget categoryChip(String category) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: ChoiceChip(
        label: Text(category),
        selected: selectedCategory == category,
        onSelected: (value) {
          setState(() {
            selectedCategory = category;
          });
        },
      ),
    );
  }

  Future<void> toggleFavorite({
    required String productId,
    required Map<String, dynamic> data,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    final favoriteRef = FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .collection("favorites")
        .doc(productId);

    final favoriteSnapshot = await favoriteRef.get();

    if (favoriteSnapshot.exists) {
      await favoriteRef.delete();
      return;
    }

    await favoriteRef.set({
      "productId": productId,
      "title": data["title"] ?? "",
      "price": data["price"] ?? "",
      "description": data["description"] ?? "",
      "category": data["category"] ?? "",
      "image": data["image"] ?? "",
      "createdAt": data["createdAt"],
      "savedAt": FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2F6BFF), Color(0xFF6A92FF)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.storefront,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              "UniMart",
              style: TextStyle(
                color: Colors.black,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("products")
            .orderBy("createdAt", descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No products available",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            );
          }

          final docs = snapshot.data!.docs;

          final filteredDocs = docs.where((product) {
            final data = product.data() as Map<String, dynamic>;

            final title = (data["title"] ?? "").toString().toLowerCase();

            final description = (data["description"] ?? "")
                .toString()
                .toLowerCase();

            final category = (data["category"] ?? "").toString();

            if (searchText.isNotEmpty &&
                !title.contains(searchText) &&
                !description.contains(searchText)) {
              return false;
            }

            if (selectedCategory != "All" && category != selectedCategory) {
              return false;
            }

            return true;
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2F6BFF), Color(0xFF6A92FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x204A77FF),
                        blurRadius: 24,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Find what you need",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Search, save, and sell from one place.",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: searchController,
                          focusNode: searchFocusNode,
                          textInputAction: TextInputAction.search,
                          autocorrect: false,
                          enableSuggestions: false,
                          onChanged: updateSearchText,
                          decoration: InputDecoration(
                            hintText: "Search products, categories...",
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: searchText.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      setState(() {
                                        searchController.clear();
                                        searchText = "";
                                      });
                                      searchFocusNode.requestFocus();
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SizedBox(
                height: 52,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  children: [
                    categoryChip("All"),
                    categoryChip("Mobiles"),
                    categoryChip("Electronics"),
                    categoryChip("Books"),
                    categoryChip("Furniture"),
                    categoryChip("Vehicles"),
                    categoryChip("Fashion"),
                    categoryChip("Sports"),
                    categoryChip("Services"),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: MediaQuery.of(context).size.width > 1200
                        ? 5
                        : 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.74,
                  ),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final product = filteredDocs[index];
                    final data = product.data() as Map<String, dynamic>;
                    final currentUser = FirebaseAuth.instance.currentUser;

                    return StreamBuilder<DocumentSnapshot>(
                      stream: currentUser == null
                          ? null
                          : FirebaseFirestore.instance
                                .collection("users")
                                .doc(currentUser.uid)
                                .collection("favorites")
                                .doc(product.id)
                                .snapshots(),
                      builder: (context, favoriteSnapshot) {
                        final isFavorite =
                            favoriteSnapshot.data?.exists ?? false;

                        return InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProductDetailScreen(
                                  productId: product.id,
                                  title: data["title"] ?? "",
                                  description: data["description"] ?? "",
                                  price: data["price"] ?? "",
                                  image: data["image"] ?? "",
                                ),
                              ),
                            );
                          },
                          child: Card(
                            elevation: 0,
                            color: Colors.white,
                            clipBehavior: Clip.antiAlias,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 6,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      data["image"] != null &&
                                              data["image"] != ""
                                          ? Image.network(
                                              data["image"],
                                              fit: BoxFit.cover,
                                            )
                                          : Container(
                                              color: const Color(0xFFF0F4FA),
                                              child: const Center(
                                                child: Icon(
                                                  Icons.image_outlined,
                                                  size: 42,
                                                  color: Color(0xFF7A8799),
                                                ),
                                              ),
                                            ),
                                      Positioned(
                                        top: 10,
                                        left: 10,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(
                                              alpha: 0.55,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            data["category"] ?? "",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        top: 10,
                                        right: 10,
                                        child: Material(
                                          color: Colors.white,
                                          shape: const CircleBorder(),
                                          elevation: 2,
                                          child: IconButton(
                                            iconSize: 18,
                                            constraints: const BoxConstraints(
                                              minWidth: 40,
                                              minHeight: 40,
                                            ),
                                            icon: Icon(
                                              isFavorite
                                                  ? Icons.favorite
                                                  : Icons.favorite_border,
                                              color: isFavorite
                                                  ? Colors.red
                                                  : Colors.black87,
                                            ),
                                            onPressed: () async {
                                              await toggleFavorite(
                                                productId: product.id,
                                                data: data,
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 5,
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "Rs ${data["price"]}",
                                          style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF162033),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          data["title"] ?? "",
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            height: 1.25,
                                          ),
                                        ),
                                        const Spacer(),
                                        Row(
                                          children: const [
                                            Icon(
                                              Icons.location_on_outlined,
                                              size: 13,
                                              color: Colors.grey,
                                            ),
                                            SizedBox(width: 3),
                                            Expanded(
                                              child: Text(
                                                "Abbottabad",
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 11,
                                                ),
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
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
