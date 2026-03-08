import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'main.dart';
import 'userProfile.dart';
import 'saved.dart';
import 'widgets/main_nav_bar.dart';

class SellScreen extends StatefulWidget {
  final String? editingItemId;
  final String? editingTitle;
  final String? editingPrice;
  final String? editingCategory;
  final String? editingDescription;
  final String? editingLocation;
  final String? editingImageUrl;

  const SellScreen({
    super.key,
    this.editingItemId,
    this.editingTitle,
    this.editingPrice,
    this.editingCategory,
    this.editingDescription,
    this.editingLocation,
    this.editingImageUrl,
  });

  @override
  State<SellScreen> createState() => _SellScreenState();
}

class _SellScreenState extends State<SellScreen> {
  bool _useRegisteredLocation = false;
  String? _selectedCategory;
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _selectedImages = [];

  final List<String> _categories = [
    'Electronics',
    'Baked Goods',
    'Clothing and Footwear',
    'Fast Food',
    'Drinks and Beverages',
    'Jewelry and Accessories',
  ];

  @override
  void initState() {
    super.initState();
    // Pre-populate fields if editing
    if (widget.editingItemId != null) {
      _titleController.text = widget.editingTitle ?? '';
      _priceController.text = widget.editingPrice ?? '';
      _descriptionController.text = widget.editingDescription ?? '';
      _selectedCategory = widget.editingCategory;
      
      if (widget.editingLocation != null) {
        if (widget.editingLocation == 'Kampala, Uganda') {
          _useRegisteredLocation = true;
        } else {
          _useRegisteredLocation = false;
          _locationController.text = widget.editingLocation!;
        }
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_selectedImages.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Maximum 3 photos allowed'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImages.add(image);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Photo added (${_selectedImages.length}/3)'),
              backgroundColor: AppColors.teal,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGray,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              'assets/images/logo.jpg',
              width: 40,
              height: 40,
            ),
          ),
        ),
        title: const Text(
          'Tukwatagane',
          style: TextStyle(
            color: AppColors.darkGray,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.bookmark_border,
              color: AppColors.mediumGray,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SavedScreen(),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const UserProfileScreen(),
                  ),
                );
              },
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Color(0xFFD4C5B9),
                child: Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Screen Title
              Text(
                widget.editingItemId != null ? 'Edit Listing' : 'Sell an Item',
                style: TextStyle(
                  color: AppColors.darkGray,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              
              // Image Upload Section
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.lightGray,
                    width: 2,
                    strokeAlign: BorderSide.strokeAlignInside,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_selectedImages.isEmpty) ...[
                      Stack(
                        children: [
                          Icon(
                            Icons.camera_alt,
                            color: AppColors.teal,
                            size: 48,
                          ),
                          Positioned(
                            right: -4,
                            top: -4,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: AppColors.teal,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Upload Photos',
                        style: TextStyle(
                          color: AppColors.darkGray,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Add up to 3 photos. Clear details help items sell faster.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.mediumGray,
                          fontSize: 14,
                        ),
                      ),
                    ] else ...[
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: _selectedImages.asMap().entries.map((entry) {
                          int index = entry.key;
                          XFile image = entry.value;
                          return Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  File(image.path),
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => _removeImage(index),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 20),
                    _selectedImages.length < 3
                        ? ElevatedButton.icon(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.add, color: Colors.white),
                            label: Text(
                              _selectedImages.isEmpty 
                                ? 'Add Photo' 
                                : 'Add More (${_selectedImages.length}/3)',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.teal,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          )
                        : ElevatedButton(
                            onPressed: null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.mediumGray,
                              disabledBackgroundColor: AppColors.lightGray,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Max',
                              style: TextStyle(
                                color: AppColors.mediumGray,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Title Field
              const Text(
                'Title',
                style: TextStyle(
                  color: AppColors.darkGray,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'What are you selling?',
                  hintStyle: const TextStyle(color: AppColors.mediumGray),
                  filled: true,
                  fillColor: AppColors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.lightGray),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.lightGray),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.teal),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Price Field
              const Text(
                'Price',
                style: TextStyle(
                  color: AppColors.darkGray,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'UGX 12,000',
                  hintStyle: const TextStyle(color: AppColors.mediumGray),
                  filled: true,
                  fillColor: AppColors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.lightGray),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.lightGray),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.teal),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Category Field
              const Text(
                'Category',
                style: TextStyle(
                  color: AppColors.darkGray,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  return DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    hint: const Text(
                      'Select Category',
                      style: TextStyle(color: AppColors.mediumGray),
                    ),
                    isExpanded: true,
                    menuMaxHeight: 300,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.lightGray),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.lightGray),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.teal),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    icon: const Icon(
                      Icons.keyboard_arrow_down,
                      color: AppColors.mediumGray,
                    ),
                    dropdownColor: AppColors.white,
                    style: const TextStyle(
                      color: AppColors.darkGray,
                      fontSize: 16,
                    ),
                    items: _categories.map((String category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        alignment: AlignmentDirectional.centerStart,
                        child: SizedBox(
                          width: constraints.maxWidth - 48,
                          child: Text(
                            category,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedCategory = newValue;
                      });
                    },
                  );
                },
              ),
              const SizedBox(height: 24),
              
              // Description Field
              const Text(
                'Description',
                style: TextStyle(
                  color: AppColors.darkGray,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                maxLength: 500,
                maxLines: 4,
                onChanged: (value) {
                  setState(() {});
                },
                decoration: InputDecoration(
                  hintText: 'Describe the condition, brand, and features...',
                  hintStyle: const TextStyle(color: AppColors.mediumGray),
                  filled: true,
                  fillColor: AppColors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.lightGray),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.lightGray),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.teal),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                  counterText: '',
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${_descriptionController.text.length}/500',
                  style: const TextStyle(
                    color: AppColors.mediumGray,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Location Toggle Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.lightGray),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Use registered location',
                          style: TextStyle(
                            color: AppColors.darkGray,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        Switch(
                          value: _useRegisteredLocation,
                          onChanged: (value) {
                            setState(() {
                              _useRegisteredLocation = value;
                            });
                          },
                          activeColor: AppColors.teal,
                        ),
                      ],
                    ),
                    if (_useRegisteredLocation) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Kampala, Uganda',
                          style: TextStyle(
                            color: AppColors.mediumGray,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!_useRegisteredLocation) ...[
                const SizedBox(height: 16),
                
                // OR Divider
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: AppColors.lightGray,
                        thickness: 1,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'OR',
                        style: TextStyle(
                          color: AppColors.mediumGray,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: AppColors.lightGray,
                        thickness: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Use different location label
                const Text(
                  'Use different location',
                  style: TextStyle(
                    color: AppColors.darkGray,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Alternate Location
                TextField(
                  controller: _locationController,
                  decoration: InputDecoration(
                    hintText: 'City, Region',
                    hintStyle: const TextStyle(color: AppColors.mediumGray),
                    prefixIcon: const Icon(
                      Icons.location_on,
                      color: AppColors.mediumGray,
                    ),
                    filled: true,
                    fillColor: AppColors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.lightGray),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.lightGray),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.teal),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 32),
              
              // Post Listing Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.editingItemId != null ? 'Update Listing' : 'Post Listing',
                        style: TextStyle(
                          color: AppColors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward,
                        color: AppColors.white,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const MainNavBar(currentIndex: 2),
    );
  }
}
