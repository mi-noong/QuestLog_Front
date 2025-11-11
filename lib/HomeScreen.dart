import 'package:flutter/material.dart';
import 'QuestScreen.dart';
import 'shop.dart';
import 'MyPageScreen.dart';
import 'InventoryScreen.dart';
import 'CalendarScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config/api_config.dart';
import 'models/user_game_info.dart' as models;
import 'services/game_service.dart';
import 'services/sound_manager.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// 오늘의 일정 모델
class TodayTask {
  final int taskId;
  final String title;
  final String status; // "TODO", "DONE", "FAILED"

  TodayTask({
    required this.taskId,
    required this.title,
    required this.status,
  });

  factory TodayTask.fromJson(Map<String, dynamic> json) {
    return TodayTask(
      taskId: json['taskId'] ?? 0,
      title: json['title'] ?? '',
      status: json['status']?.toString().toUpperCase() ?? 'TODO',
    );
  }

  bool get isCompleted => status == 'DONE';
  bool get isFailed => status == 'FAILED' || status == 'FAIL';
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  models.UserGameInfo? userGameInfo;
  bool isLoadingUser = false;
  List<TodayTask> todayTasks = [];
  bool isLoadingTasks = false;
  int? selectedQuestIndex; // 클릭한 일정의 인덱스

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 로그인 후 하루 리셋 체크
    _checkDailyReset();
    // 사용자 게임 정보 로드
    _loadUserGameInfo();
    // SharedPreferences에서 일정 목록 로드 (백엔드 호출 대신)
    _loadQuestsFromStorage();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 앱이 다시 포커스될 때 일정과 사용자 정보 새로고침
      _loadQuestsFromStorage();
      _loadUserGameInfo();
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

  // SharedPreferences에서 일정 목록 로드 함수 (BattleScreen에서 받은 일정)
  Future<void> _loadQuestsFromStorage() async {
    print('🔄 _loadQuestsFromStorage() 호출됨');
    try {
      setState(() {
        isLoadingTasks = true;
      });
      final prefs = await SharedPreferences.getInstance();
      
      // SharedPreferences에서 일정 목록 읽기
      final questListJson = prefs.getString('questList');
      print('📦 questListJson: ${questListJson != null ? "있음" : "없음"}');
      if (questListJson != null) {
        final List<dynamic> questList = jsonDecode(questListJson);
        
        // 완료/실패 상태가 저장된 일정 목록 확인
        final completedQuestsJson = prefs.getString('completedQuests');
        Map<String, String> completedQuests = {}; // String 키로 변경 (taskId 또는 제목+카테고리)
        if (completedQuestsJson != null) {
          final Map<String, dynamic> completedMap = jsonDecode(completedQuestsJson);
          completedQuests = completedMap.map((key, value) => MapEntry(key, value.toString()));
          print('📊 저장된 완료/실패 상태: $completedQuests');
        } else {
          print('📊 저장된 완료/실패 상태 없음');
        }
        
        final tasks = questList.map((quest) {
          final taskId = quest['taskId'] ?? 0;
          final title = quest['title'] ?? '';
          final category = quest['category'] ?? '';
          
          // 완료/실패 상태 확인
          String? status;
          
          // 1. taskId로 먼저 확인 (taskId가 0보다 큰 경우)
          if (taskId > 0) {
            status = completedQuests[taskId.toString()];
            print('🔍 taskId로 상태 확인: taskId=$taskId, status=$status');
          }
          
          // 2. taskId로 찾지 못하면 제목+카테고리로 확인
          if (status == null) {
            final questKey = '${title}_${category}';
            status = completedQuests[questKey];
            print('🔍 제목+카테고리로 상태 확인: key=$questKey, status=$status');
          }
          
          // 3. 둘 다 없으면 PENDING (아직 BattleScreen에 가지 않은 일정)
          status = status ?? 'PENDING';
          
          print('📋 일정 상태 확인: title=$title, taskId=$taskId, category=$category, status=$status');
          
          // BattleQuest 형식에서 TodayTask로 변환
          return TodayTask(
            taskId: taskId,
            title: title,
            status: status, // 완료/실패 상태 또는 PENDING
          );
        }).toList();
        
        if (!mounted) return;
        setState(() {
          todayTasks = tasks;
          isLoadingTasks = false;
        });
        print('✅ SharedPreferences에서 일정 로드 완료: ${tasks.length}개');
      } else {
        if (!mounted) return;
        setState(() {
          todayTasks = [];
          isLoadingTasks = false;
        });
        print('📋 SharedPreferences에 일정 목록이 없습니다.');
      }
    } catch (e) {
      print('❌ 일정 로드 중 오류: $e');
      if (!mounted) return;
      setState(() {
        isLoadingTasks = false;
      });
    }
  }

  // 체력 바 이미지 선택 함수 (MyPageScreen과 동일 로직)
  String getHpBarImage(int hp, int maxHp) {
    // 10칸 기준 단계 계산
    final hpRatio = maxHp == 0 ? 0.0 : hp / maxHp;
    final level = (hpRatio * 10).clamp(0, 10).floor();
    if (level <= 0) {
      return 'assets/images/Icon_HpXp_EmptyBar.png';
    }
    return 'assets/images/Icon_HpBar_$level.png';
  }

  // 경험치 바 이미지 선택 함수 (MyPageScreen과 동일 로직)
  String getExpBarImage(int level, int exp) {
    // 레벨별 필요 경험치: 1레벨 100, 이후 레벨당 +50
    int requiredExp(int lvl) => 100 + (lvl - 1) * 50;
    final totalNeeded = requiredExp(level);
    final xpRatio = totalNeeded == 0 ? 0.0 : exp / totalNeeded;
    final level10 = (xpRatio * 10).clamp(0, 10).floor();
    if (level10 <= 0) {
      return 'assets/images/Icon_HpXp_EmptyBar.png';
    }
    return 'assets/images/Icon_XpBar_$level10.png';
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
                      SoundManager().playClick();
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
                            getHpBarImage(
                              userGameInfo?.hp ?? 100,
                              userGameInfo?.maxHp ?? 100, // 백엔드에서 가져온 maxHp 사용
                            ),
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
                    '${userGameInfo?.gold ?? 100}',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: backpackRightPosition),
                  GestureDetector(
                    onTap: () {
                      SoundManager().playClick();
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const InventoryScreen()),
                      );
                    },
                    child: Image.asset(
                      'assets/images/Icon_Backpack.png',
                      width: 60,
                      height: 60,
                    ),
                  ),
                ],
              ),

              // 캘린더 아이콘과 상점 아이콘
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      SoundManager().playClick();
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const CalendarScreen()),
                      );
                    },
                    child: Image.asset(
                      'assets/images/Icon_Calendar.png',
                      width: 55,
                      height: 55,
                    ),
                  ),
                  SizedBox(width: shopRightPosition),
                  GestureDetector(
                    onTap: () {
                      SoundManager().playClick();
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
    // 일정이 있으면 map_Quest.png, 없으면 map.png
    final hasQuests = todayTasks.isNotEmpty;
    final mapImage = hasQuests ? 'assets/images/map_Quest.png' : 'assets/images/map.png';

    return Container(
      child: SingleChildScrollView(
        child: Center(
          child: SizedBox(
            width: 380,
            height: 390,
            child: Stack(
              children: [
                // 맵 이미지 (여백 최소화)
                Center(
                  child: Image.asset(
                    mapImage,
                    width: 380,
                    height: 390,
                    fit: BoxFit.contain,
                  ),
                ),

                // 일정이 없을 때만 퀘스트 텍스트 표시
                if (!hasQuests)
                  const Center(
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

                // 일정 아이콘들 표시
                if (hasQuests) ..._buildQuestIcons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 각 슬롯의 위치와 크기 설정 (Alignment 사용)
  // 위에서부터 아래로 배치 (첫 번째 일정이 가장 위, 마지막 일정이 가장 아래)
  static const List<Map<String, dynamic>> _slotPositions = [
    {
      'alignment': Alignment(-0.255, -0.600),
      'width': 40.0,
      'height': 40.0
    }, // 슬롯 1: 상단 좌측 원형 노드 (첫 번째 일정 - 가장 위)
    {
      'alignment': Alignment(-0.34, -0.03),
      'width': 40.0,
      'height': 40.0
    }, // 슬롯 2: 좌측 중상단 원형 노드 (두 번째 일정)
    {
      'alignment': Alignment(0.139, -0.325),
      'width': 40.0,
      'height': 40.0
    }, // 슬롯 3: 우측 중상단 원형 노드 (세 번째 일정)
    {
      'alignment': Alignment(0.400, 0.07),
      'width': 40.0,
      'height': 40.0
    }, // 슬롯 4: 노드 2 바로 아래 원형 노드 (네 번째 일정)
    {
      'alignment': Alignment(0.082, 0.290),
      'width': 40.0,
      'height': 40.0
    }, // 슬롯 5: 좌측 중하단 원형 노드 (다섯 번째 일정)
    {
      'alignment': Alignment(-0.275, 0.592),
      'width': 40.0,
      'height': 40.0
    }, // 슬롯 6: 하단 좌측 원형 노드 (여섯 번째 일정 - 가장 아래)
  ];

  // 일정 아이콘들을 맵 위에 배치하는 함수
  List<Widget> _buildQuestIcons() {
    if (todayTasks.isEmpty) return [];

    final List<Widget> icons = [];
    final int taskCount = todayTasks.length;
    final int maxSlots = 6;

    print('📋 일정 개수: $taskCount');

    // 최대 6개 슬롯 모두 표시
    for (int i = 0; i < maxSlots; i++) {
      final slotPos = _slotPositions[i];
      final Alignment alignment = slotPos['alignment'] as Alignment;
      final double width = slotPos['width'] as double;
      final double height = slotPos['height'] as double;

      String? iconAsset;
      
      if (i < taskCount) {
        // 입력된 일정이 있는 경우: 상태에 따라 아이콘 선택
        final task = todayTasks[i];
        print('🔍 슬롯 $i: 일정 상태 확인 - taskId=${task.taskId}, title=${task.title}, status=${task.status}');
        
        // BattleScreen에서 완료/실패 상태에 따라 아이콘 표시
        if (task.isCompleted) {
          // 완료된 일정: 체크 아이콘 표시
          iconAsset = 'assets/images/Icon_Check.png';
          print('✅ 슬롯 $i: 완료 상태 - Icon_Check 표시 (status: ${task.status})');
        } else if (task.isFailed) {
          // 실패한 일정: 해골 아이콘 표시
          iconAsset = 'assets/images/Icon_Skull.png';
          print('❌ 슬롯 $i: 실패 상태 - Icon_Skull 표시 (status: ${task.status})');
        } else {
          // PENDING 상태: BattleScreen으로 아직 이동하지 않은 일정
          // 아이콘 표시 안 함
          print('⏳ 슬롯 $i: PENDING 상태 - 아이콘 표시 안 함 (status: ${task.status})');
          continue;
        }
      } else {
        // 빈 슬롯: 잠금 아이콘 표시
        iconAsset = 'assets/images/Icon_Lock.png';
      }

      final String finalIconAsset = iconAsset;
      
      print('📍 슬롯 $i: Alignment(${alignment.x}, ${alignment.y}), 아이콘: $finalIconAsset, 상태: ${i < taskCount ? todayTasks[i].status : "빈 슬롯"}');

      // 일정이 있는 경우에만 클릭 가능
      final String? questTitle = (i < taskCount) ? todayTasks[i].title : null;
      final bool isSelected = selectedQuestIndex == i;
      
      icons.add(
        Align(
          alignment: alignment,
          child: GestureDetector(
            onTap: questTitle != null ? () {
              print('🖱️ 아이콘 클릭: 슬롯 $i, 제목=$questTitle, 현재 선택된 인덱스=$selectedQuestIndex');
              setState(() {
                // 같은 아이콘을 다시 클릭하면 제목 숨김
                selectedQuestIndex = selectedQuestIndex == i ? null : i;
                print('🔄 선택된 인덱스 업데이트: $selectedQuestIndex');
              });
            } : null,
            child: Stack(
              clipBehavior: Clip.none, // 제목이 Stack 밖으로 나가도 표시되도록
              alignment: Alignment.center,
              children: [
                Image.asset(
                  finalIconAsset,
                  width: width,
                  height: height,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    print('❌ 아이콘 로드 실패: $finalIconAsset');
                    return Container(
                      width: width,
                      height: height,
                      color: Colors.red.withOpacity(0.5),
                      child: const Icon(Icons.error, color: Colors.red),
                    );
                  },
                ),
                // 클릭한 아이콘의 제목 표시
                if (isSelected && questTitle != null)
                  Positioned(
                    bottom: height / 2 + 10, // 아이콘 아래에 표시
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        questTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    print('✅ 생성된 아이콘 개수: ${icons.length}');
    return icons;
  }

  // 완료된 일정 개수 계산
  int get completedQuestCount {
    return todayTasks.where((task) => task.isCompleted).length;
  }

  // 보스 스테이지 열기
  void _openBossStage(BuildContext context) {
    SoundManager().playClick();
    // TODO: 보스 스테이지 화면으로 이동
    // 현재는 BattleScreen으로 이동하되 보스 모드로 설정
    // 보스 스테이지 화면이 있으면 해당 화면으로 이동
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('보스 스테이지가 열렸습니다!'),
        backgroundColor: Colors.purple,
        duration: Duration(seconds: 2),
      ),
    );
    // 보스 스테이지 화면으로 이동하는 코드 추가 필요
  }

  Widget _buildBottomButtonSection(BuildContext context) {
    final completedCount = completedQuestCount;
    final isBossStageAvailable = completedCount >= 6;
    
    return Container(
      padding: const EdgeInsets.all(11.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 보스 스테이지 버튼 (완료된 일정이 6개 이상일 때)
          if (isBossStageAvailable)
            GestureDetector(
              onTap: () => _openBossStage(context),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset(
                    'assets/images/MainButton.png',
                    width: 230,
                    height: 70,
                  ),
                  const Text(
                    'Boss Stage',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          if (isBossStageAvailable) const SizedBox(height: 10),
          // 일반 시작 버튼
          GestureDetector(
            onTap: () async {
              SoundManager().playClick();
              // 시작 버튼 클릭 시 QuestScreen으로 이동
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const QuestScreen()),
              );
              // QuestScreen에서 돌아올 때 일정 다시 로드
              _loadQuestsFromStorage();
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
        ],
      ),
    );
  }
}
