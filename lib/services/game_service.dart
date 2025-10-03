import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_game_info.dart';

class GameService {
  static const String baseUrl = 'http://192.168.219.107:8083';
  
  static Future<UserGameInfo> getUserGameInfo(int userId) async {
    try {
      print('API 호출 시작: GET $baseUrl/api/game/user/$userId');
      final response = await http.get(
        Uri.parse('$baseUrl/api/game/user/$userId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      print('API 응답 상태: ${response.statusCode}');
      print('API 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        print('파싱된 데이터: $data');
        return UserGameInfo.fromJson(data);
      } else {
        throw Exception('Failed to load user game info: ${response.statusCode}');
      }
    } catch (e) {
      print('API 호출 오류: $e');
      throw Exception('Error fetching user game info: $e');
    }
  }
}
