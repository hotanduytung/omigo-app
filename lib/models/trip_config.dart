class TripTimeSlot {
  final String departureTime;
  final String arrivalTime;
  final double fixedPrice;
  final String status;

  TripTimeSlot({
    required this.departureTime,
    required this.arrivalTime,
    required this.fixedPrice,
    required this.status,
  });

  factory TripTimeSlot.fromJson(Map<String, dynamic> json) {
    return TripTimeSlot(
      departureTime: json['departureTime'] ?? '',
      arrivalTime: json['arrivalTime'] ?? '',
      fixedPrice: (json['fixedPrice'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'active',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'departureTime': departureTime,
      'arrivalTime': arrivalTime,
      'fixedPrice': fixedPrice,
      'status': status,
    };
  }
}

class TripConfig {
  final String? id;
  final String origin;
  final String destination;
  final String status;
  final List<TripTimeSlot> timeSlots;

  TripConfig({
    this.id,
    required this.origin,
    required this.destination,
    required this.status,
    required this.timeSlots,
  });

  factory TripConfig.fromJson(Map<String, dynamic> json) {
    var list = json['timeSlots'] as List? ?? [];
    List<TripTimeSlot> slots = list.map((i) => TripTimeSlot.fromJson(i)).toList();

    return TripConfig(
      id: json['id'] ?? json['_id'],
      origin: json['origin'] ?? '',
      destination: json['destination'] ?? '',
      status: json['status'] ?? 'active',
      timeSlots: slots,
    );
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'origin': origin,
      'destination': destination,
      'status': status,
      'timeSlots': timeSlots.map((e) => e.toJson()).toList(),
    };
    if (id != null) data['id'] = id;
    return data;
  }
}
