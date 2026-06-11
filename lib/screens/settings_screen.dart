import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final isDark = state.isDarkTheme;
    final customer = state.currentCustomer;
    final lang = state.language;

    return Scaffold(
      backgroundColor: AppColors.surface_(isDark),
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          lang == 'vi' ? 'Cài đặt' : 'Settings',
          style: AppText.heading5.copyWith(color: AppColors.ink_(isDark)),
        ),
        backgroundColor: AppColors.card_(isDark),
        foregroundColor: AppColors.ink_(isDark),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.hairline_(isDark)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Profile Card ─────────────────────────────────────────────────
            if (customer != null) ...[
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: cardDecoration(isDark),
                child: Row(
                  children: [
                    // Avatar
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.brandGreen,
                      child: Text(
                        customer.name.isNotEmpty
                            ? customer.name[0].toUpperCase()
                            : 'U',
                        style: AppText.heading5.copyWith(color: AppColors.ink),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer.name,
                            style: AppText.bodySmMedium.copyWith(
                              color: AppColors.ink_(isDark),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            customer.phoneNumber,
                            style: AppText.codeSm.copyWith(
                              color: AppColors.steel_(isDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Edit icon — circular icon button
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        border: Border.all(color: AppColors.hairline_(isDark)),
                      ),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: AppColors.brandGreen,
                        ),
                        onPressed: () => _showEditProfileDialog(
                          context, state, customer.name,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],

            // ── Section: Personalization ─────────────────────────────────────
            sectionLabel(lang == 'vi' ? 'Cá nhân hóa' : 'Personalization', isDark),
            const SizedBox(height: AppSpacing.xs),

            Container(
              clipBehavior: Clip.antiAlias,
              decoration: cardDecoration(isDark),
              child: Column(
                children: [
                  _settingsTile(
                    isDark: isDark,
                    icon: Icons.dark_mode_outlined,
                    label: lang == 'vi' ? 'Chế độ tối' : 'Dark Mode',
                    trailing: Switch(
                      value: isDark,
                      activeColor: AppColors.brandGreen,
                      onChanged: (_) => state.toggleTheme(),
                    ),
                  ),
                  Divider(height: 1, color: AppColors.hairline_(isDark)),
                  _settingsTile(
                    isDark: isDark,
                    icon: Icons.language_outlined,
                    label: lang == 'vi' ? 'Ngôn ngữ' : 'Language',
                    trailing: DropdownButton<String>(
                      value: state.language,
                      dropdownColor: AppColors.card_(isDark),
                      underline: const SizedBox(),
                      style: AppText.bodySmMedium.copyWith(
                        color: AppColors.ink_(isDark),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'vi',
                          child: Text('Tiếng Việt'),
                        ),
                        DropdownMenuItem(
                          value: 'en',
                          child: Text('English'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          state.setLanguage(val);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                val == 'vi'
                                    ? 'Đã đổi ngôn ngữ sang: Tiếng Việt'
                                    : 'Language changed to: English',
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Section: Omigo Info ──────────────────────────────────────────
            sectionLabel(lang == 'vi' ? 'Thông tin Omigo' : 'Omigo Info', isDark),
            const SizedBox(height: AppSpacing.xs),

            Container(
              clipBehavior: Clip.antiAlias,
              decoration: cardDecoration(isDark),
              child: Column(
                children: [
                  _settingsTile(
                    isDark: isDark,
                    icon: Icons.info_outline_rounded,
                    label: lang == 'vi' ? 'Phiên bản ứng dụng' : 'App Version',
                    trailing: Text(
                      'v1.0.0',
                      style: AppText.codeSm.copyWith(
                        color: AppColors.steel_(isDark),
                      ),
                    ),
                  ),
                  Divider(height: 1, color: AppColors.hairline_(isDark)),
                  _settingsTile(
                    isDark: isDark,
                    icon: Icons.help_outline_rounded,
                    label: lang == 'vi' ? 'Trung tâm trợ giúp' : 'Help Center',
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: AppColors.steel_(isDark),
                    ),
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          lang == 'vi'
                              ? 'Chức năng đang phát triển...'
                              : 'Help Center under development...',
                        ),
                      ),
                    ),
                  ),
                  Divider(height: 1, color: AppColors.hairline_(isDark)),
                  _settingsTile(
                    isDark: isDark,
                    icon: Icons.shield_outlined,
                    label: lang == 'vi'
                        ? 'Điều khoản & Bảo mật'
                        : 'Terms & Privacy',
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: AppColors.steel_(isDark),
                    ),
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          lang == 'vi'
                              ? 'Điều khoản dịch vụ Omigo'
                              : 'Omigo Terms of Service',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // ── Logout — outlined pill, brandError ──────────────────────────
            OutlinedButton(
              onPressed: () => _confirmLogout(context, state, lang),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.brandError,
                side: BorderSide(color: AppColors.brandError.withOpacity(0.5)),
                backgroundColor: AppColors.brandError.withOpacity(0.05),
                minimumSize: const Size(double.infinity, 48),
              ),
              child: Text(
                lang == 'vi' ? 'Đăng xuất tài khoản' : 'Log Out Account',
                style: AppText.buttonMd.copyWith(
                  color: AppColors.brandError,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── App attribution footer ───────────────────────────────────────
            Center(
              child: Text(
                'Omigo © 2026 · Powered by Taxi Loyal',
                style: AppText.micro.copyWith(color: AppColors.stone_(isDark)),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  // Custom tile to match {typography.body-sm} + proper icon color
  Widget _settingsTile({
    required bool isDark,
    required IconData icon,
    required String label,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.steel_(isDark)),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                label,
                style: AppText.bodySm.copyWith(color: AppColors.ink_(isDark)),
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context, AppState state, String lang) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card_(state.isDarkTheme),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(
          lang == 'vi' ? 'Đăng xuất' : 'Log Out',
          style: AppText.heading5.copyWith(color: AppColors.ink_(state.isDarkTheme)),
        ),
        content: Text(
          lang == 'vi'
              ? 'Bạn có chắc muốn đăng xuất khỏi tài khoản Omigo?'
              : 'Are you sure you want to log out?',
          style: AppText.bodySm.copyWith(color: AppColors.steel_(state.isDarkTheme)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              lang == 'vi' ? 'Hủy' : 'Cancel',
              style: AppText.bodySmMedium.copyWith(color: AppColors.steel),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              state.logout();
            },
            child: Text(
              lang == 'vi' ? 'Đăng xuất' : 'Log Out',
              style: AppText.bodySmMedium.copyWith(color: AppColors.brandError),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog(
    BuildContext context, AppState state, String currentName,
  ) {
    final controller = TextEditingController(text: currentName);
    final lang = state.language;
    final isDark = state.isDarkTheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card_(isDark),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(
          lang == 'vi' ? 'Chỉnh sửa họ tên' : 'Edit Full Name',
          style: AppText.heading5.copyWith(color: AppColors.ink_(isDark)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lang == 'vi' ? 'Họ và tên của bạn:' : 'Your full name:',
              style: AppText.caption.copyWith(color: AppColors.steel_(isDark)),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: controller,
              autofocus: true,
              style: AppText.bodySm.copyWith(color: AppColors.ink_(isDark)),
              decoration: InputDecoration(
                hintText: lang == 'vi' ? 'Nhập họ tên mới...' : 'Enter new name...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              lang == 'vi' ? 'Hủy' : 'Cancel',
              style: AppText.bodySmMedium.copyWith(color: AppColors.steel),
            ),
          ),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                Navigator.pop(ctx);
                await state.updateProfile(newName);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      lang == 'vi'
                          ? 'Đã cập nhật họ tên thành công!'
                          : 'Profile updated successfully!',
                    ),
                    backgroundColor: AppColors.brandGreen,
                  ),
                );
              }
            },
            child: Text(
              lang == 'vi' ? 'Lưu' : 'Save',
              style: AppText.bodySmMedium.copyWith(color: AppColors.brandGreen),
            ),
          ),
        ],
      ),
    );
  }
}
