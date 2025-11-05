import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'HomeScreen.dart';
import 'MyPageScreen.dart';
import 'shop.dart';

final baseUrl = 'http://192.168.219.110:8083';

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

// 사용자 인벤토리 조회 API (테스트용 모의 데이터)
Future<Map<String, dynamic>?> fetchUserInventory(String userId) async {
  try {
    print('사용자 인벤토리 정보 조회 시작: userId=$userId (모의 데이터)');
    
    // 네트워크 지연 시뮬레이션
    await Future.delayed(const Duration(milliseconds: 500));
    
    // 테스트용 모의 데이터
    final mockData = {
      'currentHP': 85,
      'maxHP': 100,
      'currentXP': 45,
      'maxXP': 100,
      'gold': 150,
      'gender': 'male',
      'atk': 25,
      'def': 15,
      'inventory': {
        'armor': {
          'id': 'leather_armor',
          'name': 'Leather Armor',
          'description': '가죽 갑옷',
          'stats': {
            'defense': 10,
            'level': 1,
          }
        },
        'weapon': {
          'id': 'wooden_sword',
          'name': 'Wooden Sword',
          'description': '나무 검',
          'stats': {
            'attack': 15,
            'level': 1,
          }
        },
        'pet': {
          'id': 'cat',
          'name': 'Cat',
          'description': '고양이 펫',
        },
        'items': [
          {
            'itemId': 'silver_armor',
            'name': 'Silver Armor',
            'description': '은 갑옷',
            'itemType': 'ARMOR',
            'quantity': 1,
            'stats': {
              'defense': 15,
              'level': 2,
            }
          },
          {
            'itemId': 'gold_sword',
            'name': 'Gold Sword',
            'description': '금 검',
            'itemType': 'WEAPON',
            'quantity': 1,
            'stats': {
              'attack': 25,
              'level': 3,
            }
          },
          {
            'itemId': 'magic_potion',
            'name': 'Magic Potion',
            'description': '마법 포션',
            'itemType': 'POTION',
            'quantity': 5,
            'stats': {
              'heal': 50,
            }
          }
        ]
      }
    };
    
    print('모의 인벤토리 데이터 반환: $mockData');
    return mockData;
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
  String? currentUserId;
  bool isLoading = false;
  Map<String, dynamic>? userInventory;
  List<InventoryItem> inventoryItems = [];
  
  // 사용자 정보
  int currentHP = 85;
  int maxHP = 100;
  int currentXP = 45;
  int maxXP = 100;
  int gold = 150;
  String gender = 'male'; // 'male' or 'female'
  String? armorId;
  String? weaponId;
  String? petId;
  int atk = 0; // 공격력
  int def = 0; // 방어력

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    // TODO: 실제 로그인된 사용자 ID로 변경 필요
    // 현재는 임시로 사용자 ID "1" 사용
    setState(() {
      currentUserId = "1";
    });
    await _loadUserInventory();
  }

  Future<void> _loadUserInventory() async {
    if (currentUserId == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      final inventory = await fetchUserInventory(currentUserId!);
      if (inventory != null) {
        setState(() {
          userInventory = inventory;
          _processInventoryItems();
        });
      }
    } catch (e) {
      print('사용자 인벤토리 로드 오류: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
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

    // 장착된 갑옷 ID 확인 (백엔드 구조에 따라 두 가지 형식 지원)
    // 형식 1: inventory['armor']['id'] 또는 형식 2: inventory['armor_id']
    String? equippedArmorId;
    if (inventory?['armor'] != null) {
      final armor = inventory['armor'];
      if (armor is Map<String, dynamic>) {
        equippedArmorId = armor['id'];
        setState(() {
          armorId = armor['id'];
        });
      }
    } else if (inventory?['armor_id'] != null) {
      equippedArmorId = inventory['armor_id'];
      setState(() {
        armorId = inventory['armor_id'];
      });
    }

    // 장착된 무기 ID 확인 (백엔드 구조에 따라 두 가지 형식 지원)
    // 형식 1: inventory['weapon']['id'] 또는 형식 2: inventory['weapon_id']
    String? equippedWeaponId;
    if (inventory?['weapon'] != null) {
      final weapon = inventory['weapon'];
      if (weapon is Map<String, dynamic>) {
        equippedWeaponId = weapon['id'];
        setState(() {
          weaponId = weapon['id'];
        });
      }
    } else if (inventory?['weapon_id'] != null) {
      equippedWeaponId = inventory['weapon_id'];
      setState(() {
        weaponId = inventory['weapon_id'];
      });
    }

    // 펫 정보 (착용 아이템이므로 inventoryItems에 추가하지 않음)
    if (inventory?['pet'] != null) {
      final pet = inventory['pet'];
      if (pet is Map<String, dynamic>) {
        setState(() {
          petId = pet['id'];
        });
      }
    } else if (inventory?['pets'] != null) {
      // 백엔드에서 pets가 JSON 문자열이나 배열로 올 수 있음
      final pets = inventory['pets'];
      if (pets is List && pets.isNotEmpty) {
        setState(() {
          petId = pets[0] is Map ? pets[0]['id'] : pets[0].toString();
        });
      }
    }

    // 구매한 아이템들만 inventoryItems에 추가 (포션 등)
    // 단, 장착된 아이템은 제외하고, 포션은 quantity > 0인 경우만 추가
    if (inventory?['items'] != null) {
      final items = inventory['items'] as List<dynamic>;
      
      for (var item in items) {
        final itemData = InventoryItem.fromJson(item);
        final itemId = itemData.itemId;
        
        // 장착된 갑옷이나 무기와 같은 itemId면 제외 (빈 칸으로 표시)
        if (itemId == equippedArmorId || itemId == equippedWeaponId) {
          continue;
        }
        
        // 포션의 경우 quantity가 0보다 큰 경우만 추가 (백엔드에서 이미 사용한 개수를 뺀 값이 quantity에 반영됨)
        if (itemData.itemType.toUpperCase() == 'POTION' && itemData.quantity <= 0) {
          continue;
        }
        
        inventoryItems.add(itemData);
      }
    }
    
    // 백엔드의 potions 필드가 있고 items 배열에 포션이 없는 경우 처리
    // (백엔드에서 potions 필드를 직접 관리하는 경우)
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
        inventoryItems.add(InventoryItem(
          itemId: 'magic_potion',
          name: 'Magic Potion',
          description: '마법 포션',
          itemType: 'POTION',
          quantity: inventory['potions'] as int,
          stats: {'heal': 50},
        ));
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
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                          ),
                        )
                      : _buildInventoryPanels(),
                ),
                // 하단 Start 버튼
                _buildBottomButtonSection(),
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
    final itemImages = {
      // 갑옷
      'basic_clothes': 'assets/images/BasicClothes.png',
      'gold_armor': 'assets/images/GoldArmor.png',
      'silver_armor': 'assets/images/SilverArmor.png',
      'leather_armor': 'assets/images/Leather_Armor.png',
      
      // 무기
      'wooden_stick': 'assets/images/WoodenStick.png',
      'wooden_sword': 'assets/images/wooden_sword.png',
      'silver_sword': 'assets/images/sliver_sword.png',
      'gold_sword': 'assets/images/golden_sword.png',
      
      // 펫
      'cat': 'assets/images/Pet_Cat.png',
      'dog': 'assets/images/Pet_Dog.png',
      'rabbit': 'assets/images/Pet_Rabbit.png',
      
      // 포션
      'magic_potion': 'assets/images/MagicPotion.png',
    };
    
    return itemImages[itemId] ?? 'assets/images/default_item.png';
  }

  // 3x3 그리드에 아이템 배치 (왼쪽부터 갑옷, 무기, 펫 세로줄)
  // 각 네모칸의 정확한 위치에 아이템 배치
  List<Widget> _build3x3GridItems(double panelWidth, double panelHeight) {
    // 아이템 정의 (순서대로 위에서 아래로)
    final armors = [
      {'id': 'leather_armor', 'name': 'Leather Armor'},
      {'id': 'silver_armor', 'name': 'Silver Armor'},
      {'id': 'gold_armor', 'name': 'Gold Armor'},
    ];
    
    final weapons = [
      {'id': 'wooden_sword', 'name': 'Wooden Sword'},
      {'id': 'silver_sword', 'name': 'Silver Sword'},
      {'id': 'gold_sword', 'name': 'Gold Sword'},
    ];
    
    final pets = [
      {'id': 'cat', 'name': 'Cat'},
      {'id': 'dog', 'name': 'Dog'},
      {'id': 'rabbit', 'name': 'Rabbit'},
    ];

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
    
    // 1열: 갑옷 (왼쪽 세로줄) - 위에서 아래로: 가죽, 실버, 골드
    for (int row = 0; row < 3; row++) {
      final armor = armors[row];
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
            _getItemImagePath(armor['id']!, 'ARMOR'),
            width: itemSize,
            height: itemSize,
            fit: BoxFit.contain,
          ),
        ),
      );
    }
    
    // 2열: 무기 (가운데 세로줄) - 위에서 아래로: 나무, 실버, 골드
    for (int row = 0; row < 3; row++) {
      final weapon = weapons[row];
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
            _getItemImagePath(weapon['id']!, 'WEAPON'),
            width: itemSize,
            height: itemSize,
            fit: BoxFit.contain,
          ),
        ),
      );
    }
    
    // 3열: 펫 (오른쪽 세로줄) - 위에서 아래로: 고양이, 개, 토끼
    for (int row = 0; row < 3; row++) {
      final pet = pets[row];
      final cellCenterX = gridStartX + cellWidth * 2.5; // 세 번째 열 중심
      final cellCenterY = gridStartY + cellHeight * (row + 0.5); // 각 행의 중심
      final offsetY = row == 2 ? bottomRowOffset : 0.0; // 맨 밑줄만 오프셋 적용
      
      items.add(
        Positioned(
          left: cellCenterX - itemHalfSize, // 셀 중심 - 아이템 크기/2
          top: cellCenterY - itemHalfSize + offsetY,
          width: itemSize,
          height: itemSize,
          child: Image.asset(
            _getItemImagePath(pet['id']!, 'PET'),
            width: itemSize,
            height: itemSize,
            fit: BoxFit.contain,
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
                  width: 24,
                  height: 24,
                ),
                const SizedBox(width: 4),
                Text(
                  gold.toString(),
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
                      fontSize: 18,
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
    
    return Container(
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
                // 수량 표시 (1개 이상일 때만)
                if (item.quantity > 1)
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

  Widget _buildBottomButtonSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 상점 아이콘 (왼쪽)
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ShopScreen()),
              );
            },
            child: Image.asset(
              'assets/images/Icon_Shop.png',
              width: 45,
              height: 45,
            ),
          ),
          // Start 버튼 (오른쪽)
          GestureDetector(
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
        ],
      ),
    );
  }
}