import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/config/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/models/habit.dart';
import '../../../shared/models/goal.dart';

final trackerRepositoryProvider = Provider<TrackerRepository>(
  (ref) => TrackerRepository(),
);

class TrackerRepository {
  static const String _habitsKey = 'my_journal_cached_habits';
  static const String _habitLogsKey = 'my_journal_cached_habit_logs';
  static const String _goalsKey = 'my_journal_cached_goals';
  final ApiClient _api;

  TrackerRepository({ApiClient? api}) : _api = api ?? ApiClient();

  // ================= HABITS =================
  Future<Result<List<Habit>>> getHabits() async {
    if (!AppConstants.isDemoMode) {
      return _api.get(
        '/api/habits',
        fromJson: (json) => (json as List<dynamic>)
            .map((item) => Habit.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_habitsKey);
      List<Habit> habits = [];

      if (cachedJson != null) {
        final List<dynamic> decoded = jsonDecode(cachedJson);
        habits = decoded
            .map((e) => Habit.fromJson(e as Map<String, dynamic>))
            .where(
              (habit) => !{'habit-1', 'habit-2', 'habit-3'}.contains(habit.id),
            )
            .toList();
      } else {
        await _saveHabitsToLocal(habits);
      }

      return Success(habits);
    } catch (e) {
      return Failure(CacheError(e.toString()));
    }
  }

  Future<Result<Habit>> createHabit(Habit habit) async {
    if (!AppConstants.isDemoMode) {
      return _api.post(
        '/api/habits',
        data: habit.toJson(),
        fromJson: (json) => Habit.fromJson(json as Map<String, dynamic>),
      );
    }
    try {
      final habitsResult = await getHabits();
      List<Habit> habits = [];
      if (habitsResult is Success<List<Habit>>) {
        habits = List.from(habitsResult.data);
      }

      final newHabit = habit.copyWith(
        id: habit.id.isEmpty ? const Uuid().v4() : habit.id,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      habits.add(newHabit);
      await _saveHabitsToLocal(habits);

      return Success(newHabit);
    } catch (e) {
      return Failure(UnknownError(e.toString()));
    }
  }

  Future<Result<Habit>> updateHabit(Habit habit) async {
    if (!AppConstants.isDemoMode) {
      return _api.patch(
        '/api/habits/${habit.id}',
        data: habit.toJson(),
        fromJson: (json) => Habit.fromJson(json as Map<String, dynamic>),
      );
    }
    try {
      final habitsResult = await getHabits();
      if (habitsResult is! Success<List<Habit>>) {
        return Failure(const UnknownError('Gagal memuat kebiasaan'));
      }

      final habits = List<Habit>.from(habitsResult.data);
      final index = habits.indexWhere((h) => h.id == habit.id);
      if (index == -1) {
        return Failure(const NotFoundError('Kebiasaan tidak ditemukan'));
      }

      final updated = habit.copyWith(updatedAt: DateTime.now());
      habits[index] = updated;
      await _saveHabitsToLocal(habits);

      return Success(updated);
    } catch (e) {
      return Failure(UnknownError(e.toString()));
    }
  }

  Future<Result<bool>> deleteHabit(String id) async {
    if (!AppConstants.isDemoMode) return _api.delete('/api/habits/$id');
    try {
      final habitsResult = await getHabits();
      if (habitsResult is! Success<List<Habit>>) {
        return Failure(const UnknownError('Gagal memuat kebiasaan'));
      }

      final habits = List<Habit>.from(habitsResult.data);
      habits.removeWhere((h) => h.id == id);
      await _saveHabitsToLocal(habits);

      return const Success(true);
    } catch (e) {
      return Failure(UnknownError(e.toString()));
    }
  }

  // ================= HABIT LOGS =================
  Future<Result<List<HabitLog>>> getHabitLogs({String? date}) async {
    if (!AppConstants.isDemoMode) {
      return _api.get(
        '/api/habit-logs',
        queryParams: {if (date != null) 'date': date},
        fromJson: (json) => (json as List<dynamic>)
            .map((item) => HabitLog.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_habitLogsKey);
      List<HabitLog> logs = [];

      if (cachedJson != null) {
        final List<dynamic> decoded = jsonDecode(cachedJson);
        logs = decoded
            .map((e) => HabitLog.fromJson(e as Map<String, dynamic>))
            .where((log) => log.id != 'log-1')
            .toList();
      } else {
        await _saveHabitLogsToLocal(logs);
      }

      if (date != null) {
        logs = logs.where((l) => l.logDate == date).toList();
      }

      return Success(logs);
    } catch (e) {
      return Failure(CacheError(e.toString()));
    }
  }

  Future<Result<HabitLog>> toggleHabitLog(String habitId, String date) async {
    if (!AppConstants.isDemoMode) {
      return _api.post(
        '/api/habit-logs/toggle',
        data: {'habit_id': habitId, 'local_date': date},
        fromJson: (json) => HabitLog.fromJson(json as Map<String, dynamic>),
      );
    }
    try {
      final logsResult = await getHabitLogs();
      List<HabitLog> logs = [];
      if (logsResult is Success<List<HabitLog>>) {
        logs = List.from(logsResult.data);
      }

      final index = logs.indexWhere(
        (l) => l.habitId == habitId && l.logDate == date,
      );
      HabitLog updated;

      if (index != -1) {
        final existing = logs[index];
        updated = existing.copyWith(isCompleted: !existing.isCompleted);
        logs[index] = updated;
      } else {
        final habitsResult = await getHabits();
        final matches = habitsResult is Success<List<Habit>>
            ? habitsResult.data.where((habit) => habit.id == habitId)
            : const <Habit>[];
        updated = HabitLog(
          id: const Uuid().v4(),
          habitId: habitId,
          userId: matches.isEmpty ? '' : matches.first.userId,
          localDate: date,
          isCompleted: true,
          updatedAt: DateTime.now(),
        );
        logs.add(updated);
      }

      await _saveHabitLogsToLocal(logs);
      return Success(updated);
    } catch (e) {
      return Failure(UnknownError(e.toString()));
    }
  }

  // ================= GOALS =================
  Future<Result<List<Goal>>> getGoals() async {
    if (!AppConstants.isDemoMode) {
      return _api.get(
        '/api/goals',
        fromJson: (json) => (json as List<dynamic>)
            .map((item) => Goal.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_goalsKey);
      List<Goal> goals = [];

      if (cachedJson != null) {
        final List<dynamic> decoded = jsonDecode(cachedJson);
        goals = decoded
            .map((e) => Goal.fromJson(e as Map<String, dynamic>))
            .where((goal) => !{'goal-1', 'goal-2'}.contains(goal.id))
            .toList();
      } else {
        await _saveGoalsToLocal(goals);
      }

      return Success(goals);
    } catch (e) {
      return Failure(CacheError(e.toString()));
    }
  }

  Future<Result<Goal>> createGoal(Goal goal) async {
    if (!AppConstants.isDemoMode) {
      return _api.post(
        '/api/goals',
        data: goal.toJson(),
        fromJson: (json) => Goal.fromJson(json as Map<String, dynamic>),
      );
    }
    try {
      final goalsResult = await getGoals();
      List<Goal> goals = [];
      if (goalsResult is Success<List<Goal>>) {
        goals = List.from(goalsResult.data);
      }

      final newGoal = goal.copyWith(
        id: goal.id.isEmpty ? const Uuid().v4() : goal.id,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      goals.add(newGoal);
      await _saveGoalsToLocal(goals);

      return Success(newGoal);
    } catch (e) {
      return Failure(UnknownError(e.toString()));
    }
  }

  Future<Result<Goal>> updateGoal(Goal goal) async {
    if (!AppConstants.isDemoMode) {
      return _api.patch(
        '/api/goals/${goal.id}',
        data: goal.toJson(),
        fromJson: (json) => Goal.fromJson(json as Map<String, dynamic>),
      );
    }
    try {
      final goalsResult = await getGoals();
      if (goalsResult is! Success<List<Goal>>) {
        return Failure(const UnknownError('Gagal memuat tujuan'));
      }

      final goals = List<Goal>.from(goalsResult.data);
      final index = goals.indexWhere((g) => g.id == goal.id);
      if (index == -1) {
        return Failure(const NotFoundError('Tujuan tidak ditemukan'));
      }

      final updated = goal.copyWith(updatedAt: DateTime.now());
      goals[index] = updated;
      await _saveGoalsToLocal(goals);

      return Success(updated);
    } catch (e) {
      return Failure(UnknownError(e.toString()));
    }
  }

  Future<Result<bool>> deleteGoal(String id) async {
    if (!AppConstants.isDemoMode) return _api.delete('/api/goals/$id');
    try {
      final goalsResult = await getGoals();
      if (goalsResult is! Success<List<Goal>>) {
        return Failure(const UnknownError('Gagal memuat tujuan'));
      }

      final goals = List<Goal>.from(goalsResult.data);
      goals.removeWhere((g) => g.id == id);
      await _saveGoalsToLocal(goals);

      return const Success(true);
    } catch (e) {
      return Failure(UnknownError(e.toString()));
    }
  }

  Future<Result<Goal>> toggleMilestone(
    String goalId,
    String milestoneId,
  ) async {
    try {
      final goalsResult = await getGoals();
      if (goalsResult is! Success<List<Goal>>) {
        return Failure(const UnknownError('Gagal memuat tujuan'));
      }

      final goals = List<Goal>.from(goalsResult.data);
      final goalIndex = goals.indexWhere((g) => g.id == goalId);
      if (goalIndex == -1) {
        return Failure(const NotFoundError('Tujuan tidak ditemukan'));
      }

      final goal = goals[goalIndex];
      final milestones = List<GoalMilestone>.from(goal.milestones);
      final mIndex = milestones.indexWhere((m) => m.id == milestoneId);
      if (mIndex == -1) {
        return Failure(const NotFoundError('Milestone tidak ditemukan'));
      }

      final m = milestones[mIndex];
      milestones[mIndex] = GoalMilestone(
        id: m.id,
        goalId: m.goalId,
        title: m.title,
        isCompleted: !m.isCompleted,
        completedAt: !m.isCompleted ? DateTime.now() : null,
        sortOrder: m.sortOrder,
      );
      final allMilestonesCompleted =
          milestones.isNotEmpty && milestones.every((item) => item.isCompleted);
      final progressPercent = milestones.isEmpty
          ? goal.progressPercentValue
          : ((milestones.where((item) => item.isCompleted).length /
                        milestones.length) *
                    100)
                .round();

      final updatedGoal = goal.copyWith(
        milestones: milestones,
        progressPercentValue: progressPercent,
        status: allMilestonesCompleted
            ? GoalStatus.selesai
            : progressPercent == 0
            ? GoalStatus.belumDimulai
            : GoalStatus.sedangBerjalan,
        updatedAt: DateTime.now(),
      );

      if (!AppConstants.isDemoMode) {
        return await updateGoal(updatedGoal);
      }

      goals[goalIndex] = updatedGoal;
      await _saveGoalsToLocal(goals);

      return Success(updatedGoal);
    } catch (e) {
      return Failure(UnknownError(e.toString()));
    }
  }

  Future<void> _saveHabitsToLocal(List<Habit> habits) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _habitsKey,
      jsonEncode(habits.map((h) => h.toJson()).toList()),
    );
  }

  Future<void> _saveHabitLogsToLocal(List<HabitLog> logs) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _habitLogsKey,
      jsonEncode(logs.map((l) => l.toJson()).toList()),
    );
  }

  Future<void> _saveGoalsToLocal(List<Goal> goals) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _goalsKey,
      jsonEncode(goals.map((g) => g.toJson()).toList()),
    );
  }
}
