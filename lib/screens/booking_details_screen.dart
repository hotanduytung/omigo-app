import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/trip_request.dart';
import '../services/app_state.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class BookingDetailsScreen extends StatefulWidget {
  final TripRequest trip;
  const BookingDetailsScreen({Key? key, required this.trip}) : super(key: key);

  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  bool _isRebooking = false;

  void _rebookRide(AppState state) {
    state.setPrefillBooking(
      widget.trip.pickupSpecificPoint,
      widget.trip.dropoffSpecificPoint,
      widget.trip.serviceType,
    );
    state.setSelectedTabIndex(0); // Go to Home tab
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _showRatingSheet(AppState state) {
    int rating = 5;
    final commentController = TextEditingController();
    final isDark = state.isDarkTheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
            top: AppSpacing.xl,
            left: AppSpacing.xl,
            right: AppSpacing.xl,
          ),
          decoration: BoxDecoration(
            color: AppColors.card_(isDark),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.xxl)),
            border: Border.all(color: AppColors.hairline_(isDark)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.hairline_(isDark),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
              Text(
                state.language == 'vi'
                    ? 'Đánh giá chuyến đi'
                    : 'Rate your ride',
                style: AppText.heading5.copyWith(color: AppColors.ink_(isDark)),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                state.language == 'vi'
                    ? 'Ý kiến của bạn giúp chúng tôi cải thiện dịch vụ'
                    : 'Your feedback helps us improve',
                textAlign: TextAlign.center,
                style:
                    AppText.caption.copyWith(color: AppColors.stone_(isDark)),
              ),
              const SizedBox(height: AppSpacing.xl),
              // Star rating
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                    5,
                    (i) => IconButton(
                          icon: Icon(
                            i < rating
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            size: 44,
                            color: i < rating
                                ? AppColors.brandGreen
                                : AppColors.hairline_(isDark),
                          ),
                          onPressed: () => setModalState(() => rating = i + 1),
                        )),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: commentController,
                maxLines: 3,
                style: AppText.bodySm.copyWith(color: AppColors.ink_(isDark)),
                decoration: InputDecoration(
                  hintText: state.language == 'vi'
                      ? 'Nhập phản hồi của bạn...'
                      : 'Write your feedback...',
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                        state.language == 'vi'
                            ? 'Cảm ơn bạn đã đánh giá!'
                            : 'Thank you for your rating!',
                      ),
                      backgroundColor: AppColors.brandGreen,
                    ));
                  },
                  child: Text(
                    state.language == 'vi' ? 'Gửi đánh giá' : 'Submit Review',
                    style:
                        AppText.buttonMd.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final isDark = state.isDarkTheme;
    final lang = state.language;
    final fmt = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

    // Status
    final sColor = statusColor(widget.trip.status);
    final sLabel = statusLabel(widget.trip.status, lang);

    // Driver
    final driverName = widget.trip.assignedDriverName ??
        (lang == 'vi' ? 'Nguyễn Văn Hùng' : 'Hung Nguyen');
    final hasDriver = ['assigned', 'on_trip', 'completed']
        .contains(widget.trip.status.toLowerCase());
    final isCompleted = widget.trip.status.toLowerCase() == 'completed';

    // Prices
    final double base = widget.trip.appliedFixedPrice;
    final double tax = base * 0.10;
    final double total = base + tax;

    // Booking ID
    final id = widget.trip.id ?? 'OMIGO';
    final shortId = id.length > 6
        ? id.substring(id.length - 6).toUpperCase()
        : id.toUpperCase();

    // Service info
    final svc = serviceInfo(widget.trip.serviceType, lang);

    return Scaffold(
      backgroundColor: AppColors.surface_(isDark),
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          lang == 'vi' ? 'Chi tiết chuyến đi' : 'Booking Details',
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Booking ID card ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: cardDecoration(isDark),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang == 'vi' ? 'Mã chuyến đi' : 'Booking ID',
                        style: AppText.microUppercase.copyWith(
                          color: AppColors.steel_(isDark),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '#$shortId',
                        style: AppText.codeMd.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink_(isDark),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Service badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(svc.icon, size: 12, color: AppColors.steel),
                        const SizedBox(width: 4),
                        Text(
                          svc.label,
                          style: AppText.captionBold
                              .copyWith(color: AppColors.steel),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  // Copy button — circular icon button
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.hairline_(isDark)),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        Icons.copy_rounded,
                        size: 14,
                        color: AppColors.steel_(isDark),
                      ),
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: widget.trip.id ?? ''),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(
                            lang == 'vi'
                                ? 'Đã sao chép mã đặt xe!'
                                : 'Copied booking ID!',
                          ),
                        ));
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Route Timeline ─────────────────────────────────────────────
            sectionLabel(lang == 'vi' ? 'Hành trình' : 'Route', isDark),
            const SizedBox(height: AppSpacing.sm),

            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: cardDecoration(isDark),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Timeline indicators
                  Column(
                    children: [
                      const SizedBox(height: 3),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: AppColors.brandGreen,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Container(
                        width: 1.5,
                        height: 36,
                        color: AppColors.hairline_(isDark),
                      ),
                      Icon(Icons.location_on_rounded,
                          color: AppColors.brandError, size: 14),
                    ],
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lang == 'vi' ? 'Điểm đón' : 'Pickup',
                          style: AppText.microUppercase.copyWith(
                            color: AppColors.stone_(isDark),
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '${widget.trip.pickupSpecificPoint}, ${widget.trip.origin}',
                          style: AppText.bodySmMedium.copyWith(
                            color: AppColors.ink_(isDark),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          lang == 'vi' ? 'Điểm trả' : 'Dropoff',
                          style: AppText.microUppercase.copyWith(
                            color: AppColors.stone_(isDark),
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '${widget.trip.dropoffSpecificPoint}, ${widget.trip.destination}',
                          style: AppText.bodySmMedium.copyWith(
                            color: AppColors.ink_(isDark),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // ── Date + Status row ──────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: cardDecoration(isDark),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lang == 'vi' ? 'Thời gian' : 'Date & Time',
                          style: AppText.microUppercase.copyWith(
                            color: AppColors.stone_(isDark),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.trip.requestedDepartureTime.split(' ').first,
                          style: AppText.bodySmMedium.copyWith(
                            color: AppColors.ink_(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: cardDecoration(isDark),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lang == 'vi' ? 'Trạng thái' : 'Status',
                          style: AppText.microUppercase.copyWith(
                            color: AppColors.stone_(isDark),
                          ),
                        ),
                        const SizedBox(height: 4),
                        statusBadge(widget.trip.status, lang),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Driver Card ────────────────────────────────────────────────
            if (hasDriver) ...[
              sectionLabel(lang == 'vi' ? 'Tài xế' : 'Driver', isDark),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: cardDecoration(isDark),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor:
                              AppColors.brandGreen.withOpacity(0.12),
                          child: Text(
                            driverName.substring(0, 1).toUpperCase(),
                            style: AppText.heading5.copyWith(
                              color: AppColors.brandGreen,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                driverName,
                                style: AppText.bodySmMedium.copyWith(
                                  color: AppColors.ink_(isDark),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.star_rounded,
                                      color: Colors.amber, size: 13),
                                  const SizedBox(width: 3),
                                  Text(
                                    '4.8',
                                    style: AppText.caption.copyWith(
                                      color: AppColors.steel_(isDark),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // License plate — code-inline badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isDark ? AppColors.surfaceCode : AppColors.ink,
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                          ),
                          child: Text(
                            '92A-567.89',
                            style: AppText.codeInline.copyWith(
                              color: AppColors.canvas,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Divider(height: 1, color: AppColors.hairline_(isDark)),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          lang == 'vi' ? 'Phương tiện' : 'Vehicle',
                          style: AppText.bodySm.copyWith(
                            color: AppColors.steel_(isDark),
                          ),
                        ),
                        Text(
                          lang == 'vi'
                              ? 'Toyota Vios • Trắng'
                              : 'Toyota Vios • White',
                          style: AppText.bodySmMedium.copyWith(
                            color: AppColors.ink_(isDark),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],

            // ── Rate — only for completed ──────────────────────────────────
            if (isCompleted) ...[
              GestureDetector(
                onTap: () => _showRatingSheet(state),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brandGreen.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                      color: AppColors.brandGreen.withOpacity(0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          color: AppColors.brandGreen, size: 20),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          lang == 'vi'
                              ? 'Đánh giá tài xế'
                              : 'Rate Driver',
                          style: AppText.bodySmMedium.copyWith(
                            color: AppColors.brandGreen,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: AppColors.brandGreen, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],

            // ── Payment Breakdown ──────────────────────────────────────────
            sectionLabel(lang == 'vi' ? 'Thanh toán' : 'Payment', isDark),
            const SizedBox(height: AppSpacing.sm),

            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: cardDecoration(isDark),
              child: Column(
                children: [
                  _payRow(
                    label: lang == 'vi' ? 'Giá cước chuyến xe' : 'Trip charge',
                    value: fmt.format(base),
                    isDark: isDark,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _payRow(
                    label: lang == 'vi' ? 'Thuế GTGT (10%)' : 'VAT (10%)',
                    value: fmt.format(tax),
                    isDark: isDark,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Divider(height: 1, color: AppColors.hairline_(isDark)),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        lang == 'vi' ? 'Tổng thanh toán' : 'Total',
                        style: AppText.bodySmMedium.copyWith(
                          color: AppColors.ink_(isDark),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      // {typography.heading-4} Geist Mono in brandGreen
                      Text(
                        fmt.format(total),
                        style: AppText.heading4.copyWith(
                          fontFamily: 'Geist Mono',
                          color: AppColors.brandGreen,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Need Help ──────────────────────────────────────────────────
            Center(
              child: TextButton(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      lang == 'vi'
                          ? 'Liên hệ tổng đài 1900-OMIGO để được hỗ trợ.'
                          : 'Contact hotline 1900-OMIGO for support.',
                    ),
                  ),
                ),
                child: Text(
                  lang == 'vi' ? 'Bạn cần trợ giúp?' : 'Need help?',
                  style: AppText.bodySmMedium.copyWith(
                    color: AppColors.brandGreen,
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // ── Action Buttons ─────────────────────────────────────────────
            Row(
              children: [
                // Export invoice — {button-secondary} outlined pill
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          lang == 'vi'
                              ? 'Đã gửi hóa đơn qua email!'
                              : 'Invoice sent to email!',
                        ),
                      ),
                    ),
                    child: Text(
                      lang == 'vi' ? 'Xuất hóa đơn' : 'Export invoice',
                      style: AppText.buttonMd.copyWith(
                        color: AppColors.ink_(isDark),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                // Rebook — {button-accent-green} mint pill
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _rebookRide(state),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandGreen,
                      foregroundColor: AppColors.ink,
                    ),
                    child: Text(
                      lang == 'vi' ? 'Đặt lại chuyến' : 'Rebook Ride',
                      style: AppText.buttonMd.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _payRow({
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppText.bodySm.copyWith(color: AppColors.steel_(isDark)),
        ),
        Text(
          value,
          style: AppText.codeSm.copyWith(
            color: AppColors.charcoal,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
