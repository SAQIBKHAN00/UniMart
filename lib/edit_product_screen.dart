// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditProductScreen extends StatefulWidget {
  final String id;
  final String title;
  final String price;
  final String description;
  final String category;
  final String condition;
  final String campus;
  final bool isNegotiable;

  const EditProductScreen({
    super.key,
    required this.id,
    required this.title,
    required this.price,
    required this.description,
    this.category = "Mobiles",
    this.condition = "Like New",
    this.campus = "COMSATS Abbottabad",
    this.isNegotiable = false,
  });

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  late TextEditingController titleController;
  late TextEditingController priceController;
  late TextEditingController descController;

  late String selectedCategory;
  late String selectedCondition;
  late String selectedCampus;
  late bool isNegotiable;
  bool isUpdating = false;

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
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.title);
    priceController = TextEditingController(text: widget.price);
    descController = TextEditingController(text: widget.description);

    selectedCategory = categories.contains(widget.category) ? widget.category : categories.first;
    selectedCondition = conditions.contains(widget.condition) ? widget.condition : conditions[1];
    selectedCampus = campuses.contains(widget.campus) ? widget.campus : campuses.first;
    isNegotiable = widget.isNegotiable;
  }

  @override
  void dispose() {
    titleController.dispose();
    priceController.dispose();
    descController.dispose();
    super.dispose();
  }

  void updateProduct() async {
    final title = titleController.text.trim();
    final priceStr = priceController.text.trim().replaceAll(',', '').replaceAll(' ', '');
    final desc = descController.text.trim();

    if (title.isEmpty || priceStr.isEmpty || desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all required fields")),
      );
      return;
    }

    bool? confirm = await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text("Save Listing Changes"),
          content: const Text("Are you sure you want to save updates to this product?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2F6BFF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Save"),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      setState(() => isUpdating = true);
      try {
        final nav = Navigator.of(context);
        final messenger = ScaffoldMessenger.of(context);

        await FirebaseFirestore.instance
            .collection("products")
            .doc(widget.id)
            .update({
          "title": title,
          "price": priceStr,
          "description": desc,
          "category": selectedCategory,
          "condition": selectedCondition,
          "campus": selectedCampus,
          "isNegotiable": isNegotiable,
          "updatedAt": FieldValue.serverTimestamp(),
        });

        messenger.showSnackBar(
          const SnackBar(
            content: Text("Product Listing Updated ✅"),
            backgroundColor: Color(0xFF10B981),
          ),
        );

        nav.pop();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to update product: $e")),
          );
        }
      } finally {
        if (mounted) setState(() => isUpdating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Edit Product",
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Product Title",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                hintText: "Product Title",
                prefixIcon: Icon(Icons.title_rounded, color: Color(0xFF2F6BFF)),
              ),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Category", style: TextStyle(fontWeight: FontWeight.bold)),
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
                      const Text("Campus", style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: selectedCampus,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        items: campuses.map((c) {
                          return DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis));
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

            const Text("Item Condition", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Price", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: priceController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        decoration: const InputDecoration(
                          prefixText: "Rs ",
                          prefixStyle: TextStyle(color: Color(0xFF2F6BFF), fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  children: [
                    const Text("Negotiable?", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
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

            const Text("Description", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: descController,
              maxLines: 4,
              decoration: const InputDecoration(hintText: "Product description..."),
            ),
            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2F6BFF),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                onPressed: isUpdating ? null : updateProduct,
                child: isUpdating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        "Save Product Changes",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
