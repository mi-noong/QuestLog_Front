import 'dart:convert';
import 'dart:core';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

import 'config/vision_config.dart';

class AuthenticationExercise extends StatefulWidget {
  const AuthenticationExercise({super.key});

  @override
  State<AuthenticationExercise> createState() => _AuthenticationExerciseState();
}

class _AuthenticationExerciseState extends State<AuthenticationExercise> {
  final ImagePicker _picker = ImagePicker();

  // Equipment verification
  File? _equipmentImage;
  bool _isVerifyingEquipment = false;
  bool? _equipmentVerified;
  String? _equipmentMessage;

  static const Set<String> _equipmentLabels = {
    'dumbbell',
    'barbell',
    'kettlebell',
    'treadmill',
    'exercise machine',
    'gym',
    'bicycle',
    'stationary bicycle',
    'yoga mat',
    'jump rope',
    'rowing machine',
    'bench',
    'elliptical trainer',
  };

  // Step verification
  Stream<StepCount>? _stepCountStream;
  int? _baselineSteps;
  int _currentSteps = 0;
  bool _isCounting = false;
  bool? _stepsVerified;
  String? _stepsMessage;
  int _stepGoal = 100; // user-configurable threshold
  final TextEditingController _goalController = TextEditingController(text: '100');

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _goalController.dispose();
    super.dispose();
  }

  Future<void> _requestActivityPermission() async {
    final status = await Permission.activityRecognition.request();
    if (!status.isGranted) {
      setState(() {
        _stepsMessage = '걸음 수 접근 권한이 필요합니다.';
      });
    }
  }

  Future<void> _captureEquipmentPhoto() async {
    setState(() {
      _equipmentMessage = null;
      _equipmentVerified = null;
    });

    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 85,
    );
    if (image == null) return;

    setState(() {
      _equipmentImage = File(image.path);
    });

    await _verifyEquipmentWithVision(_equipmentImage!);
  }

  Future<void> _verifyEquipmentWithVision(File imageFile) async {
    setState(() {
      _isVerifyingEquipment = true;
      _equipmentMessage = null;
      _equipmentVerified = null;
    });

    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      final body = {
        'requests': [
          {
            'image': {'content': base64Image},
            'features': [
              {'type': 'LABEL_DETECTION', 'maxResults': 15},
            ],
          }
        ]
      };

      final resp = await http.post(
        Uri.parse(VisionConfig.endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (resp.statusCode != 200) {
        setState(() {
          _equipmentVerified = false;
          _equipmentMessage = '인증 실패: Vision API 오류 (${resp.statusCode}).';
        });
        return;
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final responses = (data['responses'] as List?) ?? [];
      final Map<String, dynamic>? firstResponse =
          responses.isNotEmpty ? responses.first as Map<String, dynamic> : null;
      final labelAnnotations = ((firstResponse?['labelAnnotations'] as List?) ?? [])
          .cast<Map<String, dynamic>>();

      final matches = <String>[];
      for (final l in labelAnnotations) {
        final d = (l['description'] as String?)?.toLowerCase().trim();
        if (d == null) continue;
        if (_equipmentLabels.contains(d)) {
          matches.add(d);
        }
      }

      final ok = matches.isNotEmpty;
      setState(() {
        _equipmentVerified = ok;
        _equipmentMessage = ok
            ? '인증 완료: ${matches.join(', ')}'
            : '인증 실패: 운동기구로 인식되지 않았습니다.';
      });
    } catch (e) {
      setState(() {
        _equipmentVerified = false;
        _equipmentMessage = '인증 실패: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isVerifyingEquipment = false;
      });
    }
  }

  Future<void> _startStepCounting() async {
    await _requestActivityPermission();
    if (!await Permission.activityRecognition.isGranted) return;

    setState(() {
      _stepsVerified = null;
      _stepsMessage = null;
      _isCounting = true;
      _baselineSteps = null;
      _currentSteps = 0;
    });

    _stepCountStream = Pedometer.stepCountStream;
    _stepCountStream!.listen((event) {
      // event.steps is total since boot; use baseline to compute session delta
      if (_baselineSteps == null) {
        _baselineSteps = event.steps;
      }
      final delta = event.steps - (_baselineSteps ?? event.steps);
      setState(() {
        _currentSteps = delta;
        if (_currentSteps >= _stepGoal) {
          _stepsVerified = true;
          _stepsMessage = '인증 완료: $_currentSteps / $_stepGoal 걸음';
        }
      });
    }, onError: (error) {
      setState(() {
        _stepsMessage = '걸음 수 측정 오류: $error';
        _isCounting = false;
      });
    });
  }

  void _stopStepCounting() {
    setState(() {
      _isCounting = false;
      if ((_stepsVerified ?? false) == false) {
        _stepsMessage = '인증 실패: 목표 걸음 수 미달 ($_currentSteps / $_stepGoal)';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(title: const Text('운동 인증')),
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
                          '운동 인증',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
            // Equipment section
            Text('운동기구 인증', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_equipmentImage != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(_equipmentImage!, height: 200, fit: BoxFit.cover),
              )
            else
              Container(
                height: 200,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('운동기구 사진을 촬영하세요'),
              ),
                        const SizedBox(height: 8),
                        AbsorbPointer(
                          absorbing: _isVerifyingEquipment,
                          child: Opacity(
                            opacity: _isVerifyingEquipment ? 0.6 : 1,
                            child: GestureDetector(
                              onTap: _isVerifyingEquipment ? null : _captureEquipmentPhoto,
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
                                      '카메라로 인증하기',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
            if (_isVerifyingEquipment) const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Center(child: CircularProgressIndicator()),
            ),
            if (_equipmentMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _ResultBanner(
                  success: _equipmentVerified == true,
                  message: _equipmentMessage!,
                ),
              ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),

            // Steps section
            Text('걸음수 인증', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                    controller: _goalController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '목표 걸음수',
                      hintText: '예: 1000',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: () {
                    final text = _goalController.text.trim();
                    final parsed = int.tryParse(text);
                    if (parsed == null || parsed <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('유효한 양의 정수를 입력하세요.')),
                      );
                      return;
                    }
                    setState(() {
                      _stepGoal = parsed;
                      // 재평가
                      if (_currentSteps >= _stepGoal) {
                        _stepsVerified = true;
                        _stepsMessage = '인증 완료: $_currentSteps / $_stepGoal 걸음';
                      } else if (_isCounting) {
                        _stepsVerified = null;
                        _stepsMessage = null;
                      }
                    });
                              },
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
                                    child: Text('설정', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('목표: $_stepGoal 걸음'),
                const Spacer(),
                Text('현재: $_currentSteps 걸음'),
              ],
            ),
            const SizedBox(height: 8),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: AbsorbPointer(
                                absorbing: _isCounting,
                                child: Opacity(
                                  opacity: _isCounting ? 0.6 : 1,
                                  child: GestureDetector(
                                    onTap: _isCounting ? null : _startStepCounting,
                                    child: SizedBox(
                                      height: 50,
                                      width: 100,
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
                                            '시작',
                                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: AbsorbPointer(
                                absorbing: !_isCounting,
                                child: Opacity(
                                  opacity: !_isCounting ? 0.6 : 1,
                                  child: GestureDetector(
                                    onTap: _isCounting ? _stopStepCounting : null,
                                    child: SizedBox(
                                      width: 100,
                                      height: 50,
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
                                            '중지',
                                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
            if (_stepsMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _ResultBanner(
                  success: _stepsVerified == true,
                  message: _stepsMessage!,
                ),
              ),
            
            // 인증 완료 시 돌아가기 버튼
            if (_equipmentVerified == true || _stepsVerified == true)
              Padding(
                padding: const EdgeInsets.only(top: 30),
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
      ),
    );
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

