class TrackingConstants {
  static const int intervalStationarySeconds = 300; // 5 minutes
  static const int intervalWalkingSeconds = 60;     // 1 minute
  static const int intervalVehicleSeconds = 30;     // 30 seconds

  static const double stationaryDistanceThresholdMeters = 30.0;
  static const double stationarySpeedThresholdMs = 0.5; // < 1.8 km/h
  static const double walkingSpeedThresholdMs = 2.0;    // < 7.2 km/h
  static const double accuracyThresholdMeters = 50.0;   // Ignore GPS coordinates with accuracy > 50m
  static const double distanceFilterMeters = 15.0;      // Minimum distance in meters to record new point

  static const int recentSampleCount = 5;
}
