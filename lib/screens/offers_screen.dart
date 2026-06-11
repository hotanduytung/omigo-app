import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';

class OffersScreen extends StatelessWidget {
  const OffersScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final isDark = state.isDarkTheme;
    final lang = state.language;

    final List<Map<String, String>> coupons = [
      {
        'title': lang == 'vi' ? 'Giảm 30K cho chuyến ghép' : '30K Off for Shared Ride',
        'code': 'OMIGOSHARE30',
        'desc': lang == 'vi' ? 'Áp dụng cho đơn từ 120K' : 'Min spend 120K',
        'exp': '30/06/2024',
      },
      {
        'title': lang == 'vi' ? 'Giảm 50K bao xe đường dài' : '50K Off for Private Car',
        'code': 'OMIGOPRIVATE50',
        'desc': lang == 'vi' ? 'Áp dụng cho chuyến trên 300K' : 'Min spend 300K',
        'exp': '15/07/2024',
      },
      {
        'title': lang == 'vi' ? 'Miễn phí giao hàng chặng đầu' : 'Free Cargo Delivery First Ride',
        'code': 'OMIGODELIVERFREE',
        'desc': lang == 'vi' ? 'Tối đa 25K cho khách hàng mới' : 'Max discount 25K for new users',
        'exp': '31/08/2024',
      },
      {
        'title': lang == 'vi' ? 'Giảm 10% tổng hóa đơn di chuyển' : '10% Off All Booking Bills',
        'code': 'OMIGOSUMMER10',
        'desc': lang == 'vi' ? 'Áp dụng cho tất cả dịch vụ hè' : 'For all summer campaign rides',
        'exp': '30/09/2024',
      },
    ];

    return Scaffold(
      backgroundColor: AppColors.canvas_(isDark),
      appBar: AppBar(
        title: Text(
          lang == 'vi' ? 'Ưu đãi dành cho bạn' : 'Offers & Rewards',
          style: AppText.heading5.copyWith(color: AppColors.ink_(isDark)),
        ),
        backgroundColor: AppColors.canvas_(isDark),
        foregroundColor: AppColors.ink_(isDark),
        centerTitle: true,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.hairline_(isDark)),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.xl),
        itemCount: coupons.length,
        itemBuilder: (context, index) {
          final coupon = coupons[index];
          return Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            height: 104,
            decoration: cardDecoration(isDark, radius: AppRadius.lg),
            child: Row(
              children: [
                // Coupon icon column (left side of dashed line)
                Container(
                  width: 80,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.brandGreen.withOpacity(0.08),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(AppRadius.lg),
                      bottomLeft: Radius.circular(AppRadius.lg),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.brandGreen,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(
                      Icons.percent_rounded,
                      color: Colors.black,
                      size: 20,
                    ),
                  ),
                ),
                // Dashed separator line
                CustomPaint(
                  size: const Size(1, double.infinity),
                  painter: _DashedLinePainter(
                    color: AppColors.hairline_(isDark),
                  ),
                ),
                // Coupon details (middle)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          coupon['title']!,
                          style: AppText.bodySmMedium.copyWith(
                            color: AppColors.ink_(isDark),
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          coupon['desc']!,
                          style: AppText.caption.copyWith(
                            color: AppColors.steel_(isDark),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${lang == 'vi' ? 'HSD' : 'EXP'}: ${coupon['exp']}',
                          style: AppText.caption.copyWith(
                            color: AppColors.stone_(isDark),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Copy/Apply button (right side)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.md),
                  child: TextButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: coupon['code']!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            lang == 'vi'
                                ? 'Đã sao chép mã ${coupon['code']} vào bộ nhớ tạm!'
                                : 'Copied code ${coupon['code']} to clipboard!',
                          ),
                          backgroundColor: AppColors.brandGreen,
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      backgroundColor: AppColors.brandGreen.withOpacity(0.12),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(
                      lang == 'vi' ? 'Sử dụng' : 'Use',
                      style: AppText.captionBold.copyWith(
                        color: AppColors.brandGreenDeep,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  _DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const double dashHeight = 4;
    const double dashSpace = 4;
    double startY = 4;

    while (startY < size.height - 4) {
      canvas.drawLine(
        Offset(0, startY),
        Offset(0, startY + dashHeight),
        paint,
      );
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
