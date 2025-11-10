import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'config/api_config.dart';
import 'models/user_game_info.dart';
import 'services/sound_manager.dart';

// 인벤토리 아이템 모델
class InventoryItem {
  final String itemId;
  final String name;
  final String description;
  final String itemType;
  final Map<String, dynamic>? stats;
  final int quantity;

  InventoryItem({
    required this.itemId,
    required this.name,
    required this.description,
    required this.itemType,
    this.stats,
    this.quantity = 1,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    // 백엔드 ShopItem 엔티티 구조 지원: type 또는 itemType 필드 처리
    String itemType = json['itemType'] ?? json['type'] ?? '';

    // stats 처리: 백엔드에서 statType과 statValue로 분리되어 있으면 stats Map으로 변환
    Map<String, dynamic>? stats = json['stats'];
    if (stats == null && json['statType'] != null && json['statValue'] != null) {
      stats = {
        json['statType']: json['statValue'],
      };
    }

    return InventoryItem(
      itemId: json['itemId'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      itemType: itemType,
      stats: stats,
      quantity: json['quantity'] ?? 1,
    );
  }
}

// 사용자 인벤토리 조회 API
Future<Map<String, dynamic>?> fetchUserInventory(int userId) async {
  try {
    print('사용자 인벤토리 정보 조회 시작: userId=$userId');
    
    final response = await http.get(
      Uri.parse(ApiConfig.userGameInfo(userId)),
      headers: {'Content-Type': 'application/json'},
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw Exception('요청 시간이 초과되었습니다.');
      },
    );

    print('API 응답 상태: ${response.statusCode}');
    print('API 응답 본문: ${response.body}');

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      print('파싱된 데이터: $data');
      
      if (data['success'] == true) {
        // UserGameInfo 모델로 파싱
        final userGameInfo = UserGameInfo.fromJson(data);
        
        // InventoryScreen이 기대하는 형태로 변환
        final inventory = userGameInfo.inventory.isNotEmpty 
            ? userGameInfo.inventory[0] as Map<String, dynamic>?
            : null;
        
        // maxHP는 보통 레벨 * 100 또는 고정값으로 계산
        final maxHP = userGameInfo.level * 100;
        // maxXP는 보통 레벨 * 100 또는 고정값으로 계산
        final maxXP = userGameInfo.level * 100;
        
        final result = {
          'currentHP': userGameInfo.hp,
          'maxHP': maxHP,
          'currentXP': userGameInfo.exp,
          'maxXP': maxXP,
          'gold': userGameInfo.gold,
          'gender': 'male', // 기본값 (API 응답에 없으면 기본값 사용)
          'atk': userGameInfo.atk,
          'def': userGameInfo.def,
          'inventory': inventory ?? {},
        };
        
        print('변환된 인벤토리 데이터: $result');
        return result;
      }
    }
    return null;
  } catch (e) {
    print('사용자 인벤토리 조회 오류: $e');
    return null;
  }
}

// 아이템 이미지 경로 반환
String getItemImagePath(String itemId) {
  // 갑옷 이미지
  final armorImages = {
    'leather_armor': 'assets/images/Leather_Armor.png',
    'silver_armor': 'assets/images/SilverArmor.png',
    'gold_armor': 'assets/images/GoldArmor.png',
  };

  // 무기 이미지
  final weaponImages = {
    'wooden_sword': 'assets/images/wooden_sword.png',
    'silver_sword': 'assets/images/silver_sword.png',
    'gold_sword': 'assets/images/golden_sword.png',
  };

  // 포션 이미지
  final potionImages = {
    'magic_potion': 'assets/images/MagicPotion.png',
  };

  if (armorImages.containsKey(itemId)) {
    return armorImages[itemId]!;
  } else if (weaponImages.containsKey(itemId)) {
    return weaponImages[itemId]!;
  } else if (potionImages.containsKey(itemId)) {
    return potionImages[itemId]!;
  }

  // 기본값
  return 'assets/images/Leather_Armor.png';
}

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  int? currentUserDbId;
  bool isLoading = false;
  Map<String, dynamic>? userInventory;
  List<InventoryItem> inventoryItems = [];

  // 사용자 정보
  int currentHP = 85;
  int maxHP = 100;
  int currentXP = 45;
  int maxXP = 100;
  int gold = 0;
  String gender = 'male';
  String? armorId;
  String? weaponId;
  String? petId;
  int atk = 0; // 공격력
  int def = 0; // 방어력

  // 3x3 그리드용 아이템 목록 (사용자가 소유한 모든 아이템)
  List<InventoryItem> ownedArmors = [];
  List<InventoryItem> ownedWeapons = [];
  List<InventoryItem> ownedPets = [];
  List<InventoryItem> ownedPotions = [];

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDbId = prefs.getInt('userDbId');
      
      if (userDbId == null) {
        print('⚠️ 로그인한 사용자 DB ID가 없습니다.');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('로그인이 필요합니다.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      print('✅ 로그인한 사용자 DB ID: $userDbId');
      setState(() {
        currentUserDbId = userDbId;
      });
      await _loadUserInventory();
    } catch (e) {
      print('❌ 사용자 ID 가져오기 실패: $e');
    }
  }

  Future<void> _loadUserInventory() async {
    if (currentUserDbId == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      final inventory = await fetchUserInventory(currentUserDbId!);
      if (inventory != null && mounted) {
        setState(() {
          userInventory = inventory;
          _processInventoryItems();
        });
      }
    } catch (e) {
      print('사용자 인벤토리 로드 오류: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // 포션 사용 API 호출
  Future<bool> _usePotion() async {
    if (currentUserDbId == null) {
      print('❌ 사용자 ID가 없습니다.');
      return false;
    }

    try {
      print('포션 사용 요청 시작: userId=$currentUserDbId');
      final url = ApiConfig.usePotionEndpoint(currentUserDbId!);
      print('포션 사용 URL: $url');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      print('포션 사용 응답 상태: ${response.statusCode}');
      print('포션 사용 응답 본문: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true) {
          print('✅ 포션 사용 성공');
          return true;
        } else {
          print('❌ 포션 사용 실패: ${data['message']}');
          return false;
        }
      } else {
        print('❌ 포션 사용 실패: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ 포션 사용 오류: $e');
      return false;
    }
  }

  // 포션 사용 확인 다이얼로그
  Future<void> _showPotionUseDialog(InventoryItem potionItem) async {
    if (potionItem.quantity <= 0) {
      // 포션이 없으면 다이얼로그 표시 안 함
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 400,
            height: 200,
            child: Stack(
              children: [
                // StoreItemFrame_row.png 배경
                Image.asset(
                  'assets/images/StoreItemFrame_row.png',
                  width: 400,
                  height: 200,
                  fit: BoxFit.contain,
                ),
                // 내용
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '포션을 사용하시겠습니까?',
                        style: TextStyle(
                          fontFamily: 'DungGeunMo',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                          decoration: TextDecoration.none,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop(false);
                            },
                            child: Text(
                              '아니오',
                              style: TextStyle(
                                fontFamily: 'DungGeunMo',
                                fontSize: 18,
                                color: Colors.black,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop(true);
                            },
                            child: Text(
                              '예',
                              style: TextStyle(
                                fontFamily: 'DungGeunMo',
                                fontSize: 18,
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result == true) {
      // 예를 클릭한 경우
      SoundManager().playClick();
      final success = await _usePotion();
      
      if (success) {
        // 포션 사용 성공 - 인벤토리 새로고침
        await _loadUserInventory();
        
        // 성공 메시지 표시 (Quest_TimeInput.png 배경)
        if (mounted) {
          _showPotionSuccessDialog();
        }
      } else {
        // 포션 사용 실패
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '포션 사용에 실패했습니다. 포션이 부족할 수 있습니다.',
                style: TextStyle(
                  fontFamily: 'DungGeunMo',
                  decoration: TextDecoration.none,
                ),
              ),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  // 포션 사용 성공 다이얼로그 (Quest_TimeInput.png 배경)
  void _showPotionSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GestureDetector(
            onTap: () {
              Navigator.of(context).pop();
            },
            child: Container(
              width: 400,
              height: 150,
              child: Stack(
                children: [
                  // Quest_TimeInput.png 배경
                  Image.asset(
                    'assets/images/Quest_TimeInput.png',
                    width: 400,
                    height: 150,
                    fit: BoxFit.contain,
                  ),
                  // 텍스트
                  Center(
                    child: Text(
                      '체력이 30 회복되었습니다.',
                      style: TextStyle(
                        fontFamily: 'DungGeunMo',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                        decoration: TextDecoration.none,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }


  void _processInventoryItems() {
    if (userInventory == null) return;

    // 사용자 기본 정보 업데이트
    setState(() {
      currentHP = userInventory!['currentHP'] ?? 0;
      maxHP = userInventory!['maxHP'] ?? 100;
      currentXP = userInventory!['currentXP'] ?? 0;
      maxXP = userInventory!['maxXP'] ?? 100;
      gold = userInventory!['gold'] ?? 0;
      gender = userInventory!['gender'] ?? 'male';
      atk = userInventory!['atk'] ?? 0;
      def = userInventory!['def'] ?? 0;
    });

    final inventory = userInventory!['inventory'];
    inventoryItems.clear();
    ownedArmors.clear();
    ownedWeapons.clear();
    ownedPets.clear();
    ownedPotions.clear();

    // 장착된 갑옷 ID 확인 (백엔드 구조에 따라 여러 형식 지원)
    // 형식 1: equippedArmor (새로운 백엔드 구조)
    // 형식 2: armor (구형식)
    // 형식 3: armor_id (ID만)
    String? equippedArmorId;
    if (inventory?['equippedArmor'] != null) {
      final armor = inventory['equippedArmor'];
      if (armor is Map<String, dynamic>) {
        equippedArmorId = armor['itemId'] ?? armor['id'];
        setState(() {
          armorId = equippedArmorId;
        });
      }
    } else if (inventory?['armor'] != null) {
      final armor = inventory['armor'];
      if (armor is Map<String, dynamic>) {
        equippedArmorId = armor['itemId'] ?? armor['id'];
        setState(() {
          armorId = equippedArmorId;
        });
      }
    } else if (inventory?['armor_id'] != null) {
      equippedArmorId = inventory['armor_id'];
      setState(() {
        armorId = equippedArmorId;
      });
    }

    // 장착된 무기 ID 확인 (백엔드 구조에 따라 여러 형식 지원)
    // 형식 1: equippedWeapon (새로운 백엔드 구조)
    // 형식 2: weapon (구형식)
    // 형식 3: weapon_id (ID만)
    String? equippedWeaponId;
    if (inventory?['equippedWeapon'] != null) {
      final weapon = inventory['equippedWeapon'];
      if (weapon is Map<String, dynamic>) {
        equippedWeaponId = weapon['itemId'] ?? weapon['id'];
        setState(() {
          weaponId = equippedWeaponId;
        });
      }
    } else if (inventory?['weapon'] != null) {
      final weapon = inventory['weapon'];
      if (weapon is Map<String, dynamic>) {
        equippedWeaponId = weapon['itemId'] ?? weapon['id'];
        setState(() {
          weaponId = equippedWeaponId;
        });
      }
    } else if (inventory?['weapon_id'] != null) {
      equippedWeaponId = inventory['weapon_id'];
      setState(() {
        weaponId = equippedWeaponId;
      });
    }

    // 펫 정보 (착용 아이템이므로 inventoryItems에 추가하지 않음)
    if (inventory?['pets'] != null) {
      final pets = inventory['pets'];
      if (pets is List && pets.isNotEmpty) {
        final pet = pets[0];
        if (pet is Map<String, dynamic>) {
          setState(() {
            petId = pet['itemId'] ?? pet['id'];
          });
        } else {
          setState(() {
            petId = pet.toString();
          });
        }
      }
    } else if (inventory?['pet'] != null) {
      final pet = inventory['pet'];
      if (pet is Map<String, dynamic>) {
        setState(() {
          petId = pet['itemId'] ?? pet['id'];
        });
      }
    }

    // 구매한 아이템들 처리
    // 백엔드 구조: armors, weapons 배열과 items 배열을 모두 확인
    List<dynamic> allItems = [];

    // armors 배열 처리 (모든 갑옷 수집 - 3x3 그리드용)
    if (inventory?['armors'] != null && inventory['armors'] is List) {
      final armors = inventory['armors'] as List<dynamic>;
      for (var armor in armors) {
        if (armor is Map<String, dynamic>) {
          final itemId = armor['itemId'] ?? armor['id'];
          if (itemId != null) {
            final armorItem = InventoryItem(
              itemId: itemId,
              name: armor['name'] ?? '',
              description: armor['description'] ?? '',
              itemType: 'ARMOR',
              quantity: 1,
              stats: {
                'defense': armor['statValue'] ?? armor['def'] ?? 0,
              },
            );
            ownedArmors.add(armorItem);
            
            // 장착되지 않은 갑옷만 inventoryItems에 추가
            if (itemId != equippedArmorId) {
              allItems.add({
                'itemId': itemId,
                'name': armor['name'] ?? '',
                'description': armor['description'] ?? '',
                'itemType': 'ARMOR',
                'quantity': 1,
                'stats': {
                  'defense': armor['statValue'] ?? armor['def'] ?? 0,
                },
              });
            }
          }
        }
      }
    }
    
    // 장착된 갑옷도 ownedArmors에 추가 (armors 배열에 없는 경우)
    if (equippedArmorId != null) {
      bool hasEquippedArmor = ownedArmors.any((a) => a.itemId == equippedArmorId);
      if (!hasEquippedArmor) {
        // 장착된 갑옷 정보를 inventory에서 찾기
        Map<String, dynamic>? equippedArmorData;
        if (inventory?['equippedArmor'] != null && inventory['equippedArmor'] is Map) {
          equippedArmorData = inventory['equippedArmor'] as Map<String, dynamic>;
        } else if (inventory?['armor'] != null && inventory['armor'] is Map) {
          equippedArmorData = inventory['armor'] as Map<String, dynamic>;
        }
        
        if (equippedArmorData != null) {
          ownedArmors.add(InventoryItem(
            itemId: equippedArmorId,
            name: equippedArmorData['name'] ?? '',
            description: equippedArmorData['description'] ?? '',
            itemType: 'ARMOR',
            quantity: 1,
            stats: {
              'defense': equippedArmorData['statValue'] ?? equippedArmorData['def'] ?? 0,
            },
          ));
        }
      }
    }

    // weapons 배열 처리 (모든 무기 수집 - 3x3 그리드용)
    if (inventory?['weapons'] != null && inventory['weapons'] is List) {
      final weapons = inventory['weapons'] as List<dynamic>;
      for (var weapon in weapons) {
        if (weapon is Map<String, dynamic>) {
          final itemId = weapon['itemId'] ?? weapon['id'];
          if (itemId != null) {
            final weaponItem = InventoryItem(
              itemId: itemId,
              name: weapon['name'] ?? '',
              description: weapon['description'] ?? '',
              itemType: 'WEAPON',
              quantity: 1,
              stats: {
                'attack': weapon['statValue'] ?? weapon['atk'] ?? 0,
              },
            );
            ownedWeapons.add(weaponItem);
            
            // 장착되지 않은 무기만 inventoryItems에 추가
            if (itemId != equippedWeaponId) {
              allItems.add({
                'itemId': itemId,
                'name': weapon['name'] ?? '',
                'description': weapon['description'] ?? '',
                'itemType': 'WEAPON',
                'quantity': 1,
                'stats': {
                  'attack': weapon['statValue'] ?? weapon['atk'] ?? 0,
                },
              });
            }
          }
        }
      }
    }
    
    // 장착된 무기도 ownedWeapons에 추가 (weapons 배열에 없는 경우)
    if (equippedWeaponId != null) {
      bool hasEquippedWeapon = ownedWeapons.any((w) => w.itemId == equippedWeaponId);
      if (!hasEquippedWeapon) {
        // 장착된 무기 정보를 inventory에서 찾기
        Map<String, dynamic>? equippedWeaponData;
        if (inventory?['equippedWeapon'] != null && inventory['equippedWeapon'] is Map) {
          equippedWeaponData = inventory['equippedWeapon'] as Map<String, dynamic>;
        } else if (inventory?['weapon'] != null && inventory['weapon'] is Map) {
          equippedWeaponData = inventory['weapon'] as Map<String, dynamic>;
        }
        
        if (equippedWeaponData != null) {
          ownedWeapons.add(InventoryItem(
            itemId: equippedWeaponId,
            name: equippedWeaponData['name'] ?? '',
            description: equippedWeaponData['description'] ?? '',
            itemType: 'WEAPON',
            quantity: 1,
            stats: {
              'attack': equippedWeaponData['statValue'] ?? equippedWeaponData['atk'] ?? 0,
            },
          ));
        }
      }
    }

    // items 배열 처리 (기존 형식 지원)
    if (inventory?['items'] != null && inventory['items'] is List) {
      final items = inventory['items'] as List<dynamic>;
      for (var item in items) {
        if (item is Map<String, dynamic>) {
          final itemData = InventoryItem.fromJson(item);
          final itemId = itemData.itemId;
          final itemType = itemData.itemType.toUpperCase();

          // 갑옷, 무기, 펫, 포션을 3x3 그리드용 리스트에 추가
          if (itemType == 'ARMOR') {
            if (!ownedArmors.any((a) => a.itemId == itemId)) {
              ownedArmors.add(itemData);
            }
          } else if (itemType == 'WEAPON') {
            if (!ownedWeapons.any((w) => w.itemId == itemId)) {
              ownedWeapons.add(itemData);
            }
          } else if (itemType == 'PET') {
            if (!ownedPets.any((p) => p.itemId == itemId)) {
              ownedPets.add(itemData);
            }
          } else if (itemType == 'POTION') {
            // 포션은 quantity가 0보다 큰 경우만 추가
            if (itemData.quantity > 0 && !ownedPotions.any((p) => p.itemId == itemId)) {
              ownedPotions.add(itemData);
            }
          }

          // 장착된 갑옷이나 무기와 같은 itemId면 제외
          if (itemId == equippedArmorId || itemId == equippedWeaponId) {
            continue;
          }

          // 포션의 경우 quantity가 0보다 큰 경우만 추가
          if (itemType == 'POTION' && itemData.quantity <= 0) {
            continue;
          }

          allItems.add(item);
        }
      }
    }
    
    // 펫 정보를 ownedPets에 추가
    // pets 배열에서 모든 펫 수집
    if (inventory?['pets'] != null && inventory['pets'] is List) {
      final pets = inventory['pets'] as List<dynamic>;
      for (var pet in pets) {
        if (pet is Map<String, dynamic>) {
          final petItemId = pet['itemId'] ?? pet['id'];
          if (petItemId != null && !ownedPets.any((p) => p.itemId == petItemId)) {
            ownedPets.add(InventoryItem(
              itemId: petItemId,
              name: pet['name'] ?? '',
              description: pet['description'] ?? '',
              itemType: 'PET',
              quantity: 1,
            ));
            print('✅ 펫 추가: itemId=$petItemId');
          }
        }
      }
    } else if (inventory?['pet'] != null) {
      final pet = inventory['pet'];
      if (pet is Map<String, dynamic>) {
        final petItemId = pet['itemId'] ?? pet['id'] ?? petId;
        if (petItemId != null && !ownedPets.any((p) => p.itemId == petItemId)) {
          ownedPets.add(InventoryItem(
            itemId: petItemId,
            name: pet['name'] ?? '',
            description: pet['description'] ?? '',
            itemType: 'PET',
            quantity: 1,
          ));
          print('✅ 펫 추가: itemId=$petItemId');
        }
      }
    }
    
    // petId가 있지만 아직 ownedPets에 없는 경우 추가
    if (petId != null && !ownedPets.any((p) => p.itemId == petId)) {
      ownedPets.add(InventoryItem(
        itemId: petId!,
        name: petId!,
        description: '',
        itemType: 'PET',
        quantity: 1,
      ));
      print('✅ 펫 추가 (기본): itemId=$petId');
    }

    // 모든 아이템을 inventoryItems에 추가
    for (var item in allItems) {
      try {
        final itemData = InventoryItem.fromJson(item);
        inventoryItems.add(itemData);
      } catch (e) {
        print('아이템 파싱 오류: $e, item: $item');
      }
    }

    // 백엔드의 potions 필드가 있고 items 배열에 포션이 없는 경우 처리
    if (inventory?['potions'] != null &&
        inventory?['potions'] is int &&
        (inventory?['potions'] as int) > 0) {
      // items 배열에 이미 포션이 있는지 확인
      bool hasPotion = false;
      for (var item in inventoryItems) {
        if (item.itemType.toUpperCase() == 'POTION' && item.itemId == 'magic_potion') {
          hasPotion = true;
          break;
        }
      }

      // items 배열에 포션이 없으면 백엔드의 potions 필드로 추가
      if (!hasPotion) {
        final potionItem = InventoryItem(
          itemId: 'magic_potion',
          name: 'Magic Potion',
          description: '마법 포션',
          itemType: 'POTION',
          quantity: inventory['potions'] as int,
          stats: {'heal': 50},
        );
        inventoryItems.add(potionItem);
        // 3x3 그리드용 포션 리스트에도 추가
        if (!ownedPotions.any((p) => p.itemId == 'magic_potion')) {
          ownedPotions.add(potionItem);
        }
      }
    }
    
    // inventoryItems에 있는 포션도 ownedPotions에 추가 (누락 방지)
    for (var item in inventoryItems) {
      if (item.itemType.toUpperCase() == 'POTION' && 
          item.quantity > 0 && 
          !ownedPotions.any((p) => p.itemId == item.itemId)) {
        ownedPotions.add(item);
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
                const SizedBox(height: 20), // 상단 여백 추가 (Shop과 동일)
                // 상단 제목 영역 (Shop, MyPage와 동일한 스타일)
                _buildTopTitleSection(context),

                const SizedBox(height: 60), // 그리드 패널을 아래로 이동
                // 인벤토리 패널들
                Expanded(
                  child: isLoading
                      ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : _buildInventoryPanels(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // HP바 이미지 경로 반환 (현재 HP에 따라)
  String getHPBarImagePath() {
    if (maxHP == 0) return 'assets/images/Icon_HpXp_EmptyBar.png';

    double hpRatio = currentHP / maxHP;
    int barLevel = (hpRatio * 10).ceil();
    barLevel = barLevel.clamp(1, 10);

    return 'assets/images/Icon_HPBar_$barLevel.png';
  }

  // XP바 이미지 경로 반환 (현재 XP에 따라)
  String getXPBarImagePath() {
    if (maxXP == 0) return 'assets/images/Icon_HpXp_EmptyBar.png';

    double xpRatio = currentXP / maxXP;
    int barLevel = (xpRatio * 10).ceil();
    barLevel = barLevel.clamp(1, 10);

    return 'assets/images/Icon_XpBar_$barLevel.png';
  }

  // 캐릭터 이미지 경로 반환 (성별에 따라)
  String getCharacterImagePath() {
    return gender == 'female'
        ? 'assets/images/Female_Character.png'
        : 'assets/images/MaleCharacter.png';
  }

  // 갑옷 이미지 경로 반환
  String getArmorImagePath() {
    if (armorId == null) return '';

    final armorImages = {
      'leather_armor': 'assets/images/Leather_Armor.png',
      'silver_armor': 'assets/images/SilverArmor.png',
      'gold_armor': 'assets/images/GoldArmor.png',
    };

    return armorImages[armorId!] ?? '';
  }

  // 무기 이미지 경로 반환
  String getWeaponImagePath() {
    if (weaponId == null) return '';

    final weaponImages = {
      'wooden_sword': 'assets/images/wooden_sword.png',
      'silver_sword': 'assets/images/silver_sword.png',
      'gold_sword': 'assets/images/golden_sword.png',
    };

    return weaponImages[weaponId!] ?? '';
  }

  // 펫 이미지 경로 반환
  String getPetImagePath() {
    if (petId == null) return '';

    final petImages = {
      'cat': 'assets/images/Pet_Cat.png',
      'dog': 'assets/images/Pet_Dog.png',
      'rabbit': 'assets/images/Pet_Rabbit.png',
    };

    return petImages[petId!] ?? '';
  }

  // 인벤토리 아이템 이미지 경로 반환
  String _getItemImagePath(String itemId, String itemType) {
    // itemId를 소문자로 변환하여 대소문자 구분 없이 매칭
    final normalizedItemId = itemId.toLowerCase().trim();
    
    final itemImages = {
      // 갑옷
      'starting_armor': 'assets/images/BasicClothes.png',
      'gold_armor': 'assets/images/GoldArmor.png',
      'silver_armor': 'assets/images/SilverArmor.png',
      'leather_armor': 'assets/images/Leather_Armor.png',

      // 무기
      'starting_weapon': 'assets/images/WoodenStick.png',
      'wooden_sword': 'assets/images/wooden_sword.png',
      'wood_sword': 'assets/images/wooden_sword.png', // 변형
      'silver_sword': 'assets/images/sliver_sword.png',
      'gold_sword': 'assets/images/golden_sword.png',
      'golden_sword': 'assets/images/golden_sword.png', // 변형

      // 펫
      'cat': 'assets/images/Pet_Cat.png',
      'dog': 'assets/images/Pet_Dog.png',
      'rabbit': 'assets/images/Pet_Rabbit.png',
      'pet_cat': 'assets/images/Pet_Cat.png', // 변형
      'pet_dog': 'assets/images/Pet_Dog.png', // 변형
      'pet_rabbit': 'assets/images/Pet_Rabbit.png', // 변형
      'pet_cute': 'assets/images/Pet_Cat.png', // 귀여운 펫 (기본적으로 Cat 사용)

      // 포션
      'magic_potion': 'assets/images/MagicPotion.png',
      'potion': 'assets/images/MagicPotion.png', // 변형
    };

    final imagePath = itemImages[normalizedItemId];
    
    // 기본 이미지가 없으면 itemType에 따라 기본 이미지 반환
    if (imagePath == null) {
      // 디버깅: itemId가 매핑되지 않은 경우 로그 출력
      print('⚠️ 이미지 경로를 찾을 수 없음: itemId=$itemId (normalized=$normalizedItemId), itemType=$itemType');
      
      final itemTypeUpper = itemType.toUpperCase();
      if (itemTypeUpper == 'WEAPON') {
        return 'assets/images/wooden_sword.png'; // 기본 무기
      } else if (itemTypeUpper == 'PET') {
        return 'assets/images/Pet_Cat.png'; // 기본 펫
      } else if (itemTypeUpper == 'ARMOR') {
        return 'assets/images/Leather_Armor.png'; // 기본 갑옷
      } else if (itemTypeUpper == 'POTION') {
        return 'assets/images/MagicPotion.png'; // 기본 포션
      }
      
      // 최종 기본값
      return 'assets/images/Leather_Armor.png';
    }
    
    return imagePath;
  }

  // 3x3 그리드에 아이템 배치 (왼쪽부터 갑옷, 무기, 펫 세로줄)
  // 각 네모칸의 정확한 위치에 아이템 배치 (사용자 인벤토리 데이터 기반)
  List<Widget> _build3x3GridItems(double panelWidth, double panelHeight) {
    // 디버깅: 현재 수집된 아이템 목록 출력
    print('📦 3x3 그리드 아이템 수집:');
    print('   갑옷: ${ownedArmors.map((a) => a.itemId).toList()}');
    print('   무기: ${ownedWeapons.map((w) => w.itemId).toList()}');
    print('   펫: ${ownedPets.map((p) => p.itemId).toList()}');
    print('   포션: ${ownedPotions.map((p) => p.itemId).toList()}');
    
    List<Widget> items = [];

    // 패널의 패딩을 고려한 실제 그리드 영역 계산
    // 일반적으로 이미지 가장자리에 약간의 패딩이 있으므로 약 5% 정도 여백 고려
    final padding = 0.05; // 5% 패딩
    final gridStartX = panelWidth * padding;
    final gridStartY = panelHeight * padding;
    final gridWidth = panelWidth * (1 - padding * 2);
    final gridHeight = panelHeight * (1 - padding * 2);

    // 3x3 그리드 셀 크기 계산
    final cellWidth = gridWidth / 3;
    final cellHeight = gridHeight / 3;

    // 아이템 크기
    const itemSize = 45.0;
    const itemHalfSize = itemSize / 2; // 22.5

    // 각 네모칸의 중심 위치 계산
    // 맨 밑줄(3행) 아이템은 위치를 조금 올리기 위한 오프셋
    const bottomRowOffset = -8.0; // 밑줄 아이템을 8px 올림

    // 1열: 갑옷 (왼쪽 세로줄) - 사용자가 소유한 갑옷들 (최대 3개)
    for (int row = 0; row < 3 && row < ownedArmors.length; row++) {
      final armor = ownedArmors[row];
      final cellCenterX = gridStartX + cellWidth * 0.5; // 첫 번째 열 중심
      final cellCenterY = gridStartY + cellHeight * (row + 0.5); // 각 행의 중심
      final offsetY = row == 2 ? bottomRowOffset : 0.0; // 맨 밑줄만 오프셋 적용

      items.add(
        Positioned(
          left: cellCenterX - itemHalfSize, // 셀 중심 - 아이템 크기/2
          top: cellCenterY - itemHalfSize + offsetY,
          width: itemSize,
          height: itemSize,
          child: Image.asset(
            _getItemImagePath(armor.itemId, 'ARMOR'),
            width: itemSize,
            height: itemSize,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              // 이미지 로드 실패 시 빈 컨테이너
              return Container(
                width: itemSize,
                height: itemSize,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  border: Border.all(color: Colors.grey, width: 1),
                ),
              );
            },
          ),
        ),
      );
    }

    // 2열: 무기 (가운데 세로줄) - 사용자가 소유한 무기들 (최대 3개)
    for (int row = 0; row < 3 && row < ownedWeapons.length; row++) {
      final weapon = ownedWeapons[row];
      final cellCenterX = gridStartX + cellWidth * 1.5; // 두 번째 열 중심
      final cellCenterY = gridStartY + cellHeight * (row + 0.5); // 각 행의 중심
      final offsetY = row == 2 ? bottomRowOffset : 0.0; // 맨 밑줄만 오프셋 적용

      items.add(
        Positioned(
          left: cellCenterX - itemHalfSize, // 셀 중심 - 아이템 크기/2
          top: cellCenterY - itemHalfSize + offsetY,
          width: itemSize,
          height: itemSize,
          child: Image.asset(
            _getItemImagePath(weapon.itemId, 'WEAPON'),
            width: itemSize,
            height: itemSize,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              // 이미지 로드 실패 시 디버깅 정보와 함께 빈 컨테이너
              print('❌ 무기 이미지 로드 실패: itemId=${weapon.itemId}, 경로=${_getItemImagePath(weapon.itemId, "WEAPON")}, 오류: $error');
              return Container(
                width: itemSize,
                height: itemSize,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  border: Border.all(color: Colors.red, width: 2),
                ),
                child: Center(
                  child: Text(
                    weapon.itemId.length > 8 ? '${weapon.itemId.substring(0, 8)}...' : weapon.itemId,
                    style: TextStyle(fontSize: 8, color: Colors.red),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    // 3열: 포션과 펫 (오른쪽 세로줄) - 포션을 우선 표시하고, 포션이 없으면 펫 표시
    // 포션과 펫을 합쳐서 최대 3개까지 표시
    List<InventoryItem> thirdColumnItems = [];
    
    // 포션을 먼저 추가 (최대 3개)
    for (int i = 0; i < ownedPotions.length && thirdColumnItems.length < 3; i++) {
      thirdColumnItems.add(ownedPotions[i]);
    }
    
    // 포션이 3개 미만이면 펫 추가
    for (int i = 0; i < ownedPets.length && thirdColumnItems.length < 3; i++) {
      thirdColumnItems.add(ownedPets[i]);
    }
    
    // 3열 아이템 배치
    for (int row = 0; row < 3 && row < thirdColumnItems.length; row++) {
      final item = thirdColumnItems[row];
      final cellCenterX = gridStartX + cellWidth * 2.5; // 세 번째 열 중심
      final cellCenterY = gridStartY + cellHeight * (row + 0.5); // 각 행의 중심
      final offsetY = row == 2 ? bottomRowOffset : 0.0; // 맨 밑줄만 오프셋 적용
      
      // 아이템 타입에 따라 이미지 경로 결정
      final itemType = item.itemType.toUpperCase();
      final imagePath = _getItemImagePath(item.itemId, itemType);

      items.add(
        Positioned(
          left: cellCenterX - itemHalfSize, // 셀 중심 - 아이템 크기/2
          top: cellCenterY - itemHalfSize + offsetY,
          width: itemSize,
          height: itemSize,
          child: GestureDetector(
            onTap: () {
              SoundManager().playClick();
              // 포션인 경우 사용 다이얼로그 표시
              if (itemType == 'POTION') {
                _showPotionUseDialog(item);
              }
            },
            child: Stack(
              children: [
                Image.asset(
                  imagePath,
                  width: itemSize,
                  height: itemSize,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    // 이미지 로드 실패 시 디버깅 정보와 함께 빈 컨테이너
                    print('❌ 3열 아이템 이미지 로드 실패: itemId=${item.itemId}, 타입=$itemType, 경로=$imagePath, 오류: $error');
                    return Container(
                      width: itemSize,
                      height: itemSize,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        border: Border.all(color: Colors.red, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          item.itemId.length > 8 ? '${item.itemId.substring(0, 8)}...' : item.itemId,
                          style: TextStyle(fontSize: 8, color: Colors.red),
                        ),
                      ),
                    );
                  },
                ),
                // 포션의 경우 수량 표시 (1개 이상일 때, 1개도 표시)
                if (itemType == 'POTION' && item.quantity >= 1)
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${item.quantity}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontFamily: 'DungGeunMo',
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return items;
  }

  Widget _buildTopTitleSection(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // 뒤로가기 버튼 (왼쪽)
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: GestureDetector(
            onTap: () {
              SoundManager().playClick();
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
        // Inventory 제목과 골드 표시 (가운데)
        Column(
          children: [
            Text(
              'Inventory',
              style: TextStyle(
                fontSize: 48,  // Shop과 동일한 크기
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
                  width: 30,
                  height: 30,
                ),
                const SizedBox(width: 4),
                Text(
                  gold.toString(),
                  style: TextStyle(
                    fontSize: 30,
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
        SizedBox(width: 48), // 뒤로가기 버튼과 같은 너비
      ],
    );
  }

  Widget _buildInventoryPanels() {
    return Column(
      children: [
        // inventory_3x3.png 패널 - 위쪽 (세로 높이 증가)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final panelWidth = constraints.maxWidth;
              final panelHeight = 320.0;

              return Container(
                width: double.infinity,
                height: panelHeight,
                child: Stack(
                  children: [
                    // 배경 이미지
                    Positioned.fill(
                      child: Image.asset(
                        'assets/images/inventory_3x3.png',
                        fit: BoxFit.fill,
                      ),
                    ),
                    // 3x3 그리드에 아이템 배치
                    ..._build3x3GridItems(panelWidth, panelHeight),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 15),
        // Inventory_2.png 패널과 3개 작은 네모 박스 - 아래쪽
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Container(
            width: double.infinity,
            height: 160,
            child: Stack(
              children: [
                // 배경 이미지
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/Inventory_2.png',
                    fit: BoxFit.fill,
                  ),
                ),
                // "Items" 제목
                Positioned(
                  top: 15,
                  left: 25,
                  child: Text(
                    'Items',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 30,
                      fontFamily: 'DungGeunMo',
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
                // 3개 작은 네모 박스에 구매 아이템 배치 (프레임 중앙)
                Positioned(
                  bottom: 30,
                  left: 0,
                  right: 0,
                  child: _buildPurchasedItemsInBoxes(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEquippedItemsInBoxes() {
    // 착용 아이템들을 3개 박스에 배치 (갑옷, 무기, 펫)
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // 첫 번째 박스 (갑옷)
        Container(
          width: 85,
          height: 85,
          child: armorId != null
              ? _buildEquippedItemForBox(getArmorImagePath())
              : Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
            ),
          ),
        ),
        // 두 번째 박스 (무기)
        Container(
          width: 85,
          height: 85,
          child: weaponId != null
              ? _buildEquippedItemForBox(getWeaponImagePath())
              : Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
            ),
          ),
        ),
        // 세 번째 박스 (펫)
        Container(
          width: 85,
          height: 85,
          child: petId != null
              ? _buildEquippedItemForBox(getPetImagePath())
              : Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEquippedItemForBox(String imagePath) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(),
      clipBehavior: Clip.hardEdge,
      alignment: Alignment(0.1, 0.85),
      child: Image.asset(
        imagePath,
        width: 42,
        height: 42,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildPurchasedItemsInBoxes() {
    // 구매한 아이템들을 3개 박스에 배치 (갑옷, 무기, 포션)
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // 첫 번째 박스 (갑옷: gold_armor, silver_armor, leather_armor만)
        Container(
          width: 65,
          height: 65,
          decoration: BoxDecoration(),
          clipBehavior: Clip.hardEdge,
          child: _getPurchasedArmor(),
        ),
        // 두 번째 박스 (무기: gold_sword, silver_sword, wooden_sword만)
        Container(
          width: 65,
          height: 65,
          decoration: BoxDecoration(),
          clipBehavior: Clip.hardEdge,
          child: _getPurchasedWeapon(),
        ),
        // 세 번째 박스 (포션: magic_potion만)
        Container(
          width: 65,
          height: 65,
          decoration: BoxDecoration(),
          clipBehavior: Clip.hardEdge,
          child: _getPurchasedPotion(),
        ),
      ],
    );
  }

  Widget _getPurchasedArmor() {
    // 갑옷 아이템만 찾기 (gold_armor, silver_armor, leather_armor)
    // 단, 현재 장착된 갑옷은 제외 (장착된 아이템은 빈 칸으로 표시)
    final allowedArmors = ['gold_armor', 'silver_armor', 'leather_armor'];
    for (var item in inventoryItems) {
      if (item.itemType.toUpperCase() == 'ARMOR' &&
          allowedArmors.contains(item.itemId) &&
          item.itemId != armorId) { // 장착된 갑옷이 아닌 경우만 표시
        return _buildPurchasedItemForBox(item, isArmor: true);
      }
    }
    // 해당 타입의 아이템이 없거나 장착되어 있으면 빈 박스
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
      ),
    );
  }

  Widget _getPurchasedWeapon() {
    // 무기 아이템만 찾기 (gold_sword, silver_sword, wooden_sword)
    // 단, 현재 장착된 무기는 제외 (장착된 아이템은 빈 칸으로 표시)
    final allowedWeapons = ['gold_sword', 'silver_sword', 'wooden_sword'];
    for (var item in inventoryItems) {
      if (item.itemType.toUpperCase() == 'WEAPON' &&
          allowedWeapons.contains(item.itemId) &&
          item.itemId != weaponId) { // 장착된 무기가 아닌 경우만 표시
        return _buildPurchasedItemForBox(item);
      }
    }
    // 해당 타입의 아이템이 없거나 장착되어 있으면 빈 박스
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
      ),
    );
  }

  Widget _getPurchasedPotion() {
    // 포션 아이템만 찾기 (magic_potion만)
    // quantity가 0보다 큰 경우만 표시 (사용한 포션은 제외)
    for (var item in inventoryItems) {
      if (item.itemType.toUpperCase() == 'POTION' &&
          item.itemId == 'magic_potion' &&
          item.quantity > 0) { // 남은 개수가 있는 경우만 표시
        return _buildPurchasedItemForBox(item);
      }
    }
    // 해당 타입의 아이템이 없거나 모두 사용되었으면 빈 박스
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
      ),
    );
  }

  Widget _buildPurchasedItemForBox(InventoryItem item, {bool isArmor = false}) {
    // 아이템 타입에 따라 크기 결정: 갑옷과 무기는 45x45, 포션은 40x40
    final isPotion = item.itemType.toUpperCase() == 'POTION';
    final itemSize = (isPotion) ? 40.0 : 45.0;

    return GestureDetector(
      onTap: () {
        SoundManager().playClick();
        // 포션인 경우 사용 다이얼로그 표시
        if (isPotion) {
          _showPotionUseDialog(item);
        }
      },
      child: Container(
        width: 65,
        height: 65,
        decoration: BoxDecoration(),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            // 아이템 이미지와 수량 배지를 그룹화하여 오른쪽으로 이동
            Positioned(
              left: isArmor ? 5 : 7,
              top: 0,
              right: 0,
              bottom: 0,
              child: Stack(
                children: [
                  // 아이템 이미지 (정중앙)
                  Center(
                    child: Image.asset(
                      _getItemImagePath(item.itemId, item.itemType),
                      width: itemSize,
                      height: itemSize,
                      fit: BoxFit.contain,
                    ),
                  ),
                  // 수량 표시 (1개 이상일 때, 포션은 1개도 표시)
                  if (item.quantity >= 1 && (isPotion || item.quantity > 1))
                    Positioned(
                      bottom: 5,
                      right: 5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${item.quantity}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontFamily: 'DungGeunMo',
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryItemsInBoxes() {
    if (inventoryItems.isEmpty) {
      return Center(
        child: Text(
          '인벤토리가 비어있습니다.',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 16,
            fontFamily: 'DungGeunMo',
            decoration: TextDecoration.none,
          ),
        ),
      );
    }

    // Inventory_2.png의 3개 작은 네모 박스 위치에 아이템 배치
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // 첫 번째 박스 (왼쪽)
        Container(
          width: 80,
          height: 80,
          child: inventoryItems.length > 0
              ? _buildInventoryItemForBox(inventoryItems[0])
              : Container(),
        ),
        // 두 번째 박스 (가운데)
        Container(
          width: 80,
          height: 80,
          child: inventoryItems.length > 1
              ? _buildInventoryItemForBox(inventoryItems[1])
              : Container(),
        ),
        // 세 번째 박스 (오른쪽)
        Container(
          width: 80,
          height: 80,
          child: inventoryItems.length > 2
              ? _buildInventoryItemForBox(inventoryItems[2])
              : Container(),
        ),
      ],
    );
  }

  Widget _buildInventoryItemForBox(InventoryItem item) {
    return Center(
      child: Stack(
        children: [
          // 아이템 이미지
          Image.asset(
            _getItemImagePath(item.itemId, item.itemType),
            width: 60,
            height: 60,
            fit: BoxFit.contain,
          ),
          // 수량 표시 (1개 이상일 때만)
          if (item.quantity > 1)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${item.quantity}',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontFamily: 'DungGeunMo',
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInventoryGrid() {
    if (inventoryItems.isEmpty) {
      return Center(
        child: Text(
          '인벤토리가 비어있습니다.',
          style: TextStyle(
            fontSize: 24,
            color: Colors.black,
            fontFamily: 'DungGeunMo',
            decoration: TextDecoration.none,
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: inventoryItems.length,
      itemBuilder: (context, index) {
        final item = inventoryItems[index];
        return _buildInventoryItem(item);
      },
    );
  }

  Widget _buildInventoryItem(InventoryItem item) {
    return GestureDetector(
      onTap: () {
        SoundManager().playClick();
        // 아이템 클릭 시 상세 정보 표시 (추후 구현)
        print('아이템 클릭: ${item.name}');
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.brown, width: 2),
          color: Colors.brown.shade100,
        ),
        child: Stack(
          children: [
            // 아이템 이미지
            Positioned(
              top: 15,
              left: 0,
              right: 0,
              child: Center(
                child: Image.asset(
                  getItemImagePath(item.itemId),
                  width: 60,
                  height: 60,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            // 아이템 이름
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                    fontFamily: 'DungGeunMo',
                    decoration: TextDecoration.none,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            // 수량 표시 (1개 이상인 경우)
            if (item.quantity > 1)
              Positioned(
                top: 5,
                right: 5,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    item.quantity.toString(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'DungGeunMo',
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

}
