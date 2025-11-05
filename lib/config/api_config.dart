/// API 설정을 중앙에서 관리하는 클래스
class ApiConfig {
  // 서버 기본 IP 주소
  // 개발 환경에 맞게 IP 주소를 변경하세요
  //에뮬레이터: 10.0.2.2
  static const String serverIp = '10.0.2.2';
  
  // 인증 서버 포트 (로그인, 회원가입, 퀘스트 등)
  static const int authPort = 8084;
  
  // 게임 서버 포트 (게임 정보, 상점, 장비 등)
  static const int gamePort = 8084;
  
  // Base URLs
  static String get authBaseUrl => 'http://$serverIp:$authPort';
  static String get gameBaseUrl => 'http://$serverIp:$gamePort';
  
  // 인증 API 엔드포인트
  static String get loginEndpoint => '$authBaseUrl/api/auth/login';
  static String get registerEndpoint => '$authBaseUrl/api/auth/register';
  static String get questsEndpoint => '$authBaseUrl/api/auth/quests';
  static String get findIdSendCodeEndpoint => '$authBaseUrl/api/auth/find-id/send-code';
  static String get findIdVerifyCodeEndpoint => '$authBaseUrl/api/auth/find-id/verify-code';
  static String get findPasswordEndpoint => '$authBaseUrl/api/auth/find-password';
  static String checkEmailEndpoint(String email) => '$authBaseUrl/api/auth/check-email?email=$email';
  static String checkUserIdEndpoint(String userId) => '$authBaseUrl/api/auth/check-userid?userId=$userId';
  
  // 퀘스트/일정 API 엔드포인트
  static String createQuestEndpoint(int userId) => '$authBaseUrl/api/auth/quests?userId=$userId';
  static String completeQuestEndpoint(int taskId, int userId, bool isSuccess) => '$authBaseUrl/api/auth/quests/$taskId/complete?userId=$userId&isSuccess=$isSuccess';
  static String todayQuestsEndpoint(int userId) => '$authBaseUrl/api/auth/quests/today?userId=$userId';
  
  // 게임 API 엔드포인트
  static String userGameInfo(int userId) => '$gameBaseUrl/api/game/user/$userId';
  static String userEquipment(String userId) => '$gameBaseUrl/api/game/user/$userId/equipment';
  static String get shopItemsEndpoint => '$gameBaseUrl/api/game/shop/items';
  static String shopItemsByType(String type) => '$gameBaseUrl/api/game/shop/items/type/$type';
  static String get shopPurchaseEndpoint => '$gameBaseUrl/api/game/shop/purchase';
  // 구매 API (쿼리 파라미터 사용)
  static String shopBuyEndpoint(int userId, String itemId) => '$gameBaseUrl/api/game/shop/buy?userId=$userId&itemId=$itemId';
  // 하루 리셋 체크 API
  static String dailyResetEndpoint(int userId) => '$gameBaseUrl/api/game/user/$userId/daily-reset';
}

