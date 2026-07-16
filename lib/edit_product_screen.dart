import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unimart/edit_product_screen.dart';

class EditProductScreen extends StatefulWidget {
  final String id;
  final String title;
  final String price;
  final String description;

  const EditProductScreen({
    super.key,
    required this.id,
    required this.title,
    required this.price,
    required this.description,
  });

  @override
  State<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends State<EditProductScreen> {
  late TextEditingController titleController;
  late TextEditingController priceController;
  late TextEditingController descController;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.title);
    priceController = TextEditingController(text: widget.price);
    descController = TextEditingController(text: widget.description);
  }

  // ✅ UPDATED FUNCTION WITH CONFIRMATION
  void updateProduct() async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Update Product"),
          content: const Text("Are you sure you want to update this product?"),
          actions: [
            // ❌ CANCEL
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text("Cancel"),
            ),

            // ✅ CONFIRM
            TextButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text("Update"),
            ),
          ],
        );
      },
    );

    // ✅ ONLY UPDATE IF USER CONFIRMS
    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection("products")
          .doc(widget.id)
          .update({
            "title": titleController.text,
            "price": priceController.text,
            "description": descController.text,
          });

      // ✅ SHOW SUCCESS MESSAGE
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Product Updated ✅")));

      Navigator.pop(context); // go back
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Product")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: "Title"),
            ),

            const SizedBox(height: 10),

            TextField(
              controller: priceController,
              decoration: const InputDecoration(labelText: "Price"),
            ),

            const SizedBox(height: 10),

            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: "Description"),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: updateProduct,
              child: const Text("Update Product"),
            ),
          ],
        ),
      ),
    );
  }
}
