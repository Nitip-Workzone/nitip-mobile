class TrackingState {
  final double lat;
  final double lng;
  final double distance;
  final int eta;
  final String status;
  final bool visible;

  TrackingState({
    required this.lat,
    required this.lng,
    required this.distance,
    required this.eta,
    required this.status,
    required this.visible,
  });

  factory TrackingState.fromJson(Map<String, dynamic> json) {
    return TrackingState(
      lat: (json['lat'] ?? 0.0).toDouble(),
      lng: (json['lng'] ?? 0.0).toDouble(),
      distance: (json['distance'] ?? 0.0).toDouble(),
      eta: (json['eta'] ?? 0).toInt(),
      status: json['status'] ?? 'unknown',
      visible: json['visible'] ?? false,
    );
  }
}
