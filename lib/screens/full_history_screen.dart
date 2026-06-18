import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/app_state.dart';
import '../services/api_service.dart';
import '../models/trip_request.dart';
import '../theme/app_theme.dart';
import 'booking_details_screen.dart';
import 'history_screen.dart' show TripCard;
import 'tracking_screen.dart';

class FullHistoryScreen extends StatefulWidget {
  const FullHistoryScreen({Key? key}) : super(key: key);

  @override
  State<FullHistoryScreen> createState() => _FullHistoryScreenState();
}

class _FullHistoryScreenState extends State<FullHistoryScreen> {
  List<TripRequest> _allTrips = [];
  bool _isLoading = true;
  String _errorMsg = '';

  @override
  void initState() {
    super.initState();
    _loadAllTrips();
  }

  Future<void> _loadAllTrips() async {
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
        _allTrips = list;
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
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final isDark = state.isDarkTheme;
    final lang = state.language;
    final fmt = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

    return Scaffold(
      backgroundColor: AppColors.surface_(isDark),
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          lang == 'vi' ? 'Lịch sử chuyến đi' : 'Ride History',
          style: AppText.heading5.copyWith(color: AppColors.ink_(isDark)),
        ),
        backgroundColor: AppColors.card_(isDark),
        foregroundColor: AppColors.ink_(isDark),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.hairline_(isDark)),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAllTrips,
        color: AppColors.brandGreen,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.brandGreen),
              )
            : _errorMsg.isNotEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.3,
                      ),
                      Center(
                        child: Text(
                          _errorMsg,
                          style: AppText.bodySm.copyWith(
                            color: AppColors.brandError,
                          ),
                        ),
                      ),
                    ],
                  )
                : _allTrips.isEmpty
                    ? _buildEmptyState(isDark, lang, state)
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        itemCount: _allTrips.length + 1,
                        itemBuilder: (ctx, idx) {
                          if (idx == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.sm,
                              ),
                              child: sectionLabel(
                                lang == 'vi'
                                    ? '${_allTrips.length} chuyến đi'
                                    : '${_allTrips.length} trips',
                                isDark,
                              ),
                            );
                          }
                          final trip = _allTrips[idx - 1];
                          return TripCard(
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
                                        builder: (_) => const TrackingScreen(),
                                      ),
                                    )
                                    .then((_) => _loadAllTrips());
                              } else {
                                Navigator.of(context)
                                    .push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            BookingDetailsScreen(trip: trip),
                                      ),
                                    )
                                    .then((_) => _loadAllTrips());
                              }
                            },
                            onRebook: () => _rebookRide(trip, state),
                            onRate: trip.status.toLowerCase() == 'completed'
                                ? () => Navigator.of(context)
                                    .push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            BookingDetailsScreen(trip: trip),
                                      ),
                                    )
                                    .then((_) => _loadAllTrips())
                                : null,
                          );
                        },
                      ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, String lang, AppState state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceSoft,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.hairline_(isDark)),
              ),
              child: Icon(
                Icons.history_rounded,
                size: 44,
                color: isDark ? AppColors.steel : AppColors.muted,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              lang == 'vi' ? 'Chưa có chuyến đi nào' : 'No trips yet',
              style: AppText.heading5.copyWith(color: AppColors.ink_(isDark)),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              lang == 'vi'
                  ? 'Hãy đặt chuyến xe đầu tiên của bạn!'
                  : 'Book your first ride!',
              textAlign: TextAlign.center,
              style: AppText.bodySm.copyWith(color: AppColors.steel_(isDark)),
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: 180,
              child: ElevatedButton(
                onPressed: () {
                  state.setSelectedTabIndex(0);
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: Text(
                  lang == 'vi' ? 'Đặt xe ngay' : 'Book A Car',
                  style: AppText.buttonMd,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
