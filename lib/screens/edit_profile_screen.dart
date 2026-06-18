import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/customer.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';

class EditProfileScreen extends StatefulWidget {
  final Customer customer;
  const EditProfileScreen({Key? key, required this.customer}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  final _otpController = TextEditingController();

  bool _showOTP = false;
  String? _otpError;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.customer.name);
    _phoneController = TextEditingController(text: widget.customer.phoneNumber);
    _emailController = TextEditingController(text: widget.customer.email);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _handleSave(AppState state) {
    final newName = _nameController.text.trim();
    final newPhone = _phoneController.text.trim();
    final newEmail = _emailController.text.trim();
    final lang = state.language;

    if (newName.isEmpty || newPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang == 'vi'
                ? 'Tên và số điện thoại không được để trống'
                : 'Name and phone number cannot be empty',
          ),
          backgroundColor: AppColors.brandError,
        ),
      );
      return;
    }

    final hasChanges = newName != widget.customer.name ||
        newPhone != widget.customer.phoneNumber ||
        newEmail != widget.customer.email;

    if (!hasChanges) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _showOTP = true;
      _otpError = null;
      _otpController.clear();
    });
  }

  void _handleVerify(AppState state) async {
    final code = _otpController.text.trim();
    final lang = state.language;

    if (code != '123456') {
      setState(() {
        _otpError = lang == 'vi'
            ? 'Mã OTP không chính xác. Thử lại (Mock: 123456)'
            : 'Incorrect OTP. Try again (Mock: 123456)';
      });
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await state.updateProfile(
        name: _nameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        email: _emailController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              lang == 'vi'
                  ? 'Cập nhật thông tin tài khoản thành công!'
                  : 'Profile updated successfully!',
            ),
            backgroundColor: AppColors.brandGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang == 'vi' ? 'Lỗi: $e' : 'Error: $e'),
            backgroundColor: AppColors.brandError,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final isDark = state.isDarkTheme;
    final lang = state.language;

    return Scaffold(
      backgroundColor: AppColors.surface_(isDark),
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
          onPressed: () {
            if (_showOTP) {
              setState(() {
                _showOTP = false;
              });
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        title: Text(
          _showOTP
              ? (lang == 'vi' ? 'Xác thực OTP' : 'Verify OTP')
              : (lang == 'vi' ? 'Hồ sơ cá nhân' : 'Personal Profile'),
          style: AppText.heading5.copyWith(color: AppColors.ink_(isDark)),
        ),
        backgroundColor: AppColors.card_(isDark),
        foregroundColor: AppColors.ink_(isDark),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.hairline_(isDark)),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _showOTP
            ? _buildOTPView(isDark, lang, state)
            : _buildEditFormView(isDark, lang, state),
      ),
    );
  }

  Widget _buildEditFormView(bool isDark, String lang, AppState state) {
    return SingleChildScrollView(
      key: const ValueKey('edit_form'),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Graphic header icon
          Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : const Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_outline_rounded,
                size: 54,
                color: AppColors.brandGreenDeep,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            lang == 'vi' ? 'Họ và tên' : 'Full Name',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.steel_(isDark),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            style: AppText.bodySm.copyWith(color: AppColors.ink_(isDark)),
            decoration: InputDecoration(
              hintText: lang == 'vi' ? 'Nhập họ tên...' : 'Enter name...',
              filled: true,
              fillColor:
                  isDark ? AppColors.surfaceDark : const Color(0xFFFAFAFA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.hairline_(isDark)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.brandGreen, width: 1.5),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            lang == 'vi' ? 'Số điện thoại' : 'Phone Number',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.steel_(isDark),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style: AppText.bodySm.copyWith(color: AppColors.ink_(isDark)),
            decoration: InputDecoration(
              hintText:
                  lang == 'vi' ? 'Nhập số điện thoại...' : 'Enter phone...',
              filled: true,
              fillColor:
                  isDark ? AppColors.surfaceDark : const Color(0xFFFAFAFA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.hairline_(isDark)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.brandGreen, width: 1.5),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            lang == 'vi' ? 'Email' : 'Email Address',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.steel_(isDark),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: AppText.bodySm.copyWith(color: AppColors.ink_(isDark)),
            decoration: InputDecoration(
              hintText: lang == 'vi' ? 'Nhập email...' : 'Enter email...',
              filled: true,
              fillColor:
                  isDark ? AppColors.surfaceDark : const Color(0xFFFAFAFA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.hairline_(isDark)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.brandGreen, width: 1.5),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 36),
          ElevatedButton(
            onPressed: () => _handleSave(state),
            style: ElevatedButton.styleFrom(
              shape: const StadiumBorder(),
              backgroundColor: AppColors.brandGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              lang == 'vi' ? 'Lưu thay đổi' : 'Save Changes',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOTPView(bool isDark, String lang, AppState state) {
    return SingleChildScrollView(
      key: const ValueKey('otp_form'),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : const Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shield_outlined,
                size: 54,
                color: AppColors.brandGreen,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            lang == 'vi' ? 'Mã xác thực OTP' : 'Verification OTP',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.ink_(isDark),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            lang == 'vi'
                ? 'Mã OTP đã được gửi đến số điện thoại mới.\nVui lòng nhập OTP để xác nhận thay đổi (Mock: 123456)'
                : 'Verification OTP has been sent.\nPlease enter OTP to confirm changes (Mock: 123456)',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              height: 1.4,
              color: AppColors.steel_(isDark),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            autofocus: true,
            style: TextStyle(
              fontFamily: 'Inter',
              color: AppColors.ink_(isDark),
              letterSpacing: 16,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: '******',
              hintStyle:
                  TextStyle(letterSpacing: 16, color: AppColors.stone_(isDark)),
              counterText: '',
              errorText: _otpError,
              errorStyle:
                  const TextStyle(fontSize: 12, color: AppColors.brandError),
            ),
            onChanged: (text) {
              if (text.length == 6) {
                _handleVerify(state);
              }
            },
          ),
          const SizedBox(height: 36),
          ElevatedButton(
            onPressed: _isSaving ? null : () => _handleVerify(state),
            style: ElevatedButton.styleFrom(
              shape: const StadiumBorder(),
              backgroundColor: AppColors.brandGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : Text(
                    lang == 'vi' ? 'Xác nhận' : 'Verify',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              setState(() {
                _showOTP = false;
              });
            },
            child: Text(
              lang == 'vi' ? 'Quay lại chỉnh sửa' : 'Back to Edit',
              style: TextStyle(
                fontFamily: 'Inter',
                color: AppColors.brandGreenDeep,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
