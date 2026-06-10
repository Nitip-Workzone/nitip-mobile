import '../models/trip_model.dart';

abstract class TripRepository {
  Future<List<TripModel>> getMyTrips();
  Future<TripModel> createTrip(Map<String, dynamic> data);
  Future<void> startTrip(String id);
  Future<void> cancelTrip(String id);
  Future<void> completeTrip(String id);
}
