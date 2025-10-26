import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'HomeScreen.dart';

final baseUrl = 'http://192.168.219.110:8083';

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
      itemType: json['itemType'] ?? '',
      stats: json['stats'],
    );
  }
}

// 상점 아이템 목록 조회 API
Future<List<ShopItem>?> fetchShopItems() async {
  try {
    final response = await http.get(
      Uri.parse('$baseUrl/api/game/shop/items'),
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
      Uri.parse('$baseUrl/api/game/shop/items/type/$type'),
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

// 사용자 장비 상태 조회 API
Future<Map<String, dynamic>?> fetchUserEquipment(String userId) async {
  try {
    print('사용자 장비 정보 조회 시작: userId=$userId');
    
    final response = await http.get(
      Uri.parse('http://192.168.219.110:8083/api/game/user/$userId/equipment'),
      headers: {'Content-Type': 'application/json'},
    ).timeout(const Duration(seconds: 10));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('사용자 장비 데이터 조회 성공: $data');
      return data;
    } else {
      print('사용자 장비 조회 실패: ${response.statusCode}');
      return null;
    }
  } catch (e) {
    print('사용자 장비 조회 오류: $e');
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
}

// 아이템 구매 API
Future<Map<String, dynamic>> purchaseItem(String userId, String itemId) async {
  try {
    print('구매 요청 시작: userId=$userId, itemId=$itemId');
    
    final response = await http.post(
      Uri.parse('http://192.168.219.110:8083/api/game/shop/purchase'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'userId': userId,
        'itemId': itemId,
      }),
    ).timeout(const Duration(seconds: 10));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('구매 성공: $data');
      return {
        'success': true,
        'message': data['message'] ?? '구매가 성공적으로 완료되었습니다!',
        'data': data,
      };
    } else {
      final errorData = json.decode(response.body);
      print('구매 실패: ${response.statusCode} - ${errorData['message']}');
      return {
        'success': false,
        'message': errorData['message'] ?? '구매에 실패했습니다.',
        'data': null,
      };
    }
  } catch (e) {
    print('아이템 구매 오류: $e');
    String errorMessage = '구매 중 오류가 발생했습니다.';
    
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

// 구매 완료 후 사용자 정보 업데이트 API
Future<Map<String, dynamic>> updateUserAfterPurchase(String userId, String itemId, int newGold) async {
  try {
    print('구매 후 사용자 정보 업데이트 시작: userId=$userId, itemId=$itemId, newGold=$newGold');
    
    final response = await http.put(
      Uri.parse('http://192.168.219.110:8083/api/game/user/$userId/equipment'),
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
  String? currentUserId;
  bool isLoading = false;
  Map<String, dynamic>? userEquipment;
  ShopItem? currentArmorItem;
  ShopItem? currentWeaponItem;

  void _showBuyDialog(ShopItem item) {
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
    
    print('초기 상점 아이템 설정:');
    print('갑옷: ${currentArmorItem?.name ?? "없음"}');
    print('무기: ${currentWeaponItem?.name ?? "없음"}');
  }

  Future<void> _loadCurrentUser() async {
    // TODO: 실제 로그인된 사용자 ID로 변경 필요
    // 현재는 임시로 사용자 ID "1" 사용
    if (mounted) {
    setState(() {
      currentUserId = "1";
    });
    }
    await _loadUserEquipment();
  }

  Future<void> _loadUserEquipment() async {
    if (currentUserId == null) return;

    try {
      final equipment = await fetchUserEquipment(currentUserId!);
      if (equipment != null && mounted) {
        setState(() {
          userEquipment = equipment;
          _updateShopItems();
        });
      }
    } catch (e) {
      print('사용자 장비 로드 오류: $e');
      // 오류 발생 시에도 기본 아이템들은 유지
    }
  }

  // 구매 후 사용자 정보 업데이트
  Future<void> _updateUserAfterPurchase(String itemId) async {
    try {
      print('=== 구매 후 사용자 정보 업데이트 시작 ===');
      print('구매한 아이템 ID: $itemId');
      
      if (userEquipment == null || currentUserId == null) {
        print('사용자 정보가 없어 업데이트를 건너뜁니다.');
        return;
      }
      
      final currentGold = _getCurrentGold();
      final itemPrice = _getItemPriceFromId(itemId);
      final newGold = currentGold - itemPrice;
      
      print('현재 골드: $currentGold, 아이템 가격: $itemPrice, 새로운 골드: $newGold');
      
      // 백엔드에 사용자 정보 업데이트 요청
      final result = await updateUserAfterPurchase(currentUserId!, itemId, newGold);
      
      if (result['success']) {
        print('사용자 정보 업데이트 성공');
        // 로컬 상태도 업데이트
        if (userEquipment != null) {
          final inventory = userEquipment!['inventory'] as Map<String, dynamic>;
          inventory['gold'] = newGold;
          
          // 갑옷이나 무기인 경우 장비 정보도 업데이트
          final itemType = _getItemTypeFromId(itemId);
          if (itemType == 'ARMOR') {
            inventory['armor'] = {
              'id': itemId,
              'name': _getItemNameFromId(itemId),
              'level': _getItemLevelFromId(itemId),
            };
          } else if (itemType == 'WEAPON') {
            inventory['weapon'] = {
              'id': itemId,
              'name': _getItemNameFromId(itemId),
              'level': _getItemLevelFromId(itemId),
            };
          }
        }
        
        // UI 업데이트
        if (mounted) {
          setState(() {
            _updateShopItems();
          });
        }
      } else {
        print('사용자 정보 업데이트 실패: ${result['message']}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('구매는 완료되었지만 정보 업데이트에 실패했습니다: ${result['message']}'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      print('사용자 정보 업데이트 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('구매는 완료되었지만 정보 업데이트 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
    print('=== 구매 후 사용자 정보 업데이트 완료 ===');
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
    
    if (userEquipment != null) {
      final inventory = userEquipment!['inventory'];
      currentArmor = inventory?['armor'];
      currentWeapon = inventory?['weapon'];
    }

    print('=== 상점 아이템 업데이트 시작 ===');
    print('현재 장비 상태:');
    print('갑옷: $currentArmor');
    print('무기: $currentWeapon');

    // 다음 업그레이드 아이템 설정
    print('다음 업그레이드 아이템 찾기 시작');
    print('현재 갑옷으로 다음 갑옷 찾기: $currentArmor');
    currentArmorItem = EquipmentUpgrade.getNextArmorUpgrade(currentArmor);
    print('찾은 갑옷: ${currentArmorItem?.name ?? "없음"}');
    
    print('현재 무기로 다음 무기 찾기: $currentWeapon');
    currentWeaponItem = EquipmentUpgrade.getNextWeaponUpgrade(currentWeapon);
    print('찾은 무기: ${currentWeaponItem?.name ?? "없음"}');
    print('다음 업그레이드 아이템 찾기 완료');

    print('업데이트된 상점 아이템:');
    print('갑옷: ${currentArmorItem?.name ?? "없음"} (가격: ${currentArmorItem?.price ?? "N/A"})');
    print('무기: ${currentWeaponItem?.name ?? "없음"} (가격: ${currentWeaponItem?.price ?? "N/A"})');
    print('=== 상점 아이템 업데이트 완료 ===');
  }

  // 현재 보유 골드 확인
  int _getCurrentGold() {
    if (userEquipment == null) return 100; // 기본값
    final inventory = userEquipment!['inventory'] as Map<String, dynamic>?;
    return inventory?['gold'] ?? 100;
  }

  // 아이템 구매 가능 여부 확인
  bool _canAffordItem(ShopItem item) {
    final currentGold = _getCurrentGold();
    return currentGold >= item.price;
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

    // 골드 부족 체크
    if (!_canAffordItem(selectedItem!)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('골드가 부족합니다! (보유: ${_getCurrentGold()}, 필요: ${selectedItem!.price})'),
            backgroundColor: Colors.orange,
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
      
      // 백엔드 API 호출
      final result = await purchaseItem(currentUserId!, selectedItem!.itemId);
      
      print('구매 결과: $result');
      
      if (mounted) {
      if (result['success']) {
          // 구매 성공 메시지 표시
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('구매 성공: ${result['message']}'),
            backgroundColor: Colors.green,
          ),
        );
          
          // 선택된 아이템 정보를 미리 저장
          print('선택된 아이템 정보 저장 시작');
          print('selectedItem: $selectedItem');
          print('selectedItem?.itemId: ${selectedItem?.itemId}');
          print('selectedItem?.name: ${selectedItem?.name}');
          
          final purchasedItemId = selectedItem!.itemId;
          final purchasedItemName = selectedItem!.name;
          
          print('저장된 아이템 정보: ID=$purchasedItemId, Name=$purchasedItemName');
          
          // 구매 후 사용자 정보 업데이트
          print('사용자 정보 업데이트 호출 시작');
          _updateUserAfterPurchase(purchasedItemId);
          print('사용자 정보 업데이트 호출 완료');
          
          // 구매창 닫기
          _hideBuyDialog();
          
          // 모든 아이템 구매 후 구매 완료 다이얼로그 표시
          print('구매 완료 다이얼로그 표시 대기 중...');
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            print('구매 완료 다이얼로그 표시 시도');
          _showPurchaseCompleteDialog();
            print('구매 완료 다이얼로그 호출 완료');
          } else {
            print('위젯이 mounted되지 않음');
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('구매 실패: ${result['message']}'),
            backgroundColor: Colors.red,
          ),
        );
        }
      }
    } catch (e) {
      _hideBuyDialog();
      if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('구매 중 오류가 발생했습니다: $e'),
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
                        fontSize: 48,  // 24 * 2
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
                          width: 24,
                          height: 24,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${userEquipment?['inventory']?['gold'] ?? 0}',
                          style: TextStyle(
                            fontSize: 20,
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
                const SizedBox(height: 40),
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
                                _buildShopItem(
                                  'assets/images/StoreItemFrame.png',
                                  'assets/images/MagicPotion.png',
                                  'Potion',
                                  40,
                                  ShopItem(
                                    itemId: 'magic_potion',
                                    name: 'Potion',
                                    description: '마법 포션',
                                    price: 40,
                                    itemType: 'POTION',
                                  ),
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
                                _buildShopItem(
                                  'assets/images/StoreItemFrame.png',
                                  'assets/images/MagicPotion.png',
                                  'Potion',
                                  40,
                                  ShopItem(
                                    itemId: 'magic_potion',
                                    name: 'Potion',
                                    description: '마법 포션',
                                    price: 40,
                                    itemType: 'POTION',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      }
                    },
                  ),
                ),
                // 하단 Start 버튼
                _buildBottomButtonSection(),
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
    
    // 구매 가능 여부 확인
    final canAfford = _canAffordItem(shopItem);
    
    return GestureDetector(
      onTap: canAfford ? () => _showBuyDialog(shopItem) : null,
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
                  opacity: canAfford ? 1.0 : 0.5,
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
                  opacity: canAfford ? 1.0 : 0.5,
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
                opacity: canAfford ? 1.0 : 0.5,
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
                        color: canAfford ? Colors.black : Colors.red,
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

  Widget _buildBottomButtonSection() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Center(
        child: GestureDetector(
          onTap: () {
            // Start 버튼 클릭 시 동작
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
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
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
                      _getItemImagePath(selectedItem!.itemId),
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
                        width: 27,  // 18 * 1.5
                        height: 27,
                      ),
                      const SizedBox(width: 9),  // 6 * 1.5
                      Text(
                        selectedItem!.price.toString(),
                        style: TextStyle(
                          fontSize: 24,  // 16 * 1.5
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
                  bottom: 22,  // 15 * 1.5
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
                            width: 105,  // 70 * 1.5
                            height: 37,  // 25 * 1.5
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

  String _getItemImagePath(String itemId) {
    // EquipmentUpgrade 클래스의 getImagePath 사용
    if (itemId == 'magic_potion') {
      return 'assets/images/MagicPotion.png';
    }
    return EquipmentUpgrade.getImagePath(itemId);
  }
}
