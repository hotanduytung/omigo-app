import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import 'booking_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  IconData _getTabIcon(int index, bool isSelected) {
    switch (index) {
      case 0:
        return isSelected ? Icons.home_rounded : Icons.home_outlined;
      case 1:
        return isSelected ? Icons.receipt_long_rounded : Icons.receipt_long_outlined;
      case 2:
        return isSelected ? Icons.person_rounded : Icons.person_outline_rounded;
      default:
        return Icons.home_rounded;
    }
  }

  String _getTabLabel(int index, String lang) {
    final vi = lang == 'vi';
    switch (index) {
      case 0:
        return vi ? 'Trang chủ' : 'Home';
      case 1:
        return vi ? 'Hoạt động' : 'Activities';
      case 2:
        return vi ? 'Tài khoản' : 'Profile';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final isDark = state.isDarkTheme;
    final lang = state.language;

    final screens = [
      const BookingScreen(),
      const HistoryScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: state.selectedTabIndex,
        children: screens,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        bottom: true,
        child: Container(
          margin: const EdgeInsets.only(left: 20, right: 20, bottom: 8, top: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.white.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.08)
                        : Colors.black.withOpacity(0.05),
                    width: 1,
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final totalWidth = constraints.maxWidth;
                    final itemWidth = (totalWidth - 16) / 3;
                    return Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        // Sliding Indicator Background
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOutBack,
                          left: 8 + state.selectedTabIndex * itemWidth,
                          top: 4,
                          bottom: 4,
                          width: itemWidth,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isDark
                                    ? [
                                        AppColors.brandGreen.withOpacity(0.18),
                                        AppColors.brandGreen.withOpacity(0.08)
                                      ]
                                    : [
                                        AppColors.brandGreen.withOpacity(0.12),
                                        AppColors.brandGreen.withOpacity(0.04)
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: AppColors.brandGreen.withOpacity(0.25),
                                width: 1,
                              ),
                            ),
                          ),
                        ),
                        // The actual buttons
                        Row(
                          children: List.generate(3, (index) {
                            final isSelected = state.selectedTabIndex == index;
                            final icon = _getTabIcon(index, isSelected);
                            final label = _getTabLabel(index, lang);
                            return Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  state.setSelectedTabIndex(index);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      AnimatedScale(
                                        duration: const Duration(milliseconds: 250),
                                        scale: isSelected ? 1.15 : 1.0,
                                        child: Icon(
                                          icon,
                                          size: 22,
                                          color: isSelected
                                              ? AppColors.brandGreen
                                              : (isDark ? Colors.white60 : Colors.black45),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        label,
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 10.5,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                          color: isSelected
                                              ? AppColors.brandGreen
                                              : (isDark ? Colors.white60 : Colors.black45),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
