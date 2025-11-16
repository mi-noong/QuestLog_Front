class UserGameInfo {
  final int userId;
  final int hp;
  final int maxHp;
  final int exp;
  final int level;
  final int gold;
  final int atk;
  final int def;
  final List<dynamic> inventory;
  final String? weaponName;
  final String? armorName;

  UserGameInfo({
    required this.userId,
    required this.hp,
    required this.maxHp,
    required this.exp,
    required this.level,
    required this.gold,
    required this.atk,
    required this.def,
    required this.inventory,
    this.weaponName,
    this.armorName,
  });

  factory UserGameInfo.fromJson(Map<String, dynamic> json) {
    print('UserGameInfo.fromJson 호출됨');
    print('받은 JSON: $json');
    
    // data 객체에서 정보 추출
    final data = json['data'];
    final user = data['user'];
    final inventory = data['inventory'];
    
    print('사용자 데이터: $user');
    print('인벤토리 데이터: $inventory');
    
    // 무기와 갑옷 정보 추출 (equippedWeapon, equippedArmor 사용)
    String? weaponName;
    String? armorName;
    
    if (inventory != null) {
      weaponName = inventory['equippedWeapon']?['name'];
      armorName = inventory['equippedArmor']?['name'];
      print('추출된 무기명: $weaponName');
      print('추출된 갑옷명: $armorName');
    }
    
    final result = UserGameInfo(
      userId: int.tryParse(user['userId']?.toString() ?? '0') ?? 0,
      hp: user['hp'] ?? 0,
      maxHp: user['maxHp'] ?? (user['level'] ?? 1) * 100, // 백엔드에서 maxHp 제공, 없으면 level * 100
      exp: user['exp'] ?? 0,
      level: user['level'] ?? 1,
      gold: user['gold'] ?? 0,
      atk: inventory?['equippedWeapon']?['atk'] ?? 0,
      def: inventory?['equippedArmor']?['def'] ?? 0,
      inventory: inventory != null ? [inventory] : [],
      weaponName: weaponName,
      armorName: armorName,
    );
    
    print('생성된 UserGameInfo: $result');
    return result;
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'hp': hp,
      'maxHp': maxHp,
      'exp': exp,
      'level': level,
      'gold': gold,
      'atk': atk,
      'def': def,
      'inventory': inventory,
      'weaponName': weaponName,
      'armorName': armorName,
    };
  }
}
