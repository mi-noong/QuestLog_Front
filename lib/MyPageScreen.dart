import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'HomeScreen.dart';

final baseUrl = 'http://192.168.219.110:8083';

// 사용자 게임 정보 모델
class UserGameInfo {
  final int userId;
  final String username;
  final int hp;
  final int maxHp;
  final int exp;
  final int nextExp;
  final int level;
  final int gold;
  final Map<String, dynamic> weapon;
  final Map<String, dynamic> armor;
  final int potions;
  final List<dynamic> pets;
  final int attack;
  final int defense;

  UserGameInfo({
    required this.userId,
    required this.username,
    required this.hp,
    required this.maxHp,
    required this.exp,
    required this.nextExp,
    required this.level,
    required this.gold,
    required this.weapon,
    required this.armor,
    required this.potions,
    required this.pets,
    required this.attack,
    required this.defense,
  });

  factory UserGameInfo.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    final inventory = json['inventory'];
    
    return UserGameInfo(
      userId: user['userId'],
      username: user['username'],
      hp: user['hp'],
      maxHp: user['maxHp'],
      exp: user['exp'],
      nextExp: user['nextExp'],
      level: user['level'],
      gold: user['gold'],
      weapon: inventory['weapon'],
      armor: inventory['armor'],
      potions: inventory['potions'],
      pets: inventory['pets'],
      attack: json['stats']?['attack'] ?? 0,
      defense: json['stats']?['defense'] ?? 0,
    );
  }
}

// API 호출 함수
Future<UserGameInfo?> fetchUserGameInfo(int userId) async {
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/api/game/user/$userId'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        return UserGameInfo.fromJson(data['data']);
      }
    }
    return null;
  } catch (e) {
    print('사용자 정보 조회 오류: $e');
    return null;
  }
}

class MyPageScreen extends StatefulWidget {
  final UserGameInfo? initialData; // 미리보기용 초기 데이터
  const MyPageScreen({super.key, this.initialData});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  UserGameInfo? userInfo;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      userInfo = widget.initialData;
      isLoading = false;
    } else {
      _loadUserInfo();
    }
  }

  Future<void> _loadUserInfo() async {
    // 실제 사용자 ID를 사용하여 백엔드에서 데이터 가져오기
    // TODO: 실제 로그인된 사용자 ID로 변경 필요
    const userId = 1; // 임시로 사용자 ID 1 사용
    
    final fetchedUserInfo = await fetchUserGameInfo(userId);
    
    setState(() {
      userInfo = fetchedUserInfo;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/GridScreen.png'),
              fit: BoxFit.cover,
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const SizedBox(height: 20), // 상단 여백 추가
                // 홈 버튼과 My Page 제목을 같은 높이에 배치
                LayoutBuilder(
                  builder: (context, constraints) {
                    final screenWidth = MediaQuery.of(context).size.width;
                    final isTablet = screenWidth > 600;
                    
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // 홈 버튼 (왼쪽)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: GestureDetector(
                            onTap: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (context) => HomeScreen()),
                              );
                            },
                            child: Image.asset(
                              'assets/images/BackButton.png',
                              width: 40,
                              height: 40,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        // My Page 제목 (가운데)
                        Text(
                          'My Page',
                          style: TextStyle(
                            fontSize: isTablet ? 48.0 : 36.0,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            fontFamily: 'DungGeunMo',
                            decoration: TextDecoration.none,
                          ),
                        ),
                        // 오른쪽 공간 (대칭을 위해)
                        SizedBox(width: 48), // 홈 버튼과 같은 너비
                      ],
                    );
                  },
                ),
                const SizedBox(height: 72),
                if (isLoading)
                  const CircularProgressIndicator()
                else if (userInfo != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 사용자 이름 + 용사님, 레벨 텍스트를 약간 오른쪽으로 이동
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final screenWidth = MediaQuery.of(context).size.width;
                          final isTablet = screenWidth > 600;
                          
                          return Padding(
                            padding: EdgeInsets.only(left: isTablet ? 20.0 : 15.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${userInfo!.username} 용사님',
                                  style: TextStyle(
                                    fontSize: isTablet ? 28.0 : 22.0,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                    fontFamily: 'DungGeunMo',
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '@${userInfo!.userId} Level ${userInfo!.level}',
                                  style: TextStyle(
                                    fontSize: isTablet ? 24.0 : 18.0,
                                    color: Colors.black,
                                    fontFamily: 'DungGeunMo',
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      // StoreItemFrame 전체를 아래로 살짝 내림
                    const SizedBox(height: 40),
                      // 큰 네모 프레임 + 내부 HP/XP/골드 정보
                      _StatusFrame(userInfo: userInfo!),
                    ],
                  )
                else
                  const Text(
                    '사용자 정보를 불러올 수 없습니다',
                    style: TextStyle(color: Colors.red),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}


class _StatusFrame extends StatelessWidget {
  final UserGameInfo userInfo;
  const _StatusFrame({required this.userInfo});

  String _hpBarAsset() {
    // 10칸 기준 단계 계산
    final hpRatio = userInfo.maxHp == 0 ? 0.0 : userInfo.hp / userInfo.maxHp;
    final level = (hpRatio * 10).clamp(0, 10).floor();
    if (level <= 0) {
      return 'assets/images/Icon_HpXp_EmptyBar.png';
    }
    return 'assets/images/Icon_HpBar_${level}.png';
  }

  String _xpBarAsset() {
    // 레벨별 필요 경험치: 1레벨 100, 이후 레벨당 +50
    int requiredExp(int level) => 100 + (level - 1) * 50;
    final totalNeeded = requiredExp(userInfo.level);
    final xpRatio = totalNeeded == 0 ? 0.0 : userInfo.exp / totalNeeded;
    final level10 = (xpRatio * 10).clamp(0, 10).floor();
    if (level10 <= 0) {
      return 'assets/images/Icon_HpXp_EmptyBar.png';
    }
    return 'assets/images/Icon_XpBar_${level10}.png';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screen = MediaQuery.of(context).size;
        final isTablet = screen.width > 600;
        
        // 태블릿은 고정 크기, 스마트폰은 화면에 맞게 조절
        final targetHeight = isTablet 
          ? (screen.height * 0.75 / 1.2).clamp(260.0, screen.height)
          : screen.height * 0.58; // 스마트폰에서 높이 더 감소 (하단 여백 줄이기)
        final targetWidth = isTablet 
          ? (screen.width * 0.9 / 1.1).clamp(260.0, constraints.maxWidth)
          : screen.width * 0.88; // 스마트폰에서 너비 감소
          
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: targetWidth,
            height: targetHeight,
            child: Stack(
              children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/StoreItemFrame.png',
                  fit: BoxFit.fill,
                ),
              ),
              // 내부 콘텐츠는 패딩 + 컬럼으로 배치하여 오버플로 제거
              Padding(
                padding: EdgeInsets.fromLTRB(
                  isTablet ? 20.0 : 10.0, // 스마트폰에서 패딩 더 감소
                  isTablet ? 32.0 : 14.0, // 스마트폰에서 상단 패딩 감소
                  isTablet ? 20.0 : 10.0, // 스마트폰에서 패딩 더 감소
                  isTablet ? 20.0 : 8.0   // 스마트폰에서 하단 패딩 대폭 감소
                ),
                child: isTablet 
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 태블릿용 기존 레이아웃
                        Align(
                          alignment: Alignment.topCenter,
                          child: SizedBox(
                            width: targetWidth * 0.8,
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'HP',
                                      style: TextStyle(
                                        fontFamily: 'DungGeunMo',
                                        fontSize: 24.0,
                                        color: Colors.black,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: FractionallySizedBox(
                                        widthFactor: 1/1.1,
                                        alignment: Alignment.centerLeft,
                                        child: Image.asset(_hpBarAsset(), fit: BoxFit.fill),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('${userInfo.hp}/${userInfo.maxHp}',
                                        style: TextStyle(fontFamily: 'DungGeunMo', fontSize: 24.0, decoration: TextDecoration.none)),
                                    const SizedBox(width: 12),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    Text(
                                      'XP',
                                      style: TextStyle(
                                        fontFamily: 'DungGeunMo',
                                        fontSize: 24.0,
                                        color: Colors.black,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: FractionallySizedBox(
                                        widthFactor: 1/1.1,
                                        alignment: Alignment.centerLeft,
                                        child: Image.asset(_xpBarAsset(), fit: BoxFit.fill),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('${userInfo.exp}/${100 + (userInfo.level - 1) * 50}',
                                        style: TextStyle(fontFamily: 'DungGeunMo', fontSize: 24.0, decoration: TextDecoration.none)),
                                    const SizedBox(width: 12),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Padding(
                          padding: EdgeInsets.only(left: 12.0),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 40.0,
                                height: 40.0,
                                child: Image.asset('assets/images/Icon_Gold.png'),
                              ),
                              SizedBox(width: 6.0),
                              Text('${userInfo.gold}',
                                  style: TextStyle(fontFamily: 'DungGeunMo', fontSize: 36.0, color: Colors.black, decoration: TextDecoration.none)),
                            ],
                          ),
                        ),
                        SizedBox(height: 16.0),
                        Padding(
                          padding: EdgeInsets.only(left: 20.0),
                          child: Text('Equipment',
                            style: TextStyle(
                              fontFamily: 'DungGeunMo',
                              fontSize: 40.0,
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.none,
                            )),
                        ),
                        SizedBox(height: 28.0),
                        SizedBox(
                          height: 160.0,
                          child: Center(
                            child: _EquipmentRow(userInfo: userInfo),
                          ),
                        ),
                        SizedBox(height: 28.0),
                        Padding(
                          padding: EdgeInsets.only(left: 20.0),
                          child: Text('Stats',
                            style: TextStyle(
                              fontFamily: 'DungGeunMo',
                              fontSize: 40.0,
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.none,
                            )),
                        ),
                        SizedBox(height: 24.0),
                        Center(
                          child: SizedBox(
                            height: 180.0,
                            child: FractionallySizedBox(
                              widthFactor: 0.88,
                              child: _StatsPanel(userInfo: userInfo),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly, // 스마트폰에서 요소들을 균등하게 분산
                      children: [
                        // 스마트폰용 HP/XP 바
                        Align(
                          alignment: Alignment.center,
                          child: SizedBox(
                            width: targetWidth * 0.85,
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'HP',
                                      style: TextStyle(
                                        fontFamily: 'DungGeunMo',
                                        fontSize: 16.0,
                                        color: Colors.black,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                    SizedBox(width: 6.0),
                                    Expanded(
                                      child: FractionallySizedBox(
                                        widthFactor: 1/1.1,
                                        alignment: Alignment.centerLeft,
                                        child: Image.asset(_hpBarAsset(), fit: BoxFit.fill),
                                      ),
                                    ),
                                    SizedBox(width: 6.0),
                                    Text('${userInfo.hp}/${userInfo.maxHp}',
                                        style: TextStyle(fontFamily: 'DungGeunMo', fontSize: 16.0, decoration: TextDecoration.none)),
                                    SizedBox(width: 8.0),
                                  ],
                                ),
                                SizedBox(height: 12.0),
                                Row(
                                  children: [
                                    Text(
                                      'XP',
                                      style: TextStyle(
                                        fontFamily: 'DungGeunMo',
                                        fontSize: 16.0,
                                        color: Colors.black,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                    SizedBox(width: 6.0),
                                    Expanded(
                                      child: FractionallySizedBox(
                                        widthFactor: 1/1.1,
                                        alignment: Alignment.centerLeft,
                                        child: Image.asset(_xpBarAsset(), fit: BoxFit.fill),
                                      ),
                                    ),
                                    SizedBox(width: 6.0),
                                    Text('${userInfo.exp}/${100 + (userInfo.level - 1) * 50}',
                                        style: TextStyle(fontFamily: 'DungGeunMo', fontSize: 16.0, decoration: TextDecoration.none)),
                                    SizedBox(width: 8.0),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        // 스마트폰용 골드
                        Padding(
                          padding: EdgeInsets.only(left: 8.0),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 28.0,
                                height: 28.0,
                                child: Image.asset('assets/images/Icon_Gold.png'),
                              ),
                              SizedBox(width: 4.0),
                              Text('${userInfo.gold}',
                                  style: TextStyle(fontFamily: 'DungGeunMo', fontSize: 24.0, color: Colors.black, decoration: TextDecoration.none)),
                            ],
                          ),
                        ),
                        // 스마트폰용 Equipment
                        Padding(
                          padding: EdgeInsets.only(left: 15.0),
                          child: Text('Equipment',
                            style: TextStyle(
                              fontFamily: 'DungGeunMo',
                              fontSize: 28.0,
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.none,
                            )),
                        ),
                        SizedBox(
                          height: 80.0,
                          child: Center(
                            child: _EquipmentRow(userInfo: userInfo),
                          ),
                        ),
                        // 스마트폰용 Stats
                        Padding(
                          padding: EdgeInsets.only(left: 15.0),
                          child: Text('Stats',
                            style: TextStyle(
                              fontFamily: 'DungGeunMo',
                              fontSize: 28.0,
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.none,
                            )),
                        ),
                        Center(
                          child: SizedBox(
                            height: 80.0,
                            child: FractionallySizedBox(
                              widthFactor: 0.85,
                              child: _StatsPanel(userInfo: userInfo),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SmallFrame extends StatelessWidget {
  const _SmallFrame();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 64,
      child: Image.asset(
        'assets/images/Mypage_Item.png',
        fit: BoxFit.fill,
      ),
    );
  }
}

class _EquipmentRow extends StatelessWidget {
  final UserGameInfo userInfo;
  const _EquipmentRow({required this.userInfo});

  Widget _slot(String title, String? assetPathOrNull) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isTablet = screenWidth > 600;
        
        return SizedBox(
          width: isTablet ? 160.0 : 70.0, // 스마트폰에서 너비 더 감소
          height: isTablet ? 384.0 : 150.0, // 스마트폰에서 높이 더 감소
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/images/Mypage_Item.png',
                  fit: BoxFit.fill,
                ),
              ),
              if (assetPathOrNull != null)
                Center(
                  child: Image.asset(
                    assetPathOrNull,
                    width: isTablet ? 80.0 : 35.0, // 스마트폰에서 아이콘 크기 더 감소
                    height: isTablet ? 160.0 : 70.0, // 스마트폰에서 아이콘 크기 더 감소
                    fit: BoxFit.contain,
                  ),
                ),
              // 라벨은 제거하여 밑줄 가능성 차단 (필요 시 아이콘 아래 텍스트로 교체)
            ],
          ),
        );
      },
    );
  }

  String? _weaponAsset(Map<String, dynamic> weapon) {
    final name = (weapon['name'] ?? '').toString().toLowerCase();
    // 우선순위: gold -> silver -> wooden sword -> stick
    if (name.contains('gold')) return 'assets/images/golden_sword.png';
    if (name.contains('silver')) return 'assets/images/sliver_sword.png'; // 파일명 오타 수정
    if (name.contains('wooden') && name.contains('sword')) return 'assets/images/wooden_sword.png';
    if (name.contains('sword')) return 'assets/images/wooden_sword.png';
    if (name.contains('stick') || name.contains('wood')) return 'assets/images/WoodenStick.png';
    // 폴백
    return 'assets/images/wooden_sword.png';
  }

  String? _armorAsset(Map<String, dynamic> armor) {
    final name = (armor['name'] ?? '').toString().toLowerCase();
    if (name.contains('gold')) return 'assets/images/GoldArmor.png';
    if (name.contains('silver')) return 'assets/images/SilverArmor.png';
    if (name.contains('basic') || name.contains('clothes')) return 'assets/images/BasicClothes.png';
    if (name.contains('leather')) return 'assets/images/Leather_Armor.png';
    // 폴백
    return 'assets/images/Leather_Armor.png';
  }

  String? _petAsset(List<dynamic> pets) {
    if (pets.isEmpty) return null;
    final first = pets.first.toString().toLowerCase();
    if (first.contains('cat')) return 'assets/images/Pet_Cat.png';
    if (first.contains('dog')) return 'assets/images/Pet_Dog.png';
    if (first.contains('rabbit')) return 'assets/images/Pet_Rabbit.png';
    // 폴백
    return 'assets/images/Pet_Cat.png';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isTablet = screenWidth > 600;
        
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _slot('갑옷', _armorAsset(userInfo.armor)),
            SizedBox(width: isTablet ? 16.0 : 6.0), // 스마트폰에서 간격 더 감소
            _slot('무기', _weaponAsset(userInfo.weapon)),
            SizedBox(width: isTablet ? 16.0 : 6.0), // 스마트폰에서 간격 더 감소
            _slot('펫', _petAsset(userInfo.pets)),
          ],
        );
      },
    );
  }
}

class _StatsPanel extends StatelessWidget {
  final UserGameInfo userInfo;
  const _StatsPanel({required this.userInfo});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = MediaQuery.of(context).size.width;
        final isTablet = screenWidth > 600;
        
        return FractionallySizedBox(
          widthFactor: isTablet ? 0.7 : 0.9, // 스마트폰에서 너비 증가
          child: SizedBox(
            height: isTablet ? 110 : 60, // 스마트폰에서 높이 더 감소 (하단 여백 줄이기)
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/Quest_MemoInput.png',
                    fit: BoxFit.fill,
                  ),
                ),
                // 상단 라벨
                Positioned(
                  left: isTablet ? 60 : 30,
                  top: isTablet ? 10 : 4,
                  child: Text(
                    'Attack',
                    style: TextStyle(
                      fontFamily: 'DungGeunMo',
                      fontSize: isTablet ? 29 : 16,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                Positioned(
                  right: isTablet ? 60 : 30,
                  top: isTablet ? 10 : 4,
                  child: Text(
                    'Defense',
                    style: TextStyle(
                      fontFamily: 'DungGeunMo',
                      fontSize: isTablet ? 29 : 16,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                // 수치
                Positioned(
                  left: isTablet ? 70 : 40,
                  top: isTablet ? 68 : 32,
                  child: Text(
                    '${userInfo.attack}',
                    style: TextStyle(
                      fontFamily: 'DungGeunMo',
                      fontSize: isTablet ? 37 : 20,
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                Positioned(
                  right: isTablet ? 70 : 40,
                  top: isTablet ? 68 : 32,
                  child: Text(
                    '${userInfo.defense}',
                    style: TextStyle(
                      fontFamily: 'DungGeunMo',
                      fontSize: isTablet ? 37 : 20,
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}


