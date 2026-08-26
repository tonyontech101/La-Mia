import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/fade_in_view.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../auth/data/user_model.dart';
import '../../auth/data/user_repository.dart';
import 'achievements_screen.dart';

/// Screen allowing the user to edit their profile photo, display name, bio, and featured achievement badge.
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
  bool _loadError = false;
  File? _selectedImage;
  bool _removePhoto = false;
  String? _currentPhotoUrl;

  UserModel? _currentUserModel;
  List<AchievementItem> _userAchievements = [];
  String? _selectedAchievementId;
  String? _initialAchievementId;

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

    _loadCurrentProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  /// Computed change tracker — compares live field values to the loaded model.
  bool get _hasChanges {
    final m = _currentUserModel;
    if (m == null) return false;
    final nameChanged = _nameController.text.trim() != m.displayName;
    final bioChanged = _bioController.text.trim() != (m.bio ?? '');
    final photoChanged = _selectedImage != null || _removePhoto;
    final achChanged = _selectedAchievementId != _initialAchievementId;
    return nameChanged || bioChanged || photoChanged || achChanged;
  }

  void _onSelectAchievement(String? achievementId) {
    if (_selectedAchievementId == achievementId) return;
    setState(() {
      _selectedAchievementId = achievementId;
    });
  }

  void _showDiscardGuardDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
        title: Text(
          'Discard your changes?',
          style: AppTypography.headline(color: AppColors.textPrimary)
              .copyWith(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        content: Text(
          'Your edits to your name, bio, or badge will be lost.',
          style: AppTypography.body(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Keep editing',
              style: AppTypography.body(color: AppColors.textSecondary)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, false);
            },
            child: Text(
              'Discard',
              style: AppTypography.body(color: AppColors.error)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
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
      final achievements =
          AchievementCatalog.forUser(model, isChefOfMonth: false);
      if (mounted) {
        setState(() {
          _currentUserModel = model;
          _userAchievements = achievements;
          _selectedAchievementId = model?.featuredAchievementId;
          _initialAchievementId = model?.featuredAchievementId;
          _nameController.text =
              model?.displayName ?? user.displayName ?? '';
          _bioController.text = model?.bio ?? '';
          _currentPhotoUrl = model?.photoUrl ?? user.photoURL;
          _isLoading = false;
          _loadError = false;
        });
        _animationController.forward();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = true;
        });
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
        });
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Couldn\'t pick that image. Try another.',
          isError: true,
        );
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadii.card),
        ),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 4),
              Text(
                'Update your photo',
                style: AppTypography.title(color: AppColors.textPrimary)
                    .copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.lg),
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
                  const SizedBox(width: AppSpacing.md),
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
              const SizedBox(height: AppSpacing.sm),
              if (_currentPhotoUrl != null || _selectedImage != null)
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() {
                        _selectedImage = null;
                        _removePhoto = true;
                      });
                    },
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.error,
                    ),
                    label: const Text(
                      'Remove current photo',
                      style: TextStyle(color: AppColors.error),
                    ),
                  ),
                ),
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

    // Step 1: Upload photo to Firebase Storage (if changed)
    if (_selectedImage != null) {
      try {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('users')
            .child(user.uid)
            .child('profile_${DateTime.now().millisecondsSinceEpoch}.jpg');

        final uploadTask = storageRef.putFile(
          _selectedImage!,
          SettableMetadata(contentType: 'image/jpeg'),
        );

        await uploadTask;
        photoUrl = await storageRef.getDownloadURL();
        photoChanged = true;
      } catch (e) {
        photoError = e.toString();
      }
    } else if (_removePhoto) {
      photoUrl = '';
      photoChanged = true;
    }

    // Step 2: Update Firestore (bio + name + photo URL + featured achievement)
    try {
      await _userRepo.updateProfile(
        user.uid,
        displayName: name,
        bio: bio,
        photoUrl: photoChanged ? photoUrl : null,
        featuredAchievementId: _selectedAchievementId,
        clearFeaturedAchievement: _selectedAchievementId == null,
      );
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Couldn\'t save your profile. Please try again.',
          isError: true,
        );
        setState(() => _isSaving = false);
      }
      return;
    }

    // Step 3: Sync Firebase Auth profile (non-critical)
    try {
      await user.updateDisplayName(name);
      if (photoChanged) {
        await user.updatePhotoURL(
          photoUrl?.isEmpty ?? true ? null : photoUrl,
        );
      }
      await user.reload();
    } catch (_) {
      // Ignore — Firestore has the truth
    }

    if (mounted) {
      if (photoError != null) {
        AppSnackbar.show(
          context,
          message:
              'Profile saved, but your photo didn\'t upload. Try again later.',
          isError: true,
        );
      } else {
        AppSnackbar.show(context, message: 'Profile updated successfully!');
      }
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_hasChanges) _showDiscardGuardDialog();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          scrolledUnderElevation: 1,
          surfaceTintColor: AppColors.surface,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.textPrimary,
            ),
            onPressed: _isSaving
                ? null
                : (_hasChanges
                    ? _showDiscardGuardDialog
                    : () => Navigator.pop(context, false)),
          ),
          title: Text(
            'Edit Profile',
            style: AppTypography.headline(color: AppColors.textPrimary)
                .copyWith(fontWeight: FontWeight.w700, fontSize: 20),
          ),
          centerTitle: true,
          actions: [
            AnimatedOpacity(
              opacity: (_hasChanges && !_isSaving) ? 1.0 : 0.45,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: Tooltip(
                message: 'Save changes',
                child: TextButton.icon(
                  onPressed:
                      (_hasChanges && !_isSaving) ? _saveProfile : null,
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: _isSaving
                        ? const SizedBox(
                            key: ValueKey('spinner'),
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.primary,
                            ),
                          )
                        : const Icon(
                            Icons.check_rounded,
                            size: 18,
                            key: ValueKey('check'),
                          ),
                  ),
                  label: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: _isSaving
                        ? const SizedBox.shrink(key: ValueKey('saving'))
                        : const Text('Save', key: ValueKey('label')),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xxs,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: _isLoading
            ? const _SkeletonPlaceholder()
            : _loadError
                ? _buildLoadError()
                : FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: GestureDetector(
                        onTap: () => FocusScope.of(context).unfocus(),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: AppSpacing.contentMaxWidth,
                            ),
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.screenH,
                              ),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.center,
                                  children: [
                                    const SizedBox(height: AppSpacing.sm),

                                    // Hero avatar
                                    FadeInView(
                                      child: _ProfilePhotoSection(
                                        currentPhotoUrl: _currentPhotoUrl,
                                        selectedImage: _selectedImage,
                                        isPhotoRemoved: _removePhoto,
                                        displayName:
                                            _nameController.text.isNotEmpty
                                                ? _nameController.text
                                                : (_currentUserModel
                                                        ?.displayName ??
                                                    'U'),
                                        onTap: _showImageSourceDialog,
                                      ),
                                    ),

                                    const SizedBox(
                                      height: AppSpacing.lg,
                                    ),

                                    // Card 1 — Display Name
                                    FadeInView(
                                      delay: const Duration(
                                        milliseconds: 80,
                                      ),
                                      child: _buildCard(
                                        child: _EditField(
                                          label: 'Display Name',
                                          hint:
                                              'How should we call you?',
                                          helperText:
                                              'How you appear across La Mia.',
                                          controller: _nameController,
                                          maxLength: 40,
                                          validator: (value) {
                                            if (value == null ||
                                                value
                                                    .trim()
                                                    .isEmpty) {
                                              return 'Display name can\'t be empty.';
                                            }
                                            if (value
                                                    .trim()
                                                    .length <
                                                2) {
                                              return 'At least 2 characters.';
                                            }
                                            return null;
                                          },
                                          textCapitalization:
                                              TextCapitalization.words,
                                          keyboardType:
                                              TextInputType.name,
                                          textInputAction:
                                              TextInputAction.next,
                                        ),
                                      ),
                                    ),

                                    const SizedBox(
                                      height: AppSpacing.md,
                                    ),

                                    // Card 2 — Bio
                                    FadeInView(
                                      delay: const Duration(
                                        milliseconds: 160,
                                      ),
                                      child: _buildCard(
                                        child: _EditField(
                                          label: 'Bio',
                                          hint:
                                              'Share your cooking style, your favorite dish, or a little about your kitchen\u2026',
                                          helperText:
                                              'Shows under your name on your profile.',
                                          controller: _bioController,
                                          maxLength: 160,
                                          maxLines: 4,
                                          minLines: 3,
                                          textCapitalization:
                                              TextCapitalization
                                                  .sentences,
                                          keyboardType:
                                              TextInputType.multiline,
                                          textInputAction:
                                              TextInputAction.newline,
                                        ),
                                      ),
                                    ),

                                    const SizedBox(
                                      height: AppSpacing.md,
                                    ),

                                    // Card 3 — Showcase Badge
                                    FadeInView(
                                      delay: const Duration(
                                        milliseconds: 240,
                                      ),
                                      child: _buildCard(
                                        child: _ShowcaseBadgeSection(
                                          achievements:
                                              _userAchievements,
                                          selectedId:
                                              _selectedAchievementId,
                                          onSelected:
                                              _onSelectAchievement,
                                          currentUserModel:
                                              _currentUserModel,
                                        ),
                                      ),
                                    ),

                                    const SizedBox(
                                      height: AppSpacing.xl,
                                    ),

                                    // Discard button
                                    if (_hasChanges && !_isSaving)
                                      TextButton(
                                        onPressed:
                                            _showDiscardGuardDialog,
                                        child: Text(
                                          'Discard changes',
                                          style: AppTypography.body(
                                            color: AppColors
                                                .textSecondary,
                                          ).copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),

                                    const SizedBox(
                                      height: AppSpacing.xl,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 40,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'We couldn\'t load your profile',
              style: AppTypography.bodyStrong(
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Check your connection and try again.',
              style: AppTypography.caption(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Try again',
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _loadError = false;
                });
                _animationController.reset();
                _loadCurrentProfile();
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Profile Photo Section
// ---------------------------------------------------------------------------

class _ProfilePhotoSection extends StatelessWidget {
  const _ProfilePhotoSection({
    required this.currentPhotoUrl,
    required this.selectedImage,
    required this.isPhotoRemoved,
    required this.onTap,
    required this.displayName,
  });

  final String? currentPhotoUrl;
  final File? selectedImage;
  final bool isPhotoRemoved;
  final VoidCallback onTap;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        label: 'Profile photo. Double tap to change.',
        button: true,
        child: PressableScale(
          pressedScale: 0.97,
          onTap: onTap,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceAlt,
                  border: Border.all(
                    color: AppColors.primary,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.18),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(child: _buildImage()),
              ),
              // Camera FAB — 44px hit area, 36px visual
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: onTap,
                  behavior: HitTestBehavior.translucent,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.surface,
                            width: 3,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: AppColors.cardShadow,
                              blurRadius: 6,
                              offset: Offset(0, 2),
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (selectedImage != null) {
      return Image.file(
        selectedImage!,
        fit: BoxFit.cover,
        width: 96,
        height: 96,
      );
    }
    if (!isPhotoRemoved &&
        currentPhotoUrl != null &&
        currentPhotoUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: currentPhotoUrl!,
        fit: BoxFit.cover,
        width: 96,
        height: 96,
        placeholder: (context, url) => const Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.primary,
          ),
        ),
        errorWidget: (context, error, stackTrace) => _buildFallback(),
      );
    }
    return _buildFallback();
  }

  Widget _buildFallback() {
    final initial =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';
    return Container(
      color: AppColors.surfaceAlt,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 38,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Edit Field
// ---------------------------------------------------------------------------

class _EditField extends StatelessWidget {
  const _EditField({
    required this.label,
    required this.hint,
    required this.controller,
    this.helperText,
    this.maxLength,
    this.maxLines = 1,
    this.minLines,
    this.validator,
    this.textCapitalization = TextCapitalization.none,
    this.keyboardType,
    this.textInputAction,
  });

  final String label;
  final String hint;
  final String? helperText;
  final TextEditingController controller;
  final int? maxLength;
  final int maxLines;
  final int? minLines;
  final String? Function(String?)? validator;
  final TextCapitalization textCapitalization;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.label(color: AppColors.textPrimary)
              .copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.3),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          controller: controller,
          maxLength: maxLength,
          maxLines: maxLines,
          minLines: minLines,
          textCapitalization: textCapitalization,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          inputFormatters:
              maxLength != null ? [LengthLimitingTextInputFormatter(maxLength)] : null,
          style: AppTypography.body(
            color: AppColors.textPrimary,
          ).copyWith(fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTypography.body(
              color: AppColors.textSecondary,
            ).copyWith(fontSize: 16),
            helperText: helperText,
            helperStyle: AppTypography.caption(
              color: AppColors.textSecondary,
            ),
            helperMaxLines: 2,
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 14,
            ),
            counterStyle: AppTypography.caption(
              color: AppColors.textSecondary,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.field),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.field),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.field),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.field),
              borderSide: const BorderSide(
                color: AppColors.error,
                width: 1.5,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.field),
              borderSide: const BorderSide(
                color: AppColors.error,
                width: 2,
              ),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Image Source Button (bottom sheet)
// ---------------------------------------------------------------------------

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
    return PressableScale(
      pressedScale: 0.97,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadii.button),
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

// ---------------------------------------------------------------------------
// Showcase Badge Section (compact chip picker)
// ---------------------------------------------------------------------------

class _ShowcaseBadgeSection extends StatelessWidget {
  const _ShowcaseBadgeSection({
    required this.achievements,
    required this.selectedId,
    required this.onSelected,
    required this.currentUserModel,
  });

  final List<AchievementItem> achievements;
  final String? selectedId;
  final ValueChanged<String?> onSelected;
  final UserModel? currentUserModel;

  @override
  Widget build(BuildContext context) {
    final unlocked =
        achievements.where((a) => a.isUnlocked).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.emoji_events_rounded,
              size: 18,
              color: AppColors.secondary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Showcase badge',
                style: AppTypography.bodyStrong(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AchievementsScreen(
                      user: currentUserModel,
                      isChefOfMonth: false,
                    ),
                  ),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: AppColors.secondary,
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'See all',
                    style: AppTypography.caption(
                      color: AppColors.secondary,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: AppColors.secondary,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'Pin one badge to shine on your profile header.',
          style: AppTypography.caption(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: unlocked.length + 1, // +1 for the default option
            separatorBuilder: (_, _) =>
                const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _BadgeChip(
                  icon: Icons.auto_awesome_rounded,
                  label: 'Kitchen Level',
                  color: AppColors.primary,
                  isSelected: selectedId == null,
                  onTap: () => onSelected(null),
                );
              }
              final item = unlocked[index - 1];
              return _BadgeChip(
                icon: item.icon,
                label: item.title,
                color: item.badgeColor,
                isSelected: selectedId == item.id,
                onTap: () => onSelected(item.id),
              );
            },
          ),
        ),
        if (unlocked.isEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceAlt,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  color: AppColors.textSecondary,
                  size: 16,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'No showcase badges yet \u2014 cook and share recipes to unlock them.',
                  style: AppTypography.caption(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Badge Chip
// ---------------------------------------------------------------------------

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Luminance guard: light badge colors use textPrimary instead of white
    final isLightBadge = color.computeLuminance() > 0.5;
    final textColor =
        isSelected ? (isLightBadge ? AppColors.textPrimary : AppColors.onPrimary) : AppColors.textPrimary;
    final iconColor =
        isSelected ? (isLightBadge ? AppColors.textPrimary : AppColors.onPrimary) : color;
    final bgColor =
        isSelected
            ? color
            : AppColors.surface;

    return PressableScale(
      pressedScale: 0.96,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTypography.caption(color: textColor)
                  .copyWith(fontWeight: FontWeight.w700, fontSize: 12),
            ),
            if (isSelected) ...[
              const SizedBox(width: 4),
              Icon(Icons.check_rounded, size: 14, color: iconColor),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loading Skeleton
// ---------------------------------------------------------------------------

class _SkeletonPlaceholder extends StatelessWidget {
  const _SkeletonPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: AppSpacing.contentMaxWidth,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenH,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: AppSpacing.sm),
              // Avatar skeleton
              _SkeletonBlock(
                width: 96,
                height: 96,
                shape: BoxShape.circle,
              ),
              const SizedBox(height: AppSpacing.lg),
              // Card 1 skeleton
              _SkeletonBlock(
                width: double.infinity,
                height: 56,
                borderRadius: AppRadii.card,
              ),
              const SizedBox(height: AppSpacing.md),
              // Card 2 skeleton
              _SkeletonBlock(
                width: double.infinity,
                height: 96,
                borderRadius: AppRadii.card,
              ),
              const SizedBox(height: AppSpacing.md),
              // Chip row skeleton
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _SkeletonBlock(
                    width: 96,
                    height: 36,
                    borderRadius: AppRadii.pill,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _SkeletonBlock(
                    width: 80,
                    height: 36,
                    borderRadius: AppRadii.pill,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _SkeletonBlock(
                    width: 72,
                    height: 36,
                    borderRadius: AppRadii.pill,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkeletonBlock extends StatefulWidget {
  const _SkeletonBlock({
    required this.width,
    required this.height,
    this.shape,
    this.borderRadius,
  });

  final double width;
  final double height;
  final BoxShape? shape;
  final double? borderRadius;

  @override
  State<_SkeletonBlock> createState() => _SkeletonBlockState();
}

class _SkeletonBlockState extends State<_SkeletonBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final child = Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        shape: widget.shape ?? BoxShape.rectangle,
        borderRadius: widget.shape == null && widget.borderRadius != null
            ? BorderRadius.circular(widget.borderRadius!)
            : null,
      ),
    );

    if (reduceMotion) return child;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) => Opacity(
        opacity: _animation.value,
        child: child,
      ),
      child: child,
    );
  }
}
