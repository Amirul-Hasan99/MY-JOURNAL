import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class JournalNotification {
  const JournalNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'created_at': createdAt.toIso8601String(),
  };

  factory JournalNotification.fromJson(Map<String, dynamic> json) =>
      JournalNotification(
        id: json['id'] as String,
        title: json['title'] as String,
        body: json['body'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

final notificationInboxProvider =
    StateNotifierProvider<NotificationInboxNotifier, List<JournalNotification>>(
      (ref) => NotificationInboxNotifier(),
    );

class NotificationInboxNotifier
    extends StateNotifier<List<JournalNotification>> {
  static const _storageKey = 'my_journal_notification_inbox_v1';
  late final Future<void> _ready;

  NotificationInboxNotifier() : super(const []) {
    _ready = _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null) return;
      final items = (jsonDecode(raw) as List<dynamic>)
          .map(
            (item) =>
                JournalNotification.fromJson(item as Map<String, dynamic>),
          )
          .toList();
      state = items;
    } catch (_) {
      state = const [];
    }
  }

  Future<void> record(String title, String body) async {
    await _ready;
    final item = JournalNotification(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      body: body,
      createdAt: DateTime.now(),
    );
    state = [item, ...state].take(100).toList(growable: false);
    await _persist();
  }

  Future<void> remove(String id) async {
    await _ready;
    state = state.where((item) => item.id != id).toList(growable: false);
    await _persist();
  }

  Future<void> clear() async {
    await _ready;
    state = const [];
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(state.map((item) => item.toJson()).toList()),
    );
  }
}
