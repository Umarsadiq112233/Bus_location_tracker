import 'dart:math' as math;
import 'package:bus_location_tracker/app/theme/app_colors.dart';

import 'package:bus_location_tracker/app/routes/app_routes.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Onboarding Screen — full animated, scene-based backgrounds
// ─────────────────────────────────────────────────────────────────────────────
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late final AnimationController _bgAnimController;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  static const _slides = [
    _SlideData(
      title: 'Track Your Bus Live',
      subtitle:
          'View the real-time location of your school or college bus on an interactive map.',
      scene: _Scene.tracking,
      gradient: [Color(0xFF005F6B), Color(0xFF00B4CC)],
      accentColor: Color(0xFF00E5FF),
    ),
    _SlideData(
      title: 'Stay Safe & Updated',
      subtitle:
          'Get instant alerts when the bus starts, arrives, or is near your stop.',
      scene: _Scene.alerts,
      gradient: [Color(0xFF4A148C), Color(0xFF7B2FBE)],
      accentColor: Color(0xFFFFB703),
    ),
    _SlideData(
      title: 'Complete Transport System',
      subtitle:
          'Built for parents, students, drivers, and admins — one platform for everyone.',
      scene: _Scene.community,
      gradient: [Color(0xFF1B5E20), AppColors.success],
      accentColor: Color(0xFF69F0AE),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _bgAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _bgAnimController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage == _slides.length - 1) {
      _goLogin();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  void _goLogin() {
    Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgAnimController,
        builder: (context, _) {
          return Stack(
            children: [
              // ── Animated Scene Background ─────────────────────
              Positioned.fill(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemCount: _slides.length,
                  itemBuilder: (context, index) {
                    final slide = _slides[index];
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 600),
                      child: CustomPaint(
                        key: ValueKey(index),
                        painter: _ScenePainter(
                          scene: slide.scene,
                          progress: _bgAnimController.value,
                          colors: slide.gradient,
                          accentColor: slide.accentColor,
                        ),
                        size: size,
                      ),
                    );
                  },
                ),
              ),

              // ── Bottom frosted card area ───────────────────────
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _BottomSlidePanel(
                  slides: _slides,
                  currentPage: _currentPage,
                  fadeAnimation: _fadeAnimation,
                  onNext: _nextPage,
                  onSkip: _goLogin,
                ),
              ),

              // ── Skip button top-right ─────────────────────────
              Positioned(
                top: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: AnimatedOpacity(
                      opacity: _currentPage < _slides.length - 1 ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: GestureDetector(
                        onTap: _goLogin,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Text(
                            'Skip',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom Panel
// ─────────────────────────────────────────────────────────────────────────────
class _BottomSlidePanel extends StatefulWidget {
  const _BottomSlidePanel({
    required this.slides,
    required this.currentPage,
    required this.fadeAnimation,
    required this.onNext,
    required this.onSkip,
  });

  final List<_SlideData> slides;
  final int currentPage;
  final Animation<double> fadeAnimation;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  State<_BottomSlidePanel> createState() => _BottomSlidePanelState();
}

class _BottomSlidePanelState extends State<_BottomSlidePanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pageCtrl;
  final PageController _textPager = PageController();

  @override
  void initState() {
    super.initState();
    _pageCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
  }

  @override
  void didUpdateWidget(covariant _BottomSlidePanel old) {
    super.didUpdateWidget(old);
    if (old.currentPage != widget.currentPage) {
      _pageCtrl.forward(from: 0);
      _textPager.animateToPage(
        widget.currentPage,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _textPager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slide = widget.slides[widget.currentPage];
    final isLast = widget.currentPage == widget.slides.length - 1;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Page dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.slides.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: widget.currentPage == i ? 28 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: widget.currentPage == i
                          ? slide.gradient[0]
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Animated text via pager
              SizedBox(
                height: 110,
                child: PageView.builder(
                  controller: _textPager,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: widget.slides.length,
                  itemBuilder: (ctx, i) {
                    final s = widget.slides[i];
                    return Column(
                      children: [
                        Text(
                          s.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Colors.grey.shade900,
                            letterSpacing: -0.5,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          s.subtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            height: 1.6,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 28),

              // CTA Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: slide.gradient),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: slide.gradient[0].withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: widget.onNext,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isLast ? '🚌  Get Started' : 'Next',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            letterSpacing: 0.3,
                          ),
                        ),
                        if (!isLast) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 20),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data
// ─────────────────────────────────────────────────────────────────────────────
enum _Scene { tracking, alerts, community }

class _SlideData {
  const _SlideData({
    required this.title,
    required this.subtitle,
    required this.scene,
    required this.gradient,
    required this.accentColor,
  });

  final String title;
  final String subtitle;
  final _Scene scene;
  final List<Color> gradient;
  final Color accentColor;
}

// ─────────────────────────────────────────────────────────────────────────────
// Scene Painters
// ─────────────────────────────────────────────────────────────────────────────
class _ScenePainter extends CustomPainter {
  const _ScenePainter({
    required this.scene,
    required this.progress,
    required this.colors,
    required this.accentColor,
  });

  final _Scene scene;
  final double progress;
  final List<Color> colors;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    // Gradient background
    final bgRect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(
      bgRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ).createShader(bgRect),
    );

    switch (scene) {
      case _Scene.tracking:
        _paintTrackingScene(canvas, size);
        break;
      case _Scene.alerts:
        _paintAlertsScene(canvas, size);
        break;
      case _Scene.community:
        _paintCommunityScene(canvas, size);
        break;
    }
  }

  void _paintTrackingScene(Canvas canvas, Size size) {
    // Stars / particles
    final rng = math.Random(42);
    final starPaint = Paint()..color = Colors.white.withValues(alpha: 0.15);
    for (var i = 0; i < 40; i++) {
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        rng.nextDouble() * 2 + 0.5,
        starPaint,
      );
    }

    // Grid roads
    final roadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(0, size.height * 0.55),
      Offset(size.width, size.height * 0.55),
      roadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.35, 0),
      Offset(size.width * 0.35, size.height * 0.75),
      roadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.7, size.height * 0.2),
      Offset(size.width * 0.7, size.height * 0.75),
      roadPaint,
    );

    // Route polyline
    final routePath = Path()
      ..moveTo(size.width * 0.05, size.height * 0.55)
      ..cubicTo(
        size.width * 0.2,
        size.height * 0.3,
        size.width * 0.35,
        size.height * 0.25,
        size.width * 0.55,
        size.height * 0.35,
      )
      ..cubicTo(
        size.width * 0.65,
        size.height * 0.4,
        size.width * 0.72,
        size.height * 0.3,
        size.width * 0.92,
        size.height * 0.2,
      );

    canvas.drawPath(
      routePath,
      Paint()
        ..color = accentColor.withValues(alpha: 0.6)
        ..strokeWidth = 5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Animated bus on route
    final pm = routePath.computeMetrics().first;
    final busPos = pm.getTangentForOffset(pm.length * (0.15 + progress * 0.7));
    if (busPos != null) {
      final bx = busPos.position.dx;
      final by = busPos.position.dy;

      // Pulse
      canvas.drawCircle(
        Offset(bx, by),
        24 * (0.7 + math.sin(progress * math.pi * 2) * 0.3),
        Paint()..color = accentColor.withValues(alpha: 0.2),
      );
      canvas.drawCircle(Offset(bx, by), 16, Paint()..color = Colors.white);
      canvas.drawCircle(Offset(bx, by), 10, Paint()..color = colors[0]);
    }

    // City buildings
    _drawBuildings(canvas, Offset.zero, Colors.white.withValues(alpha: 0.1));

    // Location pin at end
    _drawPin(canvas, Offset(size.width * 0.9, size.height * 0.17), accentColor);

    // Pickup dot
    _drawPin(
      canvas,
      Offset(size.width * 0.07, size.height * 0.53),
      Colors.white.withValues(alpha: 0.9),
    );
  }

  void _paintAlertsScene(Canvas canvas, Size size) {
    // Stars
    final rng = math.Random(77);
    for (var i = 0; i < 50; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height * 0.6;
      final r = rng.nextDouble() * 1.5 + 0.5;
      canvas.drawCircle(
        Offset(x, y),
        r,
        Paint()
          ..color = Colors.white.withValues(
            alpha: rng.nextDouble() * 0.4 + 0.1,
          ),
      );
    }

    // Phone-like device
    final phoneRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.35),
        width: size.width * 0.48,
        height: size.height * 0.42,
      ),
      const Radius.circular(24),
    );
    canvas.drawRRect(
      phoneRect,
      Paint()..color = Colors.white.withValues(alpha: 0.12),
    );
    canvas.drawRRect(
      phoneRect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Notification rings / bell animation
    final cx = size.width * 0.5;
    final cy = size.height * 0.33;
    final bellPulse = math.sin(progress * math.pi * 2);

    for (var i = 1; i <= 3; i++) {
      final radius = 30.0 * i + progress * 20;
      canvas.drawCircle(
        Offset(cx, cy),
        radius,
        Paint()
          ..color = accentColor.withValues(alpha: math.max(0, 0.3 - i * 0.08))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    // Bell icon
    canvas.drawCircle(
      Offset(cx, cy + bellPulse * 3),
      22,
      Paint()..color = accentColor,
    );

    // Notification cards
    _drawNotifCard(
      canvas,
      Offset(size.width * 0.18, size.height * 0.56),
      size.width * 0.64,
      'Bus is near your stop!',
      Colors.white.withValues(alpha: 0.15),
    );

    _drawNotifCard(
      canvas,
      Offset(size.width * 0.24, size.height * 0.64),
      size.width * 0.52,
      'Bus arrived at Gulshan',
      Colors.white.withValues(alpha: 0.1),
    );
  }

  void _paintCommunityScene(Canvas canvas, Size size) {
    // Background geometric pattern
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    for (var i = 0; i < 10; i++) {
      canvas.drawLine(
        Offset(0, size.height * i / 10),
        Offset(size.width, size.height * i / 10),
        gridPaint,
      );
    }

    // 4 role bubbles
    final roles = [
      (
        'Parent',
        Icons.family_restroom_rounded,
        Offset(size.width * 0.25, size.height * 0.28),
      ),
      (
        'Student',
        Icons.school_rounded,
        Offset(size.width * 0.72, size.height * 0.24),
      ),
      (
        'Driver',
        Icons.drive_eta_rounded,
        Offset(size.width * 0.2, size.height * 0.52),
      ),
      (
        'Admin',
        Icons.admin_panel_settings_rounded,
        Offset(size.width * 0.75, size.height * 0.5),
      ),
    ];

    final center = Offset(size.width * 0.5, size.height * 0.38);

    // Center bus icon
    final centerPulse = math.sin(progress * math.pi * 2) * 4;
    canvas.drawCircle(
      center + Offset(0, centerPulse),
      38 + centerPulse.abs(),
      Paint()..color = Colors.white.withValues(alpha: 0.15),
    );
    canvas.drawCircle(
      center + Offset(0, centerPulse),
      28,
      Paint()..color = Colors.white.withValues(alpha: 0.25),
    );

    // Lines to roles
    for (final role in roles) {
      canvas.drawLine(
        center,
        role.$3,
        Paint()
          ..color = accentColor.withValues(alpha: 0.35)
          ..strokeWidth = 1.5,
      );
    }

    // Role circles
    for (var i = 0; i < roles.length; i++) {
      final role = roles[i];
      final bounce = math.sin(progress * math.pi * 2 + i * math.pi / 2) * 5;

      canvas.drawCircle(
        role.$3 + Offset(0, bounce),
        24,
        Paint()..color = Colors.white.withValues(alpha: 0.18),
      );
      canvas.drawCircle(
        role.$3 + Offset(0, bounce),
        24,
        Paint()
          ..color = accentColor.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  void _drawBuildings(Canvas canvas, Offset offset, Color color) {}

  void _drawPin(Canvas canvas, Offset center, Color color) {
    canvas.drawCircle(center, 10, Paint()..color = color);
    canvas.drawCircle(
      center,
      10,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(center, 4, Paint()..color = Colors.white);
  }

  void _drawNotifCard(
    Canvas canvas,
    Offset topLeft,
    double width,
    String label,
    Color color,
  ) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(topLeft.dx, topLeft.dy, width, 30),
      const Radius.circular(8),
    );
    canvas.drawRRect(rect, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _ScenePainter old) =>
      old.progress != progress || old.scene != scene;
}
