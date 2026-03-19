import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import 'main.dart';
import 'saved.dart';
import 'widgets/main_nav_bar.dart';
import 'core/api_client.dart';
import 'models/models.dart';
import 'config/campus_zones.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _profileImage;
  bool _isUploadingAvatar = false;
  UserProfile? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final resp = await apiClient.dio.get('/users/profile');
      if (mounted) {
        setState(() {
          _profile = UserProfile.fromJson(resp.data);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      if (_profile == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not load profile. Please refresh and try again.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image == null) return;

      // Show local preview immediately while uploading
      setState(() {
        _profileImage = image;
        _isUploadingAvatar = true;
      });

      // Step 1: request an avatar-scoped signature.
      late CloudinarySignatureResponse sig;
      try {
        final sigResp = await apiClient.dio.post(
          '/uploads/cloudinary/signature',
          data: {'uploadContext': 'AVATAR'},
        );
        sig = CloudinarySignatureResponse.fromJson(sigResp.data);
      } on DioException catch (e) {
        throw Exception(
          'Step 1 (signature) failed ${e.response?.statusCode}: ${e.response?.data}',
        );
      }

      final signedPublicId =
          (sig.params['public_id'] ?? sig.params['publicId'] ?? '').trim();
      if (signedPublicId.isEmpty) {
        throw Exception(
          'Step 1 (signature) failed: missing signed public_id target',
        );
      }

      // Step 2: upload directly to Cloudinary
      late String secureUrl;
      try {
        final formPayload = <String, dynamic>{
          ...sig.params,
          'api_key': sig.apiKey,
          'timestamp': sig.timestamp.toString(),
          'signature': sig.signature,
          'file': await MultipartFile.fromFile(
            image.path,
            filename: image.name,
          ),
        };

        final formData = FormData.fromMap(formPayload);
        final cloudinaryUrl =
            'https://api.cloudinary.com/v1_1/${sig.cloudName}/image/upload';
        final cloudResp = await Dio().post(cloudinaryUrl, data: formData);
        final cloudData = Map<String, dynamic>.from(cloudResp.data as Map);
        secureUrl = cloudData['secure_url']?.toString() ?? '';
        final uploadedPublicId =
            cloudData['public_id']?.toString().trim() ?? '';
        if (secureUrl.isEmpty) {
          throw Exception('Missing secure_url from Cloudinary response');
        }
        final matchesSignedTarget =
            uploadedPublicId.isEmpty ||
            uploadedPublicId == signedPublicId ||
            uploadedPublicId.endsWith('/$signedPublicId');
        if (!matchesSignedTarget) {
          throw Exception(
            'Cloudinary upload target mismatch. expected=$signedPublicId actual=$uploadedPublicId',
          );
        }
      } on DioException catch (e) {
        throw Exception(
          'Step 2 (Cloudinary upload) failed ${e.response?.statusCode}: ${e.response?.data}',
        );
      }

      // Step 3: confirm avatar metadata with backend validation.
      try {
        final confirmResp = await apiClient.dio.put(
          '/users/profile/avatar',
          data: {'avatarUrl': secureUrl, 'avatarPublicId': signedPublicId},
        );
        if (mounted) {
          setState(() {
            _profile = UserProfile.fromJson(confirmResp.data);
          });
        }
      } on DioException catch (e) {
        throw Exception(
          'Step 3 (avatar confirmation) failed ${e.response?.statusCode}: ${e.response?.data}',
        );
      }

      if (mounted) {
        setState(() => _profileImage = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated successfully.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  String get _locationLabel {
    final loc = _profile?.registeredLocation ?? _profile?.alternateLocation;
    final fallback = loc?.label ?? _profile?.campus ?? '—';
    return zoneLabel(loc?.lat, loc?.lng, fallback: fallback);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      backgroundColor: AppColors.lightGray,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.darkGray),
          onPressed: () {
            Navigator.pop(context);
          },
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Screen Title
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Text(
                'Profile',
                style: TextStyle(
                  color: AppColors.darkGray,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            // Profile Identity Section
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.lightGray, width: 3),
                    ),
                    child: CircleAvatar(
                      radius: 58,
                      backgroundColor: AppColors.darkGray,
                      backgroundImage: _profileImage != null
                          ? FileImage(File(_profileImage!.path))
                                as ImageProvider
                          : (_profile?.avatarUrl != null
                                ? NetworkImage(_profile!.avatarUrl!)
                                      as ImageProvider
                                : null),
                      child: _isUploadingAvatar
                          ? const CircularProgressIndicator(
                              color: AppColors.white,
                              strokeWidth: 3,
                            )
                          : (_profileImage == null &&
                                    _profile?.avatarUrl == null
                                ? Text(
                                    (_profile?.fullName.isNotEmpty == true)
                                        ? _profile!.fullName[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: AppColors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 40,
                                    ),
                                  )
                                : null),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.edit,
                          color: AppColors.white,
                          size: 18,
                        ),
                        onPressed: _pickProfileImage,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Name & Status
            Center(
              child: Column(
                children: [
                  Text(
                    _profile?.fullName ?? '—',
                    style: TextStyle(
                      color: AppColors.darkGray,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Student Member',
                    style: TextStyle(color: AppColors.mediumGray, fontSize: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Student Details Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section Header
                  Text(
                    'Account Information',
                    style: TextStyle(
                      color: AppColors.darkGray,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Locked Credentials Card
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'STUDENT DETAILS',
                            style: TextStyle(
                              color: AppColors.mediumGray,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // REG NO Field
                          _buildLockedField(
                            label: 'REG NO',
                            value: _profile?.registrationNumber ?? '—',
                            prefixIcon: Icons.badge,
                          ),
                          const SizedBox(height: 12),
                          // EMAIL Field
                          _buildLockedField(
                            label: 'EMAIL',
                            value: _profile?.email ?? '—',
                            prefixIcon: Icons.email,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Personal Information Card
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PERSONAL INFORMATION',
                            style: TextStyle(
                              color: AppColors.mediumGray,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // NAME Field
                          _buildLockedField(
                            label: 'NAME',
                            value: _profile?.fullName ?? '—',
                            prefixIcon: Icons.person,
                          ),
                          const SizedBox(height: 12),
                          // TEL Field
                          _buildLockedField(
                            label: 'TEL',
                            value: _profile?.phoneNumber ?? '—',
                            prefixIcon: Icons.phone,
                          ),
                          const SizedBox(height: 12),
                          // REGISTERED LOCATION Field
                          _buildLockedField(
                            label: 'REGISTERED LOCATION',
                            value: _locationLabel,
                            prefixIcon: Icons.location_on,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const MainNavBar(currentIndex: 4),
    );
  }

  Widget _buildLockedField({
    required String label,
    required String value,
    required IconData prefixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.mediumGray,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Color(0xFFF7FAFC),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(prefixIcon, color: AppColors.mediumGray, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(color: AppColors.darkGray, fontSize: 15),
                ),
              ),
              Icon(Icons.lock, color: AppColors.mediumGray, size: 18),
            ],
          ),
        ),
      ],
    );
  }
}
