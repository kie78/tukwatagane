import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'main.dart';
import 'login.dart';
import 'core/api_client.dart';
import 'core/api_exception.dart';
import 'core/ui/app_toast.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  final List<TextEditingController> _otpControllers = List.generate(
    5,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(
    5,
    (index) => FocusNode(),
  );

  final TextEditingController _newPasswordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isCodeSent = false;
  bool _isCodeVerified = false;
  bool _isLoading = false;

  String get _enteredOtp => _otpControllers.map((c) => c.text).join();

  Future<void> _handleSendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await apiClient.dio.post('/auth/forgot-password', data: {'email': email});
      if (!mounted) return;
      setState(() => _isCodeSent = true);
      AppToast.success(context, 'Reset code sent to your email.');
    } on DioException catch (e) {
      final ex = ApiException.fromDio(e);
      if (!mounted) return;
      AppToast.fromApiException(context, ex);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleVerify() {
    if (_enteredOtp.length < 5) {
      AppToast.warning(context, 'Please enter the 5-digit code.');
      return;
    }
    setState(() => _isCodeVerified = true);
    AppToast.success(context, 'Code verified.');
  }

  Future<void> _handleConfirm() async {
    final password = _newPasswordController.text;
    if (password.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await apiClient.dio.post(
        '/auth/reset-password',
        data: {
          'email': _emailController.text.trim(),
          'otp': _enteredOtp,
          'password': password,
          'confirmPassword': password,
        },
      );
      if (!mounted) return;
      AppToast.success(context, 'Password reset successful. Please log in.');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
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
    _emailController.dispose();
    _newPasswordController.dispose();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var focusNode in _otpFocusNodes) {
      focusNode.dispose();
    }
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
                      'Forgot Password?',
                      style: TextStyle(
                        color: AppColors.of(context).darkGray,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 32),
                // Instruction Text
                Text(
                  'Please enter email associated with your account.',
                  style: TextStyle(
                    color: AppColors.of(context).darkGray,
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'A reset code will be sent to reset your password. Please ensure certainty of the email you enter.',
                  style: TextStyle(
                    color: AppColors.of(context).mediumGray,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 32),
                // Email Input Field
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Email',
                      style: TextStyle(
                        color: AppColors.of(context).darkGray,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: _emailController,
                      enabled: !_isCodeSent,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: '2023example@std.must.ac.ug',
                        hintStyle: TextStyle(color: AppColors.of(context).lightGray),
                        suffixIcon: Icon(
                          Icons.mail_outline,
                          color: AppColors.of(context).mediumGray,
                        ),
                        filled: true,
                        fillColor: _isCodeSent
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
                          borderSide: BorderSide(
                            color: AppColors.of(context).primary,
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
                ),
                SizedBox(height: 32),
                // Send Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: (_isCodeSent || _isLoading)
                        ? null
                        : _handleSendCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.of(context).primary,
                      foregroundColor: AppColors.of(context).white,
                      disabledBackgroundColor: AppColors.of(context).mediumGray.withValues(
                        alpha: 0.5,
                      ),
                      disabledForegroundColor: AppColors.of(context).white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading && !_isCodeSent
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: AppColors.of(context).white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Send',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                // Code Sent Section (shown after sending)
                if (_isCodeSent) ...[
                  SizedBox(height: 40),
                  // Email confirmation text
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: AppColors.of(context).mediumGray,
                        fontSize: 16,
                        height: 1.5,
                      ),
                      children: [
                        TextSpan(text: 'We sent an email to '),
                        TextSpan(
                          text: _maskEmail(_emailController.text),
                          style: TextStyle(
                            color: AppColors.of(context).darkGray,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),
                  // Enter reset code text
                  Text(
                    'Enter reset code',
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
                        width: 56,
                        height: 56,
                        child: TextField(
                          controller: _otpControllers[index],
                          focusNode: _otpFocusNodes[index],
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          maxLength: 1,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.of(context).darkGray,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            filled: true,
                            fillColor: AppColors.of(context).white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: AppColors.of(context).lightGray,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: AppColors.of(context).lightGray,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
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
                          },
                        ),
                      );
                    }),
                  ),
                  SizedBox(height: 32),
                  // Verify Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isCodeVerified ? null : _handleVerify,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.of(context).primary,
                        foregroundColor: AppColors.of(context).white,
                        disabledBackgroundColor: AppColors.of(context).mediumGray
                            .withValues(alpha: 0.5),
                        disabledForegroundColor: AppColors.of(context).white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Verify',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
                // Password Creation Section (shown after verification)
                if (_isCodeVerified) ...[
                  SizedBox(height: 40),
                  // Create new password text
                  Text(
                    'Create new password',
                    style: TextStyle(
                      color: AppColors.of(context).darkGray,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 16),
                  // Password Field
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enter Password',
                        style: TextStyle(
                          color: AppColors.of(context).darkGray,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      TextField(
                        controller: _newPasswordController,
                        obscureText: !_isPasswordVisible,
                        decoration: InputDecoration(
                          hintText: '........',
                          hintStyle: TextStyle(color: AppColors.of(context).lightGray),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: AppColors.of(context).mediumGray,
                            ),
                            onPressed: () {
                              setState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                          filled: true,
                          fillColor: AppColors.of(context).white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.of(context).lightGray),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.of(context).lightGray),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: AppColors.of(context).primary,
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
                  ),
                  SizedBox(height: 32),
                  // Confirm Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleConfirm,
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
}
