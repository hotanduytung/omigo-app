import 'dart:ui' show PathMetric;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  bool _isOTPSent = false;
  bool _showPhoneInput = false;
  bool _showOnboarding = false;
  bool _isOnboardingForSocial = false;
  String _tempSocialMethod = '';
  String _tempPhone = '';

  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _otpFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _phoneFocusNode.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _otpController.dispose();
    _phoneFocusNode.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  void _handlePhoneLogin(AppState state) async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isOTPSent) {
      setState(() => _isOTPSent = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mã OTP xác thực đã gửi đến điện thoại của bạn (Mock: 123456)'),
        ),
      );
      // Wait for build and focus
      Future.delayed(const Duration(milliseconds: 100), () {
        _otpFocusNode.requestFocus();
      });
    } else {
      if (_otpController.text.trim() != '123456') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Mã OTP không chính xác. Vui lòng nhập 123456'),
            backgroundColor: AppColors.brandError,
          ),
        );
        return;
      }
      try {
        final phone = _phoneController.text.trim();
        if (_isOnboardingForSocial) {
          // Complete Google/Apple registration with verified phone
          final name = _tempSocialMethod == 'Apple' ? 'Apple User' : 'Google User';
          await state.login(phone, name);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Chào mừng ${state.currentCustomer?.name} đến với Omigo!'),
              backgroundColor: AppColors.brandGreen,
            ),
          );
        } else {
          // Transition phone user to onboarding to enter name/email
          setState(() {
            _tempPhone = phone;
            _showOnboarding = true;
            _showPhoneInput = false;
          });
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: AppColors.brandError,
          ),
        );
      }
    }
  }

  void _handleOnboardingComplete(AppState state) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập họ và tên'),
          backgroundColor: AppColors.brandError,
        ),
      );
      return;
    }
    try {
      await state.login(_tempPhone, name);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Chào mừng ${state.currentCustomer?.name} đến với Omigo!'),
          backgroundColor: AppColors.brandGreen,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: $e'),
          backgroundColor: AppColors.brandError,
        ),
      );
    }
  }

  Widget _buildOTPInputRow(bool isDark) {
    return Column(
      children: [
        // Hidden text field that catches focus
        Opacity(
          opacity: 0,
          child: SizedBox(
            height: 0,
            child: TextField(
              controller: _otpController,
              focusNode: _otpFocusNode,
              keyboardType: TextInputType.number,
              maxLength: 6,
              onChanged: (val) {
                setState(() {});
                if (val.length == 6) {
                  // Auto submit when complete
                  _otpFocusNode.unfocus();
                }
              },
            ),
          ),
        ),
        // Row of 6 custom circles
        GestureDetector(
          onTap: () => _otpFocusNode.requestFocus(),
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(6, (index) {
              final text = _otpController.text;
              final digit = text.length > index ? text[index] : '';
              final isFocused = _otpFocusNode.hasFocus && text.length == index;

              return Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? AppColors.surfaceCode : Colors.white,
                  border: Border.all(
                    color: isFocused
                        ? AppColors.brandGreen
                        : (digit.isNotEmpty
                            ? AppColors.brandGreenDeep
                            : (isDark ? AppColors.hairlineDark : AppColors.hairline)),
                    width: isFocused ? 2 : 1,
                  ),
                  boxShadow: isFocused
                      ? [
                          BoxShadow(
                            color: AppColors.brandGreen.withOpacity(0.15),
                            blurRadius: 8,
                            spreadRadius: 1,
                          )
                        ]
                      : [],
                ),
                alignment: Alignment.center,
                child: Text(
                  digit,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink_(isDark),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final isDark = state.isDarkTheme;
    final lang = state.language;

    if (_showOnboarding) {
      return Scaffold(
        backgroundColor: AppColors.canvas_(isDark),
        body: SafeArea(
          child: _buildOnboardingView(isDark, lang, state),
        ),
      );
    } else if (_showPhoneInput) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF121214) : const Color(0xFFF9FBFC),
        body: _buildPhoneInputView(isDark, lang, state),
      );
    } else {
      return Scaffold(
        body: _buildSocialWelcomeView(isDark, lang, state),
      );
    }
  }


  Widget _buildSocialWelcomeView(bool isDark, String lang, AppState state) {
    final isVi = lang == 'vi';

    final TextStyle bgTextStyle = TextStyle(
      fontFamily: 'Inter',
      fontSize: 130,
      fontWeight: FontWeight.w900,
      fontStyle: FontStyle.italic,
      color: Colors.white.withOpacity(0.35),
      height: 0.92,
      letterSpacing: -6,
    );

    return Stack(
      children: [
        // 1. Edge-to-edge Gradient Background
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFA7F3D0), // Light mint green
                Color(0xFF6EE7B7), // Medium mint green
                Color(0xFF34D399), // Vibrant mint green
              ],
            ),
          ),
        ),
        
        // 2. Stylized Background Text
        Positioned(
          top: MediaQuery.of(context).padding.top + 20,
          left: 0,
          right: 0,
          child: Column(
            children: [
              Text('Đặt', style: bgTextStyle),
              Text('Xe', style: bgTextStyle),
              Text('Ghép', style: bgTextStyle),
            ],
          ),
        ),
        
        // 3. White bottom card rising from the bottom (SafeArea-padded for home indicator)
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF18181B) : Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x15000000),
                  blurRadius: 24,
                  offset: Offset(0, -8),
                ),
              ],
            ),
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 32,
              bottom: MediaQuery.of(context).padding.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isVi ? 'Một bước cuối cùng để bắt đầu!' : 'Just one step to go!',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isVi
                      ? 'Để tiếp tục, bạn cần tạo một tài khoản mới'
                      : 'In order to continue you need to create an account',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF52525B),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Button 1: Continue with phone number
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isOnboardingForSocial = false;
                        _showPhoneInput = true;
                        _isOTPSent = false;
                        _phoneController.clear();
                        _otpController.clear();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF032B24), // Very dark teal green
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      isVi ? 'Tiếp tục bằng số điện thoại' : 'Continue with phone number',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B981), // Emerald green text
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Button 2: Continue with Apple
                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _tempSocialMethod = 'Apple';
                        _isOnboardingForSocial = true;
                        _showPhoneInput = true;
                        _isOTPSent = false;
                        _phoneController.clear();
                        _otpController.clear();
                      });
                    },
                    icon: Icon(
                      Icons.apple_rounded,
                      size: 22,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    label: Text(
                      isVi ? 'Tiếp tục với Apple' : 'Continue with Apple',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      side: BorderSide(
                        color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE4E4E7),
                      ),
                      backgroundColor: isDark ? const Color(0xFF27272A) : Colors.white,
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Button 3: Continue with Google
                SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _tempSocialMethod = 'Google';
                        _isOnboardingForSocial = true;
                        _showPhoneInput = true;
                        _isOTPSent = false;
                        _phoneController.clear();
                        _otpController.clear();
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      side: BorderSide(
                        color: isDark ? const Color(0xFF3F3F46) : const Color(0xFFE4E4E7),
                      ),
                      backgroundColor: isDark ? const Color(0xFF27272A) : Colors.white,
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const GoogleLogoWidget(size: 18),
                        const SizedBox(width: 10),
                        Text(
                          isVi ? 'Tiếp tục với Google' : 'Continue with Google',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneInputView(bool isDark, String lang, AppState state) {
    return Stack(
      children: [
        // Bottom waves decoration
        Positioned.fill(
          child: CustomPaint(
            painter: BottomWavesPainter(isDark: isDark),
          ),
        ),
        
        // Main view content inside SafeArea
        SafeArea(
          child: Column(
            children: [
              // Header bar with back button & title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (_isOTPSent) {
                          setState(() {
                            _isOTPSent = false;
                            _otpController.clear();
                          });
                        } else {
                          setState(() {
                            _showPhoneInput = false;
                          });
                        }
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E24) : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? const Color(0xFF2D2D35) : const Color(0xFFF1F5F9),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 16,
                          color: isDark ? Colors.white : const Color(0xFF032B24),
                        ),
                      ),
                    ),
                    
                    Text(
                      lang == 'vi' ? 'Đăng nhập' : 'Login',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    
                    const SizedBox(width: 44),
                  ],
                ),
              ),
              
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 16),
                        
                        // Centered custom orbit squircle logo
                        Center(
                          child: _buildLogoWithOrbitAndSparkles(isDark),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Title Headline
                        Text(
                          _isOTPSent 
                              ? (lang == 'vi' ? 'Nhập mã xác thực' : 'Enter verification code')
                              : (lang == 'vi' ? 'Số điện thoại của bạn' : 'Enter your phone number'),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : Colors.black,
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        
                        // Subtitle description
                        Text(
                          _isOTPSent
                              ? (lang == 'vi' 
                                  ? 'Chúng tôi đã gửi một mã xác minh OTP gồm 6 chữ số đến số điện thoại của bạn.'
                                  : 'We sent a 6-digit OTP verification code to your mobile number.')
                              : (lang == 'vi'
                                  ? 'Vui lòng nhập số điện thoại để bắt đầu kết nối\ncùng Omigo.'
                                  : 'Please enter your mobile phone number to connect and start your journey.'),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                            height: 1.45,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        const SizedBox(height: 32),

                        if (!_isOTPSent) ...[
                          // Phone input label
                          Text(
                            lang == 'vi' ? 'SỐ ĐIỆN THOẠI' : 'PHONE NUMBER',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          
                          // Custom input squircle card matching mockup
                          Container(
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E1E24) : Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isDark ? const Color(0xFF2D2D35) : const Color(0xFFE2E8F0),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                Row(
                                  children: [
                                    const Text('🇻🇳', style: TextStyle(fontSize: 20)),
                                    const SizedBox(width: 8),
                                    Text(
                                      '+84',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : Colors.black,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 16,
                                      color: isDark ? const Color(0xFF71717A) : const Color(0xFF94A3B8),
                                    ),
                                  ],
                                ),
                                Container(
                                  width: 1.5,
                                  height: 24,
                                  margin: const EdgeInsets.symmetric(horizontal: 16),
                                  color: isDark ? const Color(0xFF2D2D35) : const Color(0xFFE2E8F0),
                                ),
                                Expanded(
                                  child: TextFormField(
                                    controller: _phoneController,
                                    focusNode: _phoneFocusNode,
                                    keyboardType: TextInputType.phone,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : Colors.black,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: lang == 'vi' ? 'Nhập số điện thoại' : 'Enter phone number',
                                      hintStyle: TextStyle(
                                        color: isDark ? const Color(0xFF52525B) : const Color(0xFFCBD5E1),
                                        fontWeight: FontWeight.w500,
                                      ),
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.trim().isEmpty) {
                                        return lang == 'vi' ? 'Vui lòng nhập số điện thoại' : 'Please enter your phone number';
                                      }
                                      final clean = value.trim();
                                      if (!RegExp(r'^(0|\+84)?[3|5|7|8|9][0-9]{8}$').hasMatch(clean)) {
                                        return lang == 'vi' ? 'Số điện thoại không hợp lệ' : 'Invalid phone number';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          // OTP circles entry UI
                          _buildOTPInputRow(isDark),
                          
                          const SizedBox(height: 24),
                          
                          // Resend link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                lang == 'vi' ? 'Không nhận được mã? ' : "Didn't receive code? ",
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF71717A),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(lang == 'vi' ? 'Đã gửi lại mã OTP (123456)' : 'OTP sent again (123456)'),
                                    ),
                                  );
                                },
                                child: Text(
                                  lang == 'vi' ? 'Gửi lại' : 'Resend',
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        
                        const SizedBox(height: 40),
                        
                        // Primary Continue Button
                        SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            onPressed: state.isLoading ? null : () => _handlePhoneLogin(state),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF034E3E), // Deep forest green
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                              elevation: 0,
                            ),
                            child: state.isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Spacer(flex: 2),
                                      Text(
                                        _isOTPSent 
                                            ? (lang == 'vi' ? 'Xác nhận OTP' : 'Verify Code')
                                            : (lang == 'vi' ? 'Tiếp tục' : 'Continue'),
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const Spacer(flex: 1),
                                      const Icon(
                                        Icons.arrow_forward_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Agreement footer banner matching mockup style
                        Container(
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF141F1A) : const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark ? const Color(0xFF1E3A2F) : const Color(0xFFDCFCE7),
                              width: 1,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 12,
                                      color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF3F4F48),
                                      height: 1.45,
                                    ),
                                    children: lang == 'vi'
                                        ? [
                                            const TextSpan(text: 'Bằng cách tiếp tục, bạn đồng ý với '),
                                            const TextSpan(
                                              text: 'Điều khoản dịch vụ',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF047857),
                                              ),
                                            ),
                                            const TextSpan(text: ' và '),
                                            const TextSpan(
                                              text: 'Chính sách bảo mật',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF047857),
                                              ),
                                            ),
                                            const TextSpan(text: ' của Omigo.'),
                                          ]
                                        : [
                                            const TextSpan(text: 'By continuing, you agree to the '),
                                            const TextSpan(
                                              text: 'Terms of Service',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF047857),
                                              ),
                                            ),
                                            const TextSpan(text: ' and '),
                                            const TextSpan(
                                              text: 'Privacy Policy',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF047857),
                                              ),
                                            ),
                                            const TextSpan(text: ' of Omigo.'),
                                          ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLogoWithOrbitAndSparkles(bool isDark) {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Thin ellipse orbit path
          Positioned.fill(
            child: CustomPaint(
              painter: LogoOrbitPainter(isDark: isDark),
            ),
          ),
          
          // Squircle container housing the custom vector green oval logo
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E24) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? const Color(0xFF2D2D35) : const Color(0xFFF1F5F9),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const OmigoLogoWidget(size: 48),
          ),
          
          // Sparkles and circle decorations
          Positioned(
            top: 40,
            right: 48,
            child: CustomPaint(
              size: const Size(14, 14),
              painter: SparklePainter(color: const Color(0xFF059669)),
            ),
          ),
          Positioned(
            bottom: 44,
            right: 56,
            child: CustomPaint(
              size: const Size(12, 12),
              painter: SparklePainter(color: const Color(0xFF10B981)),
            ),
          ),
          Positioned(
            left: 48,
            bottom: 84,
            child: CustomPaint(
              size: const Size(8, 8),
              painter: SparklePainter(color: const Color(0xFF34D399)),
            ),
          ),
          Positioned(
            top: 56,
            left: 60,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: const Color(0xFF06B6D4).withOpacity(0.18),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 40,
            top: 96,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: const Color(0xFF0EA5E9).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOnboardingView(bool isDark, String lang, AppState state) {
    final isVi = lang == 'vi';
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.xl),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.brandGreenSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.assignment_ind_rounded,
                color: AppColors.brandGreen,
                size: 40,
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          Text(
            isVi ? 'Thông tin cá nhân' : 'Personal Profile',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.ink_(isDark),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          
          Text(
            isVi 
                ? 'Vui lòng điền họ tên và email để hoàn tất thiết lập tài khoản của bạn.'
                : 'Please complete your name and email to finish setting up your account.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: AppColors.steel_(isDark),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 36),

          Text(
            isVi ? 'HỌ VÀ TÊN' : 'FULL NAME',
            style: AppText.microUppercase.copyWith(
              color: AppColors.steel_(isDark),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _nameController,
            style: AppText.bodySm.copyWith(color: AppColors.ink_(isDark)),
            decoration: InputDecoration(
              hintText: isVi ? 'Nhập họ và tên của bạn' : 'Your full name',
              prefixIcon: const Icon(Icons.person_outline_rounded, size: 18),
              filled: true,
              fillColor: isDark ? AppColors.surfaceCode : Colors.white,
            ),
          ),
          const SizedBox(height: 24),

          Text(
            isVi ? 'ĐỊA CHỈ EMAIL' : 'EMAIL ADDRESS',
            style: AppText.microUppercase.copyWith(
              color: AppColors.steel_(isDark),
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: AppText.bodySm.copyWith(color: AppColors.ink_(isDark)),
            decoration: InputDecoration(
              hintText: isVi ? 'Nhập email của bạn' : 'Your email address',
              prefixIcon: const Icon(Icons.mail_outline_rounded, size: 18),
              filled: true,
              fillColor: isDark ? AppColors.surfaceCode : Colors.white,
            ),
          ),
          const SizedBox(height: 40),

          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: () => _handleOnboardingComplete(state),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brandGreen,
                shape: const StadiumBorder(),
                elevation: 0,
              ),
              child: Text(
                isVi ? 'Bắt đầu trải nghiệm' : 'Get Started',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Custom Dashed Border Painter ──
class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double dashLength;
  final double borderRadius;

  DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.gap = 4.0,
    this.dashLength = 6.0,
    this.borderRadius = 24.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(strokeWidth / 2, strokeWidth / 2, size.width - strokeWidth, size.height - strokeWidth),
      Radius.circular(borderRadius),
    );

    final Path path = Path()..addRRect(rrect);
    final Path metricsPath = Path();

    for (final PathMetric metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final double end = distance + dashLength;
        metricsPath.addPath(
          metric.extractPath(distance, end > metric.length ? metric.length : end),
          Offset.zero,
        );
        distance += dashLength + gap;
      }
    }
    canvas.drawPath(metricsPath, paint);
  }

  @override
  bool shouldRepaint(covariant DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.gap != gap ||
      oldDelegate.dashLength != dashLength ||
      oldDelegate.borderRadius != borderRadius;
}

// ── Google Logo Widget with Custom Painter ──
class GoogleLogoWidget extends StatelessWidget {
  final double size;
  const GoogleLogoWidget({Key? key, this.size = 20}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double strokeWidth = w * 0.22;
    final Rect rect = Rect.fromLTWH(strokeWidth / 2, strokeWidth / 2, w - strokeWidth, h - strokeWidth);

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // Red sector (top)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, -2.4, 1.25, false, paint);

    // Yellow sector (left)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, -3.65, 1.25, false, paint);

    // Green sector (bottom)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 0.2, 1.35, false, paint);

    // Blue sector (right + bar)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -1.15, 1.35, false, paint);

    // Draw horizontal bar of 'G'
    final Paint fillPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    final Path path = Path();
    path.moveTo(w / 2, h / 2 - strokeWidth / 2);
    path.lineTo(w - strokeWidth / 2, h / 2 - strokeWidth / 2);
    path.lineTo(w - strokeWidth / 2, h / 2 + strokeWidth / 2);
    path.lineTo(w / 2, h / 2 + strokeWidth / 2);
    path.close();
    canvas.drawPath(path, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Custom Painter for Bottom Waves ──
class BottomWavesPainter extends CustomPainter {
  final bool isDark;
  BottomWavesPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    if (isDark) return; // omit in dark mode

    final paint = Paint()
      ..style = PaintingStyle.fill;

    // Outer wave (very soft mint green)
    paint.color = const Color(0xFFECFDF5);
    final path1 = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, size.height - 80)
      ..quadraticBezierTo(size.width * 0.25, size.height - 75, size.width * 0.5, size.height - 35)
      ..quadraticBezierTo(size.width * 0.75, size.height - 5, size.width, size.height - 10)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path1, paint);

    // Inner wave (slightly darker mint green)
    paint.color = const Color(0xFFDCFCE7).withOpacity(0.5);
    final path2 = Path()
      ..moveTo(size.width, size.height)
      ..lineTo(size.width, size.height - 60)
      ..quadraticBezierTo(size.width * 0.8, size.height - 50, size.width * 0.6, size.height - 25)
      ..quadraticBezierTo(size.width * 0.3, size.height - 5, 0, size.height)
      ..close();
    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Custom Painter for Logo Orbit ──
class LogoOrbitPainter extends CustomPainter {
  final bool isDark;
  LogoOrbitPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark ? const Color(0xFF047857).withOpacity(0.2) : const Color(0xFF10B981).withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(-0.35); // rotate by -20 degrees (approx -0.35 rad)
    
    final rect = Rect.fromCenter(center: Offset.zero, width: 176, height: 72);
    canvas.drawOval(rect, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Custom Painter for Sparkle Star ──
class SparklePainter extends CustomPainter {
  final Color color;
  SparklePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..quadraticBezierTo(size.width / 2, size.height / 2, size.width, size.height / 2)
      ..quadraticBezierTo(size.width / 2, size.height / 2, size.width / 2, size.height)
      ..quadraticBezierTo(size.width / 2, size.height / 2, 0, size.height / 2)
      ..quadraticBezierTo(size.width / 2, size.height / 2, size.width / 2, 0)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

