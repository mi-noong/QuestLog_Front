import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geocoding;

class AuthenticationWork extends StatefulWidget {
  const AuthenticationWork({super.key});

  @override
  State<AuthenticationWork> createState() => _AuthenticationWorkState();
}

class _AuthenticationWorkState extends State<AuthenticationWork> {
  final TextEditingController _addressController = TextEditingController();
  static const int _fixedRadiusMeters = 200;

  // Button sizes removed; using fixed horizontal buttons

  String? _message;
  bool? _verified; // true=success, false=fail

  // Geocoded company location
  double? _companyLat;
  double? _companyLng;

  // Current user location
  double? _userLat;
  double? _userLng;

  bool _isGeocoding = false;
  bool _isGettingLocation = false;

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _ensureLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
      throw Exception('위치 권한이 필요합니다. 설정에서 권한을 허용해주세요.');
    }
  }

  Future<void> _geocodeCompanyAddress() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) {
      setState(() {
        _verified = false;
        _message = '회사 주소를 입력하세요.';
      });
      return;
    }
    setState(() {
      _isGeocoding = true;
      _verified = null;
      _message = null;
    });
    try {
      final results = await geocoding.locationFromAddress(address);
      if (results.isEmpty) {
        setState(() {
          _verified = false;
          _message = '주소를 찾을 수 없습니다.';
        });
        return;
      }
      final loc = results.first;
      setState(() {
        _companyLat = loc.latitude;
        _companyLng = loc.longitude;
        _verified = null; // 주소 변환만으로는 인증 완료가 아님
        _message = null; // 주소 변환 완료 메시지 제거
      });
    } catch (e) {
      setState(() {
        _verified = false;
        _message = '주소 변환 중 오류: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isGeocoding = false;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
      _message = null;
      _verified = null;
    });
    try {
      await _ensureLocationPermission();
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _userLat = pos.latitude;
        _userLng = pos.longitude;
      });
    } catch (e) {
      setState(() {
        _verified = false;
        _message = '현재 위치 확인 실패: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isGettingLocation = false;
      });
    }
  }

  void _verifyWithinRadius() {
    const int radiusMeters = _fixedRadiusMeters;

    if (_companyLat == null || _companyLng == null) {
      setState(() {
        _verified = false;
        _message = '회사 위치를 먼저 설정하세요.';
      });
      return;
    }
    if (_userLat == null || _userLng == null) {
      setState(() {
        _verified = false;
        _message = '현재 위치를 먼저 확인하세요.';
      });
      return;
    }
    final distance = Geolocator.distanceBetween(
      _companyLat!,
      _companyLng!,
      _userLat!,
      _userLng!,
    );

    final success = distance <= radiusMeters;
    setState(() {
      _verified = success;
      _message = success
          ? '인증 완료: 거리 ${(distance).toStringAsFixed(1)} m (반경 $radiusMeters m)'
          : '인증 실패: 거리 ${(distance).toStringAsFixed(1)} m (반경 $radiusMeters m)';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(title: const Text('근무지 인증')),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/GridScreen.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 480),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 6)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '근무지 인증',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: '회사 주소',
                      hintText: '예: 서울특별시 ...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 33),
                AbsorbPointer(
                  absorbing: _isGeocoding,
                  child: Opacity(
                    opacity: _isGeocoding ? 0.6 : 1,
                    child: GestureDetector(
                      onTap: _isGeocoding ? null : _geocodeCompanyAddress,
                      child: SizedBox(
                        height: 44,
                        width: 110,
                        child: Container(
                          decoration: BoxDecoration(
                            image: const DecorationImage(
                              image: AssetImage('assets/images/StoreBuy_OK_Button.png'),
                              fit: BoxFit.cover,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Text(
                              '주소 변환',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
                        const SizedBox(height: 24),
            Row(
              children: [
                AbsorbPointer(
                  absorbing: _isGettingLocation,
                  child: Opacity(
                    opacity: _isGettingLocation ? 0.6 : 1,
                    child: GestureDetector(
                      onTap: _isGettingLocation ? null : _getCurrentLocation,
                      child: SizedBox(
                        height: 75,
                        width: 290,
                        child: Container(
                          decoration: BoxDecoration(
                            image: const DecorationImage(
                              image: AssetImage('assets/images/MainButton.png'),
                              fit: BoxFit.cover,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Text(
                              '현재 위치',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
                        const SizedBox(height: 16),
            if (_companyLat != null && _companyLng != null)
              Text('회사 좌표: ${_companyLat!.toStringAsFixed(5)}, ${_companyLng!.toStringAsFixed(5)}'),
            if (_userLat != null && _userLng != null)
              Text('내 위치: ${_userLat!.toStringAsFixed(5)}, ${_userLng!.toStringAsFixed(5)}'),
                        const SizedBox(height: 12),
                        const Text(
                          '인증 반경: 200 m',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),

                        const SizedBox(height: 20),
            GestureDetector(
              onTap: _verifyWithinRadius,
              child: SizedBox(
                height: 75,
                width: 290,
                child: Container(
                  decoration: BoxDecoration(
                    image: const DecorationImage(
                      image: AssetImage('assets/images/MainButton.png'),
                      fit: BoxFit.cover,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      '인증하기',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                    ),
                  ),
                ),
              ),
            ),

                        if (_message != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: _ResultBanner(
                              success: _verified == true,
                              message: _message!,
                            ),
                          ),
                        
                        // 인증 완료 시 돌아가기 버튼 (인증하기 버튼을 눌러서 인증 성공했을 때만)
                        if (_verified == true && _message != null && _message!.contains('인증 완료'))
                          Padding(
                            padding: const EdgeInsets.only(top: 20),
                            child: GestureDetector(
                              onTap: () {
                                Navigator.of(context).pop(true); // 인증 완료 결과 반환
                              },
                              child: SizedBox(
                                height: 75,
                                width: 290,
                                child: Container(
                                  decoration: BoxDecoration(
                                    image: const DecorationImage(
                                      image: AssetImage('assets/images/MainButton.png'),
                                      fit: BoxFit.cover,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      '인증 완료',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

            
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ));
  }
}

class _ResultBanner extends StatelessWidget {
  final bool success;
  final String message;

  const _ResultBanner({required this.success, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: success ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: success ? Colors.green : Colors.red),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(success ? Icons.check_circle : Icons.error, color: success ? Colors.green : Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: success ? Colors.green.shade800 : Colors.red.shade800),
            ),
          ),
        ],
      ),
    );
  }
}


