import 'package:geolocator/geolocator.dart';

class LocationService {
  // 위치 권한 확인 및 요청
  Future<bool> checkAndRequestPermission() async {
    // 위치 서비스가 활성화되어 있는지 확인
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    // 권한 상태 확인
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  // 현재 위치 가져오기
  Future<Position?> getCurrentPosition() async {
    try {
      bool hasPermission = await checkAndRequestPermission();
      if (!hasPermission) {
        return null;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      return position;
    } catch (e) {
      print('위치 가져오기 오류: $e');
      return null;
    }
  }

  // 위치 권한이 영구적으로 거부되었는지 확인
  Future<bool> isPermissionPermanentlyDenied() async {
    LocationPermission permission = await Geolocator.checkPermission();
    return permission == LocationPermission.deniedForever;
  }
}
