import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'HomeScreen.dart';
import 'config/api_config.dart';
import 'models/user_game_info.dart';
import 'services/game_service.dart';
import 'services/sound_manager.dart';

// 상점 아이템 모델
class ShopItem {
  final String itemId;
  final String name;
  final String description;
  final int price;
  final String itemType;
  final Map<String, dynamic>? stats;

  ShopItem({
    required this.itemId,
    required this.name,
    required this.description,
    required this.price,
    required this.itemType,
    this.stats,
  });

  factory ShopItem.fromJson(Map<String, dynamic> json) {
    return ShopItem(
      itemId: json['itemId'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: json['price'] ?? 0,
      // 서버는 'type' 필드를 사용하지만 클라이언트는 'itemType'을 사용
      itemType: (json['itemType'] ?? json['type'] ?? '').toUpperCase(),
      stats: json['stats'],
    );
  }
}

// 상점 아이템 목록 조회 API
Future<List<ShopItem>?> fetchShopItems() async {
  try {
    final response = await http.get(
      Uri.parse(ApiConfig.shopItemsEndpoint),
      headers: {'Content-Type': 'application/json'},
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw Exception('요청 시간이 초과되었습니다.');
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        List<dynamic> itemsJson = data['data'];
        return itemsJson.map((item) => ShopItem.fromJson(item)).toList();
      }
    }
    return null;
  } catch (e) {
    print('상점 아이템 조회 오류: $e');
    return null;
  }
}

// 타입별 상점 아이템 조회 API
Future<List<ShopItem>?> fetchShopItemsByType(String type) async {
  try {
    final response = await http.get(
      Uri.parse(ApiConfig.shopItemsByType(type)),
      headers: {'Content-Type': 'application/json'},
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw Exception('요청 시간이 초과되었습니다.');
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        List<dynamic> itemsJson = data['data'];
        return itemsJson.map((item) => ShopItem.fromJson(item)).toList();
      }
    }
    return null;
  } catch (e) {
    print('타입별 상점 아이템 조회 오류: $e');
    return null;
  }
}


// 장비 업그레이드 순서 정의
class EquipmentUpgrade {
  static const List<Map<String, dynamic>> armorUpgrades = [
    {
      'id': 'leather_armor',
      'name': 'Leather Armor',
      'description': '가죽 갑옷',
      'price': 10,
      'image': 'assets/images/Leather_Armor.png',
      'level': 1,
    },
    {
      'id': 'silver_armor',
      'name': 'Silver Armor',
      'description': '은 갑옷',
      'price': 30,
      'image': 'assets/images/SilverArmor.png',
      'level': 2,
    },
    {
      'id': 'gold_armor',
      'name': 'Gold Armor',
      'description': '금 갑옷',
      'price': 50,
      'image': 'assets/images/GoldArmor.png',
      'level': 3,
    },
  ];

  static const List<Map<String, dynamic>> weaponUpgrades = [
    {
      'id': 'wooden_sword',
      'name': 'Wooden Sword',
      'description': '나무 검',
      'price': 10,
      'image': 'assets/images/wooden_sword.png',
      'level': 1,
    },
    {
      'id': 'silver_sword',
      'name': 'Silver Sword',
      'description': '은 검',
      'price': 30,
      'image': 'assets/images/sliver_sword.png',
      'level': 2,
    },
    {
      'id': 'gold_sword',
      'name': 'Gold Sword',
      'description': '금 검',
      'price': 50,
      'image': 'assets/images/golden_sword.png',
      'level': 3,
    },
  ];

  // 현재 장비 레벨에 따라 다음 업그레이드 아이템 반환
  static ShopItem? getNextArmorUpgrade(Map<String, dynamic>? currentArmor) {
    int currentLevel = 0;
    if (currentArmor != null) {
      String armorId = currentArmor['id'] ?? '';
      for (var upgrade in armorUpgrades) {
        if (upgrade['id'] == armorId) {
          currentLevel = upgrade['level'];
          break;
        }
      }
    }

    // 다음 레벨 아이템 찾기
    for (var upgrade in armorUpgrades) {
      if (upgrade['level'] > currentLevel) {
        return ShopItem(
          itemId: upgrade['id'],
          name: upgrade['name'],
          description: upgrade['description'],
          price: upgrade['price'],
          itemType: 'ARMOR',
        );
      }
    }
    return null; // 더 이상 업그레이드할 아이템이 없음
  }

  static ShopItem? getNextWeaponUpgrade(Map<String, dynamic>? currentWeapon) {
    int currentLevel = 0;
    if (currentWeapon != null) {
      String weaponId = currentWeapon['id'] ?? '';
      for (var upgrade in weaponUpgrades) {
        if (upgrade['id'] == weaponId) {
          currentLevel = upgrade['level'];
          break;
        }
      }
    }

    // 다음 레벨 아이템 찾기
    for (var upgrade in weaponUpgrades) {
      if (upgrade['level'] > currentLevel) {
        return ShopItem(
          itemId: upgrade['id'],
          name: upgrade['name'],
          description: upgrade['description'],
          price: upgrade['price'],
          itemType: 'WEAPON',
        );
      }
    }
    return null; // 더 이상 업그레이드할 아이템이 없음
  }

  // 아이템 ID로 이미지 경로 반환
  static String getImagePath(String itemId) {
    // 갑옷 이미지
    for (var armor in armorUpgrades) {
      if (armor['id'] == itemId) {
        return armor['image'];
      }
    }
    // 무기 이미지
    for (var weapon in weaponUpgrades) {
      if (weapon['id'] == itemId) {
        return weapon['image'];
      }
    }
    // 기본값
    return 'assets/images/Leather_Armor.png';
  }

  // 아이템 ID로 레벨 확인
  static int? getItemLevel(String itemId, String itemType) {
    if (itemType == 'ARMOR') {
      for (var armor in armorUpgrades) {
        if (armor['id'] == itemId) {
          return armor['level'] as int;
        }
      }
    } else if (itemType == 'WEAPON') {
      for (var weapon in weaponUpgrades) {
        if (weapon['id'] == itemId) {
          return weapon['level'] as int;
        }
      }
    }
    return null;
  }

  // 아이템 타입 확인
  static String? getItemType(String itemId) {
    for (var armor in armorUpgrades) {
      if (armor['id'] == itemId) {
        return 'ARMOR';
      }
    }
    for (var weapon in weaponUpgrades) {
      if (weapon['id'] == itemId) {
        return 'WEAPON';
      }
    }
    return null;
  }

  // 현재 장비 레벨 확인
  static int getCurrentEquipmentLevel(Map<String, dynamic>? currentEquipment, String itemType) {
    if (currentEquipment == null) {
      print('🔍 getCurrentEquipmentLevel: currentEquipment가 null입니다.');
      return 0;
    }
    
    String? equipmentId = currentEquipment['itemId'] ?? currentEquipment['id'];
    print('🔍 getCurrentEquipmentLevel: equipmentId=$equipmentId, itemType=$itemType, currentEquipment=$currentEquipment');
    if (equipmentId == null) {
      print('🔍 getCurrentEquipmentLevel: equipmentId가 null입니다.');
      return 0;
    }
    
    int? level = getItemLevel(equipmentId, itemType);
    print('🔍 getCurrentEquipmentLevel: equipmentId=$equipmentId, itemType=$itemType, level=$level');
    return level ?? 0;
  }
}

// 아이템 구매 API
Future<Map<String, dynamic>> purchaseItem(int userId, String itemId) async {
  try {
      print('구매 요청 시작: userId=$userId, itemId=$itemId');
      print('🔍 구매 시도 아이템 ID: $itemId');
      
      // 쿼리 파라미터를 사용한 엔드포인트 (itemId를 URL 인코딩)
      final encodedItemId = Uri.encodeComponent(itemId);
      final url = ApiConfig.gameBaseUrl + '/api/game/shop/buy?userId=$userId&itemId=$encodedItemId';
      print('구매 요청 URL: $url');

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
      },
    ).timeout(const Duration(seconds: 10));

    print('구매 응답 상태: ${response.statusCode}');
    print('구매 응답 본문: ${response.body}');
    
    final result = json.decode(response.body);
    
    if (result['success'] == true) {
      print('구매 성공: $result');
      // result.data를 반환 (playerGold, purchasedItem 포함)
      return {
        'success': true,
        'message': result['message'] ?? '구매가 성공적으로 완료되었습니다!',
        'data': result['data'], // { playerGold, purchasedItem }
      };
    } else {
      String errorMessage = result['message'] ?? '구매에 실패했습니다.';
      print('구매 실패: ${response.statusCode} - $errorMessage');
      throw Exception(errorMessage);
    }
  } catch (e) {
    print('아이템 구매 오류: $e');
    String errorMessage = '구매 중 오류가 발생했습니다.';

    if (e.toString().contains('Connection timed out')) {
      errorMessage = '네트워크 연결 시간이 초과되었습니다. 잠시 후 다시 시도해주세요.';
    } else if (e.toString().contains('SocketException')) {
      errorMessage = '네트워크 연결에 실패했습니다. 인터넷 연결을 확인해주세요.';
    } else if (e.toString().contains('Exception:')) {
      // 서버에서 반환한 에러 메시지 추출
      final match = RegExp(r'Exception: (.+)').firstMatch(e.toString());
      if (match != null) {
        errorMessage = match.group(1)!;
      }
    }

    throw Exception(errorMessage);
  }
}

// 구매 완료 후 사용자 정보 업데이트 API
Future<Map<String, dynamic>> updateUserAfterPurchase(String userId, String itemId, int newGold) async {
  try {
    print('구매 후 사용자 정보 업데이트 시작: userId=$userId, itemId=$itemId, newGold=$newGold');

    final response = await http.put(
      Uri.parse(ApiConfig.userEquipment(userId)),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'itemId': itemId,
        'gold': newGold,
        'purchasedAt': DateTime.now().toIso8601String(),
      }),
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('사용자 정보 업데이트 성공: $data');
      return {
        'success': true,
        'message': '사용자 정보가 성공적으로 업데이트되었습니다.',
        'data': data,
      };
    } else {
      final errorData = json.decode(response.body);
      print('사용자 정보 업데이트 실패: ${response.statusCode} - ${errorData['message']}');
      return {
        'success': false,
        'message': errorData['message'] ?? '사용자 정보 업데이트에 실패했습니다.',
        'data': null,
      };
    }
  } catch (e) {
    print('사용자 정보 업데이트 오류: $e');
    String errorMessage = '사용자 정보 업데이트 중 오류가 발생했습니다.';

    if (e.toString().contains('Connection timed out')) {
      errorMessage = '네트워크 연결 시간이 초과되었습니다. 잠시 후 다시 시도해주세요.';
    } else if (e.toString().contains('SocketException')) {
      errorMessage = '네트워크 연결에 실패했습니다. 인터넷 연결을 확인해주세요.';
    }

    return {
      'success': false,
      'message': errorMessage,
      'data': null,
    };
  }
}

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  ShopItem? selectedItem;
  bool showBuyDialog = false;
  bool showPurchaseCompleteDialog = false;
  String? currentUserId; // 문자열 ID (호환성)
  int? currentUserDbId; // Long 타입 DB ID (구매 API용)
  bool isLoading = false;
  UserGameInfo? userGameInfo; // HomeScreen과 동일한 방식
  ShopItem? currentArmorItem;
  ShopItem? currentWeaponItem;
  ShopItem? currentPotionItem;

  void _showBuyDialog(ShopItem item) {
    // 구매 가능 여부 확인 (골드 + 업그레이드 순서)
    if (!_canPurchaseItem(item)) {
      String message = '구매할 수 없습니다.';
      
      // 골드 부족
      if (!_canAffordItem(item)) {
        message = '골드가 부족합니다! (보유: ${_getCurrentGold()}, 필요: ${item.price})';
      } else {
        // 업그레이드 순서 위반
        String itemType = item.itemType;
        if (itemType.isEmpty) {
          itemType = EquipmentUpgrade.getItemType(item.itemId) ?? '';
        }
        
        // 현재 장비 확인 및 가장 높은 레벨 찾기
        int currentLevel = 0;
        if (userGameInfo != null && userGameInfo!.inventory.isNotEmpty) {
          final inventory = userGameInfo!.inventory[0] as Map<String, dynamic>?;
          if (inventory != null) {
            if (itemType == 'ARMOR') {
              // 장착된 갑옷 레벨 확인
              final equippedArmor = inventory['equippedArmor'];
              if (equippedArmor != null) {
                String armorId = equippedArmor['id'] ?? '';
                int? level = EquipmentUpgrade.getItemLevel(armorId, 'ARMOR');
                if (level != null && level > currentLevel) {
                  currentLevel = level;
                }
              }
              // 인벤토리 배열의 갑옷들 확인
              final armors = inventory['armors'];
              if (armors is List) {
                for (var armor in armors) {
                  if (armor is Map<String, dynamic>) {
                    String armorId = (armor['itemId'] ?? armor['id'])?.toString() ?? '';
                    int? level = EquipmentUpgrade.getItemLevel(armorId, 'ARMOR');
                    if (level != null && level > currentLevel) {
                      currentLevel = level;
                    }
                  }
                }
              }
            } else if (itemType == 'WEAPON') {
              // 장착된 무기 레벨 확인
              final equippedWeapon = inventory['equippedWeapon'];
              if (equippedWeapon != null) {
                String weaponId = equippedWeapon['id'] ?? '';
                int? level = EquipmentUpgrade.getItemLevel(weaponId, 'WEAPON');
                if (level != null && level > currentLevel) {
                  currentLevel = level;
                }
              }
              // 인벤토리 배열의 무기들 확인
              final weapons = inventory['weapons'];
              if (weapons is List) {
                for (var weapon in weapons) {
                  if (weapon is Map<String, dynamic>) {
                    String weaponId = (weapon['itemId'] ?? weapon['id'])?.toString() ?? '';
                    int? level = EquipmentUpgrade.getItemLevel(weaponId, 'WEAPON');
                    if (level != null && level > currentLevel) {
                      currentLevel = level;
                    }
                  }
                }
              }
            }
          }
        }
        
        int? itemLevel = EquipmentUpgrade.getItemLevel(item.itemId, itemType);
        
        if (itemLevel != null && itemLevel != currentLevel + 1) {
          // 이전 레벨 아이템부터 구매해야 함
          String requiredItemName = '';
          if (itemType == 'ARMOR') {
            if (currentLevel == 0) {
              requiredItemName = '가죽 갑옷';
            } else if (currentLevel == 1) {
              requiredItemName = '은 갑옷';
            }
          } else if (itemType == 'WEAPON') {
            if (currentLevel == 0) {
              requiredItemName = '나무 검';
            } else if (currentLevel == 1) {
              requiredItemName = '은 검';
            }
          }
          
          if (requiredItemName.isNotEmpty) {
            message = '$requiredItemName을(를) 먼저 구매해야 합니다.';
          } else {
            message = '이전 업그레이드를 먼저 완료해야 합니다.';
          }
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    // 구매 가능하면 다이얼로그 표시
    if (mounted) {
      setState(() {
        selectedItem = item;
        showBuyDialog = true;
      });
    }
  }

  void _hideBuyDialog() {
    if (mounted) {
      setState(() {
        showBuyDialog = false;
        selectedItem = null;
      });
    }
  }

  void _showPurchaseCompleteDialog() {
    print('=== 구매 완료 다이얼로그 표시 시도 ===');
    print('mounted: $mounted');
    if (mounted) {
      setState(() {
        showPurchaseCompleteDialog = true;
        print('구매 완료 다이얼로그 상태: $showPurchaseCompleteDialog');
      });
    }
    print('=== 구매 완료 다이얼로그 표시 완료 ===');
  }

  void _hidePurchaseCompleteDialog() {
    print('=== 구매 완료 다이얼로그 닫기 시도 ===');
    if (mounted) {
      setState(() {
        showPurchaseCompleteDialog = false;
        print('구매 완료 다이얼로그 상태: $showPurchaseCompleteDialog');
        // 상점 아이템은 이미 _simulateEquipmentUpdate에서 업데이트됨
      });
    }
    print('=== 구매 완료 다이얼로그 닫기 완료 ===');
  }

  @override
  void initState() {
    super.initState();
    // 초기 상태에서 기본 아이템들 설정 (테스트용)
    _initializeDefaultItems();
    _loadCurrentUser();
  }

  // 테스트용: 초기 기본 아이템들 설정
  void _initializeDefaultItems() {
    // 현재 갑옷과 무기가 없는 상태에서 첫 번째 업그레이드 아이템들 설정
    currentArmorItem = EquipmentUpgrade.getNextArmorUpgrade(null);
    currentWeaponItem = EquipmentUpgrade.getNextWeaponUpgrade(null);
    
    // 포션 아이템 기본값 설정 (서버에서 로드되면 업데이트됨)
    currentPotionItem = ShopItem(
      itemId: 'magic_potion',
      name: 'Potion',
      description: '마법 포션',
      price: 40,
      itemType: 'POTION',
    );

    print('초기 상점 아이템 설정:');
    print('갑옷: ${currentArmorItem?.name ?? "없음"}');
    print('무기: ${currentWeaponItem?.name ?? "없음"}');
    print('포션: ${currentPotionItem?.name ?? "없음"}');
  }

  Future<void> _loadCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userIdString = prefs.getString('userId');
      final userDbId = prefs.getInt('userDbId');
      
      if (userDbId != null) {
        print('✅ 로그인한 사용자 DB ID: $userDbId (문자열 ID: $userIdString)');
        if (mounted) {
          setState(() {
            currentUserId = userDbId.toString(); // 구매 API를 위해 문자열로 저장
            currentUserDbId = userDbId; // Long ID 저장
          });
        }
      } else if (userIdString != null && userIdString.isNotEmpty) {
        print('⚠️ 사용자 DB ID가 없습니다. 사용자 정보 조회로 ID를 가져옵니다.');
        // 사용자 정보 조회 API로 DB ID 가져오기
        await _fetchUserDbId(userIdString);
        return;
      } else {
        print('⚠️ 로그인한 사용자 ID가 없습니다.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('로그인이 필요합니다. 로그인 화면으로 이동합니다.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
    } catch (e) {
      print('❌ 사용자 ID 가져오기 실패: $e');
    }
    await _loadUserGameInfo();
  }
  
  // 사용자 정보 조회 API를 통해 DB ID 가져오기
  Future<void> _fetchUserDbId(String userIdString) async {
    try {
      print('사용자 DB ID 조회 시작: userIdString=$userIdString');
      
      // 문자열 userId로 사용자를 찾는 API가 없으므로
      // 사용자 정보 API를 여러 ID로 시도하거나
      // 다른 방법이 필요합니다
      // 
      // 대안: 사용자가 이미 로그인했으므로
      // 임시로 1부터 시작하여 사용자 정보를 조회해보거나
      // 백엔드에 userId(문자열)로 DB ID를 조회하는 API가 있는지 확인 필요
      
      // 일단 사용자에게 안내 메시지 표시
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('사용자 정보를 불러올 수 없습니다. 다시 로그인해주세요.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('사용자 DB ID 조회 실패: $e');
    }
  }

  Future<void> _loadUserGameInfo() async {
    if (currentUserDbId == null) return;

    try {
      setState(() {
        isLoading = true;
      });

      // HomeScreen과 동일한 방식으로 사용자 게임 정보 로드
      final info = await GameService.getUserGameInfo(currentUserDbId!);
      if (!mounted) return;
      
      setState(() {
        userGameInfo = info;
        isLoading = false;
      });
      
      // 상점 아이템 업데이트 (갑옷, 무기)
      _updateShopItems();
      
      // 서버에서 포션 아이템 가져오기
      await _loadPotionItem();
      
      print('✅ 사용자 게임 정보 로드 완료');
    } catch (e) {
      print('❌ 사용자 게임 정보 로드 오류: $e');
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }


  String _getItemTypeFromId(String itemId) {
    if (itemId.contains('armor')) return 'ARMOR';
    if (itemId.contains('sword')) return 'WEAPON';
    if (itemId == 'magic_potion') return 'POTION';
    return 'OTHER';
  }

  String _getItemNameFromId(String itemId) {
    switch (itemId) {
      case 'leather_armor': return 'Leather Armor';
      case 'silver_armor': return 'Silver Armor';
      case 'gold_armor': return 'Gold Armor';
      case 'wooden_sword': return 'Wooden Sword';
      case 'silver_sword': return 'Silver Sword';
      case 'gold_sword': return 'Gold Sword';
      case 'magic_potion': return 'Potion';
      default: return 'Unknown Item';
    }
  }

  int _getItemLevelFromId(String itemId) {
    switch (itemId) {
      case 'leather_armor':
      case 'wooden_sword': return 1;
      case 'silver_armor':
      case 'silver_sword': return 2;
      case 'gold_armor':
      case 'gold_sword': return 3;
      default: return 1;
    }
  }

  int _getItemPriceFromId(String itemId) {
    switch (itemId) {
      case 'leather_armor':
      case 'wooden_sword': return 10;
      case 'silver_armor':
      case 'silver_sword': return 30;
      case 'gold_armor':
      case 'gold_sword': return 50;
      case 'magic_potion': return 40;
      default: return 10;
    }
  }

  void _updateShopItems() {
    Map<String, dynamic>? currentArmor;
    Map<String, dynamic>? currentWeapon;
    int highestArmorLevel = 0;
    int highestWeaponLevel = 0;

    if (userGameInfo != null && userGameInfo!.inventory.isNotEmpty) {
      // inventory는 List이므로 첫 번째 요소 사용
      final inventory = userGameInfo!.inventory[0] as Map<String, dynamic>?;
      if (inventory != null) {
        currentArmor = inventory['equippedArmor'];
        currentWeapon = inventory['equippedWeapon'];
        
        // 장착된 갑옷의 레벨 확인
        if (currentArmor != null) {
          String armorId = currentArmor['id'] ?? '';
          int? level = EquipmentUpgrade.getItemLevel(armorId, 'ARMOR');
          if (level != null && level > highestArmorLevel) {
            highestArmorLevel = level;
          }
        }
        
        // 인벤토리 배열의 갑옷들 확인
        final armors = inventory['armors'];
        if (armors is List) {
          for (var armor in armors) {
            if (armor is Map<String, dynamic>) {
              String armorId = (armor['itemId'] ?? armor['id'])?.toString() ?? '';
              int? level = EquipmentUpgrade.getItemLevel(armorId, 'ARMOR');
              if (level != null && level > highestArmorLevel) {
                highestArmorLevel = level;
              }
            }
          }
        }
        
        // 장착된 무기의 레벨 확인
        if (currentWeapon != null) {
          String weaponId = currentWeapon['id'] ?? '';
          int? level = EquipmentUpgrade.getItemLevel(weaponId, 'WEAPON');
          if (level != null && level > highestWeaponLevel) {
            highestWeaponLevel = level;
          }
        }
        
        // 인벤토리 배열의 무기들 확인
        final weapons = inventory['weapons'];
        if (weapons is List) {
          for (var weapon in weapons) {
            if (weapon is Map<String, dynamic>) {
              String weaponId = (weapon['itemId'] ?? weapon['id'])?.toString() ?? '';
              int? level = EquipmentUpgrade.getItemLevel(weaponId, 'WEAPON');
              if (level != null && level > highestWeaponLevel) {
                highestWeaponLevel = level;
              }
            }
          }
        }
      }
    }

    print('=== 상점 아이템 업데이트 시작 ===');
    print('현재 장비 상태:');
    print('갑옷: $currentArmor');
    print('무기: $currentWeapon');
    print('가장 높은 갑옷 레벨: $highestArmorLevel');
    print('가장 높은 무기 레벨: $highestWeaponLevel');

    // 가장 높은 레벨에 맞는 다음 업그레이드 아이템 찾기
    // highestLevel에 해당하는 장비를 찾아서 그 다음 레벨 아이템 반환
    Map<String, dynamic>? bestArmor;
    Map<String, dynamic>? bestWeapon;
    
    // 가장 높은 레벨의 갑옷 찾기 (다음 업그레이드를 위한 기준)
    if (highestArmorLevel > 0) {
      for (var upgrade in EquipmentUpgrade.armorUpgrades) {
        if (upgrade['level'] == highestArmorLevel) {
          bestArmor = {
            'id': upgrade['id'],
            'level': upgrade['level'],
          };
          break;
        }
      }
    }
    
    // 가장 높은 레벨의 무기 찾기
    if (highestWeaponLevel > 0) {
      for (var upgrade in EquipmentUpgrade.weaponUpgrades) {
        if (upgrade['level'] == highestWeaponLevel) {
          bestWeapon = {
            'id': upgrade['id'],
            'level': upgrade['level'],
          };
          break;
        }
      }
    }

    print('다음 업그레이드 아이템 찾기 시작');
    print('기준 갑옷: $bestArmor (레벨: $highestArmorLevel)');
    currentArmorItem = EquipmentUpgrade.getNextArmorUpgrade(bestArmor);
    print('찾은 갑옷: ${currentArmorItem?.name ?? "없음"}');

    print('기준 무기: $bestWeapon (레벨: $highestWeaponLevel)');
    currentWeaponItem = EquipmentUpgrade.getNextWeaponUpgrade(bestWeapon);
    print('찾은 무기: ${currentWeaponItem?.name ?? "없음"}');
    print('다음 업그레이드 아이템 찾기 완료');

    print('업데이트된 상점 아이템:');
    print('갑옷: ${currentArmorItem?.name ?? "없음"} (가격: ${currentArmorItem?.price ?? "N/A"})');
    print('무기: ${currentWeaponItem?.name ?? "없음"} (가격: ${currentWeaponItem?.price ?? "N/A"})');
    print('포션: ${currentPotionItem?.name ?? "없음"} (가격: ${currentPotionItem?.price ?? "N/A"})');
    print('=== 상점 아이템 업데이트 완료 ===');
  }

  // 서버에서 포션 아이템 가져오기
  Future<void> _loadPotionItem() async {
    try {
      // 서버에서 POTION 타입 아이템 가져오기
      final potionItems = await fetchShopItemsByType('POTION');
      
      if (potionItems != null && potionItems.isNotEmpty) {
        // magic_potion 아이템 찾기
        final magicPotion = potionItems.firstWhere(
          (item) => item.itemId == 'magic_potion',
          orElse: () => potionItems.first, // magic_potion이 없으면 첫 번째 포션 사용
        );
        
        if (mounted) {
          setState(() {
            currentPotionItem = magicPotion;
          });
        }
        print('✅ 포션 아이템 로드 완료: ${magicPotion.name} (가격: ${magicPotion.price})');
      } else {
        // 서버에서 포션을 가져올 수 없으면 기본값 사용
        if (mounted) {
          setState(() {
            currentPotionItem = ShopItem(
              itemId: 'magic_potion',
              name: 'Potion',
              description: '마법 포션',
              price: 40,
              itemType: 'POTION',
            );
          });
        }
        print('⚠️ 서버에서 포션 아이템을 가져올 수 없어 기본값 사용');
      }
    } catch (e) {
      print('❌ 포션 아이템 로드 오류: $e');
      // 오류 발생 시 기본값 사용
      if (mounted) {
        setState(() {
          currentPotionItem = ShopItem(
            itemId: 'magic_potion',
            name: 'Potion',
            description: '마법 포션',
            price: 40,
            itemType: 'POTION',
          );
        });
      }
    }
  }

  // 현재 보유 골드 확인 (HomeScreen과 동일한 방식)
  int _getCurrentGold() {
    return userGameInfo?.gold ?? 0;
  }

  // 아이템 구매 가능 여부 확인 (골드만 체크)
  bool _canAffordItem(ShopItem item) {
    final currentGold = _getCurrentGold();
    return currentGold >= item.price;
  }

  // 아이템 구매 가능 여부 확인 (골드 + 업그레이드 순서 체크)
  bool _canPurchaseItem(ShopItem item) {
    // 1. 골드 체크
    if (!_canAffordItem(item)) {
      return false;
    }

    // 2. 업그레이드 순서 체크
    String itemType = item.itemType.toUpperCase();
    if (itemType.isEmpty) {
      // itemType이 비어있으면 ID로 타입 확인 시도
      itemType = EquipmentUpgrade.getItemType(item.itemId) ?? '';
      if (itemType.isEmpty) {
        print('⚠️ 알 수 없는 아이템 타입: ${item.itemId}');
        return true; // 타입을 알 수 없으면 구매 허용 (기타 아이템)
      }
    }

    // POTION 타입은 레벨 체크 없이 구매 가능
    if (itemType == 'POTION') {
      print('✅ 포션 구매 가능: 골드 체크 통과');
      return true;
    }

    // 현재 장비 확인 및 가장 높은 레벨 찾기
    int currentLevel = 0;
    if (userGameInfo != null && userGameInfo!.inventory.isNotEmpty) {
      final inventory = userGameInfo!.inventory[0] as Map<String, dynamic>?;
      if (inventory != null) {
        if (itemType == 'ARMOR') {
          // 장착된 갑옷 레벨 확인
          final equippedArmor = inventory['equippedArmor'];
          if (equippedArmor != null) {
            String armorId = equippedArmor['id'] ?? '';
            int? level = EquipmentUpgrade.getItemLevel(armorId, 'ARMOR');
            if (level != null && level > currentLevel) {
              currentLevel = level;
            }
          }
          // 인벤토리 배열의 갑옷들 확인
          final armors = inventory['armors'];
          if (armors is List) {
            for (var armor in armors) {
              if (armor is Map<String, dynamic>) {
                String armorId = (armor['itemId'] ?? armor['id'])?.toString() ?? '';
                int? level = EquipmentUpgrade.getItemLevel(armorId, 'ARMOR');
                if (level != null && level > currentLevel) {
                  currentLevel = level;
                }
              }
            }
          }
        } else if (itemType == 'WEAPON') {
          // 장착된 무기 레벨 확인
          final equippedWeapon = inventory['equippedWeapon'];
          if (equippedWeapon != null) {
            String weaponId = equippedWeapon['id'] ?? '';
            int? level = EquipmentUpgrade.getItemLevel(weaponId, 'WEAPON');
            if (level != null && level > currentLevel) {
              currentLevel = level;
            }
          }
          // 인벤토리 배열의 무기들 확인
          final weapons = inventory['weapons'];
          if (weapons is List) {
            for (var weapon in weapons) {
              if (weapon is Map<String, dynamic>) {
                String weaponId = (weapon['itemId'] ?? weapon['id'])?.toString() ?? '';
                int? level = EquipmentUpgrade.getItemLevel(weaponId, 'WEAPON');
                if (level != null && level > currentLevel) {
                  currentLevel = level;
                }
              }
            }
          }
        }
      }
    }
    
    // 아이템 레벨 확인
    int? itemLevel = EquipmentUpgrade.getItemLevel(item.itemId, itemType);
    if (itemLevel == null) {
      // POTION 타입이 아닌 경우에만 경고 로그 출력
      if (itemType != 'POTION') {
        print('⚠️ 아이템 레벨을 확인할 수 없음: ${item.itemId} (타입: $itemType)');
      }
      // 레벨이 없는 아이템(POTION 등)은 구매 허용
      return true;
    }

    // 업그레이드 순서 확인: 다음 레벨 아이템만 구매 가능
    // 현재 레벨이 0이면 레벨 1만, 현재 레벨이 1이면 레벨 2만, 현재 레벨이 2이면 레벨 3만 구매 가능
    int nextLevel = currentLevel + 1;
    
    if (itemLevel != nextLevel) {
      print('❌ 업그레이드 순서 위반: 현재 레벨=$currentLevel, 아이템 레벨=$itemLevel, 필요 레벨=$nextLevel');
      return false;
    }

    print('✅ 구매 가능: 현재 레벨=$currentLevel, 아이템 레벨=$itemLevel');
    return true;
  }

  Future<void> _handlePurchase() async {
    if (selectedItem == null || currentUserId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('구매할 수 없습니다. 사용자 정보를 확인해주세요.')),
        );
      }
      return;
    }

    // 구매 가능 여부 체크 (골드 + 업그레이드 순서)
    if (!_canPurchaseItem(selectedItem!)) {
      if (mounted) {
        String message = '구매할 수 없습니다.';
        
        // 골드 부족
        if (!_canAffordItem(selectedItem!)) {
          message = '골드가 부족합니다! (보유: ${_getCurrentGold()}, 필요: ${selectedItem!.price})';
        } else {
          // 업그레이드 순서 위반
          String itemType = selectedItem!.itemType;
          if (itemType.isEmpty) {
            itemType = EquipmentUpgrade.getItemType(selectedItem!.itemId) ?? '';
          }
          
          // 현재 장비 확인 및 가장 높은 레벨 찾기
          int currentLevel = 0;
          if (userGameInfo != null && userGameInfo!.inventory.isNotEmpty) {
            final inventory = userGameInfo!.inventory[0] as Map<String, dynamic>?;
            if (inventory != null) {
              if (itemType == 'ARMOR') {
                // 장착된 갑옷 레벨 확인
                final equippedArmor = inventory['equippedArmor'];
                if (equippedArmor != null) {
                  String armorId = equippedArmor['id'] ?? '';
                  int? level = EquipmentUpgrade.getItemLevel(armorId, 'ARMOR');
                  if (level != null && level > currentLevel) {
                    currentLevel = level;
                  }
                }
                // 인벤토리 배열의 갑옷들 확인
                final armors = inventory['armors'];
                if (armors is List) {
                  for (var armor in armors) {
                    if (armor is Map<String, dynamic>) {
                      String armorId = (armor['itemId'] ?? armor['id'])?.toString() ?? '';
                      int? level = EquipmentUpgrade.getItemLevel(armorId, 'ARMOR');
                      if (level != null && level > currentLevel) {
                        currentLevel = level;
                      }
                    }
                  }
                }
              } else if (itemType == 'WEAPON') {
                // 장착된 무기 레벨 확인
                final equippedWeapon = inventory['equippedWeapon'];
                if (equippedWeapon != null) {
                  String weaponId = equippedWeapon['id'] ?? '';
                  int? level = EquipmentUpgrade.getItemLevel(weaponId, 'WEAPON');
                  if (level != null && level > currentLevel) {
                    currentLevel = level;
                  }
                }
                // 인벤토리 배열의 무기들 확인
                final weapons = inventory['weapons'];
                if (weapons is List) {
                  for (var weapon in weapons) {
                    if (weapon is Map<String, dynamic>) {
                      String weaponId = (weapon['itemId'] ?? weapon['id'])?.toString() ?? '';
                      int? level = EquipmentUpgrade.getItemLevel(weaponId, 'WEAPON');
                      if (level != null && level > currentLevel) {
                        currentLevel = level;
                      }
                    }
                  }
                }
              }
            }
          }
          
          String requiredItemName = '';
          if (itemType == 'ARMOR') {
            if (currentLevel == 0) {
              requiredItemName = '가죽 갑옷';
            } else if (currentLevel == 1) {
              requiredItemName = '은 갑옷';
            }
          } else if (itemType == 'WEAPON') {
            if (currentLevel == 0) {
              requiredItemName = '나무 검';
            } else if (currentLevel == 1) {
              requiredItemName = '은 검';
            }
          }
          
          message = requiredItemName.isNotEmpty 
            ? '$requiredItemName을(를) 먼저 구매해야 합니다.'
            : '이전 업그레이드를 먼저 완료해야 합니다.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      print('=== 구매 처리 시작 ===');
      print('선택된 아이템: ${selectedItem?.name} (ID: ${selectedItem?.itemId})');

      // 백엔드 API 호출 - Long 타입 userId 사용
      if (currentUserDbId == null) {
        throw Exception('로그인이 필요합니다.');
      }
      
      final result = await purchaseItem(currentUserDbId!, selectedItem!.itemId);

      print('구매 결과: $result');

      // 구매 성공 - result.data에 playerGold와 purchasedItem이 포함됨
      final purchaseData = result['data'] as Map<String, dynamic>?;
      
      if (purchaseData != null && mounted) {
        // 구매 전 골드 확인
        final beforeGold = _getCurrentGold();
        print('구매 전 골드: $beforeGold');
        
        // 구매 성공 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('구매 성공: ${result['message'] ?? '구매가 완료되었습니다.'}'),
            backgroundColor: Colors.green,
          ),
        );

        // 구매 후 사용자 정보 다시 로드 (서버에서 업데이트된 골드와 장비 정보 반영)
        await _loadUserGameInfo();

        // 구매창 닫기
        _hideBuyDialog();

        // 구매 완료 다이얼로그 표시
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          _showPurchaseCompleteDialog();
        }
      }
    } catch (e) {
      _hideBuyDialog();
      if (mounted) {
        String errorMessage = '구매 중 오류가 발생했습니다.';
        
        if (e.toString().contains('로그인이 필요합니다')) {
          errorMessage = '로그인이 필요합니다.';
        } else if (e.toString().contains('Exception: ')) {
          // 서버에서 반환한 에러 메시지 추출
          final match = RegExp(r'Exception: (.+)').firstMatch(e.toString());
          if (match != null) {
            errorMessage = match.group(1)!;
          }
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/GridScreen.png'),
              fit: BoxFit.cover,
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const SizedBox(height: 20), // 상단 여백 추가
                // 홈 버튼과 Shop 제목을 같은 높이에 배치
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 홈 버튼 (왼쪽)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: GestureDetector(
                        onTap: () {
                          SoundManager().playClick();
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const HomeScreen()),
                          );
                        },
                        child: Image.asset(
                          'assets/images/BackButton.png',
                          width: 40,
                          height: 40,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    // Shop 제목과 골드 표시 (가운데)
                    Column(
                      children: [
                        Text(
                          'Shop',
                          style: TextStyle(
                            fontSize: 55,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                            fontFamily: 'DungGeunMo',
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // 골드 표시
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/images/Icon_Gold.png',
                              width: 40,
                              height: 40,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${userGameInfo?.gold ?? 0}',
                              style: TextStyle(
                                fontSize: 35,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                                fontFamily: 'DungGeunMo',
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // 오른쪽 공간 (대칭을 위해)
                    SizedBox(width: 48), // 홈 버튼과 같은 너비
                  ],
                ),
                // 상점 아이템들
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final screenWidth = MediaQuery.of(context).size.width;
                      final isTablet = screenWidth > 600;

                      if (isTablet) {
                        // 태블릿: 동적 레이아웃
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // 첫 번째 줄: 동적 갑옷, 동적 무기
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                if (currentArmorItem != null)
                                  _buildShopItem(
                                    'assets/images/StoreItemFrame.png',
                                    EquipmentUpgrade.getImagePath(currentArmorItem!.itemId),
                                    currentArmorItem!.name,
                                    currentArmorItem!.price,
                                    currentArmorItem!,
                                  ),
                                if (currentWeaponItem != null)
                                  _buildShopItem(
                                    'assets/images/StoreItemFrame.png',
                                    EquipmentUpgrade.getImagePath(currentWeaponItem!.itemId),
                                    currentWeaponItem!.name,
                                    currentWeaponItem!.price,
                                    currentWeaponItem!,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            // 두 번째 줄: Potion
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (currentPotionItem != null)
                                  _buildShopItem(
                                    'assets/images/StoreItemFrame.png',
                                    'assets/images/MagicPotion.png',
                                    currentPotionItem!.name,
                                    currentPotionItem!.price,
                                    currentPotionItem!,
                                  ),
                              ],
                            ),
                          ],
                        );
                      } else {
                        // 스마트폰: 동적 레이아웃
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // 첫 번째 줄: 동적 갑옷, 동적 무기
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                if (currentArmorItem != null)
                                  _buildShopItem(
                                    'assets/images/StoreItemFrame.png',
                                    EquipmentUpgrade.getImagePath(currentArmorItem!.itemId),
                                    currentArmorItem!.name,
                                    currentArmorItem!.price,
                                    currentArmorItem!,
                                  ),
                                if (currentWeaponItem != null)
                                  _buildShopItem(
                                    'assets/images/StoreItemFrame.png',
                                    EquipmentUpgrade.getImagePath(currentWeaponItem!.itemId),
                                    currentWeaponItem!.name,
                                    currentWeaponItem!.price,
                                    currentWeaponItem!,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            // 두 번째 줄: Potion
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (currentPotionItem != null)
                                  _buildShopItem(
                                    'assets/images/StoreItemFrame.png',
                                    'assets/images/MagicPotion.png',
                                    currentPotionItem!.name,
                                    currentPotionItem!.price,
                                    currentPotionItem!,
                                  ),
                              ],
                            ),
                          ],
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        // 구매 창 오버레이
        if (showBuyDialog && selectedItem != null)
          _buildBuyDialog(),
        // 구매 완료 창 오버레이
        if (showPurchaseCompleteDialog)
          _buildPurchaseCompleteDialog(),
      ],
    );
  }

  Widget _buildShopItem(String framePath, String itemPath, String itemName, int price, ShopItem shopItem) {
    // 태블릿은 고정 크기, 스마트폰은 화면에 맞게 조절
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    final itemWidth = isTablet ? 240.0 : screenWidth * 0.4; // 스마트폰 크기 원복
    final itemHeight = isTablet ? 270.0 : itemWidth * 1.125; // 비율 유지
    final imageSize = isTablet ? 120.0 : itemWidth * 0.5; // 스마트폰 이미지 크기 원복
    final fontSize = isTablet ? 21.0 : 16.0; // 스마트폰 텍스트 크기 원복
    final priceFontSize = isTablet ? 24.0 : 18.0; // 스마트폰 가격 텍스트 크기 원복

    // 구매 가능 여부 확인 (골드 + 업그레이드 순서)
    final canPurchase = _canPurchaseItem(shopItem);

    return GestureDetector(
      onTap: canPurchase ? () => _showBuyDialog(shopItem) : () {
        // 클릭 가능하지만 구매 불가능한 경우 메시지 표시 (업그레이드 순서 위반)
        if (!_canAffordItem(shopItem)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('골드가 부족합니다! (보유: ${_getCurrentGold()}, 필요: ${shopItem.price})'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          // 업그레이드 순서 위반
          String itemType = shopItem.itemType;
          if (itemType.isEmpty) {
            itemType = EquipmentUpgrade.getItemType(shopItem.itemId) ?? '';
          }
          
          // 현재 장비 확인 및 가장 높은 레벨 찾기
          int currentLevel = 0;
          if (userGameInfo != null && userGameInfo!.inventory.isNotEmpty) {
            final inventory = userGameInfo!.inventory[0] as Map<String, dynamic>?;
            if (inventory != null) {
              if (itemType == 'ARMOR') {
                // 장착된 갑옷 레벨 확인
                final equippedArmor = inventory['equippedArmor'];
                if (equippedArmor != null) {
                  String armorId = equippedArmor['id'] ?? '';
                  int? level = EquipmentUpgrade.getItemLevel(armorId, 'ARMOR');
                  if (level != null && level > currentLevel) {
                    currentLevel = level;
                  }
                }
                // 인벤토리 배열의 갑옷들 확인
                final armors = inventory['armors'];
                if (armors is List) {
                  for (var armor in armors) {
                    if (armor is Map<String, dynamic>) {
                      String armorId = (armor['itemId'] ?? armor['id'])?.toString() ?? '';
                      int? level = EquipmentUpgrade.getItemLevel(armorId, 'ARMOR');
                      if (level != null && level > currentLevel) {
                        currentLevel = level;
                      }
                    }
                  }
                }
              } else if (itemType == 'WEAPON') {
                // 장착된 무기 레벨 확인
                final equippedWeapon = inventory['equippedWeapon'];
                if (equippedWeapon != null) {
                  String weaponId = equippedWeapon['id'] ?? '';
                  int? level = EquipmentUpgrade.getItemLevel(weaponId, 'WEAPON');
                  if (level != null && level > currentLevel) {
                    currentLevel = level;
                  }
                }
                // 인벤토리 배열의 무기들 확인
                final weapons = inventory['weapons'];
                if (weapons is List) {
                  for (var weapon in weapons) {
                    if (weapon is Map<String, dynamic>) {
                      String weaponId = (weapon['itemId'] ?? weapon['id'])?.toString() ?? '';
                      int? level = EquipmentUpgrade.getItemLevel(weaponId, 'WEAPON');
                      if (level != null && level > currentLevel) {
                        currentLevel = level;
                      }
                    }
                  }
                }
              }
            }
          }
          
          String requiredItemName = '';
          if (itemType == 'ARMOR') {
            if (currentLevel == 0) {
              requiredItemName = '가죽 갑옷';
            } else if (currentLevel == 1) {
              requiredItemName = '은 갑옷';
            }
          } else if (itemType == 'WEAPON') {
            if (currentLevel == 0) {
              requiredItemName = '나무 검';
            } else if (currentLevel == 1) {
              requiredItemName = '은 검';
            }
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(requiredItemName.isNotEmpty 
                ? '$requiredItemName을(를) 먼저 구매해야 합니다.'
                : '이전 업그레이드를 먼저 완료해야 합니다.'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      child: Container(
        width: itemWidth,
        height: itemHeight,
        child: Stack(
          children: [
            // 프레임
            Image.asset(
              framePath,
              width: itemWidth,
              height: itemHeight,
              fit: BoxFit.contain,
            ),
            // 아이템 이미지
            Positioned(
              top: 15, // 원복
              left: 0,
              right: 0,
              child: Center(
                child: Opacity(
                  opacity: canPurchase ? 1.0 : 0.5,
                  child: Image.asset(
                    itemPath,
                    width: imageSize,
                    height: imageSize,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            // 아이템 이름
            Positioned(
              top: isTablet ? 150.0 : itemHeight * 0.55, // 스마트폰에서는 비율로 조절
              left: 0,
              right: 0,
              child: Center(
                child: Opacity(
                  opacity: canPurchase ? 1.0 : 0.5,
                  child: Text(
                    itemName,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      fontFamily: 'DungGeunMo',
                      decoration: TextDecoration.none,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            // 가격 (골드 아이콘 + 가격)
            Positioned(
              bottom: 15, // 원복
              left: 0,
              right: 0,
              child: Opacity(
                opacity: canPurchase ? 1.0 : 0.5,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/Icon_Gold.png',
                      width: isTablet ? 30.0 : 24.0, // 원복
                      height: isTablet ? 30.0 : 24.0,
                    ),
                    const SizedBox(width: 4), // 원복
                    Text(
                      price.toString(),
                      style: TextStyle(
                        fontSize: priceFontSize,
                        fontWeight: FontWeight.bold,
                        color: canPurchase ? Colors.black : Colors.red,
                        fontFamily: 'DungGeunMo',
                        decoration: TextDecoration.none,
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

  Widget _buildBuyDialog() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.3),
        child: Center(
          child: Container(
            width: 375,  // 250 * 1.5
            height: 270, // 180 * 1.5
            child: Stack(
              children: [
                // 구매 창 프레임
                Image.asset(
                  'assets/images/StoreBuyFrame.png',
                  width: 375,
                  height: 270,
                  fit: BoxFit.contain,
                ),
                // X 버튼 (닫기)
                Positioned(
                  top: 10,
                  right: 10,
                  child: GestureDetector(
                    onTap: _hideBuyDialog,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B4513), // 짙은 브라운 색상
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Center(
                        child: Text(
                          '×',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // 아이템 이미지
                Positioned(
                  top: 45,  // 30 * 1.5
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Image.asset(
                      _getItemImagePath(selectedItem!.itemId, selectedItem!.itemType),
                      width: 75,  // 50 * 1.5
                      height: 75,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                // 아이템 이름
                Positioned(
                  top: 130,  // 아이템 이미지 아래
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      selectedItem!.name,
                      style: TextStyle(
                        fontSize: 18,  // 적절한 크기
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        fontFamily: 'DungGeunMo',
                        decoration: TextDecoration.none,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                // 골드 아이콘과 가격
                Positioned(
                  top: 170,  // 아이템 이름 아래로 조정
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/Icon_Gold.png',
                        width: 27,
                        height: 27,
                      ),
                      const SizedBox(width: 9),
                      Text(
                        selectedItem!.price.toString(),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          fontFamily: 'DungGeunMo',
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
                // 구매 버튼
                Positioned(
                  bottom: 22,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: isLoading ? null : _handlePurchase,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.asset(
                            'assets/images/StoreBuy_OK_Button.png',
                            width: 105,
                            height: 37,
                            fit: BoxFit.contain,
                            color: isLoading ? Colors.grey : null,
                          ),
                          isLoading
                              ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                            ),
                          )
                              : const Text(
                            'buy',
                            style: TextStyle(
                              fontSize: 18,  // 12 * 1.5
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                              fontFamily: 'DungGeunMo',
                              decoration: TextDecoration.none,
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
        ),
      ),
    );
  }

  Widget _buildPurchaseCompleteDialog() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.3),
        child: Center(
          child: Container(
            width: 375,  // 구매 창과 동일한 크기
            height: 270, // 구매 창과 동일한 크기
            child: Stack(
              children: [
                // 구매 완료 창 프레임
                Image.asset(
                  'assets/images/StoreBuyFrame.png',
                  width: 375,
                  height: 270,
                  fit: BoxFit.contain,
                ),
                // "Purchase completed" 문구
                Positioned(
                  top: 90,  // 중앙에 위치하도록 조정
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text(
                      'Purchase\ncompleted.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,  // 구매 창과 비슷한 크기
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        fontFamily: 'DungGeunMo',
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
                // OK 버튼
                Positioned(
                  bottom: 22,  // 구매 창과 동일한 위치
                  left: 0,
                  right: 0,
                  child: Center(
                    child: GestureDetector(
                      onTap: _hidePurchaseCompleteDialog,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.asset(
                            'assets/images/StoreBuy_OK_Button.png',
                            width: 105,  // 구매 창과 동일한 크기
                            height: 37,
                            fit: BoxFit.contain,
                          ),
                          const Text(
                            'ok',
                            style: TextStyle(
                              fontSize: 18,  // 구매 창과 동일한 크기
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                              fontFamily: 'DungGeunMo',
                              decoration: TextDecoration.none,
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
        ),
      ),
    );
  }

  String _getItemImagePath(String itemId, String itemType) {
    // POTION 타입이면 MagicPotion.png 반환
    if (itemType.toUpperCase() == 'POTION' || itemId == 'magic_potion') {
      return 'assets/images/MagicPotion.png';
    }
    // EquipmentUpgrade 클래스의 getImagePath 사용
    return EquipmentUpgrade.getImagePath(itemId);
  }
}
