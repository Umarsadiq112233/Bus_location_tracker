import '../../app/theme/app_colors.dart';
import 'custom_button.dart';
import 'custom_text_field.dart';
import 'package:flutter/material.dart';

class InfoCard extends StatefulWidget {
  const InfoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? trailing;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  State<InfoCard> createState() => _InfoCardState();
}

class _InfoCardState extends State<InfoCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0.0, _isHovered ? -4.0 : 0.0, 0.0),
        child: Card(
          elevation: _isHovered ? 6 : 0,
          color: _isHovered
              ? (isDark ? scheme.surfaceContainerHighest : scheme.surfaceContainerLow)
              : (isDark ? AppColors.textPrimary : AppColors.surface),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: _isHovered
                  ? scheme.primary.withValues(alpha: 0.5)
                  : (isDark ? const Color(0xFF263244) : AppColors.outline),
              width: _isHovered ? 1.5 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: _isHovered ? scheme.primary : scheme.primaryContainer,
                  foregroundColor: _isHovered ? Colors.white : scheme.onPrimaryContainer,
                  child: Icon(widget.icon),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: _isHovered ? scheme.primary : scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.subtitle,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                if (widget.trailing != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    widget.trailing!,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
                if (widget.actionLabel != null && widget.onAction != null) ...[
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: widget.onAction,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: _isHovered ? scheme.primaryContainer : null,
                    ),
                    child: Text(widget.actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
class SearchActionHeader extends StatelessWidget {
  const SearchActionHeader({
    super.key,
    required this.searchLabel,
    required this.actionLabel,
    required this.onAction,
  });

  final String searchLabel;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final search = CustomTextField(
          label: searchLabel,
          icon: Icons.search_rounded,
        );
        final button = CustomButton(
          label: actionLabel,
          icon: Icons.add_rounded,
          onPressed: onAction,
        );

        if (compact) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [search, const SizedBox(height: 10), button],
          );
        }

        return Row(
          children: [
            Expanded(child: search),
            const SizedBox(width: 12),
            button,
          ],
        );
      },
    );
  }
}

class FormPanel extends StatelessWidget {
  const FormPanel({
    super.key,
    required this.fields,
    required this.buttonLabel,
    this.onSave,
  });

  final List<(String, IconData)> fields;
  final String buttonLabel;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final field in fields) ...[
              CustomTextField(label: field.$1, icon: field.$2),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: CustomButton(
                label: buttonLabel,
                icon: Icons.save_rounded,
                onPressed: onSave ?? () => Navigator.maybePop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StaticMapPanel extends StatelessWidget {
  const StaticMapPanel({super.key, this.title = 'Live map preview'});

  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: SizedBox(
        height: 330,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(painter: _MiniMapPainter(scheme)),
            ),
            Positioned(
              left: 14,
              top: 14,
              child: Chip(
                avatar: const Icon(Icons.map_rounded, size: 18),
                label: Text(title),
              ),
            ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Card(
                color: scheme.surface.withValues(alpha: .92),
                child: const ListTile(
                  leading: Icon(Icons.directions_bus_rounded),
                  title: Text('BLT-24 - North Campus Loop'),
                  subtitle: Text('Speed 42 km/h - ETA 12 min - Online'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniMapPainter extends CustomPainter {
  const _MiniMapPainter(this.scheme);

  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = scheme.outlineVariant.withValues(alpha: .55)
      ..strokeWidth = 1;
    for (var i = 0; i < 7; i++) {
      final y = size.height * (.15 + i * .12);
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 26), grid);
    }

    final route = Paint()
      ..color = scheme.primary
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(size.width * .12, size.height * .72)
      ..quadraticBezierTo(
        size.width * .4,
        size.height * .18,
        size.width * .62,
        size.height * .48,
      )
      ..quadraticBezierTo(
        size.width * .78,
        size.height * .7,
        size.width * .9,
        size.height * .35,
      );
    canvas.drawPath(path, route);
    canvas.drawCircle(
      Offset(size.width * .62, size.height * .48),
      14,
      Paint()..color = scheme.primary,
    );
  }

  @override
  bool shouldRepaint(covariant _MiniMapPainter oldDelegate) =>
      oldDelegate.scheme != scheme;
}
