import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/food_item.dart';
import '../core/utils/risk_utils.dart';

/// Calls the ShelfSense ML backend for spoilage risk.
class MlService {
  /// Base URL of the FastAPI server.
  ///  - Flutter web / Chrome:   http://localhost:8000
  ///  - Android emulator:       http://10.0.2.2:8000  (alias for the host PC)
  ///  - Real device : http://<your-PC-LAN-IP>:8000
  static const String _baseUrl = "http://192.168.100.11:8000";

  /// How long to wait for the API before giving up and using the fallback.
  static const Duration _timeout = Duration(seconds: 5);

  /// Returns "Low", "Medium", or "High" for the given item.
  static Future<String> predictRisk(FoodItem item) async {
    // Build date fields expected by the API.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final purchase = DateTime(
      item.purchaseDate.year,
      item.purchaseDate.month,
      item.purchaseDate.day,
    );
    final daysSincePurchase = today.difference(purchase).inDays;

    // Null if no expiry date; server uses the no-expiry model.
    int? daysUntilExpiry;
    if (item.expiryDate != null) {
      final expiry = DateTime(
        item.expiryDate!.year,
        item.expiryDate!.month,
        item.expiryDate!.day,
      );
      daysUntilExpiry = expiry.difference(today).inDays;
    }

    debugPrint('[ML] predictRisk: ${item.name} | cat=${item.category} '
        'storage=${item.storageType} daysSince=$daysSincePurchase '
        'daysUntilExpiry=${daysUntilExpiry ?? "none"}');

    try {
      final response = await http
          .post(
            Uri.parse("$_baseUrl/predict"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "category": item.category,
              "storage_type": item.storageType,
              // Keep value non-negative for API validation.
              "days_since_purchase":
                  daysSincePurchase < 0 ? 0 : daysSincePurchase,
              // Null means use the no-expiry model.
              "days_until_expiry": daysUntilExpiry,
            }),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final risk = data["risk_level"];
        final modelUsed = data["model_used"];
        if (risk is String && risk.isNotEmpty) {
          debugPrint('[ML] API responded: risk=$risk '
              'model=${modelUsed ?? "?"} (HTTP 200)');
          return risk;
        }
      }
      // Unexpected response, use local estimate.
      debugPrint('[ML] unexpected response (HTTP ${response.statusCode}) '
          '-> using local fallback');
      return _fallback(item);
    } on SocketException {
      // Network/server unavailable.
      debugPrint('[ML] SocketException (server unreachable) '
          '-> using local fallback');
      return _fallback(item);
    } catch (e) {
      // Any other error, use local estimate.
      debugPrint('[ML] error ($e) -> using local fallback');
      return _fallback(item);
    }
  }

  /// Local estimate used when ML API is unavailable.
  /// Uses expiry data when present, otherwise category/storage defaults.
  static String _fallback(FoodItem item) {
    final result = RiskUtils.calculateLocalRisk(
          purchaseDate: item.purchaseDate,
          expiryDate: item.expiryDate,
          category: item.category,
          storageType: item.storageType,
        ) ??
        'Unknown';
    debugPrint('[ML] local fallback result: $result '
        '(${item.expiryDate != null ? "dated heuristic" : "undated estimate"})');
    return result;
  }
}