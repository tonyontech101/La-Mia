import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/providers/firebase_providers.dart';
import '../../../core/widgets/pressable_scale.dart';

/// Result returned when the user exits the verification screen.
enum VerificationExitAction {
  /// AI approved — pop back to feed.
  approved,

  /// User chose "Edit My Recipe" after rejection — pop back to editor.
  editRecipe,

  /// User chose "Start Fresh" after rejection — pop back and reset form.
  startFresh,

  /// Timed-out / user tapped "Back to Feed".
  backToFeed,
}

/// Full-screen, TikTok-inspired AI verification flow.
///
/// Navigated-to after the recipe document has been written to Firestore with
/// `status: 'pending'`. Listens for real-time status changes from the AI
/// moderator Cloud Function and displays three phases:
///   1. Processing — animated icon + cycling messages
///   2a. Approved — celebration + "Luto Na!" 🎉
///   2b. Rejected — empathetic explanation + tips + edit/retry
///   2c. Timed-out — "still processing" fallback
class AiVerificationScreen extends ConsumerStatefulWidget {
  const AiVerificationScreen({
    super.key,
    required this.recipeDocId,
    required this.recipeName,
  });

  final String recipeDocId;
  final String recipeName;

  @override
  ConsumerState<AiVerificationScreen> createState() => _AiVerificationScreenState();
}

class _AiVerificationScreenState extends ConsumerState<AiVerificationScreen>
    with TickerProviderStateMixin {
  // ── Phase state ──────────────────────────────────────────────────────────────
  // 'processing' | 'approved' | 'rejected' | 'timeout'
  String _phase = 'processing';
  String _rejectionReason = '';
  bool _isExiting = false;

  void _exit(VerificationExitAction action) {
    if (_isExiting || !mounted) return;
    _isExiting = true;
    Navigator.pop(context, action);
  }

  // ── Animations ───────────────────────────────────────────────────────────────
  late final AnimationController _pulseController;
  late final AnimationController _rotateController;
  late final AnimationController _resultController; // drives the result reveal
  late final AnimationController _confettiController;

  late final Animation<double> _pulseAnim;
  late final Animation<double> _rotateAnim;
  late final Animation<double> _resultScale;
  late final Animation<double> _resultFade;

  // ── Cycling status messages ──────────────────────────────────────────────────
  final _statusMessages = const [
    'Uploading your masterpiece...',
    '🍳 Checking ingredients with AI...',
    '📋 Reviewing cooking steps...',
    '🔍 Validating recipe details...',
    '✨ Almost there...',
  ];
  int _currentMessageIndex = 0;
  Timer? _messageTimer;

  // ── Firestore listener ───────────────────────────────────────────────────────
  StreamSubscription<DocumentSnapshot>? _firestoreSub;
  Timer? _timeoutTimer;

  // ── Confetti particles ───────────────────────────────────────────────────────
  final List<_ConfettiParticle> _particles = [];
  final _random = Random();

  @override
  void initState() {
    super.initState();

    // Pulse animation (icon breathing effect)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Slow rotation for the decorative ring
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _rotateAnim = Tween<double>(begin: 0, end: 2 * pi).animate(_rotateController);

    // Result reveal animation
    _resultController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _resultScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _resultController, curve: Curves.elasticOut),
    );
    _resultFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _resultController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    // Confetti animation
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..addListener(() => setState(() {}));

    // Cycle through status messages
    _messageTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_phase == 'processing' && mounted) {
        setState(() {
          _currentMessageIndex =
              (_currentMessageIndex + 1) % _statusMessages.length;
        });
      }
    });

    // Start listening to Firestore
    _startListening();

    // Immediate fast heuristic check for obvious non-food items (e.g. "isa ka laptop")
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFastHeuristics();
    });
  }

  static final _nonFoodKeywords = [
    'laptop', 'computer', 'pc', 'cellphone', 'phone', 'iphone', 'android',
    'samsung', 'gadget', 'tablet', 'ipad', 'keyboard', 'mouse', 'monitor',
    'screen', 'charger', 'battery', 'cable', 'wire', 'television', 'tv',
    'relo', 'watch', 'clock', 'sasakyan', 'kotse', 'car', 'motorcycle',
    'motor', 'bike', 'bicycle', 'tires', 'gulong', 'shoes', 'sapatos',
    'tsinelas', 'damit', 'clothes', 'shirt', 'pants', 'plastic', 'metal',
    'bakal', 'bato', 'stone', 'kahoy', 'wood', 'papel', 'paper', 'pera',
    'money', 'cash', 'shampoo', 'detergent', 'bleach',
  ];

  Future<void> _checkFastHeuristics() async {
    try {
      final snap = await ref
          .read(firebaseFirestoreProvider)
          .collection('recipes')
          .doc(widget.recipeDocId)
          .get();
      if (!mounted) return;
      if (!snap.exists) {
        _onRejected('This submission was rejected by content moderation.');
        return;
      }
      final data = snap.data();
      if (data == null) return;

      final name = (data['name'] as String? ?? widget.recipeName).toLowerCase();
      final description = (data['description'] as String? ?? '').toLowerCase();
      final ingredients = (data['ingredients'] as List<dynamic>? ?? [])
          .map((e) => e.toString().toLowerCase())
          .toList();

      for (final keyword in _nonFoodKeywords) {
        final regex =
            RegExp(r'\b' + RegExp.escape(keyword) + r'\b', caseSensitive: false);
        if (regex.hasMatch(name) ||
            regex.hasMatch(description) ||
            ingredients.any((i) => regex.hasMatch(i))) {
          final reason =
              'The recipe title or content refers to non-food items ("$keyword"). Please submit genuine Filipino food dishes.';
          _onRejected(reason);
          return;
        }
      }
    } catch (_) {}
  }

  void _startListening() {
    final docRef = ref.read(firebaseFirestoreProvider)
        .collection('recipes')
        .doc(widget.recipeDocId);

    _firestoreSub = docRef.snapshots().listen((snap) {
      if (!mounted) return;
      if (!snap.exists) {
        // If document was removed from Firestore, it did not pass moderation
        if (_phase == 'processing' || _phase == 'timeout') {
          _onRejected('This submission did not pass recipe content moderation.');
        }
        return;
      }

      final status = snap.data()?['status'] as String?;
      if (status == 'approved') {
        _onApproved();
      } else if (status == 'rejected') {
        final reason = snap.data()?['rejectionReason'] as String? ??
            'This submission does not appear to be a genuine food recipe or contains non-food items.';
        _onRejected(reason);
      }
    });

    // Timeout after 45 seconds (allows serverless AI moderation cold-starts to complete)
    _timeoutTimer = Timer(const Duration(seconds: 45), () {
      if (_phase == 'processing' && mounted) {
        _onTimeout();
      }
    });
  }

  void _onApproved() {
    if (_phase == 'approved' || _phase == 'rejected') return;
    _firestoreSub?.cancel();
    _timeoutTimer?.cancel();
    _messageTimer?.cancel();

    setState(() => _phase = 'approved');
    _pulseController.stop();
    _rotateController.stop();
    _resultController.forward(from: 0.0);

    // Generate confetti
    _generateConfetti();
    _confettiController.forward();

    // Auto-navigate after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _phase == 'approved') {
        _exit(VerificationExitAction.approved);
      }
    });
  }

  void _onRejected(String reason) {
    if (_phase == 'rejected' || _phase == 'approved') return;
    _firestoreSub?.cancel();
    _timeoutTimer?.cancel();
    _messageTimer?.cancel();

    // Delete the rejected document from Firestore so it is NEVER posted
    ref.read(firebaseFirestoreProvider)
        .collection('recipes')
        .doc(widget.recipeDocId)
        .delete()
        .catchError((_) {});

    setState(() {
      _phase = 'rejected';
      _rejectionReason = reason;
    });
    _pulseController.stop();
    _rotateController.stop();
    _resultController.forward(from: 0.0);
  }

  Future<void> _onTimeout() async {
    if (_phase != 'processing') return;
    _messageTimer?.cancel();

    // Double-check Firestore state before switching to timeout
    try {
      final snap = await ref
          .read(firebaseFirestoreProvider)
          .collection('recipes')
          .doc(widget.recipeDocId)
          .get();
      if (!mounted) return;
      if (!snap.exists) {
        _onRejected('This submission did not pass content moderation.');
        return;
      }
      final status = snap.data()?['status'] as String?;
      if (status == 'approved') {
        _onApproved();
        return;
      } else if (status == 'rejected') {
        final reason = snap.data()?['rejectionReason'] as String? ??
            'This submission does not appear to be a genuine food recipe or contains non-food items.';
        _onRejected(reason);
        return;
      }
    } catch (_) {}

    // Note: Do NOT cancel _firestoreSub so late updates can still trigger _onApproved/_onRejected!
    if (mounted && _phase == 'processing') {
      setState(() => _phase = 'timeout');
      _pulseController.stop();
      _rotateController.stop();
      _resultController.forward(from: 0.0);
    }
  }

  void _generateConfetti() {
    _particles.clear();
    final colors = [
      AppColors.primary,
      AppColors.accent,
      AppColors.success,
      AppColors.secondary,
      const Color(0xFFF06292), // pink
      const Color(0xFFFFD54F), // gold
    ];
    for (int i = 0; i < 50; i++) {
      _particles.add(_ConfettiParticle(
        x: _random.nextDouble(),
        y: -_random.nextDouble() * 0.3,
        vx: (_random.nextDouble() - 0.5) * 0.015,
        vy: 0.005 + _random.nextDouble() * 0.015,
        rotation: _random.nextDouble() * 2 * pi,
        rotationSpeed: (_random.nextDouble() - 0.5) * 0.15,
        size: 6 + _random.nextDouble() * 8,
        color: colors[_random.nextInt(colors.length)],
        shape: _random.nextInt(3), // 0=square, 1=circle, 2=line
      ));
    }
  }

  @override
  void dispose() {
    _firestoreSub?.cancel();
    _timeoutTimer?.cancel();
    _messageTimer?.cancel();
    _pulseController.dispose();
    _rotateController.dispose();
    _resultController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _phase != 'processing',
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Stack(
            children: [
              // Confetti layer (only when approved)
              if (_phase == 'approved')
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ConfettiPainter(
                      particles: _particles,
                      progress: _confettiController.value,
                    ),
                  ),
                ),

              // Main content
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenH,
                    vertical: AppSpacing.xxl,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.08),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: KeyedSubtree(
                        key: ValueKey<String>(_phase),
                        child: _buildPhaseContent(),
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

  Widget _buildPhaseContent() {
    switch (_phase) {
      case 'approved':
        return _buildApprovedPhase();
      case 'rejected':
        return _buildRejectedPhase();
      case 'timeout':
        return _buildTimeoutPhase();
      default:
        return _buildProcessingPhase();
    }
  }

  // ── Phase 1: Processing ──────────────────────────────────────────────────────

  Widget _buildProcessingPhase() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 40),

        // Animated icon with decorative ring
        SizedBox(
          width: 160,
          height: 160,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Rotating dashed ring
              AnimatedBuilder(
                animation: _rotateAnim,
                builder: (context, child) => Transform.rotate(
                  angle: _rotateAnim.value,
                  child: CustomPaint(
                    size: const Size(150, 150),
                    painter: _DashedRingPainter(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
              ),

              // Inner glowing circle
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (context, child) => Transform.scale(
                  scale: _pulseAnim.value,
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.12),
                          AppColors.primary.withValues(alpha: 0.04),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surface,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              blurRadius: 24,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text(
                            '🍳',
                            style: TextStyle(fontSize: 36),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 36),

        // Title
        Text(
          'Verifying Your Recipe',
          style: AppTypography.headline(color: AppColors.textPrimary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),

        // Cycling status message with fade
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: Text(
            _statusMessages[_currentMessageIndex],
            key: ValueKey<int>(_currentMessageIndex),
            style: AppTypography.body(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),

        const SizedBox(height: 32),

        // Progress dots
        _buildProgressDots(),

        const SizedBox(height: 32),

        // Subtle info card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(AppRadii.field),
          ),
          child: Row(
            children: [
              Icon(
                Icons.shield_outlined,
                color: AppColors.primary.withValues(alpha: 0.7),
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Gemini AI is checking that your recipe contains real food ingredients and cooking steps.',
                  style: AppTypography.caption(color: AppColors.textSecondary)
                      .copyWith(height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        // Stagger the animation so dots pulse sequentially
        final delay = i * 0.3;
        return AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final value = _pulseController.value;
            // Create a wave effect
            final wave = sin((value * 2 * pi) - (delay * pi));
            final scale = 0.6 + (wave + 1) * 0.25;
            final opacity = 0.4 + (wave + 1) * 0.3;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(alpha: opacity),
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }

  // ── Phase 2a: Approved ───────────────────────────────────────────────────────

  Widget _buildApprovedPhase() {
    return AnimatedBuilder(
      animation: _resultController,
      builder: (context, child) => Opacity(
        opacity: _resultFade.value,
        child: Transform.scale(
          scale: 0.8 + (_resultScale.value * 0.2),
          child: child,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 40),

          // Big celebration icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.success.withValues(alpha: 0.1),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.3),
                width: 3,
              ),
            ),
            child: const Center(
              child: Text('🎉', style: TextStyle(fontSize: 52)),
            ),
          ),

          const SizedBox(height: 28),

          // "Luto Na!"
          Text(
            'Luto Na!',
            style: GoogleFonts.fraunces(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: AppColors.success,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          Text(
            'Your recipe has been approved\nand is now live!',
            style: AppTypography.body(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Recipe name pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.restaurant_menu_rounded,
                    size: 18, color: AppColors.accent),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    widget.recipeName,
                    style: AppTypography.bodyStrong(color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 36),

          // "View My Recipe" button
          _buildPrimaryActionButton(
            label: 'Back to Feed',
            icon: Icons.home_rounded,
            onTap: () => _exit(VerificationExitAction.approved),
          ),

          const SizedBox(height: 16),

          Text(
            'Auto-returning in a moment...',
            style: AppTypography.caption(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ── Phase 2b: Rejected ───────────────────────────────────────────────────────

  Widget _buildRejectedPhase() {
    return AnimatedBuilder(
      animation: _resultController,
      builder: (context, child) => Opacity(
        opacity: _resultFade.value,
        child: Transform.scale(
          scale: 0.8 + (_resultScale.value * 0.2),
          child: child,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 20),

          // Sad / warning icon
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.error.withValues(alpha: 0.08),
              border: Border.all(
                color: AppColors.error.withValues(alpha: 0.25),
                width: 3,
              ),
            ),
            child: const Center(
              child: Text('😔', style: TextStyle(fontSize: 48)),
            ),
          ),

          const SizedBox(height: 24),

          // Title
          Text(
            'Oops, Not Quite Right',
            style: GoogleFonts.fraunces(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Our AI recipe moderator reviewed your post and couldn\'t approve it this time.',
            style: AppTypography.body(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 20),

          // Rejection reason card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.error.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 18, color: AppColors.error.withValues(alpha: 0.8)),
                    const SizedBox(width: 8),
                    Text(
                      'Reason',
                      style: AppTypography.bodyStrong(
                        color: AppColors.error,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _rejectionReason,
                  style: AppTypography.body(
                    color: AppColors.textPrimary,
                  ).copyWith(height: 1.5),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Tips card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lightbulb_outline_rounded,
                        size: 18, color: AppColors.accent),
                    const SizedBox(width: 8),
                    Text(
                      'Tips to get approved',
                      style: AppTypography.bodyStrong(color: AppColors.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildTipRow('Use a real dish name as your title'),
                const SizedBox(height: 8),
                _buildTipRow('List actual food ingredients'),
                const SizedBox(height: 8),
                _buildTipRow('Describe real cooking/preparation steps'),
                const SizedBox(height: 8),
                _buildTipRow('Add a photo of the finished dish'),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Encouragement
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadii.field),
            ),
            child: Row(
              children: [
                const Text('👨‍🍳', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Don\'t worry — even the best chefs need a second try!',
                    style: AppTypography.label(color: AppColors.textPrimary)
                        .copyWith(fontWeight: FontWeight.w600, height: 1.4),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Edit My Recipe button (primary)
          _buildPrimaryActionButton(
            label: 'Edit My Recipe',
            icon: Icons.edit_rounded,
            onTap: () => _exit(VerificationExitAction.editRecipe),
          ),

          const SizedBox(height: 12),

          // Start Fresh button (outlined)
          _buildOutlinedActionButton(
            label: 'Start Fresh',
            icon: Icons.refresh_rounded,
            onTap: () => _exit(VerificationExitAction.startFresh),
          ),
        ],
      ),
    );
  }

  Widget _buildTipRow(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle_rounded,
            size: 16, color: AppColors.success),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: AppTypography.label(color: AppColors.textSecondary)
                .copyWith(height: 1.35),
          ),
        ),
      ],
    );
  }

  // ── Phase 2c: Timeout ────────────────────────────────────────────────────────

  Widget _buildTimeoutPhase() {
    return AnimatedBuilder(
      animation: _resultController,
      builder: (context, child) => Opacity(
        opacity: _resultFade.value,
        child: Transform.scale(
          scale: 0.8 + (_resultScale.value * 0.2),
          child: child,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 40),

          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent.withValues(alpha: 0.12),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.35),
                width: 3,
              ),
            ),
            child: const Center(
              child: Text('⏳', style: TextStyle(fontSize: 48)),
            ),
          ),

          const SizedBox(height: 28),

          Text(
            'Review in Progress',
            style: GoogleFonts.fraunces(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Our AI recipe moderator is still reviewing your recipe. Because review has not completed yet, it has not been posted.',
            style: AppTypography.body(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 16),

          // Recipe name pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.restaurant_menu_rounded,
                    size: 18, color: AppColors.accent),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    widget.recipeName,
                    style:
                        AppTypography.bodyStrong(color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          _buildPrimaryActionButton(
            label: 'Check Status Again',
            icon: Icons.refresh_rounded,
            onTap: _checkLatestStatus,
          ),

          const SizedBox(height: 12),

          _buildOutlinedActionButton(
            label: 'Cancel & Delete Recipe',
            icon: Icons.close_rounded,
            onTap: _cancelAndDelete,
          ),
        ],
      ),
    );
  }

  Future<void> _checkLatestStatus() async {
    try {
      final snap = await ref
          .read(firebaseFirestoreProvider)
          .collection('recipes')
          .doc(widget.recipeDocId)
          .get();
      if (!mounted) return;
      if (!snap.exists) {
        _onRejected('This submission was rejected by content moderation.');
        return;
      }
      final status = snap.data()?['status'] as String?;
      if (status == 'approved') {
        _onApproved();
      } else if (status == 'rejected') {
        final reason = snap.data()?['rejectionReason'] as String? ??
            'This submission does not appear to be a genuine food recipe or contains non-food items.';
        _onRejected(reason);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI is still reviewing. Please wait a moment...'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not check status: $e')),
        );
      }
    }
  }

  Future<void> _cancelAndDelete() async {
    _firestoreSub?.cancel();
    _timeoutTimer?.cancel();
    _messageTimer?.cancel();

    // Delete unapproved document from Firestore so it is not posted
    await ref
        .read(firebaseFirestoreProvider)
        .collection('recipes')
        .doc(widget.recipeDocId)
        .delete()
        .catchError((_) {});

    if (mounted) {
      _exit(VerificationExitAction.backToFeed);
    }
  }

  // ── Shared Buttons ───────────────────────────────────────────────────────────

  Widget _buildPrimaryActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: PressableScale(
        pressedScale: 0.975,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.button),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.28),
                offset: const Offset(0, 4),
                blurRadius: 12,
              ),
            ],
          ),
          child: FilledButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 20),
            label: Text(label, style: AppTypography.button()),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.button),
              ),
              elevation: 0,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOutlinedActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: PressableScale(
        pressedScale: 0.975,
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 20),
          label: Text(
            label,
            style: AppTypography.button(color: AppColors.primary),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.button),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Custom Painters ──────────────────────────────────────────────────────────

/// Dashed ring around the processing icon.
class _DashedRingPainter extends CustomPainter {
  const _DashedRingPainter({
    required this.color,
    required this.strokeWidth,
  });

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final radius = size.width / 2;
    const dashCount = 16;
    const gapAngle = 0.12;
    const sweepAngle = (2 * pi / dashCount) - gapAngle;

    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * (2 * pi / dashCount);
      canvas.drawArc(
        Rect.fromCircle(
          center: Offset(size.width / 2, size.height / 2),
          radius: radius,
        ),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRingPainter oldDelegate) =>
      color != oldDelegate.color || strokeWidth != oldDelegate.strokeWidth;
}

/// Simple confetti particle data.
class _ConfettiParticle {
  _ConfettiParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.rotation,
    required this.rotationSpeed,
    required this.size,
    required this.color,
    required this.shape,
  });

  double x, y, vx, vy, rotation, rotationSpeed, size;
  final Color color;
  final int shape; // 0=square, 1=circle, 2=line
}

/// Paints falling confetti particles.
class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.particles, required this.progress});

  final List<_ConfettiParticle> particles;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      // Simulate movement
      final currentX = (p.x + p.vx * progress * 60) * size.width;
      final currentY = (p.y + p.vy * progress * 60) * size.height;
      final currentRotation = p.rotation + p.rotationSpeed * progress * 60;
      final opacity = (1.0 - progress).clamp(0.0, 1.0);

      if (currentY > size.height || currentX < 0 || currentX > size.width) {
        continue;
      }

      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(currentX, currentY);
      canvas.rotate(currentRotation);

      switch (p.shape) {
        case 0: // square
          canvas.drawRect(
            Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size),
            paint,
          );
          break;
        case 1: // circle
          canvas.drawCircle(Offset.zero, p.size / 2, paint);
          break;
        case 2: // line
          paint.strokeWidth = 2.5;
          paint.style = PaintingStyle.stroke;
          canvas.drawLine(
            Offset(-p.size / 2, 0),
            Offset(p.size / 2, 0),
            paint,
          );
          break;
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}
