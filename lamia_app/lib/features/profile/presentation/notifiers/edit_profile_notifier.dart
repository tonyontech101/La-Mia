import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/providers/auth_service_provider.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../auth/data/user_model.dart';
import '../achievements_screen.dart';

part 'edit_profile_notifier.g.dart';

// ---------------------------------------------------------------------------
// Result type
// ---------------------------------------------------------------------------

/// Describes the outcome of a save-profile operation so the widget can show
/// the appropriate snackbar.
enum SaveProfileStatus {
  /// Profile saved successfully (photo included).
  success,

  /// Profile saved but the photo upload failed.
  photoUploadFailed,

  /// The Firestore write failed. Nothing was saved.
  error,
}

// ---------------------------------------------------------------------------
// Immutable state
// ---------------------------------------------------------------------------

class EditProfileState {
  const EditProfileState({
    this.userModel,
    this.userAchievements = const [],
    this.selectedAchievementId,
    this.initialAchievementId,
    this.currentPhotoUrl,
    this.isLoading = true,
    this.isSaving = false,
    this.loadError = false,
  });

  final UserModel? userModel;
  final List<AchievementItem> userAchievements;
  final String? selectedAchievementId;
  final String? initialAchievementId;
  final String? currentPhotoUrl;
  final bool isLoading;
  final bool isSaving;
  final bool loadError;

  factory EditProfileState.initial() => const EditProfileState();

  EditProfileState copyWith({
    UserModel? userModel,
    bool clearUserModel = false,
    List<AchievementItem>? userAchievements,
    String? selectedAchievementId,
    bool clearSelectedAchievement = false,
    String? initialAchievementId,
    bool clearInitialAchievement = false,
    String? currentPhotoUrl,
    bool clearCurrentPhotoUrl = false,
    bool? isLoading,
    bool? isSaving,
    bool? loadError,
  }) {
    return EditProfileState(
      userModel:
          clearUserModel ? null : (userModel ?? this.userModel),
      userAchievements:
          userAchievements ?? this.userAchievements,
      selectedAchievementId: clearSelectedAchievement
          ? null
          : (selectedAchievementId ?? this.selectedAchievementId),
      initialAchievementId: clearInitialAchievement
          ? null
          : (initialAchievementId ?? this.initialAchievementId),
      currentPhotoUrl: clearCurrentPhotoUrl
          ? null
          : (currentPhotoUrl ?? this.currentPhotoUrl),
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      loadError: loadError ?? this.loadError,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

@riverpod
class EditProfileNotifier extends _$EditProfileNotifier {
  @override
  EditProfileState build() {
    return EditProfileState.initial();
  }

  // ── Loading ──────────────────────────────────────────────────────────────

  /// Loads the current user's profile and computes their achievement badges.
  Future<void> loadProfile() async {
    state = state.copyWith(isLoading: true, loadError: false);

    final authService = ref.read(authServiceProvider);
    final firebaseUser = authService.currentUser;
    if (firebaseUser == null) {
      state = state.copyWith(isLoading: false);
      return;
    }

    try {
      final userRepo = ref.read(userRepositoryProvider);
      final model = await userRepo.getUser(firebaseUser.uid);
      final achievements =
          AchievementCatalog.forUser(model, isChefOfMonth: false);

      state = state.copyWith(
        userModel: model,
        userAchievements: achievements,
        selectedAchievementId: model?.featuredAchievementId,
        initialAchievementId: model?.featuredAchievementId,
        currentPhotoUrl: model?.photoUrl ?? firebaseUser.photoURL,
        isLoading: false,
        loadError: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false, loadError: true);
    }
  }

  // ── Badge selection ──────────────────────────────────────────────────────

  /// Selects (or deselects) a showcase badge.
  void selectAchievement(String? id) {
    if (id == state.selectedAchievementId) return;
    state = state.copyWith(
      selectedAchievementId: id,
      clearSelectedAchievement: id == null,
    );
  }

  // ── Saving ───────────────────────────────────────────────────────────────

  /// Persists all profile changes: photo upload → Firestore → Firebase Auth.
  ///
  /// Returns a [SaveProfileStatus] so the widget can display the correct
  /// snackbar without the notifier needing a [BuildContext].
  Future<SaveProfileStatus> saveProfile({
    required String name,
    required String bio,
    required String uid,
    File? selectedImage,
    bool removePhoto = false,
  }) async {
    state = state.copyWith(isSaving: true);

    String? photoUrl = state.currentPhotoUrl;
    bool photoChanged = false;
    bool photoUploadFailed = false;

    // Step 1: Upload photo to Firebase Storage (non-fatal on failure)
    if (selectedImage != null) {
      try {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('users')
            .child(uid)
            .child(
                'profile_${DateTime.now().millisecondsSinceEpoch}.jpg');

        final uploadTask = storageRef.putFile(
          selectedImage,
          SettableMetadata(contentType: 'image/jpeg'),
        );

        await uploadTask;
        photoUrl = await storageRef.getDownloadURL();
        photoChanged = true;
      } catch (_) {
        photoUploadFailed = true;
      }
    } else if (removePhoto) {
      photoUrl = '';
      photoChanged = true;
    }

    // Step 2: Update Firestore (bio + name + photo + badge) — fatal on failure
    try {
      final userRepo = ref.read(userRepositoryProvider);
      await userRepo.updateProfile(
        uid,
        displayName: name,
        bio: bio,
        photoUrl: photoChanged ? photoUrl : null,
        featuredAchievementId: state.selectedAchievementId,
        clearFeaturedAchievement: state.selectedAchievementId == null,
      );
    } catch (_) {
      state = state.copyWith(isSaving: false);
      return SaveProfileStatus.error;
    }

    // Step 3: Sync Firebase Auth profile (non-critical)
    try {
      final authService = ref.read(authServiceProvider);
      final user = authService.currentUser;
      if (user != null) {
        await user.updateDisplayName(name);
        if (photoChanged) {
          await user.updatePhotoURL(
            photoUrl?.isEmpty ?? true ? null : photoUrl,
          );
        }
        await user.reload();
      }
    } catch (_) {
      // Ignore — Firestore is the source of truth.
    }

    state = state.copyWith(isSaving: false);
    return photoUploadFailed
        ? SaveProfileStatus.photoUploadFailed
        : SaveProfileStatus.success;
  }
}
