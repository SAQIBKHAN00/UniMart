import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import 'chat_screen.dart';

class ProductDetailScreen extends StatelessWidget {
  final String productId;
  final String title;
  final String description;
  final String price;
  final String image;
  final String sellerId;
  final String sellerName;
  final String condition;
  final String campus;
  final bool isNegotiable;

  const ProductDetailScreen({
    super.key,
    required this.productId,
    required this.title,
    required this.description,
    required this.price,
    required this.image,
    this.sellerId = '',
    this.sellerName = 'Verified Student Seller',
    this.condition = 'Like New',
    this.campus = 'COMSATS Abbottabad',
    this.isNegotiable = true,
  });

  Future<void> toggleFavorite(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
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
      "title": title,
      "price": price,
      "description": description,
      "image": image,
      "condition": condition,
      "campus": campus,
      "savedAt": FieldValue.serverTimestamp(),
    });
  }

  void _showContactOptions(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    if (sellerId.isNotEmpty && user.uid == sellerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("This is your own product listing."),
        ),
      );
      return;
    }

    final buyerName = (user.displayName?.trim().isNotEmpty == true)
        ? user.displayName!.trim()
        : (user.email?.split('@').first ?? 'Student');

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Contact $sellerName',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2F6BFF).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.forum_rounded, color: Color(0xFF2F6BFF)),
                ),
                title: const Text(
                  'In-App Realtime Chat',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Send messages & negotiate directly'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        productId: productId,
                        productTitle: title,
                        productPrice: price,
                        productImage: image,
                        sellerId: sellerId,
                        sellerName: sellerName,
                        buyerId: user.uid,
                        buyerName: buyerName,
                      ),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.local_offer_rounded, color: Color(0xFF10B981)),
                ),
                title: const Text(
                  'Make a Counter Offer',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Propose your target purchase price'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        productId: productId,
                        productTitle: title,
                        productPrice: price,
                        productImage: image,
                        sellerId: sellerId,
                        sellerName: sellerName,
                        buyerId: user.uid,
                        buyerName: buyerName,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showZoomImage(BuildContext context) {
    if (image.isEmpty) return;
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
                  child: Image.network(
                    image,
                    errorBuilder: (context, error, stackTrace) => const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image_rounded, size: 64, color: Colors.white),
                        SizedBox(height: 8),
                        Text('Unable to load image', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Product Details",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (user != null)
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("users")
                  .doc(user.uid)
                  .collection("favorites")
                  .doc(productId)
                  .snapshots(),
              builder: (context, snapshot) {
                final isFavorite = snapshot.data?.exists ?? false;

                return IconButton(
                  onPressed: () => toggleFavorite(context),
                  icon: Icon(
                    isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: isFavorite ? Colors.red.shade600 : Colors.grey,
                  ),
                );
              },
            )
          else
            IconButton(
              onPressed: () => toggleFavorite(context),
              icon: const Icon(Icons.favorite_border_rounded),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Box with Curved Corners & Tap to Zoom
            Padding(
              padding: const EdgeInsets.all(16),
              child: GestureDetector(
                onTap: () => _showZoomImage(context),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    width: double.infinity,
                    height: 320,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: image.isNotEmpty
                              ? Image.network(
                                  image,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    color: Colors.grey.shade300,
                                    child: const Center(
                                      child: Icon(Icons.broken_image_rounded, size: 72, color: Colors.grey),
                                    ),
                                  ),
                                )
                              : Container(
                                  color: Colors.grey.shade300,
                                  child: const Center(
                                    child: Icon(Icons.image, size: 72, color: Colors.grey),
                                  ),
                                ),
                        ),
                        Positioned(
                          bottom: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.zoom_in_rounded, color: Colors.white, size: 16),
                                SizedBox(width: 4),
                                Text(
                                  'Tap to Zoom',
                                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Main Product Details Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            "Rs $price",
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF2F6BFF),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isNegotiable)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                "Negotiable",
                                style: TextStyle(
                                  color: Color(0xFF10B981),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Tags Row (Condition & Campus)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(
                            avatar: const Icon(Icons.verified_rounded, size: 16, color: Color(0xFF2F6BFF)),
                            label: Text('Condition: $condition'),
                            backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF),
                            side: BorderSide.none,
                            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          Chip(
                            avatar: const Icon(Icons.location_on_rounded, size: 16, color: Color(0xFF10B981)),
                            label: Text(campus),
                            backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFECFDF5),
                            side: BorderSide.none,
                            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Seller Profile Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor: const Color(0xFF2F6BFF).withValues(alpha: 0.15),
                              child: Text(
                                sellerName.isNotEmpty ? sellerName[0].toUpperCase() : 'S',
                                style: const TextStyle(
                                  color: Color(0xFF2F6BFF),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          sellerName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Verified Campus Student Seller',
                                    style: TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      const Text(
                        "Description",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),

                      Text(
                        description.isNotEmpty ? description : "No description provided for this item.",
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: isDark ? Colors.grey.shade300 : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Campus Safety Tip Card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.shield_outlined, color: Color(0xFFF59E0B), size: 22),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Safety Tip: Meet in well-lit public campus spots (e.g. library, cafeteria) for safe transactions.',
                                style: TextStyle(fontSize: 11, height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),

      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2F6BFF),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: () => _showContactOptions(context),
                    icon: const Icon(Icons.forum_rounded, color: Colors.white),
                    label: const Text(
                      "Contact Seller",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
