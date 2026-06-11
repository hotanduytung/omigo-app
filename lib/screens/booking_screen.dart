import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/app_state.dart';
import '../services/api_service.dart';
import '../models/trip_config.dart';
import '../models/trip_request.dart';
import '../theme/app_theme.dart';
import 'tracking_screen.dart';

// Helper coordinate mapping for live map simulation
const _coordsMap = {
  'Tam Kỳ': [15.5736, 108.4740],
  'Đà Nẵng': [16.0544, 108.2022],
  'Hội An': [15.8794, 108.3350],
  'Huế': [16.4637, 107.5909],
};

class BookingScreen extends StatefulWidget {
  const BookingScreen({Key? key}) : super(key: key);

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _pickupController = TextEditingController();
  final _dropoffController = TextEditingController();
  final _feedbackController = TextEditingController();

  List<TripConfig> _configs = [];
  bool _isLoadingConfigs = true;
  String _errorMsg = '';

  // Form selections
  // Form selections
  String _serviceType = 'xe-ghep'; // xe-ghep, bao-xe, gui-hang
  int _bookingStep = 1;
  int _selectedVehicleClass = 0; // 0: Standard, 1: Premium
  TripConfig? _selectedConfig;
  TripTimeSlot? _selectedTimeSlot;
  int _seats = 1;
  DateTime _departureDate = DateTime.now();
  TimeOfDay _departureTime = TimeOfDay.now();

  // Navigation controller for promo banners PageView
  late PageController _bannerController;
  int _bannerIndex = 0;
  Timer? _bannerTimer;

  bool _showBookingForm = false;
  bool _showFullTracking = false;

  // Review state
  int _selectedRating = 5;
  int _selectedTipIndex = 0; // 0: None, 1: 15k, 2: 30k, 3: 50k, 4: Custom
  final double _customTipAmount = 0.0;


  @override
  void initState() {
    super.initState();
    _loadConfigs();
    _pickupController.addListener(_onLocationFieldsChanged);
    _dropoffController.addListener(_onLocationFieldsChanged);
    _bannerController = PageController(initialPage: 0);
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_bannerController.hasClients) {
        setState(() {
          _bannerIndex = (_bannerIndex + 1) % 2;
          _bannerController.animateToPage(
            _bannerIndex,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _pickupController.removeListener(_onLocationFieldsChanged);
    _dropoffController.removeListener(_onLocationFieldsChanged);
    _pickupController.dispose();
    _dropoffController.dispose();
    _feedbackController.dispose();
    _bannerController.dispose();
    _bannerTimer?.cancel();
    super.dispose();
  }

  void _onLocationFieldsChanged() {
    setState(() {});
  }

  void _syncDepartureTimeFromSlot() {
    if (_selectedTimeSlot != null) {
      final parts = _selectedTimeSlot!.departureTime.split(':');
      if (parts.length >= 2) {
        final hour = int.tryParse(parts[0]) ?? 7;
        final minute = int.tryParse(parts[1]) ?? 0;
        _departureTime = TimeOfDay(hour: hour, minute: minute);
      }
    }
  }

  String _formatDateText(DateTime date, bool isVi) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final checkDate = DateTime(date.year, date.month, date.day);

    if (checkDate.isAtSameMomentAs(today)) {
      return isVi ? 'Hôm nay' : 'Today';
    } else if (checkDate.isAtSameMomentAs(tomorrow)) {
      return isVi ? 'Ngày mai' : 'Tomorrow';
    } else {
      return DateFormat('dd/MM/yyyy').format(date);
    }
  }

  void _showTimeSelectionBottomSheet(BuildContext context, bool isDark, bool isVi) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.hairlineDark : AppColors.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isVi ? 'Chọn giờ đi' : 'Select Departure Hour',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink_(isDark),
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 2.0,
                    ),
                    itemCount: 24,
                    itemBuilder: (context, index) {
                      final hour = index;
                      final timeOfDay = TimeOfDay(hour: hour, minute: 0);
                      final timeString = '${hour.toString().padLeft(2, '0')}:00';
                      final isSelected = _departureTime.hour == hour && _departureTime.minute == 0;

                      return InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          setState(() {
                            _departureTime = timeOfDay;
                            double basePrice = 90000.0;
                            if (_selectedConfig != null && _selectedConfig!.timeSlots.isNotEmpty) {
                              basePrice = _selectedConfig!.timeSlots.first.fixedPrice;
                            }
                            _selectedTimeSlot = TripTimeSlot(
                              departureTime: timeString,
                              arrivalTime: '${((hour + 2) % 24).toString().padLeft(2, '0')}:00',
                              fixedPrice: basePrice,
                              status: 'active',
                            );
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.brandGreenDeep
                                : (isDark ? AppColors.surfaceCode : const Color(0xFFF3F4F6)),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.brandGreenDeep
                                  : (isDark ? AppColors.hairlineDark : AppColors.hairline),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            timeString,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected
                                  ? Colors.black
                                  : AppColors.ink_(isDark),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Future<void> _loadConfigs() async {
    try {
      final configs = await ApiService.fetchTripConfigs();
      setState(() {
        _configs = configs.where((c) => c.status == 'active').toList();
        if (_configs.isNotEmpty) {
          _selectedConfig = _configs.first;
          final activeSlots =
              _selectedConfig!.timeSlots.where((s) => s.status == 'active').toList();
          if (activeSlots.isNotEmpty) {
            _selectedTimeSlot = activeSlots.first;
            _syncDepartureTimeFromSlot();
          }
        }
        _isLoadingConfigs = false;
      });
    } catch (e) {
      setState(() {
        _errorMsg = 'Lỗi tải cấu hình tuyến: $e';
        _isLoadingConfigs = false;
      });
    }
  }


  void _swapLocations() {
    if (_selectedConfig == null) return;
    final reverse = _configs.firstWhere(
      (c) =>
          c.origin.trim().toLowerCase() ==
              _selectedConfig!.destination.trim().toLowerCase() &&
          c.destination.trim().toLowerCase() ==
              _selectedConfig!.origin.trim().toLowerCase(),
      orElse: () => _selectedConfig!,
    );

    setState(() {
      _selectedConfig = reverse;
      final activeSlots =
          _selectedConfig!.timeSlots.where((s) => s.status == 'active').toList();
      _selectedTimeSlot = activeSlots.isNotEmpty ? activeSlots.first : null;

      final temp = _pickupController.text;
      _pickupController.text = _dropoffController.text;
      _dropoffController.text = temp;
    });
  }

  double _calculatePrice() {
    if (_selectedTimeSlot == null) return 0.0;
    double base = _selectedTimeSlot!.fixedPrice;
    if (_serviceType == 'xe-ghep') {
      return base * _seats;
    } else if (_serviceType == 'bao-xe') {
      return base * 4.0;
    } else {
      return base * 0.6; // Cargo package is 60% of base
    }
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _departureDate.isBefore(today) ? today : _departureDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF00D4A4),
              onPrimary: Colors.black,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _departureDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isVi = Provider.of<AppState>(context, listen: false).language == 'vi';
    _showTimeSelectionBottomSheet(context, isDark, isVi);
  }

  void _submitBooking(AppState state) async {
    final lang = state.language;
    if (_selectedConfig == null || _selectedTimeSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(lang == 'vi'
                ? 'Vui lòng chọn tuyến đường và khung giờ hợp lệ'
                : 'Please select a valid route and time slot')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final customer = state.currentCustomer;
    if (customer == null) return;

    final departureDT = DateTime(
      _departureDate.year,
      _departureDate.month,
      _departureDate.day,
      _departureTime.hour,
      _departureTime.minute,
    );

    final formattedTime =
        DateFormat('yyyy-MM-dd HH:mm:ss').format(departureDT);
    final basePrice = _calculatePrice();
    final finalPrice = basePrice * (_selectedVehicleClass == 0 ? 1.0 : (_serviceType == 'gui-hang' ? 2.5 : 1.4));

    final req = TripRequest(
      userName: customer.name,
      phoneNumber: customer.phoneNumber,
      pickupSpecificPoint: _pickupController.text.trim(),
      dropoffSpecificPoint: _dropoffController.text.trim(),
      requestedSeatCount: _seats,
      origin: _selectedConfig!.origin,
      destination: _selectedConfig!.destination,
      requestedDepartureTime: formattedTime,
      source: 'app',
      bookingSource: 'web',
      serviceType: _serviceType,
      createdByType: 'user',
      appliedFixedPrice: finalPrice,
      status: 'new',
      matchedTripConfigId: _selectedConfig!.id,
    );

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(lang == 'vi'
                ? 'Đang gửi yêu cầu đặt xe...'
                : 'Submitting booking request...'),
            duration: const Duration(seconds: 1)),
      );
      final created = await ApiService.createTripRequest(req);
      state.setActiveTrip(created);

      setState(() {
        _showBookingForm = false;
      });

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.brandGreen),
              const SizedBox(width: 8),
              Text(
                  lang == 'vi' ? 'Đặt xe thành công' : 'Booking Successful',
                  style: const TextStyle(
                      fontFamily: 'Inter', fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            lang == 'vi'
                ? 'Hệ thống đã nhận yêu cầu của bạn từ ${_selectedConfig!.origin} đi ${_selectedConfig!.destination}. Hãy nhấn OK để bắt đầu theo dõi trực tiếp hành trình!'
                : 'The system has received your request from ${_selectedConfig!.origin} to ${_selectedConfig!.destination}. Tap OK to start live tracking your journey!',
            style: const TextStyle(fontFamily: 'Inter', height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TrackingScreen()),
                );
              },
              child: Text(
                'OK',
                style: TextStyle(
                  color: state.isDarkTheme
                      ? AppColors.brandGreen
                      : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(lang == 'vi' ? 'Đặt xe thất bại: $e' : 'Booking failed: $e'),
            backgroundColor: Colors.redAccent),
      );
    }
  }

  // ─── View 1: Home Dashboard ────────────────────────────────────────────────
  // ─── View 1: Home Dashboard ────────────────────────────────────────────────
  Widget _buildHomeDashboard(
      bool isDark, NumberFormat currencyFormat, AppState state) {
    final customer = state.currentCustomer;
    final lang = state.language;

    return SafeArea(
      top: true,
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            // Profile Welcome Header Block
            GestureDetector(
              onDoubleTap: () {
                final mockTrip = TripRequest(
                  id: 'mock_trip_123',
                  userName: customer?.name ?? 'Văn Định',
                  phoneNumber: customer?.phoneNumber ?? '0901234567',
                  pickupSpecificPoint: 'Coopmart Tam Kỳ',
                  dropoffSpecificPoint: 'Sân bay Đà Nẵng',
                  requestedSeatCount: 1,
                  origin: 'Tam Kỳ',
                  destination: 'Đà Nẵng',
                  requestedDepartureTime: '08:00',
                  source: 'app',
                  bookingSource: 'web',
                  serviceType: 'xe-ghep',
                  createdByType: 'user',
                  appliedFixedPrice: 150000,
                  status: 'confirmed',
                  assignedDriverName: 'Nguyễn Văn Hùng',
                  assignedDriverId: 'driver_hung_123',
                );
                state.setActiveTrip(mockTrip);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(lang == 'vi' ? 'Đã kích hoạt chuyến xe giả lập!' : 'Mock trip activated!'),
                    backgroundColor: AppColors.brandGreen,
                  ),
                );
              },
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: const NetworkImage(
                      'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150',
                    ),
                    backgroundColor: isDark ? AppColors.surfaceCode : Colors.grey[200],
                    child: null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          lang == 'vi' ? 'Xin chào 👋' : 'Hello 👋',
                          style: AppText.caption.copyWith(
                            color: AppColors.steel_(isDark),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          customer?.name != null && customer!.name.isNotEmpty
                              ? customer.name
                              : (lang == 'vi' ? 'Văn Định' : 'Van Dinh'),
                          style: AppText.heading4.copyWith(
                            color: AppColors.ink_(isDark),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Notification Bell with green dot
                  Stack(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.notifications_none_rounded,
                          size: 26,
                          color: AppColors.ink_(isDark),
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                lang == 'vi'
                                    ? 'Bạn không có thông báo mới.'
                                    : 'You have no new notifications.',
                              ),
                              backgroundColor: AppColors.brandGreen,
                            ),
                          );
                        },
                      ),
                      Positioned(
                        right: 12,
                        top: 12,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.brandGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Capsule Search Bar
            GestureDetector(
              onTap: () {
                setState(() {
                  _bookingStep = 1;
                  _showBookingForm = true;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(
                    color: AppColors.hairline_(isDark),
                    width: 1,
                  ),
                  boxShadow: isDark
                      ? []
                      : const [
                          BoxShadow(
                            color: Color(0x06000000),
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      lang == 'vi' ? 'Tìm kiếm tại đây...' : 'Search here',
                      style: AppText.bodyMd.copyWith(
                        color: AppColors.stone_(isDark),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    Icon(
                      Icons.search_rounded,
                      color: AppColors.stone_(isDark),
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
            if (state.activeTrip != null) ...[
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const TrackingScreen()),
                  );
                },
                child: _buildHomeActiveTripTracker(isDark, lang, state.activeTrip!, state),
              ),
            ],
            const SizedBox(height: 24),

            // Row of 3 core service cards
            Row(
              children: [
                _buildPremiumServiceCard(
                  title: lang == 'vi' ? 'Đặt xe' : 'Rides',
                  icon: Icons.directions_car_filled_rounded,
                  iconColor: const Color(0xFFEAB308),
                  iconBgColor: const Color(0xFFFEF9C3),
                  isSelected: _serviceType == 'xe-ghep',
                  onTap: () {
                    setState(() {
                      _serviceType = 'xe-ghep';
                      _seats = 1;
                      _bookingStep = 1;
                      _showBookingForm = true;
                    });
                  },
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildPremiumServiceCard(
                  title: lang == 'vi' ? 'Bao xe' : 'Private',
                  icon: Icons.local_taxi_rounded,
                  iconColor: const Color(0xFF0284C7),
                  iconBgColor: const Color(0xFFE0F2FE),
                  isSelected: _serviceType == 'bao-xe',
                  onTap: () {
                    setState(() {
                      _serviceType = 'bao-xe';
                      _seats = 4;
                      _bookingStep = 1;
                      _showBookingForm = true;
                    });
                  },
                  isDark: isDark,
                ),
                const SizedBox(width: 8),
                _buildPremiumServiceCard(
                  title: lang == 'vi' ? 'Giao hàng' : 'Box',
                  icon: Icons.inventory_2_rounded,
                  iconColor: const Color(0xFFDC2626),
                  iconBgColor: const Color(0xFFFEE2E2),
                  isSelected: _serviceType == 'gui-hang',
                  onTap: () {
                    setState(() {
                      _serviceType = 'gui-hang';
                      _seats = 1;
                      _bookingStep = 1;
                      _showBookingForm = true;
                    });
                  },
                  isDark: isDark,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Promo Banner (no wallet balance section)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.brandGreen,
                borderRadius: BorderRadius.circular(16),
                boxShadow: isDark
                    ? []
                    : [
                        BoxShadow(
                          color: AppColors.brandGreen.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang == 'vi' ? 'Khuyến mãi Omigo' : 'Omigo Promotion',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFFD1FAE5),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lang == 'vi' ? 'Đồng giá ghép xe chỉ từ 80k/ghế' : 'Shared rides starting at \$ 8.00',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.confirmation_num_rounded, color: Colors.white, size: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Recent Trips Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  lang == 'vi' ? 'Gần đây' : 'Recent',
                  style: AppText.bodyMdMedium.copyWith(
                    color: AppColors.ink_(isDark),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    state.setSelectedTabIndex(1); // Navigate to Trips Tab
                  },
                  child: Text(
                    lang == 'vi' ? 'Xem tất cả' : 'See all',
                    style: AppText.captionBold.copyWith(
                      color: AppColors.brandGreenDeep,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Recent Trip Card with Dotted Timeline
            _buildRecentTripCard(isDark, lang),
            const SizedBox(height: 20),

            // Promotional Banner
            _buildPromoBanner(isDark, lang),
            const SizedBox(height: 20),

            // Guide Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  lang == 'vi' ? 'Cẩm nang' : 'Guides',
                  style: AppText.bodyMdMedium.copyWith(
                    color: AppColors.ink_(isDark),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  lang == 'vi' ? 'Xem tất cả' : 'See all',
                  style: AppText.captionBold.copyWith(
                    color: AppColors.brandGreenDeep,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Horizontal guides list
            SizedBox(
              height: 170,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildHorizontalGuideCard(
                    lang == 'vi'
                        ? 'Mẹo hành lý xe ghép'
                        : 'Shared ride packing tips',
                    lang == 'vi' ? '5 phút đọc' : '5 min read',
                    const Color(0xFF0EA5E9),
                    Icons.wallet_travel_rounded,
                    isDark,
                  ),
                  _buildHorizontalGuideCard(
                    lang == 'vi'
                        ? 'Quy trình đưa đón'
                        : 'Pickup & dropoff guide',
                    lang == 'vi' ? '3 phút đọc' : '3 min read',
                    const Color(0xFF10B981),
                    Icons.map_rounded,
                    isDark,
                  ),
                  _buildHorizontalGuideCard(
                    lang == 'vi'
                        ? 'Chính sách an toàn'
                        : 'Safety policy',
                    lang == 'vi' ? '4 phút đọc' : '4 min read',
                    const Color(0xFFF59E0B),
                    Icons.verified_user_rounded,
                    isDark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumServiceCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    bool isSelected = false,
    bool isDarkBg = false,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 96,
          decoration: BoxDecoration(
            color: isDarkBg 
                ? (isDark ? const Color(0xFF1E293B) : const Color(0xFF1E293B))
                : (isDark ? AppColors.surfaceDark : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected 
                  ? AppColors.brandGreen 
                  : (isDarkBg ? Colors.transparent : AppColors.hairline_(isDark)),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDarkBg 
                      ? Colors.white 
                      : (isDark ? Colors.white70 : Colors.black87),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeActiveTripTracker(bool isDark, String lang, TripRequest trip, AppState state) {
    final s = trip.status.toLowerCase();
    final simProgress = state.simProgress;
    
    String displayTime = trip.requestedDepartureTime;
    if (displayTime.contains(' ')) {
      displayTime = displayTime.split(' ').last;
    }
    final timeParts = displayTime.split(':');
    if (timeParts.length >= 2) {
      displayTime = '${timeParts[0]}:${timeParts[1]}';
    }
    
    // Status titles & subtitles
    String statusTitle = '';
    String statusSubtitle = '';
    
    final driverName = trip.assignedDriverName ?? 'Nguyễn Văn Hùng';
    final vehicleInfo = trip.assignedVehicleType != null
        ? '${trip.assignedVehicleType} (${trip.assignedLicensePlate ?? "N/A"})'
        : 'Toyota Camry mui cam (92A-1310)';
    final defaultSubtitle = lang == 'vi'
        ? 'Xe $vehicleInfo • $driverName'
        : '$vehicleInfo • $driverName';
    
    if (s == 'new' || s == 'pending') {
      statusTitle = lang == 'vi' ? 'Đang tìm tài xế...' : 'Finding driver...';
      statusSubtitle = lang == 'vi' ? 'Hệ thống đang ghép xe cho bạn' : 'We are matching you with a driver';
    } else if (s == 'confirmed' || s == 'assigned') {
      int mins = 3;
      if (simProgress >= 0.15 && simProgress < 0.30) {
        mins = 2;
      } else if (simProgress >= 0.30) {
        mins = 1;
      }
      
      statusTitle = lang == 'vi' 
          ? 'Tài xế đến sau $mins phút' 
          : 'Arrives in $mins minute${mins > 1 ? "s" : ""}';
      statusSubtitle = defaultSubtitle;
    } else if (s == 'on_trip') {
      double remainingFrac = 1.0 - simProgress;
      int mins = (remainingFrac * 15).clamp(1, 15).toInt();
      
      statusTitle = lang == 'vi'
          ? 'Đang trên xe • Đến sau $mins phút'
          : 'On trip • Arrives in $mins mins';
      statusSubtitle = defaultSubtitle;
    } else if (s == 'completed') {
      statusTitle = lang == 'vi' ? 'Đã đến nơi an toàn' : 'Arrived safely';
      statusSubtitle = lang == 'vi' ? 'Cảm ơn bạn đã di chuyển cùng Omigo' : 'Thank you for riding with Omigo';
    } else {
      statusTitle = lang == 'vi' ? 'Trạng thái chuyến xe' : 'Trip Status';
      statusSubtitle = defaultSubtitle;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1F21), // Very dark slate/black card (mockup dark style)
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusTitle,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      statusSubtitle,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: Color(0xFFA1A1AA), // Zinc 400
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white54,
                size: 14,
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Custom Timeline Progress Tracker
          LayoutBuilder(
            builder: (context, constraints) {
              final totalWidth = constraints.maxWidth;
              final startX = 16.0;
              final endX = totalWidth - 16.0;
              final trackWidth = endX - startX;
              
              // Map progress to X coordinate
              final carX = startX + trackWidth * simProgress.clamp(0.05, 0.95);
              
              return SizedBox(
                height: 48,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // 1. Dark green background track (remaining path)
                    Positioned(
                      left: startX,
                      width: trackWidth,
                      top: 16,
                      height: 16,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F5A47), // Dark dull teal/green
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    // 2. Bright progress track (completed path)
                    Positioned(
                      left: startX,
                      width: carX - startX,
                      top: 16,
                      height: 16,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF13B58C), // Bright emerald teal
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    // 3. Origin Node (Pin)
                    Positioned(
                      left: startX - 16,
                      top: 8,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Color(0xFF0F172A),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.location_on_rounded,
                          color: Color(0xFF13B58C),
                          size: 16,
                        ),
                      ),
                    ),
                    // 4. Food Waypoint Node
                    Positioned(
                      left: (startX + trackWidth * 0.35) - 16,
                      top: 8,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          '🍔',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    // 5. Destination Node (Home)
                    Positioned(
                      left: endX - 16,
                      top: 8,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Color(0xFF0F172A),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.home_rounded,
                          color: Color(0xFF13B58C),
                          size: 16,
                        ),
                      ),
                    ),
                    // 6. Yellow Car Node (Current position)
                    Positioned(
                      left: carX - 16,
                      top: 8,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Color(0xFF13B58C),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.directions_car_filled_rounded,
                          color: Color(0xFFFACC15), // Vibrant yellow
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          // --- Live Pickup Time Section (iOS 26 premium dashboard) ---
          const Divider(color: Colors.white24, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFFFACC15)),
              const SizedBox(width: 6),
              Text(
                lang == 'vi'
                    ? 'Đón lúc: $displayTime'
                    : 'Pickup: $displayTime',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          if (s == 'completed') ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () {
                  _showRatingDialogDirect(context, state, lang);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text(
                  lang == 'vi' ? 'ĐÁNH GIÁ CHUYẾN XE' : 'RATE RIDE',
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showRatingDialogDirect(BuildContext context, AppState state, String lang) {
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
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            top: 24,
            left: 24,
            right: 24,
          ),
          decoration: BoxDecoration(
            color: AppColors.card_(isDark),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AppColors.hairline_(isDark)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.hairline_(isDark),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Text(
                lang == 'vi' ? 'Đánh giá chuyến đi' : 'Rate your ride',
                style: AppText.heading5.copyWith(color: AppColors.ink_(isDark), fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                lang == 'vi'
                    ? 'Ý kiến của bạn giúp chúng tôi cải thiện dịch vụ'
                    : 'Your feedback helps us improve',
                textAlign: TextAlign.center,
                style: AppText.caption.copyWith(color: AppColors.stone_(isDark)),
              ),
              const SizedBox(height: 24),
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
              const SizedBox(height: 16),
              TextField(
                controller: commentController,
                maxLines: 3,
                style: AppText.bodySm.copyWith(color: AppColors.ink_(isDark)),
                decoration: InputDecoration(
                  hintText: lang == 'vi'
                      ? 'Nhập phản hồi của bạn...'
                      : 'Write your feedback...',
                  hintStyle: TextStyle(color: AppColors.stone_(isDark)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  filled: true,
                  fillColor: isDark ? AppColors.surfaceCode : AppColors.surfaceSoft,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    state.clearActiveTrip();
                    
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                        lang == 'vi'
                            ? 'Cảm ơn bạn đã hoàn tất và đánh giá chuyến đi!'
                            : 'Thank you for completing and rating your ride!',
                      ),
                      backgroundColor: AppColors.brandGreen,
                    ));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    lang == 'vi' ? 'Gửi đánh giá & Hoàn tất' : 'Submit & Finish',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentTripCard(bool isDark, String lang) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(isDark, radius: AppRadius.lg),
      child: Row(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    const SizedBox(height: 6),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.brandGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: 2,
                      height: 24,
                      child: CustomPaint(
                        painter: _VerticalDottedLinePainter(
                          color: AppColors.stone_(isDark),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.location_on_rounded,
                      color: Colors.grey[400],
                      size: 14,
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Coopmart Tam Kỳ',
                        style: AppText.bodySmMedium.copyWith(
                          color: AppColors.ink_(isDark),
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Sân bay Đà Nẵng',
                        style: AppText.bodySmMedium.copyWith(
                          color: AppColors.ink_(isDark),
                          fontWeight: FontWeight.w600,
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
          TextButton(
            onPressed: () {
              setState(() {
                _pickupController.text = 'Coopmart Tam Kỳ';
                _dropoffController.text = 'Sân bay Đà Nẵng';
                _serviceType = 'xe-ghep';
                _bookingStep = 1;
                _showBookingForm = true;
              });
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              backgroundColor: AppColors.brandGreenSoft,
              shape: const StadiumBorder(),
            ),
            child: Text(
              lang == 'vi' ? 'Đặt lại' : 'Rebook',
              style: AppText.captionBold.copyWith(
                color: AppColors.brandGreenDeep,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoBanner(bool isDark, String lang) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF006C52),
            Color(0xFF00A278),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: isDark
            ? []
            : const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 12,
                  offset: Offset(0, 6),
                ),
              ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -15,
            bottom: -15,
            child: Opacity(
              opacity: 0.15,
              child: const Icon(
                Icons.location_city_rounded,
                size: 100,
                color: Colors.white,
              ),
            ),
          ),
          Positioned(
            right: 20,
            top: 5,
            child: Opacity(
              opacity: 0.12,
              child: const Icon(
                Icons.route_rounded,
                size: 60,
                color: Colors.white,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        lang == 'vi' ? 'Tiết kiệm tới' : 'Save up to',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 1),
                      const Text(
                        '40%',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _serviceType = 'xe-ghep';
                            _bookingStep = 1;
                            _showBookingForm = true;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF006C52),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          minimumSize: const Size(0, 28),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: const StadiumBorder(),
                          elevation: 0,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              lang == 'vi' ? 'Tìm chuyến ghép' : 'Find rides',
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right_rounded, size: 12),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Container(
                    alignment: Alignment.centerRight,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const Icon(
                          Icons.directions_car_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                        Positioned(
                          right: 2,
                          top: 2,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: AppColors.brandGreen,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.people_rounded,
                              size: 8,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCouponCard(bool isDark, String lang) {
    return Container(
      height: 104,
      decoration: cardDecoration(isDark, radius: AppRadius.lg),
      child: Row(
        children: [
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
          CustomPaint(
            size: const Size(1, double.infinity),
            painter: _DashedLinePainter(
              color: AppColors.hairline_(isDark),
            ),
          ),
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
                    lang == 'vi' ? 'Giảm 30K cho chuyến ghép' : '30K Off for Shared Ride',
                    style: AppText.bodySmMedium.copyWith(
                      color: AppColors.ink_(isDark),
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    lang == 'vi' ? 'Áp dụng cho đơn từ 120K' : 'Min spend 120K',
                    style: AppText.caption.copyWith(
                      color: AppColors.steel_(isDark),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'HSD: 30/06/2024',
                    style: AppText.caption.copyWith(
                      color: AppColors.stone_(isDark),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      lang == 'vi'
                          ? 'Đã áp dụng mã ưu đãi OMIGOSHARE30!'
                          : 'Applied code OMIGOSHARE30!',
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
  }

  void _showOffersBottomSheet(BuildContext context, bool isDark, String lang) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.canvas_(isDark),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppRadius.xl),
          topRight: Radius.circular(AppRadius.xl),
        ),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                lang == 'vi' ? 'Mã ưu đãi của bạn' : 'Your Coupon Codes',
                style: AppText.heading5.copyWith(color: AppColors.ink_(isDark)),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildCouponItem(
                      title: lang == 'vi' ? 'Giảm 30K cho chuyến ghép' : '30K Off for Shared Ride',
                      desc: lang == 'vi' ? 'Áp dụng cho đơn từ 120K' : 'Min spend 120K',
                      code: 'OMIGOSHARE30',
                      exp: '30/06/2024',
                      isDark: isDark,
                      lang: lang,
                    ),
                    _buildCouponItem(
                      title: lang == 'vi' ? 'Giảm 50K bao xe đường dài' : '50K Off for Private Car',
                      desc: lang == 'vi' ? 'Áp dụng cho chuyến trên 300K' : 'Min spend 300K',
                      code: 'OMIGOPRIVATE50',
                      exp: '15/07/2024',
                      isDark: isDark,
                      lang: lang,
                    ),
                    _buildCouponItem(
                      title: lang == 'vi' ? 'Miễn phí giao hàng chặng đầu' : 'Free Cargo Delivery First Ride',
                      desc: lang == 'vi' ? 'Tối đa 25K cho khách hàng mới' : 'Max discount 25K for new users',
                      code: 'OMIGODELIVERFREE',
                      exp: '31/08/2024',
                      isDark: isDark,
                      lang: lang,
                    ),
                    _buildCouponItem(
                      title: lang == 'vi' ? 'Giảm 10% tổng hóa đơn di chuyển' : '10% Off All Booking Bills',
                      desc: lang == 'vi' ? 'Áp dụng cho tất cả dịch vụ hè' : 'For all summer campaign rides',
                      code: 'OMIGOSUMMER10',
                      exp: '30/09/2024',
                      isDark: isDark,
                      lang: lang,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCouponItem({
    required String title,
    required String desc,
    required String code,
    required String exp,
    required bool isDark,
    required String lang,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      height: 104,
      decoration: cardDecoration(isDark, radius: AppRadius.lg),
      child: Row(
        children: [
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
          CustomPaint(
            size: const Size(1, double.infinity),
            painter: _DashedLinePainter(
              color: AppColors.hairline_(isDark),
            ),
          ),
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
                    title,
                    style: AppText.bodySmMedium.copyWith(
                      color: AppColors.ink_(isDark),
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    desc,
                    style: AppText.caption.copyWith(
                      color: AppColors.steel_(isDark),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${lang == 'vi' ? 'HSD' : 'EXP'}: $exp',
                    style: AppText.caption.copyWith(
                      color: AppColors.stone_(isDark),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      lang == 'vi'
                          ? 'Đã áp dụng mã ưu đãi $code!'
                          : 'Applied code $code!',
                    ),
                    backgroundColor: AppColors.brandGreen,
                  ),
                );
                Navigator.pop(context);
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
  }

  Widget _buildHorizontalGuideCard(
      String title, String meta, Color color, IconData icon, bool isDark) {
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.hairline_(isDark),
          width: 1,
        ),
        boxShadow: isDark
            ? []
            : const [
                BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 90,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.8), color],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppRadius.lg),
                topRight: Radius.circular(AppRadius.lg),
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -10,
                  bottom: -10,
                  child: Opacity(
                    opacity: 0.2,
                    child: Icon(
                      icon,
                      size: 80,
                      color: Colors.white,
                    ),
                  ),
                ),
                Center(
                  child: Icon(
                    icon,
                    size: 32,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: AppText.captionBold.copyWith(
                      color: AppColors.ink_(isDark),
                      fontSize: 12,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    meta,
                    style: AppText.microUppercase.copyWith(
                      color: AppColors.brandGreenDeep,
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildBookingFormSheet(
      bool isDark, NumberFormat currencyFormat, AppState state) {
    final lang = state.language;

    // Dynamic AppBar Title based on serviceType and language
    String appTitle = '';
    if (_serviceType == 'xe-ghep') {
      appTitle = lang == 'vi' ? 'ĐẶT CHUYẾN XE GHÉP' : 'BOOK SHARED RIDE';
    } else if (_serviceType == 'bao-xe') {
      appTitle = lang == 'vi' ? 'ĐẶT BAO NGUYÊN XE' : 'BOOK PRIVATE CAR';
    } else {
      appTitle = lang == 'vi' ? 'ĐẶT GỬI HÀNG HÓA' : 'BOOK PARCEL DELIVERY';
    }

    return Scaffold(
      backgroundColor: AppColors.canvas_(isDark),
      appBar: AppBar(
        title: Text(
          appTitle,
          style: AppText.heading5.copyWith(
            color: AppColors.ink_(isDark),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.ink_(isDark)),
          onPressed: () {
            if (_bookingStep > 1) {
              setState(() {
                _bookingStep--;
              });
            } else {
              setState(() {
                _showBookingForm = false;
              });
            }
          },
        ),
        backgroundColor: AppColors.canvas_(isDark),
        foregroundColor: AppColors.ink_(isDark),
        elevation: 0,
      ),
      body: _bookingStep == 4
          ? Stack(
              children: [
                // Background Map Canvas
                Positioned.fill(
                  child: CustomPaint(
                    painter: _MapRoutePainter(
                      isDark: isDark,
                      progress: 1.0,
                      driverLat: 15.5736,
                      driverLng: 108.4740,
                      origin: _selectedConfig?.origin ?? 'Tam Kỳ',
                      destination: _selectedConfig?.destination ?? 'Đà Nẵng',
                      status: 'confirmed',
                    ),
                  ),
                ),
                // Header stepper block overlaid at top
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: AppColors.canvas_(isDark).withOpacity(0.85),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildStepperHeader(_bookingStep, isDark, lang),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                ),
                // Floating Bottom Sheet overlaid at the bottom
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.canvas_(isDark),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 16,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      top: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // A small indicator bar for swipe/drag visual cue
                          Center(
                            child: Container(
                              width: 36,
                              height: 4,
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.hairlineDark : AppColors.hairline,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          _buildConfirmStep(isDark, lang, currencyFormat),
                          _buildBottomNavigationBar(isDark, lang, state),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Stepper Header
                _buildStepperHeader(_bookingStep, isDark, lang),
                const SizedBox(height: 4),

                // Service Switcher
                _buildServiceSwitcher(isDark, lang),
                const SizedBox(height: 4),

                // 2. Subtitle Section
                _buildStepSubtitle(_bookingStep, isDark, lang),

                // 3. Main Step Form content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_bookingStep == 1)
                            _buildRouteStep(isDark, lang)
                          else if (_bookingStep == 2)
                            _buildTimeStep(isDark, lang, currencyFormat)
                          else if (_bookingStep == 3)
                            _buildInfoStep(isDark, lang),

                          if (_bookingStep == 1)
                            _buildPopularRoutes(isDark, lang),

                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _bookingStep == 4 ? null : _buildBottomNavigationBar(isDark, lang, state),
    );
  }

  Widget _buildServiceSwitcher(bool isDark, String lang) {
    if (_bookingStep > 3) return const SizedBox.shrink();

    final isVi = lang == 'vi';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
      height: 42,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceCode : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(21),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          Expanded(
            child: _buildServiceTab('xe-ghep', isVi ? 'Đặt Ghế' : 'Share Ride', isDark),
          ),
          Expanded(
            child: _buildServiceTab('bao-xe', isVi ? 'Bao Xe' : 'Private Car', isDark),
          ),
          Expanded(
            child: _buildServiceTab('gui-hang', isVi ? 'Giao Hàng' : 'Delivery', isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceTab(String type, String label, bool isDark) {
    final isSelected = _serviceType == type;
    return GestureDetector(
      onTap: () {
        if (_serviceType == type) return;
        setState(() {
          _serviceType = type;
          if (type == 'bao-xe' || type == 'gui-hang') {
            _seats = 1;
          }
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.brandGreenDeep : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          boxShadow: isSelected && !isDark
              ? [
                  const BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  )
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected
                ? (isDark ? Colors.black : AppColors.ink)
                : AppColors.steel_(isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildStepperHeader(int currentStep, bool isDark, String lang) {
    return Container(
      color: AppColors.canvas_(isDark),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Stack(
        children: [
          // Background connecting lines positioned vertically aligned with center of circles
          Positioned(
            top: 15, // 32/2 - 1
            left: 0,
            right: 0,
            child: Row(
              children: [
                const Spacer(flex: 1),
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 2,
                    color: currentStep > 1
                        ? AppColors.brandGreen
                        : (isDark ? AppColors.hairlineDark : AppColors.hairline),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 2,
                    color: currentStep > 2
                        ? AppColors.brandGreen
                        : (isDark ? AppColors.hairlineDark : AppColors.hairline),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Container(
                    height: 2,
                    color: currentStep > 3
                        ? AppColors.brandGreen
                        : (isDark ? AppColors.hairlineDark : AppColors.hairline),
                  ),
                ),
                const Spacer(flex: 1),
              ],
            ),
          ),
          // Foreground step nodes
          Row(
            children: [
              Expanded(child: _buildStepNode(1, currentStep, 'Lộ trình', 'Route', isDark, lang)),
              Expanded(child: _buildStepNode(2, currentStep, 'Thời gian', 'Time', isDark, lang)),
              Expanded(child: _buildStepNode(3, currentStep, 'Thông tin', 'Info', isDark, lang)),
              Expanded(child: _buildStepNode(4, currentStep, 'Xác nhận', 'Confirm', isDark, lang)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepNode(
    int stepNum,
    int currentStep,
    String labelVi,
    String labelEn,
    bool isDark,
    String lang,
  ) {
    final isActive = stepNum == currentStep;
    final isCompleted = stepNum < currentStep;
    final label = lang == 'vi' ? labelVi : labelEn;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted
                ? AppColors.brandGreen
                : (isActive ? AppColors.brandGreen : (isDark ? AppColors.surfaceCode : Colors.white)),
            border: Border.all(
              color: (isCompleted || isActive)
                  ? AppColors.brandGreen
                  : (isDark ? AppColors.hairlineDark : AppColors.hairline),
              width: 2,
            ),
          ),
          child: Center(
            child: isCompleted
                ? const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 16,
                  )
                : Text(
                    '$stepNum',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isActive ? Colors.white : AppColors.steel_(isDark),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive
                ? (isDark ? AppColors.brandGreen : AppColors.brandGreenDeep)
                : AppColors.steel_(isDark),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildStepSubtitle(int step, bool isDark, String lang) {
    String title = '';
    String subtitle = '';
    final isVi = lang == 'vi';

    if (_serviceType == 'gui-hang') {
      if (step == 1) {
        title = isVi ? 'Chọn lộ trình giao hàng' : 'Choose delivery route';
        subtitle = isVi ? 'Nhập địa chỉ gửi và nhận hàng' : 'Enter sender and recipient addresses';
      } else if (step == 2) {
        title = isVi ? 'Chọn thời gian gửi hàng' : 'Choose delivery time';
        subtitle = isVi ? 'Chọn ngày và giờ bàn giao hàng' : 'Select dispatch date and time';
      } else if (step == 3) {
        title = isVi ? 'Nhập thông tin hàng hóa' : 'Enter parcel details';
        subtitle = isVi ? 'Điền thông tin hàng hóa và người nhận' : 'Fill parcel and recipient details';
      } else {
        title = isVi ? 'Xác nhận đơn hàng' : 'Confirm delivery details';
        subtitle = isVi ? 'Kiểm tra lại thông tin trước khi gửi hàng' : 'Review details before dispatching';
      }
    } else if (_serviceType == 'bao-xe') {
      if (step == 1) {
        title = isVi ? 'Chọn lộ trình bao xe' : 'Choose private route';
        subtitle = isVi ? 'Nhập địa chỉ đón và trả tận nơi' : 'Enter custom pickup and dropoff locations';
      } else if (step == 2) {
        title = isVi ? 'Chọn thời gian khởi hành' : 'Choose departure time';
        subtitle = isVi ? 'Chọn ngày và giờ đi riêng biệt' : 'Select private departure date and time';
      } else if (step == 3) {
        title = isVi ? 'Nhập thông tin bao xe' : 'Enter private details';
        subtitle = isVi ? 'Điền thông tin ghi chú đón trả' : 'Fill in notes for custom pickup';
      } else {
        title = isVi ? 'Xác nhận bao xe' : 'Confirm private ride';
        subtitle = isVi ? 'Kiểm tra lại thông tin chuyến đi riêng' : 'Review your private trip details';
      }
    } else {
      if (step == 1) {
        title = isVi ? 'Chọn lộ trình của bạn' : 'Choose your route';
        subtitle = isVi ? 'Nhập điểm đón và điểm đến' : 'Enter pickup and dropoff locations';
      } else if (step == 2) {
        title = isVi ? 'Chọn thời gian phù hợp' : 'Choose departure time';
        subtitle = isVi ? 'Chọn ngày và giờ khởi hành' : 'Select departure date and time';
      } else if (step == 3) {
        title = isVi ? 'Nhập thông tin chuyến đi' : 'Enter trip details';
        subtitle = isVi ? 'Điền thông tin để tìm chuyến phù hợp' : 'Fill details to find a matching ride';
      } else {
        title = isVi ? 'Xác nhận thông tin' : 'Confirm details';
        subtitle = isVi ? 'Kiểm tra lại thông tin trước khi đặt chuyến' : 'Review your trip details before booking';
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.ink_(isDark),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: AppColors.steel_(isDark),
            ),
          ),
        ],
      ),
    );
  }

  void _showRouteSelectionBottomSheet(BuildContext context, bool isDark, bool isVi) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.hairlineDark : AppColors.hairline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isVi ? 'Chọn tuyến đường' : 'Select Route',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink_(isDark),
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _configs.length,
                  itemBuilder: (context, index) {
                    final config = _configs[index];
                    final isSelected = _selectedConfig?.id == config.id ||
                        (_selectedConfig?.origin == config.origin &&
                            _selectedConfig?.destination == config.destination);
                    return ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                      title: Text(
                        '${config.origin} ↔ ${config.destination}',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected
                              ? AppColors.brandGreenDeep
                              : AppColors.ink_(isDark),
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check,
                              color: AppColors.brandGreenDeep, size: 20)
                          : null,
                      onTap: () {
                        Navigator.pop(context);
                        setState(() {
                          _selectedConfig = config;
                          final activeSlots = _selectedConfig!.timeSlots
                              .where((s) => s.status == 'active')
                              .toList();
                          _selectedTimeSlot =
                              activeSlots.isNotEmpty ? activeSlots.first : null;
                          _pickupController.clear();
                          _dropoffController.clear();
                        });
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRouteStep(bool isDark, String lang) {
    final isVi = lang == 'vi';
    final pickupLabel = _serviceType == 'gui-hang'
        ? (isVi ? 'Địa chỉ gửi' : 'Sender Address')
        : (isVi ? 'Địa chỉ đón' : 'Pickup Address');
    final dropoffLabel = _serviceType == 'gui-hang'
        ? (isVi ? 'Địa chỉ nhận' : 'Recipient Address')
        : (isVi ? 'Địa chỉ trả' : 'Dropoff Address');

    final originCity = _selectedConfig?.origin ?? (isVi ? 'điểm đi' : 'origin');
    final destCity = _selectedConfig?.destination ?? (isVi ? 'điểm đến' : 'destination');

    final pickupHint = _serviceType == 'gui-hang'
        ? (isVi ? 'Gửi từ $originCity' : 'Send from $originCity')
        : (isVi ? 'Đón tại $originCity' : 'Pickup in $originCity');
    final dropoffHint = _serviceType == 'gui-hang'
        ? (isVi ? 'Giao tại $destCity' : 'Deliver to $destCity')
        : (isVi ? 'Trả tại $destCity' : 'Dropoff in $destCity');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      padding: const EdgeInsets.all(16.0),
      decoration: cardDecoration(isDark, radius: AppRadius.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TUYẾN ĐƯỜNG Selector
          Text(
            (isVi ? 'Tuyến đường' : 'Route').toUpperCase(),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.steel_(isDark),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: () => _showRouteSelectionBottomSheet(context, isDark, isVi),
            borderRadius: BorderRadius.circular(9999),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceCode : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(9999),
                border: Border.all(
                  color: isDark ? AppColors.hairlineDark : AppColors.hairline,
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedConfig != null
                          ? '${_selectedConfig!.origin} ↔ ${_selectedConfig!.destination}'
                          : (isVi ? 'Chọn tuyến đường...' : 'Select route...'),
                      style: AppText.bodySmMedium.copyWith(
                        color: _selectedConfig != null
                            ? AppColors.ink_(isDark)
                            : (isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF)),
                      ),
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down,
                    color: AppColors.steel_(isDark),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Side-by-side Pickup and Dropoff Address Inputs
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pickup Field
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pickupLabel.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.steel_(isDark),
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceCode : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(9999),
                        border: Border.all(
                          color: isDark ? AppColors.hairlineDark : AppColors.hairline,
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.centerLeft,
                      child: TextFormField(
                        controller: _pickupController,
                        style: AppText.bodySmMedium.copyWith(color: AppColors.ink_(isDark)),
                        decoration: InputDecoration(
                          hintText: pickupHint,
                          hintStyle: TextStyle(
                            color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                            fontSize: 13,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Swap Button Column
              Column(
                children: [
                  Opacity(
                    opacity: 0,
                    child: Text(
                      pickupLabel.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 48,
                    alignment: Alignment.center,
                    child: GestureDetector(
                      onTap: _swapLocations,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surfaceCode : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? AppColors.hairlineDark : AppColors.hairline,
                            width: 1,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0A000000),
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.swap_horiz,
                          color: AppColors.brandGreenDeep,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              // Dropoff Field
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dropoffLabel.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.steel_(isDark),
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceCode : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(9999),
                        border: Border.all(
                          color: isDark ? AppColors.hairlineDark : AppColors.hairline,
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.centerLeft,
                      child: TextFormField(
                        controller: _dropoffController,
                        style: AppText.bodySmMedium.copyWith(color: AppColors.ink_(isDark)),
                        decoration: InputDecoration(
                          hintText: dropoffHint,
                          hintStyle: TextStyle(
                            color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                            fontSize: 13,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPopularRoutes(bool isDark, String lang) {
    if (_configs.isEmpty) return const SizedBox.shrink();
    if (_pickupController.text.trim().isNotEmpty &&
        _dropoffController.text.trim().isNotEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang == 'vi' ? 'Gợi ý tuyến phổ biến' : 'Suggested popular routes',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.ink_(isDark),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: cardDecoration(isDark, radius: AppRadius.lg),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: math.min(_configs.length, 3),
              separatorBuilder: (context, index) => Divider(
                color: isDark ? AppColors.hairlineDark : AppColors.hairline,
                height: 1,
              ),
              itemBuilder: (context, index) {
                final config = _configs[index];
                final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
                final basePrice = config.timeSlots.isNotEmpty
                    ? config.timeSlots.first.fixedPrice
                    : 90000.0;

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedConfig = config;
                      _pickupController.text = config.origin;
                      _dropoffController.text = config.destination;
                      final activeSlots = config.timeSlots
                          .where((s) => s.status == 'active')
                          .toList();
                      _selectedTimeSlot = activeSlots.isNotEmpty
                          ? activeSlots.first
                          : null;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.brandGreen.withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.trending_up,
                            color: AppColors.brandGreenDeep,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${config.origin} ➔ ${config.destination}',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink_(isDark),
                            ),
                          ),
                        ),
                        Text(
                          '${lang == 'vi' ? 'Từ' : 'From'} ${currencyFormat.format(basePrice)}',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            color: AppColors.steel_(isDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeStep(bool isDark, String lang, NumberFormat currencyFormat) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Date & Time pickers in a card
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          padding: const EdgeInsets.all(16.0),
          decoration: cardDecoration(isDark, radius: AppRadius.lg),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _selectDate,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.brandGreen.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.calendar_today_rounded,
                          color: AppColors.brandGreenDeep,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _serviceType == 'gui-hang'
                                  ? (lang == 'vi' ? 'Ngày gửi' : 'Dispatch Date')
                                  : (lang == 'vi' ? 'Ngày đi' : 'Departure Date'),
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                color: AppColors.steel_(isDark),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatDateText(_departureDate, lang == 'vi'),
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.ink_(isDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: isDark ? AppColors.hairlineDark : AppColors.hairline,
              ),
              Expanded(
                child: InkWell(
                  onTap: _selectTime,
                  child: Row(
                    children: [
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.brandGreen.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.access_time_rounded,
                          color: AppColors.brandGreenDeep,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _serviceType == 'gui-hang'
                                  ? (lang == 'vi' ? 'Giờ gửi' : 'Dispatch Time')
                                  : (lang == 'vi' ? 'Giờ đi' : 'Departure Time'),
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                color: AppColors.steel_(isDark),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _departureTime.format(context),
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.ink_(isDark),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Suggested time slots list
        if (_selectedConfig != null && _selectedConfig!.timeSlots.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Text(
              lang == 'vi' ? 'Khung giờ gợi ý' : 'Suggested time slots',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.ink_(isDark),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              children: _selectedConfig!.timeSlots
                  .where((s) => s.status == 'active')
                  .map((slot) {
                final isSelected = _selectedTimeSlot == slot;
                int remainingSeats = 4;
                if (slot.departureTime.contains('09:00')) {
                  remainingSeats = 3;
                } else if (slot.departureTime.contains('13:30')) {
                  remainingSeats = 5;
                } else if (slot.departureTime.contains('18:00')) {
                  remainingSeats = 2;
                }

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedTimeSlot = slot;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.brandGreen
                            : (isDark ? AppColors.hairlineDark : AppColors.hairline),
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isDark
                          ? []
                          : const [
                              BoxShadow(
                                color: Color(0x04000000),
                                blurRadius: 8,
                                offset: Offset(0, 3),
                              ),
                            ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.brandGreen
                                  : AppColors.stone_(isDark),
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: isSelected
                                ? Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: AppColors.brandGreen,
                                      shape: BoxShape.circle,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                slot.departureTime,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.ink_(isDark),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${lang == 'vi' ? 'Vé gốc:' : 'Base fare:'} ${currencyFormat.format(slot.fixedPrice)}',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  color: AppColors.steel_(isDark),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_serviceType == 'xe-ghep')
                          Text(
                            lang == 'vi' ? 'Còn $remainingSeats chỗ' : '$remainingSeats seats left',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: AppColors.steel_(isDark),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoStep(bool isDark, String lang) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_serviceType == 'xe-ghep') ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: cardDecoration(isDark, radius: AppRadius.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.people_alt_rounded,
                        color: AppColors.steel_(isDark),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        lang == 'vi' ? 'Số chỗ đăng ký ghép' : 'Seats count to book',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink_(isDark),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceCode : AppColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _seats > 1
                              ? () => setState(() => _seats--)
                              : null,
                          icon: const Icon(Icons.remove, size: 16),
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          padding: EdgeInsets.zero,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: Text(
                            '$_seats',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.ink_(isDark),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _seats < 8
                              ? () => setState(() => _seats++)
                              : null,
                          icon: const Icon(Icons.add, size: 16),
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          Container(
            padding: const EdgeInsets.all(16),
            decoration: cardDecoration(isDark, radius: AppRadius.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _serviceType == 'gui-hang'
                      ? (lang == 'vi'
                          ? 'Ghi chú gửi hàng (mô tả hàng hóa, SĐT người nhận...)'
                          : 'Delivery Note (parcel desc, recipient phone...)')
                      : (lang == 'vi'
                          ? 'Ghi chú cho tài xế (tuỳ chọn)'
                          : 'Driver Note (Optional)'),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.steel_(isDark),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _feedbackController,
                  maxLines: 3,
                  maxLength: 120,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: AppColors.ink_(isDark),
                  ),
                  decoration: InputDecoration(
                    hintText: _serviceType == 'gui-hang'
                        ? (lang == 'vi'
                            ? 'Ví dụ: Hàng dễ vỡ, SĐT nhận: 090xxx...'
                            : 'e.g., Fragile item, recipient phone: 090xxx...')
                        : (lang == 'vi'
                            ? 'Ví dụ: Tôi sẽ có mặt trước 10 phút...'
                            : 'e.g., I will be ready 10 mins early...'),
                    hintStyle: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: AppColors.stone_(isDark),
                    ),
                    counterText: "", // hide default character counter
                    filled: true,
                    fillColor: isDark ? AppColors.surfaceCode : AppColors.surfaceSoft,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  onChanged: (text) {
                    setState(() {});
                  },
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${_feedbackController.text.length}/120',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: AppColors.steel_(isDark),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF00382A) : const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: isDark ? const Color(0xFF005E46) : const Color(0xFFDCFCE7),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  color: isDark ? AppColors.brandGreen : Colors.green[700],
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _serviceType == 'gui-hang'
                        ? (lang == 'vi'
                            ? 'Cam kết: Giao nhận tận nơi, bảo quản cẩn thận & hủy miễn phí trước 1h'
                            : 'Commitment: Door-to-door, safe handling & 1h free cancellation')
                        : (_serviceType == 'bao-xe'
                            ? (lang == 'vi'
                                ? 'Cam kết: Bao xe riêng tư, đón trả tận nơi & hủy miễn phí trước 1h'
                                : 'Commitment: 100% private, door-to-door & 1h free cancellation')
                            : (lang == 'vi'
                                ? 'Cam kết: Đúng giờ ±15 phút & hủy miễn phí trước 1h'
                                : 'Commitment: Punctual ±15 mins & 1h free cancellation')),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.brandGreen : Colors.green[800],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildConfirmStep(bool isDark, String lang, NumberFormat currencyFormat) {
    final pickupText = _pickupController.text.isNotEmpty
        ? _pickupController.text
        : (_selectedConfig?.origin ?? '');
    final dropoffText = _dropoffController.text.isNotEmpty
        ? _dropoffController.text
        : (_selectedConfig?.destination ?? '');
    final dateText = _formatDateText(_departureDate, lang == 'vi');
    final timeText = _selectedTimeSlot?.departureTime ?? _departureTime.format(context);
    final basePrice = _selectedTimeSlot?.fixedPrice ?? 0.0;

    double standardPrice = 0.0;
    if (_serviceType == 'xe-ghep') {
      standardPrice = basePrice * _seats;
    } else if (_serviceType == 'bao-xe') {
      standardPrice = basePrice * 4.0;
    } else {
      standardPrice = basePrice * 0.6; // Cargo package is 60% of base
    }

    final double premiumPrice = standardPrice * (_serviceType == 'gui-hang' ? 2.5 : 1.4);
    final double selectedPrice = _selectedVehicleClass == 0 ? standardPrice : premiumPrice;

    final standardTitle = _serviceType == 'xe-ghep'
        ? (lang == 'vi' ? 'Xe Ghép Tiết Kiệm' : 'Economy Shared')
        : _serviceType == 'bao-xe'
            ? (lang == 'vi' ? 'Bao Xe 4 Chỗ' : 'Private Sedan')
            : (lang == 'vi' ? 'Giao Hàng Nhanh' : 'Instant Parcel');

    final premiumTitle = _serviceType == 'xe-ghep'
        ? (lang == 'vi' ? 'Xe Ghép Cao Cấp' : 'Premium Shared')
        : _serviceType == 'bao-xe'
            ? (lang == 'vi' ? 'Bao Xe 7 Chỗ' : 'Private SUV')
            : (lang == 'vi' ? 'Giao Hàng Xe Tải' : 'Cargo Truck');

    final standardSub = _serviceType == 'xe-ghep'
        ? (lang == 'vi' ? '4 phút · Xe 4 chỗ tiêu chuẩn' : '4 mins · Standard 4-seater')
        : _serviceType == 'bao-xe'
            ? (lang == 'vi' ? '4 phút · Sedan đời mới' : '4 mins · Modern Sedan')
            : (lang == 'vi' ? '3 phút · Giao bằng xe máy' : '3 mins · Motorcycle delivery');

    final premiumSub = _serviceType == 'xe-ghep'
        ? (lang == 'vi' ? '6 phút · Xe 7 chỗ rộng rãi' : '6 mins · Spacious 7-seater')
        : _serviceType == 'bao-xe'
            ? (lang == 'vi' ? '6 phút · SUV 7 chỗ lớn' : '6 mins · Large 7-seat SUV')
            : (lang == 'vi' ? '10 phút · Xe bán tải / xe tải' : '10 mins · Pickup / Truck');

    final standardIcon = _serviceType == 'xe-ghep'
        ? Icons.directions_car_rounded
        : _serviceType == 'bao-xe'
            ? Icons.directions_car_filled_rounded
            : Icons.motorcycle_rounded;

    final premiumIcon = _serviceType == 'xe-ghep'
        ? Icons.airport_shuttle_rounded
        : _serviceType == 'bao-xe'
            ? Icons.airport_shuttle_rounded
            : Icons.local_shipping_rounded;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Route simple indicator pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceCode : AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                Icon(Icons.location_on_rounded, color: AppColors.brandGreen, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$pickupText → $dropoffText',
                    style: AppText.bodySmMedium.copyWith(
                      color: AppColors.ink_(isDark),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$timeText · $dateText',
                  style: AppText.caption.copyWith(color: AppColors.steel_(isDark), fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Options Header Label
          Text(
            lang == 'vi' ? 'CHỌN LOẠI DỊCH VỤ' : 'CHOOSE VEHICLE CLASS',
            style: AppText.microUppercase.copyWith(color: AppColors.steel_(isDark)),
          ),
          const SizedBox(height: 8),

          // Option Card 1: Standard
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedVehicleClass = 0;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: cardDecoration(
                isDark,
                featured: _selectedVehicleClass == 0,
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.brandGreen.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(standardIcon, color: AppColors.brandGreenDeep, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          standardTitle,
                          style: AppText.bodySmMedium.copyWith(
                            color: AppColors.ink_(isDark),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          standardSub,
                          style: AppText.caption.copyWith(color: AppColors.steel_(isDark), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    currencyFormat.format(standardPrice),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: AppColors.ink_(isDark),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Option Card 2: Premium
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedVehicleClass = 1;
              });
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: cardDecoration(
                isDark,
                featured: _selectedVehicleClass == 1,
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.brandGreen.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(premiumIcon, color: AppColors.brandGreenDeep, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          premiumTitle,
                          style: AppText.bodySmMedium.copyWith(
                            color: AppColors.ink_(isDark),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          premiumSub,
                          style: AppText.caption.copyWith(color: AppColors.steel_(isDark), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    currencyFormat.format(premiumPrice),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: AppColors.ink_(isDark),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Payment Option Selector Pill (Behance Mockup style)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.hairline_(isDark)),
            ),
            child: Row(
              children: [
                const Icon(Icons.payment_rounded, color: AppColors.brandGreen, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    lang == 'vi' ? 'Tiền mặt / Ví điện tử' : 'Cash / E-Wallet',
                    style: AppText.captionBold.copyWith(color: AppColors.ink_(isDark)),
                  ),
                ),
                Icon(Icons.keyboard_arrow_right_rounded, color: AppColors.steel_(isDark), size: 18),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Pricing Summary Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF00382A) : const Color(0xFFF0FDF9),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: isDark ? const Color(0xFF005E46) : const Color(0xFFCCFBF1),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  lang == 'vi' ? 'Tổng tiền thanh toán' : 'Total payment',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink_(isDark),
                  ),
                ),
                Text(
                  currencyFormat.format(selectedPrice),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: isDark ? AppColors.brandGreen : AppColors.brandGreenDeep,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildBottomNavigationBar(bool isDark, String lang, AppState state) {
    final nextText = lang == 'vi' ? 'Tiếp tục' : 'Continue';
    final backText = lang == 'vi' ? 'Quay lại' : 'Back';
    final submitText = lang == 'vi' ? 'Đặt chuyến' : 'Book ride';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.canvas_(isDark),
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.hairlineDark : AppColors.hairline,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: _bookingStep == 1
            ? SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    if (_pickupController.text.trim().isEmpty ||
                        _dropoffController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            lang == 'vi'
                                ? 'Vui lòng điền điểm đón và điểm đến'
                                : 'Please fill pickup and destination locations',
                          ),
                          backgroundColor: AppColors.brandError,
                        ),
                      );
                      return;
                    }
                    setState(() {
                      _bookingStep = 2;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    shape: const StadiumBorder(),
                    backgroundColor: AppColors.brandGreen,
                    foregroundColor: Colors.white,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        nextText,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 16),
                    ],
                  ),
                ),
              )
            : Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _bookingStep--;
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          shape: const StadiumBorder(),
                          side: BorderSide(
                            color: isDark ? AppColors.hairlineDark : AppColors.hairline,
                            width: 1,
                          ),
                          foregroundColor: AppColors.ink_(isDark),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.arrow_back_rounded, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                backText,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 7,
                    child: SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          if (_bookingStep == 2) {
                            if (_selectedTimeSlot == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    lang == 'vi'
                                        ? 'Vui lòng chọn khung giờ di chuyển'
                                        : 'Please select a departure time slot',
                                  ),
                                  backgroundColor: AppColors.brandError,
                                ),
                              );
                              return;
                            }
                            setState(() {
                              _bookingStep = 3;
                            });
                          } else if (_bookingStep == 3) {
                            setState(() {
                              _bookingStep = 4;
                            });
                          } else if (_bookingStep == 4) {
                            _submitBooking(state);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          shape: const StadiumBorder(),
                          backgroundColor: AppColors.brandGreen,
                          foregroundColor: Colors.white,
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _bookingStep == 4 ? submitText : nextText,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                _bookingStep == 4 ? Icons.check_circle_outline_rounded : Icons.arrow_forward_rounded,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }




  // ─── Main build switch ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final isDark = state.isDarkTheme;
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

    // Default dashboard views
    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF090E17) : const Color(0xFFF9FAFB),
      appBar: null,
      body: _isLoadingConfigs
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.brandGreen))
          : _errorMsg.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(_errorMsg,
                        style: const TextStyle(color: AppColors.brandError)),
                  ),
                )
              : _showBookingForm
                  ? _buildBookingFormSheet(isDark, currencyFormat, state)
                  : _buildHomeDashboard(isDark, currencyFormat, state),
    );
  }



}




// ─── Custom Painter: Simulated Route & Moving Vehicle ───────────────────────
class _MapRoutePainter extends CustomPainter {
  final bool isDark;
  final double progress;
  final double driverLat;
  final double driverLng;
  final String origin;
  final String destination;
  final String status;

  _MapRoutePainter({
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
      ..color = isDark ? Colors.white10 : Colors.black.withOpacity(0.04)
      ..strokeWidth = 1
      ..style = PaintingStyle.fill;

    for (double i = 0; i < size.width; i += 28) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), bgPaint);
    }
    for (double j = 0; j < size.height; j += 28) {
      canvas.drawLine(Offset(0, j), Offset(size.width, j), bgPaint);
    }

    // 2. Draw city features (River & Parks & Cross Streets) to make it look like a professional map
    // Draw Con sông (River)
    final riverPaint = Paint()
      ..color = isDark ? const Color(0xFF1E3A8A).withOpacity(0.3) : const Color(0xFFDCEBFF)
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

    // Draw Parks (Mảng xanh)
    final parkPaint = Paint()
      ..color = isDark ? const Color(0xFF065F46).withOpacity(0.2) : const Color(0xFFE2F0D9)
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

    // Draw City Cross Streets (Đường phố)
    final cityRoadPaint = Paint()
      ..color = isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;
    
    // Diagonal road 1
    canvas.drawLine(Offset(0, size.height * 0.75), Offset(size.width, size.height * 0.2), cityRoadPaint);
    // Vertical road 2
    canvas.drawLine(Offset(size.width * 0.25, 0), Offset(size.width * 0.25, size.height), cityRoadPaint);
    // Horizontal road 3
    canvas.drawLine(Offset(0, size.height * 0.8), Offset(size.width, size.height * 0.8), cityRoadPaint);

    // 3. Define coordinates mapping on screen coordinates
    // Origin pin (A) starts around bottom-left, Destination pin (B) around top-right
    final offsetA = Offset(50, size.height - 50);
    final offsetB = Offset(size.width - 50, 45);

    // Curvy route line paint
    final pathPaint = Paint()
      ..color = isDark ? Colors.white24 : Colors.black12
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Glowing border for route line
    final glowPaint = Paint()
      ..color = const Color(0xFF00D4A4).withOpacity(0.18)
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
    // Draw a nice curvy road path
    path.cubicTo(
      size.width * 0.35,
      size.height * 0.90,
      size.width * 0.65,
      size.height * 0.15,
      offsetB.dx,
      offsetB.dy,
    );

    // Draw background paths
    canvas.drawPath(path, pathPaint);
    canvas.drawPath(path, glowPaint);

    // Calculate simulated driver offset position and rotation angle
    var driverOffset = offsetA;
    double vehicleAngle = math.atan2(-30.0, 40.0); // angle when approaching A
    
    final pathMetrics = path.computeMetrics();
    for (final metric in pathMetrics) {
      if (progress > 0.0) {
        // Extract the path the driver has already covered
        final activeProgress = progress < 0.40
            ? 0.0
            : (progress - 0.40) / 0.60; // progress from A to B
        
        if (activeProgress > 0.0) {
          final extractPath =
              metric.extractPath(0.0, metric.length * activeProgress);
          canvas.drawPath(extractPath, activePathPaint);
        }

        // Get exact vehicle offset coordinates on screen
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
        ..color = const Color(0xFF00D4A4).withOpacity(0.12)
        ..style = PaintingStyle.fill;
      final radarOutline = Paint()
        ..color = const Color(0xFF00D4A4).withOpacity(0.35)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;

      final time = DateTime.now().millisecondsSinceEpoch % 1500 / 1500.0;
      canvas.drawCircle(offsetA, 40 * time, radarPaint);
      canvas.drawCircle(offsetA, 40 * time, radarOutline);
    }

    // 5. Draw Route Pins
    // Origin Pin A (Green circle with center dot)
    final pinBorder = Paint()
      ..color = isDark ? Colors.white : Colors.black
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final pinA = Paint()
      ..color = const Color(0xFF00D4A4)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(offsetA, 8, pinA);
    canvas.drawCircle(offsetA, 8, pinBorder);
    canvas.drawCircle(offsetA, 3, Paint()..color = Colors.black);

    // Label A
    final textPainterA = TextPainter(
      text: const TextSpan(
        text: 'A',
        style: TextStyle(
            color: Color(0xFF00D4A4),
            fontSize: 10,
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter'),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    textPainterA.layout();
    textPainterA.paint(canvas, Offset(offsetA.dx - 4, offsetA.dy - 24));

    // Destination Pin B (Red circle with center dot)
    final pinB = Paint()
      ..color = Colors.redAccent
      ..style = PaintingStyle.fill;
    canvas.drawCircle(offsetB, 8, pinB);
    canvas.drawCircle(offsetB, 8, pinBorder);
    canvas.drawCircle(offsetB, 3, Paint()..color = Colors.white);

    // Label B
    final textPainterB = TextPainter(
      text: const TextSpan(
        text: 'B',
        style: TextStyle(
            color: Colors.redAccent,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter'),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    textPainterB.layout();
    textPainterB.paint(canvas, Offset(offsetB.dx - 4, offsetB.dy - 24));

    // 6. Draw Simulated Driver Moving Car
    if (status != 'new' && status != 'pending') {
      final carOffset = progress < 0.40
          ? Offset(
              offsetA.dx - 40 * (1.0 - progress / 0.40),
              offsetA.dy + 30 * (1.0 - progress / 0.40),
            ) // approaching A
          : driverOffset;

      // Draw shadow ring
      canvas.drawCircle(
        carOffset,
        14,
        Paint()
          ..color = Colors.black.withOpacity(0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );

      // Save canvas state to draw rotated vehicle pointing in tangent direction
      canvas.save();
      canvas.translate(carOffset.dx, carOffset.dy);
      canvas.rotate(vehicleAngle);

      // Car body filled dot
      final carBody = Paint()
        ..color = const Color(0xFF00D4A4)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset.zero, 10, carBody);
      canvas.drawCircle(Offset.zero, 10, pinBorder);

      // Rotated car navigation pointer arrow (pointing forward along X-axis)
      final arrowPath = Path();
      arrowPath.moveTo(5, 0); // nose pointing right
      arrowPath.lineTo(-4, -4);
      arrowPath.lineTo(-2, 0);
      arrowPath.lineTo(-4, 4);
      arrowPath.close();

      canvas.drawPath(arrowPath, Paint()..color = isDark ? Colors.black : Colors.white);
      
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _VerticalDottedLinePainter extends CustomPainter {
  final Color color;
  _VerticalDottedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const double dashHeight = 3;
    const double dashSpace = 3;
    double startY = 2;

    while (startY < size.height) {
      canvas.drawLine(
        Offset(size.width / 2, startY),
        Offset(size.width / 2, startY + dashHeight),
        paint,
      );
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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

