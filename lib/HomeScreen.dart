import 'package:flutter/material.dart';
import 'QuestScreen.dart';
import 'shop.dart';
import 'MyPageScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config/api_config.dart';
import 'models/user_game_info.dart' as models;
import 'services/game_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  models.UserGameInfo? userGameInfo;
  bool isLoadingUser = false;

  @override
  void initState() {
    super.initState();
    // 로그인 후 하루 리셋 체크
    _checkDailyReset();
    // 사용자 게임 정보 로드
    _loadUserGameInfo();
  }

  // 하루 리셋 체크 함수
  Future<void> _checkDailyReset() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDbId = prefs.getInt('userDbId');
      
      if (userDbId == null) {
        print('⚠️ 로그인한 사용자 DB ID가 없습니다. 하루 리셋 체크를 건너뜁니다.');
        return;
      }

      print('📅 하루 리셋 체크 시작: userDbId=$userDbId');
      
      final response = await http.post(
        Uri.parse(ApiConfig.dailyResetEndpoint(userDbId)),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      print('📡 하루 리셋 응답 상태: ${response.statusCode}');
      print('📡 하루 리셋 응답 내용: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          print('✅ 하루 리셋 체크 완료');
          // 하루가 바뀌었으면 보너스 지급 (백엔드에서 처리)
        } else {
          print('⚠️ 하루 리셋 체크 실패: ${responseData['message']}');
        }
      } else {
        print('❌ 하루 리셋 체크 실패: HTTP ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ 하루 리셋 체크 중 오류: $e');
      // 오류가 발생해도 앱은 정상 작동해야 하므로 조용히 실패 처리
    }
  }

  Future<void> _loadUserGameInfo() async {
    try {
      setState(() {
        isLoadingUser = true;
      });
      final prefs = await SharedPreferences.getInstance();
      final userDbId = prefs.getInt('userDbId');
      if (userDbId == null) {
        print('⚠️ 로그인한 사용자 DB ID가 없습니다. 사용자 정보 로드를 건너뜁니다.');
        setState(() {
          isLoadingUser = false;
        });
        return;
      }

      final info = await GameService.getUserGameInfo(userDbId);
      if (!mounted) return;
      setState(() {
        userGameInfo = info;
        isLoadingUser = false;
      });
    } catch (e) {
      print('❌ 사용자 정보 로드 실패(Home): $e');
      if (!mounted) return;
      setState(() {
        isLoadingUser = false;
      });
    }
  }

  // 체력 바 이미지 선택 함수 (SettingScreen과 동일 로직)
  String getHpBarImage(int hp) {
    if (hp < 10) return 'assets/images/Icon_HpXp_EmptyBar.png';
    if (hp < 20) return 'assets/images/Icon_HpBar_1.png';
    if (hp < 30) return 'assets/images/Icon_HpBar_2.png';
    if (hp < 40) return 'assets/images/Icon_HpBar_3.png';
    if (hp < 50) return 'assets/images/Icon_HpBar_4.png';
    if (hp < 60) return 'assets/images/Icon_HpBar_5.png';
    if (hp < 70) return 'assets/images/Icon_HpBar_6.png';
    if (hp < 80) return 'assets/images/Icon_HpBar_7.png';
    if (hp < 90) return 'assets/images/Icon_HpBar_8.png';
    if (hp < 100) return 'assets/images/Icon_HpBar_9.png';
    return 'assets/images/Icon_HpBar_10.png';
  }

  // 경험치 바 이미지 선택 함수 (SettingScreen과 동일 로직)
  String getExpBarImage(int level, int exp) {
    int maxExp = 100 + (level - 1) * 50;
    double expPercentage = maxExp == 0 ? 0 : (exp / maxExp) * 100;
    if (expPercentage < 10) return 'assets/images/Icon_HpXp_EmptyBar.png';
    if (expPercentage < 20) return 'assets/images/Icon_XpBar_1.png';
    if (expPercentage < 30) return 'assets/images/Icon_XpBar_2.png';
    if (expPercentage < 40) return 'assets/images/Icon_XpBar_3.png';
    if (expPercentage < 50) return 'assets/images/Icon_XpBar_4.png';
    if (expPercentage < 60) return 'assets/images/Icon_XpBar_5.png';
    if (expPercentage < 70) return 'assets/images/Icon_XpBar_6.png';
    if (expPercentage < 80) return 'assets/images/Icon_XpBar_7.png';
    if (expPercentage < 90) return 'assets/images/Icon_XpBar_8.png';
    if (expPercentage < 100) return 'assets/images/Icon_XpBar_9.png';
    return 'assets/images/Icon_XpBar_10.png';
  }

  // 아이콘 위치 설정 변수들
  static const double backpackRightPosition = 170.0; // 가방 아이콘 오른쪽 여백
  static const double shopRightPosition = 210.0; // 상점 아이콘 오른쪽 여백

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/GridScreen.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 상단 플레이어 정보 영역
              _buildTopInfoSection(context),

              // 중앙 퀘스트 스크롤 영역
              Expanded(
                child: _buildQuestScrollSection(),
              ),

              // 하단 시작 버튼
              _buildBottomButtonSection(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopInfoSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.transparent,
      ),
      child: Row(
        children: [
          // 왼쪽 섹션: 캐릭터 아이콘과 HP/XP 바, 골드, 캘린더
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 캐릭터 아이콘과 HP/XP 바
              Row(
                children: [
                  // 캐릭터 아이콘 (마이페이지로 이동)
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const MyPageScreen()),
                      );
                    },
                    child: Image.asset(
                      'assets/images/Icon_MyPage.png',
                      width: 70,
                      height: 70,
                    ),
                  ),

                  const SizedBox(width: 10),

                  // HP/XP 바들
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // HP 바
                      Row(
                        children: [
                          const Text(
                            'HP',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Image.asset(
                            getHpBarImage(userGameInfo?.hp ?? 100),
                            width: 190,
                            height: 23,
                          ),
                        ],
                      ),

                      const SizedBox(height: 5),

                      // XP 바
                      Row(
                        children: [
                          const Text(
                            'XP',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Image.asset(
                            getExpBarImage(userGameInfo?.level ?? 1, userGameInfo?.exp ?? 0),
                            width: 190,
                            height: 23,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),

              // 골드와 가방 아이콘
              Row(
                children: [
                  Image.asset(
                    'assets/images/Icon_Gold.png',
                    width: 55,
                    height: 55,
                  ),
                  Text(
                    '${userGameInfo?.gold ?? 0}',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: backpackRightPosition),
                  Image.asset(
                    'assets/images/Icon_Backpack.png',
                    width: 60,
                    height: 60,
                  ),
                ],
              ),

              // 캘린더 아이콘과 상점 아이콘
              Row(
                children: [
                  Image.asset(
                    'assets/images/Icon_Calendar.png',
                    width: 55,
                    height: 55,
                  ),
                  SizedBox(width: shopRightPosition),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ShopScreen()),
                      );
                    },
                    child: Image.asset(
                      'assets/images/Icon_Shop.png',
                      width: 60,
                      height: 60,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildQuestScrollSection() {
    return Container(
      child: SingleChildScrollView(
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 맵 이미지 (여백 최소화)
              Image.asset(
                'assets/images/map.png',
                width: 380,
                height: 390,
                fit: BoxFit.contain,
              ),

              // 퀘스트 텍스트
              const Positioned(
                top: 0,
                bottom: 0,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Please Enter',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'the quest',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomButtonSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11.0),
      child: Center(
        child: GestureDetector(
          onTap: () {
            // 시작 버튼 클릭 시 QuestScreen으로 이동
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const QuestScreen()),
            );
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.asset(
                'assets/images/MainButton.png',
                width: 230,
                height: 70,
              ),
              const Text(
                'Start',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
