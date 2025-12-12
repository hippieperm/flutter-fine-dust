import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/air_quality.dart';

class AirQualityService {
  // OpenWeatherMap Air Quality API 사용
  // 실제 사용 시 API 키가 필요합니다
  // 또는 한국 공공데이터포털의 대기질 API를 사용할 수 있습니다
  static const String baseUrl = 'https://api.openweathermap.org/data/2.5/air_pollution';
  
  // 샘플 데이터를 반환하는 메서드 (API 키 없이 테스트용)
  Future<AirQuality> getSampleAirQuality() async {
    // 실제로는 API를 호출하지만, 여기서는 샘플 데이터 반환
    await Future.delayed(const Duration(seconds: 1)); // 네트워크 지연 시뮬레이션
    
    // 랜덤 샘플 데이터 (실제 앱에서는 API에서 가져옴)
    final random = DateTime.now().millisecond % 4;
    double pm25;
    double pm10;
    
    switch (random) {
      case 0:
        pm25 = 12.0;
        pm10 = 25.0;
        break;
      case 1:
        pm25 = 28.0;
        pm10 = 55.0;
        break;
      case 2:
        pm25 = 65.0;
        pm10 = 120.0;
        break;
      default:
        pm25 = 95.0;
        pm10 = 180.0;
    }
    
    return AirQuality(
      pm25: pm25,
      pm10: pm10,
      aqi: _calculateAQI(pm25),
      stationName: '서울시 강남구',
      dateTime: DateTime.now(),
    );
  }

  // 실제 API 호출 메서드 (API 키가 있을 때 사용)
  Future<AirQuality> getAirQuality(double lat, double lon, {String? apiKey}) async {
    if (apiKey == null || apiKey.isEmpty) {
      return getSampleAirQuality();
    }
    
    try {
      final url = Uri.parse('$baseUrl?lat=$lat&lon=$lon&appid=$apiKey');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final list = data['list'] as List;
        if (list.isNotEmpty) {
          final main = list[0]['main'];
          final components = list[0]['components'];
          
          return AirQuality(
            pm25: (components['pm2_5'] ?? 0.0).toDouble(),
            pm10: (components['pm10'] ?? 0.0).toDouble(),
            aqi: main['aqi'] ?? 0,
            stationName: '현재 위치',
            dateTime: DateTime.fromMillisecondsSinceEpoch(
              (list[0]['dt'] ?? 0) * 1000,
            ),
          );
        }
      }
    } catch (e) {
      print('API 호출 오류: $e');
    }
    
    return getSampleAirQuality();
  }

  int _calculateAQI(double pm25) {
    if (pm25 <= 15) return 1;
    if (pm25 <= 35) return 2;
    if (pm25 <= 75) return 3;
    return 4;
  }
}


