import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'models/air_quality.dart';
import 'services/air_quality_service.dart';
import 'services/location_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '미세먼지 앱',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
      ),
      home: const AirQualityScreen(),
    );
  }
}

class AirQualityScreen extends StatefulWidget {
  const AirQualityScreen({super.key});

  @override
  State<AirQualityScreen> createState() => _AirQualityScreenState();
}

class _AirQualityScreenState extends State<AirQualityScreen>
    with TickerProviderStateMixin {
  final AirQualityService _airQualityService = AirQualityService();
  final LocationService _locationService = LocationService();
  AirQuality? _airQuality;
  bool _isLoading = true;
  String? _errorMessage;
  Position? _currentPosition;
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _pulseAnimation = Tween<double>(begin: 0.97, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));

    _fadeController.forward();
    _loadAirQuality();
  }

  Future<void> _loadAirQuality() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 위치 가져오기
      final position = await _locationService.getCurrentPosition();

      if (position == null) {
        // 위치 권한이 거부된 경우
        final isPermanentlyDenied = await _locationService
            .isPermissionPermanentlyDenied();
        setState(() {
          _isLoading = false;
          _errorMessage = isPermanentlyDenied
              ? '위치 권한이 거부되었습니다.\n설정에서 위치 권한을 허용해주세요.'
              : '위치 정보를 가져올 수 없습니다.\n위치 권한을 허용해주세요.';
        });

        if (mounted && isPermanentlyDenied) {
          _showPermissionDialog();
        }
        return;
      }

      _currentPosition = position;

      // API 키는 여기에 설정하세요
      // 한국 공공데이터포털 API 키: https://www.data.go.kr 에서 발급
      // 1. 공공데이터포털 회원가입 및 로그인
      // 2. "실시간 대기질 정보 조회 서비스" 검색
      // 3. 활용신청 후 인증키 발급
      // ⚠️ 중요: "일반 인증키 (Decoding)"을 복사해서 넣으세요!
      // Encoding이 아닌 Decoding된 키를 사용해야 합니다.
      const String? koreaDataApiKey =
          'qB/mPTTOzHKJtX5QHVm9MnI9hf7ek1EwYgFK6WrAXBXlkVy5df1qh/E0mlPRT/PW0Hhd80Gt2xwWQwKpaPGVYg=='; // 여기에 Decoding된 인증키 입력 (예: 'qB/mPTTOzHKJtX5QHVm9MnI9hf7ek1EwYgFK6WrAXBXlkVy5df1qh/E0mlPRT/PW0Hhd80Gt2xwWQwKpaPGVYg==')

      // OpenWeatherMap API 키 (백업용, 선택사항)
      const String? openWeatherApiKey = null;

      // 위치 기반으로 대기질 정보 가져오기
      final airQuality = await _airQualityService.getAirQualityByLocation(
        position.latitude,
        position.longitude,
        koreaDataApiKey: koreaDataApiKey,
        openWeatherApiKey: openWeatherApiKey,
      );

      setState(() {
        _airQuality = airQuality;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '데이터를 불러오는 중 오류가 발생했습니다: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage ?? '알 수 없는 오류가 발생했습니다'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('위치 권한 필요'),
        content: const Text(
          '정확한 미세먼지 정보를 제공하기 위해 위치 권한이 필요합니다.\n'
          '설정에서 위치 권한을 허용해주세요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await openAppSettings();
            },
            child: const Text('설정 열기'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _airQuality != null
                ? [
                    Color(_airQuality!.statusColor).withOpacity(0.8),
                    Color(_airQuality!.statusColor).withOpacity(0.4),
                    Colors.white,
                  ]
                : [Colors.blue.shade300, Colors.blue.shade100, Colors.white],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red.shade300,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(height: 30),
                        ElevatedButton.icon(
                          onPressed: _loadAirQuality,
                          icon: const Icon(Icons.refresh),
                          label: const Text('다시 시도'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _airQuality == null
              ? const Center(child: Text('데이터를 불러올 수 없습니다'))
              : FadeTransition(
                  opacity: _fadeAnimation,
                  child: RefreshIndicator(
                    onRefresh: _loadAirQuality,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(),
                            const SizedBox(height: 30),
                            _buildMainCard(),
                            const SizedBox(height: 20),
                            _buildDetailCards(),
                            const SizedBox(height: 20),
                            _buildInfoCard(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '미세먼지 현황',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _airQuality?.stationName ?? '위치 정보 없음',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (_currentPosition != null) ...[
                const SizedBox(height: 4),
                Text(
                  '${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.refresh, size: 28),
          onPressed: _loadAirQuality,
          color: Colors.grey.shade700,
        ),
      ],
    );
  }

  Widget _buildMainCard() {
    return ScaleTransition(
      scale: _pulseAnimation,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              _airQuality!.statusEmoji,
              style: const TextStyle(fontSize: 80),
            ),
            const SizedBox(height: 20),
            Text(
              _airQuality!.status,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(_airQuality!.statusColor),
              ),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _airQuality!.pm25.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                    color: Color(_airQuality!.statusColor),
                    height: 1,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 10, left: 5),
                  child: Text(
                    'μg/m³',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'PM2.5',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCards() {
    return Row(
      children: [
        Expanded(
          child: _buildSmallCard(
            title: 'PM10',
            value: _airQuality!.pm10.toStringAsFixed(1),
            unit: 'μg/m³',
            status: _airQuality!.pm10Status,
            color: _getPm10Color(_airQuality!.pm10),
            icon: Icons.air,
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: _buildSmallCard(
            title: 'AQI',
            value: _airQuality!.aqi.toString(),
            unit: '',
            status: _getAqiStatus(_airQuality!.aqi),
            color: _airQuality!.statusColor,
            icon: Icons.assessment,
          ),
        ),
      ],
    );
  }

  Widget _buildSmallCard({
    required String title,
    required String value,
    required String unit,
    required String status,
    required int color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Color(color), size: 24),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(color),
                  height: 1,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(
                    unit,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            status,
            style: TextStyle(
              fontSize: 14,
              color: Color(color),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text(
                '업데이트 시간',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            DateFormat('yyyy년 MM월 dd일 HH:mm').format(_airQuality!.dateTime),
            style: TextStyle(fontSize: 18, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 20),
          Divider(color: Colors.grey.shade300),
          const SizedBox(height: 15),
          _buildRecommendation(),
        ],
      ),
    );
  }

  Widget _buildRecommendation() {
    String recommendation;
    IconData icon;
    Color color;

    if (_airQuality!.pm25 <= 15) {
      recommendation = '공기질이 좋습니다! 산책하기 좋은 날이에요. 🌳';
      icon = Icons.check_circle;
      color = Colors.green;
    } else if (_airQuality!.pm25 <= 35) {
      recommendation = '보통 수준입니다. 일반적인 활동은 괜찮습니다.';
      icon = Icons.info;
      color = Colors.orange;
    } else if (_airQuality!.pm25 <= 75) {
      recommendation = '미세먼지가 나쁩니다. 외출 시 마스크를 착용하세요. 😷';
      icon = Icons.warning;
      color = Colors.orange.shade700;
    } else {
      recommendation = '매우 나쁩니다! 외출을 자제하고 창문을 닫으세요. 🚫';
      icon = Icons.error;
      color = Colors.red;
    }

    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            recommendation,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  int _getPm10Color(double pm10) {
    if (pm10 <= 30) return 0xFF4CAF50;
    if (pm10 <= 80) return 0xFF8BC34A;
    if (pm10 <= 150) return 0xFFFF9800;
    return 0xFFF44336;
  }

  String _getAqiStatus(int aqi) {
    switch (aqi) {
      case 1:
        return '좋음';
      case 2:
        return '보통';
      case 3:
        return '나쁨';
      case 4:
        return '매우나쁨';
      default:
        return '알 수 없음';
    }
  }
}
