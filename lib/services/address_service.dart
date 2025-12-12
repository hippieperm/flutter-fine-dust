import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AddressService {
  // 카카오맵 역지오코딩 API 사용 (더 정확한 한국 주소)
  Future<String> getAddressFromKakao(double latitude, double longitude) async {
    try {
      // 카카오맵 REST API 키가 필요합니다 (선택사항)
      // https://developers.kakao.com 에서 발급 가능
      const String? kakaoApiKey = null; // 여기에 카카오맵 API 키 입력

      if (kakaoApiKey != null && kakaoApiKey.isNotEmpty) {
        final url = Uri.parse(
          'https://dapi.kakao.com/v2/local/geo/coord2address.json?'
          'x=$longitude&y=$latitude',
        );

        final response = await http.get(
          url,
          headers: {'Authorization': 'KakaoAK $kakaoApiKey'},
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final documents = data['documents'] as List?;

          if (documents != null && documents.isNotEmpty) {
            final address = documents[0]['address'];
            if (address != null) {
              // 시/도 시/군/구 동 형식으로 조합
              String sido = address['region_1depth_name'] ?? '';
              String sigungu = address['region_2depth_name'] ?? '';
              String dong = address['region_3depth_name'] ?? '';

              String fullAddress = '';
              if (sido.isNotEmpty) fullAddress = sido;
              if (sigungu.isNotEmpty) {
                if (fullAddress.isNotEmpty) fullAddress += ' ';
                fullAddress += sigungu;
              }
              if (dong.isNotEmpty) {
                if (fullAddress.isNotEmpty) fullAddress += ' ';
                fullAddress += dong;
              }

              if (fullAddress.isNotEmpty) {
                print('카카오맵 주소: $fullAddress');
                return fullAddress;
              }
            }
          }
        }
      }
    } catch (e) {
      print('카카오맵 API 오류: $e');
    }

    return '';
  }

  // 좌표를 주소로 변환 (역지오코딩)
  Future<String> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    // 카카오맵 API 우선 시도
    final kakaoAddress = await getAddressFromKakao(latitude, longitude);
    if (kakaoAddress.isNotEmpty) {
      return kakaoAddress;
    }

    // geocoding 패키지 사용 (백업)
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isNotEmpty) {
        final placemark = placemarks[0];

        // 디버깅: 모든 필드 출력
        print('주소 변환 디버깅:');
        print('  administrativeArea: ${placemark.administrativeArea}');
        print('  subAdministrativeArea: ${placemark.subAdministrativeArea}');
        print('  locality: ${placemark.locality}');
        print('  subLocality: ${placemark.subLocality}');
        print('  thoroughfare: ${placemark.thoroughfare}');
        print('  subThoroughfare: ${placemark.subThoroughfare}');
        print('  street: ${placemark.street}');
        print('  name: ${placemark.name}');
        print('  isoCountryCode: ${placemark.isoCountryCode}');

        // 한국 주소 형식: 시/도 시/군/구 동/읍/면
        String address = '';

        // 시/도 (예: 서울특별시, 경기도)
        if (placemark.administrativeArea != null &&
            placemark.administrativeArea!.isNotEmpty) {
          address = placemark.administrativeArea!;
        }

        // 시/군/구 (예: 강남구, 수원시)
        if (placemark.subAdministrativeArea != null &&
            placemark.subAdministrativeArea!.isNotEmpty) {
          if (address.isNotEmpty) address += ' ';
          address += placemark.subAdministrativeArea!;
        }

        // 동/읍/면 (subLocality 우선, 없으면 locality 사용)
        String? dong = placemark.subLocality ?? placemark.locality;
        if (dong != null && dong.isNotEmpty) {
          // 한국어 주소인지 확인
          if (dong.contains('동') ||
              dong.contains('읍') ||
              dong.contains('면') ||
              dong.contains('로') ||
              dong.contains('길') ||
              RegExp(r'[가-힣]').hasMatch(dong)) {
            if (address.isNotEmpty) address += ' ';
            address += dong;
          }
        }

        // 동이 없으면 thoroughfare나 name으로 시도
        if (!address.contains('동') &&
            !address.contains('읍') &&
            !address.contains('면')) {
          String? street = placemark.thoroughfare ?? placemark.name;
          if (street != null && street.isNotEmpty) {
            // 한국어 주소인지 확인
            if (street.contains('동') ||
                street.contains('읍') ||
                street.contains('면') ||
                street.contains('로') ||
                street.contains('길') ||
                RegExp(r'[가-힣]').hasMatch(street)) {
              if (address.isNotEmpty) address += ' ';
              address += street;
            }
          }
        }

        // 주소가 비어있으면 기본값
        if (address.isEmpty) {
          address = '주소 정보 없음';
        }

        print('최종 주소: $address');
        return address;
      }
    } catch (e) {
      print('주소 변환 오류: $e');
    }

    return '주소 정보 없음';
  }
}
