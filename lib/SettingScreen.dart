import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'shop.dart';
import 'MyPageScreen.dart' as mypage;
import 'models/user_game_info.dart';
import 'services/game_service.dart';

class SettingScreen extends StatefulWidget {
  final double bottomControlsAlignmentY;
  final int userId; // 사용자 ID 추가

  const SettingScreen({super.key, this.bottomControlsAlignmentY = 0.95, required this.userId});

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

  // 인벤토리 표시 상태
  String? selectedInventoryType; // 'armor', 'weapon', 'pet', null(전체)

  // Inventory_2 아이템 위치/크기 조절 상태값
  double armorItemTop = 395;
  double armorItemRight = 199.5; // 오른쪽 여백
  double armorItemSize = 60;
  double weaponItemTop = 395;
  double weaponItemRight = 199.5;
  double weaponItemSize = 60;
  double petItemTop = 395;
  double petItemRight = 199.5;
  double petItemSize = 60;

  // 캐릭터 오버레이(장착 이미지) 조절: 위치/크기
  double armorOverlayWidth = 70;
  double armorOverlayHeight = 70;
  double armorOverlayDx = 53; // +우측 / -좌측
  double armorOverlayDy = 67; // +하단 / -상단
  double weaponOverlayWidth = 60;
  double weaponOverlayHeight = 60;
  double weaponOverlayDx = 0;
  double weaponOverlayDy = 67;
  double petOverlayWidth = 70;
  double petOverlayHeight = 70;
  double petOverlayDx = 0;
  double petOverlayDy = 67;

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

  // 선택된 탭의 아이템을 버튼으로 장착
  void _equipSelected() {
    if (selectedInventoryType == 'armor' && userGameInfo?.armorName != null) {
      _toggleEquip('armor', userGameInfo!.armorName!, 'assets/images/BasicClothes.png');
    } else if (selectedInventoryType == 'weapon' && userGameInfo?.weaponName != null) {
      _toggleEquip('weapon', userGameInfo!.weaponName!, 'assets/images/WoodenStick.png');
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
    return equippedWeapon != null ? (userGameInfo?.atk ?? 0) : 0;
  }

  int getCurrentDef() {
    return equippedArmor != null ? (userGameInfo?.def ?? 0) : 0;
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

  // Inventory_2.png에 표시될 아이템 위젯 생성 (클릭 시 장착)
  Widget _buildInventory2Item(String itemType, String itemName, String imagePath, {double size = 80}) {
    final bool isEquipped = (itemType == 'weapon' && equippedWeapon == itemName) ||
        (itemType == 'armor' && equippedArmor == itemName);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (details) {
        print('아이템 onTapDown -> type:$itemType, name:$itemName, local:${details.localPosition}, global:${details.globalPosition}');
      },
      onTap: () => _toggleEquip(itemType, itemName, imagePath),
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

      print('사용자 정보 로딩 시작: userId=${widget.userId}');
      final gameInfo = await GameService.getUserGameInfo(widget.userId);
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
                              width: 55,
                              height: 55,
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
                if (selectedInventoryType == 'pet')
                  Positioned(
                    top: petItemTop,
                    right: petItemRight,
                    child: Builder(
                      builder: (_) {
                        final pets = _getUserPets();
                        if (pets.isEmpty) {
                          return Container(
                            width: petItemSize,
                            height: petItemSize,
                            alignment: Alignment.center,
                            child: Text(
                              '펫 없음',
                              style: TextStyle(
                                fontFamily: 'DungGeunMo',
                                fontSize: 14,
                                color: Colors.black,
                              ),
                            ),
                          );
                        }
                        final String petName = pets.first;
                        final String petPath = _getPetImagePath(petName);
                        return _buildInventory2Item('pet', petName, petPath, size: petItemSize);
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
                            'assets/images/Female_Character.png',
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
                if (selectedInventoryType == 'armor' && userGameInfo?.armorName != null)
                  Positioned(
                    top: armorItemTop,
                    right: armorItemRight,
                    child: _buildInventory2Item(
                      'armor',
                      userGameInfo!.armorName!,
                      'assets/images/BasicClothes.png',
                      size: armorItemSize,
                    ),
                  ),
                if (selectedInventoryType == 'weapon' && userGameInfo?.weaponName != null)
                  Positioned(
                    top: weaponItemTop,
                    right: weaponItemRight,
                    child: _buildInventory2Item(
                      'weapon',
                      userGameInfo!.weaponName!,
                      'assets/images/WoodenStick.png',
                      size: weaponItemSize,
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
                    width: 75,
                    height: 75,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 16),
                // 장착 버튼
                GestureDetector(
                  onTap: _equipSelected,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.asset(
                        'assets/images/MainButtonSquare.png',
                        width: 70,
                        height: 70,
                      ),
                      Text(
                        '장착',
                        style: TextStyle(
                          fontFamily: 'DungGeunMo',
                          fontSize: 22,
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
                    // Start 버튼 클릭 이벤트
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
