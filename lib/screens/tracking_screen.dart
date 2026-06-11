import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/app_state.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({Key? key}) : super(key: key);

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  bool _isRefreshing = false;
  Timer? _animationTimer;

  @override
  void initState() {
    super.initState();
    // 50ms timer for smooth radar/GPS animation repaint
    _animationTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted) return;
      final state = Provider.of<AppState>(context, listen: false);
      final status = state.activeTrip?.status.toLowerCase();
      if (status == 'new' || status == 'pending') {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshActiveTrip() async {
    final state = Provider.of<AppState>(context, listen: false);
    final active = state.activeTrip;
    if (active == null || active.id == null) return;

    if (mounted) setState(() => _isRefreshing = true);

    try {
      final trips = await ApiService.fetchCustomerTrips(active.phoneNumber);
      final updated =
          trips.firstWhere((t) => t.id == active.id, orElse: () => active);
      state.setActiveTrip(updated);
    } catch (_) {
      // Fail silently
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Widget _buildHorizontalProgressBar(String status, bool isDark, String lang) {
    final steps = [
      lang == 'vi' ? 'Đang ghép' : 'Connecting',
      lang == 'vi' ? 'Đang đón' : 'En route',
      lang == 'vi' ? 'Di chuyển' : 'On trip',
      lang == 'vi' ? 'Đến nơi' : 'Arrived',
    ];

    int currentStepIndex = 0;
    switch (status.toLowerCase()) {
      case 'new':
      case 'pending':
        currentStepIndex = 0;
        break;
      case 'confirmed':
      case 'assigned':
        currentStepIndex = 1;
        break;
      case 'on_trip':
        currentStepIndex = 2;
        break;
      case 'completed':
      case 'arrived':
        currentStepIndex = 3;
        break;
    }

    return Column(
      children: [
        Row(
          children: List.generate(4, (index) {
            final isDone = index <= currentStepIndex;
            final color = isDone ? AppColors.brandGreen : (isDark ? AppColors.hairlineDark : AppColors.hairline);

            return Expanded(
              child: Row(
                children: [
                  Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone ? AppColors.brandGreen : Colors.transparent,
                      border: Border.all(color: color, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: isDone
                        ? const Icon(Icons.check, size: 12, color: Colors.white)
                        : null,
                  ),
                  if (index < 3)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: index < currentStepIndex
                            ? AppColors.brandGreen
                            : (isDark ? AppColors.hairlineDark : AppColors.hairline),
                      ),
                    ),
                ],
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(4, (index) {
            final isCurrent = index == currentStepIndex;
            final isDone = index <= currentStepIndex;
            return Expanded(
              child: Text(
                steps[index],
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                  color: isCurrent
                      ? AppColors.brandGreen
                      : (isDone ? AppColors.ink_(isDark) : AppColors.stone_(isDark)),
                ),
                textAlign: TextAlign.start,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final isDark = state.isDarkTheme;
    final lang   = state.language;
    final trip   = state.activeTrip;
    final fmt    = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

    return Scaffold(
      backgroundColor: AppColors.surface_(isDark),
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          lang == 'vi' ? 'Theo dõi hành trình' : 'Track your ride',
          style: AppText.heading5.copyWith(color: AppColors.ink_(isDark)),
        ),
        backgroundColor: AppColors.card_(isDark),
        foregroundColor: AppColors.ink_(isDark),
        actions: [
          if (trip != null)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.md),
              child: _isRefreshing
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.brandGreen,
                      ),
                    )
                  : IconButton(
                      icon: Icon(Icons.refresh_rounded,
                          size: 20, color: AppColors.steel_(isDark)),
                      onPressed: _refreshActiveTrip,
                    ),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.hairline_(isDark)),
        ),
      ),
      body: trip == null
          ? _buildEmptyState(context, isDark, lang, state)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Trip Info Header Card ─────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: cardDecoration(isDark),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '#${(trip.id?.length ?? 0) > 6 ? trip.id!.substring(trip.id!.length - 6).toUpperCase() : (trip.id ?? "OMIGO").toUpperCase()}',
                              style: AppText.codeSm.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.brandGreen,
                              ),
                            ),
                            statusBadge(trip.status, lang),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Divider(height: 1, color: AppColors.hairline_(isDark)),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Icon(Icons.location_on_rounded,
                                color: AppColors.brandGreen, size: 16),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                '${trip.pickupSpecificPoint}, ${trip.origin}',
                                style: AppText.bodySmMedium.copyWith(
                                  color: AppColors.ink_(isDark),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          children: [
                            Icon(Icons.flag_rounded,
                                color: AppColors.brandError, size: 16),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                '${trip.dropoffSpecificPoint}, ${trip.destination}',
                                style: AppText.bodySmMedium.copyWith(
                                  color: AppColors.ink_(isDark),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Divider(height: 1, color: AppColors.hairline_(isDark)),
                        const SizedBox(height: AppSpacing.xs),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              fmt.format(trip.appliedFixedPrice),
                              style: AppText.codeMd.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink_(isDark),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm, vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.brandGreen.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(AppRadius.full),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.access_time_rounded,
                                      size: 12, color: AppColors.brandGreen),
                                  const SizedBox(width: 4),
                                  Text(
                                    lang == 'vi' ? 'ETA ~25 phút' : 'ETA ~25 min',
                                    style: AppText.captionBold.copyWith(
                                      color: AppColors.brandGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // ── Map Simulation ─────────────────────────────────────────
                  Container(
                    height: 220,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF0B121F)
                          : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(
                        color: isDark
                            ? AppColors.hairlineDark
                            : const Color(0xFFDBEAFE),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        CustomPaint(
                          size: const Size(double.infinity, 220),
                          painter: MapRoutePainter(
                            isDark: isDark,
                            progress: state.simProgress,
                            driverLat: state.driverLat,
                            driverLng: state.driverLng,
                            origin: trip.origin,
                            destination: trip.destination,
                            status: trip.status,
                          ),
                        ),
                        Positioned(
                          left: AppSpacing.sm,
                          top: AppSpacing.sm,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              borderRadius: BorderRadius.circular(AppRadius.xs),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6, height: 6,
                                  decoration: const BoxDecoration(
                                    color: AppColors.brandGreen,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'GPS LIVE',
                                  style: AppText.captionBold.copyWith(
                                    color: AppColors.canvas,
                                    fontSize: 10,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // ── Status Timeline Card ───────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: cardDecoration(isDark),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lang == 'vi' ? 'Trạng thái hành trình' : 'Trip status',
                          style: AppText.bodySmMedium.copyWith(
                            color: AppColors.steel_(isDark),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (state.simStatusText.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            state.simStatusText,
                            style: AppText.bodySmMedium.copyWith(
                              color: AppColors.brandGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        _buildHorizontalProgressBar(trip.status, isDark, lang),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // ── Driver Card — shows if assigned/on_trip/completed ──────
                  if (trip.assignedDriverName != null) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: cardDecoration(isDark, radius: AppRadius.lg, featured: true),
                      child: Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.brandGreen, width: 2),
                            ),
                            child: CircleAvatar(
                              radius: 22,
                              backgroundColor: AppColors.brandGreenSoft,
                              child: Text(
                                trip.assignedDriverName![0].toUpperCase(),
                                style: const TextStyle(
                                  color: AppColors.brandGreenDeep,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      trip.assignedDriverName!,
                                      style: AppText.bodySmMedium.copyWith(
                                        color: AppColors.ink_(isDark),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.star_rounded, size: 10, color: Colors.amber),
                                          SizedBox(width: 2),
                                          Text(
                                            '4.8',
                                            style: TextStyle(
                                              fontFamily: 'Inter',
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.amber,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  trip.assignedVehicleType != null
                                      ? '${trip.assignedVehicleType} • BKS: ${trip.assignedLicensePlate ?? "N/A"}'
                                      : (lang == 'vi' ? 'Toyota Vios • BKS: 92A-123.45' : 'Toyota Vios • Plate: 92A-123.45'),
                                  style: AppText.caption.copyWith(color: AppColors.steel_(isDark)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(lang == 'vi' ? 'Đang mở hộp thoại chat...' : 'Opening chat...'),
                                    ),
                                  );
                                },
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.surfaceDark : AppColors.surfaceSoft,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.hairline_(isDark)),
                                  ),
                                  child: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.brandGreen, size: 18),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => _showCallDialog(context, state, trip.assignedDriverName!),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: AppColors.brandGreen,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.brandGreen.withValues(alpha: 0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.phone_in_talk_rounded, color: Colors.white, size: 18),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // ── Cancel — only for new/confirmed ───────────────────────
                  if (trip.status == 'new' || trip.status == 'confirmed' || trip.status == 'assigned') ...[
                    OutlinedButton(
                      onPressed: () => _showCancelDialog(context, state, lang),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.brandError,
                        side: BorderSide(
                          color: AppColors.brandError.withValues(alpha: 0.5),
                        ),
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      child: Text(
                        lang == 'vi' ? 'Hủy yêu cầu đặt xe' : 'Cancel Booking',
                        style: AppText.buttonMd.copyWith(
                          color: AppColors.brandError,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],

                  // ── Finish & Rate — for completed trips ───────────────────
                  if (trip.status == 'completed') ...[
                    ElevatedButton(
                      onPressed: () => _showRatingDialog(context, state, lang),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brandGreen,
                        foregroundColor: AppColors.ink,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      child: Text(
                        lang == 'vi' ? 'Hoàn tất & Đánh giá' : 'Finish & Rate',
                        style: AppText.buttonMd.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildEmptyState(
      BuildContext context, bool isDark, String lang, AppState state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.brandGreenSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.map_outlined,
                size: 56,
                color: isDark ? AppColors.brandGreen : AppColors.brandGreenDeep,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              lang == 'vi'
                  ? 'Không có chuyến đang hoạt động'
                  : 'No active trip',
              textAlign: TextAlign.center,
              style: AppText.heading5.copyWith(color: AppColors.ink_(isDark)),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              lang == 'vi'
                  ? 'Đặt chuyến xe mới ở tab Trang chủ và theo dõi tại đây.'
                  : 'Book a new ride on Home tab and track it here.',
              textAlign: TextAlign.center,
              style: AppText.bodySm.copyWith(
                color: AppColors.steel_(isDark),
                height: 1.6,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: 200,
              child: ElevatedButton(
                onPressed: () => state.setSelectedTabIndex(0),
                child: Text(
                  lang == 'vi' ? 'Đặt xe ngay' : 'Book a Ride',
                  style: AppText.buttonMd,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCallDialog(BuildContext context, AppState state, String driverName) {
    final isDark = state.isDarkTheme;
    final lang = state.language;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card_(isDark),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(
          lang == 'vi' ? 'Gọi tài xế' : 'Call Driver',
          style: AppText.heading5.copyWith(color: AppColors.ink_(isDark)),
        ),
        content: Text(
          lang == 'vi'
              ? 'Hệ thống sẽ kết nối cuộc gọi đến tài xế $driverName.'
              : 'The system will connect a call to driver $driverName.',
          style: AppText.bodySm.copyWith(color: AppColors.steel_(isDark)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(lang == 'vi' ? 'Hủy' : 'Cancel',
                style: AppText.bodySmMedium.copyWith(color: AppColors.steel)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    lang == 'vi'
                        ? 'Đang kết nối cuộc gọi...'
                        : 'Connecting call...',
                  ),
                ),
              );
            },
            child: Text(
              lang == 'vi' ? 'Gọi ngay' : 'Call Now',
              style: AppText.bodySmMedium.copyWith(color: AppColors.brandGreen),
            ),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(BuildContext context, AppState state, String lang) {
    final isDark = state.isDarkTheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card_(isDark),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(
          lang == 'vi' ? 'Hủy chuyến xe' : 'Cancel Trip',
          style: AppText.heading5.copyWith(color: AppColors.ink_(isDark)),
        ),
        content: Text(
          lang == 'vi'
              ? 'Bạn có chắc chắn muốn hủy yêu cầu đặt xe này?'
              : 'Are you sure you want to cancel this booking?',
          style: AppText.bodySm.copyWith(color: AppColors.steel_(isDark)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(lang == 'vi' ? 'Không' : 'No',
                style: AppText.bodySmMedium.copyWith(color: AppColors.steel)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              state.clearActiveTrip();
              Navigator.pop(context); // Close tracking screen as well
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    lang == 'vi'
                        ? 'Đã hủy chuyến đi thành công.'
                        : 'Booking cancelled successfully.',
                  ),
                ),
              );
            },
            child: Text(
              lang == 'vi' ? 'Hủy chuyến' : 'Cancel Trip',
              style: AppText.bodySmMedium.copyWith(color: AppColors.brandError),
            ),
          ),
        ],
      ),
    );
  }

  void _showRatingDialog(BuildContext context, AppState state, String lang) {
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
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.hairline_(isDark),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
              Text(
                lang == 'vi' ? 'Đánh giá chuyến đi' : 'Rate your ride',
                style: AppText.heading5.copyWith(color: AppColors.ink_(isDark)),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                lang == 'vi'
                    ? 'Ý kiến của bạn giúp chúng tôi cải thiện dịch vụ'
                    : 'Your feedback helps us improve',
                textAlign: TextAlign.center,
                style: AppText.caption.copyWith(color: AppColors.stone_(isDark)),
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) => IconButton(
                  icon: Icon(
                    i < rating ? Icons.star_rounded : Icons.star_border_rounded,
                    size: 44,
                    color: i < rating ? AppColors.brandGreen : AppColors.hairline_(isDark),
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
                  hintText: lang == 'vi'
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
                    state.clearActiveTrip();
                    Navigator.pop(context);
                    
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                        lang == 'vi'
                            ? 'Cảm ơn bạn đã hoàn tất và đánh giá chuyến đi!'
                            : 'Thank you for completing and rating your ride!',
                      ),
                      backgroundColor: AppColors.brandGreen,
                    ));
                  },
                  child: Text(
                    lang == 'vi' ? 'Gửi đánh giá & Hoàn tất' : 'Submit & Finish',
                    style: AppText.buttonMd.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// MapRoutePainter — premium live simulated GPS route map
// =============================================================================
class MapRoutePainter extends CustomPainter {
  final bool isDark;
  final double progress;
  final double driverLat;
  final double driverLng;
  final String origin;
  final String destination;
  final String status;

  MapRoutePainter({
    required this.isDark,
    required this.progress,
    required this.driverLat,
    required this.driverLng,
    required this.origin,
    required this.destination,
    required this.status,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw grid background lines
    final bgPaint = Paint()
      ..color = isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04)
      ..strokeWidth = 1
      ..style = PaintingStyle.fill;

    for (double i = 0; i < size.width; i += 28) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), bgPaint);
    }
    for (double j = 0; j < size.height; j += 28) {
      canvas.drawLine(Offset(0, j), Offset(size.width, j), bgPaint);
    }

    // 2. Draw city features (River & Parks & Cross Streets) to make it look like a professional map
    final riverPaint = Paint()
      ..color = isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFDCEBFF)
      ..strokeWidth = 16
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final riverPath = Path();
    riverPath.moveTo(-20, size.height * 0.4);
    riverPath.cubicTo(
      size.width * 0.3, size.height * 0.25,
      size.width * 0.65, size.height * 0.65,
      size.width + 20, size.height * 0.5,
    );
    canvas.drawPath(riverPath, riverPaint);

    final parkPaint = Paint()
      ..color = isDark ? const Color(0xFF065F46).withValues(alpha: 0.2) : const Color(0xFFE2F0D9)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.1, size.height * 0.1, 75, 40),
        const Radius.circular(6),
      ),
      parkPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.68, size.height * 0.7, 85, 30),
        const Radius.circular(6),
      ),
      parkPaint,
    );

    final cityRoadPaint = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;
    
    canvas.drawLine(Offset(0, size.height * 0.75), Offset(size.width, size.height * 0.2), cityRoadPaint);
    canvas.drawLine(Offset(size.width * 0.25, 0), Offset(size.width * 0.25, size.height), cityRoadPaint);
    canvas.drawLine(Offset(0, size.height * 0.8), Offset(size.width, size.height * 0.8), cityRoadPaint);

    // 3. Define coordinates mapping on screen coordinates
    final offsetA = Offset(50, size.height - 50);
    final offsetB = Offset(size.width - 50, 45);

    final pathPaint = Paint()
      ..color = isDark ? Colors.white24 : Colors.black12
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = const Color(0xFF00D4A4).withValues(alpha: 0.18)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final activePathPaint = Paint()
      ..color = const Color(0xFF00D4A4)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(offsetA.dx, offsetA.dy);
    path.cubicTo(
      size.width * 0.35,
      size.height * 0.90,
      size.width * 0.65,
      size.height * 0.15,
      offsetB.dx,
      offsetB.dy,
    );

    canvas.drawPath(path, pathPaint);
    canvas.drawPath(path, glowPaint);

    var driverOffset = offsetA;
    double vehicleAngle = math.atan2(-30.0, 40.0);
    
    final pathMetrics = path.computeMetrics();
    for (final metric in pathMetrics) {
      if (progress > 0.0) {
        final activeProgress = progress < 0.40
            ? 0.0
            : (progress - 0.40) / 0.60;
        
        if (activeProgress > 0.0) {
          final extractPath =
              metric.extractPath(0.0, metric.length * activeProgress);
          canvas.drawPath(extractPath, activePathPaint);
        }

        final tangent =
            metric.getTangentForOffset(metric.length * activeProgress);
        if (tangent != null) {
          driverOffset = tangent.position;
          if (progress >= 0.40) {
            vehicleAngle = tangent.angle;
          }
        }
      }
    }

    // 4. Draw radar waves if status is new/searching
    if (status == 'new' || status == 'pending') {
      final radarPaint = Paint()
        ..color = const Color(0xFF00D4A4).withValues(alpha: 0.12)
        ..style = PaintingStyle.fill;
      final radarOutline = Paint()
        ..color = const Color(0xFF00D4A4).withValues(alpha: 0.35)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      final time = DateTime.now().millisecondsSinceEpoch % 1500 / 1500.0;
      canvas.drawCircle(offsetA, 40 * time, radarPaint);
      canvas.drawCircle(offsetA, 40 * time, radarOutline);
    }

    // 5. Draw Route Pins
    final pinBorder = Paint()
      ..color = isDark ? Colors.white : Colors.black
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final pinInnerA = Paint()
      ..color = const Color(0xFF00D4A4)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(offsetA, 8, pinInnerA);
    canvas.drawCircle(offsetA, 8, pinBorder);
    canvas.drawCircle(offsetA, 3, Paint()..color = Colors.white..style = PaintingStyle.fill);

    final pinInnerB = Paint()
      ..color = const Color(0xFFEF4444)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(offsetB, 8, pinInnerB);
    canvas.drawCircle(offsetB, 8, pinBorder);
    canvas.drawCircle(offsetB, 3, Paint()..color = Colors.white..style = PaintingStyle.fill);

    // 6. Draw Moving Driver/Vehicle Indicator
    if (progress > 0.0) {
      canvas.save();
      canvas.translate(driverOffset.dx, driverOffset.dy);
      canvas.rotate(vehicleAngle);

      final vehiclePath = Path();
      vehiclePath.moveTo(9, 0);
      vehiclePath.lineTo(-7, -7);
      vehiclePath.lineTo(-4, 0);
      vehiclePath.lineTo(-7, 7);
      vehiclePath.close();

      final vehicleShadow = Paint()
        ..color = const Color(0xFF00D4A4).withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5)
        ..style = PaintingStyle.fill;
      canvas.drawPath(vehiclePath, vehicleShadow);

      final vehiclePaint = Paint()
        ..color = const Color(0xFF00D4A4)
        ..style = PaintingStyle.fill;
      final vehicleOutline = Paint()
        ..color = Colors.white
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      canvas.drawPath(vehiclePath, vehiclePaint);
      canvas.drawPath(vehiclePath, vehicleOutline);

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant MapRoutePainter old) =>
      old.progress != progress || old.isDark != isDark || old.status != status;
}
