import '../../core/widgets/app_screen.dart';
import '../../core/widgets/flow_widgets.dart';
import 'admin_dashboard_screen.dart';
import 'package:flutter/material.dart';

class ManagementScreen extends StatelessWidget {
  const ManagementScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.searchLabel,
    required this.actionLabel,
    required this.onAction,
    required this.items,
    required this.icon,
    this.liveTrackingRoute,
    this.onItemTap,
    this.onViewLive,
  });

  final String title;
  final String subtitle;
  final String searchLabel;
  final String actionLabel;
  final VoidCallback onAction;
  final List<(String, String, String)> items;
  final IconData icon;
  final String? liveTrackingRoute;
  final void Function(int index)? onItemTap;
  final void Function(int index)? onViewLive;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 800;
    final gridCount = width >= 1200 ? 3 : 2;

    Widget listWidget;
    if (isWide) {
      listWidget = GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: gridCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 2.8,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          final card = InfoCard(
            icon: icon,
            title: item.$1,
            subtitle: item.$2,
            trailing: item.$3,
            actionLabel: (liveTrackingRoute != null || onViewLive != null) ? 'View Live' : null,
            onAction: () {
              if (onViewLive != null) {
                onViewLive!(index);
              } else if (liveTrackingRoute != null) {
                if (!AdminDashboardScreen.navigateToTab(context, liveTrackingRoute!)) {
                  Navigator.pushNamed(context, liveTrackingRoute!);
                }
              }
            },
          );
          
          if (onItemTap != null) {
            return InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onItemTap!(index),
              child: card,
            );
          }
          return card;
        },
      );
    } else {
      listWidget = Column(
        children: [
          for (int index = 0; index < items.length; index++) ...[
            Builder(
              builder: (context) {
                final item = items[index];
                final card = InfoCard(
                  icon: icon,
                  title: item.$1,
                  subtitle: item.$2,
                  trailing: item.$3,
                  actionLabel: (liveTrackingRoute != null || onViewLive != null) ? 'View Live' : null,
                  onAction: () {
                    if (onViewLive != null) {
                      onViewLive!(index);
                    } else if (liveTrackingRoute != null) {
                      if (!AdminDashboardScreen.navigateToTab(context, liveTrackingRoute!)) {
                        Navigator.pushNamed(context, liveTrackingRoute!);
                      }
                    }
                  },
                );

                if (onItemTap != null) {
                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => onItemTap!(index),
                    child: card,
                  );
                }
                return card;
              }
            ),
            const SizedBox(height: 16),
          ],
        ],
      );
    }

    if (items.isEmpty) {
      listWidget = Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            const Text(
              'No records found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'There is currently no data to display here.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return AppScreen(
      title: title,
      subtitle: subtitle,
      children: [
        SearchActionHeader(
          searchLabel: searchLabel,
          actionLabel: actionLabel,
          onAction: onAction,
        ),
        const SizedBox(height: 8),
        listWidget,
      ],
    );
  }
}

