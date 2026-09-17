import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nuriva/core/design/design.dart';
import 'package:nuriva/core/routing/app_routes.dart';
import 'package:nuriva/features/auth/application/auth_providers.dart';
import 'package:nuriva/features/auth/domain/auth_models.dart';

/// NURIVA's first frame.
///
/// Waits for two things — the session to resolve and a minimum brand dwell —
/// then navigates to home and lets the session guard redirect to wherever the
/// user actually belongs (welcome, verification, profile, or home). The dwell
/// keeps a fast session resolution from producing a jarring flicker.
final class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  static const minimumDwell = Duration(milliseconds: 1400);

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: NurivaTokens.durationSlow,
  )..forward();

  /// Held so it can be cancelled in [dispose]; an uncancelled timer would
  /// navigate from a dead element.
  Timer? _dwellTimer;
  bool _dwellDone = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _dwellTimer = Timer(SplashScreen.minimumDwell, () {
      if (mounted) setState(() => _dwellDone = true);
    });
  }

  @override
  void dispose() {
    _dwellTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);

    if (session is SessionUnavailable) {
      return Scaffold(
        body: NurivaStateView(
          title: "We couldn't load your account",
          message: 'Check your internet connection and try again.',
          icon: Icons.cloud_off_outlined,
          status: NurivaStatus.danger,
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(profileProvider(session.user.uid)),
          secondaryActionLabel: 'Sign out',
          onSecondaryAction: () => ref.read(accountServiceProvider).signOut(),
        ),
      );
    }

    if (_dwellDone && session is! SessionLoading && !_navigated) {
      _navigated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go(AppRoutes.home);
      });
    }

    return _BrandedSplash(animation: _controller);
  }
}

final class _BrandedSplash extends StatelessWidget {
  const _BrandedSplash({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final fade = CurvedAnimation(
      parent: animation,
      curve: NurivaTokens.curveStandard,
    );

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              scheme.surface,
              Color.lerp(
                scheme.surface,
                NurivaTokens.brand,
                context.isDark ? .16 : .07,
              )!,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 3),
              FadeTransition(
                opacity: fade,
                child: ScaleTransition(
                  scale: Tween<double>(begin: .88, end: 1).animate(fade),
                  child: const NurivaWordmark(markSize: 96, showTagline: true),
                ),
              ),
              const Spacer(flex: 4),
              FadeTransition(
                opacity: fade,
                child: SizedBox(
                  width: 120,
                  child: LinearProgressIndicator(
                    borderRadius: NurivaTokens.brPill,
                    backgroundColor: scheme.outlineVariant.withValues(alpha: .5),
                  ),
                ),
              ),
              const SizedBox(height: NurivaTokens.space12),
            ],
          ),
        ),
      ),
    );
  }
}
