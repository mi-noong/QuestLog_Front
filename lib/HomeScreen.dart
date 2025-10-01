import 'package:flutter/material.dart';
import 'QuestScreen.dart';
import 'shop.dart';
import 'MyPageScreen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
          child: Padding(
            padding: const EdgeInsets.all(16),
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
      ),
    );
  }

  Widget _buildTopInfoSection(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    
    // 태블릿은 고정 크기, 스마트폰은 화면에 맞게 조절
    final double barGap = isTablet ? 12.0 : 8.0; // 텍스트와 바 이미지 사이 간격
    final double iconSize = isTablet ? 69.0 : 45.0; // 스마트폰에서 아이콘 크기 감소
    final double fontSize = isTablet ? 45.0 : 24.0; // HP/XP 텍스트 크기 (스마트폰에서 크기 감소)
    final double goldFontSize = isTablet ? 44.0 : 28.0; // 골드 텍스트 크기
    final double barHeight = isTablet ? 80.0 : 60.0; // 바 높이 (스마트폰에서 더 크게)
    final double sectionWidth = isTablet ? screenWidth * 0.48 : screenWidth * 0.45; // 화면 너비 조절
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 왼쪽 섹션: 캐릭터 아이콘과 HP/XP 바, 골드, 캘린더 (좌측 사이드 고정)
          SizedBox(
            width: sectionWidth,
            child: Column(
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
                        width: iconSize + 10,
                        height: iconSize + 10,
                      ),
                    ),

                    SizedBox(width: 20.0),

                    // HP/XP 바들 (크기 증가) - 화면 상단 중앙으로 이동
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: isTablet ? 20.0 : 12.0), // 스마트폰에서 패딩 감소
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                          // HP 바
                          Row(
                            children: [
                              Text(
                                'HP',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: fontSize,
                                  fontFamily: 'DungGeunMo',
                                  decoration: TextDecoration.none,
                                ),
                              ),
                              SizedBox(width: barGap),
                              Expanded(
                                child: FractionallySizedBox(
                                  widthFactor: 2.0, // 가로 길이 더욱 증가
                                  alignment: Alignment.centerLeft,
                                  child: Image.asset(
                                    'assets/images/Icon_HPBar_10.png',
                                    height: barHeight,
                                    fit: BoxFit.fitWidth,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: isTablet ? 15.0 : 5.0), // 스마트폰에서 간격 더 좁히기

                          // XP 바
                          Row(
                            children: [
                              Text(
                                'XP',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: fontSize,
                                  fontFamily: 'DungGeunMo',
                                  decoration: TextDecoration.none,
                                ),
                              ),
                              SizedBox(width: barGap),
                              Expanded(
                                child: FractionallySizedBox(
                                  widthFactor: 2.0, // 가로 길이 더욱 증가
                                  alignment: Alignment.centerLeft,
                                  child: Image.asset(
                                    'assets/images/Icon_XpBar_10.png',
                                    height: barHeight,
                                    fit: BoxFit.fitWidth,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: isTablet ? 25.0 : 15.0), // 스마트폰에서 간격 감소

                // 골드
                Row(
                  children: [
                    Image.asset(
                      'assets/images/Icon_Gold.png',
                      width: iconSize,
                      height: iconSize,
                    ),
                    SizedBox(width: isTablet ? 12.0 : 8.0), // 스마트폰에서 간격 감소
                    Text(
                      '2500',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: goldFontSize,
                        fontFamily: 'DungGeunMo',
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: isTablet ? 25.0 : 15.0), // 스마트폰에서 간격 감소

                // 캘린더 아이콘
                Image.asset(
                  'assets/images/Icon_Calendar.png',
                  width: iconSize,
                  height: iconSize,
                ),
              ],
            ),
          ),

          // 오른쪽 섹션: 가방과 상점 아이콘들 (우측 사이드 고정)
          SizedBox(
            width: sectionWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // HP/XP바 섹션 높이만큼 상단 간격 (골드와 같은 높이에 가방 배치)
                SizedBox(height: barHeight * 2 + (isTablet ? 15.0 : 10.0) + (isTablet ? 25.0 : 15.0)),
                Image.asset(
                  'assets/images/Icon_Backpack.png',
                  width: iconSize,
                  height: iconSize,
                ),
                SizedBox(height: isTablet ? 25.0 : 15.0), // 골드와 캘린더 사이 간격과 동일
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ShopScreen()),
                    );
                  },
                  child: Image.asset(
                    'assets/images/Icon_Shop.png',
                    width: iconSize,
                    height: iconSize,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestScrollSection() {
    return const _QuestMapSection();
  }

  Widget _buildBottomButtonSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8), // 약간 위로 올림
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
                width: 280, // Shop.dart와 동일한 크기
                height: 80,
              ),
              const Text(
                'Start',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'DungGeunMo',
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestMapSection extends StatefulWidget {
  const _QuestMapSection({Key? key}) : super(key: key);

  @override
  State<_QuestMapSection> createState() => _QuestMapSectionState();
}

class _QuestMapSectionState extends State<_QuestMapSection> {
  bool _isQuestMap = false;

  void _toggleMap() {
    setState(() {
      _isQuestMap = !_isQuestMap;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: SingleChildScrollView(
        child: Center(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleMap,
            child: Stack(
              alignment: Alignment.center,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final screenWidth = MediaQuery.of(context).size.width;
                    final screenHeight = MediaQuery.of(context).size.height;
                    final isTablet = screenWidth > 600;
                    
                    // 태블릿은 고정 크기, 스마트폰은 화면에 맞게 조절
                    final mapWidth = isTablet ? 600.0 : screenWidth * 0.85; // 스마트폰에서 너비 감소
                    final mapHeight = isTablet ? 700.0 : screenHeight * 0.45; // 스마트폰에서 높이 대폭 감소
                    
                    return Image.asset(
                      _isQuestMap ? 'assets/images/map_Quest.png' : 'assets/images/map.png',
                      width: mapWidth,
                      height: mapHeight,
                      fit: BoxFit.contain,
                    );
                  },
                ),
                if (!_isQuestMap)
                  Positioned(
                    top: 0,
                    bottom: 0,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Please Enter',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: MediaQuery.of(context).size.width > 600 ? 42 : 28, // 스마트폰에서 폰트 크기 감소
                            fontWeight: FontWeight.bold,
                            fontFamily: 'DungGeunMo',
                            decoration: TextDecoration.none,
                          ),
                        ),
                        Text(
                          'the quest',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: MediaQuery.of(context).size.width > 600 ? 42 : 28, // 스마트폰에서 폰트 크기 감소
                            fontWeight: FontWeight.bold,
                            fontFamily: 'DungGeunMo',
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
