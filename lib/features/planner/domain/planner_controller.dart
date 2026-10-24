import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/models/task.dart';
import '../data/planner_repository.dart';
import '../../notifications/data/notification_inbox.dart';
import '../../notifications/data/notification_service.dart';

class PlannerState {
  final DateTime selectedDate;
  final String? selectedCategory;
  final String searchQuery;
  final List<Task> tasks;
  final bool isLoading;
  final String? errorMessage;

  PlannerState({
    required this.selectedDate,
    this.selectedCategory,
    this.searchQuery = '',
    this.tasks = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  PlannerState copyWith({
    DateTime? selectedDate,
    String? selectedCategory,
    String? searchQuery,
    List<Task>? tasks,
    bool? isLoading,
    String? errorMessage,
    bool clearCategory = false,
  }) {
    return PlannerState(
      selectedDate: selectedDate ?? this.selectedDate,
      selectedCategory: clearCategory
          ? null
          : (selectedCategory ?? this.selectedCategory),
      searchQuery: searchQuery ?? this.searchQuery,
      tasks: tasks ?? this.tasks,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  List<Task> get filteredTasks {
    final query = searchQuery.trim().toLowerCase();
    return tasks.where((t) {
      final matchesDate =
          query.isNotEmpty ||
          t.dueDate == DateFormatter.toIsoDate(selectedDate);
      final matchesCategory =
          selectedCategory == null || t.category == selectedCategory;
      final matchesQuery =
          query.isEmpty ||
          [
            t.title,
            t.description ?? '',
            t.category ?? '',
            t.dueDate,
            DateFormatter.formatFull(t.scheduledAt),
            DateFormatter.formatShort(t.scheduledAt),
          ].any((value) => value.toLowerCase().contains(query));
      return matchesDate && matchesCategory && matchesQuery;
    }).toList();
  }

  int get completedCount => filteredTasks.where((t) => t.isCompleted).length;
  int get totalCount => filteredTasks.length;
  double get completionProgress =>
      totalCount == 0 ? 0 : completedCount / totalCount;
}

class PlannerNotifier extends StateNotifier<PlannerState> {
  final PlannerRepository _repository;
  final NotificationInboxNotifier _inbox;

  PlannerNotifier(this._repository, this._inbox)
    : super(PlannerState(selectedDate: DateTime.now(), isLoading: true)) {
    loadTasks();
  }

  Future<void> loadTasks() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final result = await _repository.getTasks();
    if (result is Success<List<Task>>) {
      state = state.copyWith(tasks: result.data, isLoading: false);
      await NotificationService.instance.syncTaskReminders(result.data);
    } else if (result is Failure<List<Task>>) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: result.error.message,
      );
    }
  }

  void selectDate(DateTime date) {
    state = state.copyWith(selectedDate: date);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void selectCategory(String? category) {
    if (state.selectedCategory == category) {
      state = state.copyWith(clearCategory: true);
    } else {
      state = state.copyWith(selectedCategory: category);
    }
  }

  Future<bool> addTask(Task task) async {
    final result = await _repository.createTask(task);
    if (result is Success<Task>) {
      await _inbox.record(
        'Tugas ditambahkan',
        '“${result.data.title}” berhasil disimpan.',
      );
      await loadTasks();
      return true;
    }
    if (result case Failure<Task>(:final error)) {
      state = state.copyWith(errorMessage: error.message);
    }
    return false;
  }

  Future<bool> updateTask(Task task) async {
    final result = await _repository.updateTask(task);
    if (result is Success<Task>) {
      await _inbox.record(
        'Tugas diperbarui',
        '“${result.data.title}” berhasil diperbarui.',
      );
      await loadTasks();
      return true;
    }
    return false;
  }

  Future<bool> deleteTask(String id) async {
    final matches = state.tasks.where((task) => task.id == id);
    final title = matches.isEmpty ? 'Tugas' : matches.first.title;
    final result = await _repository.deleteTask(id);
    if (result is Success<bool>) {
      await _inbox.record('Tugas dihapus', '“$title” telah dihapus.');
      await loadTasks();
      return true;
    }
    return false;
  }

  Future<void> toggleTask(String id) async {
    final result = await _repository.toggleTaskStatus(id);
    if (result is Success<Task>) {
      await _inbox.record(
        result.data.isCompleted ? 'Tugas selesai' : 'Tugas dibuka kembali',
        'Status “${result.data.title}” telah diperbarui.',
      );
      if (result.data.isCompleted) {
        await NotificationService.instance.notifyEvent(
          title: 'Tugas selesai',
          body: '“${result.data.title}” telah ditandai selesai.',
        );
      }
      await loadTasks();
    }
  }
}

final plannerControllerProvider =
    StateNotifierProvider<PlannerNotifier, PlannerState>((ref) {
      final repository = ref.watch(plannerRepositoryProvider);
      final inbox = ref.watch(notificationInboxProvider.notifier);
      return PlannerNotifier(repository, inbox);
    });
