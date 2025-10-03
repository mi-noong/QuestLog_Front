class InventoryItem {
  final String id;
  final String name;
  final String type; // 'weapon', 'armor', 'potion' 등
  final String imagePath;
  final bool isEquipped;

  InventoryItem({
    required this.id,
    required this.name,
    required this.type,
    required this.imagePath,
    this.isEquipped = false,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    return InventoryItem(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      imagePath: json['imagePath'] ?? '',
      isEquipped: json['isEquipped'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'imagePath': imagePath,
      'isEquipped': isEquipped,
    };
  }

  InventoryItem copyWith({
    String? id,
    String? name,
    String? type,
    String? imagePath,
    bool? isEquipped,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      imagePath: imagePath ?? this.imagePath,
      isEquipped: isEquipped ?? this.isEquipped,
    );
  }
}
