import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_constants.dart';
import '../../../shared/models/task.dart';
import '../../../shared/models/habit.dart';
import '../../../shared/models/goal.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    try {
      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          // Handle notification click
        },
      );
      _isInitialized = true;
    } catch (_) {
      // Graceful fallback on unsupported platforms
    }
  }

  Future<bool> requestPermissions() async {
    await init();
    final android = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      final notificationsGranted = await android
          .requestNotificationsPermission();
      final exactAlarmsGranted = await android.requestExactAlarmsPermission();
      return (notificationsGranted ?? true) && (exactAlarmsGranted ?? true);
    }

    final ios = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return true;
  }

  Future<void> cancel(int id) async {
    try {
      await _notificationsPlugin.cancel(id);
    } catch (_) {}
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_isInitialized) await init();
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'my_journal_channel',
          'Pengingat My Journal',
          channelDescription:
              'Notifikasi harian untuk tugas, kebiasaan, dan jurnal',
          importance: Importance.max,
          priority: Priority.high,
        );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    try {
      await _notificationsPlugin.show(id, title, body, platformDetails);
    } catch (_) {}
  }

  Future<void> notifyEvent({required String title, required String body}) =>
      showNotification(
        id: _stableId('event:${DateTime.now().microsecondsSinceEpoch}:$title'),
        title: title,
        body: body,
      );

  Future<void> syncTaskReminders(List<Task> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final enabled =
        prefs.getBool(AppConstants.prefTaskDueNotifications) ?? true;
    final desired = <String, (Task, DateTime, bool)>{};
    if (enabled) {
      for (final task in tasks) {
        final reminderAt = task.scheduledAt.subtract(
          const Duration(minutes: 15),
        );
        if (!task.isCompleted && reminderAt.isAfter(DateTime.now())) {
          desired['task:${task.id}:before'] = (task, reminderAt, false);
        }
        if (!task.isCompleted && task.scheduledAt.isAfter(DateTime.now())) {
          desired['task:${task.id}:due'] = (task, task.scheduledAt, true);
        }
      }
    }
    await _removeObsolete('task:', desired.keys.toSet());
    for (final entry in desired.entries) {
      final (task, at, isDue) = entry.value;
      await _scheduleOnce(
        payload: entry.key,
        title: isDue
            ? 'Waktunya menyelesaikan tugas'
            : 'Tenggat tugas mendekat',
        body: isDue
            ? '“${task.title}” dijadwalkan sekarang. Tandai selesai setelah dikerjakan.'
            : '“${task.title}” dimulai dalam 15 menit.',
        at: at,
      );
    }
  }

  Future<void> syncHabitReminders(
    List<Habit> habits, {
    Set<String> completedTodayIds = const {},
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(AppConstants.prefHabitNotifications) ?? true;
    final desired = <String, (Habit, int)>{};
    if (enabled) {
      for (final habit in habits) {
        final time = habit.reminderTime?.split(':');
        if (!habit.isActive ||
            !habit.reminderEnabled ||
            time == null ||
            time.length != 2 ||
            habit.frequency != HabitFrequency.setiapHari) {
          continue;
        }
        final hour = int.tryParse(time[0]);
        final minute = int.tryParse(time[1]);
        if (hour == null || minute == null) continue;
        for (final weekday in habit.activeDays) {
          if (weekday >= 1 && weekday <= 7) {
            desired['habit:${habit.id}:$weekday'] = (habit, weekday);
          }
        }
      }
    }
    await _removeObsolete('habit:', desired.keys.toSet());
    for (final entry in desired.entries) {
      final (habit, weekday) = entry.value;
      final time = habit.reminderTime!.split(':');
      final hour = int.parse(time[0]);
      final minute = int.parse(time[1]);
      final now = tz.TZDateTime.now(tz.local);
      var daysAhead = (weekday - now.weekday + 7) % 7;
      if (daysAhead == 0 && completedTodayIds.contains(habit.id)) {
        daysAhead = 7;
      }
      var scheduled = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day + daysAhead,
        hour,
        minute,
      );
      if (!scheduled.isAfter(now)) {
        scheduled = scheduled.add(const Duration(days: 7));
      }
      try {
        await _notificationsPlugin.zonedSchedule(
          _stableId(entry.key),
          'Pengingat kebiasaan',
          'Waktunya “${habit.name}”.',
          scheduled,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'my_journal_habits',
              'Pengingat Kebiasaan',
              channelDescription: 'Jadwal kebiasaan harian',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: entry.key,
        );
      } catch (_) {}
    }
  }

  Future<void> syncGoalReminders(List<Goal> goals) async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(AppConstants.prefGoalNotifications) ?? true;
    final now = tz.TZDateTime.now(tz.local);
    final desired = <String, Goal>{};
    if (enabled) {
      for (final goal in goals) {
        final targetDate = goal.targetDate?.toLocal();
        if (targetDate == null) continue;
        final at = tz.TZDateTime(
          tz.local,
          targetDate.year,
          targetDate.month,
          targetDate.day,
          9,
        );
        if (at.isAfter(now) && goal.status != GoalStatus.selesai) {
          desired['goal:${goal.id}'] = goal;
        }
      }
    }
    await _removeObsolete('goal:', desired.keys.toSet());
    for (final entry in desired.entries) {
      final targetDate = entry.value.targetDate!.toLocal();
      final at = tz.TZDateTime(
        tz.local,
        targetDate.year,
        targetDate.month,
        targetDate.day,
        9,
      );
      await _scheduleOnce(
        payload: entry.key,
        title: 'Target tujuan hari ini',
        body: 'Waktunya meninjau tujuan “${entry.value.title}”.',
        at: at,
      );
    }
  }

  Future<void> _removeObsolete(String prefix, Set<String> desired) async {
    try {
      final pending = await _notificationsPlugin.pendingNotificationRequests();
      for (final request in pending) {
        final payload = request.payload;
        if (payload != null &&
            payload.startsWith(prefix) &&
            !desired.contains(payload)) {
          await _notificationsPlugin.cancel(request.id);
        }
      }
    } catch (_) {}
  }

  Future<void> _scheduleOnce({
    required String payload,
    required String title,
    required String body,
    required DateTime at,
  }) async {
    try {
      await _notificationsPlugin.zonedSchedule(
        _stableId(payload),
        title,
        body,
        tz.TZDateTime.from(at, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'my_journal_tasks',
            'Tenggat Tugas',
            channelDescription: 'Pengingat sebelum waktu tugas',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } catch (_) {}
  }

  int _stableId(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  Future<void> scheduleDailyReminder({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    try {
      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'my_journal_daily',
            'Pengingat Rutin',
            channelDescription: 'Pengingat rutin harian',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (_) {}
  }
}
