/// Rule-based spoilage risk fallback.
///
/// Used when the ML service is unavailable and when inventory data is
/// re-read so the displayed risk stays current. Items without an expiry date
/// use a category-based shelf-life estimate instead.
library risk_utils;

import '../constants/shelf_life_estimates.dart';

class RiskUtils {
  /// Returns "Low", "Medium", or "High" from the item's shelf-life progress.
  /// Returns null when there is no expiry date and no fallback estimate.
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
    final expiry = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);

    if (today.isAfter(expiry)) {
      return 'High';
    }

    final totalShelfLifeDays = expiry.difference(purchase).inDays;
    final daysRemaining = expiry.difference(today).inDays;

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

  /// Estimates risk for items without an expiry date.
  ///
  /// Uses category and storage type to approximate shelf life.
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

    final estimatedShelfLife = ShelfLifeEstimates.estimateDays(
      category,
      storageType,
    );
    if (estimatedShelfLife <= 0) return 'High';

    final daysElapsed = today.difference(purchase).inDays;
    final remainingRatio =
        (estimatedShelfLife - daysElapsed) / estimatedShelfLife;

    if (remainingRatio <= 0.2) return 'High';
    if (remainingRatio <= 0.5) return 'Medium';
    return 'Low';
  }
}


