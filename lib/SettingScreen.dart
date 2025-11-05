import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'shop.dart';
import 'MyPageScreen.dart' as mypage;
import 'BattleScreen.dart';
import 'models/user_game_info.dart';
import 'services/game_service.dart';

class SettingScreen extends StatefulWidget {
  final double bottomControlsAlignmentY;
  final String? questTitle;
  final String? category;
  final List<Map<String, dynamic>>? questList; // 일정 목록 (선택적, taskId 포함)
  // userId 파라미터 제거 - SharedPreferences에서 가져옴

  const SettingScreen({
    super.key,
    this.bottomControlsAlignmentY = 0.95,
    this.questTitle,
    this.category,
    this.questList,
  });

  @override
  State<SettingScreen> createState() => _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  UserGameInfo? userGameInfo;
  bool isLoading = true;
  String? errorMessage;

  // 장착된 아이템 상태
  String? equippedWeapon;
  String? equippedArmor;
  String? equippedPet;
  // 장착된 아이템 이미지 경로 (클릭한 이미지 그대로 사용)
  String? equippedWeaponImagePath;
  String? equippedArmorImagePath;
  String? equippedPetImagePath;

  // 장착 대기(선택) 아이템 상태
  String? _pendingArmorId;
  String? _pendingArmorImagePath;
  String? _pendingWeaponId;
  String? _pendingWeaponImagePath;

  // 인벤토리 표시 상태
  String? selectedInventoryType; // 'armor', 'weapon', 'pet', null(전체)

  // Inventory_2 아이템 위치/크기 조절 상태값
  double armorItemTop = 395;
  double armorItemRight = 110; // 오른쪽 여백
  double armorItemSize = 60;
  double weaponItemTop = 395;
  double weaponItemRight = 110;
  double weaponItemSize = 60;
  double petItemTop = 395;
  double petItemRight = 199.5;
  double petItemSize = 60;

  // 캐릭터 오버레이(장착 이미지) 조절: 위치/크기
  double armorOverlayWidth = 86;
  double armorOverlayHeight = 80;
  double armorOverlayDx = 44; // +우측 / -좌측
  double armorOverlayDy = 59; // +하단 / -상단
  double weaponOverlayWidth = 60;
  double weaponOverlayHeight = 60;
  double weaponOverlayDx = 0;
  double weaponOverlayDy = 67;
  double petOverlayWidth = 60;
  double petOverlayHeight = 60;
  double petOverlayDx = 30;
  double petOverlayDy =115;

  // 아이템 메타데이터: itemId -> 이미지 및 스탯 정보
  static const Map<String, Map<String, dynamic>> _itemMeta = {
    'leather_armor': {
      'type': 'armor',
      'def': 5,
      'path': 'assets/images/Leather_Armor.png',
    },
    'wooden_sword': {
      'type': 'weapon',
      'atk': 5,
      'path': 'assets/images/wooden_sword.png',
    },
    'silver_armor': {
      'type': 'armor',
      'def': 10,
      'path': 'assets/images/SilverArmor.png',
    },
    'silver_sword': {
      'type': 'weapon',
      'atk': 10,
      'path': 'assets/images/sliver_sword.png',
    },
    'gold_armor': {
      'type': 'armor',
      'def': 20,
      'path': 'assets/images/GoldArmor.png',
    },
    'gold_sword': {
      'type': 'weapon',
      'atk': 20,
      'path': 'assets/images/golden_sword.png',
    },
  };

  // 펫 id와 기대 이름 매핑 (유효성 검증용)
  static const Map<String, List<String>> _petIdToExpectedNames = {
    'pet_cute': ['귀여운 펫', 'cute pet'],
  };

  Map<String, dynamic>? _getInventoryMap() {
    try {
      final dynamic invRaw = userGameInfo?.inventory;
      if (invRaw == null) return null;
      // inventory가 Map이거나 List<Map>인 경우 모두 지원
      if (invRaw is Map<String, dynamic>) {
        return invRaw;
      }
      if (invRaw is List && invRaw.isNotEmpty) {
        final dynamic first = invRaw.first;
        if (first is Map<String, dynamic>) return first;
      }
    } catch (_) {}
    return null;
  }

  String? _getArmorItemId() {
    final inv = _getInventoryMap();
    if (inv == null) return null;
    // 먼저 장착된 갑옷 확인
    final armor = inv['armor'] ?? inv['equippedArmor'];
    if (armor is Map<String, dynamic>) return armor['id']?.toString();
    if (armor is String) return armor;
    return null;
  }

  String? _getWeaponItemId() {
    final inv = _getInventoryMap();
    if (inv == null) return null;
    // 먼저 장착된 무기 확인
    final weapon = inv['weapon'] ?? inv['equippedWeapon'];
    if (weapon is Map<String, dynamic>) return weapon['id']?.toString();
    if (weapon is String) return weapon;
    return null;
  }

  // 인벤토리의 갑옷 배열에서 아이템 목록 추출 (스탯 값 포함)
  List<Map<String, dynamic>> _getUserArmorEntries() {
    final List<Map<String, dynamic>> result = [];
    final Set<String> seen = <String>{};
    try {
      final inv = _getInventoryMap();
      if (inv == null) return result;
      final armorsRaw = inv['armors'];
      if (armorsRaw is List) {
        for (final e in armorsRaw) {
          if (e is Map) {
            final String? id = (e['itemId'] ?? e['id'])?.toString();
            if (id != null && id.isNotEmpty) {
              final key = id;
              if (!seen.contains(key)) {
                seen.add(key);
                // DEF 값 가져오기 (statValue 또는 _itemMeta에서)
                int defValue = e['statValue'] as int? ?? 0;
                if (defValue == 0) {
                  // statValue가 없으면 _itemMeta에서 가져오기
                  defValue = _itemMeta[id]?['def'] as int? ?? 0;
                }
                result.add({
                  'id': id,
                  'name': e['name']?.toString() ?? id,
                  'def': defValue,
                });
              }
            }
          }
        }
      }
    } catch (_) {}
    return result;
  }

  // 인벤토리의 무기 배열에서 아이템 목록 추출 (스탯 값 포함)
  List<Map<String, dynamic>> _getUserWeaponEntries() {
    final List<Map<String, dynamic>> result = [];
    final Set<String> seen = <String>{};
    try {
      final inv = _getInventoryMap();
      if (inv == null) return result;
      final weaponsRaw = inv['weapons'];
      if (weaponsRaw is List) {
        for (final e in weaponsRaw) {
          if (e is Map) {
            final String? id = (e['itemId'] ?? e['id'])?.toString();
            if (id != null && id.isNotEmpty) {
              final key = id;
              if (!seen.contains(key)) {
                seen.add(key);
                // ATK 값 가져오기 (statValue 또는 _itemMeta에서)
                int atkValue = e['statValue'] as int? ?? 0;
                if (atkValue == 0) {
                  // statValue가 없으면 _itemMeta에서 가져오기
                  atkValue = _itemMeta[id]?['atk'] as int? ?? 0;
                }
                result.add({
                  'id': id,
                  'name': e['name']?.toString() ?? id,
                  'atk': atkValue,
                });
              }
            }
          }
        }
      }
    } catch (_) {}
    return result;
  }

  String? _getItemImagePathById(String? itemId, {required String defaultPath}) {
    if (itemId == null) return defaultPath;
    final meta = _itemMeta[itemId];
    if (meta == null) return defaultPath;
    return meta['path']?.toString() ?? defaultPath;
  }

  // 장착 토글(간단 버전): 같은 아이템 터치 시 해제, 아니면 교체
  void _toggleEquip(String itemType, String itemName, String imagePath) {
    print('아이템 탭: type=$itemType, name=$itemName, path=$imagePath');
    setState(() {
      if (itemType == 'weapon') {
        final bool isSame = equippedWeapon == itemName;
        equippedWeapon = isSame ? null : itemName;
        equippedWeaponImagePath = isSame ? null : imagePath;
        print('무기 토글 결과 -> equippedWeapon:$equippedWeapon, image:$equippedWeaponImagePath');
      } else if (itemType == 'armor') {
        final bool isSame = equippedArmor == itemName;
        equippedArmor = isSame ? null : itemName;
        equippedArmorImagePath = isSame ? null : imagePath;
        print('갑옷 토글 결과 -> equippedArmor:$equippedArmor, image:$equippedArmorImagePath');
      } else if (itemType == 'pet') {
        final bool isSame = equippedPet == itemName;
        equippedPet = isSame ? null : itemName;
        equippedPetImagePath = isSame ? null : imagePath;
        print('펫 토글 결과 -> equippedPet:$equippedPet, image:$equippedPetImagePath');
      }
    });
  }

  // 선택된 탭의 아이템을 버튼으로 장착 (스탯 값이 높은 것을 우선)
  void _equipSelected() {
    if (selectedInventoryType == 'armor') {
      // 인벤토리 배열과 장착된 갑옷을 모두 고려하여 DEF가 가장 높은 것 선택
      List<Map<String, dynamic>> allArmors = [];
      
      // 장착된 갑옷 추가
      final equippedArmorId = _getArmorItemId();
      if (equippedArmorId != null) {
        int defValue = _itemMeta[equippedArmorId]?['def'] as int? ?? 0;
        allArmors.add({
          'id': equippedArmorId,
          'name': equippedArmorId,
          'def': defValue,
        });
      }
      
      // 인벤토리 배열의 갑옷들 추가
      final armorEntries = _getUserArmorEntries();
      allArmors.addAll(armorEntries);
      
      if (allArmors.isEmpty) {
        print('장착할 갑옷이 없습니다.');
        return;
      }
      
      // DEF가 가장 높은 갑옷 선택
      allArmors.sort((a, b) => (b['def'] as int).compareTo(a['def'] as int));
      final bestArmor = allArmors.first;
      final bestArmorId = bestArmor['id'] as String;
      final bestArmorPath = _getItemImagePathById(bestArmorId, defaultPath: 'assets/images/BasicClothes.png');
      
      if (bestArmorPath != null) {
        _toggleEquip('armor', bestArmorId, bestArmorPath);
        print('✅ 최고 DEF 갑옷 장착: $bestArmorId (DEF: ${bestArmor['def']})');
      } else {
        print('장착할 갑옷 이미지 경로를 찾을 수 없습니다.');
      }
      
    } else if (selectedInventoryType == 'weapon') {
      // 인벤토리 배열과 장착된 무기를 모두 고려하여 ATK가 가장 높은 것 선택
      List<Map<String, dynamic>> allWeapons = [];
      
      // 장착된 무기 추가
      final equippedWeaponId = _getWeaponItemId();
      if (equippedWeaponId != null) {
        int atkValue = _itemMeta[equippedWeaponId]?['atk'] as int? ?? 0;
        allWeapons.add({
          'id': equippedWeaponId,
          'name': equippedWeaponId,
          'atk': atkValue,
        });
      }
      
      // 인벤토리 배열의 무기들 추가
      final weaponEntries = _getUserWeaponEntries();
      allWeapons.addAll(weaponEntries);
      
      if (allWeapons.isEmpty) {
        print('장착할 무기가 없습니다.');
        return;
      }
      
      // ATK가 가장 높은 무기 선택
      allWeapons.sort((a, b) => (b['atk'] as int).compareTo(a['atk'] as int));
      final bestWeapon = allWeapons.first;
      final bestWeaponId = bestWeapon['id'] as String;
      final bestWeaponPath = _getItemImagePathById(bestWeaponId, defaultPath: 'assets/images/WoodenStick.png');
      
      if (bestWeaponPath != null) {
        _toggleEquip('weapon', bestWeaponId, bestWeaponPath);
        print('✅ 최고 ATK 무기 장착: $bestWeaponId (ATK: ${bestWeapon['atk']})');
      } else {
        print('장착할 무기 이미지 경로를 찾을 수 없습니다.');
      }
      
    } else if (selectedInventoryType == 'pet') {
      final pets = _getUserPets();
      if (pets.isNotEmpty) {
        final String petName = pets.first;
        final String petPath = _getPetImagePath(petName);
        _toggleEquip('pet', petName, petPath);
      } else {
        print('장착할 펫 없음');
      }
    } else {
      print('장착 대상 없음: selectedInventoryType=$selectedInventoryType');
    }
  }

  // 현재 장착 상태에 따른 표시용 ATK/DEF 계산
  int getCurrentAtk() {
    final String? weaponId = equippedWeapon;
    final int weaponAtk = weaponId != null ? (_itemMeta[weaponId]?['atk'] as int? ?? 0) : 0;
    return weaponAtk;
  }

  int getCurrentDef() {
    final String? armorId = equippedArmor;
    final int armorDef = armorId != null ? (_itemMeta[armorId]?['def'] as int? ?? 0) : 0;
    return armorDef;
  }

  // 사용자 인벤토리에서 펫 목록 추출
  List<String> _getUserPets() {
    try {
      final invList = userGameInfo?.inventory; // List<dynamic>
      if (invList == null || invList.isEmpty) return [];
      final inv = invList.first; // 서버 파싱 구조상 inventory 맵이 리스트 첫 요소에 있음
      if (inv is Map<String, dynamic>) {
        final petsRaw = inv['pets'];
        if (petsRaw is List) {
          // 각 요소가 문자열(펫 이름) 또는 맵({name: ...})일 수 있음
          return petsRaw.map<String>((e) {
            if (e is String) return e;
            if (e is Map) return (e['name'] ?? '').toString();
            return '';
          }).where((name) => name.isNotEmpty).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  // 펫 이름/id를 이미지 경로로 매핑
  String _getPetImagePath(String petName) {
    final lower = petName.toLowerCase();
    if (lower.contains('cat') || petName.contains('고양이')) return 'assets/images/Pet_Cat.png';
    if (lower.contains('dog') || petName.contains('개')) return 'assets/images/Pet_Dog.png';
    if (lower.contains('rabbit') || petName.contains('토끼')) return 'assets/images/Pet_Rabbit.png';
    return 'assets/images/Pet_Cat.png';
  }

  // 펫 유효성 검증: itemId와 name이 매핑과 일치하는 경우만 통과
  bool _isValidPet(String? itemId, String? name) {
    if (itemId == null || name == null || name.isEmpty) return false;
    final expected = _petIdToExpectedNames[itemId];
    if (expected == null || expected.isEmpty) return false;
    return expected.contains(name);
  }

  // 인벤토리에서 펫 엔트리 표준화 리스트 추출
  List<Map<String, String>> _getUserPetEntries() {
    final List<Map<String, String>> result = [];
    final Set<String> seen = <String>{};
    try {
      final inv = _getInventoryMap();
      if (inv == null) return result;
      final petsRaw = inv['pets'];
      if (petsRaw is List) {
        for (final e in petsRaw) {
          if (e is Map) {
            final String? id = (e['itemId'] ?? e['id'])?.toString();
            final String? name = e['name']?.toString();
            if (_isValidPet(id, name)) {
              final key = '${id!}|${name!}';
              if (!seen.contains(key)) {
                seen.add(key);
                result.add({'id': id, 'name': name});
              }
            }
          } else if (e is String) {
            // 이름만 있는 경우는 검증 불가 → 표시하지 않음
          }
        }
      }
    } catch (_) {}
    return result;
  }

  // 체력 바 이미지 선택 함수
  String getHpBarImage(int hp) {
    if (hp < 10) return 'assets/images/Icon_HpXp_EmptyBar.png';
    if (hp < 20) return 'assets/images/Icon_HpBar_1.png';
    if (hp < 30) return 'assets/images/Icon_HpBar_2.png';
    if (hp < 40) return 'assets/images/Icon_HpBar_3.png';
    if (hp < 50) return 'assets/images/Icon_HpBar_4.png';
    if (hp < 60) return 'assets/images/Icon_HpBar_5.png';
    if (hp < 70) return 'assets/images/Icon_HpBar_6.png';
    if (hp < 80) return 'assets/images/Icon_HpBar_7.png';
    if (hp < 90) return 'assets/images/Icon_HpBar_8.png';
    if (hp < 100) return 'assets/images/Icon_HpBar_9.png';
    return 'assets/images/Icon_HpBar_10.png';
  }

  // 경험치 바 이미지 선택 함수
  String getExpBarImage(int level, int exp) {
    // 레벨별 최대 경험치 계산 (1레벨: 100exp, 2레벨: 150exp, 3레벨: 200exp, 4레벨: 250exp...)
    int maxExp = 100 + (level - 1) * 50;

    // 현재 레벨에서의 경험치 퍼센트 계산
    double expPercentage = (exp / maxExp) * 100;

    // 10% 단위로 체크
    if (expPercentage < 10) return 'assets/images/Icon_HpXp_EmptyBar.png';
    if (expPercentage < 20) return 'assets/images/Icon_XpBar_1.png';
    if (expPercentage < 30) return 'assets/images/Icon_XpBar_2.png';
    if (expPercentage < 40) return 'assets/images/Icon_XpBar_3.png';
    if (expPercentage < 50) return 'assets/images/Icon_XpBar_4.png';
    if (expPercentage < 60) return 'assets/images/Icon_XpBar_5.png';
    if (expPercentage < 70) return 'assets/images/Icon_XpBar_6.png';
    if (expPercentage < 80) return 'assets/images/Icon_XpBar_7.png';
    if (expPercentage < 90) return 'assets/images/Icon_XpBar_8.png';
    if (expPercentage < 100) return 'assets/images/Icon_XpBar_9.png';
    return 'assets/images/Icon_XpBar_10.png';
  }

  // 아이템 클릭 핸들러
  void _onItemClick(String itemType, String itemName) {
    setState(() {
      if (itemType == 'weapon') {
        equippedWeapon = equippedWeapon == itemName ? null : itemName;
      } else if (itemType == 'armor') {
        equippedArmor = equippedArmor == itemName ? null : itemName;
      }
    });
  }

  // 인벤토리 칸 클릭 핸들러
  void _onInventorySlotClick(String slotType) {
    setState(() {
      if (selectedInventoryType == slotType) {
        selectedInventoryType = null; // 같은 칸 클릭 시 전체 표시
      } else {
        selectedInventoryType = slotType; // 해당 타입만 표시
      }
    });
  }

  // 인벤토리 아이템 위젯 생성
  Widget _buildInventoryItem(String itemType, String itemName, String imagePath) {
    bool isEquipped = false;
    if (itemType == 'weapon' && equippedWeapon == itemName) {
      isEquipped = true;
    } else if (itemType == 'armor' && equippedArmor == itemName) {
      isEquipped = true;
    }

    return GestureDetector(
      onTap: () => _onItemClick(itemType, itemName),
      child: Container(
        width: 60,
        height: 60,
        margin: const EdgeInsets.all(4),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            if (isEquipped)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(color: Colors.black.withOpacity(0.35)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Inventory_2.png에 표시될 아이템 위젯 생성 (클릭 시 선택, 장착 버튼으로 확정)
  Widget _buildInventory2Item(String itemType, String itemName, String imagePath, {double size = 80}) {
    final bool isEquipped = (itemType == 'weapon' && equippedWeapon == itemName) ||
        (itemType == 'armor' && equippedArmor == itemName) ||
        (itemType == 'pet' && equippedPet == itemName);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (details) {
        print('아이템 onTapDown -> type:$itemType, name:$itemName, local:${details.localPosition}, global:${details.globalPosition}');
      },
      onTap: () {
        setState(() {
          if (itemType == 'armor') {
            _pendingArmorId = itemName;
            _pendingArmorImagePath = imagePath;
            print('갑옷 선택 대기 -> id:$_pendingArmorId, path:$_pendingArmorImagePath');
          } else if (itemType == 'weapon') {
            _pendingWeaponId = itemName;
            _pendingWeaponImagePath = imagePath;
            print('무기 선택 대기 -> id:$_pendingWeaponId, path:$_pendingWeaponImagePath');
          } else if (itemType == 'pet') {
            // 펫은 즉시 토글(요구사항에 없으나 기존 동작 유지 원하면 토글로 변경 가능)
            _toggleEquip('pet', itemName, imagePath);
          }
        });
      },
      child: Container(
        width: size,
        height: size,
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            if (isEquipped)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(color: Colors.black.withOpacity(0.35)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadUserGameInfo();
  }

  Future<void> _loadUserGameInfo() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // SharedPreferences에서 로그인한 사용자의 DB ID 가져오기
      final prefs = await SharedPreferences.getInstance();
      final userDbId = prefs.getInt('userDbId');
      
      if (userDbId == null) {
        setState(() {
          errorMessage = '로그인이 필요합니다.';
          isLoading = false;
        });
        print('⚠️ 로그인한 사용자 DB ID가 없습니다.');
        return;
      }

      print('사용자 정보 로딩 시작: userId=$userDbId');
      final gameInfo = await GameService.getUserGameInfo(userDbId);
      print('사용자 정보 로딩 완료: $gameInfo');
      print('무기명: ${gameInfo.weaponName}');
      print('갑옷명: ${gameInfo.armorName}');

      setState(() {
        userGameInfo = gameInfo;
        // 자동 장착 제거 - 사용자가 직접 클릭해야만 장착됨
        isLoading = false;
      });
    } catch (e) {
      print('사용자 정보 로딩 오류: $e');
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    print('SettingScreen 빌드 - selectedInventoryType: $selectedInventoryType');
    print('장착된 무기: $equippedWeapon');
    print('장착된 갑옷: $equippedArmor');

    if (isLoading) {
      return Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/GridScreen.png',
                fit: BoxFit.cover,
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    '사용자 정보를 불러오는 중...',
                    style: TextStyle(
                      fontFamily: 'DungGeunMo',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '오류가 발생했습니다',
                style: TextStyle(
                  fontFamily: 'DungGeunMo',
                  fontSize: 20,
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                errorMessage!,
                style: TextStyle(
                  fontFamily: 'DungGeunMo',
                  fontSize: 16,
                  color: Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadUserGameInfo,
                child: Text(
                  '다시 시도',
                  style: TextStyle(
                    fontFamily: 'DungGeunMo',
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/GridScreen.png',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(15.0),
              child: Align(
                alignment: Alignment.topLeft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const mypage.MyPageScreen(),
                              ),
                            );
                          },
                          child: Image.asset(
                            'assets/images/Icon_MyPage.png',
                            width: 70,
                            height: 70,
                          ),
                        ),
                        Row(
                          children: [
                            Image.asset(
                              'assets/images/Icon_Gold.png',
                              width: 50,
                              height: 50,
                            ),
                            Text(
                              '${userGameInfo?.gold ?? 2500}',
                              style: TextStyle(
                                fontFamily: 'DungGeunMo',
                                fontSize: 25,
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'HP',
                              style: TextStyle(
                                fontFamily: 'DungGeunMo',
                                fontSize: 28,
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Image.asset(
                              getHpBarImage(userGameInfo?.hp ?? 100),
                              height: 23,
                              fit: BoxFit.contain,
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'XP',
                              style: TextStyle(
                                fontFamily: 'DungGeunMo',
                                fontSize: 28,
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Image.asset(
                              getExpBarImage(userGameInfo?.level ?? 1, userGameInfo?.exp ?? 0),
                              height: 23.5,
                              fit: BoxFit.contain,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment(0, -0.2),
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Stack(
                  children: [
                    Image.asset(
                      'assets/images/Inventory_1.png',
                      width: MediaQuery.of(context).size.width * 0.8,
                      fit: BoxFit.contain,
                    ),
                    // 갑옷 칸 (맨 위 주황색 칸)
                    Positioned(
                      top: 50,
                      left: MediaQuery.of(context).size.width * 0.4 - 30,
                      child: GestureDetector(
                        onTap: () => _onInventorySlotClick('armor'),
                        child: Container(
                          width: 60,
                          height: 60,
                        ),
                      ),
                    ),
                    // 펫 칸 (왼쪽 아래 주황색 칸)
                    Positioned(
                      top: 200,
                      left: MediaQuery.of(context).size.width * 0.4 - 80,
                      child: GestureDetector(
                        onTap: () => _onInventorySlotClick('pet'),
                        child: Container(
                          width: 60,
                          height: 60,
                        ),
                      ),
                    ),
                    // 무기 칸 (오른쪽 아래 주황색 칸)
                    Positioned(
                      top: 200,
                      left: MediaQuery.of(context).size.width * 0.4 + 20,
                      child: GestureDetector(
                        onTap: () => _onInventorySlotClick('weapon'),
                        child: Container(
                          width: 60,
                          height: 60,
                        ),
                      ),
                    ),
                  ],
                ),
                // Inventory_2.png 배경
                Positioned(
                  top: 330,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Image.asset(
                      'assets/images/Inventory_2.png',
                      width: MediaQuery.of(context).size.width * 0.8,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                // (이전 위치에서 제거) 아이템 클릭 가능 영역은 캐릭터/텍스트 등 모든 요소 위에 오도록 아래로 이동
                // 선택된 카테고리만 보이거나, 선택이 없으면 모든 카테고리 아이템을 표시
                if (selectedInventoryType == 'pet')
                  Positioned(
                    top: petItemTop,
                    right: petItemRight,
                    child: Builder(
                      builder: (_) {
                        final petEntries = _getUserPetEntries();
                        if (petEntries.isEmpty) {
                          return Container(
                            width: petItemSize,
                            height: petItemSize,
                          );
                        }
                        final List<Widget> petWidgets = [];
                        for (final entry in petEntries) {
                          final String petName = entry['name']!;
                          final String petPath = _getPetImagePath(petName);
                          petWidgets.add(_buildInventory2Item('pet', petName, petPath, size: petItemSize));
                          petWidgets.add(const SizedBox(width: 8));
                        }
                        if (petWidgets.isNotEmpty) petWidgets.removeLast();
                        return SizedBox(
                          height: petItemSize,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: petWidgets,
                          ),
                        );
                      },
                    ),
                  ),
                Positioned(
                  top: 12,
                  left: 24,
                  child: Text(
                    'ATK: ${getCurrentAtk()}',
                    style: TextStyle(
                      fontFamily: 'DungGeunMo',
                      fontSize: 30,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Positioned(
                  top: 75,
                  left: 48,
                  child: GestureDetector(
                    onTap: () => _onInventorySlotClick('armor'),
                    child: Text(
                      '+',
                      style: TextStyle(
                        fontFamily: 'DungGeunMo',
                        fontSize: 40,
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 238,
                  left: 48,
                  child: GestureDetector(
                    onTap: () => _onInventorySlotClick('pet'),
                    child: Text(
                      '+',
                      style: TextStyle(
                        fontFamily: 'DungGeunMo',
                        fontSize: 40,
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 238,
                  left: 228,
                  child: GestureDetector(
                    onTap: () => _onInventorySlotClick('weapon'),
                    child: Text(
                      '+',
                      style: TextStyle(
                        fontFamily: 'DungGeunMo',
                        fontSize: 40,
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 20,
                  child: Text(
                    'DEF: ${getCurrentDef()}',
                    style: TextStyle(
                      fontFamily: 'DungGeunMo',
                      fontSize: 30,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Positioned(
                  top: 338,
                  left: 24,
                  child: Text(
                    'Items',
                    style: TextStyle(
                      fontFamily: 'DungGeunMo',
                      fontSize: 30,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // 캐릭터 오버레이 - 클릭 막지 않도록 IgnorePointer 처리
                Positioned(
                  top: 0,
                  left: 10,
                  right: 0,
                  bottom: -40,
                  child: IgnorePointer(
                    ignoring: true,
                    child: Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // 기본 캐릭터
                          Image.asset(
                            'assets/images/MaleCharacter.png',
                            width: 170,
                            height: 170,
                            fit: BoxFit.contain,
                          ),
                          // 장착된 갑옷 오버레이 (위치/크기 조절 가능)
                          if (equippedArmorImagePath != null)
                            Positioned(
                              left: armorOverlayDx,
                              top: armorOverlayDy,
                              child: Image.asset(
                                equippedArmorImagePath!,
                                width: armorOverlayWidth,
                                height: armorOverlayHeight,
                                fit: BoxFit.contain,
                              ),
                            ),
                          // 장착된 무기 오버레이 (위치/크기 조절 가능)
                          if (equippedWeaponImagePath != null)
                            Positioned(
                              left: weaponOverlayDx,
                              top: weaponOverlayDy,
                              child: Image.asset(
                                equippedWeaponImagePath!,
                                width: weaponOverlayWidth,
                                height: weaponOverlayHeight,
                                fit: BoxFit.contain,
                              ),
                            ),
                          // 장착된 펫 오버레이 (위치/크기 조절 가능)
                          if (equippedPetImagePath != null)
                            Positioned(
                              left: petOverlayDx,
                              top: petOverlayDy,
                              child: Image.asset(
                                equippedPetImagePath!,
                                width: petOverlayWidth,
                                height: petOverlayHeight,
                                fit: BoxFit.contain,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                // 아이템 클릭 가능 영역 (_buildInventory2Item) - 최상단에 배치
                if (selectedInventoryType == 'armor')
                  Positioned(
                    top: armorItemTop,
                    right: armorItemRight,
                    child: Builder(
                      builder: (_) {
                        final List<Widget> armorWidgets = [];
                        final equippedArmorId = _getArmorItemId();
                        
                        // 먼저 인벤토리의 armors 배열에서 아이템 가져오기 (silver_armor 등)
                        final armorEntries = _getUserArmorEntries();
                        for (final entry in armorEntries) {
                          final String armorId = entry['id'] as String;
                          // 장착된 아이템과 중복되지 않도록 체크
                          if (armorId != equippedArmorId) {
                            final String armorPath = _getItemImagePathById(
                              armorId,
                              defaultPath: 'assets/images/BasicClothes.png',
                            )!;
                            armorWidgets.add(_buildInventory2Item('armor', armorId, armorPath, size: armorItemSize));
                            armorWidgets.add(const SizedBox(width: 30));
                          }
                        }
                        
                        // 그 다음 장착된 갑옷 표시 (leather_armor 등, 오른쪽에 배치)
                        if (equippedArmorId != null) {
                          final armorPath = _getItemImagePathById(
                            equippedArmorId,
                            defaultPath: 'assets/images/BasicClothes.png',
                          );
                          if (armorPath != null) {
                            armorWidgets.add(_buildInventory2Item('armor', equippedArmorId, armorPath, size: armorItemSize));
                          }
                        }
                        
                        // 마지막 SizedBox 제거
                        if (armorWidgets.isNotEmpty && armorWidgets.last is SizedBox) {
                          armorWidgets.removeLast();
                        }
                        
                        if (armorWidgets.isEmpty) {
                          return Container(
                            width: armorItemSize,
                            height: armorItemSize,
                          );
                        }
                        
                        return SizedBox(
                          height: armorItemSize,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: armorWidgets,
                          ),
                        );
                      },
                    ),
                  ),
                if (selectedInventoryType == 'weapon')
                  Positioned(
                    top: weaponItemTop,
                    right: weaponItemRight,
                    child: Builder(
                      builder: (_) {
                        final List<Widget> weaponWidgets = [];
                        final equippedWeaponId = _getWeaponItemId();
                        
                        // 먼저 인벤토리의 weapons 배열에서 아이템 가져오기 (silver_sword 등)
                        final weaponEntries = _getUserWeaponEntries();
                        for (final entry in weaponEntries) {
                          final String weaponId = entry['id'] as String;
                          // 장착된 아이템과 중복되지 않도록 체크
                          if (weaponId != equippedWeaponId) {
                            final String weaponPath = _getItemImagePathById(
                              weaponId,
                              defaultPath: 'assets/images/WoodenStick.png',
                            )!;
                            weaponWidgets.add(_buildInventory2Item('weapon', weaponId, weaponPath, size: weaponItemSize));
                            weaponWidgets.add(const SizedBox(width: 30));
                          }
                        }
                        
                        // 그 다음 장착된 무기 표시 (wooden_sword 등, 오른쪽에 배치)
                        if (equippedWeaponId != null) {
                          final weaponPath = _getItemImagePathById(
                            equippedWeaponId,
                            defaultPath: 'assets/images/WoodenStick.png',
                          );
                          if (weaponPath != null) {
                            weaponWidgets.add(_buildInventory2Item('weapon', equippedWeaponId, weaponPath, size: weaponItemSize));
                          }
                        }
                        
                        // 마지막 SizedBox 제거
                        if (weaponWidgets.isNotEmpty && weaponWidgets.last is SizedBox) {
                          weaponWidgets.removeLast();
                        }
                        
                        if (weaponWidgets.isEmpty) {
                          return Container(
                            width: weaponItemSize,
                            height: weaponItemSize,
                          );
                        }
                        
                        return SizedBox(
                          height: weaponItemSize,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: weaponWidgets,
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          Align(
            alignment: Alignment(0, widget.bottomControlsAlignmentY),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ShopScreen()),
                    );
                  },
                  child: Image.asset(
                    'assets/images/Icon_Shop.png',
                    width: 70,
                    height: 70,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 14),
                // 장착 버튼
                GestureDetector(
                  onTap: _equipSelected,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.asset(
                        'assets/images/MainButtonSquare.png',
                        width: 75,
                        height: 75,
                      ),
                      Text(
                        '장착',
                        style: TextStyle(
                          fontFamily: 'DungGeunMo',
                          fontSize: 18,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () {
                    // Start 버튼 클릭 시 BattleScreen으로 이동
                    // QuestScreen에서 전달받은 정보가 있으면 사용, 없으면 기본값 사용
                    final questTitle = widget.questTitle ?? '퀘스트';
                    final category = widget.category ?? 'work';
                    
                    // 일정 목록을 BattleQuest 리스트로 변환
                    List<BattleQuest>? battleQuestList;
                    int? currentIndex;
                    
                    if (widget.questList != null && widget.questList!.isNotEmpty) {
                      battleQuestList = widget.questList!.map((quest) {
                        final taskIdValue = quest['taskId'];
                        final taskId = taskIdValue is int ? taskIdValue : (taskIdValue as num?)?.toInt();
                        return BattleQuest(
                          questTitle: quest['title'] ?? '',
                          category: quest['category'] ?? 'work',
                          taskId: taskId,
                        );
                      }).toList();
                      
                      print('📋 SettingScreen - 일정 목록: ${battleQuestList.length}개');
                      for (int i = 0; i < battleQuestList.length; i++) {
                        print('  [$i] ${battleQuestList[i].questTitle} (${battleQuestList[i].category})');
                      }
                      
                      // 현재 일정의 인덱스 찾기
                      currentIndex = battleQuestList.indexWhere((q) => 
                        q.questTitle == questTitle && q.category == category
                      );
                      if (currentIndex == -1) {
                        print('⚠️ 현재 일정을 목록에서 찾을 수 없음, 첫 번째 일정으로 설정');
                        currentIndex = 0;
                      } else {
                        print('✅ 현재 일정 인덱스: $currentIndex');
                      }
                    }
                    
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BattleScreen(
                          params: BattleParams(
                            questTitle: questTitle,
                            category: category,
                            questList: battleQuestList,
                            currentQuestIndex: currentIndex,
                          ),
                        ),
                      ),
                    );
                  },
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.asset(
                        'assets/images/MainButton.png',
                        width: 170,
                        height: 70,
                      ),
                      Text(
                        'Start',
                        style: TextStyle(
                          fontFamily: 'DungGeunMo',
                          fontSize: 30,
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
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
