/// LOCAL RISK ESTIMATOR
/// ─────────────────────────────────────────────────────────────────────────
/// A lightweight, rule-based spoilage-risk estimator. This is a PERMANENT
/// part of the app's architecture, serving two roles:
///
///   1. Offline fallback — when the FastAPI ML service is unreachable
///      (server offline, no network, timeout), MlService uses this so the
///      app keeps working. See services/ml_service.dart.
///
///   2. Dynamic recalculation on read — FirestoreService recomputes each
///      item's risk from its dates against the current date every time the
///      inventory is loaded, so the displayed risk stays current as items
///      approach expiry without calling the ML API per item.
///      See services/firestore_service.dart.
///
/// It estimates risk purely from how close `expiryDate` is to today relative
/// to the item's total shelf life. Unlike the ML model, it does NOT consider
/// food category or storage condition — it is intentionally simple, fast, and
/// deterministic. The authoritative ML classification is applied at add/edit
/// time (via the FastAPI service); this estimator keeps the display fresh and
/// resilient between those events.
///
/// ITEMS WITHOUT AN EXPIRY DATE are handled by a second, rule-based path
/// (see _estimateWithoutExpiry). Instead of a real expiry, it uses the
/// category's typical shelf life adjusted for storage type — so these items
/// still age over time and still get a sensible offline estimate, rather
/// than being frozen at whatever the ML model said on the day they were
/// added.
library risk_utils;

import '../constants/shelf_life_estimates.dart';

class RiskUtils {
  /// Returns "Low", "Medium", or "High" based on how much of the item's
  /// shelf life has elapsed, or NULL when the item has no expiry date.
  ///
  /// Logic:
  /// - No expiry date            -> null (caller keeps the stored ML value)
  /// - Already expired           -> High
  /// - <= 20% of shelf life left -> High
  /// - <= 50% of shelf life left -> Medium
  /// - > 50% of shelf life left  -> Low
  /// `category` and `storageType` are only needed for items with no expiry
  /// date; they let the estimator fall back to typical shelf life.
  static String? calculateLocalRisk({
    required DateTime purchaseDate,
    DateTime? expiryDate,
    String? category,
    String? storageType,
  }) {
    if (expiryDate == null) {
      return _estimateWithoutExpiry(
        purchaseDate: purchaseDate,
        category: category,
        storageType: storageType,
      );
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final purchase = DateTime(
      purchaseDate.year,
      purchaseDate.month,
      purchaseDate.day,
    );
    final expiry = DateTime(
      expiryDate.year,
      expiryDate.month,
      expiryDate.day,
    );

    // Already expired -> automatically High risk
    if (today.isAfter(expiry)) {
      return 'High';
    }

    final totalShelfLifeDays = expiry.difference(purchase).inDays;
    final daysRemaining = expiry.difference(today).inDays;

    // Guard against division by zero (e.g. purchase date == expiry date)
    if (totalShelfLifeDays <= 0) {
      return 'High';
    }

    final remainingRatio = daysRemaining / totalShelfLifeDays;

    if (remainingRatio <= 0.2) {
      return 'High';
    } else if (remainingRatio <= 0.5) {
      return 'Medium';
    } else {
      return 'Low';
    }
  }

  /// Rule-based estimate for items with NO expiry date.
  ///
  /// Uses the same "proportion of shelf life remaining" logic as the dated
  /// path, but substitutes an ESTIMATED shelf life (category median, adjusted
  /// for storage) for a real expiry date. Returns null only if the caller
  /// couldn't supply category/storage, in which case there is nothing to
  /// reason from.
  ///
  /// This is a deliberate business-rule layer: it encodes domain knowledge
  /// the ML model cannot express — notably that a perishable item stored in
  /// a pantry degrades far faster — because the dataset's risk is driven by
  /// continuous temperature history that a manual-entry app cannot supply.
  static String? _estimateWithoutExpiry({
    required DateTime purchaseDate,
    String? category,
    String? storageType,
  }) {
    if (category == null || storageType == null) return null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final purchase = DateTime(
      purchaseDate.year,
      purchaseDate.month,
      purchaseDate.day,
    );

    final estimatedShelfLife =
        ShelfLifeEstimates.estimateDays(category, storageType);
    if (estimatedShelfLife <= 0) return 'High';

    final daysElapsed = today.difference(purchase).inDays;
    final remainingRatio =
        (estimatedShelfLife - daysElapsed) / estimatedShelfLife;

    // Past its typical shelf life -> High.
    if (remainingRatio <= 0.2) return 'High';
    if (remainingRatio <= 0.5) return 'Medium';
    return 'Low';
  }
}