import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:invois/configs/routes/routes_name.dart';
import 'package:invois/core/constants/custom_image.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late AnimationController _waveController;
  late AnimationController _particleController;

  @override
  void initState() {
    super.initState();

    _waveController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    _particleController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    );

    _waveController.repeat(reverse: true);
    _particleController.repeat();

    _navigateToHome();
  }

  @override
  void dispose() {
    _waveController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  void _navigateToHome() async {
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      Navigator.of(context).pushReplacementNamed(RoutesName.home);
    }
  }

  Widget _buildBackgroundWaves(Size size) {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return CustomPaint(
          size: size,
          painter: _WavePainter(
            animation: _waveController,
            color: Colors.white.withValues(alpha: 0.03),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: theme.colorScheme.primary,
      body: Stack(
        children: [
          _buildBackgroundWaves(size),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // App Icon with elegant scale, fade, and glow
                Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 32,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Image.asset(CustomImages.logo),
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 600.ms, curve: Curves.easeOut)
                    .scale(duration: 600.ms, curve: Curves.easeOutBack)
                    .then()
                    .shimmer(
                      duration: 1200.ms,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),

                const SizedBox(height: 40),

                // App Title with fade, slide, and shimmer
                Text(
                      'Invois',
                      style: const TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    )
                    .animate()
                    .fadeIn(delay: 300.ms, duration: 800.ms)
                    .slideY(begin: 0.3, end: 0, curve: Curves.easeOut)
                    .then()
                    .shimmer(
                      duration: 1200.ms,
                      color: Colors.white.withValues(alpha: 0.2),
                    ),

                const SizedBox(height: 12),

                // App Subtitle with fade and slight slide
                Text(
                      'Simple · Fast · Easy',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.85),
                        letterSpacing: 1,
                        fontWeight: FontWeight.w400,
                      ),
                    )
                    .animate()
                    .fadeIn(delay: 600.ms, duration: 800.ms)
                    .slideX(begin: -0.1, end: 0, curve: Curves.easeOut),

                const SizedBox(height: 64),

                // Loading Indicator with fade and pulse
                SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    )
                    .animate()
                    .fadeIn(delay: 900.ms, duration: 600.ms)
                    .then()
                    .scaleXY(
                      end: 1.1,
                      duration: 800.ms,
                      curve: Curves.easeInOut,
                    )
                    .then()
                    .scaleXY(
                      end: 1.0,
                      duration: 800.ms,
                      curve: Curves.easeInOut,
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter for background waves
class _WavePainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;

  _WavePainter({required this.animation, required this.color})
    : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final y1 = math.sin(animation.value * 2 * math.pi);

    final startPointY = size.height * (0.8 + 0.1 * y1);
    path.moveTo(0, startPointY);

    for (double x = 0; x < size.width; x++) {
      path.lineTo(
        x,
        size.height *
            (0.8 +
                0.1 *
                    math.sin(
                      (x / size.width) * 2 * math.pi +
                          animation.value * 2 * math.pi,
                    )),
      );
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) => true;
}
