import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// 백엔드 설정 클래스
class BackendConfig {
  static const String baseUrl = 'http://192.168.219.110:8083';
  
  static String get questsEndpoint => '$baseUrl/api/auth/quests';
  
  // 로그인한 사용자 ID를 가져오는 함수
  static Future<String> getUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      
      if (userId != null && userId.isNotEmpty) {
        print('✅ 로그인한 사용자 ID: $userId');
        return userId;
      } else {
        print('⚠️ 로그인한 사용자 ID가 없습니다. 기본값 사용');
        return 'guest_user';
      }
    } catch (e) {
      print('❌ 사용자 ID 가져오기 실패: $e');
      return 'guest_user';
    }
  }
}

class QuestData {
  String title;
  String memo;
  String category;
  TimeOfDay? startTime;
  TimeOfDay? endTime;

  QuestData({
    this.title = '',
    this.memo = '',
    this.category = 'category',
    this.startTime,
    this.endTime,
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

    // TODO: 백엔드 엔드포인트가 준비되면 활성화
    // await _sendDataToBackend();

    // 모든 카드의 데이터를 저장하고 알림 설정
    int successCount = 0;
    for (int i = 0; i < _questDataList.length; i++) {
      QuestData data = _questDataList[i];
      if (data.startTime != null && data.endTime != null && data.title.isNotEmpty) {
        await _scheduleCardNotification(data, i);
        successCount++;
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$successCount개의 퀘스트 알림이 설정되었습니다!\n앱을 종료해도 알림이 작동합니다.'),
        duration: const Duration(seconds: 4),
      ),
    );
    
    // 즉시 테스트 알림도 발송
    await _sendTestNotification();
    
    // 3초 후 추가 테스트 알림 발송
    Timer(const Duration(seconds: 3), () async {
      await _sendDelayedTestNotification();
    });
  }

  Future<void> _sendTestNotification() async {
    try {
      FlutterLocalNotificationsPlugin _localNotification = FlutterLocalNotificationsPlugin();
      
      // 알림 채널 생성
    AndroidNotificationChannel channel = AndroidNotificationChannel(
        'questlog_test',
        'QuestLog Test',
        description: 'Test notifications',
      importance: Importance.max,
    );

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin = 
        _localNotification.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(channel);
    
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'questlog_test',
        'QuestLog Test',
        channelDescription: 'Test notifications',
      importance: Importance.max,
      priority: Priority.max,
      enableVibration: true,
      playSound: true,
      showWhen: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
    );
    final NotificationDetails details = NotificationDetails(android: androidDetails);

      await _localNotification.show(
        9999,
        '알림 설정 완료!',
        '모든 퀘스트 알림이 설정되었습니다. 설정된 시간에 알림이 발송됩니다.',
        details,
      );
      
      print('✅ 테스트 알림 발송 성공');
    } catch (e) {
      print('❌ 테스트 알림 실패: $e');
    }
  }

  Future<void> _sendDelayedTestNotification() async {
    try {
    FlutterLocalNotificationsPlugin _localNotification = FlutterLocalNotificationsPlugin();
    
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'questlog_test',
        'QuestLog Test',
        channelDescription: 'Test notifications',
      importance: Importance.max,
      priority: Priority.max,
        enableVibration: true,
        playSound: true,
        showWhen: true,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
    );
    final NotificationDetails details = NotificationDetails(android: androidDetails);

      await _localNotification.show(
        9998,
        '알림 시스템 테스트',
        '3초 후 알림이 정상적으로 발송되었습니다! 스케줄된 알림도 정상 작동할 것입니다.',
        details,
      );
      
      print('✅ 지연 테스트 알림 발송 성공');
    } catch (e) {
      print('❌ 지연 테스트 알림 실패: $e');
    }
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

  // TODO: 백엔드 엔드포인트가 준비되면 활성화
  /*
  // 백엔드 API 호출 함수들
  Future<void> _sendDataToBackend() async {
    try {
      // 유효한 데이터만 필터링
      List<Map<String, dynamic>> validQuests = [];
      
      for (int i = 0; i < _questDataList.length; i++) {
        QuestData data = _questDataList[i];
        if (data.title.isNotEmpty && data.startTime != null && data.endTime != null) {
          validQuests.add(_convertQuestDataToBackendFormat(data, i));
        }
      }

      if (validQuests.isEmpty) {
        print('⚠️ 백엔드로 전송할 유효한 퀘스트가 없습니다.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('전송할 유효한 퀘스트가 없습니다. 제목과 시간을 입력해주세요.'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // 백엔드 API 호출
      final response = await _sendQuestsToBackend(validQuests);
      
      if (response['success']) {
        print('✅ 백엔드 데이터 전송 성공: ${validQuests.length}개 퀘스트');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('백엔드에 ${validQuests.length}개 퀘스트가 저장되었습니다!'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        print('❌ 백엔드 데이터 전송 실패: ${response['error']}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('백엔드 저장 실패: ${response['error']}'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red,
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

  // 개별 카드 데이터를 백엔드로 전송하는 함수
  Future<void> _sendSingleCardToBackend(QuestData data, int cardIndex) async {
    try {
      if (data.title.isEmpty || data.startTime == null || data.endTime == null) {
        print('⚠️ 카드 ${cardIndex + 1}: 유효하지 않은 데이터로 백엔드 전송 불가');
        return;
      }

      final questData = _convertQuestDataToBackendFormat(data, cardIndex);
      final response = await _sendQuestsToBackend([questData]);
      
      if (response['success']) {
        print('✅ 카드 ${cardIndex + 1} 백엔드 전송 성공');
      } else {
        print('❌ 카드 ${cardIndex + 1} 백엔드 전송 실패: ${response['error']}');
      }
    } catch (e) {
      print('❌ 카드 ${cardIndex + 1} 백엔드 전송 중 오류: $e');
    }
  }
  */


  // TODO: 백엔드 엔드포인트가 준비되면 활성화
  /*
  Map<String, dynamic> _convertQuestDataToBackendFormat(QuestData data, int cardIndex) {
    return {
      'cardIndex': cardIndex,
      'title': data.title,
      'memo': data.memo,
      'category': data.category,
      'startTime': {
        'hour': data.startTime!.hour,
        'minute': data.startTime!.minute,
        'formatted': _formatTimeOfDay(data.startTime),
      },
      'endTime': {
        'hour': data.endTime!.hour,
        'minute': data.endTime!.minute,
        'formatted': _formatTimeOfDay(data.endTime),
      },
      'createdAt': DateTime.now().toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> _sendQuestsToBackend(List<Map<String, dynamic>> quests) async {
    try {
      // 로그인한 사용자 ID 가져오기
      final userId = await BackendConfig.getUserId();
      
      final response = await http.post(
        Uri.parse(BackendConfig.questsEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'quests': quests,
          'userId': userId,
          'date': DateTime.now().toIso8601String().split('T')[0], // YYYY-MM-DD 형식
        }),
      );

      print('📡 백엔드 응답 상태: ${response.statusCode}');
      print('📡 백엔드 응답 내용: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        return {
          'success': true,
          'data': responseData,
        };
      } else {
        return {
          'success': false,
          'error': 'HTTP ${response.statusCode}: ${response.body}',
        };
      }
    } catch (e) {
      print('❌ 백엔드 API 호출 실패: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  */

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
      padding: const EdgeInsets.all(20.0),
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
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // OK 버튼 (첫 번째 카드에만 표시)
          if (_currentIndex == 0) ...[
            GestureDetector(
              onTap: () {
                _scheduleNotifications();
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
            const SizedBox(width: 20),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Quest_Background와 오버레이 요소들
          SizedBox(
            width: 850,
            height: 550,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Image.asset(
                  'assets/images/Quest_Background.png',
                  width: 850,
                  height: 550,
                  fit: BoxFit.contain,
                ),

                // 상단 Quest_Input (오버레이 텍스트 입력)
                Positioned(
                  top: 70,
                  child: SizedBox(
                    width: 300,
                    height: 100,
                    child: Stack(
                      children: [
                        Image.asset(
                          'assets/images/Quest_Input.png',
                          width: 300,
                          height: 100,
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
                  top: 175,
                  left: 65,
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
                  top: 210,
                  left: 65,
                  child: SizedBox(
                    width: 240,
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
                  top: 310,
                  child: _CategoryDropdown(
                    width: 240,
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
                  top: 370,
                  left: 65,
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
                  top: 405,
                  left: 65,
                  child: Visibility(
                    visible: !_isCategoryOpen,
                    child: GestureDetector(
                      onTap: _pickStartTime,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.asset(
                            'assets/images/Quest_TimeInput.png',
                            width: 100,
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
                  top: 405,
                  left: 180,
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
                  top: 405,
                  left: 205,
                  child: Visibility(
                    visible: !_isCategoryOpen,
                    child: GestureDetector(
                      onTap: _pickEndTime,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.asset(
                            'assets/images/Quest_TimeInput.png',
                            width: 100,
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

  Future<void> _testNotificationNow() async {
    FlutterLocalNotificationsPlugin _localNotification = FlutterLocalNotificationsPlugin();
    
    // 제목 텍스트 확인
    String title = _titleController.text.trim();
    print('테스트 알림 - 제목 텍스트: "$title"');
    
    // 먼저 즉시 알림 테스트
    await _testImmediateNotification();
    
    // 알림 채널 재생성
    AndroidNotificationChannel channel = AndroidNotificationChannel(
      'questlog_reminders',
      'QuestLog Reminders',
      description: 'Notifications for quest start and end times',
      importance: Importance.max,
    );

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin = 
        _localNotification.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(channel);
    
    // 3초 후 알림 테스트 (더 짧은 시간)
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    final tz.TZDateTime scheduledDate = now.add(const Duration(seconds: 3));
    
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'questlog_reminders',
      'QuestLog Reminders',
      channelDescription: 'Notifications for quest start and end times',
      importance: Importance.max,
      priority: Priority.max,
      enableVibration: true,
      playSound: true,
      showWhen: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
    );
    final NotificationDetails details = NotificationDetails(android: androidDetails);

    try {
      // 권한 재확인
      if (androidPlugin != null) {
        final bool? canSchedule = await androidPlugin.canScheduleExactNotifications();
        print('정확한 알림 스케줄링 가능: $canSchedule');
        
        final bool? notificationsEnabled = await androidPlugin.areNotificationsEnabled();
        print('알림 권한 상태: $notificationsEnabled');
      }
      
      await _localNotification.zonedSchedule(
        999,
        '3초 후 테스트 알림',
        '3초 후 테스트 알림입니다!',
        scheduledDate,
        details,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        androidAllowWhileIdle: true,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'test_3sec',
      );
      
      // 예약 확인
      final List<PendingNotificationRequest> pending = await _localNotification.pendingNotificationRequests();
      print('예약된 알림 개수: ${pending.length}');
      for (var notif in pending) {
        print('예약된 알림: ID=${notif.id}, 제목=${notif.title}');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('즉시 알림과 3초 후 알림이 예약되었습니다!\nTimer 대안도 시도해보세요.'),
          duration: Duration(seconds: 3),
        ),
      );
      
      // Timer를 사용한 대안 테스트
      Timer(const Duration(seconds: 3), () async {
        await _testTimerNotification();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('테스트 알림 실패: $e')),
      );
    }
  }

  Future<void> _testTimerNotification() async {
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
      await _localNotification.show(
        997,
        'Timer 테스트 알림',
        'Timer를 사용한 3초 후 알림입니다!',
        details,
      );
      print('✅ Timer 알림 발송 성공');
    } catch (e) {
      print('❌ Timer 알림 실패: $e');
    }
  }

  Future<void> _testImmediateNotification() async {
    FlutterLocalNotificationsPlugin _localNotification = FlutterLocalNotificationsPlugin();
    
    // 제목 텍스트 확인
    String title = _titleController.text.trim();
    String notificationTitle = title.isNotEmpty 
        ? '${title} 테스트 알림'
        : '즉시 테스트 알림';
    String notificationMessage = title.isNotEmpty 
        ? '${title} 알림 시스템이 작동합니다!'
        : '알림 시스템이 작동합니다!';
    
    // 알림 채널 재생성
    AndroidNotificationChannel channel = AndroidNotificationChannel(
      'questlog_reminders',
      'QuestLog Reminders',
      description: 'Notifications for quest start and end times',
      importance: Importance.max,
    );

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin = 
        _localNotification.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(channel);
    
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'questlog_reminders',
      'QuestLog Reminders',
      channelDescription: 'Notifications for quest start and end times',
      importance: Importance.max,
      priority: Priority.max,
    );
    final NotificationDetails details = NotificationDetails(android: androidDetails);

    try {
      await _localNotification.show(
        998,
        notificationTitle,
        notificationMessage,
        details,
      );
    } catch (e) {
      print('즉시 알림 실패: $e');
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
