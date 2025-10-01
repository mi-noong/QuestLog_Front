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

// 아이템 구매 API
Future<bool> purchaseItem(int userId, String itemId) async {
  try {
    final response = await http.post(
      Uri.parse('$baseUrl/api/game/shop/purchase'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'userId': userId,
        'itemId': itemId,
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['success'] == true;
    }
    return false;
  } catch (e) {
    print('아이템 구매 오류: $e');
    return false;
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

  void _showBuyDialog(ShopItem item) {
    setState(() {
      selectedItem = item;
      showBuyDialog = true;
    });
  }

  void _hideBuyDialog() {
    setState(() {
      showBuyDialog = false;
      selectedItem = null;
    });
  }

  void _showPurchaseCompleteDialog() {
    setState(() {
      showPurchaseCompleteDialog = true;
    });
  }

  void _hidePurchaseCompleteDialog() {
    setState(() {
      showPurchaseCompleteDialog = false;
    });
  }

  Future<void> _handlePurchase() async {
    if (selectedItem != null) {
      // 백엔드 API 호출 후 결과에 따라 처리
      bool success = await purchaseItem(1, selectedItem!.itemId);
      
      _hideBuyDialog();
      
      if (success) {
        _showPurchaseCompleteDialog();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('구매 실패: 골드가 부족하거나 오류가 발생했습니다.')),
        );
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
                    // Shop 제목 (가운데)
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
                        // 태블릿: 기존 레이아웃 유지
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // 첫 번째 줄: Leather Armor, Wooden Sword
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildShopItem(
                                  'assets/images/StoreItemFrame.png',
                                  'assets/images/Leather_Armor.png',
                                  'Leather Armor',
                                  10,
                                  ShopItem(
                                    itemId: 'leather_armor',
                                    name: 'Leather Armor',
                                    description: '가죽 갑옷',
                                    price: 10,
                                    itemType: 'ARMOR',
                                  ),
                                ),
                                _buildShopItem(
                                  'assets/images/StoreItemFrame.png',
                                  'assets/images/wooden_sword.png',
                                  'Wooden Sword',
                                  10,
                                  ShopItem(
                                    itemId: 'wooden_sword',
                                    name: 'Wooden Sword',
                                    description: '나무 검',
                                    price: 10,
                                    itemType: 'WEAPON',
                                  ),
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
                        // 스마트폰: 세로 배치로 변경
                        return SingleChildScrollView(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 20),
                              _buildShopItem(
                                'assets/images/StoreItemFrame.png',
                                'assets/images/Leather_Armor.png',
                                'Leather Armor',
                                10,
                                ShopItem(
                                  itemId: 'leather_armor',
                                  name: 'Leather Armor',
                                  description: '가죽 갑옷',
                                  price: 10,
                                  itemType: 'ARMOR',
                                ),
                              ),
                              const SizedBox(height: 20),
                              _buildShopItem(
                                'assets/images/StoreItemFrame.png',
                                'assets/images/wooden_sword.png',
                                'Wooden Sword',
                                10,
                                ShopItem(
                                  itemId: 'wooden_sword',
                                  name: 'Wooden Sword',
                                  description: '나무 검',
                                  price: 10,
                                  itemType: 'WEAPON',
                                ),
                              ),
                              const SizedBox(height: 20),
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
                              const SizedBox(height: 20),
                            ],
                          ),
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
    
    final itemWidth = isTablet ? 240.0 : screenWidth * 0.4;
    final itemHeight = isTablet ? 270.0 : itemWidth * 1.125; // 비율 유지
    final imageSize = isTablet ? 120.0 : itemWidth * 0.5;
    final fontSize = isTablet ? 21.0 : 16.0;
    final priceFontSize = isTablet ? 24.0 : 18.0;
    
    return GestureDetector(
      onTap: () => _showBuyDialog(shopItem),
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
              top: 15,
              left: 0,
              right: 0,
              child: Center(
                child: Image.asset(
                  itemPath,
                  width: imageSize,
                  height: imageSize,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            // 아이템 이름
            Positioned(
              top: isTablet ? 150.0 : itemHeight * 0.55, // 스마트폰에서는 비율로 조절
              left: 0,
              right: 0,
              child: Center(
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
            // 가격 (골드 아이콘 + 가격)
            Positioned(
              bottom: 15,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/Icon_Gold.png',
                    width: isTablet ? 30.0 : 24.0,
                    height: isTablet ? 30.0 : 24.0,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    price.toString(),
                    style: TextStyle(
                      fontSize: priceFontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      fontFamily: 'DungGeunMo',
                      decoration: TextDecoration.none,
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
                      onTap: _handlePurchase,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Image.asset(
                            'assets/images/StoreBuy_OK_Button.png',
                            width: 105,  // 70 * 1.5
                            height: 37,  // 25 * 1.5
                            fit: BoxFit.contain,
                          ),
                          const Text(
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
    switch (itemId) {
      case 'leather_armor':
        return 'assets/images/Leather_Armor.png';
      case 'wooden_sword':
        return 'assets/images/wooden_sword.png';
      case 'magic_potion':
        return 'assets/images/MagicPotion.png';
      default:
        return 'assets/images/Leather_Armor.png';
    }
  }
}
