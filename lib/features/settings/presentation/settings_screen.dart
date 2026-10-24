import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/widgets/app_card.dart';
import '../../../features/notifications/data/notification_service.dart';
import '../../../features/planner/domain/planner_controller.dart';
import '../../../features/tracker/domain/tracker_controller.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _dailyReminder = false;
  bool _habitNotifications = true;
  bool _taskDueNotifications = true;
  bool _goalNotifications = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationPreferences();
  }

  Future<void> _loadNotificationPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final daily = prefs.getBool(AppConstants.prefDailyJournalReminder) ?? false;
    final habits = prefs.getBool(AppConstants.prefHabitNotifications) ?? true;
    final tasks = prefs.getBool(AppConstants.prefTaskDueNotifications) ?? true;
    final goals = prefs.getBool(AppConstants.prefGoalNotifications) ?? true;
    if (!mounted) return;
    setState(() {
      _dailyReminder = daily;
      _habitNotifications = habits;
      _taskDueNotifications = tasks;
      _goalNotifications = goals;
    });
    if (daily || habits || tasks || goals) {
      const permissionAskedKey = 'my_journal_notification_permission_asked';
      if (!(prefs.getBool(permissionAskedKey) ?? false)) {
        final granted = await NotificationService.instance.requestPermissions();
        await prefs.setBool(permissionAskedKey, true);
        if (!granted && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Aktifkan izin notifikasi My Journal di pengaturan perangkat agar pengingat dapat muncul.',
              ),
            ),
          );
        }
      }
    }
    if (daily) {
      await NotificationService.instance.scheduleDailyReminder(
        id: 1001,
        title: 'Waktunya menulis jurnal',
        body: 'Luangkan waktu untuk merefleksikan harimu.',
        hour: 20,
        minute: 0,
      );
    } else {
      await NotificationService.instance.cancel(1001);
    }
    await NotificationService.instance.syncHabitReminders(
      ref.read(trackerControllerProvider).habits,
      completedTodayIds: ref
          .read(trackerControllerProvider)
          .todayLogs
          .where((log) => log.isCompleted)
          .map((log) => log.habitId)
          .toSet(),
    );
    await NotificationService.instance.syncGoalReminders(
      ref.read(trackerControllerProvider).goals,
    );
    await NotificationService.instance.syncTaskReminders(
      ref.read(plannerControllerProvider).tasks,
    );
  }

  Future<void> _updateReminder(String key, bool enabled) async {
    if (enabled) {
      final granted = await NotificationService.instance.requestPermissions();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Izin notifikasi belum diberikan. Aktifkan izin di pengaturan perangkat.',
              ),
            ),
          );
        }
        return;
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, enabled);
    if (!mounted) return;
    setState(() {
      if (key == AppConstants.prefDailyJournalReminder) {
        _dailyReminder = enabled;
      } else if (key == AppConstants.prefHabitNotifications) {
        _habitNotifications = enabled;
      } else if (key == AppConstants.prefGoalNotifications) {
        _goalNotifications = enabled;
      } else {
        _taskDueNotifications = enabled;
      }
    });
    if (key == AppConstants.prefDailyJournalReminder) {
      if (enabled) {
        await NotificationService.instance.scheduleDailyReminder(
          id: 1001,
          title: 'Waktunya menulis jurnal',
          body: 'Luangkan waktu untuk merefleksikan harimu.',
          hour: 20,
          minute: 0,
        );
      } else {
        await NotificationService.instance.cancel(1001);
      }
    } else if (key == AppConstants.prefHabitNotifications) {
      await NotificationService.instance.syncHabitReminders(
        ref.read(trackerControllerProvider).habits,
      );
    } else if (key == AppConstants.prefGoalNotifications) {
      await NotificationService.instance.syncGoalReminders(
        ref.read(trackerControllerProvider).goals,
      );
    } else {
      await NotificationService.instance.syncTaskReminders(
        ref.read(plannerControllerProvider).tasks,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentThemeMode = ref.watch(themeModeProvider);
    final themeNotifier = ref.read(themeModeProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          // Tampilan & Tema
          Text(
            'TAMPILAN',
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.system,
                    label: Text('Sistem'),
                    icon: Icon(Icons.brightness_auto, size: 18),
                  ),
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.light,
                    label: Text('Terang'),
                    icon: Icon(Icons.light_mode_outlined, size: 18),
                  ),
                  ButtonSegment<ThemeMode>(
                    value: ThemeMode.dark,
                    label: Text('Gelap'),
                    icon: Icon(Icons.dark_mode_outlined, size: 18),
                  ),
                ],
                selected: {currentThemeMode},
                onSelectionChanged: (newSelection) {
                  themeNotifier.setThemeMode(newSelection.first);
                },
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Notifikasi
          Text(
            'NOTIFIKASI & PENGINGAT',
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Pengingat Jurnal Harian'),
                  subtitle: const Text(
                    'Ingatkan untuk refleksi setiap malam pukul 20:00',
                  ),
                  value: _dailyReminder,
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppColors.primary,
                  inactiveThumbColor: AppColors.textSecondary,
                  inactiveTrackColor: AppColors.border,
                  onChanged: (val) => _updateReminder(
                    AppConstants.prefDailyJournalReminder,
                    val,
                  ),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Pengingat Kebiasaan'),
                  subtitle: const Text(
                    'Notifikasi sesuai jadwal target rutinitasmu',
                  ),
                  value: _habitNotifications,
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppColors.primary,
                  inactiveThumbColor: AppColors.textSecondary,
                  inactiveTrackColor: AppColors.border,
                  onChanged: (val) =>
                      _updateReminder(AppConstants.prefHabitNotifications, val),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Target Tujuan Tracker'),
                  subtitle: const Text(
                    'Pengingat pukul 09:00 pada tanggal target tujuan',
                  ),
                  value: _goalNotifications,
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppColors.primary,
                  inactiveThumbColor: AppColors.textSecondary,
                  inactiveTrackColor: AppColors.border,
                  onChanged: (val) =>
                      _updateReminder(AppConstants.prefGoalNotifications, val),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Tenggat Waktu Tugas'),
                  subtitle: const Text(
                    'Peringatan 15 menit sebelum waktu tugas tiba',
                  ),
                  value: _taskDueNotifications,
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppColors.primary,
                  inactiveThumbColor: AppColors.textSecondary,
                  inactiveTrackColor: AppColors.border,
                  onChanged: (val) => _updateReminder(
                    AppConstants.prefTaskDueNotifications,
                    val,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Tentang Aplikasi
          Text(
            'TENTANG',
            style: AppTextStyles.caption.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  title: const Text('Versi Aplikasi'),
                  trailing: Text(
                    '1.0.0 (Build 1)',
                    style: AppTextStyles.caption,
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Kebijakan Privasi & Ketentuan'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'My Journal',
                      applicationVersion: '1.0.0',
                      applicationLegalese:
                          '© 2026 My Journal Team. All rights reserved.',
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
