import 'package:flutter/material.dart';
import 'QuestScreen.dart';
import 'shop.dart';
import 'InventoryScreen.dart';
import 'MyPageScreen.dart' as MyPage;
import 'CalendarScreen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// 오늘의 일정 모델 (TaskResponse 기반)
class TodaySchedule {
  final String id;
  final String title;
  final bool isCompleted;
  final int index; // 맵 위에 표시할 순서

  TodaySchedule({
    required this.id,
    required this.title,
    required this.isCompleted,
    required this.index,
  });

  factory TodaySchedule.fromJson(Map<String, dynamic> json, int index) {
    // 백엔드 TaskResponse의 status 필드 확인
    // Task.TaskStatus가 DONE이면 완료, 그 외(PENDING, IN_PROGRESS)는 미완료
    final status = json['status']?.toString().toUpperCase() ?? '';
    final isCompleted = status == 'DONE';
    
    return TodaySchedule(
      id: json['id']?.toString() ?? json['taskId']?.toString() ?? '',
      title: json['title'] ?? '',
      isCompleted: isCompleted,
      index: index,
    );
  }
}

// 오늘의 일정 조회 API (백엔드 QuestController의 /today 엔드포인트 사용)
Future<List<TodaySchedule>> fetchTodaySchedules(String userId) async {
  try {
    final response = await http.get(
      Uri.parse('http://192.168.219.110:8083/api/auth/quests/today?userId=$userId'),
      headers: {'Content-Type': 'application/json'},
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true && data['data'] != null) {
        final responseData = data['data'];
        
        // QuestStatusResponse 구조: { tasks: [], completionRate: double, bossReady: boolean, ... }
        if (responseData['tasks'] != null) {
          List<dynamic> tasksJson = responseData['tasks'];
          return tasksJson.asMap().entries.map((entry) {
            return TodaySchedule.fromJson(entry.value, entry.key);
          }).toList();
        }
      }
    }
    return [];
  } catch (e) {
    print('오늘의 일정 조회 오류: $e');
    return [];
  }
}

// 사용자 ID 가져오기
Future<String> getUserId() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId');
    
    if (userId != null && userId.isNotEmpty) {
      return userId;
    } else {
      // TODO: 실제 로그인된 사용자 ID로 변경 필요
      return '1'; // 임시로 사용자 ID "1" 사용
    }
  } catch (e) {
    print('사용자 ID 가져오기 실패: $e');
    return '1'; // 기본값
  }
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  MyPage.UserGameInfo? userInfo;
  bool isLoading = true;
  List<TodaySchedule> todaySchedules = [];
  bool hasQuests = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 로그인 후 하루 리셋 체크
    _checkDailyReset();
    // 사용자 정보와 일정 데이터 로드
    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _refreshData();
    }
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
        Uri.parse('http://192.168.219.110:8083/api/game/daily-reset/$userDbId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );
      
      print('📡 하루 리셋 응답 상태: ${response.statusCode}');
      print('📡 하루 리셋 응답 내용: ${response.body}');
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
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

  Future<void> _loadData() async {
    try {
      setState(() {
        isLoading = true;
      });

      final prefs = await SharedPreferences.getInstance();
      final userDbId = prefs.getInt('userDbId');
      String userId;
      
      // userDbId가 있으면 우선 사용, 없으면 기존 방식 사용
      if (userDbId != null) {
        userId = userDbId.toString();
      } else {
        userId = await getUserId();
      }
      
      // 사용자 정보와 오늘의 일정을 동시에 로드
      final fetchedUserInfo = await MyPage.fetchUserGameInfo(userId);
      final schedules = await fetchTodaySchedules(userId);
      
      // 디버깅: 일정 데이터가 제대로 로드되었는지 확인
      print('일정 데이터 로드: ${schedules.length}개');
      for (var schedule in schedules) {
        print('  - ${schedule.title} (완료: ${schedule.isCompleted})');
      }
      
      if (mounted) {
        setState(() {
          userInfo = fetchedUserInfo;
          todaySchedules = schedules;
          hasQuests = schedules.isNotEmpty;
          isLoading = false;
        });
        print('hasQuests 업데이트: $hasQuests, 일정 개수: ${todaySchedules.length}');
      }
    } catch (e) {
      print('데이터 로드 중 오류 발생: $e');
      // 에러가 발생하면 빈 리스트로 설정
      if (mounted) {
        setState(() {
          todaySchedules = [];
          hasQuests = false;
          isLoading = false;
        });
      }
    }
  }
  
  // 화면이 다시 보일 때 데이터 갱신
  void _refreshData() {
    _loadData();
  }

  // HP 바 이미지 선택 함수 (MyPageScreen과 동일한 로직)
  String _getHPBarImagePath() {
    if (userInfo == null || userInfo!.maxHp == 0) {
      return 'assets/images/Icon_HpXp_EmptyBar.png';
    }
    
    // 10칸 기준 단계 계산
    final hpRatio = userInfo!.hp / userInfo!.maxHp;
    final level = (hpRatio * 10).clamp(0, 10).floor();
    
    if (level <= 0) {
      return 'assets/images/Icon_HpXp_EmptyBar.png';
    }
    return 'assets/images/Icon_HPBar_$level.png';
  }

  // XP 바 이미지 선택 함수 (MyPageScreen과 동일한 로직)
  String _getXPBarImagePath() {
    if (userInfo == null) {
      return 'assets/images/Icon_HpXp_EmptyBar.png';
    }
    
    // 레벨별 필요 경험치: 1레벨 100, 이후 레벨당 +50
    int requiredExp(int level) => 100 + (level - 1) * 50;
    final totalNeeded = requiredExp(userInfo!.level);
    final xpRatio = totalNeeded == 0 ? 0.0 : userInfo!.exp / totalNeeded;
    final level10 = (xpRatio * 10).clamp(0, 10).floor();
    
    if (level10 <= 0) {
      return 'assets/images/Icon_HpXp_EmptyBar.png';
    }
    return 'assets/images/Icon_XpBar_$level10.png';
  }

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
    final double barGap = isTablet ? 12.0 : 8.0; 
    final double iconSize = isTablet ? 69.0 : 45.0;
    final double fontSize = isTablet ? 45.0 : 24.0;
    final double barHeight = isTablet ? 80.0 : 60.0;
    final double sectionWidth = isTablet ? screenWidth * 0.48 : screenWidth * 0.45; 
    
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
                          MaterialPageRoute(
                            builder: (context) => MyPage.MyPageScreen(initialData: userInfo),
                          ),
                        ).then((_) {
                          // 마이페이지에서 돌아올 때 사용자 정보 갱신
                          _refreshData();
                        });
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
                                    isLoading ? 'assets/images/Icon_HPBar_10.png' : _getHPBarImagePath(),
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
                                    isLoading ? 'assets/images/Icon_XpBar_10.png' : _getXPBarImagePath(),
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
                      isLoading ? '0' : (userInfo?.gold ?? 0).toString(),
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
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const CalendarScreen()),
                    );
                  },
                  child: Image.asset(
                    'assets/images/Icon_Calendar.png',
                    width: iconSize,
                    height: iconSize,
                  ),
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
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const InventoryScreen()),
                    );
                  },
                  child: Image.asset(
                    'assets/images/Icon_Backpack.png',
                    width: iconSize,
                    height: iconSize,
                  ),
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
    return _QuestMapSection(
      hasQuests: hasQuests,
      schedules: todaySchedules,
      onRefresh: _refreshData,
    );
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
            ).then((_) {
              // QuestScreen에서 돌아올 때 데이터 갱신
              _refreshData();
            });
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
  final bool hasQuests;
  final List<TodaySchedule> schedules;
  final VoidCallback onRefresh;

  const _QuestMapSection({
    Key? key,
    required this.hasQuests,
    required this.schedules,
    required this.onRefresh,
  }) : super(key: key);

  @override
  State<_QuestMapSection> createState() => _QuestMapSectionState();
}

class _QuestMapSectionState extends State<_QuestMapSection> {
  // 퀘스트가 등록되어 있으면 map_Quest.png 표시
  bool get _shouldShowQuestMap => widget.hasQuests;
  
  // 선택된 일정 인덱스 (null이면 아무것도 선택되지 않음)
  int? selectedScheduleIndex;

  // 맵 위에 일정 상태 아이콘 배치하는 함수
  List<Widget> _buildScheduleIcons() {

    // 위에서부터 아래로 배치 (첫 번째 일정이 가장 위, 마지막 일정이 가장 아래)
    final nodePositions = [
      const Alignment(-0.275, -0.575),   // 0: 상단 좌측 원형 노드 (첫 번째 일정 - 가장 위)
      const Alignment(-0.35, 0.00),   // 1: 좌측 중상단 원형 노드 (두 번째 일정)
      const Alignment(0.139, -0.295),    // 2: 우측 중상단 원형 노드 (세 번째 일정)
      const Alignment(0.417, 0.10),   // 3: 노드 2 바로 아래 원형 노드 (네 번째 일정)
      const Alignment(0.082, 0.304),     // 4: 좌측 중하단 원형 노드 (다섯 번째 일정)
      const Alignment(-0.275, 0.595),      // 5: 하단 좌측 원형 노드 (여섯 번째 일정 - 가장 아래)
    ];

    List<Widget> icons = [];
    
    // 일정이 있는 노드에 일정 아이콘 표시
    for (int index = 0; index < widget.schedules.length && index < nodePositions.length; index++) {
      final schedule = widget.schedules[index];
      
      // 완료: 체크 아이콘, 미완료: 해골 아이콘
      final iconPath = schedule.isCompleted 
          ? 'assets/images/Icon_Check.png'
          : 'assets/images/Icon_Skull.png';
      
      icons.add(
        Positioned.fill(
          child: Align(
            alignment: nodePositions[index],
            child: GestureDetector(
              onTap: () {
                setState(() {
                  // 같은 아이콘을 다시 클릭하면 제목 숨김, 다른 아이콘을 클릭하면 해당 제목 표시
                  if (selectedScheduleIndex == index) {
                    selectedScheduleIndex = null;
                  } else {
                    selectedScheduleIndex = index;
                  }
                });
              },
              child: Image.asset(
                iconPath,
                width: 24,  // 원형 노드 안에 들어가도록 크기 조정
                height: 24,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      );
    }
    
    // 일정이 없는 노드에 락 아이콘 표시
    for (int index = widget.schedules.length; index < nodePositions.length; index++) {
      icons.add(
        Positioned.fill(
          child: Align(
            alignment: nodePositions[index],
            child: GestureDetector(
              onTap: () {
                setState(() {
                  // 락 아이콘 클릭 시 selectedScheduleIndex를 해당 인덱스로 설정
                  // (widget.schedules.length 이상의 값으로 락 아이콘임을 구분)
                  if (selectedScheduleIndex == index) {
                    selectedScheduleIndex = null;
                  } else {
                    selectedScheduleIndex = index;
                  }
                });
              },
              child: Image.asset(
                'assets/images/Icon_Lock.png',
                width: 23,  
                height: 23,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      );
    }
    
    return icons;
  }
  
  // 선택된 일정의 제목을 표시하는 위젯
  Widget? _buildSelectedScheduleTitle() {
    if (selectedScheduleIndex == null) {
      return null;
    }
    
    final nodePositions = [
      const Alignment(-0.275, -0.575),   // 0: 상단 좌측 원형 노드 (첫 번째 일정 - 가장 위)
      const Alignment(-0.35, 0.00),   // 1: 좌측 중상단 원형 노드 (두 번째 일정)
      const Alignment(0.139, -0.295),    // 2: 우측 중상단 원형 노드 (세 번째 일정)
      const Alignment(0.417, 0.10),   // 3: 노드 2 바로 아래 원형 노드 (네 번째 일정)
      const Alignment(0.082, 0.304),     // 4: 좌측 중하단 원형 노드 (다섯 번째 일정)
      const Alignment(-0.275, 0.595),      // 5: 하단 좌측 원형 노드 (여섯 번째 일정 - 가장 아래)
    ];
    
    // 락 아이콘인지 확인 (selectedScheduleIndex가 schedules.length 이상이면 락 아이콘)
    final isLockIcon = selectedScheduleIndex! >= widget.schedules.length;
    
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final fontSize = isTablet ? 14.0 : 12.0;
    
    // 락 아이콘인 경우 '퀘스트를 등록해 주세요.' 표시, 아니면 일정 제목 표시
    final title = isLockIcon ? '퀘스트를 등록해 주세요.' : widget.schedules[selectedScheduleIndex!].title;
    final textColor = isLockIcon ? Colors.red : Colors.black;
    
    return Positioned.fill(
      child: Align(
        alignment: nodePositions[selectedScheduleIndex!],
        child: Transform.translate(
          offset: Offset(0, -50), // 아이콘 위에 표시
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.black, width: 1),
            ),
            child: Text(
              title,
              style: TextStyle(
                color: textColor,
                fontSize: fontSize,
                fontFamily: 'DungGeunMo',
                decoration: TextDecoration.none,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: SingleChildScrollView(
        child: Center(
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
                    _shouldShowQuestMap ? 'assets/images/map_Quest.png' : 'assets/images/map.png',
                    width: mapWidth,
                    height: mapHeight,
                    fit: BoxFit.contain,
                  );
                },
              ),
              // 퀘스트가 등록되지 않았을 때만 "Please enter the quest" 표시
              if (!_shouldShowQuestMap)
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
                          fontSize: MediaQuery.of(context).size.width > 600 ? 42 : 28,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'DungGeunMo',
                          decoration: TextDecoration.none,
                        ),
                      ),
                      Text(
                        'the quest',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: MediaQuery.of(context).size.width > 600 ? 42 : 28,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'DungGeunMo',
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
              // 퀘스트가 등록되어 있으면 map_Quest.png 위에 일정 상태 아이콘 표시
              if (_shouldShowQuestMap)
                ..._buildScheduleIcons(),
              // 선택된 일정의 제목 표시
              if (_shouldShowQuestMap && selectedScheduleIndex != null)
                _buildSelectedScheduleTitle() ?? const SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }
}
