import 'dart:math';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Reusable animated audio waveform visualizer for voice listening and playback.
class AudioWaveVisualizer extends StatefulWidget {
  final bool isRecording;
  final Color primaryColor;
  final int barCount;
  final double height;

  const AudioWaveVisualizer({
    super.key,
    required this.isRecording,
    this.primaryColor = AppColors.primary,
    this.barCount = 20,
    this.height = 42.0,
  });

  @override
  State<AudioWaveVisualizer> createState() => _AudioWaveVisualizerState();
}

class _AudioWaveVisualizerState extends State<AudioWaveVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat(reverse: true);
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
              final double normalizedHeight = widget.isRecording
                  ? (sin((_controller.value * 2 * pi) + (index * 0.45)).abs() *
                          0.7 +
                      0.3)
                  : 0.15;

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                width: 3.5,
                height: widget.height * normalizedHeight,
                decoration: BoxDecoration(
                  color: widget.isRecording
                      ? widget.primaryColor.withOpacity(
                          (0.4 + normalizedHeight * 0.6).clamp(0.4, 1.0),
                        )
                      : AppColors.border,
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

