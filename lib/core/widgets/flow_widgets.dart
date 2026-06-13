import 'package:bus_location_tracker/core/widgets/custom_button.dart';
import 'package:bus_location_tracker/core/widgets/custom_text_field.dart';
import 'package:flutter/material.dart';

class InfoCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: scheme.primaryContainer,
              foregroundColor: scheme.onPrimaryContainer,
              child: Icon(icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Text(subtitle, overflow: TextOverflow.ellipsis, maxLines: 2),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              Text(
                trailing!,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(width: 8),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
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
