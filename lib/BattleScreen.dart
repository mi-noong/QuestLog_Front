import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'AuthenticationWork.dart';
import 'AuthenticationExercise.dart';
import 'AuthenticationStudy.dart';
import 'HomeScreen.dart';
import 'config/api_config.dart';
import 'services/game_service.dart';

// 전투 화면에 전달할 파라미터
class BattleParams {
  final String questTitle;
  final String category; // 'work', 'exercise', 'study'
  final List<BattleQuest>? questList; // 일정 목록 (선택적)
  final int? currentQuestIndex; // 현재 일정 인덱스 (선택적)

  BattleParams({
    required this.questTitle,
    required this.category,
    this.questList,
    this.currentQuestIndex,
  });
}

// 일정 정보 클래스
class BattleQuest {
  final String questTitle;
  final String category;
  final int? taskId; // 일정 ID (백엔드에서 받아온 값, 선택적)

  BattleQuest({
    required this.questTitle,
    required this.category,
    this.taskId,
  });
}

// BattleScreen 위젯
class BattleScreen extends StatefulWidget {
  final BattleParams params;

  const BattleScreen({super.key, required this.params});

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> {
  late BattleGame game;
  bool battleStarted = false;
  bool showNextButton = false;
  late String currentQuestTitle; // 현재 일정 제목 (수정 가능)
  late String currentCategory; // 현재 카테고리 (수정 가능)

  @override
  void initState() {
    super.initState();
    
    // 현재 일정 제목 및 카테고리 초기화
    currentQuestTitle = widget.params.questTitle;
    currentCategory = widget.params.category;
    
    // 현재 일정의 taskId 찾기
    int? currentTaskId;
    if (widget.params.questList != null && 
        widget.params.currentQuestIndex != null &&
        widget.params.currentQuestIndex! < widget.params.questList!.length) {
      currentTaskId = widget.params.questList![widget.params.currentQuestIndex!].taskId;
    }

    game = BattleGame(
      questTitle: widget.params.questTitle,
      category: widget.params.category,
      taskId: currentTaskId,
      onBattleComplete: () {
        _handleNextQuest();
      },
      onBattleStart: () {
        setState(() {
          battleStarted = true;
        });
      },
      onNextButtonShow: () {
        setState(() {
          showNextButton = true;
        });
      },
      onRewardReceived: (exp, gold) {
        // 보상 정보 저장 (나중에 사용)
        game._rewardExp = exp;
        game._rewardGold = gold;
      },
      onTitleChanged: (newTitle) {
        setState(() {
          currentQuestTitle = newTitle;
        });
      },
      onCategoryChanged: (newCategory) {
        setState(() {
          currentCategory = newCategory;
        });
      },
    );
  }

  // 일정 완료 API 호출 (백그라운드에서 실행)
  Future<void> _completeQuest(bool isSuccess) async {
    try {
      final userDbId = await _getUserDbId();
      if (userDbId == null) {
        print('⚠️ 사용자 DB ID가 없어 일정 완료 API를 호출할 수 없습니다.');
        return;
      }

      int? taskId = game.taskId;
      
      // taskId가 없으면 오늘의 일정에서 찾기
      if (taskId == null) {
        taskId = await _findTaskIdByTitleAndCategory(userDbId);
      }

      if (taskId == null) {
        print('⚠️ taskId를 찾을 수 없어 일정 완료 API를 호출할 수 없습니다.');
        return;
      }

      print('📡 [백그라운드] 일정 완료 API 호출: taskId=$taskId, userId=$userDbId, isSuccess=$isSuccess');

      final url = ApiConfig.completeQuestEndpoint(taskId, userDbId, isSuccess);
      final response = await http.put(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      print('📡 [백그라운드] 일정 완료 API 응답: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          // 일정 상태 확인
          final data = result['data'];
          if (data != null) {
            final status = data['status'] as String? ?? '';
            final title = data['title'] as String? ?? '';
            
            if (isSuccess) {
              print('✅ [백그라운드] 일정 완료 성공: "$title" -> 상태: $status');
              // 완료 상태 확인
              if (status.toLowerCase() == 'done') {
                print('✅ 일정 상태가 "done"으로 변경됨');
              } else {
                print('⚠️ 일정 상태가 예상과 다름: $status (예상: done)');
              }
            } else {
              print('❌ [백그라운드] 일정 실패 처리: "$title" -> 상태: $status');
              // 실패 상태 확인
              if (status.toLowerCase() == 'fail') {
                print('❌ 일정 상태가 "fail"로 변경됨');
              } else {
                print('⚠️ 일정 상태가 예상과 다름: $status (예상: fail)');
              }
            }
          }
          
          // 성공 시 보상 정보 가져오기 (레벨 기반 계산) - 백그라운드에서 실행
          if (isSuccess) {
            // await 없이 백그라운드에서 실행하되, 보상 화면 표시 전까지는 대기하지 않음
            _fetchRewardInfoForGame(userDbId).catchError((error) {
              print('❌ [백그라운드] 보상 정보 가져오기 오류: $error');
            });
            
            // 보너스 보상 확인 (완료된 일정이 6개 이상일 때)
            _checkBonusReward(userDbId).catchError((error) {
              print('❌ [백그라운드] 보너스 보상 확인 오류: $error');
            });
          }
        } else {
          print('❌ [백그라운드] 일정 완료 실패: ${result['message']}');
        }
      } else {
        print('❌ [백그라운드] 일정 완료 실패: HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [백그라운드] 일정 완료 API 호출 오류: $e');
    }
  }

  // 사용자 DB ID 가져오기
  Future<int?> _getUserDbId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('userDbId');
    } catch (e) {
      print('❌ 사용자 DB ID 가져오기 실패: $e');
      return null;
    }
  }

  // 제목과 카테고리로 taskId 찾기
  Future<int?> _findTaskIdByTitleAndCategory(int userId) async {
    try {
      print('🔍 오늘의 일정에서 taskId 찾기: title="${widget.params.questTitle}", category="${widget.params.category}"');
      
      final url = ApiConfig.todayQuestsEndpoint(userId);
      print('📡 API 호출 URL: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      print('📡 API 응답 상태: ${response.statusCode}');
      print('📡 API 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        print('📋 파싱된 결과: success=${result['success']}, data=${result['data']}');
        
        if (result['success'] == true && result['data'] != null) {
          final tasks = result['data']['tasks'] as List<dynamic>?;
          print('📋 일정 개수: ${tasks?.length ?? 0}');
          
          if (tasks != null && tasks.isNotEmpty) {
            // 카테고리 매핑 (소문자 -> 대문자)
            String apiCategory = widget.params.category.toUpperCase();
            // 이미 대문자이므로 그대로 사용
            print('🔍 찾을 카테고리: $apiCategory');
            print('🔍 찾을 제목: "${widget.params.questTitle}"');
            
            // 모든 일정 출력 (디버깅)
            for (int i = 0; i < tasks.length; i++) {
              final task = tasks[i];
              print('  [$i] taskId=${task['taskId']}, title="${task['title']}", category="${task['category']}", status="${task['status']}"');
            }

            // 먼저 정확한 매칭 시도 (TODO, PENDING)
            for (var task in tasks) {
              final taskTitle = task['title']?.toString().trim() ?? '';
              final taskCategory = task['category']?.toString() ?? '';
              final taskStatus = task['status']?.toString() ?? '';
              
              if (taskTitle == widget.params.questTitle.trim() && 
                  taskCategory.toUpperCase() == apiCategory &&
                  (taskStatus == 'TODO' || taskStatus == 'PENDING')) {
                final taskIdValue = task['taskId'];
                final foundTaskId = taskIdValue is int ? taskIdValue : (taskIdValue as num?)?.toInt();
                if (foundTaskId != null) {
                  print('✅ taskId 찾음 (정확한 매칭): $foundTaskId');
                  return foundTaskId;
                }
              }
            }
            
            // 정확한 매칭 실패 시 status 무시하고 매칭 시도
            print('⚠️ 정확한 매칭 실패, status 무시하고 다시 시도');
            for (var task in tasks) {
              final taskTitle = task['title']?.toString().trim() ?? '';
              final taskCategory = task['category']?.toString() ?? '';
              
              if (taskTitle == widget.params.questTitle.trim() && 
                  taskCategory.toUpperCase() == apiCategory) {
                final taskIdValue = task['taskId'];
                final foundTaskId = taskIdValue is int ? taskIdValue : (taskIdValue as num?)?.toInt();
                if (foundTaskId != null) {
                  print('✅ taskId 찾음 (status 무시): $foundTaskId');
                  return foundTaskId;
                }
              }
            }
            
            // 카테고리만 매칭 시도
            print('⚠️ 카테고리 매칭 실패, 첫 번째 일치하는 카테고리 일정 반환');
            for (var task in tasks) {
              final taskCategory = task['category']?.toString() ?? '';
              if (taskCategory.toUpperCase() == apiCategory) {
                final taskIdValue = task['taskId'];
                final foundTaskId = taskIdValue is int ? taskIdValue : (taskIdValue as num?)?.toInt();
                if (foundTaskId != null) {
                  print('⚠️ taskId 찾음 (카테고리만 매칭): $foundTaskId');
                  return foundTaskId;
                }
              }
            }
          }
        } else {
          print('⚠️ API 응답이 실패했거나 data가 null입니다.');
        }
      } else {
        print('⚠️ API 응답 상태 코드가 200이 아닙니다: ${response.statusCode}');
      }
      
      print('⚠️ taskId를 찾을 수 없습니다.');
      return null;
    } catch (e) {
      print('❌ 오늘의 일정 조회 실패: $e');
      print('❌ 오류 스택: ${StackTrace.current}');
      return null;
    }
  }

  // 보상 정보 가져오기 (보상 화면 표시 전까지 대기 가능)
  Future<void> _fetchRewardInfoForGame(int userId, {Duration? maxWaitTime}) async {
    try {
      print('💰 [백그라운드] 보상 정보 가져오기 시작');
      
      // 일정 완료 후 정보 조회 (약간의 딜레이 후)
      await Future.delayed(const Duration(milliseconds: 300));
      
      final userInfoAfter = await GameService.getUserGameInfo(userId);
      final level = userInfoAfter.level;

      print('💰 [백그라운드] 사용자 레벨: $level');

      // 레벨별 보상 계산
      int rewardExp = _calculateTaskExp(level);
      int rewardGold = _calculateTaskGold(level);

      print('💰 [백그라운드] 계산된 보상 (레벨 $level): +$rewardExp exp, +$rewardGold G');

      // 게임에 보상 정보 전달 (보상 화면 표시 전까지 대기 중이면 즉시 반영)
      if (game.onRewardReceived != null) {
        game.onRewardReceived!(rewardExp, rewardGold);
      }
    } catch (e) {
      print('❌ [백그라운드] 보상 정보 가져오기 실패: $e');
    }
  }

  // 보너스 보상 확인 (모든 일정 완료 시 - 6개 모두 완료)
  Future<void> _checkBonusReward(int userId) async {
    try {
      print('🎁 [백그라운드] 보너스 보상 확인 시작');
      
      // 일정 완료 후 약간의 딜레이 (백엔드 상태 업데이트 대기)
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 오늘의 일정 조회 (bossReady 및 완료된 일정 수 확인)
      final url = ApiConfig.todayQuestsEndpoint(userId);
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true && result['data'] != null) {
          final bossReady = result['data']['bossReady'] as bool? ?? false;
          final completedTasks = result['data']['completedTasks'] as int? ?? 0;
          final totalTasks = result['data']['totalTasks'] as int? ?? 0;
          
          print('🎁 [백그라운드] 보너스 보상 확인: bossReady=$bossReady, completedTasks=$completedTasks, totalTasks=$totalTasks');
          
          // 보너스 보상 조건: 완료된 일정이 6개 이상이고 bossReady가 true
          if (bossReady && completedTasks >= 6) {
            // 보너스 보상 지급 확인 (+50 exp, +15G는 자동 지급됨)
            print('🎉 [백그라운드] 모든 일정 완료! 보너스 보상 지급됨 (+50 exp, +15G)');
            print('   완료된 일정: $completedTasks개 / 전체: $totalTasks개');
            
            // 게임에 보너스 보상 정보 전달
            game._hasBonusReward = true;
          } else {
            print('📊 [백그라운드] 보너스 보상 조건 미충족: completedTasks=$completedTasks (6개 필요), bossReady=$bossReady');
          }
        }
      }
    } catch (e) {
      print('❌ [백그라운드] 보너스 보상 확인 실패: $e');
    }
  }

  // 레벨별 경험치 계산 (가이드 문서 참조)
  int _calculateTaskExp(int level) {
    if (level <= 5) {
      return 10 + (level - 1);
    } else if (level <= 10) {
      return 16 + (level - 6);
    } else if (level <= 15) {
      return 20 + (level - 11);
    } else {
      return 25 + (level - 16);
    }
  }

  // 레벨별 골드 계산 (가이드 문서 참조)
  int _calculateTaskGold(int level) {
    if (level <= 5) {
      return 5;
    } else if (level <= 10) {
      return 10;
    } else if (level <= 15) {
      return 15;
    } else {
      return 20 + ((level - 16) ~/ 5) * 5;
    }
  }

  // 일정 수정 API 호출
  Future<void> _updateQuest(String title, String category) async {
    try {
      final userDbId = await _getUserDbId();
      if (userDbId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('로그인이 필요합니다.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      int? taskId = game.taskId;
      
      // taskId가 없으면 오늘의 일정에서 찾기
      if (taskId == null) {
        taskId = await _findTaskIdByTitleAndCategory(userDbId);
      }

      if (taskId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('일정을 찾을 수 없습니다.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // 카테고리 매핑 (소문자 -> 대문자)
      String apiCategory = category.toUpperCase();

      // 기존 일정 정보 조회 (시간 정보 가져오기)
      String? existingTime;
      try {
        final questUrl = ApiConfig.todayQuestsEndpoint(userDbId);
        final questResponse = await http.get(
          Uri.parse(questUrl),
          headers: {'Content-Type': 'application/json'},
        ).timeout(const Duration(seconds: 10));
        
        if (questResponse.statusCode == 200) {
          final questResult = jsonDecode(questResponse.body);
          if (questResult['success'] == true && questResult['data'] != null) {
            final tasks = questResult['data']['tasks'] as List<dynamic>?;
            if (tasks != null) {
              for (var task in tasks) {
                if (task['taskId'] == taskId) {
                  existingTime = task['time']?.toString() ?? '00:00';
                  break;
                }
              }
            }
          }
        }
      } catch (e) {
        print('⚠️ 기존 일정 시간 조회 실패: $e');
      }
      
      // 시간이 없으면 기본값 사용
      if (existingTime == null) {
        existingTime = '00:00';
      }

      // 날짜 형식: YYYY-MM-DD (오늘 날짜)
      final dateStr = DateTime.now().toIso8601String().split('T')[0];

      // Request Body 구성
      final requestBody = {
        'title': title,
        'memo': '', // 메모는 수정하지 않음
        'category': apiCategory,
        'date': dateStr,
        'time': existingTime, // 기존 시간 유지
      };

      print('📡 일정 수정 API 호출:');
      print('   URL: ${ApiConfig.updateQuestEndpoint(taskId, userDbId)}');
      print('   Body: $requestBody');

      final response = await http.put(
        Uri.parse(ApiConfig.updateQuestEndpoint(taskId, userDbId)),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 10));

      print('📡 일정 수정 API 응답: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          // 화면 갱신
          setState(() {
            currentQuestTitle = title;
            currentCategory = category;
          });
          
          // 게임의 제목과 카테고리 업데이트
          game.updateTitle(title);
          game.updateCategory(category);
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('일정이 수정되었습니다.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('일정 수정 실패: ${result['message']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        // 400 오류 시 응답 본문의 상세 메시지 표시
        String errorMessage = '일정 수정 실패: HTTP ${response.statusCode}';
        try {
          final errorBody = jsonDecode(response.body);
          if (errorBody['message'] != null) {
            errorMessage = '일정 수정 실패: ${errorBody['message']}';
          } else if (errorBody['error'] != null) {
            errorMessage = '일정 수정 실패: ${errorBody['error']}';
          }
        } catch (e) {
          // JSON 파싱 실패 시 원본 메시지 사용
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('❌ 일정 수정 API 호출 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('일정 수정 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 일정 수정 다이얼로그 표시
  Future<void> _showEditQuestDialog() async {
    final TextEditingController titleController = TextEditingController(text: currentQuestTitle);
    String selectedCategory = currentCategory;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.transparent,
          contentPadding: EdgeInsets.zero,
          content: Container(
            width: 500,
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              image: const DecorationImage(
                image: AssetImage('assets/images/Quest_Background.png'),
                fit: BoxFit.fill,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '일정 수정',
                  style: TextStyle(
                    fontFamily: 'DungGeunMo',
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 20),
                // 제목 입력
                SizedBox(
                  width: 200,
                  height: 100,
                  child: Stack(
                    children: [
                      Image.asset(
                        'assets/images/Quest_Input.png',
                        width: 280,
                        height: 80,
                        fit: BoxFit.contain,
                        alignment: Alignment.center,
                        filterQuality: FilterQuality.high,
                      ),
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 38),
                          child: TextField(
                            controller: titleController,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            style: const TextStyle(
                              fontFamily: 'DungGeunMo',
                              color: Colors.black,
                              fontSize: 20,
                            ),
                            cursorColor: Colors.black,
                            decoration: const InputDecoration(
                              isCollapsed: true,
                              border: InputBorder.none,
                              hintText: '제목을 입력하세요',
                              hintStyle: TextStyle(color: Colors.grey),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // 카테고리 선택
                CategoryDropdown(
                  width: 150,
                  selectedCategory: selectedCategory,
                  onCategoryChanged: (category) {
                    setDialogState(() {
                      selectedCategory = category;
                    });
                  },
                ),
                const SizedBox(height: 20),
                // 저장 버튼
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                      },
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.asset(
                            'assets/images/MainButtonSquare.png',
                            width: 70,
                            height: 70,
                          ),
                          const Text(
                            '취소',
                            style: TextStyle(
                              fontFamily: 'DungGeunMo',
                              color: Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    GestureDetector(
                      onTap: () {
                        if (titleController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('제목을 입력해주세요.'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }
                        
                        Navigator.pop(context);
                        _updateQuest(titleController.text.trim(), selectedCategory);
                      },
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.asset(
                            'assets/images/MainButton.png',
                            width: 110,
                            height: 70,
                          ),
                          const Text(
                            '저장',
                            style: TextStyle(
                              fontFamily: 'DungGeunMo',
                              color: Colors.black,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleNextQuest() {
    final questList = widget.params.questList;
    final currentIndex = widget.params.currentQuestIndex;
    
    print('🔍 NEXT 버튼 클릭 - questList: ${questList?.length}, currentIndex: $currentIndex');
    
    // 일정 목록이 없거나 현재가 마지막 일정이면 HomeScreen으로 이동
    if (questList == null || questList.isEmpty || currentIndex == null || currentIndex >= questList.length - 1) {
      print('✅ 모든 일정 완료 - HomeScreen으로 이동');
      // 모든 일정 완료 - HomeScreen으로 이동
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false, // 모든 이전 화면 제거
      );
    } else {
      // 다음 일정이 있으면 다음 BattleScreen으로 이동
      final nextIndex = currentIndex + 1;
      print('➡️ 다음 일정으로 이동 - nextIndex: $nextIndex, 총 일정: ${questList.length}');
      final nextQuest = questList[nextIndex];
      print('📋 다음 일정: ${nextQuest.questTitle} (${nextQuest.category})');
      
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => BattleScreen(
            params: BattleParams(
              questTitle: nextQuest.questTitle,
              category: nextQuest.category,
              questList: questList,
              currentQuestIndex: nextIndex,
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTapDown: (details) {
          // NEXT 버튼이 Flutter 위젯으로 처리되므로 여기서는 보물상자만 처리
          final RenderBox box = context.findRenderObject() as RenderBox;
          final localPosition = box.globalToLocal(details.globalPosition);
          final tapPosition = Vector2(localPosition.dx, localPosition.dy);
          
          // 보물상자 탭 처리
          if (game._treasureChest != null && !game._treasureChest!._isOpen) {
            if (game._treasureChest!.handleTap(tapPosition)) {
              // 보물상자가 열림
            }
          }
        },
        child: Stack(
          children: [
            GameWidget<BattleGame>(game: game),
            // 일정 수정 버튼 (왼쪽 아래, 전투 시작 전에만 표시)
            if (!battleStarted)
              Positioned(
                bottom: 50,
                left: 20,
                child: GestureDetector(
                  onTap: _showEditQuestDialog,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.asset(
                        'assets/images/MainButtonSquare.png',
                        width: 60,
                        height: 60,
                      ),
                      const Icon(
                        Icons.edit,
                        color: Colors.black,
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
            // NEXT 버튼 (보상/실패 화면 후에 표시, Quest_Background.png 안에 위치)
            if (showNextButton)
              Positioned(
                // Quest_Background.png 배경 계산:
                // 배경 중심 Y: size.y / 1.8 ≈ 화면 높이의 55.6%
                // 배경 높이: size.y * 0.57 ≈ 화면 높이의 57%
                // 배경 상단 Y = (size.y / 1.8) - (size.y * 0.57 / 2) ≈ 화면 높이의 27.1%
                // 배경 하단 Y = (size.y / 1.8) + (size.y * 0.57 / 2) ≈ 화면 높이의 84.1%
                // 보상 텍스트: size.y / 2 + 40 ≈ 화면 높이의 50% + 40
                // 실패 화면: size.y / 1.8 + 80 ≈ 화면 높이의 55.6% + 80
                // NEXT 버튼을 텍스트 아래, 배경 안쪽에 배치
                top: MediaQuery.of(context).size.height / 2 + 110, // 보상 텍스트 아래
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () {
                      // NEXT 버튼 클릭 시 전투 완료 처리
                      _handleNextQuest();
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.asset(
                          'assets/images/MainButton.png',
                          width: 200,
                          height: 70,
                        ),
                        const Text(
                          'NEXT',
                          style: TextStyle(
                            fontFamily: 'DungGeunMo',
                            color: Colors.black,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            // 일정 완료/실패 버튼 (전투 시작 전에만 표시)
            if (!battleStarted)
              Positioned(
                bottom: 50,
                left: 0,
                right: 0,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 일정 완료 버튼
                      GestureDetector(
                        onTap: () async {
                          // 카테고리별로 인증 화면으로 이동 (수정된 카테고리 사용)
                          final normalizedCategory = currentCategory.toLowerCase().trim();
                          Widget authScreen;
                          
                          switch (normalizedCategory) {
                            case 'exercise':
                              authScreen = const AuthenticationExercise();
                              break;
                            case 'study':
                              authScreen = const AuthenticationStudy();
                              break;
                            case 'work':
                              authScreen = const AuthenticationWork();
                              break;
                            default:
                              authScreen = const AuthenticationWork();
                              break;
                          }
                          
                          // 인증 화면으로 이동하고 결과를 기다림
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => authScreen),
                          );
                          
                          // 인증이 완료되면 (result가 true이면) 애니메이션 먼저 시작, API는 백그라운드에서 처리
                          if (result == true) {
                            // 애니메이션 먼저 시작
                            game.changeMonsterToCannon();
                            game.startBattle();
                            setState(() {
                              battleStarted = true;
                            });
                            
                            // 백그라운드에서 일정 완료 API 호출 (await 하지 않음)
                            _completeQuest(true).catchError((error) {
                              print('❌ 백그라운드 일정 완료 API 오류: $error');
                            });
                          }
                        },
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Image.asset(
                              'assets/images/MainButton.png',
                              width: 200,
                              height: 70,
                            ),
                            const Text(
                              '일정 완료',
                              style: TextStyle(
                                fontFamily: 'DungGeunMo',
                                color: Colors.black,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),
                      // 일정 실패 버튼
                      GestureDetector(
                        onTap: () async {
                          // 일정 완료 API 호출 (실패)
                          await _completeQuest(false);
                          
                          // 일정 실패 처리 - 몬스터 공격 애니메이션 시작
                          game.startFailure();
                          setState(() {
                            battleStarted = true;
                          });
                        },
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Image.asset(
                              'assets/images/MainButton.png',
                              width: 200,
                              height: 70,
                            ),
                            const Text(
                              '일정 실패',
                              style: TextStyle(
                                fontFamily: 'DungGeunMo',
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
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Flame 게임 클래스
class BattleGame extends FlameGame {
  final String questTitle;
  final String category;
  final VoidCallback onBattleComplete;
  final VoidCallback? onBattleStart;
  final VoidCallback? onNextButtonShow;
  final int? taskId; // 일정 ID (백엔드용)
  final Function(int exp, int gold)? onRewardReceived; // 보상 받았을 때 콜백
  final Function(String)? onTitleChanged; // 제목 변경 시 콜백
  final Function(String)? onCategoryChanged; // 카테고리 변경 시 콜백

  BattleGame({
    required this.questTitle,
    required this.category,
    required this.onBattleComplete,
    this.onBattleStart,
    this.onNextButtonShow,
    this.taskId,
    this.onRewardReceived,
    this.onTitleChanged,
    this.onCategoryChanged,
  }) : _currentCategory = category;

  late Character character;
  late Monster monster;
  late TextComponent titleText;
  bool _battleStarted = false;
  bool _rewardShown = false;
  TreasureChest? _treasureChest;
  int? _rewardExp;
  int? _rewardGold;
  bool _hasBonusReward = false; // 보너스 보상 여부
  String _currentCategory; // 현재 카테고리 (수정 가능)

  void changeMonsterToCannon() {
    monster.changeToCannon();
  }

  void startFailure() {
    if (_battleStarted) return;
    _battleStarted = true;
    _startFailureBattle();
  }

  // 몬스터 크기 가져오기 (죽음 애니메이션 설정용)
  Vector2 _getMonsterSizeForDeath(String category) {
    final normalizedCategory = category.toLowerCase().trim();
    switch (normalizedCategory) {
      case 'work':
        return Vector2(180, 180);
      case 'exercise':
        return Vector2(180, 180);
      case 'study':
        return Vector2(178, 225);
      default:
        return Vector2(180, 180);
    }
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // 배경 색상 설정
    camera.viewfinder.visibleGameSize = size;
    
    // 배경 이미지 추가 (MainForestScreen.png)
    try {
      final backgroundSprite = await loadSprite('MainForestScreen.png');
      final background = SpriteComponent(
        sprite: backgroundSprite,
      );
      // 배경 이미지를 화면 전체에 맞춤
      background.size = size;
      background.position = Vector2.zero();
      add(background);
    } catch (e) {
      // 이미지가 없으면 기본 색상 배경 사용
      print('배경 이미지를 찾을 수 없습니다: $e');
      add(RectangleComponent(
        size: size,
        paint: Paint()..color = const Color(0xFF1a1a2e),
      ));
    }

    // 타이틀 배경 이미지 (map_row.png)
    try {
      final titleBgSprite = await loadSprite('map_row.png');
      final titleBackground = SpriteComponent(
        sprite: titleBgSprite,
        position: Vector2(size.x / 2, 120),
        anchor: Anchor.center,
        size: Vector2(size.x * 0.9, 110), // 이미지 크기를 줄임 (화면 너비의 80%, 높이 60)
      );
      titleBackground.priority = 0; // 텍스트보다 낮은 priority로 배경에 배치
      add(titleBackground);
    } catch (e) {
      print('타이틀 배경 이미지를 찾을 수 없습니다: $e');
    }

    // 타이틀 텍스트
    titleText = TextComponent(
      text: questTitle,
      textRenderer: TextPaint(
        style: const TextStyle(
          fontFamily: 'DungGeunMo',
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
    );
    titleText.position = Vector2(size.x / 2, 120);
    titleText.anchor = Anchor.center;
    titleText.priority = 1; // 배경 이미지보다 높은 priority로 텍스트가 위에 표시
    add(titleText);

    // 캐릭터 생성 및 추가
    character = Character(category: category);
    character.position = Vector2(size.x * 0.26, size.y / 1.67);
    character.anchor = Anchor.center;
    character.priority = 10; // 몬스터보다 높은 priority로 설정 (앞에 표시)
    add(character);
    print('✅ 캐릭터 추가 완료');

    // 몬스터 생성 및 추가
    print('🎮 BattleGame 초기화 - 카테고리: "$_currentCategory"');
    monster = Monster(category: _currentCategory);
    monster.position = Vector2(size.x * 0.76, size.y / 1.64);
    monster.anchor = Anchor.center;
    monster.priority = 1; // 캐릭터보다 낮은 priority로 설정 (뒤에 표시)
    
    // 죽음 애니메이션 크기와 위치 설정 (카테고리별로 다르게 설정)
    final originalSize = _getMonsterSizeForDeath(_currentCategory);
    final normalizedCategory = _currentCategory.toLowerCase().trim();
    
    switch (normalizedCategory) {
      case 'work':
        // 일 몬스터 죽음 애니메이션 설정
        monster.setDeathSize(originalSize.x * 1.0, originalSize.y * 1.0);
        monster.setDeathPosition(size.x * 0.8, size.y * 0.6);
        break;
      case 'exercise':
        // 운동 몬스터 죽음 애니메이션 설정
        monster.setDeathSize(originalSize.x * 1.0, originalSize.y * 1.0);
        monster.setDeathPosition(size.x * 0.8, size.y * 0.6);
        break;
      case 'study':
        // 공부 몬스터 죽음 애니메이션 설정
        monster.setDeathSize(originalSize.x * 0.8, originalSize.y * 0.8);
        monster.setDeathPosition(size.x * 0.8, size.y * 0.6);
        break;
      default:
        // 기본값
        monster.setDeathSize(originalSize.x * 1.1, originalSize.y * 1.1);
        monster.setDeathPosition(size.x * 0.8, size.y * 0.6);
        break;
    }
    
    // Cannon 이미지 크기와 위치 설정 (카테고리별로 다르게 설정)
    switch (normalizedCategory) {
      case 'work':
        // 일 몬스터 Cannon 이미지 설정
        monster.setCannonSize(originalSize.x * 1.2, originalSize.y * 0.9);
        monster.setCannonPosition(size.x * 0.71, size.y / 1.62);
        break;
      case 'exercise':
        // 운동 몬스터 Cannon 이미지 설정
        monster.setCannonSize(originalSize.x * 1.3, originalSize.y * 1.0);
        monster.setCannonPosition(size.x * 0.71, size.y / 1.64);
        break;
      case 'study':
        // 공부 몬스터 Cannon 이미지 설정
        monster.setCannonSize(originalSize.x * 1.1, originalSize.y * 0.8);
        monster.setCannonPosition(size.x * 0.73, size.y / 1.64);
        break;
      default:
        // 기본값
        monster.setCannonSize(originalSize.x * 1.1, originalSize.y * 0.8);
        monster.setCannonPosition(size.x * 0.73, size.y / 1.64);
        break;
    }
    
    add(monster);
    print('✅ 몬스터 추가 완료');
  }

  // 제목 업데이트 함수
  void updateTitle(String newTitle) {
    titleText.text = newTitle;
    onTitleChanged?.call(newTitle);
  }

  // 카테고리 업데이트 함수 (몬스터 이미지 변경)
  Future<void> updateCategory(String newCategory) async {
    _currentCategory = newCategory;
    onCategoryChanged?.call(newCategory);
    
    // 몬스터 이미지 변경
    try {
      // 기존 몬스터 제거
      monster.removeFromParent();
      
      // 새 몬스터 생성
      monster = Monster(category: newCategory);
      monster.position = Vector2(size.x * 0.76, size.y / 1.64);
      monster.anchor = Anchor.center;
      monster.priority = 1;
      
      // 죽음 애니메이션 크기와 위치 설정
      final originalSize = _getMonsterSizeForDeath(newCategory);
      final normalizedCategory = newCategory.toLowerCase().trim();
      
      switch (normalizedCategory) {
        case 'work':
          monster.setDeathSize(originalSize.x * 1.0, originalSize.y * 1.0);
          monster.setDeathPosition(size.x * 0.8, size.y * 0.6);
          break;
        case 'exercise':
          monster.setDeathSize(originalSize.x * 1.0, originalSize.y * 1.0);
          monster.setDeathPosition(size.x * 0.8, size.y * 0.6);
          break;
        case 'study':
          monster.setDeathSize(originalSize.x * 0.8, originalSize.y * 0.8);
          monster.setDeathPosition(size.x * 0.8, size.y * 0.6);
          break;
        default:
          monster.setDeathSize(originalSize.x * 1.1, originalSize.y * 1.1);
          monster.setDeathPosition(size.x * 0.8, size.y * 0.6);
          break;
      }
      
      // Cannon 이미지 크기와 위치 설정
      switch (normalizedCategory) {
        case 'work':
          monster.setCannonSize(originalSize.x * 1.2, originalSize.y * 0.9);
          monster.setCannonPosition(size.x * 0.71, size.y / 1.62);
          break;
        case 'exercise':
          monster.setCannonSize(originalSize.x * 1.3, originalSize.y * 1.0);
          monster.setCannonPosition(size.x * 0.71, size.y / 1.64);
          break;
        case 'study':
          monster.setCannonSize(originalSize.x * 1.1, originalSize.y * 0.8);
          monster.setCannonPosition(size.x * 0.73, size.y / 1.64);
          break;
        default:
          monster.setCannonSize(originalSize.x * 1.1, originalSize.y * 0.8);
          monster.setCannonPosition(size.x * 0.73, size.y / 1.64);
          break;
      }
      
      // 몬스터 로드 완료 대기
      await monster.onLoad();
      add(monster);
      
      print('✅ 몬스터 카테고리 변경 완료: $newCategory');
    } catch (e) {
      print('❌ 몬스터 카테고리 변경 실패: $e');
    }
  }

  void startBattle() {
    if (_battleStarted) return;
    _battleStarted = true;
    onBattleStart?.call();
    _startBattle();
  }

  Future<void> _startBattle() async {
    // 캐릭터가 몬스터에게 이동
    await character.moveTo(
      Vector2(size.x * 0.5, size.y / 1.6),
      speed: 200,
    );

    // 공격 애니메이션
    await character.attack();

    // 몬스터 피해 애니메이션
    await monster.takeDamage();

    // 몬스터가 사라지는 애니메이션
    await monster.die();

    // 보상 화면 표시 (NEXT 버튼으로 화면 종료)
    await _showReward();
    
    // 애니메이션 완료 후 자동으로 화면을 넘기지 않음
    // NEXT 버튼을 클릭해야만 화면이 종료됨
  }

  Future<void> _startFailureBattle() async {
    // 몬스터를 Cannon 이미지로 변경
    monster.changeToCannon();
    await Future.delayed(const Duration(milliseconds: 300));
    
    // 몬스터 공격 애니메이션
    monster.attack();
    await Future.delayed(const Duration(milliseconds: 500));
    
    // 발사체 이미지 경로 결정 (수정된 카테고리 사용)
    String projectileImage = 'rpg/Cannon_Work.png';
    switch (_currentCategory.toLowerCase().trim()) {
      case 'exercise':
        projectileImage = 'rpg/Cannon_Exercise.png';
        break;
      case 'study':
        projectileImage = 'rpg/Cannon_Study.png';
        break;
      case 'work':
        projectileImage = 'rpg/Cannon_Work.png';
        break;
    }
    
    // 발사체 스프라이트 로드
    final projectileSprite = await loadSprite(projectileImage);
    
    // 발사체 생성 (간단하게 SpriteComponent로)
    final projectile = SpriteComponent(
      sprite: projectileSprite,
      position: monster.position.clone(),
      anchor: Anchor.center,
      size: Vector2(100, 60),
    );
    projectile.priority = 10000;
    add(projectile);
    
    // 발사체를 캐릭터 위치로 이동
    final moveEffect = MoveToEffect(
      character.position,
      EffectController(duration: 0.8),
    );
    projectile.add(moveEffect);
    
    // 이동 완료 대기
    await moveEffect.completed;
    
    // 발사체 제거
    projectile.removeFromParent();
    
    // 캐릭터 죽음 애니메이션
    await character.die();
    
    // 실패 화면 표시
    await _showFailureScreen();
  }

  Future<void> _showReward() async {
    if (_rewardShown) return;
    _rewardShown = true;

    // Quest_Background.png 배경 추가 (화면 정중앙)
    try {
      final backgroundSprite = await loadSprite('Quest_Background.png');
      final rewardBackground = SpriteComponent(
        sprite: backgroundSprite,
        position: Vector2(size.x / 2, size.y / 1.8),
        anchor: Anchor.center,
        size: Vector2(size.x * 0.85, size.y * 0.57), // 적절한 크기
      );
      rewardBackground.priority = 5000; // 높은 priority
      add(rewardBackground);

      // Close_TreasureChest.png 추가 (보물상자)
      final chestSprite = await loadSprite('Close_TreasureChest.png');
      final treasureChest = TreasureChest(
        closedSprite: chestSprite,
      );
      treasureChest.position = Vector2(size.x / 2, size.y / 2 - 40); // 배경 중앙, 약간 위
      treasureChest.anchor = Anchor.center;
      treasureChest.priority = 6000; // 배경보다 높은 priority
      // 보물상자 크기 설정 (기본 크기의 0.7배로 축소)
      treasureChest.size = Vector2(treasureChest.size.x * 0.06, treasureChest.size.y * 0.06);
      add(treasureChest);
      
      // 보물상자 참조 저장
      _treasureChest = treasureChest;

      // 보상 텍스트는 보물상자가 열릴 때 추가됨
      TextComponent? rewardText;

      // 보물상자가 열릴 때까지 대기 (이 시간 동안 백그라운드에서 보상 정보가 도착할 수 있음)
      await treasureChest.waitForOpen();
      
      // 보상 정보가 도착할 때까지 최대 1초 대기 (이미 도착했으면 즉시 진행)
      int waitCount = 0;
      while (_rewardExp == null && _rewardGold == null && waitCount < 10) {
        await Future.delayed(const Duration(milliseconds: 100));
        waitCount++;
      }
      
      // 텍스트 표시 (실제 보상 값 사용, 도착하지 않았으면 기본값 사용)
      String rewardTextStr;
      if (_rewardExp != null && _rewardGold != null) {
        rewardTextStr = '+${_rewardExp}exp +${_rewardGold}G';
      } else {
        rewardTextStr = '+10exp +10G'; // 기본값 (API 실패 시)
        print('⚠️ 보상 정보가 아직 도착하지 않아 기본값 사용');
      }
      
      rewardText = TextComponent(
        text: rewardTextStr,
        textRenderer: TextPaint(
          style: const TextStyle(
            fontFamily: 'DungGeunMo',
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      );
      rewardText.position = Vector2(size.x / 2, size.y / 2 + 40); // 보물상자 아래
      rewardText.anchor = Anchor.center;
      rewardText.priority = 7000; // 가장 높은 priority
      add(rewardText);

      // 보너스 보상 표시 (모든 일정 완료 시)
      // 보너스 보상이 도착할 때까지 최대 1초 대기
      int bonusWaitCount = 0;
      while (!_hasBonusReward && bonusWaitCount < 10) {
        await Future.delayed(const Duration(milliseconds: 100));
        bonusWaitCount++;
      }
      
      if (_hasBonusReward) {
        // 보너스 보상 텍스트 추가
        final bonusText = TextComponent(
          text: '+50exp +15G (보너스)',
          textRenderer: TextPaint(
            style: const TextStyle(
              fontFamily: 'DungGeunMo',
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
        );
        bonusText.position = Vector2(size.x / 2, size.y / 2 + 70); // 일반 보상 아래
        bonusText.anchor = Anchor.center;
        bonusText.priority = 7001; // 가장 높은 priority
        add(bonusText);
        
        print('🎉 보너스 보상 표시: +50exp +15G');
      }

      // NEXT 버튼 표시 (Flutter 위젯으로 표시)
      onNextButtonShow?.call();
      
    } catch (e) {
      print('보상 이미지를 찾을 수 없습니다: $e');
    }
  }

  Future<void> _showFailureScreen() async {
    // Quest_Background.png 배경 추가 (화면 정중앙)
    try {
      final backgroundSprite = await loadSprite('Quest_Background.png');
      final failureBackground = SpriteComponent(
        sprite: backgroundSprite,
        position: Vector2(size.x / 2, size.y / 1.8),
        anchor: Anchor.center,
        size: Vector2(size.x * 0.85, size.y * 0.57), // 적절한 크기
      );
      failureBackground.priority = 5000; // 높은 priority
      add(failureBackground);

      // '일정 실패' 텍스트
      final failureTitle = TextComponent(
        text: '일정 실패',
        textRenderer: TextPaint(
          style: const TextStyle(
            fontFamily: 'DungGeunMo',
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      );
      failureTitle.position = Vector2(size.x / 2, size.y / 1.8 - 60); // 배경 중앙 위쪽
      failureTitle.anchor = Anchor.center;
      failureTitle.priority = 7000;
      add(failureTitle);

      // '-HP 30' 텍스트
      final hpLossText = TextComponent(
        text: '-HP 30',
        textRenderer: TextPaint(
          style: const TextStyle(
            fontFamily: 'DungGeunMo',
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
      );
      hpLossText.position = Vector2(size.x / 2, size.y / 1.8 + 10); // 실패 텍스트 아래
      hpLossText.anchor = Anchor.center;
      hpLossText.priority = 7000;
      add(hpLossText);

      // NEXT 버튼 표시 (Flutter 위젯으로 표시)
      onNextButtonShow?.call();
      
    } catch (e) {
      print('실패 화면 이미지를 찾을 수 없습니다: $e');
    }
  }
}

// 캐릭터 컴포넌트
class Character extends SpriteAnimationComponent with HasGameRef {
  final String category;
  SpriteAnimation? _walkAnimation;
  SpriteAnimation? _idleAnimation;
  SpriteAnimation? _fightAnimation;
  SpriteAnimation? _diedAnimation;

  Character({required this.category});

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // 크기를 먼저 설정 (이미지 로드 전에)
    size = Vector2(165, 165);
    
    // 기본 상태 이미지 (Ch_Basic.png)
    try {
      final idleSprite = await gameRef.loadSprite('rpg/Ch_Basic.png');
      _idleAnimation = SpriteAnimation.spriteList([idleSprite], stepTime: 1.0);
      animation = _idleAnimation;
      print('✅ 캐릭터 기본 이미지 로드 성공: rpg/Ch_Basic.png');
    } catch (e) {
      // 이미지가 없으면 기본 이미지로 대체
      try {
        final fallbackSprite = await gameRef.loadSprite('Female_Character.png');
        _idleAnimation = SpriteAnimation.spriteList([fallbackSprite], stepTime: 1.0);
        animation = _idleAnimation;
        print('✅ 캐릭터 대체 이미지 로드 성공: Female_Character.png');
      } catch (e2) {
        print('❌ 캐릭터 이미지를 찾을 수 없습니다: $e, $e2');
      }
    }
    
    // 걷기 애니메이션 로드
    await _loadWalkAnimation();
    
    // 공격 애니메이션 로드
    await _loadFightAnimation();
    
    // 죽음 애니메이션 로드
    await _loadDiedAnimation();
  }

  Future<void> _loadWalkAnimation() async {
    try {
      final List<Sprite> walkSprites = [];
      for (int i = 1; i <= 5; i++) {
        try {
          final sprite = await gameRef.loadSprite('rpg/Ch_Walk_0$i.png');
          walkSprites.add(sprite);
        } catch (e) {
          print('걷기 프레임 $i 로드 실패: $e');
        }
      }
      
      if (walkSprites.isNotEmpty) {
        _walkAnimation = SpriteAnimation.spriteList(
          walkSprites,
          stepTime: 0.1, // 각 프레임 표시 시간 (0.1초)
          loop: true,
        );
        print('✅ 걷기 애니메이션 로드 완료: ${walkSprites.length}프레임');
      } else {
        print('⚠️ 걷기 애니메이션 프레임을 찾을 수 없습니다');
      }
    } catch (e) {
      print('❌ 걷기 애니메이션 로드 실패: $e');
    }
  }

  Future<void> moveTo(Vector2 target, {required double speed}) async {
    // 걷기 애니메이션 시작
    if (_walkAnimation != null) {
      animation = _walkAnimation;
    }
    
    final effect = MoveToEffect(
      target,
      EffectController(duration: 0.5),
    );
    add(effect);
    await effect.completed;
    
    // 이동 완료 후 기본 애니메이션으로 복귀
    if (_idleAnimation != null) {
      animation = _idleAnimation;
    }
  }

  Future<void> _loadFightAnimation() async {
    try {
      final List<Sprite> fightSprites = [];
      for (int i = 1; i <= 5; i++) {
        try {
          final sprite = await gameRef.loadSprite('rpg/Ch_Fight_0$i.png');
          fightSprites.add(sprite);
        } catch (e) {
          print('공격 프레임 $i 로드 실패: $e');
        }
      }
      
      if (fightSprites.isNotEmpty) {
        _fightAnimation = SpriteAnimation.spriteList(
          fightSprites,
          stepTime: 0.15, // 각 프레임 표시 시간 (0.15초)
          loop: false, // 공격은 한 번만 재생
        );
        print('✅ 공격 애니메이션 로드 완료: ${fightSprites.length}프레임');
      } else {
        print('⚠️ 공격 애니메이션 프레임을 찾을 수 없습니다');
      }
    } catch (e) {
      print('❌ 공격 애니메이션 로드 실패: $e');
    }
  }

  Future<void> attack() async {
    // 공격 애니메이션 시작
    if (_fightAnimation != null) {
      animation = _fightAnimation;
    }
    
    // 약간 앞으로 이동
    final originalPos = position.clone();
    final attackPos = position + Vector2(50, 0);
    
    // 앞으로 이동
    final moveForward = MoveToEffect(
      attackPos,
      EffectController(duration: 0.2),
    );
    add(moveForward);
    await moveForward.completed;

    // 공격 애니메이션이 끝날 때까지 대기 (5프레임 * 0.15초 = 0.75초)
    await Future.delayed(const Duration(milliseconds: 750));

    // 뒤로 이동
    final moveBack = MoveToEffect(
      originalPos,
      EffectController(duration: 0.2),
    );
    add(moveBack);
    await moveBack.completed;
    
    // 기본 애니메이션으로 복귀
    if (_idleAnimation != null) {
      animation = _idleAnimation;
    }
  }

  Future<void> _loadDiedAnimation() async {
    try {
      final List<Sprite> diedSprites = [];
      for (int i = 1; i <= 4; i++) {
        try {
          final sprite = await gameRef.loadSprite('rpg/Ch_Died_0$i.png');
          diedSprites.add(sprite);
        } catch (e) {
          print('죽음 프레임 $i 로드 실패: $e');
        }
      }
      
      if (diedSprites.isNotEmpty) {
        _diedAnimation = SpriteAnimation.spriteList(
          diedSprites,
          stepTime: 0.2, // 각 프레임 표시 시간 (0.2초)
          loop: false, // 죽음은 한 번만 재생
        );
        print('✅ 죽음 애니메이션 로드 완료: ${diedSprites.length}프레임');
      } else {
        print('⚠️ 죽음 애니메이션 프레임을 찾을 수 없습니다');
      }
    } catch (e) {
      print('❌ 죽음 애니메이션 로드 실패: $e');
    }
  }

  Future<void> die() async {
    print('💀 캐릭터가 공격받았습니다!');
    
    // 흔들림 효과 (몬스터와 유사한 패턴)
    final originalPosition = position.clone();
    print('💀 흔들림 시작 - 원래 위치: ${originalPosition.x}, ${originalPosition.y}');
    
    for (int i = 0; i < 5; i++) {
      position = originalPosition + Vector2(
        (i % 2 == 0 ? 1 : -1) * 15,
        (i % 2 == 0 ? -1 : 1) * 10,
      );
      await Future.delayed(const Duration(milliseconds: 50));
      position = originalPosition;
    }
    
    // 최종 위치로 복귀
    position = originalPosition;
    print('💀 흔들림 완료');
    
    // 죽음 애니메이션 재생
    if (_diedAnimation != null) {
      print('💀 죽음 애니메이션 재생 시작');
      print('💀 현재 애니메이션 프레임 수: ${_diedAnimation!.frames.length}');
      animation = _diedAnimation;
      
      // 애니메이션이 제대로 설정되었는지 확인
      print('💀 애니메이션 설정 완료 - animation: ${animation != null ? "설정됨" : "null"}');
      print('💀 현재 opacity: $opacity, size: ${size.x}x${size.y}, position: ${position.x}, ${position.y}');
      
      // 첫 프레임 재생 (Ch_Died_01) - 1프레임 * 0.2초 = 0.2초
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Ch_Died_02, 03, 04가 재생될 때 위치를 아래로 조정
      position = originalPosition + Vector2(0, 40); // 아래로 40픽셀 이동
      print('💀 Ch_Died_02, 03, 04 위치 조정 - 아래로 이동: ${position.y}');
      
      // 마지막 3프레임(Ch_Died_02, 03, 04) 재생 - 3프레임 * 0.2초 = 0.6초
      await Future.delayed(const Duration(milliseconds: 600));
      print('💀 죽음 애니메이션 재생 완료');
    } else {
      print('⚠️ 죽음 애니메이션이 없습니다! _diedAnimation이 null입니다.');
    }
    
    // 페이드아웃
    print('💀 페이드아웃 시작');
    final fadeOut = OpacityEffect.to(
      0,
      EffectController(duration: 1.2),
    );
    add(fadeOut);
    await fadeOut.completed;
    
    print('💀 캐릭터 죽음 애니메이션 완료');
  }
}

// 몬스터 컴포넌트
class Monster extends SpriteAnimationComponent with HasGameRef {
  final String category;
  SpriteAnimation? _deathAnimation;
  SpriteAnimation? _idleAnimation;
  SpriteAnimation? _cannonAnimation;
  SpriteAnimation? _cannonShootAnimation;

  // 죽음 애니메이션 크기 및 위치 조절 변수
  Vector2 deathSize = Vector2.zero(); // zero면 기본 크기 유지
  Vector2? deathPosition; // null이면 기본 위치 유지

  // Cannon 애니메이션 크기 및 위치 조절 변수
  Vector2 cannonSize = Vector2.zero(); // zero면 기본 크기 유지
  Vector2? cannonPosition; // null이면 기본 위치 유지

  Monster({required this.category});

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // 카테고리별로 다른 크기를 먼저 설정 (이미지 로드 전에)
    size = _getMonsterSize(category);
    
    // 카테고리에 따라 다른 몬스터 기본 이미지 사용
    String imagePath = _getMonsterImagePath(category);
    print('🔍 몬스터 이미지 로드 시도: $imagePath');
    try {
      final idleSprite = await gameRef.loadSprite(imagePath);
      _idleAnimation = SpriteAnimation.spriteList([idleSprite], stepTime: 1.0);
      animation = _idleAnimation;
      print('✅ 몬스터 이미지 로드 성공: $imagePath');
    } catch (e) {
      // 이미지가 없으면 기본 캐릭터 이미지로 대체
      try {
        final fallbackSprite = await gameRef.loadSprite('Female_Character.png');
        _idleAnimation = SpriteAnimation.spriteList([fallbackSprite], stepTime: 1.0);
        animation = _idleAnimation;
        print('⚠️ 몬스터 이미지를 찾을 수 없어 기본 이미지 사용: $imagePath');
      } catch (e2) {
        print('❌ 몬스터 이미지를 찾을 수 없습니다: $imagePath, $e, $e2');
      }
    }
    
    // 죽음 애니메이션 로드
    await _loadDeathAnimation();
    
    // Cannon 애니메이션 로드
    await _loadCannonAnimation();
    
    // Cannon Shoot 공격 애니메이션 로드
    await _loadCannonShootAnimation();
  }

  Future<void> _loadCannonAnimation() async {
    try {
      final cannonImagePath = _getCannonImagePath(category);
      final cannonSprite = await gameRef.loadSprite(cannonImagePath);
      _cannonAnimation = SpriteAnimation.spriteList([cannonSprite], stepTime: 1.0);
      print('✅ Cannon 애니메이션 로드 완료: $cannonImagePath');
    } catch (e) {
      print('⚠️ Cannon 이미지를 찾을 수 없습니다: $e');
    }
  }

  Future<void> _loadCannonShootAnimation() async {
    try {
      final shootImagePath = _getCannonShootImagePath(category);
      final shootSprite = await gameRef.loadSprite(shootImagePath);
      _cannonShootAnimation = SpriteAnimation.spriteList([shootSprite], stepTime: 1.0);
      print('✅ Cannon Shoot 애니메이션 로드 완료: $shootImagePath');
    } catch (e) {
      print('⚠️ Cannon Shoot 이미지를 찾을 수 없습니다: $e');
    }
  }

  String _getCannonShootImagePath(String category) {
    final normalizedCategory = category.toLowerCase().trim();
    switch (normalizedCategory) {
      case 'exercise':
        return 'rpg/Monster_Exercise_Cannon_Shoot.png';
      case 'study':
        return 'rpg/Monster_Study_Cannon_Shoot.png';
      case 'work':
        return 'rpg/Monster_Work_Cannon_Shoot.png';
      default:
        return 'rpg/Monster_Work_Cannon_Shoot.png'; // 기본값
    }
  }

  void attack() {
    // Cannon Shoot 공격 애니메이션 재생
    if (_cannonShootAnimation != null) {
      animation = _cannonShootAnimation;
      print('🔥 몬스터 공격 애니메이션 시작');
    }
  }

  String _getCannonImagePath(String category) {
    final normalizedCategory = category.toLowerCase().trim();
    switch (normalizedCategory) {
      case 'exercise':
        return 'rpg/Monster_Exercise_Cannon.png';
      case 'study':
        return 'rpg/Monster_Study_Cannon.png';
      case 'work':
        return 'rpg/Monster_Work_Cannon.png';
      default:
        return 'rpg/Monster_Work_Cannon.png'; // 기본값
    }
  }

  void changeToCannon() {
    if (_cannonAnimation != null) {
      // Cannon 이미지 크기 조절
      if (cannonSize != Vector2.zero()) {
        size = cannonSize;
      }
      
      // Cannon 이미지 위치 조절
      if (cannonPosition != null) {
        position = cannonPosition!;
      }
      
      animation = _cannonAnimation;
      print('🔄 몬스터를 Cannon 이미지로 변경 (크기: ${size.x}x${size.y}, 위치: ${position.x}, ${position.y})');
    }
  }

  // Cannon 이미지 크기 설정
  void setCannonSize(double width, double height) {
    cannonSize = Vector2(width, height);
  }

  // Cannon 이미지 위치 설정
  void setCannonPosition(double x, double y) {
    cannonPosition = Vector2(x, y);
  }

  Future<void> _loadDeathAnimation() async {
    try {
      final List<Sprite> deathSprites = [];
      final List<String> frameNames = _getDeathAnimationFrames(category);
      
      for (final frameName in frameNames) {
        try {
          final sprite = await gameRef.loadSprite(frameName);
          deathSprites.add(sprite);
        } catch (e) {
          print('죽음 프레임 "$frameName" 로드 실패: $e');
        }
      }
      
      if (deathSprites.isNotEmpty) {
        _deathAnimation = SpriteAnimation.spriteList(
          deathSprites,
          stepTime: 0.15, // 각 프레임 표시 시간 (0.15초)
          loop: false, // 죽음은 한 번만 재생
        );
        print('✅ 죽음 애니메이션 로드 완료: ${deathSprites.length}프레임');
      } else {
        print('⚠️ 죽음 애니메이션 프레임을 찾을 수 없습니다');
      }
    } catch (e) {
      print('❌ 죽음 애니메이션 로드 실패: $e');
    }
  }

  List<String> _getDeathAnimationFrames(String category) {
    final normalizedCategory = category.toLowerCase().trim();
    switch (normalizedCategory) {
      case 'exercise':
        return [
          'rpg/Monster_Exercise_Attacked.png',
          'rpg/Monster_Exercise_Attacked_2.png',
          'rpg/Monster_Exercise_Attacked_3.png',
          'rpg/Monster_Exercise_Dead.png',
        ];
      case 'study':
        return [
          'rpg/Monster_Study_Attacked.png',
          'rpg/Monster_Study_Attacked_2.png',
          'rpg/Monster_Study_Attacked_3.png',
          'rpg/Monster_Study_Dead.png',
        ];
      case 'work':
        return [
          'rpg/Monster_Work_Attacked.png',
          'rpg/Monster_Work_Attacked_2.png',
          'rpg/Monster_Work_Attacked_3.png',
          'rpg/Monster_Work_Dead.png',
        ];
      default:
        return []; // 기본값 (애니메이션 없음)
    }
  }

  Vector2 _getMonsterSize(String category) {
    final normalizedCategory = category.toLowerCase().trim();
    switch (normalizedCategory) {
      case 'work':
        return Vector2(180, 180); // 일 몬스터 크기
      case 'exercise':
        return Vector2(180, 180); // 운동 몬스터 크기
      case 'study':
        return Vector2(176, 227); // 공부 몬스터 크기
      default:
        return Vector2(180, 180); // 기본 크기
    }
  }

  String _getMonsterImagePath(String category) {
    // 카테고리에 따라 다른 몬스터 이미지 경로 반환
    final normalizedCategory = category.toLowerCase().trim();
    print('🔍 몬스터 이미지 경로 확인 - 카테고리: "$category" (정규화: "$normalizedCategory")');
    
    switch (normalizedCategory) {
      case 'work':
        print('✅ Work 몬스터 선택');
        return 'rpg/Monster_Work_Basic.png';
      case 'exercise':
        print('✅ Exercise 몬스터 선택');
        return 'rpg/Monster_Exercise_Basic.png';
      case 'study':
        print('✅ Study 몬스터 선택');
        return 'rpg/Monster_Study_Basic.png';
      default:
        print('⚠️ 알 수 없는 카테고리, 기본값(Work) 사용: "$normalizedCategory"');
        return 'rpg/Monster_Work_Basic.png'; // 기본값
    }
  }

  Future<void> takeDamage() async {
    // 흔들림 효과
    final originalPos = position.clone();
    
    for (int i = 0; i < 5; i++) {
      position = originalPos + Vector2(
        (i % 2 == 0 ? 1 : -1) * 15,
        (i % 2 == 0 ? -1 : 1) * 10,
      );
      await Future.delayed(const Duration(milliseconds: 50));
      position = originalPos;
    }

    // 죽음 애니메이션 재생 전에 크기와 위치 조절
    if (deathSize != Vector2.zero()) {
      size = deathSize;
    }
    
    if (deathPosition != null) {
      position = deathPosition!;
    }

    // 바로 죽음 애니메이션 재생
    if (_deathAnimation != null) {
      animation = _deathAnimation;
      // 죽음 애니메이션이 끝날 때까지 대기 (4프레임 * 0.15초 = 0.6초)
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  // 죽음 애니메이션 크기 설정
  void setDeathSize(double width, double height) {
    deathSize = Vector2(width, height);
  }

  // 죽음 애니메이션 위치 설정
  void setDeathPosition(double x, double y) {
    deathPosition = Vector2(x, y);
  }

  Future<void> die() async {
    // 사라지는 애니메이션(페이드 아웃)
    final fadeOut = OpacityEffect.to(
      0,
      EffectController(duration: 1.2),
    );
    add(fadeOut);

    await fadeOut.completed;
    removeFromParent();
  }
}

// 보물상자 컴포넌트
class TreasureChest extends SpriteComponent with HasGameRef {
  final Sprite closedSprite;
  Sprite? _openSprite;
  bool _isOpen = false;
  final Completer<void> _openCompleter = Completer<void>();

  TreasureChest({
    required this.closedSprite,
  }) : super(
          sprite: closedSprite,
        );

  Future<void> waitForOpen() => _openCompleter.future;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // Open_TreasureChest.png 로드
    try {
      _openSprite = await gameRef.loadSprite('Open_TreasureChest.png');
    } catch (e) {
      print('보물상자 열림 이미지를 찾을 수 없습니다: $e');
    }
  }

  bool handleTap(Vector2 tapPosition) {
    if (_isOpen) return false;
    
    // 탭 위치가 컴포넌트 영역 내에 있는지 확인
    final topLeft = position - size / 2;
    final bottomRight = position + size / 2;
    
    if (tapPosition.x >= topLeft.x && tapPosition.x <= bottomRight.x &&
        tapPosition.y >= topLeft.y && tapPosition.y <= bottomRight.y) {
      _handleTap();
      return true;
    }
    return false;
  }

  Future<void> _handleTap() async {
    // 흔들림 애니메이션
    await shake();
    // Open_TreasureChest.png로 변경
    await open();
  }

  Future<void> shake() async {
    final originalPos = position.clone();
    
    // 흔들림 애니메이션
    for (int i = 0; i < 8; i++) {
      position = originalPos + Vector2(
        (i % 2 == 0 ? 1 : -1) * 10,
        (i % 2 == 0 ? -1 : 1) * 8,
      );
      await Future.delayed(const Duration(milliseconds: 50));
      position = originalPos;
    }
    
    position = originalPos;
  }

  Future<void> open() async {
    if (_isOpen || _openSprite == null) return;
    _isOpen = true;
    
    // Open_TreasureChest.png로 변경
    sprite = _openSprite;
    
    // 완료 신호
    if (!_openCompleter.isCompleted) {
      _openCompleter.complete();
    }
  }
}

// NEXT 버튼 컴포넌트
class NextButton extends SpriteComponent with HasGameRef {
  final Sprite buttonSprite;
  final VoidCallback onTap;
  late TextComponent buttonText;

  NextButton({
    required this.buttonSprite,
    required this.onTap,
  }) : super(
          sprite: buttonSprite,
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    
    // 버튼 텍스트 추가
    buttonText = TextComponent(
      text: 'NEXT',
      textRenderer: TextPaint(
        style: const TextStyle(
          fontFamily: 'DungGeunMo',
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
      ),
    );
    buttonText.position = Vector2(size.x / 2, size.y / 2);
    buttonText.anchor = Anchor.center;
    buttonText.priority = 9000; // 버튼 이미지보다 위에 표시
    add(buttonText);
  }

  bool handleTap(Vector2 tapPosition) {
    // 탭 위치가 컴포넌트 영역 내에 있는지 확인
    final topLeft = position - size / 2;
    final bottomRight = position + size / 2;
    
    if (tapPosition.x >= topLeft.x && tapPosition.x <= bottomRight.x &&
        tapPosition.y >= topLeft.y && tapPosition.y <= bottomRight.y) {
      onTap();
      return true;
    }
    return false;
  }
}

// 카테고리 드롭다운 위젯
class CategoryDropdown extends StatefulWidget {
  final double width;
  final String selectedCategory;
  final ValueChanged<String>? onCategoryChanged;
  
  const CategoryDropdown({
    super.key, 
    required this.width, 
    required this.selectedCategory,
    this.onCategoryChanged,
  });

  @override
  State<CategoryDropdown> createState() => _CategoryDropdownState();
}

class _CategoryDropdownState extends State<CategoryDropdown> {
  bool _isOpen = false;
  String _selected = 'category';

  final List<String> _options = const ['study', 'exercise', 'work'];

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedCategory;
  }

  @override
  void didUpdateWidget(CategoryDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedCategory != widget.selectedCategory) {
      _selected = widget.selectedCategory;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _isOpen = !_isOpen;
            });
          },
          child: Container(
            width: widget.width,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEEC29C),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selected,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(
                  _isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: Colors.black,
                ),
              ],
            ),
          ),
        ),
        if (_isOpen)
          Container(
            width: widget.width,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEEC29C),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: _options.map((opt) {
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selected = opt;
                      _isOpen = false;
                    });
                    widget.onCategoryChanged?.call(opt);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text(
                      opt,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
