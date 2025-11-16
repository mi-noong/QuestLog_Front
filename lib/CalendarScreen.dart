import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/api_config.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

// 일정 모델
class Schedule {
  final String id;
  final String title;
  final bool isCompleted;
  final bool isFailed;

  Schedule({
    required this.id,
    required this.title,
    required this.isCompleted,
    required this.isFailed,
  });

  factory Schedule.fromJson(Map<String, dynamic> json) {
    final status = json['status']?.toString().toUpperCase() ?? '';
    final isCompleted = status == 'DONE';
    final isFailed = status == 'FAILED' || status == 'FAIL';

    return Schedule(
      id: json['id']?.toString() ?? json['taskId']?.toString() ?? '',
      title: json['title'] ?? '',
      isCompleted: isCompleted,
      isFailed: isFailed,
    );
  }

  // SharedPreferences에서 가져온 일정으로부터 생성
  factory Schedule.fromStorageTask({
    required int taskId,
    required String title,
    required String category,
    required String? status,
  }) {
    final statusUpper = status?.toUpperCase() ?? 'PENDING';
    final isCompleted = statusUpper == 'DONE';
    final isFailed = statusUpper == 'FAILED' || statusUpper == 'FAIL';

    return Schedule(
      id: taskId.toString(),
      title: title,
      isCompleted: isCompleted,
      isFailed: isFailed,
    );
  }
}

// SharedPreferences에서 완료/실패된 일정 가져오기 (HomeScreen과 동일한 방식)
Future<List<Schedule>> fetchSchedulesFromStorage() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    
    // SharedPreferences에서 일정 목록 읽기
    final questListJson = prefs.getString('questList');
    if (questListJson == null) {
      print('📋 SharedPreferences에 일정 목록이 없습니다.');
      return [];
    }

    final List<dynamic> questList = jsonDecode(questListJson);
    
    // 완료/실패 상태가 저장된 일정 목록 확인
    final completedQuestsJson = prefs.getString('completedQuests');
    Map<String, String> completedQuests = {};
    if (completedQuestsJson != null) {
      final Map<String, dynamic> completedMap = jsonDecode(completedQuestsJson);
      completedQuests = completedMap.map((key, value) => MapEntry(key, value.toString()));
      print('📊 저장된 완료/실패 상태: $completedQuests');
    }

    final schedules = <Schedule>[];
    
    for (var quest in questList) {
      final taskId = quest['taskId'] ?? 0;
      final title = quest['title'] ?? '';
      final category = quest['category'] ?? '';
      
      // 완료/실패 상태 확인
      String? status;
      
      // 1. taskId로 먼저 확인 (taskId가 0보다 큰 경우)
      if (taskId > 0) {
        status = completedQuests[taskId.toString()];
      }
      
      // 2. taskId로 찾지 못하면 제목+카테고리로 확인
      if (status == null) {
        final questKey = '${title}_${category}';
        status = completedQuests[questKey];
      }
      
      // 완료 또는 실패 상태인 일정만 포함 (PENDING 상태 제외)
      if (status != null) {
        final statusUpper = status.toUpperCase();
        if (statusUpper == 'DONE' || statusUpper == 'FAILED' || statusUpper == 'FAIL') {
          schedules.add(Schedule.fromStorageTask(
            taskId: taskId,
            title: title,
            category: category,
            status: status,
          ));
        }
      }
    }
    
    print('✅ SharedPreferences에서 완료/실패 일정 로드 완료: ${schedules.length}개');
    return schedules;
  } catch (e) {
    print('❌ SharedPreferences에서 일정 로드 중 오류: $e');
    return [];
  }
}

// 날짜별 일정 조회 API (백업용, 필요시 사용)
Future<List<Schedule>> fetchSchedulesByDate(int userDbId, DateTime date) async {
  try {
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final response = await http.get(
      Uri.parse(ApiConfig.questsByDateEndpoint(userDbId, dateStr)),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true && data['data'] != null) {
        // 백엔드에서 data['data']는 직접 List<TaskResponse>를 반환
        final responseData = data['data'];

        // responseData가 리스트인지 확인
        if (responseData is List) {
          return responseData.map((task) => Schedule.fromJson(task)).toList();
        }
      }
    }
    return [];
  } catch (e) {
    print('날짜별 일정 조회 오류: $e');
    return [];
  }
}

// 사용자 DB ID 가져오기
Future<int?> getUserDbId() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final userDbId = prefs.getInt('userDbId');

    if (userDbId != null) {
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

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();

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
                const SizedBox(height: 20), // 상단 여백 추가
                // 뒤로가기 버튼과 Calendar 제목을 같은 높이에 배치
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 뒤로가기 버튼 (왼쪽)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                        },
                        child: Image.asset(
                          'assets/images/BackButton.png',
                          width: 40,
                          height: 40,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    // Calendar 제목 (가운데)
                    const Text(
                      'Calendar',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        fontFamily: 'DungGeunMo',
                        decoration: TextDecoration.none,
                      ),
                    ),
                    // 오른쪽 공간 (대칭을 위해)
                    const SizedBox(width: 48), // 뒤로가기 버튼과 같은 너비
                  ],
                ),

                // 캘린더 영역
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                        padding: const EdgeInsets.all(15),
                        constraints: const BoxConstraints(
                          maxHeight: 500,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black, width: 2),
                        ),
                        child: TableCalendar(
                          firstDay: DateTime(2020),
                          lastDay: DateTime(2030),
                          focusedDay: _focusedDay,
                          selectedDayPredicate: (day) {
                            return isSameDay(_selectedDay, day);
                          },
                          onDaySelected: (selectedDay, focusedDay) {
                            setState(() {
                              _selectedDay = selectedDay;
                              _focusedDay = focusedDay;
                            });
                            _showScheduleDialog(selectedDay);
                          },
                          onPageChanged: (focusedDay) {
                            setState(() {
                              _focusedDay = focusedDay;
                            });
                          },
                          calendarStyle: const CalendarStyle(
                            todayDecoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                            selectedDecoration: BoxDecoration(
                              color: Colors.black,
                              shape: BoxShape.circle,
                            ),
                            defaultTextStyle: TextStyle(
                              color: Colors.black,
                              fontFamily: 'DungGeunMo',
                            ),
                            weekendTextStyle: TextStyle(
                              color: Colors.black,
                              fontFamily: 'DungGeunMo',
                            ),
                            outsideTextStyle: TextStyle(
                              color: Colors.grey,
                              fontFamily: 'DungGeunMo',
                            ),
                          ),
                          headerStyle: const HeaderStyle(
                            titleTextStyle: TextStyle(
                              color: Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'DungGeunMo',
                            ),
                            leftChevronIcon: Icon(Icons.chevron_left, color: Colors.black),
                            rightChevronIcon: Icon(Icons.chevron_right, color: Colors.black),
                            formatButtonVisible: false,
                          ),
                          daysOfWeekStyle: const DaysOfWeekStyle(
                            weekdayStyle: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'DungGeunMo',
                            ),
                            weekendStyle: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'DungGeunMo',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 날짜별 일정 다이얼로그 표시 (SharedPreferences에서 완료/실패 일정 가져오기)
  Future<void> _showScheduleDialog(DateTime date) async {
    // SharedPreferences에서 완료/실패된 일정 가져오기 (HomeScreen과 동일)
    final schedules = await fetchSchedulesFromStorage();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 날짜 표시
                Text(
                  '${date.year}년 ${date.month}월 ${date.day}일',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'DungGeunMo',
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 16),
                // 일정 목록
                if (schedules.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      '완료하거나 실패한 일정이 없습니다.',
                      style: TextStyle(
                        fontSize: 16,
                        fontFamily: 'DungGeunMo',
                        color: Colors.grey,
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: schedules.length,
                      itemBuilder: (context, index) {
                        final schedule = schedules[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: schedule.isCompleted
                                ? Colors.green.withOpacity(0.2)
                                : schedule.isFailed
                                    ? Colors.red.withOpacity(0.2)
                                    : Colors.grey.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: schedule.isCompleted
                                  ? Colors.green
                                  : schedule.isFailed
                                      ? Colors.red
                                      : Colors.grey,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              // 성공/실패 아이콘 (HomeScreen과 동일)
                              Image.asset(
                                schedule.isCompleted
                                    ? 'assets/images/Icon_Check.png'
                                    : schedule.isFailed
                                        ? 'assets/images/Icon_Skull.png'
                                        : 'assets/images/Icon_Lock.png',
                                width: 24,
                                height: 24,
                              ),
                              const SizedBox(width: 12),
                              // 일정 제목과 상태 표시
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      schedule.title,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontFamily: 'DungGeunMo',
                                        color: schedule.isCompleted
                                            ? Colors.green.shade900
                                            : schedule.isFailed
                                                ? Colors.red.shade900
                                                : Colors.black,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      schedule.isCompleted
                                          ? '성공'
                                          : schedule.isFailed
                                              ? '실패'
                                              : '대기중',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontFamily: 'DungGeunMo',
                                        color: schedule.isCompleted
                                            ? Colors.green.shade700
                                            : schedule.isFailed
                                                ? Colors.red.shade700
                                                : Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 16),
                // 닫기 버튼
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '닫기',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'DungGeunMo',
                        color: Colors.white,
                      ),
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

import 'config/api_config.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

// 일정 모델
class Schedule {
  final String id;
  final String title;
  final bool isCompleted;

  Schedule({
    required this.id,
    required this.title,
    required this.isCompleted,
  });

  factory Schedule.fromJson(Map<String, dynamic> json) {
    final status = json['status']?.toString().toUpperCase() ?? '';
    final isCompleted = status == 'DONE';

    return Schedule(
      id: json['id']?.toString() ?? json['taskId']?.toString() ?? '',
      title: json['title'] ?? '',
      isCompleted: isCompleted,
    );
  }
}

// 날짜별 일정 조회 API
Future<List<Schedule>> fetchSchedulesByDate(int userDbId, DateTime date) async {
  try {
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final response = await http.get(
      Uri.parse(ApiConfig.questsByDateEndpoint(userDbId, dateStr)),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true && data['data'] != null) {
        // 백엔드에서 data['data']는 직접 List<TaskResponse>를 반환
        final responseData = data['data'];

        // responseData가 리스트인지 확인
        if (responseData is List) {
          return responseData.map((task) => Schedule.fromJson(task)).toList();
        }
      }
    }
    return [];
  } catch (e) {
    print('날짜별 일정 조회 오류: $e');
    return [];
  }
}

// 사용자 DB ID 가져오기
Future<int?> getUserDbId() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final userDbId = prefs.getInt('userDbId');

    if (userDbId != null) {
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

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();

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
                const SizedBox(height: 20), // 상단 여백 추가
                // 뒤로가기 버튼과 Calendar 제목을 같은 높이에 배치
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 뒤로가기 버튼 (왼쪽)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                        },
                        child: Image.asset(
                          'assets/images/BackButton.png',
                          width: 40,
                          height: 40,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    // Calendar 제목 (가운데)
                    const Text(
                      'Calendar',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        fontFamily: 'DungGeunMo',
                        decoration: TextDecoration.none,
                      ),
                    ),
                    // 오른쪽 공간 (대칭을 위해)
                    const SizedBox(width: 48), // 뒤로가기 버튼과 같은 너비
                  ],
                ),

                // 캘린더 영역
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                        padding: const EdgeInsets.all(15),
                        constraints: const BoxConstraints(
                          maxHeight: 500,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black, width: 2),
                        ),
                        child: TableCalendar(
                          firstDay: DateTime(2020),
                          lastDay: DateTime(2030),
                          focusedDay: _focusedDay,
                          selectedDayPredicate: (day) {
                            return isSameDay(_selectedDay, day);
                          },
                          onDaySelected: (selectedDay, focusedDay) {
                            setState(() {
                              _selectedDay = selectedDay;
                              _focusedDay = focusedDay;
                            });
                            _showScheduleDialog(selectedDay);
                          },
                          onPageChanged: (focusedDay) {
                            setState(() {
                              _focusedDay = focusedDay;
                            });
                          },
                          calendarStyle: const CalendarStyle(
                            todayDecoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                            selectedDecoration: BoxDecoration(
                              color: Colors.black,
                              shape: BoxShape.circle,
                            ),
                            defaultTextStyle: TextStyle(
                              color: Colors.black,
                              fontFamily: 'DungGeunMo',
                            ),
                            weekendTextStyle: TextStyle(
                              color: Colors.black,
                              fontFamily: 'DungGeunMo',
                            ),
                            outsideTextStyle: TextStyle(
                              color: Colors.grey,
                              fontFamily: 'DungGeunMo',
                            ),
                          ),
                          headerStyle: const HeaderStyle(
                            titleTextStyle: TextStyle(
                              color: Colors.black,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'DungGeunMo',
                            ),
                            leftChevronIcon: Icon(Icons.chevron_left, color: Colors.black),
                            rightChevronIcon: Icon(Icons.chevron_right, color: Colors.black),
                            formatButtonVisible: false,
                          ),
                          daysOfWeekStyle: const DaysOfWeekStyle(
                            weekdayStyle: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'DungGeunMo',
                            ),
                            weekendStyle: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'DungGeunMo',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 날짜별 일정 다이얼로그 표시
  Future<void> _showScheduleDialog(DateTime date) async {
    final userDbId = await getUserDbId();
    if (userDbId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('로그인이 필요합니다.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    final schedules = await fetchSchedulesByDate(userDbId, date);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 날짜 표시
                Text(
                  '${date.year}년 ${date.month}월 ${date.day}일',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'DungGeunMo',
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 16),
                // 일정 목록
                if (schedules.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Text(
                      '등록된 일정이 없습니다.',
                      style: TextStyle(
                        fontSize: 16,
                        fontFamily: 'DungGeunMo',
                        color: Colors.grey,
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: schedules.length,
                      itemBuilder: (context, index) {
                        final schedule = schedules[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: schedule.isCompleted
                                ? Colors.green.withOpacity(0.2)
                                : Colors.grey.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: schedule.isCompleted
                                  ? Colors.green
                                  : Colors.grey,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              // 완료 상태 아이콘
                              Icon(
                                schedule.isCompleted
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                color: schedule.isCompleted
                                    ? Colors.green
                                    : Colors.grey,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              // 일정 제목
                              Expanded(
                                child: Text(
                                  schedule.title,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontFamily: 'DungGeunMo',
                                    color: schedule.isCompleted
                                        ? Colors.green.shade900
                                        : Colors.black,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 16),
                // 닫기 버튼
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '닫기',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'DungGeunMo',
                        color: Colors.white,
                      ),
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

