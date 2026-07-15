import 'package:flutter/material.dart';

/// Одна серія даних для графіка.
class ChartSeries {
  final String label;
  final Color color;
  final List<double> values;
  const ChartSeries(this.label, this.color, this.values);
}

/// Простий лінійний графік на CustomPainter (без сторонніх бібліотек):
/// сітка, підписи осі Y, кілька серій, легенда з поточним значенням.
class SimpleLineChart extends StatelessWidget {
  final List<ChartSeries> series;
  final double? maxY; // null — автоматично за даними
  final double height;
  final String Function(double) formatY;

  static String _defaultFormatY(double v) => v.toStringAsFixed(0);

  const SimpleLineChart({
    super.key,
    required this.series,
    this.maxY,
    this.height = 140,
    this.formatY = _defaultFormatY,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _LineChartPainter(
              series: series,
              fixedMaxY: maxY,
              formatY: formatY,
              gridColor: scheme.outlineVariant,
              textColor: scheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 16,
          children: [
            for (final s in series)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 10, height: 10, color: s.color),
                  const SizedBox(width: 4),
                  Text(
                    s.values.isEmpty
                        ? s.label
                        : '${s.label}: ${formatY(s.values.last)}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<ChartSeries> series;
  final double? fixedMaxY;
  final String Function(double) formatY;
  final Color gridColor;
  final Color textColor;

  _LineChartPainter({
    required this.series,
    required this.fixedMaxY,
    required this.formatY,
    required this.gridColor,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 46.0;
    const topPad = 4.0;
    const bottomPad = 4.0;

    var maxY = fixedMaxY ?? 0;
    if (fixedMaxY == null) {
      for (final s in series) {
        for (final v in s.values) {
          if (v > maxY) maxY = v;
        }
      }
      maxY *= 1.15;
    }
    if (maxY <= 0) maxY = 1;

    final chartWidth = size.width - leftPad;
    final chartHeight = size.height - topPad - bottomPad;
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;

    for (var i = 0; i <= 4; i++) {
      final y = topPad + chartHeight * i / 4;
      canvas.drawLine(Offset(leftPad, y), Offset(size.width, y), gridPaint);
      final value = maxY * (4 - i) / 4;
      final tp = TextPainter(
        text: TextSpan(
          text: formatY(value),
          style: TextStyle(fontSize: 9, color: textColor),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: leftPad - 4);
      tp.paint(canvas, Offset(leftPad - tp.width - 4, y - tp.height / 2));
    }

    var maxN = 2;
    for (final s in series) {
      if (s.values.length > maxN) maxN = s.values.length;
    }

    for (final s in series) {
      if (s.values.isEmpty) continue;
      final paint = Paint()
        ..color = s.color
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true;
      final path = Path();
      final offset = maxN - s.values.length;
      for (var i = 0; i < s.values.length; i++) {
        final x = leftPad + chartWidth * (offset + i) / (maxN - 1);
        final y = topPad +
            chartHeight * (1 - (s.values[i] / maxY).clamp(0.0, 1.0));
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) => true;
}
