import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/providers/auth_service_provider.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../auth/data/user_repository.dart';
import '../../auth/presentation/email_verification_screen.dart';
import '../../notifications/data/notification_preference_model.dart';
import '../../notifications/data/notification_repository.dart';
import '../../notifications/services/local_notification_service.dart';
import 'edit_profile_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key, this.isGuest = false});

  final bool isGuest;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Accordion state: null = all collapsed, 0 = Profile Info, 1 = Change Password, 2 = Change Email
  int? _expandedIndex;

  UserRepository get _userRepo => ref.read(userRepositoryProvider);
  NotificationRepository get _notifRepo => ref.read(notificationRepositoryProvider);

  // Loading state for initial data fetch
  bool _isLoadingProfile = true;

  // Notification Preference
  bool _enableNotifications = true;
  NotificationPreferenceModel _notifPrefs = NotificationPreferenceModel.defaults();

  // --- Profile Info Fields ---
  late TextEditingController _nameController;
  late TextEditingController _bioController;

  // --- Change Password Fields ---
  final _passwordFormKey = GlobalKey<FormState>();
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isUpdatingPassword = false;

  // --- Change Email Fields ---
  final _emailFormKey = GlobalKey<FormState>();
  final TextEditingController _currentEmailPasswordController = TextEditingController();
  final TextEditingController _newEmailController = TextEditingController();
  final TextEditingController _confirmEmailController = TextEditingController();
  bool _obscureEmailPassword = true;
  bool _isUpdatingEmail = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _bioController = TextEditingController();

    _nameController.addListener(() => setState(() {}));
    _bioController.addListener(() => setState(() {}));
    _currentPasswordController.addListener(() => setState(() {}));
    _newPasswordController.addListener(() => setState(() {}));
    _confirmPasswordController.addListener(() => setState(() {}));
    _currentEmailPasswordController.addListener(() => setState(() {}));
    _newEmailController.addListener(() => setState(() {}));
    _confirmEmailController.addListener(() => setState(() {}));

    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _currentEmailPasswordController.dispose();
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

    final user = ref.read(authServiceProvider).currentUser;
    if (user == null) {
      setState(() => _isLoadingProfile = false);
      return;
    }

    try {
      final model = await _userRepo.getUser(user.uid);
      final pref = await _notifRepo.getNotificationPreferences(user.uid);
      
      // Also load notifications pref from Firestore user doc if present, default to true
      final userDoc = await ref.read(firebaseFirestoreProvider).collection('users').doc(user.uid).get();
      final hasNotifPref = userDoc.data()?.containsKey('enableNotifications') ?? false;
      final notifPref = hasNotifPref ? (userDoc.data()?['enableNotifications'] as bool) : true;

      if (mounted) {
        setState(() {
          _nameController.text = model?.displayName ?? user.displayName ?? '';
          _bioController.text = model?.bio ?? '';
          _enableNotifications = notifPref;
          _notifPrefs = pref;
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

  // --- Password Actions ---
  Future<void> _updatePassword() async {
    if (widget.isGuest) {
      AppSnackbar.show(context, message: 'Guests cannot change passwords!');
      return;
    }

    if (!_passwordFormKey.currentState!.validate()) return;

    final authService = ref.read(authServiceProvider);
    final user = authService.currentUser;
    if (user == null) return;

    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final email = user.email;
    if (email == null) return;

    setState(() => _isUpdatingPassword = true);

    try {
      // Step 1: Reauthenticate with current password
      await authService.reauthenticateWithEmail(
        email: email,
        password: currentPassword,
      );

      // Step 2: Send verification email to current email
      await authService.sendEmailVerification();

      if (!mounted) return;

      // Step 3: Navigate to verification screen
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => EmailVerificationScreen(
            verificationTitle: 'Verify to change password',
            verificationSubtitle:
                'We sent a verification link to your current email. '
                'Click the link, then tap Done below to complete your password change.',
            requireManualConfirm: true,
            onVerified: (ctx) async {
              // Step 4: After verification, update the password
              await authService.changePassword(newPassword);
            },
          ),
        ),
      );

      if (mounted) {
        _clearPasswordFields();
        AppSnackbar.show(
          context,
          message: 'Password updated successfully!',
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: e.message ?? 'Failed to update password. Please try again.',
          isError: true,
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: e.toString().replaceFirst('Exception: ', ''),
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingPassword = false);
      }
    }
  }

  void _clearPasswordFields() {
    setState(() {
      _currentPasswordController.clear();
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

    final authService = ref.read(authServiceProvider);
    final user = authService.currentUser;
    if (user == null) return;

    final currentPassword = _currentEmailPasswordController.text;
    final newEmail = _newEmailController.text.trim();

    setState(() => _isUpdatingEmail = true);

    try {
      // Step 1: Reauthenticate and send verification to new email
      await authService.changeEmail(
        newEmail: newEmail,
        currentPassword: currentPassword,
      );

      if (!mounted) return;

      // Step 2: Navigate to verification screen
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => EmailVerificationScreen(
            verificationTitle: 'Verify your new email',
            verificationSubtitle:
                'We sent a verification link to $newEmail. '
                'Click the link, then tap Done below to complete your email change.',
            requireManualConfirm: true,
            onVerified: (ctx) async {
              // Verify the email was actually updated by Firebase after
              // the user clicked the verification link.
              final currentUser = authService.currentUser;
              if (currentUser == null) {
                throw Exception('User session lost. Please sign in again.');
              }
              await currentUser.reload();
              if (currentUser.email != newEmail) {
                throw Exception(
                  'Email has not been updated yet. '
                  'Please click the verification link first.',
                );
              }
            },
          ),
        ),
      );

      if (mounted) {
        _clearEmailFields();
        AppSnackbar.show(
          context,
          message: 'Email updated successfully!',
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: e.message ?? 'Failed to change email. Please try again.',
          isError: true,
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: e.toString().replaceFirst('Exception: ', ''),
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingEmail = false);
      }
    }
  }

  void _clearEmailFields() {
    setState(() {
      _currentEmailPasswordController.clear();
      _newEmailController.clear();
      _confirmEmailController.clear();
    });
  }

  // --- Preference Actions ---
  Future<void> _onToggleNotifications(bool value) async {
    final user = ref.read(authServiceProvider).currentUser;

    if (value) {
      final granted = await LocalNotificationService.instance.requestPermissions();
      if (!granted) {
        if (mounted) {
          AppSnackbar.show(
            context,
            message: 'Notification permission was not granted by your device settings.',
            isError: true,
          );
        }
        return;
      }

      setState(() => _enableNotifications = true);

      if (!widget.isGuest && user != null) {
        try {
          await ref.read(firebaseFirestoreProvider).collection('users').doc(user.uid).set({
            'enableNotifications': true,
          }, SetOptions(merge: true));
        } catch (_) {}
      }

      if (_notifPrefs.dailySuggestions) {
        await LocalNotificationService.instance.scheduleDailySuggestion();
      }

      if (_notifPrefs.mealReminders) {
        if (user != null) {
          final plan = await ref.read(mealPlanRepositoryProvider).getCurrentWeekPlan(user.uid);
          if (plan != null) {
            await ref.read(mealPlanRepositoryProvider).scheduleMealPlanReminders(plan);
          }
        }
      }
    } else {
      setState(() => _enableNotifications = false);

      if (!widget.isGuest && user != null) {
        try {
          await ref.read(firebaseFirestoreProvider).collection('users').doc(user.uid).set({
            'enableNotifications': false,
          }, SetOptions(merge: true));
        } catch (_) {}
      }

      await LocalNotificationService.instance.cancelAllNotifications();
    }
  }

  Future<void> _onUpdateGranularPreference(String key, bool value) async {
    if (widget.isGuest) return;

    NotificationPreferenceModel updated;
    switch (key) {
      case 'likes':
        updated = _notifPrefs.copyWith(likes: value);
        break;
      case 'comments':
        updated = _notifPrefs.copyWith(comments: value);
        break;
      case 'followers':
        updated = _notifPrefs.copyWith(followers: value);
        break;
      case 'followingNewRecipes':
        updated = _notifPrefs.copyWith(followingNewRecipes: value);
        break;
      case 'mealReminders':
        updated = _notifPrefs.copyWith(mealReminders: value);
        break;
      case 'dailySuggestions':
        updated = _notifPrefs.copyWith(dailySuggestions: value);
        break;
      default:
        return;
    }

    setState(() {
      _notifPrefs = updated;
    });

    final user = ref.read(authServiceProvider).currentUser;
    if (user != null) {
      try {
        await _notifRepo.updateNotificationPreferences(user.uid, updated);
      } catch (_) {}
    }

    if (key == 'dailySuggestions') {
      if (value) {
        await LocalNotificationService.instance.scheduleDailySuggestion();
      } else {
        await LocalNotificationService.instance.cancelDailySuggestion();
      }
    } else if (key == 'mealReminders') {
      if (value) {
        if (user != null) {
          final plan = await ref.read(mealPlanRepositoryProvider).getCurrentWeekPlan(user.uid);
          if (plan != null) {
            await ref.read(mealPlanRepositoryProvider).scheduleMealPlanReminders(plan);
          }
        }
      } else {
        if (user != null) {
          final plan = await ref.read(mealPlanRepositoryProvider).getCurrentWeekPlan(user.uid);
          if (plan != null) {
            await LocalNotificationService.instance.cancelMealRemindersForWeek(plan.days.keys.toList());
          }
        }
      }
    }
  }

  Widget _buildGranularPreferenceTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.body(
                    color: AppColors.textPrimary,
                  ).copyWith(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.caption(
                    color: AppColors.textSecondary,
                  ).copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withValues(alpha: 0.2),
            inactiveThumbColor: AppColors.textSecondary,
            inactiveTrackColor: AppColors.border,
          ),
        ],
      ),
    );
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
                                    // Tile 1: Profile Information
                                    _buildNavigationTile(
                                      icon: Icons.person_outline_rounded,
                                      title: 'Profile Information',
                                      isFirst: true,
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => const EditProfileScreen(),
                                          ),
                                        ).then((_) => _loadUserData());
                                      },
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
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
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
                                    if (_enableNotifications) ...[
                                      const Divider(color: AppColors.border, height: 24),
                                      _buildGranularPreferenceTile(
                                        title: 'Likes & Ratings',
                                        subtitle: 'When someone likes or rates your recipes',
                                        value: _notifPrefs.likes,
                                        onChanged: (val) => _onUpdateGranularPreference('likes', val),
                                      ),
                                      _buildGranularPreferenceTile(
                                        title: 'Comments',
                                        subtitle: 'When someone comments on your recipes',
                                        value: _notifPrefs.comments,
                                        onChanged: (val) => _onUpdateGranularPreference('comments', val),
                                      ),
                                      _buildGranularPreferenceTile(
                                        title: 'New Followers',
                                        subtitle: 'When someone follows your profile',
                                        value: _notifPrefs.followers,
                                        onChanged: (val) => _onUpdateGranularPreference('followers', val),
                                      ),
                                      _buildGranularPreferenceTile(
                                        title: 'Creator Updates',
                                        subtitle: 'When chefs you follow post new recipes',
                                        value: _notifPrefs.followingNewRecipes,
                                        onChanged: (val) => _onUpdateGranularPreference('followingNewRecipes', val),
                                      ),
                                      _buildGranularPreferenceTile(
                                        title: 'Meal Reminders',
                                        subtitle: 'Reminders for your scheduled meal plans',
                                        value: _notifPrefs.mealReminders,
                                        onChanged: (val) => _onUpdateGranularPreference('mealReminders', val),
                                      ),
                                      _buildGranularPreferenceTile(
                                        title: 'Daily Meal Recommendations',
                                        subtitle: 'Ano Pong Ulam? daily cooking alerts',
                                        value: _notifPrefs.dailySuggestions,
                                        onChanged: (val) => _onUpdateGranularPreference('dailySuggestions', val),
                                      ),
                                    ],
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

  // --- REUSABLE NAVIGATION TILE ---
  Widget _buildNavigationTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(isFirst ? 20 : 0),
        topRight: Radius.circular(isFirst ? 20 : 0),
        bottomLeft: Radius.circular(isLast ? 20 : 0),
        bottomRight: Radius.circular(isLast ? 20 : 0),
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
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ],
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
            label: 'Current Password',
            hint: 'Enter current password...',
            controller: _currentPasswordController,
            obscureText: _obscureCurrentPassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureCurrentPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                color: AppColors.textSecondary,
                size: 20,
              ),
              onPressed: () => setState(() => _obscureCurrentPassword = !_obscureCurrentPassword),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Current password is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: AppColors.primary, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'A verification link will be sent to your current email for security.',
                    style: AppTypography.caption(
                      color: AppColors.textPrimary,
                    ).copyWith(fontSize: 11, height: 1.4),
                  ),
                ),
              ],
            ),
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
                label: 'Update Password',
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
            label: 'Current Password',
            hint: 'Enter current password...',
            controller: _currentEmailPasswordController,
            obscureText: _obscureEmailPassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureEmailPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                color: AppColors.textSecondary,
                size: 20,
              ),
              onPressed: () => setState(() => _obscureEmailPassword = !_obscureEmailPassword),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Current password is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: AppColors.primary, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'A verification link will be sent to your new email. Your current email will remain active until the new one is verified.',
                    style: AppTypography.caption(
                      color: AppColors.textPrimary,
                    ).copyWith(fontSize: 11, height: 1.4),
                  ),
                ),
              ],
            ),
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
                label: 'Update Email',
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
