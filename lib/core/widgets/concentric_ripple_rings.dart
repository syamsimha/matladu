import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Concentric glowing radial ripple rings surrounding the central voice microphone
/// as displayed on the Matladu AI Home / Translator Screen (Screen 2).
class ConcentricRippleRings extends StatefulWidget {
  final bool isListening;
  final VoidCallback onTap;

  const ConcentricRippleRings({
    super.key,
    required this.isListening,
    required this.onTap,
  });

  @override
  State<ConcentricRippleRings> createState() => _ConcentricRippleRingsState();
}

class _ConcentricRippleRingsState extends State<ConcentricRippleRings>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, child) {
        final double pulse = widget.isListening ? _scaleAnimation.value : 1.0;

        return Center(
          child: SizedBox(
            width: 220,
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer Subtle Halo Ring
                Transform.scale(
                  scale: pulse,
                  child: Container(
                    width: 210,
                    height: 210,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.micRipple1.withOpacity(widget.isListening ? 0.35 : 0.20),
                          AppColors.micRipple1.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ),

                // Middle Translucent Ring
                Transform.scale(
                  scale: widget.isListening ? (2.0 - pulse) : 1.0,
                  child: Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.cardLightBlue.withOpacity(0.85),
                      border: Border.all(
                        color: AppColors.primaryLight.withOpacity(0.18),
                        width: 1.5,
                      ),
                    ),
                  ),
                ),

                // Inner Soft Ring
                Container(
                  width: 135,
                  height: 135,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.12),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),

                // Center Vivid Blue Action Button with Microphone Icon
                GestureDetector(
                  onTap: widget.onTap,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: widget.isListening
                          ? const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF2563EB),
                                Color(0xFF9333EA),
                              ],
                            )
                          : AppColors.primaryGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.38),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        widget.isListening
                            ? Icons.graphic_eq_rounded
                            : Icons.mic_rounded,
                        size: 44,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
