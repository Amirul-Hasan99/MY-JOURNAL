import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/network/api_client.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/config/app_constants.dart';
import '../../../shared/models/journal_entry.dart';
import '../../../shared/models/mood_entry.dart';

final journalRepositoryProvider = Provider<JournalRepository>(
  (ref) => JournalRepository(),
);

class JournalRepository {
  static const String _storageKey = 'my_journal_cached_entries';
  final ApiClient _api;

  JournalRepository({ApiClient? api}) : _api = api ?? ApiClient();

  Future<Result<List<JournalEntry>>> getEntries({
    String? searchQuery,
    MoodType? moodFilter,
    String? categoryFilter,
  }) async {
    if (!AppConstants.isDemoMode) {
      return _api.get(
        '/api/journal',
        queryParams: {
          if (searchQuery != null && searchQuery.trim().isNotEmpty)
            'searchQuery': searchQuery.trim(),
          if (moodFilter != null) 'moodFilter': moodFilter.label.toLowerCase(),
          if (categoryFilter != null && categoryFilter != 'Semua')
            'categoryFilter': categoryFilter,
        },
        fromJson: (json) => (json as List<dynamic>)
            .map((item) => JournalEntry.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_storageKey);
      List<JournalEntry> entries = [];

      if (cachedJson != null) {
        final List<dynamic> decoded = jsonDecode(cachedJson);
        entries = decoded
            .map((e) => JournalEntry.fromJson(e as Map<String, dynamic>))
            .where((entry) => !{'journal-1', 'journal-2'}.contains(entry.id))
            .toList();
      } else {
        await _saveEntriesToLocal(entries);
      }

      var filtered = entries;

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.toLowerCase();
        filtered = filtered.where((e) {
          final titleMatch = e.title.toLowerCase().contains(q);
          final contentMatch = e.content.toLowerCase().contains(q);
          final tagMatch = e.tags.any((t) => t.toLowerCase().contains(q));
          final dateMatch =
              e.entryDate.toLowerCase().contains(q) ||
              e.createdAt.toIso8601String().toLowerCase().contains(q);
          return titleMatch || contentMatch || tagMatch || dateMatch;
        }).toList();
      }

      if (moodFilter != null) {
        filtered = filtered.where((e) => e.mood == moodFilter).toList();
      }

      if (categoryFilter != null &&
          categoryFilter.isNotEmpty &&
          categoryFilter != 'Semua') {
        filtered = filtered.where((e) => e.category == categoryFilter).toList();
      }

      // Sort newest first
      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return Success(filtered);
    } catch (e) {
      return Failure(CacheError(e.toString()));
    }
  }

  Future<Result<JournalEntry>> getEntryById(String id) async {
    try {
      final entriesResult = await getEntries();
      if (entriesResult is Success<List<JournalEntry>>) {
        final entry = entriesResult.data.firstWhere(
          (e) => e.id == id,
          orElse: () => throw Exception('Entry not found'),
        );
        return Success(entry);
      }
      return Failure(const NotFoundError('Catatan jurnal tidak ditemukan'));
    } catch (e) {
      return Failure(NotFoundError(e.toString()));
    }
  }

  Future<Result<JournalEntry>> createEntry(JournalEntry entry) async {
    if (!AppConstants.isDemoMode) {
      return _api.post(
        '/api/journal',
        data: entry.toJson(),
        fromJson: (json) => JournalEntry.fromJson(json as Map<String, dynamic>),
      );
    }
    try {
      final entriesResult = await getEntries();
      List<JournalEntry> entries = [];
      if (entriesResult is Success<List<JournalEntry>>) {
        entries = List.from(entriesResult.data);
      }

      final newEntry = entry.copyWith(
        id: entry.id.isEmpty ? const Uuid().v4() : entry.id,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      entries.insert(0, newEntry);
      await _saveEntriesToLocal(entries);

      return Success(newEntry);
    } catch (e) {
      return Failure(UnknownError(e.toString()));
    }
  }

  Future<Result<JournalEntry>> updateEntry(JournalEntry entry) async {
    if (!AppConstants.isDemoMode) {
      return _api.patch(
        '/api/journal/${entry.id}',
        data: entry.toJson(),
        fromJson: (json) => JournalEntry.fromJson(json as Map<String, dynamic>),
      );
    }
    try {
      final entriesResult = await getEntries();
      if (entriesResult is! Success<List<JournalEntry>>) {
        return Failure(const UnknownError('Gagal memuat catatan jurnal'));
      }

      final entries = List<JournalEntry>.from(entriesResult.data);
      final index = entries.indexWhere((e) => e.id == entry.id);
      if (index == -1) {
        return Failure(const NotFoundError('Catatan jurnal tidak ditemukan'));
      }

      final updated = entry.copyWith(updatedAt: DateTime.now());
      entries[index] = updated;
      await _saveEntriesToLocal(entries);

      return Success(updated);
    } catch (e) {
      return Failure(UnknownError(e.toString()));
    }
  }

  Future<Result<bool>> deleteEntry(String id) async {
    if (!AppConstants.isDemoMode) return _api.delete('/api/journal/$id');
    try {
      final entriesResult = await getEntries();
      if (entriesResult is! Success<List<JournalEntry>>) {
        return Failure(const UnknownError('Gagal memuat catatan jurnal'));
      }

      final entries = List<JournalEntry>.from(entriesResult.data);
      entries.removeWhere((e) => e.id == id);
      await _saveEntriesToLocal(entries);

      return const Success(true);
    } catch (e) {
      return Failure(UnknownError(e.toString()));
    }
  }

  Future<void> _saveEntriesToLocal(List<JournalEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(entries.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, jsonString);
  }
}
