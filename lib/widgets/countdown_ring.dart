import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Section 3.5 — The Countdown Ring
///
/// A circular ring that fills with a warm gradient as time approaches.
/// Color transitions: Calm Mint → Ember Amber → Spark Cyan as urgency grows.
///
/// Used in three places:
///   • In-app (this widget).
///   • iOS Live Activity SwiftUI widget (ios/Runner/WhisprWidget/).
///   • Android ongoing notification (CountdownForegroundService).
/// The visual spec here is the canonical reference; native implementations
/// mirror it as closely as their frameworks allow.
class CountdownRing extends StatefulWidget {
  final DateTime fireAt;
  final String taskTitle;
  /// How many minutes before fireAt the ring starts (= liveActivityWindowMinutes).
  final int windowMinutes;
  final double size;

  const CountdownRing({
    super.key,
    required this.fireAt,
    required this.taskTitle,
    this.windowMinutes = 30,
    this.size = 120,
  });

  @override
  State<CountdownRing> createState() => _CountdownRingState();
}

class _CountdownRingState extends State<CountdownRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Returns a 0.0–1.0 progress value where 1.0 = full ring (countdown done).
  double _computeProgress() {
    final now = DateTime.now();
    final totalWindow = Duration(minutes: widget.windowMinutes);
    final remaining = widget.fireAt.difference(now);
    if (remaining.isNegative) return 1.0;
    if (remaining > totalWindow) return 0.0;
    return 1.0 - remaining.inSeconds / totalWindow.inSeconds;
  }

  /// Color gradient: Calm Mint (0%) → Ember Amber (60%) → Spark Cyan (100%)
  Color _ringColor(double progress) {
    if (progress < 0.6) {
      return Color.lerp(
        WhisprColors.calmMint,
        WhisprColors.emberAmber,
        progress / 0.6,
      )!;
    } else {
      return Color.lerp(
        WhisprColors.emberAmber,
        WhisprColors.sparkCyan,
        (progress - 0.6) / 0.4,
      )!;
    }
  }

  String _formatRemaining() {
    final remaining = widget.fireAt.difference(DateTime.now());
    if (remaining.isNegative) return '0s';
    final h = remaining.inHours;
    final m = remaining.inMinutes % 60;
    final s = remaining.inSeconds % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = _computeProgress();
        final color = _ringColor(progress);
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _RingPainter(progress: progress, color: color),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatRemaining(),
                    style: WhisprText.countdown(
                      size: widget.size * 0.16,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: widget.size * 0.65,
                    child: Text(
                      widget.taskTitle,
                      style: WhisprText.body(
                        size: widget.size * 0.1,
                        color: WhisprColors.plumInk,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 6;
    final strokeWidth = size.width * 0.08;

    // Background track.
    final trackPaint = Paint()
      ..color = WhisprColors.borderGray
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Filled arc.
    if (progress > 0) {
      final fillPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2, // Start at the top.
        2 * math.pi * progress,
        false,
        fillPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}
