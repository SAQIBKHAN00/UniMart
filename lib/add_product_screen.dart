import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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

  String selectedCategory = "Mobiles";

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

  Future pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);

    if (picked != null) {
      setState(() {
        imageFile = picked;
      });
    }
  }

  bool validateProduct() {
    final title = titleController.text.trim();
    final price = priceController.text.trim();
    final description = descController.text.trim();

    if (title.isEmpty || price.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all product details")),
      );
      return false;
    }

    if (imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a product image")),
      );
      return false;
    }

    if (double.tryParse(price) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid price")),
      );
      return false;
    }

    return true;
  }

  void addProduct() async {
    try {
      if (!validateProduct()) {
        return;
      }

      String imageUrl = "";

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

      var resString = String.fromCharCodes(resData);

      var jsonData = json.decode(resString);

      imageUrl = jsonData["secure_url"];

      await FirebaseFirestore.instance.collection("products").add({
        "title": titleController.text.trim(),
        "price": priceController.text.trim(),
        "description": descController.text.trim(),
        "category": selectedCategory,
        "image": imageUrl,
        "createdAt": DateTime.now(),
        "userId": FirebaseAuth.instance.currentUser!.uid,
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Product Added ✅")));

      titleController.clear();
      priceController.clear();
      descController.clear();

      setState(() {
        imageFile = null;
        selectedCategory = "Mobiles";
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text("Sell Product"),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2F6BFF), Color(0xFF5A8CFF)],
            ),
          ),
        ),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: pickImage,
                      child: Container(
                        height: 170,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6F8FC),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFD8E2F0)),
                        ),
                        child: imageFile == null
                            ? const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate_outlined,
                                    size: 42,
                                    color: Color(0xFF2F6BFF),
                                  ),
                                  SizedBox(height: 10),
                                  Text("Tap to select product image"),
                                ],
                              )
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: Image.network(
                                  imageFile!.path,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: "Product Title",
                        prefixIcon: Icon(Icons.title),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Price",
                        prefixIcon: Icon(Icons.currency_rupee),
                      ),
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: descController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: "Description",
                        prefixIcon: Icon(Icons.description_outlined),
                      ),
                    ),

                    const SizedBox(height: 12),

                    DropdownButtonFormField<String>(
                      value: selectedCategory,
                      decoration: const InputDecoration(
                        labelText: "Category",
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      items: categories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedCategory = value!;
                        });
                      },
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2F6BFF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: addProduct,
                        child: const Text(
                          "Add Product",
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
