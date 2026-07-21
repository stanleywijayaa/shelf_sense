import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/food_item.dart';
import '../core/utils/risk_utils.dart';
import 'notification_service.dart';

/// Handles Firestore access for the food inventory.
class FirestoreService {
  /// Inventory is per signed-in user at users/{uid}/inventory.
  CollectionReference get _inventoryRef {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('inventory');
  }

  /// Adds a new food item.
  /// Uses a local doc ID and does not await the server write (offline-safe).
  Future<void> addFoodItem(FoodItem item) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final docRef = _inventoryRef.doc(); // ID generated locally, instantly
    final savedItem = item.copyWith(id: docRef.id);

    debugPrint('[FIRESTORE] addFoodItem "${item.name}" '
        'id=${docRef.id} under users/$uid/inventory');

    // Trigger write without waiting for server acknowledgment.
    docRef.set(savedItem.toMap()).then((_) {
      debugPrint('[FIRESTORE] add synced to server: ${docRef.id}');
    }).catchError((e) {
      // Ignore remote write failures to avoid blocking the UI.
      debugPrint('[FIRESTORE] add write error (queued locally): $e');
    });

    // Notification scheduling is local, so it is awaited.
    await NotificationService.scheduleForItem(savedItem);
  }

  /// Returns a real-time stream of food items.
  /// Sorts in Dart so null expiry dates are kept (placed last).
  /// Recalculates risk locally so values stay current over time.
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
        // Keep displayed risk updated based on current date.
        return currentRisk == null
            ? item
            : item.copyWith(riskLevel: currentRisk);
      }).toList();

      // Soonest expiry first; null expiry dates last.
      items.sort((a, b) {
        if (a.expiryDate == null && b.expiryDate == null) return 0;
        if (a.expiryDate == null) return 1;
        if (b.expiryDate == null) return -1;
        return a.expiryDate!.compareTo(b.expiryDate!);
      });

      return items;
    });
  }

  /// Updates a food item by document ID.
  /// Does not await the server write (offline-safe).
  Future<void> updateFoodItem(FoodItem item) async {
    debugPrint('[FIRESTORE] updateFoodItem "${item.name}" id=${item.id}');
    _inventoryRef.doc(item.id).update(item.toMap()).catchError((e) {
      debugPrint('[FIRESTORE] update write error (queued locally): $e');
    });

    // Reschedule in case the expiry date changed (or was removed).
    await NotificationService.cancelForItem(item.id);
    await NotificationService.scheduleForItem(item);
  }

  /// Deletes a food item by document ID.
  /// Does not await the server delete (offline-safe).
  Future<void> deleteFoodItem(String id) async {
    debugPrint('[FIRESTORE] deleteFoodItem id=$id');
    _inventoryRef.doc(id).delete().catchError((e) {
      debugPrint('[FIRESTORE] delete write error (queued locally): $e');
    });
    await NotificationService.cancelForItem(id);
  }
}