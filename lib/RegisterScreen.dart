import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'RegisterSuccessScreen.dart';
import 'config/api_config.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);


  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _passwordConfirmController = TextEditingController();

  bool _passwordMismatch = false;
  String? _inputError;
  bool _isLoading = false;
  bool _isEmailChecking = false;
  bool _isUserIdChecking = false;
  String? _emailError;
  String? _userIdError;

  // 이메일 중복 확인
  Future<void> _checkEmailDuplicate() async {
    if (_emailController.text.isEmpty) {
      setState(() {
        _emailError = null;
      });
      return;
    }

    setState(() {
      _isEmailChecking = true;
      _emailError = null;
    });

    try {
      final response = await http.get(
        Uri.parse(ApiConfig.checkEmailEndpoint(_emailController.text)),
        headers: {'Content-Type': 'application/json'},
      );

      print('이메일 중복 확인 응답: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['available'] == false) {
          setState(() {
            _emailError = '이미 사용 중인 이메일입니다.';
          });
        } else {
          setState(() {
            _emailError = null;
          });
        }
      } else {
        setState(() {
          _emailError = '이메일 확인 중 오류가 발생했습니다.';
        });
      }
    } catch (e) {
      setState(() {
        _emailError = '이메일 확인 중 오류가 발생했습니다.';
      });
    } finally {
      setState(() {
        _isEmailChecking = false;
      });
    }
  }

  // 아이디 중복 확인
  Future<void> _checkUserIdDuplicate() async {
    if (_idController.text.isEmpty) {
      setState(() {
        _userIdError = null;
      });
      return;
    }

    setState(() {
      _isUserIdChecking = true;
      _userIdError = null;
    });

    try {
      final response = await http.get(
        Uri.parse(ApiConfig.checkUserIdEndpoint(_idController.text)),
        headers: {'Content-Type': 'application/json'},
      );

      print('아이디 중복 확인 응답: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['available'] == false) {
          setState(() {
            _userIdError = '이미 사용 중인 아이디입니다.';
          });
        } else {
          setState(() {
            _userIdError = null;
          });
        }
      } else {
        setState(() {
          _userIdError = '아이디 확인 중 오류가 발생했습니다.';
        });
      }
    } catch (e) {
      setState(() {
        _userIdError = '아이디 확인 중 오류가 발생했습니다.';
      });
    } finally {
      setState(() {
        _isUserIdChecking = false;
      });
    }
  }

  // 회원가입 API 호출
  Future<void> _register() async {
    setState(() {
      _passwordMismatch = false;
      _inputError = null;
      _isLoading = true;
    });

    // 입력값 검증
    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _idController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _passwordConfirmController.text.isEmpty) {
      setState(() {
        _inputError = '정보를 입력해주세요.';
        _isLoading = false;
      });
      return;
    }

    if (_passwordController.text != _passwordConfirmController.text) {
      setState(() {
        _passwordMismatch = true;
        _isLoading = false;
      });
      return;
    }

    // 중복 확인 에러 체크
    if (_emailError != null || _userIdError != null) {
      setState(() {
        _inputError = '이메일 또는 아이디 중복을 확인해주세요.';
        _isLoading = false;
      });
      return;
    }

    try {
      print('회원가입 요청 시작: ${ApiConfig.registerEndpoint}');
      print('요청 데이터: ${json.encode({
        'username': _nameController.text,
        'email': _emailController.text,
        'userId': _idController.text,
        'password': _passwordController.text,
        'confirmPassword': _passwordConfirmController.text,
      })}');
      
      final response = await http.post(
        Uri.parse(ApiConfig.registerEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'username': _nameController.text,
          'email': _emailController.text,
          'userId': _idController.text,
          'password': _passwordController.text,
          'confirmPassword': _passwordConfirmController.text,
        }),
      );

      print('응답 상태 코드: ${response.statusCode}');
      print('응답 본문: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        // 회원가입 성공
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RegisterSuccessScreen(
              id: _idController.text,
              name: _nameController.text,
              email: _emailController.text,
              password: _passwordController.text,
            ),
          ),
        );
      } else {
        try {
          final data = json.decode(response.body);
          String errorMessage = data['message'] ?? '회원가입 중 오류가 발생했습니다.';
          
          if (response.statusCode == 500) {
            errorMessage = '서버에 일시적인 문제가 발생했습니다. 잠시 후 다시 시도해주세요.';
          } else if (response.statusCode == 400) {
            errorMessage = '입력 정보를 다시 확인해주세요.';
          }
          
          setState(() {
            _inputError = errorMessage;
            _isLoading = false;
          });
        } catch (e) {
          setState(() {
            _inputError = '서버 응답을 처리할 수 없습니다. 잠시 후 다시 시도해주세요.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('네트워크 오류 상세: $e');
      setState(() {
        _inputError = '네트워크 오류가 발생했습니다: $e';
        _isLoading = false;
      });
    }
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
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 32),
                  // 회원가입 제목
                  const Center(
                    child: Text(
                      'sign up',
                      style: TextStyle(
                        fontSize: 70,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  // 이름 입력
                  _buildInputField('사용자 이름', controller: _nameController, hint: 'Enter your Name'),
                  const SizedBox(height: 16),
                  // 이메일 입력
                  _buildInputFieldWithCheck('이메일', controller: _emailController, hint: 'Enter your Email', 
                    onCheck: _checkEmailDuplicate, isChecking: _isEmailChecking, error: _emailError),
                  const SizedBox(height: 16),
                  // 아이디 입력
                  _buildInputFieldWithCheck('아이디', controller: _idController, hint: 'Enter your ID',
                    onCheck: _checkUserIdDuplicate, isChecking: _isUserIdChecking, error: _userIdError),
                  const SizedBox(height: 16),
                  // 비밀번호 입력
                  _buildInputField('비밀번호', controller: _passwordController, isPassword: true, hint: 'Enter your Password'),
                  const SizedBox(height: 16),
                  // 비밀번호 확인
                  _buildInputField('비밀번호 확인', controller: _passwordConfirmController, isPassword: true, hint: 'Enter your Password', isError: _passwordMismatch),
                  if (_inputError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 4),
                      child: Text(
                        _inputError!,
                        style: TextStyle(color: Colors.red[700], fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ),
                  if (_passwordMismatch)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 4),
                      child: Text(
                        '비밀번호가 일치하지 않습니다.',
                        style: TextStyle(color: Colors.red[700], fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ),
                  const SizedBox(height: 32),
                  // 회원가입 버튼
                  Center(
                    child: SizedBox(
                      width: 200,
                      height: 70,
                      child: GestureDetector(
                        onTap: _isLoading ? null : _register,
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
                                    '회원가입',
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
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(String label, {bool isPassword = false, required TextEditingController controller, required String hint, bool isError = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black,
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
            border: isError ? Border.all(color: Colors.red, width: 2) : null,
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword,
            style: const TextStyle(color: Colors.black),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.grey),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputFieldWithCheck(String label, {
    required TextEditingController controller, 
    required String hint,
    required VoidCallback onCheck,
    required bool isChecking,
    String? error,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black,
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
            border: error != null ? Border.all(color: Colors.red, width: 2) : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  style: const TextStyle(color: Colors.black),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: isChecking ? null : onCheck,
                child: isChecking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.blue,
                        ),
                      )
                    : const Text(
                        '중복확인',
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
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              error,
              style: TextStyle(color: Colors.red[700], fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
      ],
    );
  }

}
