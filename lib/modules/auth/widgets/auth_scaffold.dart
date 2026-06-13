import 'dart:math' as math;

import 'package:flutter/material.dart';

class AuthScaffold extends StatefulWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.badge = 'Secure school transport',
    this.showBackButton = true,
    this.showVisual = false,
  });

  final String title;
  final String subtitle;
  final String badge;
  final Widget child;
  final bool showBackButton;
  final bool showVisual;

  @override
  State<AuthScaffold> createState() => _AuthScaffoldState();
}

class _AuthScaffoldState extends State<AuthScaffold>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  painter: _AuthBackgroundPainter(
                    colorScheme: scheme,
                    progress: _controller.value,
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 920;

                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    isWide ? 32 : 16,
                    16,
                    isWide ? 32 : 16,
                    24,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1180),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _AuthTopBar(showBackButton: widget.showBackButton),
                          const SizedBox(height: 22),
                          if (widget.showVisual && isWide)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  flex: 6,
                                  child: _AuthVisualPanel(
                                    animation: _controller,
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Expanded(
                                  flex: 5,
                                  child: _AuthCard(widget: widget),
                                ),
                              ],
                            )
                          else
                            Center(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: widget.showVisual ? 620 : 520,
                                ),
                                child: Column(
                                  children: [
                                    if (widget.showVisual) ...[
                                      _AuthVisualPanel(animation: _controller),
                                      const SizedBox(height: 16),
                                    ],
                                    _AuthCard(widget: widget),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthTopBar extends StatelessWidget {
  const _AuthTopBar({required this.showBackButton});

  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        if (showBackButton)
          IconButton.filledTonal(
            tooltip: 'Back',
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back_rounded),
          )
        else
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.directions_bus_filled_rounded,
              color: scheme.onPrimary,
            ),
          ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BLT',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
              ),
              Text('Bus Location Tracker', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Help',
          onPressed: () {},
          icon: const Icon(Icons.support_agent_rounded),
        ),
      ],
    );
  }
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({required this.widget});

  final AuthScaffold widget;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Card(
        color: scheme.surface.withValues(alpha: .94),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_user_rounded,
                      size: 16,
                      color: scheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.badge,
                      style: TextStyle(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
              if (widget.subtitle.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  widget.subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              widget.child,
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthVisualPanel extends StatelessWidget {
  const _AuthVisualPanel({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AspectRatio(
      aspectRatio: 1.12,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/auth_hero.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: scheme.outlineVariant),
              ),
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 14,
            child: AnimatedBuilder(
              animation: animation,
              builder: (context, _) {
                return Transform.translate(
                  offset: Offset(
                    0,
                    math.sin(animation.value * math.pi * 2) * 4,
                  ),
                  child: _LiveStatusPanel(progress: animation.value),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveStatusPanel extends StatelessWidget {
  const _LiveStatusPanel({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: .9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(
                  value: .62 + (progress * .08),
                  strokeWidth: 4,
                ),
              ),
              const Icon(Icons.directions_bus_rounded),
            ],
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'BLT-24 syncing live',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                Text('ETA 12 min - Route protected'),
              ],
            ),
          ),
          Icon(Icons.shield_rounded, color: scheme.primary),
        ],
      ),
    );
  }
}

class _AuthBackgroundPainter extends CustomPainter {
  const _AuthBackgroundPainter({
    required this.colorScheme,
    required this.progress,
  });

  final ColorScheme colorScheme;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final base = Paint()..color = colorScheme.surface;
    canvas.drawRect(Offset.zero & size, base);

    final primary = Paint()
      ..color = colorScheme.primaryContainer.withValues(alpha: .44);
    final tertiary = Paint()
      ..color = colorScheme.tertiaryContainer.withValues(alpha: .36);

    final drift = math.sin(progress * math.pi * 2) * 18;
    canvas.drawCircle(
      Offset(size.width * .12, size.height * .18 + drift),
      130,
      primary,
    );
    canvas.drawCircle(
      Offset(size.width * .92, size.height * .72 - drift),
      170,
      tertiary,
    );

    final line = Paint()
      ..color = colorScheme.outlineVariant.withValues(alpha: .45)
      ..strokeWidth = 1;
    for (var i = 0; i < 7; i++) {
      final y = size.height * (.12 + i * .13);
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 36), line);
    }
  }

  @override
  bool shouldRepaint(covariant _AuthBackgroundPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.colorScheme != colorScheme;
  }
}
