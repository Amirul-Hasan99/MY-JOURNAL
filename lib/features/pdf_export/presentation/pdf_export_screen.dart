import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/app_button.dart';
import '../../planner/domain/planner_controller.dart';
import '../../journal/domain/journal_controller.dart';
import '../../tracker/domain/tracker_controller.dart';
import '../../auth/domain/auth_controller.dart';
import '../data/pdf_generator_service.dart';

class PdfExportScreen extends ConsumerWidget {
  const PdfExportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plannerState = ref.watch(plannerControllerProvider);
    final journalState = ref.watch(journalControllerProvider);
    final trackerState = ref.watch(trackerControllerProvider);
    final user = ref.watch(currentUserProvider);

    final userName = user?.displayName ?? 'Pengguna My Journal';

    final isLoading =
        plannerState.isLoading ||
        journalState.isLoading ||
        trackerState.isLoading;
    final errorMessage =
        plannerState.errorMessage ??
        journalState.errorMessage ??
        trackerState.errorMessage;

    return Scaffold(
      appBar: AppBar(title: const Text('Ekspor Laporan PDF')),
      body: isLoading
          ? const LoadingView(message: 'Menyiapkan data laporan...')
          : errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(errorMessage, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    AppButton(
                      label: 'Coba Lagi',
                      onPressed: () {
                        ref
                            .read(plannerControllerProvider.notifier)
                            .loadTasks();
                        ref
                            .read(journalControllerProvider.notifier)
                            .loadEntries();
                        ref.read(trackerControllerProvider.notifier).loadAll();
                      },
                    ),
                  ],
                ),
              ),
            )
          : PdfPreview(
              build: (format) => PdfGeneratorService.generateJournalReport(
                userName: userName,
                entries: journalState.entries,
                tasks: plannerState.tasks,
                goals: trackerState.goals,
                habits: trackerState.habits,
                completedHabitIds: trackerState.todayLogs
                    .where((log) => log.isCompleted)
                    .map((log) => log.habitId)
                    .toSet(),
              ),
              canChangeOrientation: false,
              canChangePageFormat: false,
              canDebug: false,
              pdfFileName: 'My_Journal_Report.pdf',
              previewPageMargin: const EdgeInsets.all(16),
              loadingWidget: const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
    );
  }
}
