import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Сегмент кільцевої діаграми.
class DonutSegment {
  final String label;
  final double value;
  final Color color;
  const DonutSegment(this.label, this.value, this.color);
}

/// Кільцева діаграма з легендою (як "Типи інтерфейсів" у WinboxMobile).
class DonutChart extends StatelessWidget {
  final List<DonutSegment> segments;
  final double size;

  const DonutChart({super.key, required this.segments, this.size = 140});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: size,
          height: size,
          child: CustomPaint(painter: _DonutPainter(segments)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final s in segments)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Container(width: 12, height: 12, color: s.color),
                      const SizedBox(width: 8),
                      Expanded(child: Text(s.label)),
                      Text(s.value.toStringAsFixed(0),
                          style:
                              const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<DonutSegment> segments;
  _DonutPainter(this.segments);

  @override
  void paint(Canvas canvas, Size size) {
    final total =
        segments.fold<double>(0, (sum, s) => sum + s.value);
    if (total <= 0) return;
    final strokeWidth = size.width * 0.22;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(strokeWidth / 2);
    var start = -math.pi / 2;
    for (final s in segments) {
      final sweep = s.value / total * 2 * math.pi;
      final paint = Paint()
        ..color = s.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      // невеликий зазор між сегментами
      canvas.drawArc(arcRect, start + 0.02, math.max(sweep - 0.04, 0.01),
          false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.segments != segments;
}
