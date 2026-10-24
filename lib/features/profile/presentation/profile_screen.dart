import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_button.dart';
import '../../../shared/utils/profile_photo.dart';
import '../../auth/domain/auth_controller.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../pdf_export/presentation/pdf_export_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil Pengguna'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          children: [
            // Avatar & Name Card
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 46,
                    backgroundColor: AppColors.primary,
                    backgroundImage: profileImageProvider(user?.photoUrl),
                    child: profileImageProvider(user?.photoUrl) == null
                        ? Text(
                            user?.displayName.isNotEmpty == true
                                ? user!.displayName[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              fontSize: 36,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    user?.displayName ?? 'Pengguna My Journal',
                    style: AppTextStyles.heading2.copyWith(fontSize: 20),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user?.email ?? '—',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (user?.bio != null && user!.bio!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      user.bio!,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Ubah Profil'),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const EditProfileScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Profile Menus
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(
                      Icons.picture_as_pdf_outlined,
                      color: AppColors.primary,
                    ),
                    title: const Text('Ekspor Laporan PDF'),
                    subtitle: const Text(
                      'Cetak & bagikan riwayat jurnal dan aktivitas',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const PdfExportScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.tune_rounded,
                      color: AppColors.primary,
                    ),
                    title: const Text('Pengaturan Aplikasi'),
                    subtitle: const Text('Tema gelap, notifikasi, dan akun'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Logout Button
            AppButton(
              label: 'Keluar Akun',
              icon: Icons.logout_rounded,
              variant: AppButtonVariant.outlined,
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Konfirmasi Keluar'),
                    content: const Text(
                      'Apakah kamu yakin ingin keluar dari akun?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Batal'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text(
                          'Keluar',
                          style: TextStyle(color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref.read(authControllerProvider.notifier).logout();
                  if (context.mounted) {
                    context.go('/login');
                  }
                }
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'My Journal v1.0.0 (Neon Edition)',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
