import 'package:flutter/material.dart';
import 'package:bus_location_tracker/app/theme/app_colors.dart';

/// A generic pulsing box that serves as the foundation for skeleton loaders.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 12,
    this.margin,
  });

  final double? width;
  final double? height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final Color startColor = isDark 
        ? const Color(0xFF1E293B) // slate 800
        : const Color(0xFFE2E8F0); // slate 200
    final Color endColor = isDark 
        ? const Color(0xFF334155) // slate 700
        : const Color(0xFFF1F5F9); // slate 100

    _colorAnimation = ColorTween(
      begin: startColor,
      end: endColor,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorAnimation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          margin: widget.margin,
          decoration: BoxDecoration(
            color: _colorAnimation.value,
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

/// A professional skeleton screen matching the Student Dashboard layout.
class StudentDashboardSkeleton extends StatelessWidget {
  const StudentDashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF0F172A) : AppColors.surfaceSoft;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row Skeleton
              Row(
                children: [
                  const SkeletonBox(width: 46, height: 46, borderRadius: 14),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBox(width: 120, height: 16),
                        SizedBox(height: 6),
                        SkeletonBox(width: 80, height: 12),
                      ],
                    ),
                  ),
                  const SkeletonBox(width: 38, height: 38, borderRadius: 10),
                ],
              ),
              const SizedBox(height: 20),

              // Arrival Hero Card Skeleton
              const SkeletonBox(width: double.infinity, height: 160, borderRadius: 24),
              const SizedBox(height: 16),

              // Info Cards Row Skeleton
              const Row(
                children: [
                  Expanded(
                    child: SkeletonBox(height: 90, borderRadius: 18),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: SkeletonBox(height: 90, borderRadius: 18),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Quick Actions Skeleton
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 110, height: 16, margin: EdgeInsets.only(bottom: 12)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          SkeletonBox(width: 50, height: 50, borderRadius: 25),
                          SizedBox(height: 8),
                          SkeletonBox(width: 60, height: 10),
                        ],
                      ),
                      Column(
                        children: [
                          SkeletonBox(width: 50, height: 50, borderRadius: 25),
                          SizedBox(height: 8),
                          SkeletonBox(width: 60, height: 10),
                        ],
                      ),
                      Column(
                        children: [
                          SkeletonBox(width: 50, height: 50, borderRadius: 25),
                          SizedBox(height: 8),
                          SkeletonBox(width: 60, height: 10),
                        ],
                      ),
                      Column(
                        children: [
                          SkeletonBox(width: 50, height: 50, borderRadius: 25),
                          SizedBox(height: 8),
                          SkeletonBox(width: 60, height: 10),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Schedule Card Skeleton
              const SkeletonBox(width: double.infinity, height: 110, borderRadius: 20),
              const SizedBox(height: 16),

              // Timeline Card Skeleton
              const SkeletonBox(width: double.infinity, height: 150, borderRadius: 20),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildDummyBottomNav(context),
    );
  }
}

/// A professional skeleton screen matching the Parent Dashboard layout.
class ParentDashboardSkeleton extends StatelessWidget {
  const ParentDashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF0F172A) : AppColors.surfaceSoft;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          children: [
            // SliverAppBar Dummy Header
            Container(
              height: 148,
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : AppColors.parent.primary,
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SkeletonBox(width: 24, height: 24, borderRadius: 6),
                  SizedBox(width: 10),
                  SkeletonBox(width: 140, height: 18),
                  Spacer(),
                  SkeletonBox(width: 34, height: 34, borderRadius: 17),
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Children Selector Skeleton
                  const Row(
                    children: [
                      SkeletonBox(width: 90, height: 38, borderRadius: 20),
                      SizedBox(width: 8),
                      SkeletonBox(width: 90, height: 38, borderRadius: 20),
                      Spacer(),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Live Map Hero Card Skeleton
                  const SkeletonBox(width: double.infinity, height: 240, borderRadius: 24),
                  const SizedBox(height: 16),

                  // Bus Status Row Skeleton
                  const Row(
                    children: [
                      Expanded(child: SkeletonBox(height: 70, borderRadius: 16)),
                      SizedBox(width: 12),
                      Expanded(child: SkeletonBox(height: 70, borderRadius: 16)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Quick Actions Card Skeleton
                  const SkeletonBox(width: double.infinity, height: 80, borderRadius: 20),
                  const SizedBox(height: 16),

                  // Today Journey Card Skeleton
                  const SkeletonBox(width: double.infinity, height: 140, borderRadius: 20),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildDummyBottomNav(context),
    );
  }
}

/// A professional skeleton screen matching the Driver Dashboard layout.
class DriverDashboardSkeleton extends StatelessWidget {
  const DriverDashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF0F172A) : AppColors.surfaceSoft;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          children: [
            // Dummy SliverAppBar Header
            Container(
              height: 180,
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 54, 20, 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : AppColors.primary,
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      SkeletonBox(width: 46, height: 46, borderRadius: 14),
                      SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(width: 80, height: 12),
                          SizedBox(height: 6),
                          SkeletonBox(width: 120, height: 18),
                        ],
                      ),
                      Spacer(),
                      SkeletonBox(width: 70, height: 26, borderRadius: 13),
                    ],
                  ),
                  SizedBox(height: 16),
                  SkeletonBox(width: 200, height: 26, borderRadius: 13),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bus Assigned Card Skeleton
                  const SkeletonBox(width: double.infinity, height: 100, borderRadius: 20),
                  const SizedBox(height: 16),

                  // Trip Actions Card Skeleton
                  const SkeletonBox(width: double.infinity, height: 160, borderRadius: 24),
                  const SizedBox(height: 20),

                  // System Status Grid Title Dummy
                  const SkeletonBox(width: 100, height: 16, margin: EdgeInsets.only(bottom: 12)),
                  
                  // System Status Grid Dummy
                  const Row(
                    children: [
                      Expanded(child: SkeletonBox(height: 80, borderRadius: 16)),
                      SizedBox(width: 12),
                      Expanded(child: SkeletonBox(height: 80, borderRadius: 16)),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Quick Actions Grid Title Dummy
                  const SkeletonBox(width: 100, height: 16, margin: EdgeInsets.only(bottom: 12)),

                  // Quick Actions Grid Dummy
                  const Row(
                    children: [
                      Expanded(child: SkeletonBox(height: 80, borderRadius: 16)),
                      SizedBox(width: 12),
                      Expanded(child: SkeletonBox(height: 80, borderRadius: 16)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildDummyBottomNav(context),
    );
  }
}

/// A generic list skeleton containing multiple rows of card/tile placeholders.
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({
    super.key,
    this.itemCount = 3,
    this.cardHeight = 90,
    this.borderRadius = 16,
    this.spacing = 16,
    this.padding = const EdgeInsets.all(16),
  });

  final int itemCount;
  final double cardHeight;
  final double borderRadius;
  final double spacing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: padding,
      itemCount: itemCount,
      separatorBuilder: (context, index) => SizedBox(height: spacing),
      itemBuilder: (context, index) {
        return Container(
          height: cardHeight,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              SkeletonBox(width: 50, height: 50, borderRadius: borderRadius),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SkeletonBox(width: 120, height: 14),
                    const SizedBox(height: 8),
                    SkeletonBox(
                      width: double.infinity,
                      height: 10,
                      margin: const EdgeInsets.only(right: 32),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              const SkeletonBox(width: 24, height: 24, borderRadius: 6),
            ],
          ),
        );
      },
    );
  }
}

/// Helper method to construct a dummy bottom navigation bar matching the design system
Widget _buildDummyBottomNav(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return Container(
    height: 64,
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      border: Border(
        top: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
      ),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: List.generate(4, (index) {
        return const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SkeletonBox(width: 22, height: 22, borderRadius: 6),
            SizedBox(height: 4),
            SkeletonBox(width: 32, height: 8),
          ],
        );
      }),
    ),
  );
}

/// A professional skeleton screen matching the Profile Screen layout.
class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF0F172A) : AppColors.surfaceSoft;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          children: [
            // Dummy Header Card
            Container(
              height: 240,
              width: double.infinity,
              padding: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : AppColors.primary,
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SkeletonBox(width: 90, height: 90, borderRadius: 45),
                  SizedBox(height: 12),
                  SkeletonBox(width: 150, height: 18),
                  SizedBox(height: 8),
                  SkeletonBox(width: 80, height: 12, borderRadius: 6),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SkeletonBox(width: 140, height: 14),
                  const SizedBox(height: 12),
                  const SkeletonBox(width: double.infinity, height: 100, borderRadius: 16),
                  const SizedBox(height: 24),
                  const SkeletonBox(width: 140, height: 14),
                  const SizedBox(height: 12),
                  const SkeletonBox(width: double.infinity, height: 100, borderRadius: 16),
                  const SizedBox(height: 24),
                  const SkeletonBox(width: double.infinity, height: 52, borderRadius: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
