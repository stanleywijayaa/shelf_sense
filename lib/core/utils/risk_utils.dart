/// MOCK / PLACEHOLDER RISK LOGIC
/// ─────────────────────────────────────────────────────────────────────────
/// This is a temporary, rule-based risk calculator used ONLY for UI testing
/// while the real Machine Learning model (Phase 4) is being developed.
///
/// It estimates spoilage risk purely from how close `expiryDate` is to today,
/// relative to the total shelf life (the gap between purchaseDate and
/// expiryDate). This has no relation to the actual ML approach — it does NOT
/// consider food type, storage condition, or any trained patterns.
///
/// TODO: Replace calls to `calculateMockRisk()` with a real API call to
/// the FastAPI ML service (see services/ml_service.dart) once the model
/// is trained and deployed. Once that's wired in, this file can be deleted
/// or kept only as a fallback for offline/demo mode.
library risk_utils;
 
class RiskUtils {
  /// Returns "Low", "Medium", or "High" based on how much of the item's
  /// shelf life has elapsed.
  ///
  /// Logic:
  /// - Already expired           -> High
  /// - <= 20% of shelf life left -> High
  /// - <= 50% of shelf life left -> Medium
  /// - > 50% of shelf life left  -> Low
  static String calculateMockRisk({
    required DateTime purchaseDate,
    required DateTime expiryDate,
  }) {
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