import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/theme/app_colors.dart';

class EmergencyAlertsScreen extends StatefulWidget {
  const EmergencyAlertsScreen({super.key});

  @override
  State<EmergencyAlertsScreen> createState() => _EmergencyAlertsScreenState();
}

class _EmergencyAlertsScreenState extends State<EmergencyAlertsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    if (phoneNumber.isEmpty) return;
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        throw 'Could not launch $launchUri';
      }
    } catch (e) {
      debugPrint('Error making call: $e');
    }
  }

  Future<void> _openMapUrl(double lat, double lng) async {
    final Uri googleMapUrl = Uri.parse(
      "https://www.google.com/maps/search/?api=1&query=$lat,$lng",
    );
    try {
      if (await canLaunchUrl(googleMapUrl)) {
        await launchUrl(googleMapUrl, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $googleMapUrl';
      }
    } catch (e) {
      debugPrint('Error opening map: $e');
    }
  }

  String _formatTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.isNegative) {
      return 'Just now';
    }
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year;
    return '$hour:$minute - $day/$month/$year';
  }

  IconData _getEmergencyIcon(String type) {
    return switch (type.toLowerCase()) {
      'accident' => Icons.car_crash_rounded,
      'breakdown' => Icons.build_rounded,
      'medical' => Icons.local_hospital_rounded,
      'traffic delay' => Icons.traffic_rounded,
      _ => Icons.warning_rounded,
    };
  }

  Color _getEmergencyColor(String type) {
    return switch (type.toLowerCase()) {
      'accident' => AppColors.danger,
      'breakdown' => const Color(0xFFE65100),
      'medical' => const Color(0xFF00796B),
      'traffic delay' => const Color(0xFFF57C00),
      _ => const Color(0xFF616161),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Alerts Management'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.admin.primary,
          unselectedLabelColor: scheme.onSurfaceVariant,
          indicatorColor: AppColors.admin.primary,
          tabs: const [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.gpp_maybe_rounded, size: 20),
                  SizedBox(width: 8),
                  Text('Active SOS'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_rounded, size: 20),
                  SizedBox(width: 8),
                  Text('SOS History'),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildAlertsList(context, isActive: true),
            _buildAlertsList(context, isActive: false),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsList(BuildContext context, {required bool isActive}) {
    final scheme = Theme.of(context).colorScheme;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('emergency_alerts')
          .where('status', isEqualTo: isActive ? 'active' : 'resolved')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading alerts: ${snapshot.error}',
              style: TextStyle(color: scheme.error),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isActive
                      ? Icons.shield_rounded
                      : Icons.history_toggle_off_rounded,
                  size: 64,
                  color: scheme.onSurfaceVariant.withOpacity(0.4),
                ),
                const SizedBox(height: 16),
                Text(
                  isActive
                      ? 'No active emergency alerts at the moment.'
                      : 'No resolved alerts in history.',
                  style: themeTextMuted(context),
                ),
                if (isActive) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'All systems running normally.',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                  ),
                ],
              ],
            ),
          );
        }

        // Sort locally by createdAt descending
        final sortedDocs = docs.toList()
          ..sort((a, b) {
            final aTime =
                (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
            final bTime =
                (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: sortedDocs.length,
          itemBuilder: (context, index) {
            final doc = sortedDocs[index];
            final alert = doc.data() as Map<String, dynamic>;
            return _buildAlertCard(context, doc.id, alert, isActive);
          },
        );
      },
    );
  }

  Widget _buildAlertCard(
    BuildContext context,
    String docId,
    Map<String, dynamic> alert,
    bool isActive,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final type = alert['type'] ?? 'Emergency';
    final message = alert['message'] ?? '';
    final driverName = alert['driverName'] ?? 'Unknown Driver';
    final driverPhone = alert['driverPhone'] ?? '';
    final busNum = alert['busNumber'] ?? 'Unknown Bus';
    final busId = alert['busId'] ?? '';
    final address = alert['address'] ?? '';
    final lat = alert['latitude'] as double?;
    final lng = alert['longitude'] as double?;
    final createdAt = alert['createdAt'] as Timestamp?;

    final alertColor = _getEmergencyColor(type);
    final alertIcon = _getEmergencyIcon(type);

    DateTime? alertDateTime = createdAt?.toDate();
    String timeAgo = alertDateTime != null ? _formatTimeAgo(alertDateTime) : '';
    String timeFormatted = alertDateTime != null
        ? _formatDateTime(alertDateTime)
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isActive
            ? (isDark
                  ? AppColors.danger.withOpacity(0.08)
                  : AppColors.danger.withOpacity(0.04))
            : scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? AppColors.danger.withOpacity(0.4)
              : scheme.outlineVariant,
          width: isActive ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header banner/row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type Icon Container
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: alertColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(alertIcon, color: alertColor, size: 24),
                ),
                const SizedBox(width: 12),
                // Title and Bus Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '$type Alert',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isActive
                                  ? AppColors.danger
                                  : scheme.onSurface,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isActive)
                            _PulsingDot(color: AppColors.danger)
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.success.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check,
                                    size: 10,
                                    color: AppColors.success,
                                  ),
                                  SizedBox(width: 2),
                                  Text(
                                    'Resolved',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Bus Number: $busNum',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                // Elapsed time / Date
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (isActive && timeAgo.isNotEmpty)
                      Text(
                        timeAgo,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.danger,
                        ),
                      ),
                    Text(
                      timeFormatted,
                      style: themeTextMuted(context).copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 0.8),

          // Message/Details
          if (message.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? scheme.surfaceContainerHigh
                      : scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.format_quote_rounded,
                      size: 20,
                      color: scheme.onSurfaceVariant.withOpacity(0.5),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        message,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Driver info & Location Details
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Driver Row
                Row(
                  children: [
                    Icon(
                      Icons.person_rounded,
                      size: 16,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Driver: ',
                      style: themeTextMuted(context).copyWith(fontSize: 13),
                    ),
                    Text(
                      driverName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    if (driverPhone.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _makePhoneCall(driverPhone),
                        child: Text(
                          '($driverPhone)',
                          style: TextStyle(
                            color: AppColors.admin.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                // Location Row
                if (address.isNotEmpty)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 16,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          address,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                if (lat != null && lng != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const SizedBox(width: 24),
                      Text(
                        'Coords: ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
                        style: themeTextMuted(context).copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Actions
          if (isActive || (lat != null && lng != null)) ...[
            const Divider(height: 1, thickness: 0.8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  // Locate on Map
                  if (busId.isNotEmpty)
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          '/admin-live-tracking',
                          arguments: busId,
                        );
                      },
                      icon: const Icon(Icons.map_rounded, size: 16),
                      label: const Text('Locate Bus'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.admin.primary,
                        side: BorderSide(color: AppColors.admin.primary),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  // External Maps Link
                  if (lat != null && lng != null)
                    OutlinedButton.icon(
                      onPressed: () => _openMapUrl(lat, lng),
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text('External Map'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: scheme.onSurfaceVariant,
                        side: BorderSide(color: scheme.outline),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  // Call driver
                  if (driverPhone.isNotEmpty)
                    FilledButton.icon(
                      onPressed: () => _makePhoneCall(driverPhone),
                      icon: const Icon(Icons.call_rounded, size: 16),
                      label: const Text('Call Driver'),
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.secondaryContainer,
                        foregroundColor: scheme.onSecondaryContainer,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  // Resolve button
                  if (isActive)
                    FilledButton.icon(
                      onPressed: () => _resolveAlert(context, docId),
                      icon: const Icon(Icons.check_circle_rounded, size: 16),
                      label: const Text('Mark Resolved'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _resolveAlert(BuildContext context, String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('emergency_alerts')
          .doc(docId)
          .update({'status': 'resolved'});

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SOS alert marked as resolved successfully.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to resolve alert: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  TextStyle themeTextMuted(BuildContext context) {
    return TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.8),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});
  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulsingController;

  @override
  void initState() {
    super.initState();
    _pulsingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulsingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulsingController,
      builder: (context, child) {
        return Container(
          width: 8 + (4 * _pulsingController.value),
          height: 8 + (4 * _pulsingController.value),
          decoration: BoxDecoration(
            color: widget.color.withOpacity(
              0.3 + (0.7 * (1.0 - _pulsingController.value)),
            ),
            shape: BoxShape.circle,
            border: Border.all(color: widget.color, width: 1.5),
          ),
        );
      },
    );
  }
}
