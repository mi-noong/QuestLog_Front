import 'package:flutter/material.dart';
import 'QuestScreen.dart';
import 'shop.dart';

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
                  // 캐릭터 아이콘
                  Image.asset(
                    'assets/images/Icon_MyPage.png',
                    width: 80,
                    height: 80,
                  ),

                  const SizedBox(width: 16),

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
                            ),
                          ),
                          const SizedBox(width: 8),
                          Image.asset(
                            'assets/images/Icon_HpBar_10.png',
                            width: 190,
                            height: 30,
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // XP 바
                      Row(
                        children: [
                          const Text(
                            'XP',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 24,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Image.asset(
                            'assets/images/Icon_XpBar_10.png',
                            width: 190,
                            height: 30,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 골드
              Row(
                children: [
                  Image.asset(
                    'assets/images/Icon_Gold.png',
                    width: 60,
                    height: 60,
                  ),
                  const Text(
                    '2500',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 25,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // 캘린더 아이콘
              Image.asset(
                'assets/images/Icon_Calendar.png',
                width: 60,
                height: 60,
              ),
            ],
          ),

          const Spacer(),

          // 오른쪽 섹션: 가방과 상점 아이콘들 (더 아래로)
          Column(
            children: [
              const SizedBox(height: 100), // 더 많이 아래로 이동
              Image.asset(
                'assets/images/Icon_Backpack.png',
                width: 60,
                height: 60,
              ),
              const SizedBox(height: 8),
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
                width: 400,
                height: 480,
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
      padding: const EdgeInsets.all(25.0),
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
                width: 250,
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
