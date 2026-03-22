class CategoryModel {
  String id;
  String name;
  String? iconName; // Optional: for future icon support
  String? colorHex; // Optional: for future color customization

  CategoryModel({
    required this.id,
    required this.name,
    this.iconName,
    this.colorHex,
  });

  // Convert Firestore Document to CategoryModel
  factory CategoryModel.fromMap(Map<String, dynamic> data, String documentId) {
    return CategoryModel(
      id: documentId,
      name: data['name'] ?? '',
      iconName: data['iconName'],
      colorHex: data['colorHex'],
    );
  }

  // Convert CategoryModel to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'iconName': iconName,
      'colorHex': colorHex,
    };
  }
}
