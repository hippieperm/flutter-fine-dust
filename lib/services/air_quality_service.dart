import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/air_quality.dart';

class AirQualityService {
  // 한국 공공데이터포털 실시간 대기질 정보 API
  // https://www.data.go.kr 에서 API 키 발급 필요
  static const String koreaDataBaseUrl =
      'https://apis.data.go.kr/B552584/ArpltnInforInqireSvc';

  // OpenWeatherMap Air Quality API (백업용)
  static const String openWeatherBaseUrl =
      'https://api.openweathermap.org/data/2.5/air_pollution';

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
  Future<AirQuality> getAirQuality(
    double lat,
    double lon, {
    String? apiKey,
  }) async {
    if (apiKey == null || apiKey.isEmpty) {
      return getSampleAirQuality();
    }

    try {
      final url = Uri.parse(
        '$openWeatherBaseUrl?lat=$lat&lon=$lon&appid=$apiKey',
      );
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

  // 한국 지역인지 확인 (대략적인 범위)
  bool _isKoreaLocation(double lat, double lon) {
    // 한국 좌표 범위: 위도 33.0~38.6, 경도 124.5~132.0
    return lat >= 33.0 && lat <= 38.6 && lon >= 124.5 && lon <= 132.0;
  }

  // 한국 공공데이터포털 API로 대기질 정보 가져오기
  Future<AirQuality> getAirQualityFromKoreaData(
    double lat,
    double lon, {
    required String apiKey,
  }) async {
    try {
      // 한국 지역이 아닌 경우 샘플 데이터 반환
      if (!_isKoreaLocation(lat, lon)) {
        print('한국 지역이 아닙니다. 샘플 데이터를 반환합니다. (위도: $lat, 경도: $lon)');
        final sampleData = await getSampleAirQuality();
        return AirQuality(
          pm25: sampleData.pm25,
          pm10: sampleData.pm10,
          aqi: sampleData.aqi,
          stationName: '한국 지역이 아닙니다 (샘플 데이터)',
          dateTime: sampleData.dateTime,
        );
      }

      // API 키 URL 인코딩 (Decoding된 키를 사용하는 경우)
      final encodedApiKey = Uri.encodeComponent(apiKey);

      // 시도별 실시간 측정정보 API 사용 (더 안정적)
      // 서울, 부산, 대구, 인천, 광주, 대전, 울산, 경기, 강원, 충북, 충남, 전북, 전남, 경북, 경남, 제주, 세종
      String sidoName = _getSidoName(lat, lon);

      // 1단계: 시도별 실시간 측정정보 가져오기
      final dataUrl = Uri.parse(
        '$koreaDataBaseUrl/getCtprvnRltmMesureDnsty?'
        'serviceKey=$encodedApiKey'
        '&returnType=json'
        '&numOfRows=100'
        '&pageNo=1'
        '&sidoName=${Uri.encodeComponent(sidoName)}'
        '&ver=1.0',
      );

      print('대기질 데이터 조회 URL: $dataUrl');
      final dataResponse = await http.get(dataUrl);
      print('대기질 데이터 응답 상태: ${dataResponse.statusCode}');
      print('대기질 데이터 응답 본문: ${dataResponse.body}');

      if (dataResponse.statusCode == 200) {
        final data = json.decode(dataResponse.body);

        // 에러 체크
        final resultCode = data['response']?['header']?['resultCode'];
        if (resultCode != '00' && resultCode != null) {
          final resultMsg =
              data['response']?['header']?['resultMsg'] ?? '알 수 없는 오류';
          print('API 오류: $resultCode - $resultMsg');
          throw Exception('API 오류: $resultMsg');
        }

        final dataItems = data['response']?['body']?['items'] as List?;

        if (dataItems != null && dataItems.isNotEmpty) {
          // 가장 가까운 측정소 찾기 (좌표 기반, 없으면 첫 번째 사용)
          Map<String, dynamic>? nearestStation;
          double minDistance = double.infinity;
          bool hasCoordinates = false;

          for (var item in dataItems) {
            // 좌표 필드 시도 (다양한 필드명 확인)
            double? stationLat = double.tryParse(item['dmX']?.toString() ?? '');
            double? stationLon = double.tryParse(item['dmY']?.toString() ?? '');

            // 다른 필드명도 시도
            if (stationLat == null || stationLon == null) {
              stationLat = double.tryParse(item['lat']?.toString() ?? '');
              stationLon = double.tryParse(item['lon']?.toString() ?? '');
            }

            if (stationLat == null || stationLon == null) {
              stationLat = double.tryParse(item['latitude']?.toString() ?? '');
              stationLon = double.tryParse(item['longitude']?.toString() ?? '');
            }

            // 좌표가 있으면 거리 계산
            if (stationLat != null &&
                stationLon != null &&
                stationLat != 0.0 &&
                stationLon != 0.0) {
              hasCoordinates = true;
              // 거리 계산 (간단한 유클리드 거리)
              final distance =
                  (lat - stationLat) * (lat - stationLat) +
                  (lon - stationLon) * (lon - stationLon);

              if (distance < minDistance) {
                minDistance = distance;
                nearestStation = item;
              }
            }
          }

          // 좌표가 없으면 첫 번째 측정소 사용
          if (!hasCoordinates || nearestStation == null) {
            nearestStation = dataItems[0];
            print('좌표 정보가 없어 첫 번째 측정소를 사용합니다.');
          }

          // null 체크
          if (nearestStation == null) {
            throw Exception('측정소 데이터를 찾을 수 없습니다.');
          }

          final item = nearestStation;
          final stationName = item['stationName']?.toString() ?? '알 수 없음';
          print(
            '선택된 측정소: $stationName, 대기질 데이터: PM2.5=${item['pm25Value']}, PM10=${item['pm10Value']}',
          );

          // PM2.5와 PM10 값 파싱 (- 값 처리)
          String pm25Value = item['pm25Value']?.toString() ?? '-';
          String pm10Value = item['pm10Value']?.toString() ?? '-';

          double pm25 = 0.0;
          double pm10 = 0.0;

          if (pm25Value != '-' && pm25Value.isNotEmpty) {
            pm25 = double.tryParse(pm25Value) ?? 0.0;
          }

          if (pm10Value != '-' && pm10Value.isNotEmpty) {
            pm10 = double.tryParse(pm10Value) ?? 0.0;
          }

          // 데이터 시간 파싱
          String dataTime =
              item['dataTime']?.toString() ?? DateTime.now().toString();
          DateTime dateTime;
          try {
            // "2024-01-15 14:00" 형식
            dateTime = DateFormat('yyyy-MM-dd HH:mm').parse(dataTime);
          } catch (e) {
            dateTime = DateTime.now();
          }

          return AirQuality(
            pm25: pm25,
            pm10: pm10,
            aqi: _calculateAQI(pm25),
            stationName: stationName,
            dateTime: dateTime,
          );
        }
      }

      // 데이터를 찾지 못한 경우 샘플 데이터 반환
      print('측정소 데이터를 찾을 수 없습니다. 샘플 데이터를 반환합니다.');
      final sampleData = await getSampleAirQuality();
      return AirQuality(
        pm25: sampleData.pm25,
        pm10: sampleData.pm10,
        aqi: sampleData.aqi,
        stationName: '데이터 없음 (샘플 데이터)',
        dateTime: sampleData.dateTime,
      );
    } catch (e) {
      print('한국 공공데이터 API 호출 오류: $e');
      // 에러 발생 시 샘플 데이터 반환 (사용자 경험을 위해)
      final sampleData = await getSampleAirQuality();
      return AirQuality(
        pm25: sampleData.pm25,
        pm10: sampleData.pm10,
        aqi: sampleData.aqi,
        stationName: 'API 오류 (샘플 데이터)',
        dateTime: sampleData.dateTime,
      );
    }
  }

  // 위치 기반으로 대기질 정보 가져오기 (기본 메서드)
  Future<AirQuality> getAirQualityByLocation(
    double lat,
    double lon, {
    String? koreaDataApiKey,
    String? openWeatherApiKey,
  }) async {
    // 한국 공공데이터포털 API 우선 사용 (한국 지역인 경우)
    if (koreaDataApiKey != null &&
        koreaDataApiKey.isNotEmpty &&
        _isKoreaLocation(lat, lon)) {
      try {
        final result = await getAirQualityFromKoreaData(
          lat,
          lon,
          apiKey: koreaDataApiKey,
        );
        // 실제 데이터가 있는 경우만 반환
        if (result.pm25 > 0 || result.pm10 > 0) {
          return result;
        }
      } catch (e) {
        print('한국 공공데이터 API 실패, 백업 API 시도: $e');
        // 에러 발생 시 백업 API로 전환
      }
    }

    // OpenWeatherMap API (백업)
    if (openWeatherApiKey != null && openWeatherApiKey.isNotEmpty) {
      final result = await getAirQuality(lat, lon, apiKey: openWeatherApiKey);
      if (result.pm25 > 0) {
        return result;
      }
    }

    // API 키가 없거나 실패한 경우 샘플 데이터 반환
    return getSampleAirQuality();
  }

  // 좌표로부터 시도명 추출
  String _getSidoName(double lat, double lon) {
    // 서울
    if (lat >= 37.4 && lat <= 37.7 && lon >= 126.8 && lon <= 127.2) {
      return '서울';
    }
    // 부산
    if (lat >= 35.0 && lat <= 35.3 && lon >= 129.0 && lon <= 129.3) {
      return '부산';
    }
    // 대구
    if (lat >= 35.7 && lat <= 36.0 && lon >= 128.4 && lon <= 128.7) {
      return '대구';
    }
    // 인천
    if (lat >= 37.4 && lat <= 37.6 && lon >= 126.5 && lon <= 126.8) {
      return '인천';
    }
    // 광주
    if (lat >= 35.1 && lat <= 35.2 && lon >= 126.7 && lon <= 126.9) {
      return '광주';
    }
    // 대전
    if (lat >= 36.2 && lat <= 36.4 && lon >= 127.3 && lon <= 127.5) {
      return '대전';
    }
    // 울산
    if (lat >= 35.4 && lat <= 35.6 && lon >= 129.2 && lon <= 129.4) {
      return '울산';
    }
    // 세종
    if (lat >= 36.4 && lat <= 36.6 && lon >= 127.2 && lon <= 127.4) {
      return '세종';
    }
    // 경기
    if (lat >= 37.0 && lat <= 38.6 && lon >= 126.5 && lon <= 127.8) {
      return '경기';
    }
    // 강원
    if (lat >= 37.0 && lat <= 38.6 && lon >= 127.0 && lon <= 129.0) {
      return '강원';
    }
    // 충북
    if (lat >= 36.0 && lat <= 37.0 && lon >= 127.0 && lon <= 128.5) {
      return '충북';
    }
    // 충남
    if (lat >= 36.0 && lat <= 37.0 && lon >= 126.0 && lon <= 127.5) {
      return '충남';
    }
    // 전북
    if (lat >= 35.0 && lat <= 36.0 && lon >= 126.5 && lon <= 127.5) {
      return '전북';
    }
    // 전남
    if (lat >= 34.0 && lat <= 35.5 && lon >= 125.0 && lon <= 127.0) {
      return '전남';
    }
    // 경북
    if (lat >= 35.5 && lat <= 37.0 && lon >= 128.0 && lon <= 130.0) {
      return '경북';
    }
    // 경남
    if (lat >= 34.5 && lat <= 35.5 && lon >= 127.5 && lon <= 129.5) {
      return '경남';
    }
    // 제주
    if (lat >= 33.0 && lat <= 33.6 && lon >= 126.0 && lon <= 127.0) {
      return '제주';
    }

    // 기본값: 서울
    return '서울';
  }

  int _calculateAQI(double pm25) {
    if (pm25 <= 15) return 1;
    if (pm25 <= 35) return 2;
    if (pm25 <= 75) return 3;
    return 4;
  }
}
