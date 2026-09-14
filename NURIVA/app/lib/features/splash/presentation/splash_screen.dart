import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nuriva/core/design/design.dart';
import 'package:nuriva/core/routing/app_routes.dart';

/// NURIVA's first frame.
///
/// The splash exists to resolve where the user belongs — signed out, needing
/// onboarding, or home — before showing a screen they might be bounced off.
/// Module 02 replaces the timer with real auth-state resolution; the branded
/// presentation and the redirect seam do not change.
final class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: NurivaTokens.durationSlow,
  )..forward();

  /// Held so it can be cancelled in [dispose].
  ///
  /// An uncancelled `Future.delayed` keeps running after the widget is gone and
  /// then calls `context.go` on a dead element. It also leaks into widget tests
  /// as a pending timer, which is how this was caught.
  Timer? _handoffTimer;

  static const _minimumDwell = Duration(milliseconds: 1400);

  @override
  void initState() {
    super.initState();
    _scheduleHandoff();
  }

  /// Decides where to go next.
  ///
  /// Module 01 has no auth, so this is a deliberate minimum dwell that lets the
  /// brand register rather than flashing past. Module 02 replaces it with real
  /// auth-state resolution and keeps the dwell as a floor, so a fast auth
  /// result does not produce a jarring flicker.
  void _scheduleHandoff() {
    _handoffTimer = Timer(_minimumDwell, () {
      if (!mounted) return;
      context.go(AppRoutes.home);
    });
  }

  @override
  void dispose() {
    _handoffTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;

    final fade = CurvedAnimation(
      parent: _controller,
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
                  child: const NurivaWordmark(
                    markSize: 96,
                    showTagline: true,
                  ),
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
