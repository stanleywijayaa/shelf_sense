/// Estimated shelf life per food category, used to reason about items that
/// have NO expiry date.
///
/// The base figures are the median `shelf_life_days` per category derived
/// from the training dataset during preprocessing — the same values exported
/// to ml_backend/model/category_stats.json. Keeping them here lets the app
/// estimate risk offline, without calling the ML API.
///
/// The storage adjustments are DOMAIN KNOWLEDGE, not learned from data:
/// freezing greatly extends shelf life, while storing a perishable item at
/// ambient temperature greatly shortens it. This encodes the "deli meat in
/// a pantry is dangerous" reasoning that the ML model cannot capture, since
/// the dataset's spoilage risk is driven by continuous temperature history
/// the app has no access to.
class ShelfLifeEstimates {
  /// Median shelf life in days per category (from the training dataset).
  static const Map<String, double> _baseDays = {
    'Bakery': 4,
    'Beverages': 18,
    'Dairy': 17,
    'Deli': 9,
    'Frozen_Meals': 212,
    'Meat': 6,
    'Produce': 12,
    'Ready_to_Eat': 3,
    'Seafood': 5,
  };

  /// Categories the dataset marks as highly perishable
  /// (spoilage_sensitivity >= 0.70). These degrade fastest when stored
  /// at ambient temperature.
  static const Set<String> _perishable = {
    'Dairy',
    'Deli',
    'Meat',
    'Ready_to_Eat',
    'Seafood',
  };

  /// Multiplier applied when an item is frozen.
  static const double _freezerFactor = 8.0;

  /// Multiplier applied when a PERISHABLE item sits at room temperature.
  static const double _pantryPerishableFactor = 0.4;

  /// Fallback for an unrecognised category.
  static const double _defaultDays = 7;

  /// Estimated total shelf life (days) for a category in a given storage.
  static double estimateDays(String category, String storageType) {
    final base = _baseDays[category] ?? _defaultDays;

    switch (storageType) {
      case 'Freezer':
        return base * _freezerFactor;
      case 'Pantry':
        // Perishables kept out of the fridge spoil far faster.
        return _perishable.contains(category)
            ? base * _pantryPerishableFactor
            : base;
      case 'Fridge':
      default:
        // The dataset medians reflect refrigerated storage, so no adjustment.
        return base;
    }
  }
}