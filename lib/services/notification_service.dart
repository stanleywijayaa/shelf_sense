import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../models/food_item.dart';

/// Local on-device notifications for upcoming food expiry.
/// Schedules reminders daysBeforeExpiry before expiry and cancels on delete.
/// Works on Android/iOS (not supported on web).
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Days before expiry to trigger the reminder.
  static const int daysBeforeExpiry = 2;

  /// Initialize the plugin; call once at app startup.
  static Future<void> init() async {
    // Initialize timezone data.
    tz_data.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings);

    // Request Android notification permission (Android 13+).
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  /// Schedule a reminder daysBeforeExpiry before an item's expiry.
  /// Uses a stable int id derived from the item's Firestore id.
  static Future<void> scheduleForItem(FoodItem item) async {
    // Skip items with no expiry date.
    if (item.expiryDate == null) {
      debugPrint('[NOTIF] skip "${item.name}": no expiry date');
      return;
    }

    final notifyDate = item.expiryDate!.subtract(
      const Duration(days: daysBeforeExpiry),
    );

    // Skip notify dates that are in the past.
    if (notifyDate.isBefore(DateTime.now())) {
      debugPrint(
        '[NOTIF] skip "${item.name}": notify date $notifyDate '
        'is in the past',
      );
      return;
    }

    final scheduledTime = tz.TZDateTime.from(notifyDate, tz.local);

    const androidDetails = AndroidNotificationDetails(
      'shelfsense_expiry',
      'Expiry Reminders',
      channelDescription: 'Alerts for food items approaching their expiry date',
      importance: Importance.high,
      priority: Priority.high,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.zonedSchedule(
      _notificationId(item.id),
      'Food expiring soon',
      '${item.name} expires in $daysBeforeExpiry days. Use it before it spoils!',
      scheduledTime,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      // Required on iOS.
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    debugPrint(
      '[NOTIF] scheduled "${item.name}" for $scheduledTime '
      '(id=${_notificationId(item.id)})',
    );
  }

  /// Cancel the scheduled notification for an item.
  static Future<void> cancelForItem(String itemId) async {
    await _plugin.cancel(_notificationId(itemId));
    debugPrint('[NOTIF] cancelled id=${_notificationId(itemId)}');
  }

  /// Cancel all scheduled notifications.
  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// Convert a Firestore document id to a stable positive int id.
  static int _notificationId(String itemId) {
    // hashCode can be negative; make it a positive 31-bit int.
    return itemId.hashCode & 0x7fffffff;
  }
}
