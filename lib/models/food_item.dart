import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single food item stored in the user's inventory.
class FoodItem {
  final String id;
  final String name;
  final String category;       // e.g. Dairy, Vegetable, Meat, Grain
  final String storageType;    // e.g. Fridge, Freezer, Pantry
  final DateTime purchaseDate;
  final DateTime expiryDate;
  final String riskLevel;      // "Low" | "Medium" | "High" (placeholder until ML is wired in)

  FoodItem({
    required this.id,
    required this.name,
    required this.category,
    required this.storageType,
    required this.purchaseDate,
    required this.expiryDate,
    this.riskLevel = "Unknown",
  });

  /// Converts this object into a Map so it can be written to Firestore.
  /// Dates are stored as Firestore Timestamps, not raw DateTime,
  /// since Firestore doesn't natively support Dart's DateTime type.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'storageType': storageType,
      'purchaseDate': Timestamp.fromDate(purchaseDate),
      'expiryDate': Timestamp.fromDate(expiryDate),
      'riskLevel': riskLevel,
    };
  }

  /// Builds a FoodItem from a Firestore document snapshot.
  /// This is used when reading data back out of Firestore.
  factory FoodItem.fromMap(String id, Map<String, dynamic> map) {
    return FoodItem(
      id: id,
      name: map['name'] ?? '',
      category: map['category'] ?? '',
      storageType: map['storageType'] ?? '',
      purchaseDate: (map['purchaseDate'] as Timestamp).toDate(),
      expiryDate: (map['expiryDate'] as Timestamp).toDate(),
      riskLevel: map['riskLevel'] ?? 'Unknown',
    );
  }

  /// Convenience helper: a copy of this item with some fields replaced.
  /// Useful later when updating risk level after calling the ML API,
  /// without having to rebuild the whole object manually.
  FoodItem copyWith({
    String? id,
    String? name,
    String? category,
    String? storageType,
    DateTime? purchaseDate,
    DateTime? expiryDate,
    String? riskLevel,
  }) {
    return FoodItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      storageType: storageType ?? this.storageType,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      expiryDate: expiryDate ?? this.expiryDate,
      riskLevel: riskLevel ?? this.riskLevel,
    );
  }
}