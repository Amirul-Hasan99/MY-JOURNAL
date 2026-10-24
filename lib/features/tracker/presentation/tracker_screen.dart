import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/responsive_action_fab.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/utils/date_formatter.dart';
import '../domain/tracker_controller.dart';
import '../../journal/domain/journal_controller.dart';
import '../../../shared/models/journal_entry.dart';
import '../../../shared/models/mood_entry.dart';
import 'habit_form_screen.dart';
import 'goal_form_screen.dart';
import '../../journal/presentation/journal_detail_screen.dart';

class TrackerScreen extends ConsumerWidget {
  const TrackerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(trackerControllerProvider);
    final controller = ref.read(trackerControllerProvider.notifier);
    final journalState = ref.watch(journalControllerProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pelacak Rutinitas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => controller.loadAll(),
          ),
        ],
      ),
      floatingActionButton: ResponsiveActionFab(
        heroTag: 'tracker-create-item',
        label: state.activeTab == 0
            ? 'Kebiasaan Baru'
            : state.activeTab == 1
            ? 'Tujuan Baru'
            : 'Tulis Jurnal',
        icon: state.activeTab == 2 ? Icons.edit_note_rounded : Icons.add_rounded,
        onPressed: () => context.push(
          state.activeTab == 0
              ? AppConstants.routeAddHabit
              : state.activeTab == 1
              ? AppConstants.routeAddGoal
              : AppConstants.routeAddJournal,
        ),
      ),
      body: Column(
        children: [
          // Segmented Tab Selector
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
              vertical: AppSpacing.sm,
            ),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.card,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _TabButton(
                      label: 'Kebiasaan',
                      isSelected: state.activeTab == 0,
                      onTap: () => controller.setActiveTab(0),
                    ),
                  ),
                  Expanded(
                    child: _TabButton(
                      label: 'Tujuan',
                      isSelected: state.activeTab == 1,
                      onTap: () => controller.setActiveTab(1),
                    ),
                  ),
                  Expanded(
                    child: _TabButton(
                      label: 'Mood',
                      isSelected: state.activeTab == 2,
                      onTap: () => controller.setActiveTab(2),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              0,
              AppSpacing.screenPadding,
              AppSpacing.sm,
            ),
            child: TextField(
              onChanged: controller.setSearchQuery,
              decoration: InputDecoration(
                hintText: 'Cari nama atau tanggal (YYYY-MM-DD)...',
                prefixIcon: const Icon(Icons.search_rounded),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
              ),
            ),
          ),

          // Content
          Expanded(
            child: state.isLoading
                ? const LoadingView(message: 'Memuat data pelacak...')
                : state.errorMessage != null
                ? ErrorState(
                    message: state.errorMessage!,
                    onRetry: controller.loadAll,
                  )
                : state.activeTab == 0
                ? _buildHabitsList(context, ref, state, isDark)
                : state.activeTab == 1
                ? _buildGoalsList(context, ref, state, isDark)
                : _buildMoodList(context, ref, journalState.entries, journalState.isLoading, journalState.errorMessage, state.searchQuery),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodList(BuildContext context, WidgetRef ref, List<JournalEntry> entries, bool loading, String? error, String searchQuery) {
    if (loading) return const LoadingView(message: 'Memuat catatan suasana hati...');
    if (error != null) return ErrorState(message: error, onRetry: () => ref.read(journalControllerProvider.notifier).loadEntries());

    final query = searchQuery.trim().toLowerCase();
    final dated = entries.where((entry) => entry.mood != null && (query.isEmpty || entry.title.toLowerCase().contains(query) || entry.entryDate.toLowerCase().contains(query) || DateFormatter.formatFull(DateTime.parse(entry.entryDate)).toLowerCase().contains(query))).toList()
      ..sort((a, b) => b.entryDate.compareTo(a.entryDate));
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final todayEntry = dated.where((entry) => entry.entryDate == today).firstOrNull;
    final recent = dated.take(7).toList();
    final counts = {for (final mood in MoodType.values) mood: recent.where((entry) => entry.mood == mood).length};

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.screenPadding, AppSpacing.xs, AppSpacing.screenPadding, 90),
      children: [
        AppCard(
          backgroundColor: AppColors.primaryLight,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(todayEntry == null ? 'Bagaimana perasaanmu hari ini?' : 'Mood hari ini', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
            const SizedBox(height: AppSpacing.sm),
            if (todayEntry == null)
              Text('Catat suasana hati lewat jurnal agar progres dan refleksimu tersimpan bersama.', style: AppTextStyles.bodySmall)
            else
              Row(children: [Text(todayEntry.mood!.emoji, style: const TextStyle(fontSize: 32)), const SizedBox(width: AppSpacing.sm), Expanded(child: Text('${todayEntry.mood!.label} · ${todayEntry.title}', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)))]),
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(onPressed: () => context.push(AppConstants.routeAddJournal), icon: const Icon(Icons.edit_note_rounded), label: Text(todayEntry == null ? 'Catat mood di jurnal' : 'Tambah refleksi')),
          ]),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(query.isEmpty ? 'Riwayat 7 catatan terakhir' : 'Hasil pencarian mood', style: AppTextStyles.heading3.copyWith(fontSize: 18)),
        const SizedBox(height: AppSpacing.sm),
        if (recent.isEmpty)
          EmptyState(icon: Icons.mood_outlined, title: query.isEmpty ? 'Belum ada catatan mood' : 'Tidak ada hasil', message: query.isEmpty ? 'Pilih suasana hati saat menulis jurnal untuk melihat perkembangannya di sini.' : 'Coba kata kunci nama atau tanggal yang berbeda.')
        else ...[
          AppCard(child: Column(children: MoodType.values.map((mood) {
            final count = counts[mood]!;
            return Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [Text(mood.emoji, style: const TextStyle(fontSize: 19)), const SizedBox(width: 8), SizedBox(width: 70, child: Text(mood.label, style: AppTextStyles.caption)), Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: recent.isEmpty ? 0 : count / recent.length, minHeight: 8, backgroundColor: AppColors.background, color: mood.color))), const SizedBox(width: 8), Text('$count', style: AppTextStyles.caption)]));
          }).toList())),
          const SizedBox(height: AppSpacing.sm),
          ...recent.map((entry) => Padding(padding: const EdgeInsets.only(bottom: AppSpacing.sm), child: AppCard(onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (context) => JournalDetailScreen(entry: entry))), child: Row(children: [Text(entry.mood!.emoji, style: const TextStyle(fontSize: 27)), const SizedBox(width: AppSpacing.md), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(entry.title, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)), Text('${entry.mood!.label} · ${entry.entryDate}', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary))]))]))))
        ],
      ],
    );
  }

  Widget _buildHabitsList(
    BuildContext context,
    WidgetRef ref,
    TrackerState state,
    bool isDark,
  ) {
    if (state.filteredHabits.isEmpty) {
      return EmptyState(
        icon: Icons.repeat_rounded,
        title: state.habits.isEmpty ? 'Belum Ada Kebiasaan' : 'Tidak Ada Hasil',
        message: state.habits.isEmpty
            ? 'Bangun rutinitas positif setiap hari. Konsistensi kecil menghasilkan perubahan besar.'
            : 'Coba kata kunci nama atau tanggal yang berbeda.',
        actionLabel: state.habits.isEmpty ? 'Buat Kebiasaan' : null,
        onAction: state.habits.isEmpty
            ? () => context.push(AppConstants.routeAddHabit)
            : null,
      );
    }

    final controller = ref.read(trackerControllerProvider.notifier);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.xs,
        AppSpacing.screenPadding,
        80,
      ),
      children: [
        // Summary Header Card
        AppCard(
          backgroundColor: AppColors.primaryLight,
          borderColor: AppColors.primary.withValues(alpha: 0.2),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_fire_department_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pencapaian Hari Ini',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      '${state.completedHabitsTodayCount} dari ${state.habits.length} kebiasaan sudah terselesaikan!',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // Habit Cards
        ...state.filteredHabits.map((habit) {
          final isCompleted = state.isHabitCompletedToday(habit.id);

          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: AppCard(
              child: Row(
                children: [
                  // Tap to toggle
                  GestureDetector(
                    onTap: () => controller.toggleHabitToday(habit.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? AppColors.success
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isCompleted
                              ? AppColors.success
                              : AppColors.border,
                          width: 2,
                        ),
                      ),
                      child: isCompleted
                          ? const Icon(
                              Icons.check,
                              size: 20,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),

                  // Habit details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          habit.name,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            decoration: isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            color: isCompleted
                                ? (isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondary)
                                : (isDark
                                      ? AppColors.textPrimaryDark
                                      : AppColors.textPrimary),
                          ),
                        ),
                        if (habit.description != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            habit.description!,
                            style: AppTextStyles.caption.copyWith(
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.surfaceDark
                                    : AppColors.background,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                habit.frequency.label,
                                style: AppTextStyles.caption.copyWith(
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            if (habit.reminderTime != null) ...[
                              const SizedBox(width: AppSpacing.xs),
                              Icon(
                                Icons.alarm,
                                size: 12,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                habit.reminderTime!,
                                style: AppTextStyles.caption.copyWith(
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Actions menu
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    onSelected: (val) {
                      if (val == 'edit') {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                HabitFormScreen(habitToEdit: habit),
                          ),
                        );
                      } else if (val == 'delete') {
                        controller.deleteHabit(habit.id);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(value: 'edit', child: Text('Ubah')),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Hapus',
                          style: TextStyle(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildGoalsList(
    BuildContext context,
    WidgetRef ref,
    TrackerState state,
    bool isDark,
  ) {
    if (state.filteredGoals.isEmpty) {
      return EmptyState(
        icon: Icons.flag_rounded,
        title: state.goals.isEmpty ? 'Belum Ada Target' : 'Tidak Ada Hasil',
        message: state.goals.isEmpty
            ? 'Tentukan tujuan jangka panjangmu dan pecah menjadi tahapan-tahapan yang dapat dicapai.'
            : 'Coba kata kunci nama atau tanggal yang berbeda.',
        actionLabel: state.goals.isEmpty ? 'Buat Target Pertama' : null,
        onAction: state.goals.isEmpty
            ? () => context.push(AppConstants.routeAddGoal)
            : null,
      );
    }

    final controller = ref.read(trackerControllerProvider.notifier);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.xs,
        AppSpacing.screenPadding,
        80,
      ),
      itemCount: state.filteredGoals.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final goal = state.filteredGoals[index];
        final completedMilestones = goal.milestones
            .where((m) => m.isCompleted)
            .length;
        final totalMilestones = goal.milestones.length;
        final progress = goal.progressPercent;
        final percent = (progress * 100).toInt();
        var sliderValue = goal.progressPercentValue.toDouble();

        return AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Text(
                      goal.category ?? 'Target',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert,
                      size: 20,
                      color: AppColors.textSecondary,
                    ),
                    onSelected: (val) {
                      if (val == 'edit') {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                GoalFormScreen(goalToEdit: goal),
                          ),
                        );
                      } else if (val == 'delete') {
                        controller.deleteGoal(goal.id);
                      }
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(value: 'edit', child: Text('Ubah')),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Hapus',
                          style: TextStyle(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                goal.title,
                style: AppTextStyles.heading3.copyWith(
                  fontSize: 16,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimary,
                ),
              ),
              if (goal.description != null) ...[
                const SizedBox(height: 4),
                Text(
                  goal.description!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                  ),
                ),
              ],
              if (goal.targetDate != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_month_outlined,
                      size: 16,
                      color: AppColors.primaryDark,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Target: ${DateFormatter.formatFull(goal.targetDate!)}',
                      style: AppTextStyles.caption.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.md),

              // Progress Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Progres', style: AppTextStyles.caption),
                  Text(
                    totalMilestones > 0
                        ? '$percent% ($completedMilestones/$totalMilestones ceklis)'
                        : '$percent% selesai',
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: isDark
                      ? AppColors.surfaceDark
                      : AppColors.primaryLight,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primary,
                  ),
                ),
              ),

              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Text('Atur progres', style: AppTextStyles.caption),
                  const Spacer(),
                  Text(
                    '$percent%',
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
              StatefulBuilder(
                builder: (context, setSliderState) => Slider(
                  value: sliderValue.clamp(0, 100),
                  min: 0,
                  max: 100,
                  divisions: 20,
                  label: '${sliderValue.round()}%',
                  activeColor: AppColors.primary,
                  onChanged: (value) => setSliderState(() {
                    sliderValue = value;
                  }),
                  onChangeEnd: (value) {
                    controller.setGoalProgress(goal, value.round());
                  },
                ),
              ),

              // Milestones list
              if (goal.milestones.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                const Divider(),
                ...goal.milestones.map((m) {
                  return CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      m.title,
                      style: AppTextStyles.bodySmall.copyWith(
                        decoration: m.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        color: m.isCompleted ? AppColors.textSecondary : null,
                      ),
                    ),
                    value: m.isCompleted,
                    activeColor: AppColors.primary,
                    onChanged: (_) {
                      controller.toggleMilestone(goal.id, m.id);
                    },
                  );
                }),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodyMedium.copyWith(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
