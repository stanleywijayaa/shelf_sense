import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single food item stored in the user's inventory.
///
/// `expiryDate` is OPTIONAL: many household items (loose produce, bulk
/// goods, homemade food) carry no printed date. When it's null the app
/// uses the no-expiry ML model, hides day countdowns, and skips expiry
/// reminders — see MlService, RiskUtils and NotificationService.
class FoodItem {
  final String id;
  final String name;
  final String category;       // e.g. Dairy, Meat, Produce
  final String storageType;    // Fridge, Freezer, Pantry
  final DateTime purchaseDate;
  final DateTime? expiryDate;  // null when the item has no expiry date
  final String riskLevel;      // "Low" | "Medium" | "High"

  FoodItem({
    required this.id,
    required this.name,
    required this.category,
    required this.storageType,
    required this.purchaseDate,
    this.expiryDate,
    this.riskLevel = "Unknown",
  });

  /// True when this item has no expiry date and therefore relies on the
  /// no-expiry model / has no countdown to display.
  bool get hasExpiryDate => expiryDate != null;

  /// Converts this object into a Map so it can be written to Firestore.
  /// Dates are stored as Firestore Timestamps; a null expiry is stored as
  /// null so the field still exists on the document.
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'storageType': storageType,
      'purchaseDate': Timestamp.fromDate(purchaseDate),
      'expiryDate':
          expiryDate == null ? null : Timestamp.fromDate(expiryDate!),
      'riskLevel': riskLevel,
    };
  }

  /// Builds a FoodItem from a Firestore document snapshot.
  factory FoodItem.fromMap(String id, Map<String, dynamic> map) {
    final rawExpiry = map['expiryDate'];
    return FoodItem(
      id: id,
      name: map['name'] ?? '',
      category: map['category'] ?? '',
      storageType: map['storageType'] ?? '',
      purchaseDate: (map['purchaseDate'] as Timestamp).toDate(),
      expiryDate:
          rawExpiry == null ? null : (rawExpiry as Timestamp).toDate(),
      riskLevel: map['riskLevel'] ?? 'Unknown',
    );
  }

  /// A copy of this item with some fields replaced.
  ///
  /// Note `clearExpiry`: because `expiryDate` is nullable, passing null
  /// can't distinguish "leave unchanged" from "remove the date", so an
  /// explicit flag is used to clear it.
  FoodItem copyWith({
    String? id,
    String? name,
    String? category,
    String? storageType,
    DateTime? purchaseDate,
    DateTime? expiryDate,
    bool clearExpiry = false,
    String? riskLevel,
  }) {
    return FoodItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      storageType: storageType ?? this.storageType,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      expiryDate: clearExpiry ? null : (expiryDate ?? this.expiryDate),
      riskLevel: riskLevel ?? this.riskLevel,
    );
  }
}