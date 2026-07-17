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
/// ITEMS WITHOUT AN EXPIRY DATE: this heuristic is date-based, so it cannot
/// estimate risk for them — calculateLocalRisk returns null. Those items keep
/// the classification produced by the no-expiry ML model at add/edit time.
library risk_utils;

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
  static String? calculateLocalRisk({
    required DateTime purchaseDate,
    DateTime? expiryDate,
  }) {
    // No date to reason about — the caller should keep the ML prediction.
    if (expiryDate == null) return null;

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
}