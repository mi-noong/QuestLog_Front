import 'package:flutter/material.dart';

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
              _buildTopInfoSection(),
              // 중앙 퀘스트 스크롤 영역
              Expanded(child: _buildQuestScrollSection()),
              // 하단 시작 버튼
              _buildBottomButtonSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 왼쪽 섹션
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 캐릭터 + HP/XP
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.asset('assets/images/Icon_MyPage.png', width: 80, height: 80),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('HP', style: TextStyle(color: Colors.black, fontSize: 24, fontFamily: 'DungGeunMo')),
                              const SizedBox(width: 4),
                              Expanded(
                                child: SizedBox(
                                  height: 70,
                                  child: Image.asset(
                                    'assets/images/Icon_HPBar_10.png',
                                    fit: BoxFit.fitWidth,
                                    alignment: Alignment.centerLeft,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Text('XP', style: TextStyle(color: Colors.black, fontSize: 24, fontFamily: 'DungGeunMo')),
                              const SizedBox(width: 4),
                              Expanded(
                                child: SizedBox(
                                  height: 70,
                                  child: Image.asset(
                                    'assets/images/Icon_XpBar_10.png',
                                    fit: BoxFit.fitWidth,
                                    alignment: Alignment.centerLeft,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Image.asset('assets/images/Icon_Gold.png', width: 70, height: 70),
                    const SizedBox(width: 4),
                    const Text('2500', style: TextStyle(color: Colors.black, fontSize: 24, fontFamily: 'DungGeunMo')),
                  ],
                ),
                const SizedBox(height: 8),
                Image.asset('assets/images/Icon_Calendar.png', width: 60, height: 60),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // 오른쪽 섹션: 가방/상점
          Column(
            children: [
              const SizedBox(height: 140),
              Image.asset('assets/images/Icon_Backpack.png', width: 60, height: 60),
              const SizedBox(height: 8),
              Image.asset('assets/images/Icon_Shop.png', width: 60, height: 60),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuestScrollSection() {
    return Container(
      margin: const EdgeInsets.all(16.0),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 맵 이미지 (여백 최소화)
            Image.asset(
              'assets/images/map.png',
              width: 900,
              height: 1300,
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
                      fontFamily: 'DungGeunMo',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'the quest',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 28,
                      fontFamily: 'DungGeunMo',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButtonSection() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: GestureDetector(
          onTap: () {
            // 시작 버튼 클릭 시 동작
            print('Start button tapped');
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.asset(
                'assets/images/MainButton.png',
                width: 280,
                height: 80,
              ),
              const Text(
                'Start',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 24,
                  fontFamily: 'DungGeunMo',
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
