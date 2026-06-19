import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPicker, FixedExtentScrollController;
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

  // Quick Suggestions Map
  static const Map<String, List<String>> _quickSuggestions = {
    'Tam Kỳ': [
      'Coopmart Tam Kỳ',
      'Bến xe Tam Kỳ',
      'Đại học Quảng Nam',
      'Ga Tam Kỳ',
      'Bệnh viện Đa khoa Quảng Nam',
    ],
    'Đà Nẵng': [
      'Sân bay Đà Nẵng',
      'Ga Đà Nẵng',
      'Bến xe Đà Nẵng',
      'Cầu Rồng',
      'Lotte Mart Đà Nẵng',
    ],
    'Hội An': [
      'Phố cổ Hội An',
      'Biển An Bàng',
      'Bến xe Hội An',
      'VinWonders Nam Hội An',
    ],
    'Huế': ['Đại Nội Huế', 'Ga Huế', 'Bến xe phía Nam', 'Chợ Đông Ba'],
  };

  // State variables for validation errors
  String? _pickupError;
  String? _dropoffError;

  // State variables for parcel delivery details
  String _parcelType =
      'tai-lieu'; // tai-lieu, quan-ao, thuc-pham, dien-tu, khac
  String _parcelSize = 'nho'; // nho, vua, lon

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

  String _getMonthNameEn(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    if (month >= 1 && month <= 12) {
      return months[month - 1];
    }
    return '';
  }

  void _showCupertinoDateTimePicker(
    BuildContext context,
    bool isDark,
    bool isVi,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Generate dates: 30 days starting from today
    final dates = List.generate(30, (i) => today.add(Duration(days: i)));
    
    // Generate hours: 0 to 23
    final hours = List.generate(24, (i) => i);
    
    // Initial selection indices
    int initialDateIndex = 0;
    for (int i = 0; i < dates.length; i++) {
      if (dates[i].year == _departureDate.year &&
          dates[i].month == _departureDate.month &&
          dates[i].day == _departureDate.day) {
        initialDateIndex = i;
        break;
      }
    }
    
    int initialHourIndex = _departureTime.hour;
    
    // Controllers for pickers
    final dateController = FixedExtentScrollController(initialItem: initialDateIndex);
    final hourController = FixedExtentScrollController(initialItem: initialHourIndex);
    
    int tempDateIndex = initialDateIndex;
    int tempHour = initialHourIndex;
    
    final weekdaysVi = {
      DateTime.monday: 'T2',
      DateTime.tuesday: 'T3',
      DateTime.wednesday: 'T4',
      DateTime.thursday: 'T5',
      DateTime.friday: 'T6',
      DateTime.saturday: 'T7',
      DateTime.sunday: 'CN',
    };
    final weekdaysEn = {
      DateTime.monday: 'Mon',
      DateTime.tuesday: 'Tue',
      DateTime.wednesday: 'Wed',
      DateTime.thursday: 'Thu',
      DateTime.friday: 'Fri',
      DateTime.saturday: 'Sat',
      DateTime.sunday: 'Sun',
    };

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        isVi ? 'Hủy' : 'Cancel',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: AppColors.steel_(isDark),
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Text(
                      isVi ? 'Chọn thời gian' : 'Select Time',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.ink_(isDark),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        final selectedDate = dates[tempDateIndex];
                        final selectedDateTime = DateTime(
                          selectedDate.year,
                          selectedDate.month,
                          selectedDate.day,
                          tempHour,
                          0,
                        );
                        
                        // Check if selected datetime is in the past
                        if (selectedDateTime.isBefore(now)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isVi
                                    ? 'Thời gian chọn không được trong quá khứ'
                                    : 'Selected time cannot be in the past',
                              ),
                              backgroundColor: AppColors.brandError,
                            ),
                          );
                          return;
                        }
                        
                        Navigator.pop(context);
                        setState(() {
                          _departureDate = selectedDate;
                          _departureTime = TimeOfDay(hour: tempHour, minute: 0);
                          
                          final hourStr = tempHour.toString().padLeft(2, '0');
                          final timeString = '$hourStr:00';
                          _selectedTimeSlot = TripTimeSlot(
                            departureTime: timeString,
                            arrivalTime: '${((tempHour + 2) % 24).toString().padLeft(2, '0')}:00',
                            fixedPrice: 90000.0,
                            status: 'active',
                          );
                        });
                      },
                      child: Text(
                        isVi ? 'Xác nhận' : 'Confirm',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          color: AppColors.brandGreenDeep,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Scroll columns
              Stack(
                alignment: Alignment.center,
                children: [
                  // Unified selection overlay
                  Container(
                    height: 40,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.06)
                          : Colors.black.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  Container(
                    height: 200,
                    child: Row(
                      children: [
                        // Column 1: Date
                        Expanded(
                          flex: 3,
                          child: CupertinoPicker(
                            scrollController: dateController,
                            itemExtent: 40,
                            onSelectedItemChanged: (index) {
                              tempDateIndex = index;
                            },
                            selectionOverlay: const SizedBox.shrink(),
                            children: List.generate(dates.length, (index) {
                              final d = dates[index];
                              String label = '';
                              if (d.year == today.year && d.month == today.month && d.day == today.day) {
                                label = isVi ? 'Hôm nay' : 'Today';
                              } else if (d.year == today.add(const Duration(days: 1)).year &&
                                  d.month == today.add(const Duration(days: 1)).month &&
                                  d.day == today.add(const Duration(days: 1)).day) {
                                label = isVi ? 'Ngày mai' : 'Tomorrow';
                              } else {
                                final dayOfWeek = isVi
                                    ? weekdaysVi[d.weekday] ?? ''
                                    : weekdaysEn[d.weekday] ?? '';
                                label = isVi
                                    ? '$dayOfWeek ${d.day} Thg ${d.month}'
                                    : '$dayOfWeek ${d.day} ${_getMonthNameEn(d.month)}';
                              }
                              return Center(
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.ink_(isDark),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                        // Column 2: Hour
                        Expanded(
                          flex: 2,
                          child: CupertinoPicker(
                            scrollController: hourController,
                            itemExtent: 40,
                            onSelectedItemChanged: (index) {
                              tempHour = hours[index];
                            },
                            selectionOverlay: const SizedBox.shrink(),
                            children: List.generate(hours.length, (index) {
                              final h = hours[index];
                              final hStr = h.toString().padLeft(2, '0');
                              return Center(
                                child: Text(
                                  hStr,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.ink_(isDark),
                                  ),
                                ),
                              );
                            }),
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
          final activeSlots = _selectedConfig!.timeSlots
              .where((s) => s.status == 'active')
              .toList();
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
      final activeSlots = _selectedConfig!.timeSlots
          .where((s) => s.status == 'active')
          .toList();
      _selectedTimeSlot = activeSlots.isNotEmpty ? activeSlots.first : null;

      final temp = _pickupController.text;
      _pickupController.text = _dropoffController.text;
      _dropoffController.text = temp;
    });
  }

  double _calculatePrice() {
    if (_selectedTimeSlot == null) return 0.0;
    double base = 90000.0;
    if (_serviceType == 'xe-ghep') {
      return base * _seats;
    } else if (_serviceType == 'bao-xe') {
      return base * 4.0;
    } else {
      double cargoPrice = base * 0.6; // Cargo package is 60% of base
      if (_parcelSize == 'vua') {
        cargoPrice *= 1.3;
      } else if (_parcelSize == 'lon') {
        cargoPrice *= 1.7;
      }
      return cargoPrice;
    }
  }

  Future<void> _selectDate() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isVi = Provider.of<AppState>(context, listen: false).language == 'vi';
    _showCupertinoDateTimePicker(context, isDark, isVi);
  }

  Future<void> _selectTime() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isVi = Provider.of<AppState>(context, listen: false).language == 'vi';
    _showCupertinoDateTimePicker(context, isDark, isVi);
  }

  void _submitBooking(AppState state) async {
    final lang = state.language;
    if (_selectedConfig == null || _selectedTimeSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang == 'vi'
                ? 'Vui lòng chọn tuyến đường và khung giờ hợp lệ'
                : 'Please select a valid route and time slot',
          ),
        ),
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

    final formattedTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(departureDT);
    final basePrice = _calculatePrice();
    final finalPrice = basePrice *
        (_selectedVehicleClass == 0
            ? 1.0
            : (_serviceType == 'gui-hang' ? 2.5 : 1.4));

    final noteText = _feedbackController.text.trim();
    String pickupSpecificPoint = _pickupController.text.trim();
    if (_serviceType == 'gui-hang') {
      final typeLabel = _parcelTypeLabel(lang);
      final sizeLabel = _parcelSizeLabel(lang);
      pickupSpecificPoint += ' [Loại: $typeLabel, Cỡ: $sizeLabel]';
    }
    if (noteText.isNotEmpty) {
      pickupSpecificPoint += ' (Ghi chú: $noteText)';
    }

    final req = TripRequest(
      userName: customer.name,
      phoneNumber: customer.phoneNumber,
      pickupSpecificPoint: pickupSpecificPoint,
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
          content: Text(
            lang == 'vi'
                ? 'Đang gửi yêu cầu đặt xe...'
                : 'Submitting booking request...',
          ),
          duration: const Duration(seconds: 1),
        ),
      );
      final created = await ApiService.createTripRequest(req);
      state.setActiveTrip(created);

      setState(() {
        _showBookingForm = false;
      });

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.brandGreen),
              const SizedBox(width: 8),
              Text(
                lang == 'vi' ? 'Đặt xe thành công' : 'Booking Successful',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.bold,
                ),
              ),
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
                  color:
                      state.isDarkTheme ? AppColors.brandGreen : Colors.black,
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
          content: Text(
            lang == 'vi' ? 'Đặt xe thất bại: $e' : 'Booking failed: $e',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // ─── View 1: Home Dashboard ────────────────────────────────────────────────
  // ─── View 1: Home Dashboard ────────────────────────────────────────────────
  Widget _buildHomeDashboard(
    bool isDark,
    NumberFormat currencyFormat,
    AppState state,
  ) {
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
                    content: Text(
                      lang == 'vi'
                          ? 'Đã kích hoạt chuyến xe giả lập!'
                          : 'Mock trip activated!',
                    ),
                    backgroundColor: AppColors.brandGreen,
                  ),
                );
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color:
                      isDark ? AppColors.surfaceDark : const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? AppColors.hairlineDark : AppColors.hairline,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundImage: const NetworkImage(
                        'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150',
                      ),
                      backgroundColor:
                          isDark ? AppColors.surfaceCode : Colors.grey[200],
                      child: null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lang == 'vi' ? 'Xin chào 👋' : 'Hello 👋',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12.5,
                              color: AppColors.steel_(isDark),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            customer?.name != null && customer!.name.isNotEmpty
                                ? customer.name
                                : (lang == 'vi' ? 'Văn Định' : 'Van Dinh'),
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 16.5,
                              color: AppColors.ink_(isDark),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Notification Bell with green dot
                    Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark
                                ? Colors.white.withOpacity(0.05)
                                : Colors.black.withOpacity(0.03),
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.notifications_none_rounded,
                              size: 22,
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
                        ),
                        Positioned(
                          right: 6,
                          top: 6,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color:
                      isDark ? AppColors.surfaceDark : const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(
                    color: isDark ? AppColors.hairlineDark : AppColors.hairline,
                    width: 1,
                  ),
                  boxShadow: isDark
                      ? []
                      : [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      lang == 'vi' ? 'Bạn muốn đi đâu?' : 'Where to?',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13.5,
                        color: AppColors.stone_(isDark),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Icon(
                      Icons.search_rounded,
                      color: AppColors.brandGreenDeep,
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
                child: _buildHomeActiveTripTracker(
                  isDark,
                  lang,
                  state.activeTrip!,
                  state,
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Row of 3 core service cards
            Row(
              children: [
                _buildPremiumServiceCard(
                  title: lang == 'vi' ? 'Đặt xe' : 'Rides',
                  imageAsset: 'assets/images/3d_car_yellow.png',
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
                  imageAsset: 'assets/images/3d_car_premium_black.png',
                  iconColor: const Color(0xFF374151),
                  iconBgColor: const Color(0xFFF3F4F6),
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
                  imageAsset: 'assets/images/3d_box_red.png',
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
                        lang == 'vi' ? 'Khuyến mãi' : 'Promotion',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFFD1FAE5),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lang == 'vi'
                            ? 'Ghép xe đồng giá từ 80k'
                            : 'Shared rides from \$8',
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
                    child: const Icon(
                      Icons.confirmation_num_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
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
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumServiceCard({
    required String title,
    required String imageAsset,
    required Color iconColor,
    required Color iconBgColor,
    bool isSelected = false,
    bool isDarkBg = false,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final cardBg = isDark ? AppColors.surfaceDark : const Color(0xFFFAFAFA);
    final borderCol = isSelected
        ? AppColors.brandGreen
        : (isDark ? AppColors.hairlineDark : AppColors.hairline);

    return Expanded(
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 72,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark
                        ? AppColors.brandGreen.withOpacity(0.08)
                        : AppColors.brandGreen.withOpacity(0.05))
                    : cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: borderCol,
                  width: isSelected ? 2.0 : 1.0,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.brandGreen.withOpacity(0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.0 : 0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        )
                      ],
              ),
              child: Center(
                child: Image.asset(
                  imageAsset,
                  width: 48,
                  height: 48,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12.5,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected
                  ? AppColors.brandGreenDeep
                  : (isDark ? Colors.white70 : Colors.black87),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildHomeActiveTripTracker(
    bool isDark,
    String lang,
    TripRequest trip,
    AppState state,
  ) {
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
        : 'Toyota Camry (92A-1310)';
    final defaultSubtitle = lang == 'vi'
        ? 'Xe $vehicleInfo • $driverName'
        : '$vehicleInfo • $driverName';

    if (s == 'new' || s == 'pending') {
      statusTitle = lang == 'vi' ? 'Đang tìm tài xế...' : 'Finding driver...';
      statusSubtitle = lang == 'vi'
          ? 'Hệ thống đang ghép xe cho bạn'
          : 'We are matching you with a driver';
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
      statusSubtitle = lang == 'vi'
          ? 'Cảm ơn bạn đã di chuyển cùng Omigo'
          : 'Thank you for riding with Omigo';
    } else {
      statusTitle = lang == 'vi' ? 'Trạng thái chuyến xe' : 'Trip Status';
      statusSubtitle = defaultSubtitle;
    }

    final isShared = trip.serviceType == 'xe-ghep';
    final serviceLabel = isShared
        ? (lang == 'vi' ? 'XE GHÉP' : 'SHARED')
        : (trip.serviceType == 'bao-xe'
            ? (lang == 'vi' ? 'BAO XE' : 'PRIVATE')
            : (lang == 'vi' ? 'GIAO HÀNG' : 'DELIVERY'));

    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1F21), // Slate-900 style background
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header Row ───
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            statusTitle,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF13B58C).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: const Color(0xFF13B58C).withOpacity(0.3),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            serviceLabel,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF13B58C),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lang == 'vi'
                          ? 'Đón lúc: $displayTime'
                          : 'Pickup: $displayTime',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11.5,
                        color: Color(0xFFA1A1AA),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.phone_rounded,
                        color: Colors.white,
                        size: 15,
                      ),
                      onPressed: () {
                        final phone = trip.assignedDriverPhone ?? '0961099069';
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              lang == 'vi'
                                  ? 'Đang gọi tài xế: $phone...'
                                  : 'Calling driver: $phone...',
                            ),
                            backgroundColor: const Color(0xFF13B58C),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.map_rounded,
                        color: Colors.white,
                        size: 15,
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const TrackingScreen()),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ─── Compact Address Flow ───
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Column(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: Color(0xFF13B58C),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 14,
                      color: Colors.white24,
                    ),
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip.pickupSpecificPoint,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white70,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        trip.dropoffSpecificPoint,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white70,
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
          const SizedBox(height: 12),

          // ─── Custom Timeline Progress Tracker ───
          LayoutBuilder(
            builder: (context, constraints) {
              final totalWidth = constraints.maxWidth;
              final startX = 8.0;
              final endX = totalWidth - 8.0;
              final trackWidth = endX - startX;

              final carX = startX + trackWidth * simProgress.clamp(0.02, 0.98);

              return SizedBox(
                height: 32,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: startX,
                      width: trackWidth,
                      top: 14,
                      height: 4,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Positioned(
                      left: startX,
                      width: carX - startX,
                      top: 14,
                      height: 4,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF13B58C),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Positioned(
                      left: startX - 6,
                      top: 10,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1F21),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF13B58C),
                            width: 2.5,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: endX - 6,
                      top: 10,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1F21),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.redAccent,
                            width: 2.5,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: carX - 16,
                      top: 0,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.35),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
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
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(color: Colors.white12, height: 16),

          // ─── Driver details & Price ───
          Row(
            children: [
              const CircleAvatar(
                radius: 15,
                backgroundImage: NetworkImage(
                  'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=100',
                ),
                backgroundColor: Colors.white12,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driverName,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      vehicleInfo,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10.5,
                        color: Color(0xFFA1A1AA),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Text(
                currencyFormat.format(trip.appliedFixedPrice),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF13B58C),
                ),
              ),
            ],
          ),
          if (s == 'completed') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: OutlinedButton(
                      onPressed: () {
                        state.setPrefillBooking(
                          trip.pickupSpecificPoint,
                          trip.dropoffSpecificPoint,
                          trip.serviceType,
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF13B58C),
                        side: const BorderSide(
                            color: Color(0xFF13B58C), width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        lang == 'vi' ? 'ĐẶT LẠI' : 'REBOOK',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: ElevatedButton(
                      onPressed: () {
                        _showRatingDialogDirect(context, state, lang);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF13B58C),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        lang == 'vi' ? 'ĐÁNH GIÁ' : 'RATE RIDE',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showRatingDialogDirect(
    BuildContext context,
    AppState state,
    String lang,
  ) {
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
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.hairline_(isDark),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Text(
                lang == 'vi' ? 'Đánh giá chuyến đi' : 'Rate your ride',
                style: AppText.heading5.copyWith(
                  color: AppColors.ink_(isDark),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                lang == 'vi'
                    ? 'Ý kiến của bạn giúp chúng tôi cải thiện dịch vụ'
                    : 'Your feedback helps us improve',
                textAlign: TextAlign.center,
                style: AppText.caption.copyWith(
                  color: AppColors.stone_(isDark),
                ),
              ),
              const SizedBox(height: 24),
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
                  ),
                ),
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
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  filled: true,
                  fillColor:
                      isDark ? AppColors.surfaceCode : AppColors.surfaceSoft,
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

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          lang == 'vi'
                              ? 'Cảm ơn bạn đã hoàn tất và đánh giá chuyến đi!'
                              : 'Thank you for completing and rating your ride!',
                        ),
                        backgroundColor: AppColors.brandGreen,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    lang == 'vi'
                        ? 'Gửi đánh giá & Hoàn tất'
                        : 'Submit & Finish',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
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
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.hairlineDark : AppColors.hairline,
          width: 1,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
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
                          color: isDark ? Colors.white24 : Colors.black12,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.location_on_rounded,
                      color: isDark ? Colors.white38 : Colors.grey[400],
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
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13.5,
                          color: AppColors.ink_(isDark),
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Sân bay Đà Nẵng',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13.5,
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
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _pickupController.text = 'Coopmart Tam Kỳ';
                _dropoffController.text = 'Sân bay Đà Nẵng';
                _serviceType = 'xe-ghep';
                _bookingStep = 1;
                _showBookingForm = true;
              });
            },
            style: ElevatedButton.styleFrom(
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              backgroundColor: isDark
                  ? AppColors.brandGreen.withOpacity(0.15)
                  : AppColors.brandGreenSoft,
              foregroundColor: AppColors.brandGreenDeep,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              lang == 'vi' ? 'Đặt lại' : 'Rebook',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.bold,
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
          colors: [Color(0xFF006C52), Color(0xFF00A278)],
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
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
            painter: _DashedLinePainter(color: AppColors.hairline_(isDark)),
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
                    lang == 'vi'
                        ? 'Giảm 30K cho chuyến ghép'
                        : '30K Off for Shared Ride',
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
                      title: lang == 'vi'
                          ? 'Giảm 30K cho chuyến ghép'
                          : '30K Off for Shared Ride',
                      desc: lang == 'vi'
                          ? 'Áp dụng cho đơn từ 120K'
                          : 'Min spend 120K',
                      code: 'OMIGOSHARE30',
                      exp: '30/06/2024',
                      isDark: isDark,
                      lang: lang,
                    ),
                    _buildCouponItem(
                      title: lang == 'vi'
                          ? 'Giảm 50K bao xe đường dài'
                          : '50K Off for Private Car',
                      desc: lang == 'vi'
                          ? 'Áp dụng cho chuyến trên 300K'
                          : 'Min spend 300K',
                      code: 'OMIGOPRIVATE50',
                      exp: '15/07/2024',
                      isDark: isDark,
                      lang: lang,
                    ),
                    _buildCouponItem(
                      title: lang == 'vi'
                          ? 'Miễn phí giao hàng chặng đầu'
                          : 'Free Cargo Delivery First Ride',
                      desc: lang == 'vi'
                          ? 'Tối đa 25K cho khách hàng mới'
                          : 'Max discount 25K for new users',
                      code: 'OMIGODELIVERFREE',
                      exp: '31/08/2024',
                      isDark: isDark,
                      lang: lang,
                    ),
                    _buildCouponItem(
                      title: lang == 'vi'
                          ? 'Giảm 10% tổng hóa đơn di chuyển'
                          : '10% Off All Booking Bills',
                      desc: lang == 'vi'
                          ? 'Áp dụng cho tất cả dịch vụ hè'
                          : 'For all summer campaign rides',
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
            painter: _DashedLinePainter(color: AppColors.hairline_(isDark)),
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
    String title,
    String meta,
    Color color,
    IconData icon,
    bool isDark,
  ) {
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.hairline_(isDark), width: 1),
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
                    child: Icon(icon, size: 80, color: Colors.white),
                  ),
                ),
                Center(child: Icon(icon, size: 32, color: Colors.white)),
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
    bool isDark,
    NumberFormat currencyFormat,
    AppState state,
  ) {
    final lang = state.language;

    // Dynamic AppBar Title based on serviceType and language
    String appTitle = '';
    if (_serviceType == 'xe-ghep') {
      appTitle = lang == 'vi' ? 'ĐẶT XE GHÉP' : 'SHARED RIDE';
    } else if (_serviceType == 'bao-xe') {
      appTitle = lang == 'vi' ? 'BAO TRỌN XE' : 'PRIVATE CAR';
    } else {
      appTitle = lang == 'vi' ? 'GIAO HÀNG HÓA' : 'PARCEL DELIVERY';
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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Step Title
          _buildStepSubtitle(_bookingStep, isDark, lang),

          // 2. Service switcher tab/labels
          _buildServiceSwitcher(isDark, lang),

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
                    else if (_bookingStep == 2) ...[
                      _buildTimeStep(isDark, lang, currencyFormat),
                      const SizedBox(height: 16),
                      _buildInfoStep(isDark, lang),
                    ] else if (_bookingStep == 3)
                      _buildConfirmStep(isDark, lang, currencyFormat),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(isDark, lang, state),
    );
  }

  Widget _buildServiceSwitcher(bool isDark, String lang) {
    if (_bookingStep > 2) return const SizedBox.shrink();

    final isVi = lang == 'vi';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      height: 48,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.hairlineDark : const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _buildServiceTab(
              'xe-ghep',
              isVi ? 'Xe Ghép' : 'Shared',
              Icons.people_alt_rounded,
              isDark,
            ),
          ),
          Expanded(
            child: _buildServiceTab(
              'bao-xe',
              isVi ? 'Bao Xe' : 'Private',
              Icons.directions_car_rounded,
              isDark,
            ),
          ),
          Expanded(
            child: _buildServiceTab(
              'gui-hang',
              isVi ? 'Giao Hàng' : 'Parcel',
              Icons.local_shipping_rounded,
              isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceTab(String type, String label, IconData icon, bool isDark) {
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
              ? (isDark ? AppColors.brandGreen.withOpacity(0.15) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(
                  color: AppColors.brandGreen.withOpacity(0.4),
                  width: 1,
                )
              : null,
          boxShadow: isSelected && !isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? AppColors.brandGreen
                  : (isDark ? Colors.white60 : AppColors.steel),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? AppColors.brandGreen
                    : (isDark ? Colors.white60 : AppColors.steel),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepperHeader(int currentStep, bool isDark, String lang) {
    final vi = lang == 'vi';
    String stepName = '';
    switch (currentStep) {
      case 1:
        stepName = vi ? 'Lộ trình' : 'Route';
        break;
      case 2:
        stepName = vi ? 'Chi tiết' : 'Details';
        break;
      case 3:
        stepName = vi ? 'Xác nhận' : 'Confirm';
        break;
    }

    final double progressPercent = currentStep / 3.0;

    return Container(
      color: AppColors.canvas_(isDark),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                vi ? 'TIẾN TRÌNH ĐẶT XE' : 'BOOKING PROGRESS',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.steel_(isDark),
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                '${vi ? "Bước" : "Step"} $currentStep/3: $stepName',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brandGreenDeep,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progressPercent,
              minHeight: 4,
              backgroundColor: isDark ? AppColors.surfaceCode : const Color(0xFFE5E7EB),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.brandGreen),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepSubtitle(int step, bool isDark, String lang) {
    if (step == 1) return const SizedBox.shrink();
    String title = '';
    final isVi = lang == 'vi';

    if (_serviceType == 'gui-hang') {
      if (step == 2) {
        title = isVi ? 'Thời gian & Thông tin gửi hàng' : 'Time & Parcel Details';
      } else {
        title = isVi ? 'Xác nhận đơn hàng' : 'Confirm delivery details';
      }
    } else if (_serviceType == 'bao-xe') {
      if (step == 2) {
        title = isVi ? 'Thời gian & Thông tin bao xe' : 'Time & Private Details';
      } else {
        title = isVi ? 'Xác nhận bao xe' : 'Confirm private ride';
      }
    } else {
      if (step == 2) {
        title = isVi ? 'Thời gian & Thông tin chuyến đi' : 'Time & Trip Details';
      } else {
        title = isVi ? 'Xác nhận thông tin' : 'Confirm details';
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
      child: Text(
        title,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.ink_(isDark),
        ),
      ),
    );
  }

  void _showRouteSelectionBottomSheet(
    BuildContext context,
    bool isDark,
    bool isVi,
  ) {
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
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 4,
                      ),
                      title: Text(
                        '${config.origin} ↔ ${config.destination}',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected
                              ? AppColors.brandGreenDeep
                              : AppColors.ink_(isDark),
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(
                              Icons.check,
                              color: AppColors.brandGreenDeep,
                              size: 20,
                            )
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
    final destCity =
        _selectedConfig?.destination ?? (isVi ? 'điểm đến' : 'destination');

    final pickupHint = _serviceType == 'gui-hang'
        ? (isVi ? 'Gửi từ $originCity' : 'Send from $originCity')
        : (isVi ? 'Đón tại $originCity' : 'Pickup in $originCity');
    final dropoffHint = _serviceType == 'gui-hang'
        ? (isVi ? 'Giao tại $destCity' : 'Deliver to $destCity')
        : (isVi ? 'Trả tại $destCity' : 'Dropoff in $destCity');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. TUYẾN ĐƯỜNG Section
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          padding: const EdgeInsets.all(16.0),
          decoration: cardDecoration(isDark, radius: AppRadius.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                                : (isDark
                                    ? const Color(0xFF6B7280)
                                    : const Color(0xFF9CA3AF)),
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
            ],
          ),
        ),

        // 2. ĐỊA CHỈ ĐÓN & TRẢ Section
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          padding: const EdgeInsets.all(16.0),
          decoration: cardDecoration(isDark, radius: AppRadius.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Pickup Input Field (Full width)
                  Column(
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
                            color: _pickupError != null
                                ? AppColors.brandError
                                : (isDark ? AppColors.hairlineDark : AppColors.hairline),
                            width: _pickupError != null ? 1.5 : 1,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.centerLeft,
                        child: TextFormField(
                          controller: _pickupController,
                          onChanged: (_) => setState(() {}),
                          style: AppText.bodySmMedium.copyWith(
                            color: AppColors.ink_(isDark),
                          ),
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
                            filled: false,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // 2. Pickup suggestions & errors
                  if (_pickupError != null || (_selectedConfig != null && _pickupController.text.trim().isEmpty)) ...[
                    const SizedBox(height: 4),
                    if (_pickupError != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 12.0),
                        child: Text(
                          _pickupError!,
                          style: const TextStyle(
                            color: AppColors.brandError,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    if (_selectedConfig != null && _pickupController.text.trim().isEmpty)
                      _buildSuggestionChips(
                        _selectedConfig!.origin,
                        _pickupController,
                        isDark,
                        isVi ? 'Gợi ý điểm đón:' : 'Suggested pickup:',
                      ),
                  ],

                  // 3. Swap / Đổi chiều button centered in between
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      child: InkWell(
                        onTap: _swapLocations,
                        borderRadius: BorderRadius.circular(9999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.surfaceCode : Colors.white,
                            borderRadius: BorderRadius.circular(9999),
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
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.swap_vert_rounded,
                                color: AppColors.brandGreenDeep,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isVi ? 'Đổi chiều' : 'Swap',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.brandGreenDeep,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 4. Dropoff Input Field (Full width)
                  Column(
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
                            color: _dropoffError != null
                                ? AppColors.brandError
                                : (isDark ? AppColors.hairlineDark : AppColors.hairline),
                            width: _dropoffError != null ? 1.5 : 1,
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.centerLeft,
                        child: TextFormField(
                          controller: _dropoffController,
                          onChanged: (_) => setState(() {}),
                          style: AppText.bodySmMedium.copyWith(
                            color: AppColors.ink_(isDark),
                          ),
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
                            filled: false,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // 5. Dropoff suggestions & errors
                  if (_dropoffError != null || (_selectedConfig != null && _dropoffController.text.trim().isEmpty)) ...[
                    const SizedBox(height: 4),
                    if (_dropoffError != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 12.0),
                        child: Text(
                          _dropoffError!,
                          style: const TextStyle(
                            color: AppColors.brandError,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    if (_selectedConfig != null && _dropoffController.text.trim().isEmpty)
                      _buildSuggestionChips(
                        _selectedConfig!.destination,
                        _dropoffController,
                        isDark,
                        isVi ? 'Gợi ý điểm trả:' : 'Suggested dropoff:',
                      ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
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
                final currencyFormat = NumberFormat.currency(
                  locale: 'vi_VN',
                  symbol: 'đ',
                );
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
                      _selectedTimeSlot =
                          activeSlots.isNotEmpty ? activeSlots.first : null;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 14.0,
                    ),
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
    final now = DateTime.now();
    final isToday = _departureDate.year == now.year &&
        _departureDate.month == now.month &&
        _departureDate.day == now.day;

    final activeSlots = _selectedConfig?.timeSlots
            .where((s) => s.status == 'active')
            .toList() ??
        [];

    final allPassed = isToday &&
        activeSlots.isNotEmpty &&
        activeSlots.every((slot) {
          final timeParts = slot.departureTime.split(':');
          if (timeParts.length >= 2) {
            final hour = int.tryParse(timeParts[0]) ?? 0;
            final minute = int.tryParse(timeParts[1]) ?? 0;
            final slotTime = DateTime(
              now.year,
              now.month,
              now.day,
              hour,
              minute,
            );
            return slotTime.isBefore(now);
          }
          return false;
        });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Date & Time pickers in a card
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          padding: const EdgeInsets.all(16.0),
          decoration: cardDecoration(isDark, radius: AppRadius.lg),
          child: Column(
            children: [
              // Date picker field (Row 1)
              InkWell(
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
                                ? (lang == 'vi'
                                    ? 'Ngày gửi'
                                    : 'Dispatch Date')
                                : (lang == 'vi'
                                    ? 'Ngày đi'
                                    : 'Departure Date'),
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
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.steel_(isDark),
                      size: 20,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Divider(
                color: isDark ? AppColors.hairlineDark : AppColors.hairline,
                height: 1,
              ),
              const SizedBox(height: 12),
              // Time picker field (Row 2)
              InkWell(
                onTap: _selectTime,
                child: Row(
                  children: [
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
                                : (lang == 'vi'
                                    ? 'Giờ đi'
                                    : 'Departure Time'),
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
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.steel_(isDark),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        if (allPassed)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF3B1F1F) : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF5C2D2D) : const Color(0xFFFEE2E2),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.brandError,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    lang == 'vi'
                        ? 'Tất cả các chuyến xe hôm nay đã khởi hành. Bạn có thể chọn ngày mai để tiếp tục đặt vé.'
                        : 'All rides for today have already departed. Please select tomorrow to book.',
                    style: const TextStyle(
                      color: AppColors.brandError,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildInfoStep(bool isDark, String lang) {
    int maxSeats = 4;
    if (_selectedTimeSlot != null) {
      if (_selectedTimeSlot!.departureTime.contains('09:00')) {
        maxSeats = 3;
      } else if (_selectedTimeSlot!.departureTime.contains('13:30') ||
          _selectedTimeSlot!.departureTime.contains('12:00')) {
        maxSeats = 5;
      } else if (_selectedTimeSlot!.departureTime.contains('18:00')) {
        maxSeats = 2;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_serviceType == 'xe-ghep') ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: cardDecoration(isDark, radius: AppRadius.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                            lang == 'vi'
                                ? 'Số chỗ đăng ký ghép'
                                : 'Seats count to book',
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
                          color: isDark
                              ? AppColors.surfaceCode
                              : AppColors.surfaceSoft,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: _seats > 1
                                  ? () => setState(() => _seats--)
                                  : null,
                              icon: const Icon(Icons.remove, size: 16),
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                              padding: EdgeInsets.zero,
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12.0,
                              ),
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
                              onPressed: _seats < maxSeats
                                  ? () => setState(() => _seats++)
                                  : null,
                              icon: const Icon(Icons.add, size: 16),
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const SizedBox.shrink(),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_serviceType == 'gui-hang') ...[
            // 1. Parcel Type selection
            Container(
              padding: const EdgeInsets.all(16),
              decoration: cardDecoration(isDark, radius: AppRadius.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang == 'vi' ? 'LOẠI HÀNG HÓA' : 'PARCEL TYPE',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.steel_(isDark),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildParcelTypeOption(
                        'tai-lieu',
                        lang == 'vi' ? '📄 Tài liệu' : '📄 Documents',
                        isDark,
                      ),
                      _buildParcelTypeOption(
                        'quan-ao',
                        lang == 'vi' ? '👕 Quần áo' : '👕 Clothes',
                        isDark,
                      ),
                      _buildParcelTypeOption(
                        'thuc-pham',
                        lang == 'vi' ? '🍕 Thực phẩm' : '🍕 Food',
                        isDark,
                      ),
                      _buildParcelTypeOption(
                        'dien-tu',
                        lang == 'vi' ? '💻 Điện tử' : '💻 Electronics',
                        isDark,
                      ),
                      _buildParcelTypeOption(
                        'khac',
                        lang == 'vi' ? '📦 Khác' : '📦 Other',
                        isDark,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Parcel Size selection
            Container(
              padding: const EdgeInsets.all(16),
              decoration: cardDecoration(isDark, radius: AppRadius.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang == 'vi'
                        ? 'KÍCH THƯỚC & KHỐI LƯỢNG'
                        : 'PARCEL SIZE & WEIGHT',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.steel_(isDark),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Column(
                    children: [
                      _buildParcelSizeCard(
                        'nho',
                        lang == 'vi' ? 'Nhỏ' : 'Small',
                        '< 5 kg',
                        lang == 'vi' ? 'Giá gốc' : 'Base',
                        isDark,
                      ),
                      const SizedBox(height: 8),
                      _buildParcelSizeCard(
                        'vua',
                        lang == 'vi' ? 'Vừa' : 'Medium',
                        '5 - 20 kg',
                        '+30%',
                        isDark,
                      ),
                      const SizedBox(height: 8),
                      _buildParcelSizeCard(
                        'lon',
                        lang == 'vi' ? 'Lớn' : 'Large',
                        '> 20 kg',
                        '+70%',
                        isDark,
                      ),
                    ],
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
                    fillColor:
                        isDark ? AppColors.surfaceCode : AppColors.surfaceSoft,
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
                color:
                    isDark ? const Color(0xFF005E46) : const Color(0xFFDCFCE7),
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
                            ? 'Cam kết: Giao nhận tận nơi, bảo quản cẩn thận & hủy miễn phí'
                            : 'Commitment: Door-to-door, safe handling & free cancellation')
                        : (_serviceType == 'bao-xe'
                            ? (lang == 'vi'
                                ? 'Cam kết: Bao xe riêng tư, đón trả tận nơi & hủy miễn phí'
                                : 'Commitment: 100% private, door-to-door & free cancellation')
                            : (lang == 'vi'
                                ? 'Cam kết: Đúng giờ ±15 phút & hủy miễn phí'
                                : 'Commitment: Punctual ±15 mins & free cancellation')),
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

  Widget _buildConfirmStep(
    bool isDark,
    String lang,
    NumberFormat currencyFormat,
  ) {
    final pickupText = _pickupController.text.isNotEmpty
        ? _pickupController.text
        : (_selectedConfig?.origin ?? '');
    final dropoffText = _dropoffController.text.isNotEmpty
        ? _dropoffController.text
        : (_selectedConfig?.destination ?? '');
    final dateText = _formatDateText(_departureDate, lang == 'vi');
    final timeText =
        _selectedTimeSlot?.departureTime ?? _departureTime.format(context);

    final double standardPrice = _calculatePrice();
    final double premiumPrice =
        standardPrice * (_serviceType == 'gui-hang' ? 2.5 : 1.4);
    final double selectedPrice =
        _selectedVehicleClass == 0 ? standardPrice : premiumPrice;

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
        ? (lang == 'vi'
            ? '4 phút · Xe 4 chỗ tiêu chuẩn'
            : '4 mins · Standard 4-seater')
        : _serviceType == 'bao-xe'
            ? (lang == 'vi'
                ? '4 phút · Sedan đời mới'
                : '4 mins · Modern Sedan')
            : (lang == 'vi'
                ? '3 phút · Giao bằng xe máy'
                : '3 mins · Motorcycle delivery');

    final premiumSub = _serviceType == 'xe-ghep'
        ? (lang == 'vi'
            ? '6 phút · Xe 7 chỗ rộng rãi'
            : '6 mins · Spacious 7-seater')
        : _serviceType == 'bao-xe'
            ? (lang == 'vi'
                ? '6 phút · SUV 7 chỗ lớn'
                : '6 mins · Large 7-seat SUV')
            : (lang == 'vi'
                ? '10 phút · Xe bán tải / xe tải'
                : '10 mins · Pickup / Truck');

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
                Icon(
                  Icons.location_on_rounded,
                  color: AppColors.brandGreen,
                  size: 16,
                ),
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
                  style: AppText.caption.copyWith(
                    color: AppColors.steel_(isDark),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (_serviceType == 'gui-hang') ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.surfaceCode.withOpacity(0.5)
                    : AppColors.surfaceSoft.withOpacity(0.5),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: isDark ? AppColors.hairlineDark : AppColors.hairline,
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.inventory_2_outlined,
                    color: AppColors.brandGreen,
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    lang == 'vi'
                        ? 'Hàng hóa: ${_parcelTypeLabel(lang)} (${_parcelSizeLabel(lang)})'
                        : 'Parcel: ${_parcelTypeLabel(lang)} (${_parcelSizeLabel(lang)})',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11.5,
                      color: AppColors.steel_(isDark),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Options Header Label
          Text(
            lang == 'vi' ? 'CHỌN LOẠI DỊCH VỤ' : 'CHOOSE VEHICLE CLASS',
            style: AppText.microUppercase.copyWith(
              color: AppColors.steel_(isDark),
            ),
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
                    child: Icon(
                      standardIcon,
                      color: AppColors.brandGreenDeep,
                      size: 22,
                    ),
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
                          style: AppText.caption.copyWith(
                            color: AppColors.steel_(isDark),
                            fontSize: 11,
                          ),
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
                    child: Icon(
                      premiumIcon,
                      color: AppColors.brandGreenDeep,
                      size: 22,
                    ),
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
                          style: AppText.caption.copyWith(
                            color: AppColors.steel_(isDark),
                            fontSize: 11,
                          ),
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
                const Icon(
                  Icons.payment_rounded,
                  color: AppColors.brandGreen,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    lang == 'vi' ? 'Tiền mặt / Ví điện tử' : 'Cash / E-Wallet',
                    style: AppText.captionBold.copyWith(
                      color: AppColors.ink_(isDark),
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_right_rounded,
                  color: AppColors.steel_(isDark),
                  size: 18,
                ),
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
                color:
                    isDark ? const Color(0xFF005E46) : const Color(0xFFCCFBF1),
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
                    color: isDark
                        ? AppColors.brandGreen
                        : AppColors.brandGreenDeep,
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
    final vi = lang == 'vi';
    final nextText = vi ? 'Tiếp tục' : 'Continue';
    final backText = vi ? 'Quay lại' : 'Back';
    final submitText = vi ? 'Xác nhận đặt' : 'Confirm & Book';

    String stepName = '';
    switch (_bookingStep) {
      case 1:
        stepName = vi ? 'Lộ trình' : 'Route';
        break;
      case 2:
        stepName = vi ? 'Chi tiết' : 'Details';
        break;
      case 3:
        stepName = vi ? 'Xác nhận' : 'Confirm';
        break;
    }
    final stepText = '${vi ? "Bước" : "Step"} $_bookingStep/3: $stepName';

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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Text(
                stepText,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.brandGreenDeep,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _bookingStep == 1
                ? SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        final pickupVal = _pickupController.text.trim();
                        final dropoffVal = _dropoffController.text.trim();
                        setState(() {
                          _pickupError = pickupVal.isEmpty
                              ? (lang == 'vi'
                                  ? 'Vui lòng nhập điểm đón'
                                  : 'Please enter pickup location')
                              : null;
                          _dropoffError = dropoffVal.isEmpty
                              ? (lang == 'vi'
                                  ? 'Vui lòng nhập điểm đến'
                                  : 'Please enter destination')
                              : null;
                        });
                        if (_pickupError != null || _dropoffError != null) return;

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
                                color: isDark
                                    ? AppColors.hairlineDark
                                    : AppColors.hairline,
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
                                    _bookingStep == 3 ? submitText : nextText,
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    _bookingStep == 3
                                        ? Icons.check_circle_outline_rounded
                                        : Icons.arrow_forward_rounded,
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

    if (state.prefillPickup != null) {
      final pPickup = state.prefillPickup!;
      final pDropoff = state.prefillDropoff!;
      final pServiceType = state.prefillServiceType!;

      if (state.activeTrip != null &&
          state.activeTrip!.status.toLowerCase() == 'completed') {
        state.clearActiveTrip();
      }

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _pickupController.text = pPickup;
            _dropoffController.text = pDropoff;
            _serviceType = pServiceType;
            if (pServiceType == 'bao-xe') {
              _seats = 4;
            } else {
              _seats = 1;
            }
            _showBookingForm = true;
            _bookingStep = 1;
          });
          state.clearPrefillBooking();
        }
      });
    }

    // Default dashboard views
    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF090E17) : const Color(0xFFF9FAFB),
      appBar: null,
      body: _isLoadingConfigs
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.brandGreen),
            )
          : _errorMsg.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      _errorMsg,
                      style: const TextStyle(color: AppColors.brandError),
                    ),
                  ),
                )
              : _showBookingForm
                  ? _buildBookingFormSheet(isDark, currencyFormat, state)
                  : _buildHomeDashboard(isDark, currencyFormat, state),
    );
  }

  Widget _buildSuggestionChips(
    String city,
    TextEditingController controller,
    bool isDark,
    String title,
  ) {
    final suggestions = _quickSuggestions[city] ?? [];
    if (suggestions.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            title,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10.5,
              color: AppColors.steel_(isDark),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 36,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: suggestions.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final item = suggestions[index];
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ActionChip(
                  label: Text(
                    item,
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'Inter',
                      color: isDark ? Colors.white70 : Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  backgroundColor:
                      isDark ? AppColors.surfaceCode : const Color(0xFFF3F4F6),
                  shape: StadiumBorder(
                    side: BorderSide(
                      color:
                          isDark ? AppColors.hairlineDark : AppColors.hairline,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  onPressed: () {
                    setState(() {
                      controller.text = item;
                      if (controller == _pickupController) _pickupError = null;
                      if (controller == _dropoffController)
                        _dropoffError = null;
                    });
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildParcelTypeOption(String type, String label, bool isDark) {
    final isSelected = _parcelType == type;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.black : AppColors.ink_(isDark),
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.brandGreen,
      backgroundColor: isDark ? AppColors.surfaceCode : const Color(0xFFF3F4F6),
      checkmarkColor: Colors.black,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _parcelType = type;
          });
        }
      },
    );
  }

  Widget _buildParcelSizeCard(
    String size,
    String title,
    String weight,
    String priceTag,
    bool isDark,
  ) {
    final isSelected = _parcelSize == size;
    return GestureDetector(
      onTap: () {
        setState(() {
          _parcelSize = size;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: cardDecoration(
          isDark,
          featured: isSelected,
          radius: AppRadius.md,
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppColors.brandGreenDeep
                      : AppColors.steel_(isDark),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: const BoxDecoration(
                          color: AppColors.brandGreenDeep,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? AppColors.brandGreenDeep
                          : AppColors.ink_(isDark),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    weight,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: AppColors.steel_(isDark),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.brandGreen.withOpacity(0.12)
                    : (isDark
                        ? AppColors.surfaceCode
                        : const Color(0xFFF3F4F6)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                priceTag,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? AppColors.brandGreenDeep
                      : AppColors.steel_(isDark),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _parcelTypeLabel(String lang) {
    switch (_parcelType) {
      case 'tai-lieu':
        return lang == 'vi' ? 'Tài liệu' : 'Documents';
      case 'quan-ao':
        return lang == 'vi' ? 'Quần áo' : 'Clothes';
      case 'thuc-pham':
        return lang == 'vi' ? 'Thực phẩm' : 'Food';
      case 'dien-tu':
        return lang == 'vi' ? 'Điện tử' : 'Electronics';
      case 'khac':
      default:
        return lang == 'vi' ? 'Khác' : 'Others';
    }
  }

  String _parcelSizeLabel(String lang) {
    switch (_parcelSize) {
      case 'nho':
        return lang == 'vi' ? 'Nhỏ (<5kg)' : 'Small (<5kg)';
      case 'vua':
        return lang == 'vi' ? 'Vừa (5-15kg)' : 'Medium (5-15kg)';
      case 'lon':
        return lang == 'vi' ? 'Lớn (15-30kg)' : 'Large (15-30kg)';
      default:
        return lang == 'vi' ? 'Nhỏ' : 'Small';
    }
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
      ..color = isDark
          ? const Color(0xFF1E3A8A).withOpacity(0.3)
          : const Color(0xFFDCEBFF)
      ..strokeWidth = 16
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final riverPath = Path();
    riverPath.moveTo(-20, size.height * 0.4);
    riverPath.cubicTo(
      size.width * 0.3,
      size.height * 0.25,
      size.width * 0.65,
      size.height * 0.65,
      size.width + 20,
      size.height * 0.5,
    );
    canvas.drawPath(riverPath, riverPaint);

    // Draw Parks (Mảng xanh)
    final parkPaint = Paint()
      ..color = isDark
          ? const Color(0xFF065F46).withOpacity(0.2)
          : const Color(0xFFE2F0D9)
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
      ..color = isDark
          ? Colors.white.withOpacity(0.06)
          : Colors.black.withOpacity(0.04)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;

    // Diagonal road 1
    canvas.drawLine(
      Offset(0, size.height * 0.75),
      Offset(size.width, size.height * 0.2),
      cityRoadPaint,
    );
    // Vertical road 2
    canvas.drawLine(
      Offset(size.width * 0.25, 0),
      Offset(size.width * 0.25, size.height),
      cityRoadPaint,
    );
    // Horizontal road 3
    canvas.drawLine(
      Offset(0, size.height * 0.8),
      Offset(size.width, size.height * 0.8),
      cityRoadPaint,
    );

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
          final extractPath = metric.extractPath(
            0.0,
            metric.length * activeProgress,
          );
          canvas.drawPath(extractPath, activePathPaint);
        }

        // Get exact vehicle offset coordinates on screen
        final tangent = metric.getTangentForOffset(
          metric.length * activeProgress,
        );
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
          fontFamily: 'Inter',
        ),
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
          fontFamily: 'Inter',
        ),
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

      canvas.drawPath(
        arrowPath,
        Paint()..color = isDark ? Colors.black : Colors.white,
      );

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
      canvas.drawLine(Offset(0, startY), Offset(0, startY + dashHeight), paint);
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
