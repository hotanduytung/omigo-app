class TripRequest {
  final String? id;
  final String userName;
  final String phoneNumber;
  final String pickupSpecificPoint;
  final String dropoffSpecificPoint;
  final int requestedSeatCount;
  final String origin;
  final String destination;
  final String requestedDepartureTime;
  final String source;
  final String bookingSource;
  final String serviceType;
  final String createdByType;
  final String? createdByName;
  final String? matchedTripConfigId;
  final String? matchedTimeSlotId;
  final String? assignedDriverId;
  final String? assignedDriverName;
  final String? assignedDriverPhone;
  final String? assignedVehicleType;
  final String? assignedLicensePlate;
  final double appliedFixedPrice;
  final String status;

  TripRequest({
    this.id,
    required this.userName,
    required this.phoneNumber,
    required this.pickupSpecificPoint,
    required this.dropoffSpecificPoint,
    required this.requestedSeatCount,
    required this.origin,
    required this.destination,
    required this.requestedDepartureTime,
    required this.source,
    required this.bookingSource,
    required this.serviceType,
    required this.createdByType,
    this.createdByName,
    this.matchedTripConfigId,
    this.matchedTimeSlotId,
    this.assignedDriverId,
    this.assignedDriverName,
    this.assignedDriverPhone,
    this.assignedVehicleType,
    this.assignedLicensePlate,
    required this.appliedFixedPrice,
    required this.status,
  });

  TripRequest copyWith({
    String? id,
    String? userName,
    String? phoneNumber,
    String? pickupSpecificPoint,
    String? dropoffSpecificPoint,
    int? requestedSeatCount,
    String? origin,
    String? destination,
    String? requestedDepartureTime,
    String? source,
    String? bookingSource,
    String? serviceType,
    String? createdByType,
    String? createdByName,
    String? matchedTripConfigId,
    String? matchedTimeSlotId,
    String? assignedDriverId,
    String? assignedDriverName,
    String? assignedDriverPhone,
    String? assignedVehicleType,
    String? assignedLicensePlate,
    double? appliedFixedPrice,
    String? status,
  }) {
    return TripRequest(
      id: id ?? this.id,
      userName: userName ?? this.userName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      pickupSpecificPoint: pickupSpecificPoint ?? this.pickupSpecificPoint,
      dropoffSpecificPoint: dropoffSpecificPoint ?? this.dropoffSpecificPoint,
      requestedSeatCount: requestedSeatCount ?? this.requestedSeatCount,
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      requestedDepartureTime: requestedDepartureTime ?? this.requestedDepartureTime,
      source: source ?? this.source,
      bookingSource: bookingSource ?? this.bookingSource,
      serviceType: serviceType ?? this.serviceType,
      createdByType: createdByType ?? this.createdByType,
      createdByName: createdByName ?? this.createdByName,
      matchedTripConfigId: matchedTripConfigId ?? this.matchedTripConfigId,
      matchedTimeSlotId: matchedTimeSlotId ?? this.matchedTimeSlotId,
      assignedDriverId: assignedDriverId ?? this.assignedDriverId,
      assignedDriverName: assignedDriverName ?? this.assignedDriverName,
      assignedDriverPhone: assignedDriverPhone ?? this.assignedDriverPhone,
      assignedVehicleType: assignedVehicleType ?? this.assignedVehicleType,
      assignedLicensePlate: assignedLicensePlate ?? this.assignedLicensePlate,
      appliedFixedPrice: appliedFixedPrice ?? this.appliedFixedPrice,
      status: status ?? this.status,
    );
  }

  factory TripRequest.fromJson(Map<String, dynamic> json) {
    final driverTrip = json['driverTrip'];
    return TripRequest(
      id: json['id'] ?? json['_id'],
      userName: json['userName'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      pickupSpecificPoint: json['pickupSpecificPoint'] ?? '',
      dropoffSpecificPoint: json['dropoffSpecificPoint'] ?? '',
      requestedSeatCount: (json['requestedSeatCount'] as num?)?.toInt() ?? 1,
      origin: json['origin'] ?? '',
      destination: json['destination'] ?? '',
      requestedDepartureTime: json['requestedDepartureTime'] ?? '',
      source: json['source'] ?? 'app',
      bookingSource: json['bookingSource'] ?? 'web',
      serviceType: json['serviceType'] ?? 'xe-ghep',
      createdByType: json['createdByType'] ?? 'user',
      createdByName: json['createdByName'],
      matchedTripConfigId: json['matchedTripConfigId'],
      matchedTimeSlotId: json['matchedTimeSlotId'],
      assignedDriverId: json['assignedDriverId'],
      assignedDriverName: json['assignedDriverName'] ?? (driverTrip != null ? driverTrip['driverName'] : null),
      assignedDriverPhone: json['assignedDriverPhone'] ?? (driverTrip != null ? driverTrip['driverPhone'] : null),
      assignedVehicleType: json['assignedVehicleType'] ?? (driverTrip != null ? driverTrip['vehicleType'] : null),
      assignedLicensePlate: json['assignedLicensePlate'] ?? (driverTrip != null ? driverTrip['licensePlate'] : null),
      appliedFixedPrice: (json['appliedFixedPrice'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'new',
    );
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'userName': userName,
      'phoneNumber': phoneNumber,
      'pickupSpecificPoint': pickupSpecificPoint,
      'dropoffSpecificPoint': dropoffSpecificPoint,
      'requestedSeatCount': requestedSeatCount,
      'origin': origin,
      'destination': destination,
      'requestedDepartureTime': requestedDepartureTime,
      'source': source,
      'bookingSource': bookingSource,
      'serviceType': serviceType,
      'createdByType': createdByType,
      'appliedFixedPrice': appliedFixedPrice,
      'status': status,
    };
    if (id != null) data['id'] = id;
    if (createdByName != null) data['createdByName'] = createdByName;
    if (matchedTripConfigId != null) data['matchedTripConfigId'] = matchedTripConfigId;
    if (matchedTimeSlotId != null) data['matchedTimeSlotId'] = matchedTimeSlotId;
    if (assignedDriverId != null) data['assignedDriverId'] = assignedDriverId;
    if (assignedDriverName != null) data['assignedDriverName'] = assignedDriverName;
    if (assignedDriverPhone != null) data['assignedDriverPhone'] = assignedDriverPhone;
    if (assignedVehicleType != null) data['assignedVehicleType'] = assignedVehicleType;
    if (assignedLicensePlate != null) data['assignedLicensePlate'] = assignedLicensePlate;
    return data;
  }
}
