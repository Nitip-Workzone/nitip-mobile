class TripModel {
  final String id;
  final String runnerId;
  final String originName;
  final double originLat;
  final double originLng;
  final String destinationName;
  final double destinationLat;
  final double destinationLng;
  final DateTime departureTime;
  final DateTime? returnTime;
  final bool isRoundTrip;
  final String status;
  final String? notes;
  final double maxWeightKg;
  final double availableWeightKg;
  final double maxVolumeLiters;
  final double availableVolumeLiters;
  final String vehicleType;
  final DateTime createdAt;

  TripModel({
    required this.id,
    required this.runnerId,
    required this.originName,
    required this.originLat,
    required this.originLng,
    required this.destinationName,
    required this.destinationLat,
    required this.destinationLng,
    required this.departureTime,
    this.returnTime,
    this.isRoundTrip = false,
    required this.status,
    this.notes,
    this.maxWeightKg = 0.0,
    this.availableWeightKg = 0.0,
    this.maxVolumeLiters = 0.0,
    this.availableVolumeLiters = 0.0,
    this.vehicleType = 'motorcycle',
    required this.createdAt,
  });

  factory TripModel.fromJson(Map<String, dynamic> json) {
    return TripModel(
      id: json['id'] ?? '',
      runnerId: json['runner_id'] ?? '',
      originName: json['origin_name'] ?? '',
      originLat: (json['origin_lat'] as num?)?.toDouble() ?? 0.0,
      originLng: (json['origin_lng'] as num?)?.toDouble() ?? 0.0,
      destinationName: json['destination_name'] ?? '',
      destinationLat: (json['destination_lat'] as num?)?.toDouble() ?? 0.0,
      destinationLng: (json['destination_lng'] as num?)?.toDouble() ?? 0.0,
      departureTime: json['departure_time'] != null
          ? DateTime.parse(json['departure_time']).toLocal()
          : DateTime.now(),
      returnTime: json['return_time'] != null
          ? DateTime.parse(json['return_time']).toLocal()
          : null,
      isRoundTrip: json['is_round_trip'] ?? false,
      status: json['status'] ?? 'active',
      notes: json['notes'],
      maxWeightKg: (json['max_weight_kg'] as num?)?.toDouble() ?? 0.0,
      availableWeightKg: (json['available_weight_kg'] as num?)?.toDouble() ?? 0.0,
      maxVolumeLiters: (json['max_volume_liters'] as num?)?.toDouble() ?? 0.0,
      availableVolumeLiters: (json['available_volume_liters'] as num?)?.toDouble() ?? 0.0,
      vehicleType: json['vehicle_type'] ?? 'motorcycle',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at']).toLocal()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'runner_id': runnerId,
      'origin_name': originName,
      'origin_lat': originLat,
      'origin_lng': originLng,
      'destination_name': destinationName,
      'destination_lat': destinationLat,
      'destination_lng': destinationLng,
      'departure_time': departureTime.toUtc().toIso8601String(),
      if (returnTime != null) 'return_time': returnTime!.toUtc().toIso8601String(),
      'is_round_trip': isRoundTrip,
      'status': status,
      'notes': notes,
      'max_weight_kg': maxWeightKg,
      'available_weight_kg': availableWeightKg,
      'max_volume_liters': maxVolumeLiters,
      'available_volume_liters': availableVolumeLiters,
      'vehicle_type': vehicleType,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  TripModel copyWith({
    String? id,
    String? runnerId,
    String? originName,
    double? originLat,
    double? originLng,
    String? destinationName,
    double? destinationLat,
    double? destinationLng,
    DateTime? departureTime,
    DateTime? returnTime,
    bool? isRoundTrip,
    String? status,
    String? notes,
    double? maxWeightKg,
    double? availableWeightKg,
    double? maxVolumeLiters,
    double? availableVolumeLiters,
    String? vehicleType,
    DateTime? createdAt,
  }) {
    return TripModel(
      id: id ?? this.id,
      runnerId: runnerId ?? this.runnerId,
      originName: originName ?? this.originName,
      originLat: originLat ?? this.originLat,
      originLng: originLng ?? this.originLng,
      destinationName: destinationName ?? this.destinationName,
      destinationLat: destinationLat ?? this.destinationLat,
      destinationLng: destinationLng ?? this.destinationLng,
      departureTime: departureTime ?? this.departureTime,
      returnTime: returnTime ?? this.returnTime,
      isRoundTrip: isRoundTrip ?? this.isRoundTrip,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      maxWeightKg: maxWeightKg ?? this.maxWeightKg,
      availableWeightKg: availableWeightKg ?? this.availableWeightKg,
      maxVolumeLiters: maxVolumeLiters ?? this.maxVolumeLiters,
      availableVolumeLiters: availableVolumeLiters ?? this.availableVolumeLiters,
      vehicleType: vehicleType ?? this.vehicleType,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
