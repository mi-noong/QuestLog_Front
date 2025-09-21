import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'PasswordSuccessScreen.dart';

class PasswordScreen extends StatefulWidget {
  const PasswordScreen({super.key});

  @override
  State<PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends State<PasswordScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _idController = TextEditingController();
  
  String? _errorMessage;
  bool _isLoading = false;

  Future<void> _findPassword() async {
    if (_nameController.text.isEmpty || 
        _emailController.text.isEmpty || 
        _idController.text.isEmpty) {
      setState(() {
        _errorMessage = '모든 정보를 입력해주세요.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final baseUrl = 'http://192.168.219.110:8083';
    try {
      final requestBody = {
        'username': _nameController.text.trim(),
        'email': _emailController.text.trim().toLowerCase(),
        'userId': _idController.text.trim(),
      };
      
      print('비밀번호 찾기 요청 데이터: $requestBody');
      print('요청 URL: $baseUrl/api/auth/find-password');
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/find-password'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));

      print('응답 상태 코드: ${response.statusCode}');
      print('응답 본문: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        // 성공 시 PasswordSuccessScreen으로 이동
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PasswordSuccessScreen(
                userEmail: _emailController.text.trim(),
              ),
            ),
          );
        }
      } else {
        // 서버 응답에서 에러 메시지 파싱 시도
        String errorMessage = '일치하는 사용자가 없습니다.\n다시 시도해주시기 바랍니다.';
        
        try {
          final responseData = jsonDecode(response.body);
          if (responseData['message'] != null) {
            errorMessage = responseData['message'];
          }
        } catch (e) {
          print('응답 파싱 오류: $e');
        }
        
        // 상태 코드별 특별 처리
        if (response.statusCode == 500) {
          errorMessage = '서버 내부 오류가 발생했습니다.\n잠시 후 다시 시도해주세요.';
        } else if (response.statusCode == 404) {
          errorMessage = '서버를 찾을 수 없습니다.\n네트워크 연결을 확인해주세요.';
        } else if (response.statusCode == 400) {
          errorMessage = '일치하는 사용자가 없습니다.';
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

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _idController.dispose();
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
              // 제목
              const Text(
                '비밀번호 찾기',
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
                height: 70,
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
                height: 70,
                decoration: BoxDecoration(
                  image: const DecorationImage(
                    image: AssetImage('assets/images/InputBar.png'),
                    fit: BoxFit.cover,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  controller: _emailController,
                  style: const TextStyle(color: Colors.black),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
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
                    FocusScope.of(context).nextFocus();
                  },
                ),
              ),
              
              const SizedBox(height: 20),
              
              // 아이디 입력 필드
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '아이디',
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
                child: TextField(
                  controller: _idController,
                  style: const TextStyle(color: Colors.black),
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    hintText: 'Enter your ID',
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
              
              const SizedBox(height: 60),
              
              // 비밀번호 찾기 버튼
              SizedBox(
                width: 200,
                height: 70,
                child: GestureDetector(
                  onTap: _isLoading ? null : _findPassword,
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
                              '비밀번호 찾기',
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
      ),
    );
  }
}
