import 'package:flutter_test/flutter_test.dart';
import 'package:my_journal/core/config/app_constants.dart';
import 'package:my_journal/core/errors/app_error.dart';
import 'package:my_journal/features/journal/data/journal_repository.dart';
import 'package:my_journal/features/planner/data/planner_repository.dart';
import 'package:my_journal/features/tracker/data/tracker_repository.dart';

void main() {
  group('local data requires explicit demo mode', () {
    test('planner does not read demo cache in connected mode', () async {
      expect(await PlannerRepository().getTasks(), isA<Failure>());
    });

    test('journal does not read demo cache in connected mode', () async {
      expect(await JournalRepository().getEntries(), isA<Failure>());
    });

    test('tracker does not read demo cache in connected mode', () async {
      final repository = TrackerRepository();
      expect(await repository.getHabits(), isA<Failure>());
      expect(await repository.getHabitLogs(), isA<Failure>());
      expect(await repository.getGoals(), isA<Failure>());
    });
  }, skip: AppConstants.isDemoMode);
}
