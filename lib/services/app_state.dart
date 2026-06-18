import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/customer.dart';
import '../models/trip_request.dart';
import 'api_service.dart';

class AppState extends ChangeNotifier {
  Customer? _currentCustomer;
  String _language = 'vi';
  bool _isDarkTheme = false;
  TripRequest? _activeTrip;
  bool _isLoading = false;
  int _selectedTabIndex = 0;

  String? _prefillPickup;
  String? _prefillDropoff;
  String? _prefillServiceType;

  // Coordinate map for simulation
  static const Map<String, List<double>> _coordsMap = {
    'Tam Kỳ': [15.5736, 108.4740],
    'Đà Nẵng': [16.0544, 108.2022],
    'Hội An': [15.8794, 108.3350],
    'Huế': [16.4637, 107.5909],
  };

  // Simulation states
  double _simProgress = 0.0;
  double _driverLat = 0.0;
  double _driverLng = 0.0;
  String _simStatusText = '';
  Timer? _simTimer;
  Timer? _pollTimer;

  Customer? get currentCustomer => _currentCustomer;
  bool get isLoggedIn => _currentCustomer != null;
  String get language => _language;
  bool get isDarkTheme => _isDarkTheme;
  TripRequest? get activeTrip => _activeTrip;
  bool get isLoading => _isLoading;
  int get selectedTabIndex => _selectedTabIndex;

  String? get prefillPickup => _prefillPickup;
  String? get prefillDropoff => _prefillDropoff;
  String? get prefillServiceType => _prefillServiceType;

  double get simProgress => _simProgress;
  double get driverLat => _driverLat;
  double get driverLng => _driverLng;
  String get simStatusText => _simStatusText;

  void setPrefillBooking(String pickup, String dropoff, String serviceType) {
    _prefillPickup = pickup;
    _prefillDropoff = dropoff;
    _prefillServiceType = serviceType;
    notifyListeners();
  }

  void clearPrefillBooking() {
    _prefillPickup = null;
    _prefillDropoff = null;
    _prefillServiceType = null;
    notifyListeners();
  }

  void setSelectedTabIndex(int index) {
    _selectedTabIndex = index;
    notifyListeners();
  }

  AppState() {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    // Auto-login mock customer credentials if empty for seamless testing
    var phone = prefs.getString('customer_phone');
    var name = prefs.getString('customer_name');
    var email = prefs.getString('customer_email');
    if (phone == null || name == null || email == null) {
      phone = '0901234567';
      name = 'Văn Định';
      email = 'vandinh@gmail.com';
      await prefs.setString('customer_phone', phone);
      await prefs.setString('customer_name', name);
      await prefs.setString('customer_email', email);
    }

    _currentCustomer = Customer(name: name, phoneNumber: phone, email: email);
    debugPrint("AppState: Stored Customer Phone: $phone, Name: $name");

    try {
      final trips = await ApiService.fetchCustomerTrips(phone);
      for (final t in trips) {
        if (t.status != 'completed' && t.status != 'cancelled') {
          _activeTrip = t;
          startSimTimer(t);
          break;
        }
      }
    } catch (e) {
      debugPrint("Failed to auto-restore active trip: $e");
    }

    // Auto-populate a mock active trip in progress if none is active
    if (_activeTrip == null) {
      final mockTrip = TripRequest(
        id: 'mock_active_trip_999',
        userName: name,
        phoneNumber: phone,
        pickupSpecificPoint: 'Coopmart Tam Kỳ',
        dropoffSpecificPoint: 'Sân bay Đà Nẵng',
        requestedSeatCount: 1,
        origin: 'Tam Kỳ',
        destination: 'Đà Nẵng',
        requestedDepartureTime: '08:30',
        source: 'app',
        bookingSource: 'web',
        serviceType: 'xe-ghep',
        createdByType: 'user',
        appliedFixedPrice: 150000,
        status: 'assigned', // approaches passenger, then switches to 'on_trip'
        assignedDriverName: 'Nguyễn Văn Hùng',
        assignedDriverId: 'driver_hung_123',
      );
      _activeTrip = mockTrip;
      startSimTimer(mockTrip);
    }

    _language = prefs.getString('language') ?? 'vi';
    _isDarkTheme = prefs.getBool('isDarkTheme') ?? false;
    notifyListeners();
  }

  Future<void> login(String phoneNumber, String name,
      {String email = ''}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final customer =
          await ApiService.loginCustomer(phoneNumber, name: name, email: email);
      _currentCustomer = customer;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('customer_phone', customer.phoneNumber);
      await prefs.setString('customer_name', customer.name);
      await prefs.setString('customer_email', customer.email);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateProfile(
      {required String name,
      required String phoneNumber,
      required String email}) async {
    if (_currentCustomer == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      final updated =
          Customer(name: name, phoneNumber: phoneNumber, email: email);
      _currentCustomer = updated;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('customer_name', name);
      await prefs.setString('customer_phone', phoneNumber);
      await prefs.setString('customer_email', email);

      await ApiService.loginCustomer(phoneNumber, name: name, email: email);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _currentCustomer = null;
    _activeTrip = null;
    _stopSimTimer();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('customer_phone');
    await prefs.remove('customer_name');
    await prefs.remove('customer_email');
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    _language = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', lang);
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkTheme = !_isDarkTheme;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkTheme', _isDarkTheme);
    notifyListeners();
  }

  void setActiveTrip(TripRequest trip) {
    _activeTrip = trip;
    startSimTimer(trip);
    notifyListeners();
  }

  void clearActiveTrip() {
    _activeTrip = null;
    _stopSimTimer();
    notifyListeners();
  }

  void startSimTimer(TripRequest trip) {
    _simTimer?.cancel();
    _pollTimer?.cancel();

    final originNode = _coordsMap[trip.origin] ?? [15.5736, 108.4740];
    final destNode = _coordsMap[trip.destination] ?? [16.0544, 108.2022];

    final startLat = originNode[0] - 0.04;
    final startLng = originNode[1] - 0.03;

    _simProgress = 0.0;
    _driverLat = startLat;
    _driverLng = startLng;
    _simStatusText = _language == 'vi'
        ? 'Hệ thống đang tìm tài xế gần bạn nhất...'
        : 'Finding your driver...';

    // 1. Live status polling timer
    _pollTimer = Timer.periodic(const Duration(seconds: 8), (_) async {
      if (_activeTrip == null || _activeTrip!.id == null) return;
      try {
        final list =
            await ApiService.fetchCustomerTrips(_activeTrip!.phoneNumber);
        final found = list.firstWhere((t) => t.id == _activeTrip!.id,
            orElse: () => _activeTrip!);
        if (found.status != _activeTrip!.status) {
          _activeTrip = found;
          notifyListeners();
        }
      } catch (_) {}
    });

    // 2. Real-time GPS movement simulation along road nodes
    _simTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_activeTrip == null) {
        _stopSimTimer();
        return;
      }

      final currentTrip = _activeTrip!;
      final l = _language;

      if (currentTrip.status == 'new' || currentTrip.status == 'pending') {
        _simProgress = 0.0;
        _simStatusText = l == 'vi'
            ? 'Đang ghép chuyến cùng tài xế phù hợp...'
            : 'Connecting you with a driver...';
      } else if (currentTrip.status == 'confirmed' ||
          currentTrip.status == 'assigned') {
        // Driver approaching passenger
        _simProgress = (_simProgress + 0.06).clamp(0.0, 0.40);
        if (_simProgress < 0.35) {
          _simStatusText = l == 'vi'
              ? 'Tài xế đang di chuyển tới điểm đón của bạn'
              : 'Driver is on the way to your pickup location';
        } else {
          _simStatusText = l == 'vi'
              ? 'Tài xế đã đến điểm đón. Hãy chuẩn bị lên xe!'
              : 'Driver has arrived. Please meet them now!';

          if (_simProgress >= 0.40) {
            _activeTrip = currentTrip.copyWith(status: 'on_trip');
          }
        }
      } else if (currentTrip.status == 'on_trip') {
        // Driver driving passenger to destination
        if (_simProgress < 0.40) _simProgress = 0.40;
        _simProgress = (_simProgress + 0.05).clamp(0.0, 1.0);

        if (_simProgress < 0.85) {
          _simStatusText = l == 'vi'
              ? 'Hành trình đang di chuyển trên quốc lộ'
              : 'On trip along the highway...';
        } else if (_simProgress < 1.0) {
          _simStatusText = l == 'vi'
              ? 'Bạn sắp đến điểm trả rồi!'
              : 'Almost at your destination!';
        } else {
          _simStatusText = l == 'vi'
              ? 'Bạn đã tới điểm đến an toàn!'
              : 'Arrived safely at destination!';

          if (_simProgress >= 1.0) {
            _activeTrip = currentTrip.copyWith(status: 'completed');
          }
        }
      } else if (currentTrip.status == 'completed') {
        _simProgress = 1.0;
        _simStatusText = l == 'vi'
            ? 'Chuyến xe hoàn tất. Hãy gửi đánh giá!'
            : 'Trip completed. Please rate your driver!';
      }

      // Interpolate current simulated location
      if (_simProgress < 0.40) {
        final t = _simProgress / 0.40;
        _driverLat = startLat + (originNode[0] - startLat) * t;
        _driverLng = startLng + (originNode[1] - startLng) * t;
      } else {
        final t = (_simProgress - 0.40) / 0.60;
        _driverLat = originNode[0] + (destNode[0] - originNode[0]) * t;
        _driverLng = originNode[1] + (destNode[1] - originNode[1]) * t;
      }

      notifyListeners();
    });
  }

  void _stopSimTimer() {
    _simTimer?.cancel();
    _pollTimer?.cancel();
    _simTimer = null;
    _pollTimer = null;
  }
}
