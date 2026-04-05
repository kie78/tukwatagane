import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'main.dart';
import 'browse.dart';
import 'core/api_client.dart';
import 'core/auth_service.dart';
import 'core/api_exception.dart';
import 'core/ui/app_toast.dart';
import 'core/validation/signup_validators.dart';
import 'models/models.dart';

class AccountAuthScreen extends StatefulWidget {
  final String email;

  const AccountAuthScreen({super.key, required this.email});

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
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isOtpConfirmed = false;
  bool _showPasswordFields = false;
  bool _isLoading = false;
  bool _otpTouched = false;
  bool _passwordTouched = false;
  bool _confirmPasswordTouched = false;
  String? _otpError;
  String? _passwordError;
  String? _confirmPasswordError;

  String get _enteredOtp => _otpControllers.map((c) => c.text).join();
  bool get _isOtpComplete => SignupValidators.validateOtp(_enteredOtp) == null;
  bool get _isPasswordFormValid {
    final p = SignupValidators.validatePassword(_passwordController.text);
    final c = SignupValidators.validateConfirmPassword(
      _passwordController.text,
      _confirmPasswordController.text,
    );
    return p == null && c == null;
  }

  void _validateOtpInline() {
    _otpError = SignupValidators.validateOtp(_enteredOtp);
  }

  void _validatePasswordInline() {
    _passwordError = SignupValidators.validatePassword(_passwordController.text);
    _confirmPasswordError = SignupValidators.validateConfirmPassword(
      _passwordController.text,
      _confirmPasswordController.text,
    );
  }

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_onPasswordChanged);
    _confirmPasswordController.addListener(_onConfirmPasswordChanged);
  }

  void _onPasswordChanged() {
    setState(() {
      _passwordTouched = true;
      _validatePasswordInline();
    });
  }

  void _onConfirmPasswordChanged() {
    setState(() {
      _confirmPasswordTouched = true;
      _validatePasswordInline();
    });
  }

  Future<void> _handleOtpSubmit() async {
    final otp = _enteredOtp;
    setState(() {
      _otpTouched = true;
      _validateOtpInline();
    });
    if (!_isOtpComplete) {
      AppToast.warning(context, 'Please enter the 5-digit code.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await apiClient.dio.post(
        '/auth/register/verify-otp',
        data: {'email': widget.email, 'otp': otp},
      );
      if (!mounted) return;
      setState(() {
        _isOtpConfirmed = true;
        _showPasswordFields = true;
      });
      AppToast.success(context, 'Code verified. Set your password to continue.');
    } on DioException catch (e) {
      final ex = ApiException.fromDio(e);
      if (!mounted) return;
      AppToast.fromApiException(context, ex);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleConfirm() async {
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    setState(() {
      _passwordTouched = true;
      _confirmPasswordTouched = true;
      _validatePasswordInline();
    });

    if (password.isEmpty || confirm.isEmpty) {
      AppToast.warning(context, 'Please enter and confirm your password.');
      return;
    }
    if (!_isPasswordFormValid) {
      AppToast.warning(context, 'Please fix password validation errors.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final resp = await apiClient.dio.post(
        '/auth/register/set-password',
        data: {
          'email': widget.email,
          'password': password,
          'confirmPassword': confirm,
        },
      );
      final auth = AuthResponse.fromJson(resp.data);
      await apiClient.saveToken(auth.token);
      await authService.saveSession(
        token: auth.token,
        userId: auth.user.id,
        email: auth.user.email,
        fullName: auth.user.fullName,
      );
      if (!mounted) return;
      AppToast.success(context, 'Account created successfully.');
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const BrowseScreen()),
        (route) => false,
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
  void dispose() {
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var focusNode in _otpFocusNodes) {
      focusNode.dispose();
    }
    _passwordController.removeListener(_onPasswordChanged);
    _confirmPasswordController.removeListener(_onConfirmPasswordChanged);
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
                      'Authenticate Email',
                      style: TextStyle(
                        color: AppColors.of(context).darkGray,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24),
                // Stepper
                _buildStepper(currentStep: 1),
                SizedBox(height: 32),
                // Email notification text
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      color: AppColors.of(context).mediumGray,
                      fontSize: 16,
                      height: 1.5,
                    ),
                    children: [
                      TextSpan(text: 'We\'ve sent a verification code to '),
                      TextSpan(
                        text: _maskEmail(widget.email),
                        style: TextStyle(
                          color: AppColors.of(context).darkGray,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),
                // Enter code below text
                Text(
                  'Enter code below',
                  style: TextStyle(
                    color: AppColors.of(context).darkGray,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),
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
                          color: AppColors.of(context).darkGray,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          filled: true,
                          fillColor: _isOtpConfirmed
                              ? AppColors.of(context).primary.withValues(alpha: 0.1)
                              : AppColors.of(context).white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: _isOtpConfirmed
                                  ? AppColors.of(context).primary
                                  : AppColors.of(context).lightGray,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: _isOtpConfirmed
                                  ? AppColors.of(context).primary
                                  : AppColors.of(context).lightGray,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppColors.of(context).primary,
                              width: 2,
                            ),
                          ),
                          disabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppColors.of(context).primary,
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
                          setState(() {
                            _otpTouched = true;
                            _validateOtpInline();
                          });
                        },
                      ),
                    );
                  }),
                ),
                if (_otpTouched && _otpError != null) ...[
                  SizedBox(height: 8),
                  Text(
                    _otpError!,
                    style: TextStyle(
                      color: AppColors.of(context).darkGray,
                      fontSize: 12,
                    ),
                  ),
                ],
                SizedBox(height: 32),
                // Submit/Confirmed Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: (_isOtpConfirmed || _isLoading)
                        ? null
                        : (!_isOtpComplete ? null : _handleOtpSubmit),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isOtpConfirmed
                          ? AppColors.of(context).primary
                          : AppColors.of(context).primary,
                      foregroundColor: AppColors.of(context).white,
                      disabledBackgroundColor: _isOtpConfirmed
                          ? AppColors.of(context).primary
                          : Colors.black54,
                      disabledForegroundColor: AppColors.of(context).white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading && !_isOtpConfirmed
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: AppColors.of(context).white,
                              strokeWidth: 2,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_isOtpConfirmed)
                                Icon(Icons.check_circle, size: 20),
                              if (_isOtpConfirmed) SizedBox(width: 8),
                              Text(
                                _isOtpConfirmed ? 'Confirmed' : 'Submit',
                                style: TextStyle(
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
                  SizedBox(height: 40),
                  // Create password text
                  Text(
                    'Create password',
                    style: TextStyle(
                      color: AppColors.of(context).darkGray,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  _buildPasswordField(
                    label: 'Password',
                    controller: _passwordController,
                    isPasswordVisible: _isPasswordVisible,
                    errorText: _passwordTouched ? _passwordError : null,
                    onToggleVisibility: () {
                      setState(() {
                        _isPasswordVisible = !_isPasswordVisible;
                      });
                    },
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Min. 8 characters · uppercase · number · special character (e.g. SecurePass123!)',
                    style: TextStyle(color: AppColors.of(context).mediumGray, fontSize: 12),
                  ),
                  SizedBox(height: 20),
                  _buildPasswordField(
                    label: 'Confirm Password',
                    controller: _confirmPasswordController,
                    isPasswordVisible: _isConfirmPasswordVisible,
                    errorText: _confirmPasswordTouched
                        ? _confirmPasswordError
                        : null,
                    onToggleVisibility: () {
                      setState(() {
                        _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                      });
                    },
                  ),
                  SizedBox(height: 40),
                  // Final Confirm Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: (_isLoading || !_isPasswordFormValid)
                          ? null
                          : _handleConfirm,
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
                              'Confirm',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
                SizedBox(height: 32),
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
                  child: Icon(Icons.check, color: AppColors.of(context).white, size: 16),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Details',
                style: TextStyle(
                  color: AppColors.of(context).primary,
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

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool isPasswordVisible,
    String? errorText,
    required VoidCallback onToggleVisibility,
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
          obscureText: !isPasswordVisible,
          decoration: InputDecoration(
            hintText: '........',
            hintStyle: TextStyle(color: AppColors.of(context).lightGray),
            errorText: errorText,
            errorStyle: TextStyle(color: AppColors.of(context).darkGray),
            suffixIcon: IconButton(
              icon: Icon(
                isPasswordVisible
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: AppColors.of(context).mediumGray,
              ),
              onPressed: onToggleVisibility,
            ),
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
}
