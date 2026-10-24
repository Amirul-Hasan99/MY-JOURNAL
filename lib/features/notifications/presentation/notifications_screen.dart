import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/utils/date_formatter.dart';
import '../data/notification_inbox.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationInboxProvider);
    final inbox = ref.read(notificationInboxProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        actions: [
          if (notifications.isNotEmpty)
            IconButton(
              tooltip: 'Hapus semua',
              onPressed: inbox.clear,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ),
      body: notifications.isEmpty
          ? const EmptyState(
              icon: Icons.notifications_off_outlined,
              title: 'Belum Ada Notifikasi',
              message: 'Pembaruan tugas, jurnal, kebiasaan, dan tujuan akan muncul di sini.',
            )
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              itemCount: notifications.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final item = notifications[index];
                return Dismissible(
                  key: ValueKey(item.id),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) => inbox.remove(item.id),
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    ),
                    child: const Icon(
                      Icons.delete_outline,
                      color: Colors.white,
                    ),
                  ),
                  child: AppCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.notifications_active_outlined,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(item.body, style: AppTextStyles.bodySmall),
                              const SizedBox(height: 6),
                              Text(
                                DateFormatter.formatRelative(item.createdAt),
                                style: AppTextStyles.caption.copyWith(
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
