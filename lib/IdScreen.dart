import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'IdSuccessScreen.dart';
import 'config/api_config.dart';

class IdScreen extends StatefulWidget {
  const IdScreen({super.key});

  @override
  State<IdScreen> createState() => _IdScreenState();
}

class _IdScreenState extends State<IdScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _verificationCodeController = TextEditingController();
  
  String? _errorMessage;
  bool _isLoading = false;
  bool _isVerificationSent = false;
  bool _showVerificationInput = false;
  String? _verificationMessage;
  bool _isVerificationValid = false;
  String? _foundUserId;

  Future<void> _sendVerificationCode() async {
    if (_nameController.text.isEmpty || _emailController.text.isEmpty) {
      setState(() {
        _errorMessage = '사용자 이름과 이메일을 모두 입력해주세요.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final requestBody = {
        'username': _nameController.text,
        'email': _emailController.text,
      };
      
      print('요청 데이터: $requestBody');
      print('요청 URL: ${ApiConfig.findIdSendCodeEndpoint}');
      
      final response = await http.post(
        Uri.parse(ApiConfig.findIdSendCodeEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));

      print('응답 상태 코드: ${response.statusCode}');
      print('응답 본문: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        setState(() {
          _isVerificationSent = true;
          _showVerificationInput = true;
          _errorMessage = null;
        });
      } else {
        // 서버 응답에서 에러 메시지 파싱 시도
        String errorMessage = '일치하는 사용자가 없습니다.';
        
        try {
          final responseData = jsonDecode(response.body);
          if (responseData['message'] != null) {
            errorMessage = responseData['message'];
          }
        } catch (e) {
          print('응답 파싱 오류: $e');
        }
        
        // 500 에러에 대한 특별 처리
        if (response.statusCode == 500) {
          errorMessage = '이메일 발송 서비스에 일시적인 문제가 발생했습니다.\n잠시 후 다시 시도해주세요.';
        }
        
        setState(() {
          _errorMessage = errorMessage;
        });
      }
    } catch (e) {
      String errorMessage = '서버 연결에 실패했습니다. 다시 시도해 주세요.';
      
      if (e.toString().contains('TimeoutException')) {
        errorMessage = '요청 시간이 초과되었습니다.\n네트워크 상태를 확인해주세요.';
      }
      
      setState(() {
        _errorMessage = errorMessage;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyCode() async {
    if (_verificationCodeController.text.isEmpty) {
      setState(() {
        _verificationMessage = '인증번호를 입력해주세요.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _verificationMessage = null;
    });

    try {
      final requestBody = {
        'username': _nameController.text.trim(),
        'email': _emailController.text.trim().toLowerCase(),
        'code': _verificationCodeController.text.trim(),
      };
      
      print('인증번호 확인 요청 데이터: $requestBody');
      print('인증번호 확인 요청 URL: ${ApiConfig.findIdVerifyCodeEndpoint}');
      
      final response = await http.post(
        Uri.parse(ApiConfig.findIdVerifyCodeEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));

      print('인증번호 확인 응답 상태 코드: ${response.statusCode}');
      print('인증번호 확인 응답 본문: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // 응답에서 사용자 아이디 추출
        try {
          final responseData = jsonDecode(response.body);
          if (responseData['data'] != null && responseData['data']['userId'] != null) {
            _foundUserId = responseData['data']['userId'];
          }
        } catch (e) {
          print('사용자 아이디 파싱 오류: $e');
        }
        
        setState(() {
          _isVerificationValid = true;
          _verificationMessage = '인증번호가 일치합니다.';
        });
      } else {
        setState(() {
          _isVerificationValid = false;
          _verificationMessage = '인증번호가 일치하지 않습니다.';
        });
      }
    } catch (e) {
      setState(() {
        _isVerificationValid = false;
        _verificationMessage = '인증번호 확인 중 오류가 발생했습니다.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _verificationCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/LoginBackGround.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 아이디 찾기 제목
                const Text(
                  '아이디 찾기',
                  style: TextStyle(
                    fontSize: 45,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                
                const SizedBox(height: 80),
                
                // 사용자 이름 입력 필드
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '사용자 이름',
                    style: TextStyle(fontSize: 16, color: Colors.black),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 60,
                  decoration: BoxDecoration(
                    image: const DecorationImage(
                      image: AssetImage('assets/images/InputBar.png'),
                      fit: BoxFit.cover,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.black),
                    keyboardType: TextInputType.text,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: 'Enter your Name',
                      hintStyle: TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) {
                      FocusScope.of(context).nextFocus();
                    },
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // 이메일 입력 필드
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '이메일',
                    style: TextStyle(fontSize: 16, color: Colors.black),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 60,
                  decoration: BoxDecoration(
                    image: const DecorationImage(
                      image: AssetImage('assets/images/InputBar.png'),
                      fit: BoxFit.cover,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _emailController,
                          style: const TextStyle(color: Colors.black),
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            hintText: 'Enter your Email',
                            hintStyle: TextStyle(color: Colors.grey),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          onSubmitted: (_) {
                            FocusScope.of(context).unfocus();
                          },
                        ),
                      ),
                      TextButton(
                        onPressed: _isLoading ? null : _sendVerificationCode,
                        child: const Text(
                          '인증번호 발송',
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // 에러 메시지 표시
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                
                // 인증번호 입력 필드 (인증번호 발송 후 표시)
                if (_showVerificationInput) ...[
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '인증번호',
                      style: TextStyle(fontSize: 16, color: Colors.black),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 70,
                    decoration: BoxDecoration(
                      image: const DecorationImage(
                        image: AssetImage('assets/images/InputBar.png'),
                        fit: BoxFit.cover,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _verificationCodeController,
                            style: const TextStyle(color: Colors.black),
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            decoration: const InputDecoration(
                              hintText: '인증번호를 입력하세요',
                              hintStyle: TextStyle(color: Colors.grey),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            onSubmitted: (_) {
                              FocusScope.of(context).unfocus();
                            },
                          ),
                        ),
                        TextButton(
                          onPressed: _isLoading ? null : _verifyCode,
                          child: const Text(
                            '확인',
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // 인증번호 확인 메시지
                  if (_verificationMessage != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(top: 8),
                      child: Text(
                        _verificationMessage!,
                        style: TextStyle(
                          color: _isVerificationValid ? Colors.green : Colors.red,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 20),
                ],
                
                const SizedBox(height: 60),
                
                // 아이디 찾기 버튼
                SizedBox(
                  width: 200,
                  height: 70,
                  child: GestureDetector(
                    onTap: () {
                      if (_isVerificationValid && _foundUserId != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => IdSuccessScreen(
                              name: _nameController.text.trim(),
                              userId: _foundUserId!,
                            ),
                          ),
                        );
                      } else {
                        setState(() {
                          _verificationMessage = '인증번호가 일치하지 않습니다.';
                          _isVerificationValid = false;
                          _showVerificationInput = true;
                        });
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        image: const DecorationImage(
                          image: AssetImage('assets/images/LoginButton.png'),
                          fit: BoxFit.cover,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.black)
                            : const Text(
                                '아이디 찾기',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
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
      )
    );
  }
}
