import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/api_client.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/config/app_constants.dart';
import '../../../shared/models/task.dart';

final plannerRepositoryProvider = Provider<PlannerRepository>(
  (ref) => PlannerRepository(),
);

class PlannerRepository {
  static const String _storageKey = 'my_journal_cached_tasks';
  final ApiClient _api;

  PlannerRepository({ApiClient? api}) : _api = api ?? ApiClient();

  Future<Result<List<Task>>> getTasks({String? date, String? category}) async {
    if (!AppConstants.isDemoMode) {
      return _api.get(
        '/api/tasks',
        queryParams: {
          if (date != null) 'date': date,
          if (category != null && category.isNotEmpty) 'category': category,
        },
        fromJson: (json) => (json as List<dynamic>)
            .map((item) => Task.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_storageKey);
      List<Task> tasks = [];

      if (cachedJson != null) {
        final List<dynamic> decoded = jsonDecode(cachedJson);
        tasks = decoded
            .map((e) => Task.fromJson(e as Map<String, dynamic>))
            .where((task) => !{'task-1', 'task-2', 'task-3'}.contains(task.id))
            .toList();
      } else {
        await _saveTasksToLocal(tasks);
      }

      var filtered = tasks;
      if (date != null) {
        filtered = filtered.where((t) => t.dueDate == date).toList();
      }
      if (category != null && category.isNotEmpty) {
        filtered = filtered.where((t) => t.category == category).toList();
      }

      // Sort by priority and time
      filtered.sort((a, b) {
        if (a.isCompleted != b.isCompleted) {
          return a.isCompleted ? 1 : -1;
        }
        return b.priority.index.compareTo(a.priority.index);
      });

      return Success(filtered);
    } catch (e) {
      return Failure(CacheError(e.toString()));
    }
  }

  Future<Result<Task>> createTask(Task task) async {
    if (!AppConstants.isDemoMode) {
      return _api.post(
        '/api/tasks',
        data: task.toJson(),
        fromJson: (json) => Task.fromJson(json as Map<String, dynamic>),
      );
    }
    try {
      final tasksResult = await getTasks();
      List<Task> tasks = [];
      if (tasksResult is Success<List<Task>>) {
        tasks = List.from(tasksResult.data);
      }

      final newTask = task.copyWith(
        id: task.id.isEmpty ? const Uuid().v4() : task.id,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      tasks.add(newTask);
      await _saveTasksToLocal(tasks);

      // Best effort API sync

      return Success(newTask);
    } catch (e) {
      return Failure(UnknownError(e.toString()));
    }
  }

  Future<Result<Task>> updateTask(Task task) async {
    if (!AppConstants.isDemoMode) {
      return _api.patch(
        '/api/tasks/${task.id}',
        data: task.toJson(),
        fromJson: (json) => Task.fromJson(json as Map<String, dynamic>),
      );
    }
    try {
      final tasksResult = await getTasks();
      if (tasksResult is! Success<List<Task>>) {
        return Failure(const UnknownError('Gagal memuat tugas'));
      }

      final tasks = List<Task>.from(tasksResult.data);
      final index = tasks.indexWhere((t) => t.id == task.id);
      if (index == -1) {
        return Failure(const NotFoundError('Tugas tidak ditemukan'));
      }

      final updated = task.copyWith(updatedAt: DateTime.now());
      tasks[index] = updated;
      await _saveTasksToLocal(tasks);

      return Success(updated);
    } catch (e) {
      return Failure(UnknownError(e.toString()));
    }
  }

  Future<Result<bool>> deleteTask(String id) async {
    if (!AppConstants.isDemoMode) return _api.delete('/api/tasks/$id');
    try {
      final tasksResult = await getTasks();
      if (tasksResult is! Success<List<Task>>) {
        return Failure(const UnknownError('Gagal memuat tugas'));
      }

      final tasks = List<Task>.from(tasksResult.data);
      tasks.removeWhere((t) => t.id == id);
      await _saveTasksToLocal(tasks);

      return const Success(true);
    } catch (e) {
      return Failure(UnknownError(e.toString()));
    }
  }

  Future<Result<Task>> toggleTaskStatus(String id) async {
    try {
      final tasksResult = await getTasks();
      if (tasksResult is! Success<List<Task>>) {
        return Failure(const UnknownError('Gagal memuat tugas'));
      }

      final tasks = List<Task>.from(tasksResult.data);
      final index = tasks.indexWhere((t) => t.id == id);
      if (index == -1) {
        return Failure(const NotFoundError('Tugas tidak ditemukan'));
      }

      final current = tasks[index];
      final newStatus = current.status == TaskStatus.selesai
          ? TaskStatus.belumSelesai
          : TaskStatus.selesai;
      final updated = current.copyWith(
        status: newStatus,
        updatedAt: DateTime.now(),
      );

      if (!AppConstants.isDemoMode) {
        return await updateTask(updated);
      }

      tasks[index] = updated;
      await _saveTasksToLocal(tasks);

      return Success(updated);
    } catch (e) {
      return Failure(UnknownError(e.toString()));
    }
  }

  Future<void> _saveTasksToLocal(List<Task> tasks) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(tasks.map((t) => t.toJson()).toList());
    await prefs.setString(_storageKey, jsonString);
  }
}
