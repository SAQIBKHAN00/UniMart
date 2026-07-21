import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'product_detail_screen.dart';
import 'login_screen.dart';
import 'chats_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String searchText = "";
  String selectedCategory = "All";
  String selectedCampus = "All Campuses";
  String selectedSort = "Latest";

  final TextEditingController searchController = TextEditingController();
  final FocusNode searchFocusNode = FocusNode();
  Timer? _searchDebounce;

  final List<String> categories = [
    "All",
    "Mobiles",
    "Electronics",
    "Books",
    "Furniture",
    "Vehicles",
    "Fashion",
    "Sports",
    "Services",
  ];

  final List<String> campuses = [
    "All Campuses",
    "COMSATS Abbottabad",
    "COMSATS Islamabad",
    "NUST Islamabad",
    "FAST Islamabad",
    "UET Lahore",
  ];

  final List<String> sortOptions = [
    "Latest",
    "Price: Low to High",
    "Price: High to Low",
  ];

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

  IconData _getCategoryIcon(String cat) {
    switch (cat) {
      case 'Mobiles':
        return Icons.smartphone_rounded;
      case 'Electronics':
        return Icons.laptop_mac_rounded;
      case 'Books':
        return Icons.menu_book_rounded;
      case 'Furniture':
        return Icons.chair_rounded;
      case 'Vehicles':
        return Icons.directions_car_rounded;
      case 'Fashion':
        return Icons.checkroom_rounded;
      case 'Sports':
        return Icons.sports_basketball_rounded;
      case 'Services':
        return Icons.build_rounded;
      default:
        return Icons.grid_view_rounded;
    }
  }

  Widget categoryChip(String category) {
    final isSelected = selectedCategory == category;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        avatar: Icon(
          _getCategoryIcon(category),
          size: 16,
          color: isSelected
              ? Colors.white
              : (isDark ? Colors.grey.shade400 : const Color(0xFF2F6BFF)),
        ),
        label: Text(category),
        selected: isSelected,
        selectedColor: const Color(0xFF2F6BFF),
        checkmarkColor: Colors.white,
        showCheckmark: false,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        side: BorderSide(
          color: isSelected
              ? const Color(0xFF2F6BFF)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : (isDark ? Colors.grey.shade200 : Colors.black87),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          fontSize: 13,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
      "condition": data["condition"] ?? "",
      "campus": data["campus"] ?? "",
      "sellerId": data["userId"] ?? "",
      "sellerName": data["sellerName"] ?? "",
      "isNegotiable": data["isNegotiable"] == true,
      "createdAt": data["createdAt"],
      "savedAt": FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2F6BFF), Color(0xFF6366F1)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2F6BFF).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.storefront_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "UniMart",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  "Campus Marketplace",
                  style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.forum_outlined, color: Color(0xFF2F6BFF)),
            onPressed: () {
              if (currentUser == null) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
              } else {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatsListScreen()));
              }
            },
            tooltip: 'Messages',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {});
        },
        color: const Color(0xFF2F6BFF),
        child: CustomScrollView(
          slivers: [
            // Top Hero Search & Filters Banner
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search Field
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: searchController,
                        focusNode: searchFocusNode,
                        onChanged: updateSearchText,
                        decoration: InputDecoration(
                          hintText: "Search books, mobiles, electronics...",
                          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF2F6BFF)),
                          suffixIcon: searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 20),
                                  onPressed: () {
                                    searchController.clear();
                                    updateSearchText("");
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Campus & Sort Controls Bar
                    Row(
                      children: [
                        // Campus Filter Dropdown Pill
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedCampus,
                                isExpanded: true,
                                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF2F6BFF)),
                                items: campuses.map((campus) {
                                  return DropdownMenuItem(
                                    value: campus,
                                    child: Row(
                                      children: [
                                        const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF2F6BFF)),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            campus,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      selectedCampus = value;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Sort Filter Dropdown Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedSort,
                              icon: const Icon(Icons.swap_vert_rounded, color: Color(0xFF2F6BFF)),
                              items: sortOptions.map((sort) {
                                return DropdownMenuItem(
                                  value: sort,
                                  child: Text(
                                    sort,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    selectedSort = value;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Categories Horizontal Bar
                    SizedBox(
                      height: 42,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: categories.map(categoryChip).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Products Section Stream
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection("products").snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text("Error loading products: ${snapshot.error}"),
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 220,
                        childAspectRatio: 0.75,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => Container(
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        childCount: 6,
                      ),
                    ),
                  );
                }

                var docs = snapshot.data?.docs ?? [];

                // Filter by category
                if (selectedCategory != "All") {
                  docs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return (data["category"] ?? "") == selectedCategory;
                  }).toList();
                }

                // Filter by campus
                if (selectedCampus != "All Campuses") {
                  docs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return (data["campus"] ?? "COMSATS Abbottabad") == selectedCampus;
                  }).toList();
                }

                // Filter by search text
                if (searchText.isNotEmpty) {
                  docs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final title = (data["title"] ?? "").toString().toLowerCase();
                    final desc = (data["description"] ?? "").toString().toLowerCase();
                    final cat = (data["category"] ?? "").toString().toLowerCase();
                    return title.contains(searchText) || desc.contains(searchText) || cat.contains(searchText);
                  }).toList();
                }

                // Helper to parse price reliably
                double parsePrice(dynamic raw) {
                  if (raw == null) return 0;
                  final cleaned = raw.toString().replaceAll(RegExp(r'[^0-9.]'), '');
                  return double.tryParse(cleaned) ?? 0;
                }

                // Sort docs client-side
                docs.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;

                  if (selectedSort == "Price: Low to High") {
                    return parsePrice(aData["price"]).compareTo(parsePrice(bData["price"]));
                  } else if (selectedSort == "Price: High to Low") {
                    return parsePrice(bData["price"]).compareTo(parsePrice(aData["price"]));
                  } else {
                    // Latest default
                    final aTime = aData["createdAt"] as Timestamp?;
                    final bTime = bData["createdAt"] as Timestamp?;
                    if (aTime == null && bTime == null) return 0;
                    if (aTime == null) return 1;
                    if (bTime == null) return -1;
                    return bTime.compareTo(aTime);
                  }
                });

                if (docs.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
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
                              Icons.search_off_rounded,
                              size: 48,
                              color: Color(0xFF2F6BFF),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "No products found",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            "Try searching with different keywords or clearing filters.",
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 220,
                      childAspectRatio: 0.75,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final doc = docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final productId = doc.id;
                        final title = data["title"] ?? "Product";
                        final price = data["price"] ?? "0";
                        final desc = data["description"] ?? "";
                        final image = data["image"] ?? "";
                        final condition = data["condition"] ?? "Like New";
                        final campus = data["campus"] ?? "Campus";
                        final isNegotiable = data["isNegotiable"] == true;
                        final sellerId = data["userId"] ?? "";
                        final sellerName = data["sellerName"] ?? "Student Seller";

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
                          borderRadius: BorderRadius.circular(22),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Thumbnail Stack with Favorite Button & Condition Tag
                                Expanded(
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: ClipRRect(
                                          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                                          child: image.isNotEmpty
                                              ? Image.network(
                                                  image,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) => Container(
                                                    color: Colors.grey.shade200,
                                                    child: const Icon(Icons.broken_image_rounded, size: 40, color: Colors.grey),
                                                  ),
                                                )
                                              : Container(
                                                  color: Colors.grey.shade200,
                                                  child: const Icon(Icons.image_rounded, size: 40, color: Colors.grey),
                                                ),
                                        ),
                                      ),

                                      // Condition Pill Tag
                                      Positioned(
                                        top: 10,
                                        left: 10,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.65),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            condition,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),

                                      // Favorite Heart Button
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: currentUser == null
                                            ? Container(
                                                padding: const EdgeInsets.all(6),
                                                decoration: const BoxDecoration(
                                                  color: Colors.white,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(Icons.favorite_border, size: 18, color: Colors.grey),
                                              )
                                            : StreamBuilder<DocumentSnapshot>(
                                                stream: FirebaseFirestore.instance
                                                    .collection("users")
                                                    .doc(currentUser.uid)
                                                    .collection("favorites")
                                                    .doc(productId)
                                                    .snapshots(),
                                                builder: (context, favSnap) {
                                                  final isFav = favSnap.data?.exists ?? false;

                                                  return GestureDetector(
                                                    onTap: () => toggleFavorite(productId: productId, data: data),
                                                    child: Container(
                                                      padding: const EdgeInsets.all(6),
                                                      decoration: BoxDecoration(
                                                        color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                                        shape: BoxShape.circle,
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: Colors.black.withValues(alpha: 0.15),
                                                            blurRadius: 6,
                                                          ),
                                                        ],
                                                      ),
                                                      child: Icon(
                                                        isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                                        size: 18,
                                                        color: isFav ? Colors.red.shade600 : Colors.grey,
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Details Padding Container
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 4),

                                      // Price & Negotiable Badge Row
                                      Row(
                                        children: [
                                          Text(
                                            "Rs $price",
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFF2F6BFF),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          if (isNegotiable)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Text(
                                                "Neg",
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF10B981),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),

                                      // Campus Location Tag
                                      Row(
                                        children: [
                                          const Icon(Icons.location_on_outlined, size: 12, color: Colors.grey),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              campus,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      childCount: docs.length,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
