/// Food categories used across the app.
///
/// IMPORTANT — two-layer design:
///   * `values`  are the RAW strings the ML model was trained on and that
///     get written to Firestore (e.g. "Frozen_Meals"). These must NEVER
///     change, or predictions and recipe matching break.
///   * `label()` returns the friendly text shown to the user
///     (e.g. "Frozen Meals"). Display only.
///
/// This keeps the underscores and supermarket jargon out of the UI while
/// preserving exact train/serve consistency underneath.
class FoodCategories {
  /// The nine categories the model knows, in the order shown to users.
  static const List<String> values = [
    'Produce',
    'Dairy',
    'Meat',
    'Seafood',
    'Bakery',
    'Deli',
    'Frozen_Meals',
    'Ready_to_Eat',
    'Beverages',
  ];

  static const Map<String, String> _labels = {
    'Produce': 'Fruits & Vegetables',
    'Dairy': 'Dairy',
    'Meat': 'Meat & Poultry',
    'Seafood': 'Fish & Seafood',
    'Bakery': 'Bread & Bakery',
    'Deli': 'Deli & Cold Cuts',
    'Frozen_Meals': 'Frozen Meals',
    'Ready_to_Eat': 'Ready-to-Eat',
    'Beverages': 'Drinks',
  };

  /// Friendly display text for a stored category value.
  /// Falls back to replacing underscores if an unknown value appears
  /// (e.g. legacy data), so the UI never shows a raw "Some_Value".
  static String label(String value) {
    return _labels[value] ?? value.replaceAll('_', ' ');
  }
}