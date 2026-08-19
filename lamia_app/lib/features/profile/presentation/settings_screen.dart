import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../auth/data/user_repository.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.isGuest = false});

  final bool isGuest;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Accordion state: null = all collapsed, 0 = Profile Info, 1 = Change Password, 2 = Change Email
  int? _expandedIndex;

  final UserRepository _userRepo = UserRepository();
  final ImagePicker _imagePicker = ImagePicker();

  // Loading state for initial data fetch
  bool _isLoadingProfile = true;

  // Notification Preference
  bool _enableNotifications = true;

  // --- Profile Info Fields ---
  final _profileFormKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _bioController;
  File? _selectedImage;
  String? _currentPhotoUrl;
  bool _removePhoto = false;
  bool _isSavingProfile = false;

  // --- Change Password Fields ---
  final _passwordFormKey = GlobalKey<FormState>();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isUpdatingPassword = false;

  // --- Change Email Fields ---
  final _emailFormKey = GlobalKey<FormState>();
  final TextEditingController _newEmailController = TextEditingController();
  final TextEditingController _confirmEmailController = TextEditingController();
  bool _isUpdatingEmail = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _bioController = TextEditingController();

    _nameController.addListener(() => setState(() {}));
    _bioController.addListener(() => setState(() {}));
    _newPasswordController.addListener(() => setState(() {}));
    _confirmPasswordController.addListener(() => setState(() {}));
    _newEmailController.addListener(() => setState(() {}));
    _confirmEmailController.addListener(() => setState(() {}));

    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _newEmailController.dispose();
    _confirmEmailController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    if (widget.isGuest) {
      setState(() {
        _isLoadingProfile = false;
        _nameController.text = 'Guest Foodie';
        _bioController.text = 'Browsing as guest foodie.';
      });
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoadingProfile = false);
      return;
    }

    try {
      final model = await _userRepo.getUser(user.uid);
      
      // Also load notifications pref from Firestore user doc if present, default to true
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final hasNotifPref = userDoc.data()?.containsKey('enableNotifications') ?? false;
      final notifPref = hasNotifPref ? (userDoc.data()?['enableNotifications'] as bool) : true;

      if (mounted) {
        setState(() {
          _nameController.text = model?.displayName ?? user.displayName ?? '';
          _bioController.text = model?.bio ?? '';
          _currentPhotoUrl = model?.photoUrl ?? user.photoURL;
          _enableNotifications = notifPref;
          _isLoadingProfile = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingProfile = false);
      }
    }
  }

  void _toggleAccordion(int index) {
    setState(() {
      if (_expandedIndex == index) {
        _expandedIndex = null; // collapse
      } else {
        _expandedIndex = index; // expand
      }
    });
  }

  // --- Profile Picture Pick Options ---
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
                      });
                    },
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.error,
                    ),
                    label: const Text(
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

  // --- Profile Info Actions ---
  Future<void> _saveProfile() async {
    if (widget.isGuest) {
      AppSnackbar.show(context, message: 'Guests cannot modify profile settings!');
      return;
    }

    if (!_profileFormKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSavingProfile = true);

    final name = _nameController.text.trim();
    final bio = _bioController.text.trim();
    String? photoUrl = _currentPhotoUrl;
    bool photoChanged = false;
    String? photoError;

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
        photoError = 'Photo upload failed: ${e.toString()}';
      }
    } else if (_removePhoto) {
      photoUrl = '';
      photoChanged = true;
    }

    try {
      await _userRepo.updateProfile(
        user.uid,
        displayName: name,
        bio: bio,
        photoUrl: photoChanged ? photoUrl : null,
      );

      await user.updateDisplayName(name);
      if (photoChanged) {
        await user.updatePhotoURL(photoUrl?.isEmpty ?? true ? null : photoUrl);
      }
      await user.reload();

      if (mounted) {
        setState(() {
          if (photoChanged) {
            _currentPhotoUrl = photoUrl?.isEmpty ?? true ? null : photoUrl;
            _selectedImage = null;
            _removePhoto = false;
          }
          _isSavingProfile = false;
        });

        final msg = photoError != null
            ? 'Profile saved! $photoError'
            : 'Profile updated successfully!';
        AppSnackbar.show(context, message: msg);
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Failed to save profile: ${e.toString()}',
        );
        setState(() => _isSavingProfile = false);
      }
    }
  }

  void _clearProfileFields() {
    _loadUserData();
    setState(() {
      _selectedImage = null;
      _removePhoto = false;
    });
  }

  // --- Password Actions ---
  Future<void> _updatePassword() async {
    if (widget.isGuest) {
      AppSnackbar.show(context, message: 'Guests cannot change passwords!');
      return;
    }

    if (!_passwordFormKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isUpdatingPassword = true);

    try {
      await user.updatePassword(_newPasswordController.text);
      if (mounted) {
        AppSnackbar.show(context, message: 'Password updated successfully!');
        _clearPasswordFields();
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        if (e.code == 'requires-recent-login') {
          AppSnackbar.show(
            context,
            message: 'Security sensitive action. Please sign out and sign back in to reset password.',
          );
        } else {
          AppSnackbar.show(context, message: e.message ?? 'Failed to update password');
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(context, message: 'An error occurred: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingPassword = false);
      }
    }
  }

  void _clearPasswordFields() {
    setState(() {
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    });
  }

  // --- Email Actions ---
  Future<void> _updateEmail() async {
    if (widget.isGuest) {
      AppSnackbar.show(context, message: 'Guests cannot change email addresses!');
      return;
    }

    if (!_emailFormKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isUpdatingEmail = true);

    try {
      await user.verifyBeforeUpdateEmail(_newEmailController.text.trim());
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'A verification link has been sent to your new email. Please verify it to complete the update.',
        );
        _clearEmailFields();
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        if (e.code == 'requires-recent-login') {
          AppSnackbar.show(
            context,
            message: 'Security sensitive action. Please sign out and sign back in to change email.',
          );
        } else {
          AppSnackbar.show(context, message: e.message ?? 'Failed to change email');
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(context, message: 'An error occurred: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingEmail = false);
      }
    }
  }

  void _clearEmailFields() {
    setState(() {
      _newEmailController.clear();
      _confirmEmailController.clear();
    });
  }

  // --- Preference Actions ---
  Future<void> _onToggleNotifications(bool value) async {
    setState(() {
      _enableNotifications = value;
    });

    if (widget.isGuest) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'enableNotifications': value,
        }, SetOptions(merge: true));
      } catch (_) {}
    }
  }

  // --- Credits & Acknowledgements Dialog ---
  void _showCreditsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.85,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 12),
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
                  'Credits & Acknowledgements',
                  style: AppTypography.title(color: AppColors.textPrimary)
                      .copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      _buildCreditSection(
                        title: 'La Mia Team',
                        items: [
                          'Anthony Danola - Project Manager',
                          'Jayzer Relator - Lead Developer',
                          'Gabriel Bernardino - UI/UX & Frontend Developer',
                          'Kazumasa Xyron Nagao - Dataset Manager & Developer',
                          'Kurt Justin Dublin - Developer',
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildCreditSection(
                        title: 'Powered By',
                        items: [
                          'Flutter (Google Mobile SDK)',
                          'Firebase Authentication & Cloud Firestore',
                          'Firebase Cloud Storage',
                          'Google Fonts (Fraunces & Inter)',
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildCreditSection(
                        title: 'Dependencies & Open Source',
                        items: [
                          'image_picker - Image capture & selection',
                          'cached_network_image - Caching & performance',
                          'logger & crashlytics - App diagnostics',
                        ],
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: Text(
                          '© 2026 La Mia App. Nabunturan Build.',
                          style: AppTypography.caption(color: AppColors.textSecondary),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCreditSection({required String title, required List<String> items}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.body(color: AppColors.primary)
              .copyWith(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: items.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Text(
                        item,
                        style: AppTypography.body(color: AppColors.textPrimary)
                            .copyWith(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isLoadingProfile
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppSpacing.contentMaxWidth,
                  ),
                  child: Column(
                    children: [
                      // Custom App Bar with Title
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.screenH - 8,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(
                                Icons.arrow_back_rounded,
                                color: AppColors.textPrimary,
                                size: 24,
                              ),
                              tooltip: 'Back',
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Settings',
                              style: AppTypography.headline(
                                color: AppColors.textPrimary,
                              ).copyWith(fontWeight: FontWeight.w700, fontSize: 20),
                            ),
                          ],
                        ),
                      ),

                      // Content List
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.screenH,
                            vertical: 12,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ACCOUNT SECTION HEADER
                              Padding(
                                padding: const EdgeInsets.only(left: 8, bottom: 8),
                                child: Text(
                                  'ACCOUNT',
                                  style: AppTypography.caption(
                                    color: AppColors.textSecondary,
                                  ).copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                    fontSize: 12,
                                  ),
                                ),
                              ),

                              // ACCOUNT CARD ENCLOSING THE ACCORDION
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppColors.border),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: AppColors.cardShadow,
                                      blurRadius: 10,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    // Accordion Tile 1: Profile Info
                                    _buildAccordionTile(
                                      index: 0,
                                      icon: Icons.person_outline_rounded,
                                      title: 'Profile Info',
                                      expandedWidget: _buildProfileInfoForm(),
                                    ),
                                    const Divider(height: 1, color: AppColors.border),

                                    // Accordion Tile 2: Change Password
                                    _buildAccordionTile(
                                      index: 1,
                                      icon: Icons.lock_outline_rounded,
                                      title: 'Change Password',
                                      expandedWidget: _buildChangePasswordForm(),
                                    ),
                                    const Divider(height: 1, color: AppColors.border),

                                    // Accordion Tile 3: Change Email
                                    _buildAccordionTile(
                                      index: 2,
                                      icon: Icons.mail_outline_rounded,
                                      title: 'Change Email',
                                      expandedWidget: _buildChangeEmailForm(),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 28),

                              // PREFERENCES SECTION HEADER
                              Padding(
                                padding: const EdgeInsets.only(left: 8, bottom: 8),
                                child: Text(
                                  'PREFERENCES',
                                  style: AppTypography.caption(
                                    color: AppColors.textSecondary,
                                  ).copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                    fontSize: 12,
                                  ),
                                ),
                              ),

                              // PREFERENCES CARD
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.border),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: AppColors.cardShadow,
                                      blurRadius: 8,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Enable Notifications',
                                      style: AppTypography.body(
                                        color: AppColors.textPrimary,
                                      ).copyWith(fontWeight: FontWeight.w600),
                                    ),
                                    Switch(
                                      value: _enableNotifications,
                                      onChanged: _onToggleNotifications,
                                      activeThumbColor: AppColors.primary,
                                      activeTrackColor: AppColors.primary.withValues(alpha: 0.2),
                                      inactiveThumbColor: AppColors.textSecondary,
                                      inactiveTrackColor: AppColors.border,
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 36),

                              // BUILD VERSION & CREDITS CARD
                              Center(
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 20,
                                    horizontal: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: AppColors.border),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: AppColors.cardShadow,
                                        blurRadius: 8,
                                        offset: Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        'La-Mia (Beta Build)',
                                        style: AppTypography.body(
                                          color: AppColors.textPrimary,
                                        ).copyWith(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'v.1.0.0.0',
                                        style: AppTypography.caption(
                                          color: AppColors.textSecondary,
                                        ).copyWith(fontSize: 13),
                                      ),
                                      const SizedBox(height: 12),
                                      GestureDetector(
                                        onTap: _showCreditsModal,
                                        child: Text(
                                          'Credits & Acknowledgement',
                                          style: AppTypography.caption(
                                            color: AppColors.secondary,
                                          ).copyWith(
                                            fontWeight: FontWeight.bold,
                                            decoration: TextDecoration.underline,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // --- REUSABLE ACCORDION CONTAINER ---
  Widget _buildAccordionTile({
    required int index,
    required IconData icon,
    required String title,
    required Widget expandedWidget,
  }) {
    final isExpanded = _expandedIndex == index;
    return Column(
      children: [
        InkWell(
          onTap: () => _toggleAccordion(index),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(index == 0 ? 20 : 0),
            topRight: Radius.circular(index == 0 ? 20 : 0),
            bottomLeft: Radius.circular(index == 2 && !isExpanded ? 20 : 0),
            bottomRight: Radius.circular(index == 2 && !isExpanded ? 20 : 0),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Icon(icon, color: AppColors.textPrimary, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: AppTypography.body(color: AppColors.textPrimary)
                        .copyWith(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
                AnimatedRotation(
                  turns: isExpanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: isExpanded
              ? Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
                  child: ClipRect(child: expandedWidget),
                )
              : const SizedBox(width: double.infinity, height: 0),
        ),
      ],
    );
  }

  // --- PANEL 1 FORM: Profile Info ---
  Widget _buildProfileInfoForm() {
    return Form(
      key: _profileFormKey,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar edit column
              Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surfaceAlt,
                      border: Border.all(color: AppColors.primary, width: 2),
                    ),
                    child: ClipOval(
                      child: _buildAvatarImage(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _showImageSourceDialog,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        'Edit',
                        style: AppTypography.caption(color: AppColors.textPrimary)
                            .copyWith(fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),

              // Inputs column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSettingsTextField(
                      label: 'Name',
                      hint: 'Enter your nickname...',
                      controller: _nameController,
                      maxLength: 50,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Name cannot be empty';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildSettingsTextField(
                      label: 'Bio',
                      hint: 'Enter your bio...',
                      controller: _bioController,
                      maxLength: 150,
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildSecondaryButton(
                label: 'Clear',
                onPressed: _isSavingProfile ? null : _clearProfileFields,
              ),
              const SizedBox(width: 12),
              _buildPrimaryActionButton(
                label: 'Save',
                isLoading: _isSavingProfile,
                onPressed: _saveProfile,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarImage() {
    if (_selectedImage != null) {
      return Image.file(_selectedImage!, fit: BoxFit.cover);
    }
    if (!_removePhoto && _currentPhotoUrl != null && _currentPhotoUrl!.isNotEmpty) {
      return Image.network(
        _currentPhotoUrl!,
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => _buildAvatarFallback(),
      );
    }
    return _buildAvatarFallback();
  }

  Widget _buildAvatarFallback() {
    return const Icon(
      Icons.person_rounded,
      size: 40,
      color: AppColors.textSecondary,
    );
  }

  // --- PANEL 2 FORM: Change Password ---
  Widget _buildChangePasswordForm() {
    if (widget.isGuest) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Password changes are not available for Guest accounts. Please register to customize your credentials.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      );
    }

    return Form(
      key: _passwordFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSettingsTextField(
            label: 'New Password',
            hint: 'Enter new password...',
            controller: _newPasswordController,
            obscureText: _obscureNewPassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureNewPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                color: AppColors.textSecondary,
                size: 20,
              ),
              onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Password cannot be empty';
              }
              if (value.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          _buildSettingsTextField(
            label: 'Confirm Password',
            hint: 'Confirm new password here...',
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirmPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                color: AppColors.textSecondary,
                size: 20,
              ),
              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please confirm your password';
              }
              if (value != _newPasswordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildSecondaryButton(
                label: 'Clear',
                onPressed: _isUpdatingPassword ? null : _clearPasswordFields,
              ),
              const SizedBox(width: 12),
              _buildPrimaryActionButton(
                label: 'Verify',
                isLoading: _isUpdatingPassword,
                onPressed: _updatePassword,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- PANEL 3 FORM: Change Email ---
  Widget _buildChangeEmailForm() {
    if (widget.isGuest) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Email updates are not available for Guest accounts. Please register to customize your credentials.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      );
    }

    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSettingsTextField(
            label: 'New email',
            hint: 'Enter new email...',
            controller: _newEmailController,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Email cannot be empty';
              }
              final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
              if (!emailRegex.hasMatch(value.trim())) {
                return 'Please enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          _buildSettingsTextField(
            label: 'Confirm new email',
            hint: 'Confirm new email here...',
            controller: _confirmEmailController,
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please confirm your email';
              }
              if (value.trim() != _newEmailController.text.trim()) {
                return 'Emails do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildSecondaryButton(
                label: 'Clear',
                onPressed: _isUpdatingEmail ? null : _clearEmailFields,
              ),
              const SizedBox(width: 12),
              _buildPrimaryActionButton(
                label: 'Verify',
                isLoading: _isUpdatingEmail,
                onPressed: _updateEmail,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- HELPER COMPONENT: Styled TextField ---
  Widget _buildSettingsTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    int? maxLength,
    int maxLines = 1,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.caption(color: AppColors.textPrimary)
              .copyWith(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: AppTypography.body(color: AppColors.textPrimary).copyWith(fontSize: 14),
          maxLength: maxLength,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTypography.body(color: AppColors.textSecondary)
                .copyWith(fontSize: 14),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: AppColors.surfaceAlt,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            counterText: '',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error, width: 1.5),
            ),
          ),
          validator: validator,
        ),
        if (maxLength != null)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 2, right: 4),
              child: Text(
                '${controller.text.length}/$maxLength',
                style: AppTypography.caption(color: AppColors.textSecondary).copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // --- HELPER COMPONENT: Styled Action Buttons ---
  Widget _buildSecondaryButton({
    required String label,
    required VoidCallback? onPressed,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      ),
      child: Text(
        label,
        style: AppTypography.body(color: AppColors.textPrimary)
            .copyWith(fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }

  Widget _buildPrimaryActionButton({
    required String label,
    required bool isLoading,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      ),
      child: isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.onPrimary,
              ),
            )
          : Text(
              label,
              style: AppTypography.body(color: AppColors.onPrimary)
                  .copyWith(fontWeight: FontWeight.w700, fontSize: 13),
            ),
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 24, color: AppColors.primary),
            const SizedBox(height: 6),
            Text(
              label,
              style: AppTypography.body(color: AppColors.textPrimary)
                  .copyWith(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
