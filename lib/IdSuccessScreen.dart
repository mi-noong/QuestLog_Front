import 'package:flutter/material.dart';
import 'LoginScreen.dart';

class IdSuccessScreen extends StatelessWidget {
  final String name;
  final String userId;

  const IdSuccessScreen({Key? key, required this.name, required this.userId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/LoginBackGround.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: DefaultTextStyle.merge(
              style: const TextStyle(fontFamily: 'DungGeunMo'),
              child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.account_circle, size: 120, color: Color(0xFF90CAFF)),
                const SizedBox(height: 32),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(color: Colors.black, fontSize: 28, fontWeight: FontWeight.normal, fontFamily: 'DungGeunMo'),
                    children: [
                      TextSpan(text: '$name님의 아이디는\n'),
                      TextSpan(
                        text: userId,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 32),
                      ),
                      const TextSpan(text: '입니다.'),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: 240,
                  height: 70,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                        (route) => false,
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
                          '로그인',
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
