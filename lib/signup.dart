import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import 'main.dart';
import 'accountAuth.dart';
import 'login.dart';
import 'core/api_client.dart';
import 'core/api_exception.dart';
import 'core/app_config.dart';
import 'core/ui/app_toast.dart';
import 'core/validation/signup_validators.dart';
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

  bool _fullNameTouched = false;
  bool _regNumberTouched = false;
  bool _emailTouched = false;
  bool _phoneTouched = false;
  String? _fullNameError;
  String? _regNumberError;
  String? _emailError;
  String? _phoneError;

  bool _useCurrentLocation = false;
  String? _currentLocationText;
  bool _isLoadingLocation = false;
  Position? _currentPosition;
  bool _isLoading = false;
  String? _selectedZone;

  @override
  void initState() {
    super.initState();
    _fullNameController.addListener(_onFullNameChanged);
    _regNumberController.addListener(_onRegNumberChanged);
    _emailController.addListener(_onEmailChanged);
    _phoneController.addListener(_onPhoneChanged);
  }

  void _onFullNameChanged() {
    setState(() {
      _fullNameTouched = true;
      _fullNameError = SignupValidators.validateFullName(
        _fullNameController.text,
      );
    });
  }

  void _onRegNumberChanged() {
    setState(() {
      _regNumberTouched = true;
      _regNumberError = SignupValidators.validateRegistrationNumber(
        _regNumberController.text,
      );
    });
  }

  void _onEmailChanged() {
    setState(() {
      _emailTouched = true;
      _emailError = SignupValidators.validateUniversityEmail(
        _emailController.text,
      );
    });
  }

  void _onPhoneChanged() {
    setState(() {
      _phoneTouched = true;
      _phoneError = SignupValidators.validatePhone(_phoneController.text);
    });
  }

  bool get _canSubmitForm {
    final fullNameValid =
        SignupValidators.validateFullName(_fullNameController.text) == null;
    final regValid =
        SignupValidators.validateRegistrationNumber(_regNumberController.text) ==
        null;
    final emailValid =
        SignupValidators.validateUniversityEmail(_emailController.text) == null;
    final phoneValid = SignupValidators.validatePhone(_phoneController.text) == null;
    return fullNameValid && regValid && emailValid && phoneValid;
  }

  void _validateAllVisibleFields() {
    _fullNameTouched = true;
    _regNumberTouched = true;
    _emailTouched = true;
    _phoneTouched = true;
    _fullNameError = SignupValidators.validateFullName(_fullNameController.text);
    _regNumberError = SignupValidators.validateRegistrationNumber(
      _regNumberController.text,
    );
    _emailError = SignupValidators.validateUniversityEmail(_emailController.text);
    _phoneError = SignupValidators.validatePhone(_phoneController.text);
  }

  @override
  void dispose() {
    _fullNameController.removeListener(_onFullNameChanged);
    _regNumberController.removeListener(_onRegNumberChanged);
    _emailController.removeListener(_onEmailChanged);
    _phoneController.removeListener(_onPhoneChanged);
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
          AppToast.warning(
            context,
            'Location services are disabled. Please enable them.',
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
            AppToast.warning(context, 'Location permission denied.');
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
          AppToast.warning(
            context,
            'Location permissions are permanently denied.',
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
        AppToast.info(context, 'Location: $_currentLocationText');
      }
    } catch (e) {
      setState(() {
        _isLoadingLocation = false;
        _useCurrentLocation = false;
        _currentLocationText = null;
        _currentPosition = null;
      });
      if (mounted) {
        AppToast.error(context, 'Error getting location: $e');
      }
    }
  }

  Future<void> _submit() async {
    final fullName = _fullNameController.text.trim();
    final regNumber = _regNumberController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();

    setState(_validateAllVisibleFields);
    if (!_canSubmitForm) {
      AppToast.warning(context, 'Please fix the highlighted fields.');
      return;
    }

    if (!AppConfig.isAllowedEmail(email)) {
      AppToast.warning(
        context,
        'Only @must.ac.ug or @std.must.ac.ug emails are allowed.',
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
      AppToast.success(context, 'Verification code sent.');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AccountAuthScreen(email: email),
        ),
      );
    } on DioException catch (e) {
      final ex = ApiException.fromDio(e);
      if (!mounted) return;
      AppToast.fromApiException(context, ex);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.of(context).lightGray,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 16),
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
                          color: AppColors.of(context).lightGray,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.of(context).mediumGray.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          Icons.arrow_back,
                          color: AppColors.of(context).darkGray,
                          size: 20,
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    Text(
                      'Create Account',
                      style: TextStyle(
                        color: AppColors.of(context).darkGray,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24),
                // Subtext
                Text(
                  'Join our student marketplace to start trading.',
                  style: TextStyle(color: AppColors.of(context).mediumGray, fontSize: 16),
                ),
                SizedBox(height: 24),
                // Stepper
                _buildStepper(currentStep: 0),
                SizedBox(height: 40),
                // Full Name Field
                _buildInputField(
                  label: 'Full Name',
                  controller: _fullNameController,
                  hintText: 'Michael Okello',
                  icon: Icons.person_outline,
                  errorText: _fullNameTouched ? _fullNameError : null,
                  keyboardType: TextInputType.name,
                ),
                SizedBox(height: 20),
                // Registration Number Field
                _buildInputField(
                  label: 'Registration Number',
                  controller: _regNumberController,
                  hintText: '2023/BIT/...',
                  icon: Icons.badge_outlined,
                  errorText: _regNumberTouched ? _regNumberError : null,
                  keyboardType: TextInputType.text,
                ),
                SizedBox(height: 20),
                // University Email Field
                _buildInputField(
                  label: 'University Email',
                  controller: _emailController,
                  hintText: '2023example@std.must.ac.ug',
                  icon: Icons.mail_outline,
                  errorText: _emailTouched ? _emailError : null,
                  keyboardType: TextInputType.emailAddress,
                ),
                SizedBox(height: 20),
                // Tel (Phone) Field
                _buildInputField(
                  label: 'Tel',
                  controller: _phoneController,
                  hintText: '+256 700 000000',
                  icon: Icons.phone_outlined,
                  errorText: _phoneTouched ? _phoneError : null,
                  keyboardType: TextInputType.phone,
                ),
                SizedBox(height: 20),
                // Location Section
                _buildLocationSection(),
                SizedBox(height: 40),
                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: (_isLoading || !_canSubmitForm) ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.of(context).primary,
                      foregroundColor: AppColors.of(context).white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: AppColors.of(context).white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Submit',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                SizedBox(height: 24),
                // Login Prompt
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: TextStyle(
                          color: AppColors.of(context).mediumGray,
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
                            color: AppColors.of(context).primary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 32),
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
    String? errorText,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final hasError = errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.of(context).darkGray,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: AppColors.of(context).mediumGray),
            suffixIcon: Icon(icon, color: AppColors.of(context).mediumGray),
            errorText: errorText,
            errorStyle: TextStyle(color: AppColors.of(context).darkGray),
            filled: true,
            fillColor: AppColors.of(context).white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasError ? AppColors.of(context).darkGray : AppColors.of(context).lightGray,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: hasError ? AppColors.of(context).darkGray : AppColors.of(context).lightGray,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.of(context).primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.of(context).darkGray, width: 2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.of(context).darkGray, width: 2),
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
                  color: currentStep >= 0 ? AppColors.of(context).primary : AppColors.of(context).white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: currentStep >= 0
                        ? AppColors.of(context).primary
                        : AppColors.of(context).mediumGray,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    '1',
                    style: TextStyle(
                      color: currentStep >= 0
                          ? AppColors.of(context).white
                          : AppColors.of(context).mediumGray,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Details',
                style: TextStyle(
                  color: currentStep >= 0
                      ? AppColors.of(context).primary
                      : AppColors.of(context).mediumGray,
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
            color: currentStep >= 1 ? AppColors.of(context).primary : AppColors.of(context).white,
          ),
        ),
        Expanded(
          child: Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: currentStep >= 1 ? AppColors.of(context).primary : AppColors.of(context).white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: currentStep >= 1
                        ? AppColors.of(context).primary
                        : AppColors.of(context).mediumGray,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    '2',
                    style: TextStyle(
                      color: currentStep >= 1
                          ? AppColors.of(context).white
                          : AppColors.of(context).mediumGray,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Verify',
                style: TextStyle(
                  color: currentStep >= 1
                      ? AppColors.of(context).primary
                      : AppColors.of(context).mediumGray,
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
            color: currentStep >= 2 ? AppColors.of(context).primary : AppColors.of(context).white,
          ),
        ),
        Expanded(
          child: Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: currentStep >= 2 ? AppColors.of(context).primary : AppColors.of(context).white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: currentStep >= 2
                        ? AppColors.of(context).primary
                        : AppColors.of(context).mediumGray,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    '3',
                    style: TextStyle(
                      color: currentStep >= 2
                          ? AppColors.of(context).white
                          : AppColors.of(context).mediumGray,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Browse',
                style: TextStyle(
                  color: currentStep >= 2
                      ? AppColors.of(context).primary
                      : AppColors.of(context).mediumGray,
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
            color: AppColors.of(context).darkGray,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12),
        // Use Current Location Row
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.of(context).white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.of(context).lightGray),
          ),
          child: Row(
            children: [
              Icon(
                Icons.explore_outlined,
                color: AppColors.of(context).mediumGray,
                size: 20,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Use current location',
                  style: TextStyle(color: AppColors.of(context).darkGray, fontSize: 14),
                ),
              ),
              if (_isLoadingLocation)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.of(context).primary),
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
                  activeColor: AppColors.of(context).primary,
                ),
            ],
          ),
        ),
        if (_useCurrentLocation && _currentLocationText != null) ...[
          SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.of(context).primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.of(context).primary.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.location_on, color: AppColors.of(context).primary, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _currentLocationText!,
                    style: TextStyle(
                      color: AppColors.of(context).darkGray,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        SizedBox(height: 12),
        // Alternate Location Field
        DropdownButtonFormField<String>(
          value: _selectedZone,
          hint: Text(
            'Select a zone',
            style: TextStyle(color: AppColors.of(context).lightGray),
          ),
          isExpanded: true,
          menuMaxHeight: 300,
          onChanged: _useCurrentLocation
              ? null
              : (value) => setState(() => _selectedZone = value),
          icon: Icon(
            Icons.keyboard_arrow_down,
            color: AppColors.of(context).mediumGray,
          ),
          dropdownColor: AppColors.of(context).white,
          style: TextStyle(color: AppColors.of(context).darkGray, fontSize: 16),
          decoration: InputDecoration(
            suffixIcon: Icon(
              Icons.map_outlined,
              color: AppColors.of(context).mediumGray,
            ),
            filled: true,
            fillColor: _useCurrentLocation
                ? AppColors.of(context).lightGray.withValues(alpha: 0.3)
                : AppColors.of(context).white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.of(context).lightGray),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.of(context).lightGray),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.of(context).lightGray.withValues(alpha: 0.5),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.of(context).primary, width: 2),
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
