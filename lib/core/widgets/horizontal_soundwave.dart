import 'dart:math';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Horizontal audio soundwave bars representing voice recognition and playback.
/// Supports blue, green, and purple gradients matching the reference screens.
class HorizontalSoundwave extends StatefulWidget {
  final Color? color;
  final LinearGradient? gradient;
  final int barCount;
  final double height;
  final bool isAnimated;

  const HorizontalSoundwave({
    super.key,
    this.color,
    this.gradient,
    this.barCount = 28,
    this.height = 28.0,
    this.isAnimated = true,
  });

  @override
  State<HorizontalSoundwave> createState() => _HorizontalSoundwaveState();
}

class _HorizontalSoundwaveState extends State<HorizontalSoundwave>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  // Fixed aesthetic pattern heights for clean reproduction of reference bars
  static const List<double> _waveformPattern = [
    0.20, 0.35, 0.50, 0.70, 0.40, 0.85, 0.60, 1.00,
    0.75, 0.90, 0.55, 0.40, 0.65, 0.80, 0.95, 0.70,
    0.50, 0.85, 0.60, 0.45, 0.75, 0.90, 0.55, 0.35,
    0.50, 0.40, 0.25, 0.15,
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.isAnimated) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          height: widget.height,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(widget.barCount, (index) {
              final double baseH = _waveformPattern[index % _waveformPattern.length];
              final double variance = widget.isAnimated
                  ? (sin((_controller.value * 2 * pi) + (index * 0.4)) * 0.2)
                  : 0.0;
              final double finalHeight = (baseH + variance).clamp(0.15, 1.0) * widget.height;

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2.0),
                width: 3.2,
                height: finalHeight,
                decoration: BoxDecoration(
                  color: widget.gradient == null
                      ? (widget.color ?? AppColors.primary)
                      : null,
                  gradient: widget.gradient,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
