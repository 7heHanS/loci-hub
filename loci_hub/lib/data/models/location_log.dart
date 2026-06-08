class LocationLog {
  final int? id;
  final String journalDate;
  final int timestamp; // UTC Epoch seconds
  final double latitude;
  final double longitude;
  final double accuracy;
  final double altitude;
  final double speed;
  final double heading;
  final String provider;
  final String activityType; // stationary|walking|vehicle
  final int createdAt; // UTC Epoch seconds when inserted

  LocationLog({
    this.id,
    required this.journalDate,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.altitude,
    required this.speed,
    required this.heading,
    required this.provider,
    required this.activityType,
    required this.createdAt,
  });

  LocationLog copyWith({
    int? id,
    String? journalDate,
    int? timestamp,
    double? latitude,
    double? longitude,
    double? accuracy,
    double? altitude,
    double? speed,
    double? heading,
    String? provider,
    String? activityType,
    int? createdAt,
  }) {
    return LocationLog(
      id: id ?? this.id,
      journalDate: journalDate ?? this.journalDate,
      timestamp: timestamp ?? this.timestamp,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracy: accuracy ?? this.accuracy,
      altitude: altitude ?? this.altitude,
      speed: speed ?? this.speed,
      heading: heading ?? this.heading,
      provider: provider ?? this.provider,
      activityType: activityType ?? this.activityType,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'journal_date': journalDate,
      'timestamp': timestamp,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'altitude': altitude,
      'speed': speed,
      'heading': heading,
      'provider': provider,
      'activity_type': activityType,
      'created_at': createdAt,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  factory LocationLog.fromMap(Map<String, dynamic> map) {
    return LocationLog(
      id: map['id'] as int?,
      journalDate: map['journal_date'] as String,
      timestamp: map['timestamp'] as int,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      accuracy: (map['accuracy'] as num).toDouble(),
      altitude: (map['altitude'] as num).toDouble(),
      speed: (map['speed'] as num).toDouble(),
      heading: (map['heading'] as num).toDouble(),
      provider: map['provider'] as String,
      activityType: map['activity_type'] as String,
      createdAt: map['created_at'] as int,
    );
  }

  @override
  String toString() {
    return 'LocationLog(id: $id, journalDate: $journalDate, timestamp: $timestamp, lat: $latitude, lng: $longitude, acc: $accuracy, speed: $speed, activity: $activityType)';
  }
}
