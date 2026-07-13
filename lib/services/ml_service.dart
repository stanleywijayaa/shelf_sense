import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/food_item.dart';
import '../core/utils/risk_utils.dart';
 
/// Talks to the ShelfSense FastAPI ML backend to get a real spoilage-risk
/// prediction for a food item. Falls back to the local rule-based estimate
/// (risk_utils.dart) if the API is unreachable — so the app still works
/// offline or when the ML server isn't running (e.g. during a demo).
class MlService {
  /// Base URL of the FastAPI server.
  ///
  /// IMPORTANT — this depends on where you run the app:
  ///  - Android emulator:      http://10.0.2.2:8000   (special alias for host)
  ///  - Real device (your A71): http://<your-PC-LAN-IP>:8000
  ///        e.g. http://192.168.1.5:8000  — find it with `ipconfig` on Windows
  ///        (the IPv4 address). The phone and PC must be on the same Wi-Fi.
  ///  - localhost does NOT work from a phone — that points to the phone itself.
  /// "http://localhost:8000" if you run the app in a web browser on the same machine as the server.
  static const String _baseUrl = "http://localhost:8000";
 
  /// How long to wait for the API before giving up and using the fallback.
  static const Duration _timeout = Duration(seconds: 5);
 
  /// Returns "Low", "Medium", or "High" for the given item.
  /// Tries the ML API first; on any failure, uses the local mock estimate.
  static Future<String> predictRisk(FoodItem item) async {
    // Derive the date features the API expects, from the item's dates.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
 
    final purchase = DateTime(
      item.purchaseDate.year,
      item.purchaseDate.month,
      item.purchaseDate.day,
    );
    final expiry = DateTime(
      item.expiryDate.year,
      item.expiryDate.month,
      item.expiryDate.day,
    );
 
    final daysSincePurchase = today.difference(purchase).inDays;
    final daysUntilExpiry = expiry.difference(today).inDays;
 
    try {
      final response = await http
          .post(
            Uri.parse("$_baseUrl/predict"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "category": item.category,
              "storage_type": item.storageType,
              // clamp to >= 0 since the API requires days_since_purchase >= 0
              "days_since_purchase":
                  daysSincePurchase < 0 ? 0 : daysSincePurchase,
              "days_until_expiry": daysUntilExpiry,
            }),
          )
          .timeout(_timeout);
 
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final risk = data["risk_level"];
        if (risk is String && risk.isNotEmpty) {
          return risk;
        }
      }
      // Unexpected response — fall through to the local estimate.
      return _fallback(item);
    } on SocketException {
      // No network / server unreachable.
      return _fallback(item);
    } catch (_) {
      // Timeout, bad JSON, or anything else — stay resilient.
      return _fallback(item);
    }
  }
 
  /// Local rule-based estimate used when the ML API can't be reached.
  static String _fallback(FoodItem item) {
    return RiskUtils.calculateLocalRisk(
      purchaseDate: item.purchaseDate,
      expiryDate: item.expiryDate,
    );
  }
}