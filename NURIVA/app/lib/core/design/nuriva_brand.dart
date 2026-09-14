import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nuriva/core/design/nuriva_tokens.dart';

/// The NURIVA mark: a rounded shield enclosing a pulse line.
///
/// Drawn rather than shipped as an asset so it stays sharp at any size, adapts
/// to the active theme, and adds no binary to the repository. The shield reads
/// as protection and the pulse as care — the two things the product claims.
final class NurivaMark extends StatelessWidget {
  const NurivaMark({this.size = 72, this.color, super.key});

  final double size;

  /// Defaults to the brand colour.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _MarkPainter(color ?? NurivaTokens.brand),
        isComplex: false,
      ),
    );
  }
}

final class _MarkPainter extends CustomPainter {
  const _MarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Shield: a rounded rectangle whose lower edge tapers to a point.
    final shield = Path()
      ..moveTo(w * .5, h * .04)
      ..lineTo(w * .88, h * .2)
      ..lineTo(w * .88, h * .52)
      ..quadraticBezierTo(w * .88, h * .84, w * .5, h * .97)
      ..quadraticBezierTo(w * .12, h * .84, w * .12, h * .52)
      ..lineTo(w * .12, h * .2)
      ..close();

    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color, Color.lerp(color, Colors.black, .22)!],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(shield, fill);

    // Pulse line across the middle third.
    final pulse = Path()
      ..moveTo(w * .24, h * .5)
      ..lineTo(w * .38, h * .5)
      ..lineTo(w * .45, h * .36)
      ..lineTo(w * .55, h * .64)
      ..lineTo(w * .62, h * .5)
      ..lineTo(w * .76, h * .5);

    canvas.drawPath(
      pulse,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2, w * .065)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => oldDelegate.color != color;
}

/// The NURIVA wordmark, optionally with the shield above it.
final class NurivaWordmark extends StatelessWidget {
  const NurivaWordmark({
    this.showMark = true,
    this.markSize = 72,
    this.fontSize = NurivaTokens.fontDisplay,
    this.showTagline = false,
    super.key,
  });

  final bool showMark;
  final double markSize;
  final double fontSize;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    final onSurface = context.colors.onSurface;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showMark) ...[
          NurivaMark(size: markSize),
          const SizedBox(height: NurivaTokens.space5),
        ],
        Text(
          'NURIVA',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            // Wide tracking reads as considered rather than shouted, which is
            // the difference between a healthcare brand and a warning label.
            letterSpacing: fontSize * .18,
            color: onSurface,
            height: 1,
          ),
        ),
        if (showTagline) ...[
          const SizedBox(height: NurivaTokens.space3),
          Text(
            'Medication care, together',
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
              letterSpacing: .2,
            ),
          ),
        ],
      ],
    );
  }
}
