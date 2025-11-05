import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'RegisterScreen.dart';
import 'PasswordScreen.dart';
import 'IdScreen.dart';
import 'HomeScreen.dart';
import 'config/api_config.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false;

  // 로그인 응답 처리 및 사용자 정보 저장
  Future<void> _handleLoginResponse(Map<String, dynamic> responseData) async {
    if (responseData['success'] != true) {
      return;
    }

    try {
      final userData = responseData['data'];
      
      // data가 객체인지 확인
      if (userData is! Map<String, dynamic>) {
        print('⚠️ 로그인 응답 data가 객체가 아닙니다: $userData');
        // data가 문자열인 경우 userId만 저장
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userId', _idController.text);
        print('✅ 사용자 ID 저장 완료: ${_idController.text}');
        return;
      }

      // ✅ 중요: DB ID (Long 타입)를 저장해야 합니다
      final dbId = userData['id'] as int?;
      final userId = userData['userId'] as String? ?? _idController.text;
      final username = userData['username'] as String?;

      final prefs = await SharedPreferences.getInstance();

      // DB ID 저장 (구매 API에 사용)
      if (dbId != null) {
        await prefs.setInt('userDbId', dbId);
        print('✅ 사용자 DB ID 저장 완료: $dbId');
      } else {
        print('⚠️ 로그인 응답에 DB ID가 없습니다.');
      }

      // 사용자 ID (문자열) 저장 - 로그인용
      await prefs.setString('userId', userId);
      print('✅ 사용자 ID 저장 완료: $userId');

      // 사용자명 저장 (선택적)
      if (username != null) {
        await prefs.setString('username', username);
        print('✅ 사용자명 저장 완료: $username');
      }
    } catch (e) {
      print('❌ 사용자 정보 저장 실패: $e');
      // 저장 실패해도 기본 userId는 저장
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userId', _idController.text);
      } catch (e2) {
        print('❌ 기본 사용자 ID 저장도 실패: $e2');
      }
    }
  }


  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.loginEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': _idController.text,
          'password': _passwordController.text,
        }),
      );
      if (response.statusCode == 200) {
        // 로그인 응답에서 데이터 추출
        final responseData = json.decode(response.body);
        print('로그인 응답 데이터: $responseData');
        
        // 로그인 응답에서 사용자 정보 저장
        await _handleLoginResponse(responseData);
        
        //로그인 성공 -> HomeScreen 이동
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        setState(() {
          _errorMessage = '아이디 또는 비밀번호가 맞지 않습니다.\n다시 시도해주시기 바랍니다.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '서버 연결에 실패했습니다. 다시 시도해 주세요.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/LoginBackGround.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height - 
                             MediaQuery.of(context).padding.top - 
                             MediaQuery.of(context).padding.bottom - 40,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                // 제목
                const Text(
                  'Login',
                  style: TextStyle(
                    fontSize: 70,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // 아이디 입력 필드
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'ID',
                    style: TextStyle(fontSize: 25, color: Colors.black),
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
                  ),
                  child: TextField(
                    controller: _idController,
                    style: const TextStyle(color: Colors.black),
                    decoration: const InputDecoration(
                      hintText: 'Enter your ID',
                      hintStyle: TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // 비밀번호 입력 필드
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Password',
                    style: TextStyle(fontSize: 25, color: Colors.black),
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
                  ),
                  child: TextField(
                    controller: _passwordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.black),
                    decoration: const InputDecoration(
                      hintText: 'Enter your Password',
                      hintStyle: TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
                
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
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                
                // 로그인 버튼
                SizedBox(
                  width: 200,
                  height: 70,
                  child: GestureDetector(
                    onTap: _login,
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
                                'Login',
                                style: TextStyle(
                                  fontSize: 25,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // 아이디/비밀번호 찾기 링크
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => IdScreen()),
                        );
                      },
                      child: const Text('아이디 찾기', style: TextStyle(color: Colors.black)),
                    ),
                    Container(
                      height: 16,
                      width: 1,
                      color: Colors.black,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => PasswordScreen()),
                        );
                      },
                      child: const Text('비밀번호 찾기', style: TextStyle(color: Colors.black)),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // 회원가입 버튼
                SizedBox(
                  width: 200,
                  height: 70,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const RegisterScreen()),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        image: const DecorationImage(
                          image: AssetImage('assets/images/LoginButton.png'),
                          fit: BoxFit.cover,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text(
                          'sign up',
                          style: TextStyle(
                            fontSize: 25,
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
      ),
    );
  }
}
