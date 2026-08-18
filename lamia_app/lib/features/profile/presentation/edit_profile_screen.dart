import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/primary_button.dart';
import '../../auth/data/user_repository.dart';

/// Screen allowing the user to edit their profile photo, display name, and bio.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen>
    with SingleTickerProviderStateMixin {
  final UserRepository _userRepo = UserRepository();
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();

  late TextEditingController _nameController;
  late TextEditingController _bioController;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasChanges = false;
  File? _selectedImage;
  bool _removePhoto = false;
  String? _currentPhotoUrl;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _bioController = TextEditingController();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _nameController.addListener(_onFieldChanged);
    _bioController.addListener(_onFieldChanged);
    _loadCurrentProfile();
  }

  @override
  void dispose() {
    _nameController.removeListener(_onFieldChanged);
    _bioController.removeListener(_onFieldChanged);
    _nameController.dispose();
    _bioController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    // Setting the controllers from Firestore during initialization is not a
    // user edit and must not enable the Save/Discard controls.
    if (!_isLoading && !_hasChanges && mounted) {
      setState(() => _hasChanges = true);
    }
  }

  Future<void> _loadCurrentProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() => _isLoading = false);
        _animationController.forward();
      }
      return;
    }
    try {
      final model = await _userRepo.getUser(user.uid);
      if (mounted) {
        setState(() {
          _nameController.text = model?.displayName ?? user.displayName ?? '';
          _bioController.text = model?.bio ?? '';
          _currentPhotoUrl = model?.photoUrl ?? user.photoURL;
          _isLoading = false;
        });
        _animationController.forward();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
        _animationController.forward();
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (pickedFile != null && mounted) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _removePhoto = false;
          _hasChanges = true;
        });
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Failed to pick image: ${e.toString()}',
        );
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Change Profile Photo',
                style: AppTypography.title(
                  color: AppColors.textPrimary,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _ImageSourceButton(
                      icon: Icons.camera_alt_rounded,
                      label: 'Camera',
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.camera);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _ImageSourceButton(
                      icon: Icons.photo_library_rounded,
                      label: 'Gallery',
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.gallery);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_currentPhotoUrl != null || _selectedImage != null)
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() {
                        _selectedImage = null;
                        _removePhoto = true;
                        _hasChanges = true;
                      });
                    },
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.error,
                    ),
                    label: Text(
                      'Remove Photo',
                      style: TextStyle(color: AppColors.error),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_hasChanges) {
      Navigator.pop(context, false);
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    final name = _nameController.text.trim();
    final bio = _bioController.text.trim();
    String? photoUrl = _currentPhotoUrl;
    bool photoChanged = false;
    String? photoError;

    // ── Step 1: Upload photo to Firebase Storage (if changed) ────────────
    if (_selectedImage != null) {
      try {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('users')
            .child(user.uid)
            // A new object name gives the avatar a new download URL, so
            // CachedNetworkImage cannot keep showing the previous upload.
            .child('profile_${DateTime.now().millisecondsSinceEpoch}.jpg');

        final uploadTask = storageRef.putFile(
          _selectedImage!,
          SettableMetadata(contentType: 'image/jpeg'),
        );

        await uploadTask;
        photoUrl = await storageRef.getDownloadURL();
        photoChanged = true;
      } catch (e) {
        // Photo upload failed — continue saving name & bio anyway
        photoError = 'Photo upload failed: ${e.toString()}';
      }
    } else if (_removePhoto) {
      // Remove only when that action was explicitly selected. Editing a name
      // or bio must never delete the existing avatar.
      photoUrl = '';
      photoChanged = true;
    }

    // ── Step 2: Update Firestore (bio + name + photo URL) ────────────────
    try {
      await _userRepo.updateProfile(
        user.uid,
        displayName: name,
        bio: bio,
        photoUrl: photoChanged ? photoUrl : null,
      );
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Failed to save profile: ${e.toString()}',
        );
        setState(() => _isSaving = false);
      }
      return;
    }

    // ── Step 3: Sync Firebase Auth profile (non-critical) ────────────────
    try {
      await user.updateDisplayName(name);
      if (photoChanged) {
        await user.updatePhotoURL(photoUrl?.isEmpty ?? true ? null : photoUrl);
      }
      await user.reload();
    } catch (_) {
      // Ignore — Firestore has the truth
    }

    if (mounted) {
      final msg = photoError != null
          ? 'Profile saved! $photoError'
          : 'Profile updated successfully!';
      AppSnackbar.show(context, message: msg);
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: _isSaving ? null : () => Navigator.pop(context),
        ),
        title: Text(
          'Edit Profile',
          style: AppTypography.title(
            color: AppColors.textPrimary,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: const [SizedBox(width: 48)],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.screenH),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 8),

                          // Profile Photo Section
                          _ProfilePhotoSection(
                            currentPhotoUrl: _currentPhotoUrl,
                            selectedImage: _selectedImage,
                            isPhotoRemoved: _removePhoto,
                            onTap: _showImageSourceDialog,
                          ),

                          const SizedBox(height: 32),

                          // Display Name Field
                          _EditField(
                            label: 'Display Name',
                            hint: 'Enter display name',
                            controller: _nameController,
                            maxLength: 40,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Display name cannot be empty';
                              }
                              if (value.trim().length < 2) {
                                return 'Name must be at least 2 characters';
                              }
                              return null;
                            },
                            textCapitalization: TextCapitalization.words,
                          ),

                          const SizedBox(height: 20),

                          // Bio Field
                          _EditField(
                            label: 'Bio',
                            hint: 'Tell the community about your cooking style...',
                            controller: _bioController,
                            maxLength: 160,
                            maxLines: 4,
                            minLines: 3,
                            textCapitalization: TextCapitalization.sentences,
                          ),

                          const SizedBox(height: 24),

                          // Save Button (alternative to app bar action)
                          PrimaryButton(
                            label: 'Save Changes',
                            onPressed: _hasChanges && !_isSaving ? _saveProfile : null,
                            isLoading: _isSaving,
                          ),

                          const SizedBox(height: 16),

                          // Discard changes text button
                          if (_hasChanges)
                            TextButton(
                              onPressed: _isSaving
                                  ? null
                                  : () {
                                      Navigator.pop(context, false);
                                    },
                              child: Text(
                                'Discard Changes',
                                style: AppTypography.body(
                                  color: AppColors.textSecondary,
                                ).copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _ProfilePhotoSection extends StatelessWidget {
  const _ProfilePhotoSection({
    required this.currentPhotoUrl,
    required this.selectedImage,
    required this.isPhotoRemoved,
    required this.onTap,
  });

  final String? currentPhotoUrl;
  final File? selectedImage;
  final bool isPhotoRemoved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 112,
          height: 112,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.surfaceAlt,
            border: Border.all(color: AppColors.primary, width: 3),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipOval(
            child: _buildImage(),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.cardShadow,
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: AppColors.onPrimary,
                size: 18,
              ),
            ),
          ),
        ),
        if (selectedImage != null || currentPhotoUrl != null)
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Text(
                'Tap to change',
                style: AppTypography.caption(
                  color: AppColors.onPrimary,
                ).copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildImage() {
    if (selectedImage != null) {
      return Image.file(
        selectedImage!,
        fit: BoxFit.cover,
        width: 112,
        height: 112,
      );
    }
    if (!isPhotoRemoved && currentPhotoUrl != null && currentPhotoUrl!.isNotEmpty) {
      return Image.network(
        currentPhotoUrl!,
        fit: BoxFit.cover,
        width: 112,
        height: 112,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const Center(
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
          );
        },
        errorBuilder: (context, error, stackTrace) => _buildFallback(),
      );
    }
    return _buildFallback();
  }

  Widget _buildFallback() {
    return Container(
      color: AppColors.surfaceAlt,
      alignment: Alignment.center,
      child: const Icon(
        Icons.person_rounded,
        size: 48,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  const _EditField({
    required this.label,
    required this.hint,
    required this.controller,
    this.maxLength,
    this.maxLines = 1,
    this.minLines,
    this.validator,
    this.textCapitalization = TextCapitalization.none,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final int? maxLength;
  final int maxLines;
  final int? minLines;
  final String? Function(String?)? validator;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.caption(
            color: AppColors.textPrimary,
          ).copyWith(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.3),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLength: maxLength,
          maxLines: maxLines,
          minLines: minLines,
          textCapitalization: textCapitalization,
          style: AppTypography.body(color: AppColors.textPrimary).copyWith(fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTypography.body(color: AppColors.textSecondary).copyWith(fontSize: 16),
            counterText: '',
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.error, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.error, width: 2),
            ),
          ),
          validator: validator,
        ),
        if (maxLength != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(
              '${controller.text.length}/$maxLength',
              style: AppTypography.caption(
                color: controller.text.length > maxLength! * 0.9
                    ? AppColors.accent
                    : AppColors.textSecondary,
              ).copyWith(fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ),
      ],
    );
  }
}

class _ImageSourceButton extends StatelessWidget {
  const _ImageSourceButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 28, color: AppColors.primary),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTypography.body(
                color: AppColors.textPrimary,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
