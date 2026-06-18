import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/app_state.dart';
import '../services/api_service.dart';
import '../models/trip_request.dart';
import '../theme/app_theme.dart';
import 'booking_details_screen.dart';
import 'full_history_screen.dart';
import 'tracking_screen.dart';

class HistoryScreen extends StatefulWidget {
  final String? filterType; // 'rides', 'cargo', or null for all
  const HistoryScreen({Key? key, this.filterType}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<TripRequest> _recentTrips = [];
  bool _isLoading = true;
  String _errorMsg = '';
  String _selectedSegmentFilter = 'all';

  @override
  void initState() {
    super.initState();
    if (widget.filterType != null) {
      _selectedSegmentFilter = widget.filterType!;
    }
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final state = Provider.of<AppState>(context, listen: false);
    if (state.currentCustomer == null) return;

    setState(() {
      _isLoading = true;
      _errorMsg = '';
    });

    try {
      final list = await ApiService.fetchCustomerTrips(
        state.currentCustomer!.phoneNumber,
      );
      list.sort((a, b) =>
          b.requestedDepartureTime.compareTo(a.requestedDepartureTime));
      setState(() {
        _recentTrips = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMsg = state.language == 'vi'
            ? 'Lỗi tải lịch sử: $e'
            : 'Error loading history: $e';
        _isLoading = false;
      });
    }
  }

  void _rebookRide(TripRequest trip, AppState state) {
    state.setPrefillBooking(
      trip.pickupSpecificPoint,
      trip.dropoffSpecificPoint,
      trip.serviceType,
    );
    state.setSelectedTabIndex(0); // Go to Home tab
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final isDark = state.isDarkTheme;
    final lang = state.language;
    final fmt = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

    final displayTrips = _recentTrips.where((t) {
      if (_selectedSegmentFilter == 'rides') {
        return t.serviceType == 'xe-ghep' || t.serviceType == 'bao-xe';
      } else if (_selectedSegmentFilter == 'cargo') {
        return t.serviceType == 'gui-hang';
      }
      return true; // 'all'
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.canvas_(isDark),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Custom Mockup-style Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      lang == 'vi' ? 'Hoạt động' : 'Activities',
                      style: AppText.heading3.copyWith(
                        color: AppColors.ink_(isDark),
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.history_rounded,
                            size: 22, color: AppColors.steel_(isDark)),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const FullHistoryScreen()),
                          );
                        },
                        tooltip: lang == 'vi' ? 'Lịch sử' : 'History',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _buildSegmentControl(isDark, lang),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl, vertical: AppSpacing.sm),
              child: Text(
                lang == 'vi' ? 'Gần đây' : 'Recent',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink_(isDark),
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadHistory,
                color: AppColors.brandGreen,
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.brandGreen),
                      )
                    : _errorMsg.isNotEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height * 0.2),
                              Center(
                                child: Text(
                                  _errorMsg,
                                  style: AppText.bodySm
                                      .copyWith(color: AppColors.brandError),
                                ),
                              ),
                            ],
                          )
                        : displayTrips.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  SizedBox(
                                      height:
                                          MediaQuery.of(context).size.height *
                                              0.1),
                                  _buildEmptyState(isDark, lang, state),
                                ],
                              )
                            : ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.xl,
                                    vertical: AppSpacing.xs),
                                itemCount: displayTrips.length,
                                itemBuilder: (context, index) {
                                  final trip = displayTrips[index];
                                  return _TripCard(
                                    trip: trip,
                                    isDark: isDark,
                                    lang: lang,
                                    fmt: fmt,
                                    onTap: () {
                                      final s = trip.status.toLowerCase();
                                      final isActive = s != 'completed' &&
                                          s != 'cancelled' &&
                                          s != 'canceled';
                                      if (isActive) {
                                        state.setActiveTrip(trip);
                                        Navigator.of(context)
                                            .push(
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    const TrackingScreen(),
                                              ),
                                            )
                                            .then((_) => _loadHistory());
                                      } else {
                                        Navigator.of(context)
                                            .push(
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    BookingDetailsScreen(
                                                        trip: trip),
                                              ),
                                            )
                                            .then((_) => _loadHistory());
                                      }
                                    },
                                    onRebook: () => _rebookRide(trip, state),
                                    onRate:
                                        trip.status.toLowerCase() == 'completed'
                                            ? () => Navigator.of(context)
                                                .push(
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        BookingDetailsScreen(
                                                            trip: trip),
                                                  ),
                                                )
                                                .then((_) => _loadHistory())
                                            : null,
                                  );
                                },
                              ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentControl(bool isDark, String lang) {
    return Container(
      margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl, vertical: AppSpacing.md),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(
          color: AppColors.hairline_(isDark),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          _buildSegmentTab('all', lang == 'vi' ? 'Tất cả' : 'All', isDark),
          _buildSegmentTab(
              'rides', lang == 'vi' ? 'Chuyến đi' : 'Rides', isDark),
          _buildSegmentTab(
              'cargo', lang == 'vi' ? 'Đơn hàng' : 'Orders', isDark),
        ],
      ),
    );
  }

  Widget _buildSegmentTab(String filter, String label, bool isDark) {
    final isSelected = _selectedSegmentFilter == filter;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedSegmentFilter = filter;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.brandGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.full),
            boxShadow: isSelected && !isDark
                ? [
                    BoxShadow(
                      color: AppColors.brandGreen.withOpacity(0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppText.captionBold.copyWith(
              color: isSelected ? Colors.black : AppColors.steel_(isDark),
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, String lang, AppState state) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceCode : AppColors.surfaceSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              size: 36,
              color: isDark ? AppColors.brandGreen : AppColors.steel,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            lang == 'vi' ? 'Chưa có hoạt động nào' : 'No activities yet',
            style: AppText.bodySmMedium.copyWith(color: AppColors.ink_(isDark)),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            lang == 'vi'
                ? 'Đặt chuyến đi hoặc gửi đơn hàng đầu tiên của bạn ngay!'
                : 'Book a ride or start a cargo delivery now!',
            textAlign: TextAlign.center,
            style: AppText.caption.copyWith(color: AppColors.steel_(isDark)),
          ),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: 160,
            child: ElevatedButton(
              onPressed: () => state.setSelectedTabIndex(0),
              child: Text(
                lang == 'vi' ? 'Đặt xe ngay' : 'Book A Car',
                style: AppText.buttonMd,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SHARED TRIP CARD WIDGET — used by both HistoryScreen & FullHistoryScreen
// =============================================================================
class _TripCard extends StatelessWidget {
  final TripRequest trip;
  final bool isDark;
  final String lang;
  final NumberFormat fmt;
  final VoidCallback onTap;
  final VoidCallback onRebook;
  final VoidCallback? onRate;

  const _TripCard({
    required this.trip,
    required this.isDark,
    required this.lang,
    required this.fmt,
    required this.onTap,
    required this.onRebook,
    this.onRate,
  });

  @override
  Widget build(BuildContext context) {
    final s = trip.status.toLowerCase();
    final isVi = lang == 'vi';

    // Status text and color mapping
    String statusLabel = '';
    Color statusColor = AppColors.brandGreenDeep;

    if (s == 'new' || s == 'pending' || s == 'searching') {
      statusLabel = isVi ? 'Đang tìm tài xế' : 'Looking for a driver';
      statusColor = const Color(0xFF3B82F6); // Blue
    } else if (s == 'confirmed' || s == 'assigned') {
      statusLabel = isVi ? 'Đã lên lịch' : 'Scheduled';
      statusColor = AppColors.testimonialOrange; // Orange
    } else if (s == 'on_trip') {
      statusLabel = isVi ? 'Đang di chuyển' : 'On trip';
      statusColor = const Color(0xFF8B5CF6); // Purple
    } else if (s == 'completed') {
      statusLabel = isVi ? 'Đã hoàn thành' : 'Completed';
      statusColor =
          isDark ? AppColors.brandGreen : const Color(0xFF10B981); // Green
    } else if (s == 'canceled') {
      statusLabel = isVi ? 'Đã hủy' : 'Canceled';
      statusColor = AppColors.brandError; // Red
    } else {
      statusLabel = trip.status;
      statusColor = AppColors.brandGreenDeep;
    }

    final svc = serviceInfo(trip.serviceType, lang);
    final isCompleted = s == 'completed';
    final isCanceled = s == 'canceled';

    final pickupText = trip.pickupSpecificPoint.isNotEmpty
        ? trip.pickupSpecificPoint
        : trip.origin;
    final dropoffText = trip.dropoffSpecificPoint.isNotEmpty
        ? trip.dropoffSpecificPoint
        : trip.destination;
    final routeText = '$pickupText → $dropoffText';
    final dateText =
        '${trip.requestedDepartureTime.split(' ').first}  ·  ${svc.label}';
    final priceText = fmt.format(trip.appliedFixedPrice);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12.0),
        decoration: cardDecoration(isDark, radius: AppRadius.lg),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status text at the top
            Text(
              statusLabel,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
            const SizedBox(height: 12),

            // Icon + Route + Price Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color:
                        isDark ? AppColors.surfaceCode : AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Image.asset(
                      trip.serviceType == 'bao-xe'
                          ? 'assets/images/3d_car_premium_black.png'
                          : (trip.serviceType == 'gui-hang'
                              ? 'assets/images/3d_box_red.png'
                              : 'assets/images/3d_car_yellow.png'),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    routeText,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink_(isDark),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  priceText,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink_(isDark),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Time & Date
            Text(
              dateText,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: AppColors.steel_(isDark),
              ),
            ),

            // CTA Button if needed
            if (isCanceled || isCompleted) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (isCompleted && onRate != null) ...[
                    GestureDetector(
                      onTap: onRate,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isVi ? 'Đánh giá' : 'Rate',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.brandGreenDeep,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: AppColors.brandGreenDeep,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.star_rounded,
                              size: 8,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  GestureDetector(
                    onTap: onRebook,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isVi ? 'Đặt lại' : 'Rebook',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.brandGreenDeep,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: AppColors.brandGreenDeep,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.refresh_rounded,
                            size: 8,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Export the shared card for FullHistoryScreen
class TripCard extends _TripCard {
  const TripCard({
    required super.trip,
    required super.isDark,
    required super.lang,
    required super.fmt,
    required super.onTap,
    required super.onRebook,
    super.onRate,
    Key? key,
  });
}
