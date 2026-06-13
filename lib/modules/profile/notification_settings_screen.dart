import 'package:bus_location_tracker/app/theme/app_colors.dart';
import 'package:flutter/material.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  // Trip notifications
  bool _busStarted = true;
  bool _nearMyStop = true;
  bool _busArrived = true;
  bool _busReachedSchool = true;
  bool _delayAlerts = true;
  bool _emergencyAlerts = true;

  // Sound & vibration
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  // Quiet hours
  bool _quietHoursEnabled = false;
  TimeOfDay _quietStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _quietEnd = const TimeOfDay(hour: 7, minute: 0);

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _quietStart : _quietEnd,
    );
    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _quietStart = picked;
        } else {
          _quietEnd = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSoft,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Notification Settings',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: AppColors.textPrimary,
          ),
        ),
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Trip Notifications ───────────────────────────────
          _SectionHeader(
            icon: Icons.directions_bus_rounded,
            title: 'Trip Notifications',
            color: AppColors.primary,
          ),
          const SizedBox(height: 8),
          _NotifCard(
            children: [
              _ToggleTile(
                icon: Icons.play_circle_rounded,
                title: 'Bus Started',
                subtitle: 'When your bus starts the route',
                value: _busStarted,
                color: AppColors.success,
                onChanged: (v) => setState(() => _busStarted = v),
              ),
              _divider(),
              _ToggleTile(
                icon: Icons.near_me_rounded,
                title: 'Near My Stop',
                subtitle: 'When bus is 5 minutes away',
                value: _nearMyStop,
                color: AppColors.primary,
                onChanged: (v) => setState(() => _nearMyStop = v),
              ),
              _divider(),
              _ToggleTile(
                icon: Icons.location_on_rounded,
                title: 'Bus Arrived',
                subtitle: 'When bus reaches your pickup point',
                value: _busArrived,
                color: AppColors.secondary,
                onChanged: (v) => setState(() => _busArrived = v),
              ),
              _divider(),
              _ToggleTile(
                icon: Icons.school_rounded,
                title: 'Reached School',
                subtitle: 'When bus arrives at school',
                value: _busReachedSchool,
                color: const Color(0xFF7B2FBE),
                onChanged: (v) => setState(() => _busReachedSchool = v),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Alert Notifications ───────────────────────────────
          _SectionHeader(
            icon: Icons.warning_amber_rounded,
            title: 'Alert Notifications',
            color: AppColors.warning,
          ),
          const SizedBox(height: 8),
          _NotifCard(
            children: [
              _ToggleTile(
                icon: Icons.schedule_rounded,
                title: 'Delay Alerts',
                subtitle: 'When bus is running late',
                value: _delayAlerts,
                color: AppColors.warning,
                onChanged: (v) => setState(() => _delayAlerts = v),
              ),
              _divider(),
              _ToggleTile(
                icon: Icons.emergency_rounded,
                title: 'Emergency Alerts',
                subtitle: 'Critical safety notifications',
                value: _emergencyAlerts,
                color: AppColors.danger,
                onChanged: (v) => setState(() => _emergencyAlerts = v),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Sound & Vibration ─────────────────────────────────
          _SectionHeader(
            icon: Icons.volume_up_rounded,
            title: 'Sound & Vibration',
            color: AppColors.info,
          ),
          const SizedBox(height: 8),
          _NotifCard(
            children: [
              _ToggleTile(
                icon: Icons.music_note_rounded,
                title: 'Sound',
                subtitle: 'Play sound for notifications',
                value: _soundEnabled,
                color: AppColors.info,
                onChanged: (v) => setState(() => _soundEnabled = v),
              ),
              _divider(),
              _ToggleTile(
                icon: Icons.vibration_rounded,
                title: 'Vibration',
                subtitle: 'Vibrate for notifications',
                value: _vibrationEnabled,
                color: const Color(0xFF7B2FBE),
                onChanged: (v) => setState(() => _vibrationEnabled = v),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Quiet Hours ───────────────────────────────────────
          _SectionHeader(
            icon: Icons.nightlight_round,
            title: 'Quiet Hours',
            color: const Color(0xFF3949AB),
          ),
          const SizedBox(height: 8),
          _NotifCard(
            children: [
              _ToggleTile(
                icon: Icons.do_not_disturb_on_rounded,
                title: 'Enable Quiet Hours',
                subtitle: 'Silence notifications at night',
                value: _quietHoursEnabled,
                color: const Color(0xFF3949AB),
                onChanged: (v) => setState(() => _quietHoursEnabled = v),
              ),
              if (_quietHoursEnabled) ...[
                _divider(),
                _TimeTile(
                  title: 'Start Time',
                  time: _quietStart,
                  enabled: _quietHoursEnabled,
                  onTap: () => _pickTime(true),
                ),
                _divider(),
                _TimeTile(
                  title: 'End Time',
                  time: _quietEnd,
                  enabled: _quietHoursEnabled,
                  onTap: () => _pickTime(false),
                ),
              ],
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _divider() => const Divider(height: 1, indent: 56, endIndent: 0);
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.color,
  });

  final IconData icon;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _NotifCard extends StatelessWidget {
  const _NotifCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final Color color;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: color,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({
    required this.title,
    required this.time,
    required this.enabled,
    required this.onTap,
  });

  final String title;
  final TimeOfDay time;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final formatted =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const SizedBox(width: 50),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Text(
              formatted,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
