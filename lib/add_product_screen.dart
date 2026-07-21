import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'login_screen.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final titleController = TextEditingController();
  final priceController = TextEditingController();
  final descController = TextEditingController();

  XFile? imageFile;
  bool isUploading = false;
  bool isNegotiable = false;

  String selectedCategory = "Mobiles";
  String selectedCondition = "Like New";
  String selectedCampus = "COMSATS Abbottabad";

  final List<String> categories = [
    "Mobiles",
    "Electronics",
    "Books",
    "Furniture",
    "Vehicles",
    "Fashion",
    "Sports",
    "Services",
  ];

  final List<String> conditions = [
    "Brand New",
    "Like New",
    "Good Condition",
    "Fair",
  ];

  final List<String> campuses = [
    "COMSATS Abbottabad",
    "COMSATS Islamabad",
    "NUST Islamabad",
    "FAST Islamabad",
    "UET Lahore",
    "General / All",
  ];

  @override
  void dispose() {
    titleController.dispose();
    priceController.dispose();
    descController.dispose();
    super.dispose();
  }

  Future<void> pickImage(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1024,
      );

      if (picked != null) {
        setState(() {
          imageFile = picked;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to pick image: $e")),
      );
    }
  }

  void _showImageOptions() {
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
                    pickImage(ImageSource.camera);
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
                    pickImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool validateProduct() {
    final title = titleController.text.trim();
    final priceStr = priceController.text.trim().replaceAll(',', '').replaceAll(' ', '');
    final description = descController.text.trim();

    if (title.isEmpty || priceStr.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Please fill all required product details"),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
      return false;
    }

    if (imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Please attach a photo of your item"),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
      return false;
    }

    if (double.tryParse(priceStr) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Please enter a valid numeric price"),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
      return false;
    }

    return true;
  }

  void addProduct() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please log in to post a product listing"),
        ),
      );
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }

    try {
      if (!validateProduct()) return;

      setState(() => isUploading = true);

      String imageUrl = "";

      if (imageFile != null) {
        try {
          var uri = Uri.parse(
            "https://api.cloudinary.com/v1_1/dszakogia/image/upload",
          );

          var request = http.MultipartRequest("POST", uri);
          request.fields["upload_preset"] = "unimart_upload";

          var bytes = await imageFile!.readAsBytes();
          request.files.add(
            http.MultipartFile.fromBytes("file", bytes, filename: imageFile!.name),
          );

          var response = await request.send();
          var resData = await response.stream.toBytes();
          var resString = utf8.decode(resData);
          var jsonData = json.decode(resString);

          if (response.statusCode == 200 && jsonData["secure_url"] != null) {
            imageUrl = jsonData["secure_url"];
          } else {
            // Fallback to base64 Data URI so image upload never fails
            final base64Str = base64Encode(bytes);
            final ext = imageFile!.name.split('.').last.toLowerCase();
            final mime = (ext == 'png') ? 'image/png' : 'image/jpeg';
            imageUrl = 'data:$mime;base64,$base64Str';
          }
        } catch (_) {
          // Fallback to base64 Data URI on network failure
          var bytes = await imageFile!.readAsBytes();
          final base64Str = base64Encode(bytes);
          final ext = imageFile!.name.split('.').last.toLowerCase();
          final mime = (ext == 'png') ? 'image/png' : 'image/jpeg';
          imageUrl = 'data:$mime;base64,$base64Str';
        }
      }

      final sellerName = user.displayName?.trim().isNotEmpty == true
          ? user.displayName!.trim()
          : (user.email?.split('@').first ?? 'UniMart Seller');

      final cleanPrice = priceController.text.trim().replaceAll(',', '').replaceAll(' ', '');

      await FirebaseFirestore.instance.collection("products").add({
        "title": titleController.text.trim(),
        "price": cleanPrice,
        "description": descController.text.trim(),
        "category": selectedCategory,
        "condition": selectedCondition,
        "campus": selectedCampus,
        "isNegotiable": isNegotiable,
        "image": imageUrl,
        "createdAt": FieldValue.serverTimestamp(),
        "userId": user.uid,
        "sellerName": sellerName,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 10),
                Text('Product Posted Successfully! 🎉', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        );

        titleController.clear();
        priceController.clear();
        descController.clear();

        setState(() {
          imageFile = null;
          selectedCategory = "Mobiles";
          selectedCondition = "Like New";
          selectedCampus = "COMSATS Abbottabad";
          isNegotiable = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to publish product: $e"),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Sell an Item",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Photo Picker Box
            const Text(
              "Item Photo",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _showImageOptions,
              child: Container(
                width: double.infinity,
                height: 180,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: imageFile != null
                        ? const Color(0xFF10B981)
                        : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    width: imageFile != null ? 2 : 1.5,
                  ),
                ),
                child: imageFile != null
                    ? Stack(
                        children: [
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: FutureBuilder<List<int>>(
                                future: imageFile!.readAsBytes(),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData) {
                                    return Image.memory(
                                      Uint8List.fromList(snapshot.data!),
                                      fit: BoxFit.cover,
                                    );
                                  }
                                  return const Center(child: CircularProgressIndicator());
                                },
                              ),
                            ),
                          ),
                          Positioned(
                            top: 10,
                            right: 10,
                            child: CircleAvatar(
                              backgroundColor: Colors.black.withValues(alpha: 0.6),
                              child: IconButton(
                                icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 20),
                                onPressed: _showImageOptions,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2F6BFF).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.add_a_photo_rounded,
                              size: 32,
                              color: Color(0xFF2F6BFF),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            "Tap to add product photo",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "Clear photos get 3x faster responses!",
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // Section 2: Product Title
            const Text(
              "Product Title",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: "e.g. iPhone 13 Pro 128GB, Engineering Physics Book",
                prefixIcon: Icon(Icons.title_rounded, color: Color(0xFF2F6BFF)),
              ),
            ),
            const SizedBox(height: 20),

            // Section 3: Category & Campus Row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Category",
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: selectedCategory,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        items: categories.map((cat) {
                          return DropdownMenuItem(value: cat, child: Text(cat));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => selectedCategory = val);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Campus",
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: selectedCampus,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        items: campuses.map((c) {
                          return DropdownMenuItem(
                            value: c,
                            child: Text(c, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => selectedCampus = val);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Section 4: Condition Selector Chips
            const Text(
              "Item Condition",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: conditions.map((cond) {
                final isSelected = selectedCondition == cond;
                return ChoiceChip(
                  label: Text(cond),
                  selected: isSelected,
                  selectedColor: const Color(0xFF2F6BFF),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : (isDark ? Colors.grey.shade200 : Colors.black87),
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => selectedCondition = cond);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Section 5: Price & Negotiable Switch
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Listing Price",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: priceController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        decoration: const InputDecoration(
                          hintText: "4500",
                          prefixText: "Rs ",
                          prefixStyle: TextStyle(color: Color(0xFF2F6BFF), fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      "Price Negotiable?",
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Switch(
                      value: isNegotiable,
                      activeTrackColor: const Color(0xFF10B981),
                      onChanged: (val) => setState(() => isNegotiable = val),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Section 6: Description Field
            const Text(
              "Description",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descController,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: "Mention item details, reason for selling, warranty, included accessories...",
              ),
            ),
            const SizedBox(height: 30),

            // Publish Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2F6BFF),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: isUploading ? null : addProduct,
                icon: isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload_rounded, color: Colors.white),
                label: Text(
                  isUploading ? "Publishing Item..." : "Publish Item Now",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
