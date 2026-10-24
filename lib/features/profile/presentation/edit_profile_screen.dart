import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../shared/models/user_profile.dart';
import '../../../shared/utils/profile_photo.dart';
import '../../auth/domain/auth_controller.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  Uint8List? _selectedPhotoBytes;
  String _selectedPhotoMimeType = 'image/jpeg';
  bool _isPickingPhoto = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(currentUserProvider);
    _nameController = TextEditingController(text: user?.displayName ?? '');
    _bioController = TextEditingController(text: user?.bio ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final currentUser = ref.read(currentUserProvider);
    if (currentUser != null) {
      final updated = UserProfile(
        id: currentUser.id,
        authUserId: currentUser.authUserId,
        displayName: _nameController.text.trim(),
        email: currentUser.email,
        bio: _bioController.text.trim(),
        photoUrl: _selectedPhotoBytes == null
            ? currentUser.photoUrl
            : 'data:$_selectedPhotoMimeType;base64,${base64Encode(_selectedPhotoBytes!)}',
        createdAt: currentUser.createdAt,
        updatedAt: DateTime.now(),
      );

      final saved = await ref
          .read(authControllerProvider.notifier)
          .updateProfile(updated);
      if (!saved) {
        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profil gagal disimpan ke backend.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }
    }

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil berhasil diperbarui'),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop();
    }
  }

  Future<void> _pickPhoto() async {
    setState(() => _isPickingPhoto = true);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 900,
        maxHeight: 900,
        imageQuality: 78,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final mimeType = _resolveImageMimeType(bytes, file.mimeType);
      if (mimeType == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gunakan foto berformat JPEG, PNG, atau WebP.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }
      if (bytes.length > 3 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Foto terlalu besar. Pilih foto di bawah 3 MB.'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }
      if (mounted) {
        setState(() {
          _selectedPhotoBytes = bytes;
          _selectedPhotoMimeType = mimeType;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto tidak dapat dibuka. Coba pilih foto lain.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingPhoto = false);
    }
  }

  String? _resolveImageMimeType(Uint8List bytes, String? pickerMimeType) {
    if (pickerMimeType == 'image/jpeg' ||
        pickerMimeType == 'image/png' ||
        pickerMimeType == 'image/webp') {
      return pickerMimeType;
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'image/webp';
    }
    if (bytes.length >= 2 && bytes[0] == 0xff && bytes[1] == 0xd8) {
      return 'image/jpeg';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ubah Profil')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Builder(
                  builder: (context) {
                    final user = ref.watch(currentUserProvider);
                    final imageProvider = _selectedPhotoBytes != null
                        ? profileImageFromBytes(_selectedPhotoBytes!)
                        : profileImageProvider(user?.photoUrl);
                    return Column(
                      children: [
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 48,
                              backgroundColor: AppColors.primaryLight,
                              backgroundImage: imageProvider,
                              child: imageProvider == null
                                  ? Text(
                                      user?.displayName.isNotEmpty == true
                                          ? user!.displayName[0].toUpperCase()
                                          : 'U',
                                      style: const TextStyle(
                                        color: AppColors.primaryDark,
                                        fontSize: 34,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                            Container(
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                tooltip: 'Pilih foto profil dari perangkat',
                                onPressed: _isPickingPhoto ? null : _pickPhoto,
                                icon: _isPickingPhoto
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.photo_camera_outlined,
                                        color: Colors.white,
                                        size: 19,
                                      ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        TextButton.icon(
                          onPressed: _isPickingPhoto ? null : _pickPhoto,
                          icon: const Icon(Icons.upload_outlined),
                          label: const Text('Unggah foto dari perangkat'),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                    );
                  },
                ),
                AppTextField(
                  controller: _nameController,
                  label: 'Nama Lengkap',
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Nama tidak boleh kosong'
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _bioController,
                  label: 'Bio / Kutipan Pribadi',
                  hintText:
                      'Tuliskan sedikit tentang dirimu atau prinsip hidupmu...',
                  maxLines: 3,
                ),
                const SizedBox(height: AppSpacing.xxl),
                AppButton(
                  label: 'Simpan Perubahan',
                  isLoading: _isSaving,
                  onPressed: _save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
