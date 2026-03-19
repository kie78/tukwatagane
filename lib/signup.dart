import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import 'main.dart';
import 'accountAuth.dart';
import 'login.dart';
import 'core/api_client.dart';
import 'core/api_exception.dart';
import 'core/app_config.dart';
import 'config/campus_zones.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _regNumberController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _useCurrentLocation = false;
  String? _currentLocationText;
  bool _isLoadingLocation = false;
  Position? _currentPosition;
  bool _isLoading = false;
  String? _selectedZone;

  @override
  void dispose() {
    _fullNameController.dispose();
    _regNumberController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoadingLocation = true;
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLoadingLocation = false;
          _useCurrentLocation = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location services are disabled. Please enable them.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoadingLocation = false;
            _useCurrentLocation = false;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permission denied.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoadingLocation = false;
          _useCurrentLocation = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permissions are permanently denied.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentPosition = position;
        _currentLocationText = zoneLabel(
          position.latitude,
          position.longitude,
          fallback: 'MUST Campus',
        );
        _isLoadingLocation = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location: $_currentLocationText'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoadingLocation = false;
        _useCurrentLocation = false;
        _currentLocationText = null;
        _currentPosition = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submit() async {
    final fullName = _fullNameController.text.trim();
    final regNumber = _regNumberController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();

    if (fullName.isEmpty ||
        regNumber.isEmpty ||
        email.isEmpty ||
        phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!AppConfig.isAllowedEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Only @must.ac.ug or @std.must.ac.ug emails are allowed.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final body = <String, dynamic>{
        'fullName': fullName,
        'registrationNumber': regNumber,
        'email': email,
        'phoneNumber': phone,
        'campus': 'main',
      };

      if (_useCurrentLocation && _currentPosition != null) {
        final lat = _currentPosition!.latitude;
        final lng = _currentPosition!.longitude;
        body['registeredLocation'] = {
          'label': zoneLabel(lat, lng, fallback: 'MUST Campus'),
          'lat': lat,
          'lng': lng,
        };
      } else if (_selectedZone != null) {
        final centroid = zoneCentroid(_selectedZone!);
        body['alternateLocation'] = {
          'label': _selectedZone!,
          if (centroid != null) 'lat': centroid.lat,
          if (centroid != null) 'lng': centroid.lng,
        };
      }

      await apiClient.dio.post('/auth/register/start', data: body);

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AccountAuthScreen(email: email),
        ),
      );
    } on DioException catch (e) {
      final ex = ApiException.fromDio(e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ex.message), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGray,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                // Back Button and Heading
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.lightGray,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.mediumGray.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.arrow_back,
                          color: AppColors.darkGray,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Create Account',
                      style: TextStyle(
                        color: AppColors.darkGray,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Subtext
                Text(
                  'Join our student marketplace to start trading.',
                  style: TextStyle(color: AppColors.mediumGray, fontSize: 16),
                ),
                const SizedBox(height: 24),
                // Stepper
                _buildStepper(currentStep: 0),
                const SizedBox(height: 40),
                // Full Name Field
                _buildInputField(
                  label: 'Full Name',
                  controller: _fullNameController,
                  hintText: 'Michael Okello',
                  icon: Icons.person_outline,
                  keyboardType: TextInputType.name,
                ),
                const SizedBox(height: 20),
                // Registration Number Field
                _buildInputField(
                  label: 'Registration Number',
                  controller: _regNumberController,
                  hintText: '2023/BIT/...',
                  icon: Icons.badge_outlined,
                  keyboardType: TextInputType.text,
                ),
                const SizedBox(height: 20),
                // University Email Field
                _buildInputField(
                  label: 'University Email',
                  controller: _emailController,
                  hintText: '2023example@std.must.ac.ug',
                  icon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 20),
                // Tel (Phone) Field
                _buildInputField(
                  label: 'Tel',
                  controller: _phoneController,
                  hintText: '+256 700 000000',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 20),
                // Location Section
                _buildLocationSection(),
                const SizedBox(height: 40),
                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Submit',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                // Login Prompt
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: TextStyle(
                          color: AppColors.mediumGray,
                          fontSize: 14,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginScreen(),
                            ),
                          );
                        },
                        child: Text(
                          'Log In',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.darkGray,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: AppColors.lightGray),
            suffixIcon: Icon(icon, color: AppColors.mediumGray),
            filled: true,
            fillColor: AppColors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.lightGray),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.lightGray),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.teal, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepper({required int currentStep}) {
    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: currentStep >= 0 ? AppColors.teal : AppColors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: currentStep >= 0
                        ? AppColors.teal
                        : AppColors.mediumGray,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    '1',
                    style: TextStyle(
                      color: currentStep >= 0
                          ? AppColors.white
                          : AppColors.mediumGray,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Details',
                style: TextStyle(
                  color: currentStep >= 0
                      ? AppColors.teal
                      : AppColors.mediumGray,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            height: 2,
            color: currentStep >= 1 ? AppColors.teal : AppColors.white,
          ),
        ),
        Expanded(
          child: Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: currentStep >= 1 ? AppColors.teal : AppColors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: currentStep >= 1
                        ? AppColors.teal
                        : AppColors.mediumGray,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    '2',
                    style: TextStyle(
                      color: currentStep >= 1
                          ? AppColors.white
                          : AppColors.mediumGray,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Verify',
                style: TextStyle(
                  color: currentStep >= 1
                      ? AppColors.teal
                      : AppColors.mediumGray,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            height: 2,
            color: currentStep >= 2 ? AppColors.teal : AppColors.white,
          ),
        ),
        Expanded(
          child: Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: currentStep >= 2 ? AppColors.teal : AppColors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: currentStep >= 2
                        ? AppColors.teal
                        : AppColors.mediumGray,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    '3',
                    style: TextStyle(
                      color: currentStep >= 2
                          ? AppColors.white
                          : AppColors.mediumGray,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Browse',
                style: TextStyle(
                  color: currentStep >= 2
                      ? AppColors.teal
                      : AppColors.mediumGray,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Location',
          style: TextStyle(
            color: AppColors.darkGray,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        // Use Current Location Row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.lightGray),
          ),
          child: Row(
            children: [
              Icon(
                Icons.explore_outlined,
                color: AppColors.mediumGray,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Use current location',
                  style: TextStyle(color: AppColors.darkGray, fontSize: 14),
                ),
              ),
              if (_isLoadingLocation)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.teal),
                  ),
                )
              else
                Switch(
                  value: _useCurrentLocation,
                  onChanged: (value) async {
                    setState(() {
                      _useCurrentLocation = value;
                    });
                    if (value) {
                      await _getCurrentLocation();
                    } else {
                      setState(() {
                        _currentLocationText = null;
                      });
                    }
                  },
                  activeColor: AppColors.teal,
                ),
            ],
          ),
        ),
        if (_useCurrentLocation && _currentLocationText != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.teal.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.location_on, color: AppColors.teal, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _currentLocationText!,
                    style: TextStyle(
                      color: AppColors.darkGray,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        // Alternate Location Field
        DropdownButtonFormField<String>(
          value: _selectedZone,
          hint: Text(
            'Select a zone',
            style: TextStyle(color: AppColors.lightGray),
          ),
          isExpanded: true,
          menuMaxHeight: 300,
          onChanged: _useCurrentLocation
              ? null
              : (value) => setState(() => _selectedZone = value),
          icon: const Icon(
            Icons.keyboard_arrow_down,
            color: AppColors.mediumGray,
          ),
          dropdownColor: AppColors.white,
          style: const TextStyle(color: AppColors.darkGray, fontSize: 16),
          decoration: InputDecoration(
            suffixIcon: const Icon(
              Icons.map_outlined,
              color: AppColors.mediumGray,
            ),
            filled: true,
            fillColor: _useCurrentLocation
                ? AppColors.lightGray.withValues(alpha: 0.3)
                : AppColors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.lightGray),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.lightGray),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.lightGray.withValues(alpha: 0.5),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.teal, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
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
    );
  }
}
