import 'package:flutter/material.dart';
import 'SettingScreen.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/api_config.dart';

// 사용자 DB ID 가져오기 헬퍼 함수 (일정 생성 API용)
Future<int?> getUserDbId() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final userDbId = prefs.getInt('userDbId');
    
    if (userDbId != null) {
      print('✅ 로그인한 사용자 DB ID: $userDbId');
      return userDbId;
    } else {
      print('⚠️ 로그인한 사용자 DB ID가 없습니다.');
      return null;
    }
  } catch (e) {
    print('❌ 사용자 DB ID 가져오기 실패: $e');
    return null;
  }
}

class QuestData {
  String title;
  String memo;
  String category;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  int? taskId; // 백엔드에서 받은 일정 ID

  QuestData({
    this.title = '',
    this.memo = '',
    this.category = 'category',
    this.startTime,
    this.endTime,
    this.taskId,
  });
}

class QuestScreen extends StatefulWidget {
  const QuestScreen({super.key});

  @override
  State<QuestScreen> createState() => _QuestScreenState();
}

class _QuestScreenState extends State<QuestScreen> {
  final PageController _pageController = PageController();
  final List<QuestCard> _questCards = [];
  final List<QuestData> _questDataList = [];
  int _currentIndex = 0;
  static const int _maxCards = 6;


  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // 첫 번째 카드 추가
    _addNewCard();
  }

  void _addNewCard() {
    if (_questCards.length < _maxCards) {
      setState(() {
        _questDataList.add(QuestData());
        _questCards.add(QuestCard(
          key: ValueKey(_questCards.length),
          questData: _questDataList.last,
          onDataChanged: (data) {
            _questDataList[_questCards.length - 1] = data;
          },
        ));
      });
    }
  }

  void _addNewCardAndMoveToLast() {
    if (_questCards.length < _maxCards) {
      _addNewCard();
      // 새 카드가 추가되면 마지막 페이지로 이동
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pageController.animateToPage(
          _questCards.length - 1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  void _removeCurrentCard() {
    if (_questCards.length > 1) {
      setState(() {
        _questDataList.removeAt(_currentIndex);
        _questCards.removeAt(_currentIndex);
        if (_currentIndex >= _questCards.length) {
          _currentIndex = _questCards.length - 1;
        }
      });
    }
  }

  Future<void> _scheduleNotifications() async {
    if (_questDataList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('저장할 퀘스트가 없습니다.')),
      );
      return;
    }

    // 백엔드로 일정 데이터 전송 (백그라운드에서 실행)
    _sendDataToBackend().catchError((error) {
      print('❌ 백그라운드 일정 저장 오류: $error');
    });

    // 모든 카드의 데이터를 저장하고 알림 설정 (백그라운드와 병행)
    for (int i = 0; i < _questDataList.length; i++) {
      QuestData data = _questDataList[i];
      if (data.startTime != null && data.endTime != null && data.title.isNotEmpty) {
        await _scheduleCardNotification(data, i);
      }
    }
    
    // 저장 시작 메시지 표시
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('일정을 저장하는 중...'),
        duration: Duration(seconds: 1),
        backgroundColor: Colors.blue,
      ),
    );
  }


  Future<void> _scheduleCardNotification(QuestData data, int cardIndex) async {
    // 백그라운드 서비스 호출
    try {
      const platform = MethodChannel('questlog/notification_service');
      
      String startMessage = '${data.title}를(을) 시작 할 시간입니다!';
      String endMessage = '${data.title}를(을) 완료 할 시간입니다!';
      
      await platform.invokeMethod('startNotificationService', {
        'startHour': data.startTime!.hour,
        'startMinute': data.startTime!.minute,
        'endHour': data.endTime!.hour,
        'endMinute': data.endTime!.minute,
        'startTimeText': _formatTimeOfDay(data.startTime),
        'endTimeText': _formatTimeOfDay(data.endTime),
        'title': data.title,
        'startMessage': startMessage,
        'endMessage': endMessage,
        'cardIndex': cardIndex,
      });
      
      print('✅ 카드 ${cardIndex + 1} 백그라운드 서비스 호출 성공');
    } catch (e) {
      print('❌ 카드 ${cardIndex + 1} 백그라운드 서비스 실패: $e');
    }
    
    // 백그라운드 서비스 성공 여부와 관계없이 Flutter 로컬 알림도 추가 설정
    await _scheduleFlutterNotification(data, cardIndex);
    
    // 추가로 Timer 방식도 백업으로 설정
    await _scheduleTimerNotification(data, cardIndex);
  }

  Future<void> _scheduleFlutterNotification(QuestData data, int cardIndex) async {
    try {
      FlutterLocalNotificationsPlugin _localNotification = FlutterLocalNotificationsPlugin();
      
      // 알림 채널 생성
    AndroidNotificationChannel channel = AndroidNotificationChannel(
        'questlog_reminders_${cardIndex}',
        'QuestLog Reminders ${cardIndex + 1}',
        description: 'Notifications for quest ${data.title}',
      importance: Importance.max,
    );

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin = 
        _localNotification.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(channel);
    
      // 시작 알림 스케줄링
      final DateTime now = DateTime.now();
      final DateTime startDateTime = _getNextDateTime(data.startTime!, now);
      final DateTime endDateTime = _getNextDateTime(data.endTime!, now);
      
      // 시작 알림
      final AndroidNotificationDetails startAndroidDetails = AndroidNotificationDetails(
        'questlog_reminders_${cardIndex}',
        'QuestLog Reminders ${cardIndex + 1}',
        channelDescription: 'Notifications for quest ${data.title}',
      importance: Importance.max,
      priority: Priority.max,
        enableVibration: true,
        playSound: true,
        showWhen: true,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        ongoing: false,
        autoCancel: true,
        channelShowBadge: true,
        icon: '@mipmap/ic_launcher',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: const BigTextStyleInformation(''),
      );
      final NotificationDetails startDetails = NotificationDetails(android: startAndroidDetails);
      
      // 종료 알림
      final AndroidNotificationDetails endAndroidDetails = AndroidNotificationDetails(
        'questlog_reminders_${cardIndex}',
        'QuestLog Reminders ${cardIndex + 1}',
        channelDescription: 'Notifications for quest ${data.title}',
        importance: Importance.max,
        priority: Priority.max,
        enableVibration: true,
        playSound: true,
        showWhen: true,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        ongoing: false,
        autoCancel: true,
        channelShowBadge: true,
        icon: '@mipmap/ic_launcher',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: const BigTextStyleInformation(''),
      );
      final NotificationDetails endDetails = NotificationDetails(android: endAndroidDetails);
      
      // 시작 알림 스케줄링
      int startId = (cardIndex + 1) * 1000 + 1; // 더 고유한 ID
      int endId = (cardIndex + 1) * 1000 + 2; // 더 고유한 ID
      
      print('📅 카드 ${cardIndex + 1} 알림 스케줄링:');
      print('   시작 ID: $startId, 시간: ${startDateTime.toString()}');
      print('   종료 ID: $endId, 시간: ${endDateTime.toString()}');
      
      // 매일 반복이 아닌 특정 시간에 한 번만 실행
      await _localNotification.zonedSchedule(
        startId,
        '${data.title} 시작 알림',
        '${data.title}를(을) 시작 할 시간입니다!',
        tz.TZDateTime.from(startDateTime, tz.local),
        startDetails,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        androidAllowWhileIdle: true,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'start_${cardIndex}',
        // matchDateTimeComponents 제거 - 한 번만 실행
      );
      
      // 종료 알림 스케줄링
      await _localNotification.zonedSchedule(
        endId,
        '${data.title} 종료 알림',
        '${data.title}를(을) 완료 할 시간입니다!',
        tz.TZDateTime.from(endDateTime, tz.local),
        endDetails,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        androidAllowWhileIdle: true,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'end_${cardIndex}',
        // matchDateTimeComponents 제거 - 한 번만 실행
      );
      
      print('✅ 카드 ${cardIndex + 1} Flutter 알림 스케줄링 성공');
      print('   시작 시간: ${_formatTimeOfDay(data.startTime)}');
      print('   종료 시간: ${_formatTimeOfDay(data.endTime)}');
    } catch (e) {
      print('❌ 카드 ${cardIndex + 1} Flutter 알림 실패: $e');
    }
  }

  DateTime _getNextDateTime(TimeOfDay timeOfDay, DateTime now) {
    DateTime scheduled = DateTime(now.year, now.month, now.day, timeOfDay.hour, timeOfDay.minute);
    
    print('🕐 시간 계산: 현재 ${now.toString()}, 설정 시간 ${scheduled.toString()}');
    
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
      print('📅 다음날로 변경: ${scheduled.toString()}');
    } else {
      print('✅ 오늘 시간 사용: ${scheduled.toString()}');
    }
    
    return scheduled;
  }

  String _formatTimeOfDay(TimeOfDay? timeOfDay) {
    if (timeOfDay == null) return '--:--';
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(timeOfDay.hour)}:${twoDigits(timeOfDay.minute)}';
  }

  Future<void> _scheduleTimerNotification(QuestData data, int cardIndex) async {
    try {
    final DateTime now = DateTime.now();
      final DateTime startDateTime = _getNextDateTime(data.startTime!, now);
      final DateTime endDateTime = _getNextDateTime(data.endTime!, now);

    // 시작 시간까지의 지연 시간 계산
    final Duration startDelay = startDateTime.difference(now);
    // 종료 시간까지의 지연 시간 계산
    final Duration endDelay = endDateTime.difference(now);

      print('⏰ 카드 ${cardIndex + 1} Timer 알림 설정:');
      print('   시작 시간까지 남은 시간: ${startDelay.inMinutes}분');
      print('   종료 시간까지 남은 시간: ${endDelay.inMinutes}분');

    // 시작 알림 타이머 설정
    if (startDelay.inMilliseconds > 0) {
        Timer(startDelay, () async {
          await _sendTimerNotification(
            (cardIndex + 1) * 10000 + 1,
            '${data.title} 시작 알림',
            '${data.title}를(을) 시작 할 시간입니다!',
        );
      });
    }

    // 종료 알림 타이머 설정
    if (endDelay.inMilliseconds > 0) {
        Timer(endDelay, () async {
          await _sendTimerNotification(
            (cardIndex + 1) * 10000 + 2,
            '${data.title} 종료 알림',
            '${data.title}를(을) 완료 할 시간입니다!',
        );
      });
    }

      print('✅ 카드 ${cardIndex + 1} Timer 알림 설정 성공');
    } catch (e) {
      print('❌ 카드 ${cardIndex + 1} Timer 알림 설정 실패: $e');
    }
  }

  Future<void> _sendTimerNotification(int id, String title, String body) async {
    try {
    FlutterLocalNotificationsPlugin _localNotification = FlutterLocalNotificationsPlugin();
    
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'questlog_timer_reminders',
        'QuestLog Timer Reminders',
        channelDescription: 'Timer-based notifications for quest reminders',
      importance: Importance.max,
      priority: Priority.max,
        enableVibration: true,
        playSound: true,
        showWhen: true,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        ongoing: false,
        autoCancel: true,
        channelShowBadge: true,
        icon: '@mipmap/ic_launcher',
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        styleInformation: const BigTextStyleInformation(''),
    );
    final NotificationDetails details = NotificationDetails(android: androidDetails);

      await _localNotification.show(id, title, body, details);
      print('✅ Timer 알림 발송 성공: $title');
    } catch (e) {
      print('❌ Timer 알림 발송 실패: $e');
    }
  }

  // 백엔드 API 호출 함수들
  Future<void> _sendDataToBackend() async {
    try {
      // DB ID 가져오기
      final userDbId = await getUserDbId();
      if (userDbId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('로그인이 필요합니다. 로그인 후 다시 시도해주세요.'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // 유효한 데이터만 필터링하여 개별 일정으로 생성
      int successCount = 0;
      int failCount = 0;
      
      for (int i = 0; i < _questDataList.length; i++) {
        QuestData data = _questDataList[i];
        if (data.title.isNotEmpty && data.startTime != null) {
          final taskId = await _createQuestInBackend(userDbId, data);
          if (taskId != null) {
            // taskId를 QuestData에 저장
            _questDataList[i].taskId = taskId;
            successCount++;
          } else {
            failCount++;
          }
        }
      }

      if (successCount > 0) {
        print('✅ 백엔드 일정 생성 성공: $successCount개');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$successCount개 일정이 저장되었습니다!'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      if (failCount > 0) {
        print('❌ 백엔드 일정 생성 실패: $failCount개');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$failCount개 일정 저장에 실패했습니다.'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }

      if (successCount == 0 && failCount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('전송할 유효한 퀘스트가 없습니다. 제목과 시간을 입력해주세요.'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('❌ 백엔드 데이터 전송 중 오류: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('백엔드 연결 오류: $e'),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // 카테고리 매핑 함수 (소문자 -> 대문자)
  String _mapCategoryToApiFormat(String category) {
    switch (category.toLowerCase()) {
      case 'study':
        return 'STUDY';
      case 'exercise':
        return 'EXERCISE';
      case 'work':
        return 'WORK';
      case 'hobby':
        return 'HOBBY';
      case 'social':
        return 'SOCIAL';
      case 'health':
        return 'HEALTH';
      case 'daily':
        return 'DAILY';
      default:
        return 'DAILY'; // 기본값
    }
  }

  // 개별 일정을 백엔드로 생성하는 함수 (taskId 반환)
  Future<int?> _createQuestInBackend(int userDbId, QuestData data) async {
    try {
      if (data.title.isEmpty || data.startTime == null) {
        print('⚠️ 유효하지 않은 데이터로 백엔드 전송 불가');
        return null;
      }

      // 날짜 형식: YYYY-MM-DD
      final dateStr = DateTime.now().toIso8601String().split('T')[0];
      
      // 시간 형식: HH:mm (startTime 사용)
      final timeStr = _formatTimeOfDay(data.startTime);

      // Request Body 구성
      final requestBody = {
        'title': data.title,
        'memo': data.memo.isNotEmpty ? data.memo : '',
        'category': _mapCategoryToApiFormat(data.category),
        'date': dateStr,
        'time': timeStr,
      };

      print('📡 일정 생성 API 호출:');
      print('   URL: ${ApiConfig.createQuestEndpoint(userDbId)}');
      print('   Body: $requestBody');

      final response = await http.post(
        Uri.parse(ApiConfig.createQuestEndpoint(userDbId)),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      );

      print('📡 백엔드 응답 상태: ${response.statusCode}');
      print('📡 백엔드 응답 내용: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          // taskId 추출
          final taskIdValue = responseData['data']?['taskId'];
          final taskId = taskIdValue is int ? taskIdValue : (taskIdValue as num?)?.toInt();
          
          if (taskId != null) {
            print('✅ 일정 생성 성공: ${data.title}, taskId=$taskId');
            return taskId;
          } else {
            print('⚠️ 일정 생성 성공했으나 taskId를 찾을 수 없음: ${data.title}');
            return null;
          }
        } else {
          print('❌ 일정 생성 실패: ${responseData['message']}');
          return null;
        }
      } else {
        print('❌ 일정 생성 실패: HTTP ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ 일정 생성 API 호출 실패: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
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
              // 상단 텍스트
              _buildTopTextSection(),

              // 카드 페이지뷰
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  itemCount: _questCards.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _questCards[index],
                    );
                  },
                ),
              ),

              // 고정 버튼들
              _buildFixedButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopTextSection() {
    return Container(
      padding: const EdgeInsets.all(10.0),
      child: Column(
        children: [
          const Center(
        child: Text(
          '오늘의 Quest를 \n  적어주세요',
          style: TextStyle(
            color: Colors.black,
            fontSize: 35,
            fontWeight: FontWeight.bold,
          ),
        ),
          ),
          const SizedBox(height: 10),
          // 카드 개수 표시
          Text(
            '${_questCards.length}/$_maxCards',
            style: const TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          // 페이지 인디케이터
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _questCards.length,
              (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _currentIndex == index ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _currentIndex == index ? Colors.black : Colors.grey,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFixedButtons() {
    return Container(
      padding: const EdgeInsets.all(10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Start 버튼 (현재 카드의 일정 정보로 전투 화면 이동)
          if (_questDataList.isNotEmpty && _currentIndex < _questDataList.length) ...[
            GestureDetector(
              onTap: () async {
                // 완료된 일정 목록 생성 (제목과 카테고리가 있는 일정만)
                final List<QuestData> validQuests = [];
                for (var questData in _questDataList) {
                  if (questData.title.isNotEmpty && 
                      questData.category.isNotEmpty && 
                      questData.category != 'category') {
                    validQuests.add(questData);
                  }
                }
                
                if (validQuests.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('완료된 일정이 없습니다.'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                  return;
                }
                
                // taskId가 없는 일정이 있으면 먼저 저장
                final userDbId = await getUserDbId();
                if (userDbId != null) {
                  bool needToSave = false;
                  for (int i = 0; i < validQuests.length; i++) {
                    final questIndex = _questDataList.indexOf(validQuests[i]);
                    if (questIndex != -1 && _questDataList[questIndex].taskId == null) {
                      needToSave = true;
                      print('📝 taskId가 없는 일정 발견, 저장 시작: ${validQuests[i].title}');
                      final taskId = await _createQuestInBackend(userDbId, validQuests[i]);
                      if (taskId != null) {
                        _questDataList[questIndex].taskId = taskId;
                        validQuests[i].taskId = taskId;
                        print('✅ 일정 저장 완료: ${validQuests[i].title}, taskId=$taskId');
                      } else {
                        print('⚠️ 일정 저장 실패: ${validQuests[i].title}');
                      }
                    }
                  }
                  
                  if (needToSave) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('일정을 저장하는 중...'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  }
                }
                
                // 일정 목록 생성 (taskId 포함)
                final List<Map<String, dynamic>> questList = [];
                for (var questData in validQuests) {
                  questList.add({
                    'title': questData.title,
                    'category': questData.category.toLowerCase(),
                    'taskId': questData.taskId, // taskId 포함
                  });
                }
                
                print('📋 QuestScreen - 일정 목록 생성: ${questList.length}개');
                for (int i = 0; i < questList.length; i++) {
                  print('  [$i] ${questList[i]['title']} (${questList[i]['category']}), taskId=${questList[i]['taskId']}');
                }
                
                // 항상 첫 번째 일정(인덱스 0)부터 시작
                final firstQuest = questList[0];
                print('📍 첫 번째 일정으로 시작: ${firstQuest['title']} (${firstQuest['category']}), taskId=${firstQuest['taskId']}');
                
                // SettingScreen으로 이동 (일정 정보 및 목록 전달)
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SettingScreen(
                      questTitle: firstQuest['title']!,
                      category: firstQuest['category']!,
                      questList: questList, // 전체 일정 목록 전달 (입력 순서대로)
                    ),
                  ),
                );
              },
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset(
                    'assets/images/MainButton.png',
                    width: 150,
                    height: 70,
                  ),
                  const Text(
                    'OK',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
          ],

          
          // 새 카드 추가 버튼
          GestureDetector(
            onTap: () {
              _addNewCardAndMoveToLast();
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
                  '+',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 10),
          
          // 삭제 버튼
          GestureDetector(
            onTap: () {
              _removeCurrentCard();
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
                  '-',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 30,
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

class QuestCard extends StatefulWidget {
  final QuestData questData;
  final Function(QuestData) onDataChanged;

  const QuestCard({super.key, required this.questData, required this.onDataChanged});

  @override
  State<QuestCard> createState() => _QuestCardState();
}

class _QuestCardState extends State<QuestCard> {
  bool _isCategoryOpen = false;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  Timer? _startTimer;
  Timer? _endTimer;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _memoController = TextEditingController();
  String _selectedCategory = 'category';
  
  // Quest_Background.png 위치 설정 변수
  static const double questBackgroundTop = -0; // Quest_Background.png의 top 위치

  @override
  void initState() {
    super.initState();
    // 데이터 초기화
    _titleController.text = widget.questData.title;
    _memoController.text = widget.questData.memo;
    _selectedCategory = widget.questData.category;
    _startTime = widget.questData.startTime;
    _endTime = widget.questData.endTime;
  }

  void _updateData() {
    widget.questData.title = _titleController.text;
    widget.questData.memo = _memoController.text;
    widget.questData.category = _selectedCategory;
    widget.questData.startTime = _startTime;
    widget.questData.endTime = _endTime;
    widget.onDataChanged(widget.questData);
  }

  String _formatTimeOfDay(TimeOfDay? timeOfDay) {
    if (timeOfDay == null) return '--:--';
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(timeOfDay.hour)}:${twoDigits(timeOfDay.minute)}';
  }

  Future<void> _pickStartTime() async {
    final TimeOfDay nowTod = TimeOfDay.now();
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _startTime ?? nowTod,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(primary: Colors.black),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _startTime = picked);
      _updateData();
    }
  }

  Future<void> _pickEndTime() async {
    final TimeOfDay nowTod = TimeOfDay.now();
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _endTime ?? _startTime ?? nowTod,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(primary: Colors.black),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _endTime = picked);
      _updateData();
    }
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _endTimer?.cancel();
    _titleController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
          // Quest_Background와 오버레이 요소들
          SizedBox(
            width: 650,
            height: 460,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Positioned(
                  top: questBackgroundTop,
                  child: Image.asset(
                    'assets/images/Quest_Background.png',
                    width: 650,
                    height: 460,
                    fit: BoxFit.contain,
                  ),
                ),

                // 상단 Quest_Input (오버레이 텍스트 입력)
                Positioned(
                  top: 50,
                  child: SizedBox(
                    width: 300,
                    height: 100,
                    child: Stack(
                      children: [
                        Image.asset(
                          'assets/images/Quest_Input.png',
                          width: 300,
                          height: 90,
                          fit: BoxFit.contain,
                          alignment: Alignment.center,
                          filterQuality: FilterQuality.high,
                        ),
                        Positioned.fill(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 38),
                            child: TextField(
                              controller: _titleController,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              style: TextStyle(color: Colors.black, fontSize: 20),
                              cursorColor: Colors.black,
                              onChanged: (value) => _updateData(),
                              decoration: InputDecoration(
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
                ),

                // Memo 라벨
                const Positioned(
                  top: 135,
                  left: 60,
                  child: Text(
                    'Memo',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // Memo 입력 영역
                Positioned(
                  top: 165,
                  left: 60,
                  child: SizedBox(
                    width: 200,
                    height: 90,
                    child: Stack(
                      children: [
                        Image.asset(
                          'assets/images/Quest_MemoInput.png',
                          width: 240,
                          height: 90,
                          fit: BoxFit.fill,
                        ),
                        Positioned.fill(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: TextField(
                              controller: _memoController,
                              maxLines: null,
                              keyboardType: TextInputType.multiline,
                              textInputAction: TextInputAction.newline,
                              style: TextStyle(color: Colors.black, fontSize: 14),
                              cursorColor: Colors.black,
                              onChanged: (value) => _updateData(),
                              decoration: InputDecoration(
                                isCollapsed: true,
                                border: InputBorder.none,
                                hintText: '메모를 입력하세요',
                                hintStyle: TextStyle(color: Colors.grey),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Category 드롭다운
                Positioned(
                  top: 260,
                  child: _CategoryDropdown(
                    width: 200,
                    selectedCategory: _selectedCategory,
                    onOpenChanged: (open) {
                      setState(() {
                        _isCategoryOpen = open;
                      });
                    },
                    onCategoryChanged: (category) {
                      setState(() {
                        _selectedCategory = category;
                      });
                      _updateData();
                    },
                  ),
                ),

                // Time 라벨
                Positioned(
                  top: 315,
                  left: 60,
                  child: Visibility(
                    visible: !_isCategoryOpen,
                    child: const Text(
                      'Time',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                // Time 입력 영역
                Positioned(
                  top: 345,
                  left: 60,
                  child: Visibility(
                    visible: !_isCategoryOpen,
                    child: GestureDetector(
                      onTap: _pickStartTime,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.asset(
                            'assets/images/Quest_TimeInput.png',
                            width: 80,
                            fit: BoxFit.contain,
                          ),
                          Text(
                            _formatTimeOfDay(_startTime),
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 345,
                  left: 155,
                  child: Visibility(
                    visible: !_isCategoryOpen,
                    child: const Text(
                      ':',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 345,
                  left: 180,
                  child: Visibility(
                    visible: !_isCategoryOpen,
                    child: GestureDetector(
                      onTap: _pickEndTime,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.asset(
                            'assets/images/Quest_TimeInput.png',
                            width: 80,
                            fit: BoxFit.contain,
                          ),
                          Text(
                            _formatTimeOfDay(_endTime),
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

        ],
      ),
    )
    );
  }


  Future<void> _scheduleBackgroundNotifications() async {
    try {
      const platform = MethodChannel('questlog/notification_service');
      
      String title = _titleController.text.trim();
      print('백그라운드 서비스 - 제목 텍스트: "$title"');
      String startMessage = title.isNotEmpty 
          ? '${title}를(을) 시작 할 시간입니다!'
          : '퀘스트를 시작 할 시간입니다!';
      String endMessage = title.isNotEmpty 
          ? '${title}를(을) 완료 할 시간입니다!'
          : '퀘스트를 완료 할 시간입니다!';
      
      print('백그라운드 서비스 - 시작 메시지: "$startMessage"');
      print('백그라운드 서비스 - 종료 메시지: "$endMessage"');
      
      await platform.invokeMethod('startNotificationService', {
        'startHour': _startTime!.hour,
        'startMinute': _startTime!.minute,
        'endHour': _endTime!.hour,
        'endMinute': _endTime!.minute,
        'startTimeText': _formatTimeOfDay(_startTime),
        'endTimeText': _formatTimeOfDay(_endTime),
        'title': title,
        'startMessage': startMessage,
        'endMessage': endMessage,
      });

      print('백그라운드 서비스 호출 성공');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('백그라운드 알림 설정 완료!\n시작: ${_formatTimeOfDay(_startTime)} | 종료: ${_formatTimeOfDay(_endTime)}\n앱을 종료해도 알림이 작동합니다!'),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      print('백그라운드 서비스 시작 실패: $e');
      print('Timer 방식으로 폴백합니다');
      // 백그라운드 서비스 실패 시 Timer 방식으로 폴백
      await _scheduleTimerNotifications();
    }
  }

  Future<void> _scheduleTimerNotifications() async {
    print('Timer 방식으로 알림을 설정합니다');
    final DateTime now = DateTime.now();
    final DateTime startDateTime = _getNextDateTime(_startTime!, now);
    final DateTime endDateTime = _getNextDateTime(_endTime!, now);

    // 시작 시간까지의 지연 시간 계산
    final Duration startDelay = startDateTime.difference(now);
    // 종료 시간까지의 지연 시간 계산
    final Duration endDelay = endDateTime.difference(now);

    print('시작 시간까지 남은 시간: ${startDelay.inMinutes}분');
    print('종료 시간까지 남은 시간: ${endDelay.inMinutes}분');

    // 시작 알림 타이머 설정
    if (startDelay.inMilliseconds > 0) {
      _startTimer = Timer(startDelay, () async {
        String title = _titleController.text.trim();
        print('시작 알림 - 제목 텍스트: "$title"');
        String notificationTitle = title.isNotEmpty 
            ? '${title}를(을) 시작 할 시간입니다!'
            : '퀘스트를 시작 할 시간입니다!';
        String notificationMessage = title.isNotEmpty 
            ? '${title}를(을) 시작 할 시간입니다!'
            : '퀘스트를 시작 할 시간입니다!';
        await _sendNotification(
          1,
          notificationTitle,
          notificationMessage,
        );
      });
    }

    // 종료 알림 타이머 설정
    if (endDelay.inMilliseconds > 0) {
      _endTimer = Timer(endDelay, () async {
        String title = _titleController.text.trim();
        print('종료 알림 - 제목 텍스트: "$title"');
        String notificationTitle = title.isNotEmpty 
            ? '${title}를(을) 완료 할 시간입니다!'
            : '퀘스트를 완료 할 시간입니다!';
        String notificationMessage = title.isNotEmpty 
            ? '${title}를(을) 완료 할 시간입니다!'
            : '퀘스트를 완료 할 시간입니다!';
        await _sendNotification(
          2,
          notificationTitle,
          notificationMessage,
        );
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Timer 알림 설정 완료!\n시작: ${_formatTimeOfDay(_startTime)} | 종료: ${_formatTimeOfDay(_endTime)}\n앱을 계속 실행해주세요.'),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  DateTime _getNextDateTime(TimeOfDay timeOfDay, DateTime now) {
    DateTime scheduled = DateTime(now.year, now.month, now.day, timeOfDay.hour, timeOfDay.minute);
    
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    
    return scheduled;
  }

  Future<void> _sendNotification(int id, String title, String body) async {
    FlutterLocalNotificationsPlugin _localNotification = FlutterLocalNotificationsPlugin();
    
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'questlog_reminders',
      'QuestLog Reminders',
      channelDescription: 'Notifications for quest start and end times',
      importance: Importance.max,
      priority: Priority.max,
    );
    final NotificationDetails details = NotificationDetails(android: androidDetails);

    try {
      await _localNotification.show(id, title, body, details);
      print('✅ 알림 발송 성공: $title');
    } catch (e) {
      print('❌ 알림 발송 실패: $e');
    }
  }

}

class _CategoryDropdown extends StatefulWidget {
  final double width;
  final ValueChanged<bool>? onOpenChanged;
  final String selectedCategory;
  final ValueChanged<String>? onCategoryChanged;
  
  const _CategoryDropdown({
    super.key, 
    required this.width, 
    this.onOpenChanged,
    required this.selectedCategory,
    this.onCategoryChanged,
  });

  @override
  State<_CategoryDropdown> createState() => _CategoryDropdownState();
}

class _CategoryDropdownState extends State<_CategoryDropdown> {
  bool _isOpen = false;
  String _selected = 'category';

  final List<String> _options = const ['study', 'exercise', 'work'];

  @override
  void initState() {
    super.initState();
    _selected = widget.selectedCategory;
  }

  @override
  void didUpdateWidget(_CategoryDropdown oldWidget) {
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
            widget.onOpenChanged?.call(_isOpen);
          },
          child: Container(
            width: widget.width,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFEEC29C),
              //borderRadius: BorderRadius.circular(12),
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
              //borderRadius: BorderRadius.circular(12),
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
                    widget.onOpenChanged?.call(_isOpen);
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
