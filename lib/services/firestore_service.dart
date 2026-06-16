import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/food_item.dart';
 
/// Handles all direct communication with Firestore for the food inventory.
/// This is the ONLY file that should call Firestore directly —
/// screens and providers should go through this service instead.
class FirestoreService {
  final CollectionReference _inventoryRef =
      FirebaseFirestore.instance.collection('inventory');
 
  /// Adds a new food item to Firestore.
  /// Firestore auto-generates the document ID, so we don't need to
  /// supply one — `item.id` can be left empty when creating a new item.
  Future<void> addFoodItem(FoodItem item) async {
    await _inventoryRef.add(item.toMap());
  }
 
  /// Returns a real-time stream of all food items in the inventory.
  /// Using a Stream (instead of a one-time fetch) means the UI
  /// automatically updates whenever Firestore data changes —
  /// no manual refresh needed.
  Stream<List<FoodItem>> getFoodItems() {
    return _inventoryRef
        .orderBy('expiryDate') // soonest-to-expire items first
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return FoodItem.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();
    });
  }
 
  /// Updates an existing food item by its document ID.
  Future<void> updateFoodItem(FoodItem item) async {
    await _inventoryRef.doc(item.id).update(item.toMap());
  }
 
  /// Deletes a food item by its document ID.
  Future<void> deleteFoodItem(String id) async {
    await _inventoryRef.doc(id).delete();
  }
}