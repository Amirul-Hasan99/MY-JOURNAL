import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/models/habit.dart';
import '../../../shared/models/goal.dart';
import '../data/tracker_repository.dart';
import '../../notifications/data/notification_inbox.dart';
import '../../notifications/data/notification_service.dart';

class TrackerState {
  final List<Habit> habits;
  final List<HabitLog> todayLogs;
  final List<Goal> goals;
  final bool isLoading;
  final String? errorMessage;
  final int activeTab; // 0 = Habits, 1 = Goals
  final String searchQuery;

  TrackerState({
    this.habits = const [],
    this.todayLogs = const [],
    this.goals = const [],
    this.isLoading = false,
    this.errorMessage,
    this.activeTab = 0,
    this.searchQuery = '',
  });

  TrackerState copyWith({
    List<Habit>? habits,
    List<HabitLog>? todayLogs,
    List<Goal>? goals,
    bool? isLoading,
    String? errorMessage,
    int? activeTab,
    String? searchQuery,
  }) {
    return TrackerState(
      habits: habits ?? this.habits,
      todayLogs: todayLogs ?? this.todayLogs,
      goals: goals ?? this.goals,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      activeTab: activeTab ?? this.activeTab,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  bool isHabitCompletedToday(String habitId) {
    return todayLogs.any((l) => l.habitId == habitId && l.isCompleted);
  }

  int get completedHabitsTodayCount {
    return habits.where((h) => isHabitCompletedToday(h.id)).length;
  }

  List<Habit> get filteredHabits {
    final q = searchQuery.trim().toLowerCase();
    return habits
        .where(
          (habit) =>
              q.isEmpty ||
              [
                habit.name,
                habit.description ?? '',
                habit.createdAt.toIso8601String(),
                DateFormatter.formatFull(habit.createdAt),
              ].any((value) => value.toLowerCase().contains(q)),
        )
        .toList();
  }

  List<Goal> get filteredGoals {
    final q = searchQuery.trim().toLowerCase();
    return goals
        .where(
          (goal) =>
              q.isEmpty ||
              [
                goal.title,
                goal.description ?? '',
                goal.category ?? '',
                if (goal.targetDate != null)
                  DateFormatter.toIsoDate(goal.targetDate!),
                if (goal.targetDate != null)
                  DateFormatter.formatFull(goal.targetDate!),
                DateFormatter.toIsoDate(goal.createdAt),
              ].any((value) => value.toLowerCase().contains(q)),
        )
        .toList();
  }
}

class TrackerNotifier extends StateNotifier<TrackerState> {
  final TrackerRepository _repository;
  final NotificationInboxNotifier _inbox;

  TrackerNotifier(this._repository, this._inbox)
    : super(TrackerState(isLoading: true)) {
    loadAll();
  }

  Future<void> loadAll() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final todayStr = DateFormatter.toIsoDate(DateTime.now());

    final habitsResult = await _repository.getHabits();
    final logsResult = await _repository.getHabitLogs(date: todayStr);
    final goalsResult = await _repository.getGoals();

    final habits = habitsResult is Success<List<Habit>>
        ? habitsResult.data
        : state.habits;
    final logs = logsResult is Success<List<HabitLog>>
        ? logsResult.data
        : state.todayLogs;
    final goals = goalsResult is Success<List<Goal>>
        ? goalsResult.data
        : state.goals;
    final errors = [
      if (habitsResult case Failure<List<Habit>>(:final error)) error.message,
      if (logsResult case Failure<List<HabitLog>>(:final error)) error.message,
      if (goalsResult case Failure<List<Goal>>(:final error)) error.message,
    ];

    state = state.copyWith(
      habits: habits,
      todayLogs: logs,
      goals: goals,
      isLoading: false,
      errorMessage: errors.isEmpty ? null : errors.join('\n'),
    );
    await NotificationService.instance.syncHabitReminders(
      habits,
      completedTodayIds: logs
          .where((log) => log.isCompleted)
          .map((log) => log.habitId)
          .toSet(),
    );
    await NotificationService.instance.syncGoalReminders(goals);
  }

  void setActiveTab(int tab) {
    state = state.copyWith(activeTab: tab);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  Future<void> toggleHabitToday(String habitId) async {
    final todayStr = DateFormatter.toIsoDate(DateTime.now());
    final result = await _repository.toggleHabitLog(habitId, todayStr);
    if (result is Success<HabitLog>) {
      final habit = state.habits.where((item) => item.id == habitId);
      final name = habit.isEmpty ? 'Kebiasaan' : habit.first.name;
      await _inbox.record(
        'Kebiasaan diperbarui',
        'Status “$name” hari ini telah diperbarui.',
      );
      if (result.data.isCompleted) {
        await NotificationService.instance.notifyEvent(
          title: 'Kebiasaan selesai',
          body: '“$name” berhasil diselesaikan hari ini.',
        );
      }
      // Reload logs
      final logsResult = await _repository.getHabitLogs(date: todayStr);
      if (logsResult is Success<List<HabitLog>>) {
        state = state.copyWith(todayLogs: logsResult.data);
        await NotificationService.instance.syncHabitReminders(
          state.habits,
          completedTodayIds: logsResult.data
              .where((log) => log.isCompleted)
              .map((log) => log.habitId)
              .toSet(),
        );
      }
    }
  }

  Future<bool> addHabit(Habit habit) async {
    final result = await _repository.createHabit(habit);
    if (result is Success<Habit>) {
      await _inbox.record(
        'Kebiasaan ditambahkan',
        '“${result.data.name}” berhasil disimpan.',
      );
      await loadAll();
      return true;
    }
    return false;
  }

  Future<bool> updateHabit(Habit habit) async {
    final result = await _repository.updateHabit(habit);
    if (result is Success<Habit>) {
      await _inbox.record(
        'Kebiasaan diperbarui',
        '“${result.data.name}” berhasil diperbarui.',
      );
      await loadAll();
      return true;
    }
    return false;
  }

  Future<bool> deleteHabit(String id) async {
    final matches = state.habits.where((habit) => habit.id == id);
    final name = matches.isEmpty ? 'Kebiasaan' : matches.first.name;
    final result = await _repository.deleteHabit(id);
    if (result is Success<bool>) {
      await _inbox.record('Kebiasaan dihapus', '“$name” telah dihapus.');
      await loadAll();
      return true;
    }
    return false;
  }

  Future<void> toggleMilestone(String goalId, String milestoneId) async {
    final result = await _repository.toggleMilestone(goalId, milestoneId);
    if (result is Success<Goal>) {
      final milestone = result.data.milestones.where(
        (item) => item.id == milestoneId,
      );
      if (milestone.isNotEmpty) {
        await _inbox.record(
          milestone.first.isCompleted
              ? 'Tahapan tujuan selesai'
              : 'Tahapan tujuan dibuka kembali',
          '“${milestone.first.title}” pada tujuan “${result.data.title}” telah diperbarui.',
        );
        if (milestone.first.isCompleted &&
            result.data.status == GoalStatus.selesai) {
          await NotificationService.instance.notifyEvent(
            title: 'Tujuan tercapai',
            body: 'Semua tahapan “${result.data.title}” telah selesai.',
          );
        } else if (milestone.first.isCompleted) {
          await NotificationService.instance.notifyEvent(
            title: 'Progres tujuan diperbarui',
            body: 'Tahapan “${milestone.first.title}” selesai.',
          );
        }
      }
      await loadAll();
    }
  }

  Future<bool> addGoal(Goal goal) async {
    final result = await _repository.createGoal(goal);
    if (result is Success<Goal>) {
      await _inbox.record(
        'Tujuan ditambahkan',
        '“${result.data.title}” berhasil disimpan.',
      );
      await loadAll();
      return true;
    }
    return false;
  }

  Future<bool> updateGoal(Goal goal) async {
    final result = await _repository.updateGoal(goal);
    if (result is Success<Goal>) {
      await _inbox.record(
        'Tujuan diperbarui',
        '“${result.data.title}” berhasil diperbarui.',
      );
      await loadAll();
      return true;
    }
    return false;
  }

  Future<void> setGoalProgress(Goal goal, int percent) async {
    final bounded = percent.clamp(0, 100);
    if (bounded == goal.progressPercentValue) return;
    final updatedGoal = goal.copyWith(
      progressPercentValue: bounded,
      status: bounded == 100
          ? GoalStatus.selesai
          : bounded > 0
          ? GoalStatus.sedangBerjalan
          : GoalStatus.belumDimulai,
      updatedAt: DateTime.now(),
    );
    final saved = await updateGoal(updatedGoal);
    if (saved && bounded == 100) {
      await NotificationService.instance.notifyEvent(
        title: 'Tujuan tercapai',
        body: '“${goal.title}” telah mencapai 100%.',
      );
    }
  }

  Future<bool> deleteGoal(String id) async {
    final matches = state.goals.where((goal) => goal.id == id);
    final title = matches.isEmpty ? 'Tujuan' : matches.first.title;
    final result = await _repository.deleteGoal(id);
    if (result is Success<bool>) {
      await _inbox.record('Tujuan dihapus', '“$title” telah dihapus.');
      await loadAll();
      return true;
    }
    return false;
  }
}

final trackerControllerProvider =
    StateNotifierProvider<TrackerNotifier, TrackerState>((ref) {
      final repository = ref.watch(trackerRepositoryProvider);
      final inbox = ref.watch(notificationInboxProvider.notifier);
      return TrackerNotifier(repository, inbox);
    });
