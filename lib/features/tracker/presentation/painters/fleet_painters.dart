import 'dart:math' as math;

import 'package:flutter/material.dart';

class RouteMapPainter extends CustomPainter {
  RouteMapPainter({required this.colorScheme, required this.progress});

  final ColorScheme colorScheme;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = colorScheme.surfaceContainerHighest;
    canvas.drawRect(Offset.zero & size, bg);

    final road = Paint()
      ..color = colorScheme.outlineVariant.withValues(alpha: .8)
      ..strokeWidth = 18
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final route = Paint()
      ..color = colorScheme.primary
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final thin = Paint()
      ..color = colorScheme.surface.withValues(alpha: .85)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(size.width * .12, size.height * .78)
      ..cubicTo(
        size.width * .28,
        size.height * .56,
        size.width * .35,
        size.height * .24,
        size.width * .56,
        size.height * .34,
      )
      ..cubicTo(
        size.width * .72,
        size.height * .42,
        size.width * .62,
        size.height * .74,
        size.width * .88,
        size.height * .58,
      );

    for (var i = 0; i < 7; i++) {
      final y = size.height * (.15 + i * .12);
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 28), thin);
    }
    for (var i = 0; i < 5; i++) {
      final x = size.width * (.12 + i * .19);
      canvas.drawLine(Offset(x, 0), Offset(x - 42, size.height), thin);
    }

    canvas.drawPath(path, road);
    canvas.drawPath(path, route);

    final metric = path.computeMetrics().first;
    final distance = metric.length * progress;
    final tangent =
        metric.getTangentForOffset(distance) ??
        metric.getTangentForOffset(metric.length * .68)!;
    final bus = tangent.position;

    final pulse = 18 + math.sin(progress * math.pi * 2) * 6;
    canvas.drawCircle(
      bus,
      pulse,
      Paint()..color = colorScheme.primary.withValues(alpha: .18),
    );
    canvas.drawCircle(bus, 13, Paint()..color = colorScheme.primary);
    _drawBus(canvas, bus, colorScheme.onPrimary);

    for (final stop in [.08, .33, .58, .82]) {
      final stopPoint = metric
          .getTangentForOffset(metric.length * stop)!
          .position;
      canvas.drawCircle(stopPoint, 8, Paint()..color = colorScheme.surface);
      canvas.drawCircle(stopPoint, 5, Paint()..color = colorScheme.tertiary);
    }
  }

  void _drawBus(Canvas canvas, Offset center, Color color) {
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: 18, height: 12),
      const Radius.circular(3),
    );
    canvas.drawRRect(body, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant RouteMapPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.colorScheme != colorScheme;
  }
}

class FleetPainter extends CustomPainter {
  FleetPainter({required this.colorScheme, required this.progress});

  final ColorScheme colorScheme;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final panel = Paint()..color = colorScheme.surface.withValues(alpha: .45);
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(8),
    );
    canvas.drawRRect(rect, panel);

    final routePaint = Paint()
      ..color = colorScheme.onPrimaryContainer.withValues(alpha: .22)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final route = Path()
      ..moveTo(size.width * .1, size.height * .72)
      ..quadraticBezierTo(
        size.width * .32,
        size.height * .14,
        size.width * .58,
        size.height * .42,
      )
      ..quadraticBezierTo(
        size.width * .8,
        size.height * .66,
        size.width * .9,
        size.height * .24,
      );
    canvas.drawPath(route, routePaint);

    final metric = route.computeMetrics().first;
    final point = metric
        .getTangentForOffset(metric.length * progress)!
        .position;
    canvas.drawCircle(
      point,
      22,
      Paint()..color = colorScheme.primary.withValues(alpha: .16),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: point, width: 44, height: 28),
        const Radius.circular(7),
      ),
      Paint()..color = colorScheme.primary,
    );
    canvas.drawCircle(
      point + const Offset(-12, 14),
      4,
      Paint()..color = colorScheme.onPrimary,
    );
    canvas.drawCircle(
      point + const Offset(12, 14),
      4,
      Paint()..color = colorScheme.onPrimary,
    );

    final school = Rect.fromLTWH(
      size.width * .66,
      size.height * .12,
      size.width * .18,
      size.height * .22,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(school, const Radius.circular(8)),
      Paint()..color = colorScheme.tertiaryContainer,
    );
  }

  @override
  bool shouldRepaint(covariant FleetPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.colorScheme != colorScheme;
  }
}
