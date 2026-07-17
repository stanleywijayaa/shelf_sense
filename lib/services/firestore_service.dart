import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/food_item.dart';
import '../core/utils/risk_utils.dart';
import 'notification_service.dart';

/// Handles all direct communication with Firestore for the food inventory.
/// This is the ONLY file that should call Firestore directly —
/// screens and providers should go through this service instead.
class FirestoreService {
  final CollectionReference _inventoryRef =
      FirebaseFirestore.instance.collection('inventory');

  /// Adds a new food item to Firestore.
  Future<void> addFoodItem(FoodItem item) async {
    // .add() generates the document ID; capture it so we can schedule a
    // notification tied to this specific item.
    final docRef = await _inventoryRef.add(item.toMap());
    final savedItem = item.copyWith(id: docRef.id);
    await NotificationService.scheduleForItem(savedItem);
  }

  /// Returns a real-time stream of all food items in the inventory.
  ///
  /// SORTING IS DONE CLIENT-SIDE, deliberately. A Firestore
  /// `.orderBy('expiryDate')` would silently EXCLUDE documents whose
  /// expiryDate is null — items without an expiry date would vanish from
  /// the inventory entirely. Sorting in Dart keeps them, placed last.
  ///
  /// Risk is RECALCULATED locally on every read using the current date, so
  /// the displayed risk stays current as items approach expiry without
  /// calling the ML API per item. Items with no expiry date are estimated
  /// from their category's typical shelf life adjusted for storage type,
  /// so they age over time too rather than being frozen at the value the
  /// no-expiry model produced on the day they were added.
  Stream<List<FoodItem>> getFoodItems() {
    return _inventoryRef.snapshots().map((snapshot) {
      final items = snapshot.docs.map((doc) {
        final item =
            FoodItem.fromMap(doc.id, doc.data() as Map<String, dynamic>);

        final currentRisk = RiskUtils.calculateLocalRisk(
          purchaseDate: item.purchaseDate,
          expiryDate: item.expiryDate,
          category: item.category,
          storageType: item.storageType,
        );
        // Items WITH an expiry date use the date-based heuristic; items
        // without one use the category/storage shelf-life estimate. Both
        // age over time, so displayed risk stays current either way.
        return currentRisk == null
            ? item
            : item.copyWith(riskLevel: currentRisk);
      }).toList();

      // Soonest-to-expire first; items without an expiry date go last.
      items.sort((a, b) {
        if (a.expiryDate == null && b.expiryDate == null) return 0;
        if (a.expiryDate == null) return 1;
        if (b.expiryDate == null) return -1;
        return a.expiryDate!.compareTo(b.expiryDate!);
      });

      return items;
    });
  }

  /// Updates an existing food item by its document ID.
  Future<void> updateFoodItem(FoodItem item) async {
    await _inventoryRef.doc(item.id).update(item.toMap());
    // Reschedule in case the expiry date changed (or was removed).
    await NotificationService.cancelForItem(item.id);
    await NotificationService.scheduleForItem(item);
  }

  /// Deletes a food item by its document ID.
  Future<void> deleteFoodItem(String id) async {
    await _inventoryRef.doc(id).delete();
    await NotificationService.cancelForItem(id);
  }
}