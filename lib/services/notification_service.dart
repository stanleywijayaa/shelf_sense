import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../models/food_item.dart';

/// Handles local (on-device) notifications that alert the user before a food
/// item expires. No server or internet needed — the device's OS fires these
/// at the scheduled time, even if the app is closed.
///
/// Strategy: when an item is added/edited, schedule a notification for a set
/// number of days BEFORE its expiry date. When an item is deleted, cancel it.
///
/// Note: local notifications work on real devices (Android/iOS). They do NOT
/// work on Flutter web, so test this on the phone.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// How many days before expiry to fire the reminder.
  static const int daysBeforeExpiry = 2;

  /// Call once at app startup (in main.dart) before scheduling anything.
  static Future<void> init() async {
    // Set up timezone data so scheduled times are correct.
    tz_data.initializeTimeZones();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings);

    // Android 13+ requires explicitly requesting notification permission.
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Schedule a reminder for a single food item, a few days before it expires.
  /// Uses a stable integer id derived from the item's Firestore id so we can
  /// cancel/replace it later.
  static Future<void> scheduleForItem(FoodItem item) async {
    final notifyDate = item.expiryDate.subtract(
      const Duration(days: daysBeforeExpiry),
    );

    // Don't schedule for a time already in the past.
    if (notifyDate.isBefore(DateTime.now())) return;

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
      // uiLocalNotificationDateInterpretation is required on iOS.
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Cancel the scheduled notification for an item (e.g. when it's deleted).
  static Future<void> cancelForItem(String itemId) async {
    await _plugin.cancel(_notificationId(itemId));
  }

  /// Cancel everything (useful if you ever need a clean slate).
  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// Turns a Firestore document id (a string) into a stable notification id
  /// (an int), since the plugin identifies notifications by int.
  static int _notificationId(String itemId) {
    // hashCode can be negative; make it a positive 31-bit int.
    return itemId.hashCode & 0x7fffffff;
  }
}