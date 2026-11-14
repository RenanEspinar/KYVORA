import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// One native Android reminder per ongoing workout; independent of Flutter timers.
/// Keeps the legacy application ID so existing accounts and data are unaffected.
class RestAlerts {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'kyvora_rest_v1',
      'Descansos KYVORA',
      channelDescription: 'Avisos cuando termina el descanso entre series.',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  Future<void> init() async {
    if (!Platform.isAndroid) return;
    try {
      tzdata.initializeTimeZones();
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('kyvora_notification'),
        ),
      );
      _ready = true;
    } catch (_) {
      // A notification initialization error must not block opening KYVORA.
      _ready = false;
    }
  }

  int _notificationId(String workoutId) {
    // Deterministic across restarts; Android notification IDs are signed 32-bit.
    var hash = 2166136261;
    for (final c in workoutId.codeUnits) {
      hash = ((hash ^ c) * 16777619) & 0x7fffffff;
    }
    return hash;
  }

  Future<bool> requestNotifications() async {
    if (!_ready) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestPreciseAlarms() async {
    if (!_ready) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestExactAlarmsPermission() ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> cancel(String workoutId) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(_notificationId(workoutId));
    } catch (_) {}
  }

  Future<void> schedule(String workoutId, int restSeconds) async {
    if (!_ready) return;
    await cancel(workoutId);
    if (restSeconds <= 0) return;
    if (!await requestNotifications()) return;

    // UTC retains the correct instant even in countries with DST.
    final instant = tz.TZDateTime.from(
      DateTime.now().toUtc().add(Duration(seconds: restSeconds)),
      tz.UTC,
    );
    final id = _notificationId(workoutId);

    Future<void> add(AndroidScheduleMode mode) => _plugin.zonedSchedule(
      id,
      'KYVORA · descanso terminado',
      'Tu siguiente serie te espera.',
      instant,
      _details,
      androidScheduleMode: mode,
    );

    try {
      // Exact alarms require explicit Android authorization on newer devices.
      await add(AndroidScheduleMode.exactAllowWhileIdle);
    } catch (_) {
      // Degrade gracefully when exact-alarm permission was not granted.
      try {
        await add(AndroidScheduleMode.inexactAllowWhileIdle);
      } catch (_) {}
    }
  }
}

final restAlerts = RestAlerts();
