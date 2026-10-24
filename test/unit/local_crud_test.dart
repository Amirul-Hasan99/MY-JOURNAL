import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_journal/core/config/app_constants.dart';
import 'package:my_journal/core/errors/app_error.dart';
import 'package:my_journal/features/journal/data/journal_repository.dart';
import 'package:my_journal/features/notifications/data/notification_inbox.dart';
import 'package:my_journal/features/planner/data/planner_repository.dart';
import 'package:my_journal/features/tracker/data/tracker_repository.dart';
import 'package:my_journal/shared/models/goal.dart';
import 'package:my_journal/shared/models/habit.dart';
import 'package:my_journal/shared/models/journal_entry.dart';
import 'package:my_journal/shared/models/mood_entry.dart';
import 'package:my_journal/shared/models/task.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('local CRUD with explicitly enabled demo storage', () {
    test(
      'Planner starts empty and supports create, read, update, delete',
      () async {
        final repository = PlannerRepository();
        final initial = await repository.getTasks();
        expect((initial as Success<List<Task>>).data, isEmpty);

        final created = await repository.createTask(_task(''));
        final task = (created as Success<Task>).data;
        expect(task.id, isNotEmpty);
        expect(
          (await repository.getTasks() as Success<List<Task>>).data,
          hasLength(1),
        );

        final updated = await repository.updateTask(
          task.copyWith(title: 'Tugas diubah'),
        );
        expect((updated as Success<Task>).data.title, 'Tugas diubah');
        expect(await repository.deleteTask(task.id), isA<Success<bool>>());
        expect(
          (await repository.getTasks() as Success<List<Task>>).data,
          isEmpty,
        );
      },
      skip: !AppConstants.isDemoMode,
    );

    test(
      'Journal starts empty and supports create, read, update, delete',
      () async {
        final repository = JournalRepository();
        expect(
          (await repository.getEntries() as Success<List<JournalEntry>>).data,
          isEmpty,
        );

        final created = await repository.createEntry(_entry(''));
        final entry = (created as Success<JournalEntry>).data;
        expect(
          (await repository.getEntries() as Success<List<JournalEntry>>).data,
          hasLength(1),
        );

        final updated = await repository.updateEntry(
          entry.copyWith(title: 'Catatan diubah'),
        );
        expect((updated as Success<JournalEntry>).data.title, 'Catatan diubah');
        expect(await repository.deleteEntry(entry.id), isA<Success<bool>>());
        expect(
          (await repository.getEntries() as Success<List<JournalEntry>>).data,
          isEmpty,
        );
      },
      skip: !AppConstants.isDemoMode,
    );

    test('Tracker supports habit, log, goal create/update/delete', () async {
      final repository = TrackerRepository();
      expect(
        (await repository.getHabits() as Success<List<Habit>>).data,
        isEmpty,
      );
      expect(
        (await repository.getGoals() as Success<List<Goal>>).data,
        isEmpty,
      );

      final now = DateTime.now();
      final habit =
          (await repository.createHabit(_habit('')) as Success<Habit>).data;
      expect(habit.id, isNotEmpty);
      expect(
        (await repository.toggleHabitLog(
          habit.id,
          '2026-10-23',
        ) as Success<HabitLog>).data.isCompleted,
        isTrue,
      );
      expect(
        (await repository.updateHabit(
          habit.copyWith(name: 'Kebiasaan diubah'),
        ) as Success<Habit>).data.name,
        'Kebiasaan diubah',
      );
      expect(await repository.deleteHabit(habit.id), isA<Success<bool>>());

      final goal =
          (await repository.createGoal(_goal('', now)) as Success<Goal>).data;
      expect(goal.id, isNotEmpty);
      expect(
        (await repository.updateGoal(
          goal.copyWith(title: 'Tujuan diubah'),
        ) as Success<Goal>).data.title,
        'Tujuan diubah',
      );
      expect(await repository.deleteGoal(goal.id), isA<Success<bool>>());
      expect(
        (await repository.getHabits() as Success<List<Habit>>).data,
        isEmpty,
      );
      expect(
        (await repository.getGoals() as Success<List<Goal>>).data,
        isEmpty,
      );
    }, skip: !AppConstants.isDemoMode);

    test('notification inbox records and removes real CRUD events', () async {
      final inbox = NotificationInboxNotifier();
      await inbox.record('Tugas ditambahkan', 'Rapat pagi berhasil disimpan.');
      expect(inbox.state, hasLength(1));
      expect(inbox.state.first.body, 'Rapat pagi berhasil disimpan.');
      await inbox.remove(inbox.state.first.id);
      expect(inbox.state, isEmpty);
      inbox.dispose();
    }, skip: !AppConstants.isDemoMode);
  });
}

Task _task(String id) {
  final now = DateTime.now();
  return Task(
    id: id,
    userId: 'test-user',
    title: 'Rapat pagi',
    scheduledAt: now.add(const Duration(hours: 1)),
    priority: TaskPriority.sedang,
    createdAt: now,
    updatedAt: now,
  );
}

JournalEntry _entry(String id) {
  final now = DateTime.now();
  final date =
      '${now.year}-${now.month.toString().padLeft(2, "0")}-${now.day.toString().padLeft(2, "0")}';
  return JournalEntry(
    id: id,
    userId: 'test-user',
    title: 'Catatan hari ini',
    content: 'Isi jurnal uji.',
    entryDate: date,
    mood: MoodType.tenang,
    tags: const [],
    photoUrls: const [],
    createdAt: now,
    updatedAt: now,
  );
}

Habit _habit(String id) {
  final now = DateTime.now();
  return Habit(
    id: id,
    userId: 'test-user',
    name: 'Membaca',
    frequency: HabitFrequency.setiapHari,
    activeDays: const [1, 2, 3, 4, 5, 6, 7],
    reminderEnabled: false,
    isActive: true,
    createdAt: now,
    updatedAt: now,
  );
}

Goal _goal(String id, DateTime now) => Goal(
  id: id,
  userId: 'test-user',
  title: 'Belajar Dart',
  targetDate: now.add(const Duration(days: 30)),
  status: GoalStatus.sedangBerjalan,
  milestones: const [],
  createdAt: now,
  updatedAt: now,
);
