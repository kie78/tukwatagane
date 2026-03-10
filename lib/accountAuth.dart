import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'main.dart';
import 'browse.dart';
import 'core/api_client.dart';
import 'core/auth_service.dart';
import 'core/api_exception.dart';
import 'models/models.dart';

class AccountAuthScreen extends StatefulWidget {
  final String email;

  const AccountAuthScreen({
    super.key,
    required this.email,
  });

  @override
  State<AccountAuthScreen> createState() => _AccountAuthScreenState();
}

class _AccountAuthScreenState extends State<AccountAuthScreen> {
  final List<TextEditingController> _otpControllers = List.generate(
    5,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(
    5,
    (index) => FocusNode(),
  );
  
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isOtpConfirmed = false;
  bool _showPasswordFields = false;
  bool _isLoading = false;

  String get _enteredOtp =>
      _otpControllers.map((c) => c.text).join();

  Future<void> _handleOtpSubmit() async {
    final otp = _enteredOtp;
    if (otp.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the 5-digit code.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await apiClient.dio.post('/auth/register/verify-otp', data: {
        'email': widget.email,
        'otp': otp,
      });
      if (!mounted) return;
      setState(() {
        _isOtpConfirmed = true;
        _showPasswordFields = true;
      });
    } on DioException catch (e) {
      final ex = ApiException.fromDio(e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ex.message),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleConfirm() async {
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (password.isEmpty || confirm.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter and confirm your password.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (password != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final resp = await apiClient.dio.post('/auth/register/set-password', data: {
        'email': widget.email,
        'password': password,
        'confirmPassword': confirm,
      });
      final auth = AuthResponse.fromJson(resp.data);
      await apiClient.saveToken(auth.token);
      await authService.saveSession(
        token: auth.token,
        userId: auth.user.id,
        email: auth.user.email,
        fullName: auth.user.fullName,
      );
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const BrowseScreen()),
        (route) => false,
      );
    } on DioException catch (e) {
      final ex = ApiException.fromDio(e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ex.message),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var focusNode in _otpFocusNodes) {
      focusNode.dispose();
    }
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _maskEmail(String email) {
    if (email.isEmpty) return email;
    final parts = email.split('@');
    if (parts.length != 2) return email;
    
    final username = parts[0];
    final domain = parts[1];
    
    if (username.length <= 2) {
      return '${username[0]}***@$domain';
    }
    
    final visibleChars = username.substring(0, 2);
    return '$visibleChars***@$domain';
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
                            color: AppColors.mediumGray.withOpacity(0.3),
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
                      'Authenticate Email',
                      style: TextStyle(
                        color: AppColors.darkGray,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Stepper
                _buildStepper(currentStep: 1),
                const SizedBox(height: 32),
                // Email notification text
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      color: AppColors.mediumGray,
                      fontSize: 16,
                      height: 1.5,
                    ),
                    children: [
                      TextSpan(text: 'We\'ve sent a verification code to '),
                      TextSpan(
                        text: _maskEmail(widget.email),
                        style: TextStyle(
                          color: AppColors.darkGray,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Enter code below text
                Text(
                  'Enter code below',
                  style: TextStyle(
                    color: AppColors.darkGray,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                // OTP Input Fields
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(5, (index) {
                    return SizedBox(
                      width: 48,
                      height: 56,
                      child: TextField(
                        controller: _otpControllers[index],
                        focusNode: _otpFocusNodes[index],
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        enabled: !_isOtpConfirmed,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkGray,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          filled: true,
                          fillColor: _isOtpConfirmed 
                              ? AppColors.teal.withOpacity(0.1)
                              : AppColors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: _isOtpConfirmed 
                                  ? AppColors.teal 
                                  : AppColors.lightGray,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: _isOtpConfirmed 
                                  ? AppColors.teal 
                                  : AppColors.lightGray,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppColors.teal,
                              width: 2,
                            ),
                          ),
                          disabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppColors.teal,
                              width: 2,
                            ),
                          ),
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (value) {
                          if (value.length == 1 && index < 4) {
                            _otpFocusNodes[index + 1].requestFocus();
                          } else if (value.isEmpty && index > 0) {
                            _otpFocusNodes[index - 1].requestFocus();
                          }
                        },
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 32),
                // Submit/Confirmed Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: (_isOtpConfirmed || _isLoading) ? null : _handleOtpSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isOtpConfirmed
                          ? AppColors.teal
                          : Colors.black,
                      foregroundColor: AppColors.white,
                      disabledBackgroundColor:
                          _isOtpConfirmed ? AppColors.teal : Colors.black54,
                      disabledForegroundColor: AppColors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading && !_isOtpConfirmed
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_isOtpConfirmed)
                                const Icon(Icons.check_circle, size: 20),
                              if (_isOtpConfirmed) const SizedBox(width: 8),
                              Text(
                                _isOtpConfirmed ? 'Confirmed' : 'Submit',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                // Password Fields (shown after OTP confirmation)
                if (_showPasswordFields) ...[
                  const SizedBox(height: 40),
                  // Create password text
                  Text(
                    'Create password',
                    style: TextStyle(
                      color: AppColors.darkGray,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildPasswordField(
                    label: 'Password',
                    controller: _passwordController,
                    isPasswordVisible: _isPasswordVisible,
                    onToggleVisibility: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Min. 8 characters · uppercase · number · special character (e.g. SecurePass123!)',
                    style: TextStyle(
                      color: AppColors.mediumGray,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildPasswordField(
                    label: 'Confirm Password',
                    controller: _confirmPasswordController,
                    isPasswordVisible: _isConfirmPasswordVisible,
                    onToggleVisibility: () {
                      setState(() {
                        _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                      });
                    },
                  ),
                  const SizedBox(height: 40),
                  // Final Confirm Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleConfirm,
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
                              'Confirm',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
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
                    color: currentStep >= 0 ? AppColors.teal : AppColors.mediumGray,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.check,
                    color: AppColors.white,
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Details',
                style: TextStyle(
                  color: AppColors.teal,
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
                    color: currentStep >= 1 ? AppColors.teal : AppColors.mediumGray,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    '2',
                    style: TextStyle(
                      color: currentStep >= 1 ? AppColors.white : AppColors.mediumGray,
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
                  color: currentStep >= 1 ? AppColors.teal : AppColors.mediumGray,
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
                    color: currentStep >= 2 ? AppColors.teal : AppColors.mediumGray,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    '3',
                    style: TextStyle(
                      color: currentStep >= 2 ? AppColors.white : AppColors.mediumGray,
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
                  color: currentStep >= 2 ? AppColors.teal : AppColors.mediumGray,
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

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool isPasswordVisible,
    required VoidCallback onToggleVisibility,
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
          obscureText: !isPasswordVisible,
          decoration: InputDecoration(
            hintText: '........',
            hintStyle: TextStyle(
              color: AppColors.lightGray,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                isPasswordVisible
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: AppColors.mediumGray,
              ),
              onPressed: onToggleVisibility,
            ),
            filled: true,
            fillColor: AppColors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.lightGray,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.lightGray,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.teal,
                width: 2,
              ),
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
}
