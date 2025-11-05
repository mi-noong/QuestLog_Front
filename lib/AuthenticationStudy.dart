import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'config/vision_config.dart';

class AuthenticationStudy extends StatefulWidget {
  const AuthenticationStudy({super.key});

  @override
  State<AuthenticationStudy> createState() => _AuthenticationStudyState();
}

class _AuthenticationStudyState extends State<AuthenticationStudy> {
  final ImagePicker _picker = ImagePicker();

  File? _capturedImage;
  bool _isLoading = false;
  String? _resultMessage;
  bool? _isVerified; // true = success, false = fail, null = not attempted

  static const Set<String> _acceptedLabels = {
    'notebook',
    'paper',
    'document',
    'worksheet',
    'text',
    'handwriting',
    'note',
    'exam',
    'book',
    'page',
  };

  Future<void> _captureWithCamera() async {
    setState(() {
      _resultMessage = null;
      _isVerified = null;
    });

    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 85,
    );

    if (image == null) return;

    setState(() {
      _capturedImage = File(image.path);
    });

    await _analyzeImageAndVerify(File(image.path));
  }

  Future<void> _analyzeImageAndVerify(File imageFile) async {
    setState(() {
      _isLoading = true;
      _resultMessage = null;
      _isVerified = null;
    });

    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      final requestBody = {
        'requests': [
          {
            'image': {'content': base64Image},
            'features': [
              {'type': 'LABEL_DETECTION', 'maxResults': 15},
            ],
          }
        ]
      };

      final response = await http.post(
        Uri.parse(VisionConfig.endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode != 200) {
        setState(() {
          _isVerified = false;
          _resultMessage = '인증 실패: Vision API 오류 (${response.statusCode}).';
        });
        return;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final responses = (data['responses'] as List?) ?? [];
      if (responses.isEmpty) {
        setState(() {
          _isVerified = false;
          _resultMessage = '인증 실패: 분석 결과가 없습니다.';
        });
        return;
      }

      final labels = ((responses.first['labelAnnotations'] as List?) ?? [])
          .cast<Map<String, dynamic>>();

      final matchedLabels = <String>[];
      for (final label in labels) {
        final description = (label['description'] as String?)?.toLowerCase().trim();
        if (description == null) continue;
        if (_acceptedLabels.contains(description)) {
          matchedLabels.add(description);
        }
      }

      final bool success = matchedLabels.isNotEmpty;

      setState(() {
        _isVerified = success;
        _resultMessage = success
            ? '인증 완료: ${matchedLabels.join(', ')}'
            : '인증 실패: 필기노트/문제지로 인식되지 않았습니다.';
      });
    } catch (e) {
      setState(() {
        _isVerified = false;
        _resultMessage = '인증 실패: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: const Text('공부 인증'),
      // ),
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
                          '공부 인증',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
            if (_capturedImage != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  _capturedImage!,
                  height: 220,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                height: 220,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('카메라로 사진을 촬영하세요'),
              ),

                        const SizedBox(height: 16),

                        AbsorbPointer(
                          absorbing: _isLoading,
                          child: Opacity(
                            opacity: _isLoading ? 0.6 : 1,
                            child: GestureDetector(
                              onTap: _isLoading ? null : _captureWithCamera,
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

                        const SizedBox(height: 16),

                        if (_isLoading) const Center(child: CircularProgressIndicator()),

                        if (_resultMessage != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: _isVerified == true
                                  ? Colors.green.shade50
                                  : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _isVerified == true ? Colors.green : Colors.red,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  _isVerified == true ? Icons.check_circle : Icons.error,
                                  color: _isVerified == true ? Colors.green : Colors.red,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _resultMessage!,
                                    style: TextStyle(
                                      color: _isVerified == true ? Colors.green.shade800 : Colors.red.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        
                        // 인증 완료 시 돌아가기 버튼
                        if (_isVerified == true)
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


