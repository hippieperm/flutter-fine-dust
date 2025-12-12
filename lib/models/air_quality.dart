class AirQuality {
  final double pm25;
  final double pm10;
  final int aqi; // Air Quality Index
  final String stationName;
  final DateTime dateTime;

  AirQuality({
    required this.pm25,
    required this.pm10,
    required this.aqi,
    required this.stationName,
    required this.dateTime,
  });

  String get status {
    if (pm25 <= 15) return '좋음';
    if (pm25 <= 35) return '보통';
    if (pm25 <= 75) return '나쁨';
    return '매우나쁨';
  }

  String get statusEmoji {
    if (pm25 <= 15) return '😊';
    if (pm25 <= 35) return '😐';
    if (pm25 <= 75) return '😷';
    return '😱';
  }

  String get pm10Status {
    if (pm10 <= 30) return '좋음';
    if (pm10 <= 80) return '보통';
    if (pm10 <= 150) return '나쁨';
    return '매우나쁨';
  }

  // 미세먼지 수치에 따른 색상
  int get statusColor {
    if (pm25 <= 15) return 0xFF4CAF50; // 초록색
    if (pm25 <= 35) return 0xFF8BC34A; // 연두색
    if (pm25 <= 75) return 0xFFFF9800; // 주황색
    return 0xFFF44336; // 빨간색
  }

  factory AirQuality.fromJson(Map<String, dynamic> json) {
    return AirQuality(
      pm25: (json['pm25'] ?? json['PM25'] ?? 0.0).toDouble(),
      pm10: (json['pm10'] ?? json['PM10'] ?? 0.0).toDouble(),
      aqi: json['aqi'] ?? json['AQI'] ?? 0,
      stationName: json['stationName'] ?? json['station_name'] ?? '알 수 없음',
      dateTime: json['dateTime'] != null
          ? DateTime.parse(json['dateTime'])
          : DateTime.now(),
    );
  }
}


