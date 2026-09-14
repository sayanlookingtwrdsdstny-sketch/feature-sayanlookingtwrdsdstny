import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nuriva/core/design/design.dart';
import 'package:nuriva/core/routing/app_router.dart';

/// The root widget.
final class NurivaApp extends ConsumerWidget {
  const NurivaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'NURIVA',
      debugShowCheckedModeBanner: false,
      theme: NurivaTheme.light(),
      darkTheme: NurivaTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
      builder: (context, child) => _ClampedTextScale(child: child),
    );
  }
}

/// Clamps the OS text-scale factor to [NurivaTokens.maxTextScale].
///
/// Users in NURIVA's audience often set system text very large, and unbounded
/// scaling can push a primary action off screen. On a dose reminder that is a
/// safety problem, not a layout nitpick — so scaling is honoured up to a bound
/// rather than ignored or left unlimited.
final class _ClampedTextScale extends StatelessWidget {
  const _ClampedTextScale({required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final clamped = media.textScaler.clamp(
      minScaleFactor: 1,
      maxScaleFactor: NurivaTokens.maxTextScale,
    );

    return MediaQuery(
      data: media.copyWith(textScaler: clamped),
      child: child ?? const SizedBox.shrink(),
    );
  }
}
