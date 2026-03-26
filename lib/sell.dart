import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import 'main.dart';
import 'saved.dart';
import 'widgets/main_nav_bar.dart';
import 'core/api_client.dart';
import 'core/api_exception.dart';
import 'core/ui/app_toast.dart';
import 'models/models.dart';
import 'config/campus_zones.dart';

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
  bool _isLoading = false;
  bool _isLocationLoading = true;
  bool _useRegisteredLocation = false;
  String _registeredLocationLabel = 'Loading...';
  double? _registeredLocationLat;
  double? _registeredLocationLng;
  String? _selectedCategory;
  List<ListingImageResponse> _existingImages = [];
  String? _selectedZone;

  static const _categoryCodeMap = {
    'Electronics': 'ELECTRONICS',
    'Baked Goods': 'BAKERY',
    'Clothing and Footwear': 'CLOTHING',
    'Fast Food': 'FAST_FOOD',
    'Drinks and Beverages': 'BEVERAGES',
    'Jewelry and Accessories': 'BEAUTY',
  };
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
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
    _loadRegisteredLocation();
    // Pre-populate fields if editing
    if (widget.editingItemId != null) {
      _titleController.text = widget.editingTitle ?? '';
      _priceController.text = widget.editingPrice ?? '';
      _descriptionController.text = widget.editingDescription ?? '';
      _selectedCategory = widget.editingCategory;
      _loadExistingImages();

      if (widget.editingLocation != null) {
        if (widget.editingLocation == 'useRegistered') {
          _useRegisteredLocation = true;
        } else {
          _useRegisteredLocation = false;
          if (campusZones.any((z) => z.name == widget.editingLocation)) {
            _selectedZone = widget.editingLocation;
          }
        }
      }
    }
  }

  Future<void> _loadExistingImages() async {
    try {
      final resp = await apiClient.dio.get('/listings/${widget.editingItemId}');
      final listing = ListingResponse.fromJson(resp.data);
      if (mounted) setState(() => _existingImages = listing.images);
    } catch (_) {}
  }

  Future<void> _removeExistingImage(ListingImageResponse img) async {
    try {
      await apiClient.dio.delete(
        '/listings/${widget.editingItemId}/images/${img.id}',
      );
      if (mounted)
        setState(() => _existingImages.removeWhere((i) => i.id == img.id));
    } catch (_) {}
  }

  Future<void> _loadRegisteredLocation() async {
    try {
      final resp = await apiClient.dio.get('/users/profile');
      final profile = UserProfile.fromJson(resp.data);
      final loc = profile.registeredLocation ?? profile.alternateLocation;
      final fallback =
          loc?.label ?? profile.campus ?? 'Your registered location';
      final label = zoneLabel(loc?.lat, loc?.lng, fallback: fallback);
      if (mounted) {
        setState(() {
          _registeredLocationLabel = label;
          _registeredLocationLat = loc?.lat;
          _registeredLocationLng = loc?.lng;
          _isLocationLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _registeredLocationLabel = 'Your registered location';
          _isLocationLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_existingImages.length + _selectedImages.length >= 1) {
      AppToast.warning(context, 'Only 1 photo is allowed');
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
          AppToast.info(context, 'Photo added (${_selectedImages.length}/1)');
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Error picking image: $e');
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _submitListing() async {
    final title = _titleController.text.trim();
    final priceText = _priceController.text.trim();
    final description = _descriptionController.text.trim();

    if (title.isEmpty) {
      AppToast.warning(context, 'Please enter a title');
      return;
    }
    if (priceText.isEmpty) {
      AppToast.warning(context, 'Please enter a price');
      return;
    }
    final price = int.tryParse(priceText.replaceAll(',', ''));
    if (price == null || price <= 0) {
      AppToast.warning(context, 'Please enter a valid price');
      return;
    }
    if (_selectedCategory == null) {
      AppToast.warning(context, 'Please select a category');
      return;
    }
    if (!_useRegisteredLocation && _selectedZone == null) {
      AppToast.warning(context, 'Please select a location zone');
      return;
    }
    if (_useRegisteredLocation && _isLocationLoading) {
      AppToast.info(context, 'Your location is still loading, please wait a moment');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final categoryCode =
          _categoryCodeMap[_selectedCategory!] ?? _selectedCategory!;

      ListingResponse listing;
      if (widget.editingItemId != null) {
        final centroid = _selectedZone != null
            ? zoneCentroid(_selectedZone!)
            : null;
        final resp = await apiClient.dio.put(
          '/listings/${widget.editingItemId}',
          data: {
            'title': title,
            'priceUgx': price,
            'categoryCode': categoryCode,
            'description': description,
            'locationText': _useRegisteredLocation
                ? _registeredLocationLabel
                : (_selectedZone ?? ''),
            'useRegisteredLocation': _useRegisteredLocation,
            if (_useRegisteredLocation && _registeredLocationLat != null)
              'lat': _registeredLocationLat,
            if (_useRegisteredLocation && _registeredLocationLng != null)
              'lng': _registeredLocationLng,
            if (!_useRegisteredLocation && centroid != null)
              'lat': centroid.lat,
            if (!_useRegisteredLocation && centroid != null)
              'lng': centroid.lng,
          },
        );
        listing = ListingResponse.fromJson(resp.data);
      } else {
        final centroid = _selectedZone != null
            ? zoneCentroid(_selectedZone!)
            : null;
        final resp = await apiClient.dio.post(
          '/listings',
          data: {
            'title': title,
            'priceUgx': price,
            'categoryCode': categoryCode,
            'description': description,
            'locationText': _useRegisteredLocation
                ? _registeredLocationLabel
                : (_selectedZone ?? ''),
            'useRegisteredLocation': _useRegisteredLocation,
            if (_useRegisteredLocation && _registeredLocationLat != null)
              'lat': _registeredLocationLat,
            if (_useRegisteredLocation && _registeredLocationLng != null)
              'lng': _registeredLocationLng,
            if (!_useRegisteredLocation && centroid != null)
              'lat': centroid.lat,
            if (!_useRegisteredLocation && centroid != null)
              'lng': centroid.lng,
          },
        );
        listing = ListingResponse.fromJson(resp.data);
      }

      // Upload images
      int uploadsFailed = 0;
      for (final img in _selectedImages) {
        try {
          // Step 1: get signed upload credentials from our backend
          debugPrint(
            '[IMG] Step 1: requesting signature for listing ${listing.id}',
          );
          final sigResp = await apiClient.dio.post(
            '/uploads/cloudinary/signature',
            data: {
              'listingId': listing.id,
              'folder': 'campusplug/listings/${listing.id}',
            },
          );
          final sig = CloudinarySignatureResponse.fromJson(sigResp.data);
          debugPrint(
            '[IMG] Step 1 OK: cloudName=${sig.cloudName}, params=${sig.params}',
          );

          // Step 2: upload the file directly to Cloudinary
          debugPrint('[IMG] Step 2: uploading to Cloudinary');
          final formData = FormData.fromMap({
            'file': await MultipartFile.fromFile(img.path, filename: img.name),
            'api_key': sig.apiKey,
            'timestamp': sig.timestamp.toString(),
            'signature': sig.signature,
            ...sig.params,
          });
          final cloudinaryUrl =
              'https://api.cloudinary.com/v1_1/${sig.cloudName}/image/upload';
          final cloudResp = await Dio().post(cloudinaryUrl, data: formData);
          final cloudData = cloudResp.data as Map<String, dynamic>;
          debugPrint('[IMG] Step 2 OK: url=${cloudData['secure_url']}');

          // Step 3: register the image against the listing in our backend
          debugPrint('[IMG] Step 3: registering image with backend');
          await apiClient.dio.post(
            '/listings/${listing.id}/images',
            data: {
              'publicId': cloudData['public_id'],
              'secureUrl': cloudData['secure_url'],
              'width': cloudData['width'],
              'height': cloudData['height'],
              'bytes': cloudData['bytes'],
              'format': cloudData['format'],
            },
          );
          debugPrint('[IMG] Step 3 OK: image registered');
        } catch (e) {
          uploadsFailed++;
          debugPrint('[IMG] FAILED: $e');
          if (e is DioException && e.response != null) {
            debugPrint('[IMG] Response body: ${e.response?.data}');
          }
        }
      }

      if (mounted) {
        if (uploadsFailed > 0 && _selectedImages.isNotEmpty) {
          AppToast.warning(
            context,
            uploadsFailed == _selectedImages.length
                ? 'Listing saved, but image upload failed. Check your connection and try editing.'
                : 'Listing saved, but $uploadsFailed image(s) failed to upload.',
          );
        } else {
          AppToast.success(
            context,
            widget.editingItemId != null ? 'Listing updated!' : 'Listing posted!',
          );
        }
        if (widget.editingItemId != null) {
          Navigator.pop(context);
        } else {
          Navigator.pushReplacementNamed(context, '/browse');
        }
      }
    } on ApiException catch (e) {
      if (mounted) {
        AppToast.error(context, e.message);
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, 'Error: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
            child: Image.asset('assets/images/logo.jpg', width: 40, height: 40),
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
                MaterialPageRoute(builder: (context) => const SavedScreen()),
              );
            },
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
                    if (_existingImages.isEmpty && _selectedImages.isEmpty) ...[
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
                        'Upload Photo',
                        style: TextStyle(
                          color: AppColors.darkGray,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Add 1 clear photo. Clear details help items sell faster.',
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
                        children: [
                          // Existing uploaded images
                          ..._existingImages.map(
                            (img) => Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    img.secureUrl,
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () => _removeExistingImage(img),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Newly selected images
                          ..._selectedImages.asMap().entries.map((entry) {
                            final index = entry.key;
                            final image = entry.value;
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
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                    (_existingImages.length + _selectedImages.length) < 1
                        ? ElevatedButton.icon(
                            onPressed: _pickImage,
                            icon: const Icon(Icons.add, color: Colors.white),
                            label: const Text(
                              'Add Photo',
                              style: TextStyle(
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
                              'Max 1 Photo',
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
                        borderSide: const BorderSide(
                          color: AppColors.lightGray,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.lightGray,
                        ),
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
                          _registeredLocationLabel,
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
                      child: Divider(color: AppColors.lightGray, thickness: 1),
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
                      child: Divider(color: AppColors.lightGray, thickness: 1),
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
                DropdownButtonFormField<String>(
                  value: _selectedZone,
                  hint: const Text(
                    'Select a zone',
                    style: TextStyle(color: AppColors.mediumGray),
                  ),
                  isExpanded: true,
                  menuMaxHeight: 300,
                  onChanged: (value) => setState(() => _selectedZone = value),
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    color: AppColors.mediumGray,
                  ),
                  dropdownColor: AppColors.white,
                  style: const TextStyle(
                    color: AppColors.darkGray,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
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
                  items: campusZones.map((zone) {
                    return DropdownMenuItem<String>(
                      value: zone.name,
                      child: Text(zone.name),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 32),

              // Post Listing Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitListing,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: AppColors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              widget.editingItemId != null
                                  ? 'Update Listing'
                                  : 'Post Listing',
                              style: const TextStyle(
                                color: AppColors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
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
