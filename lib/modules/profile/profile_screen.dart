import 'package:bus_location_tracker/app/routes/app_routes.dart';
import 'package:bus_location_tracker/app/theme/app_colors.dart';
import 'package:bus_location_tracker/core/models/bus_model.dart';
import 'package:bus_location_tracker/core/models/route_model.dart';
import 'package:bus_location_tracker/core/models/user_model.dart';
import 'package:bus_location_tracker/core/services/auth_service.dart';
import 'package:bus_location_tracker/shared/enums/user_role.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:bus_location_tracker/core/utils/profile_image_helper.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:bus_location_tracker/core/widgets/skeleton_loader.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    this.compactStudentMode = false,
    this.driver,
    this.bus,
    this.route,
    this.onProfileUpdated,
  });

  final bool compactStudentMode;
  final UserModel? driver;
  final BusModel? bus;
  final RouteModel? route;
  final VoidCallback? onProfileUpdated;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  UserModel? _user;
  BusModel? _bus;
  RouteModel? _route;
  Uint8List? _localImageBytes;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.driver != oldWidget.driver ||
        widget.bus != oldWidget.bus ||
        widget.route != oldWidget.route) {
      if (widget.driver != null) {
        setState(() {
          _user = widget.driver;
          _bus = widget.bus;
          _route = widget.route;
          _isLoading = false;
        });
        _loadLocalImage(_user!.uid);
      }
    }
  }

  Future<void> _loadLocalImage(String uid) async {
    final bytes = await ProfileImageHelper.getProfileImage(uid);
    if (mounted) {
      setState(() {
        _localImageBytes = bytes;
      });
    }
  }

  Future<void> _loadProfileData({bool forceFetch = false}) async {
    if (widget.driver != null && !forceFetch) {
      setState(() {
        _user = widget.driver;
        _bus = widget.bus;
        _route = widget.route;
        _isLoading = false;
      });
      _loadLocalImage(_user!.uid);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final auth = AuthService();
      final currentUser = auth.currentUser;
      if (currentUser == null) {
        setState(() {
          _errorMessage = 'No user logged in.';
          _isLoading = false;
        });
        return;
      }

      final user = await auth.getUserData(currentUser.uid);
      if (user == null) {
        setState(() {
          _errorMessage = 'User profile data not found.';
          _isLoading = false;
        });
        return;
      }

      BusModel? bus;
      RouteModel? route;

      if (user.assignedBusId != null && user.assignedBusId!.isNotEmpty) {
        bus = await auth.fetchAssignedBus(user.assignedBusId!);
        if (bus != null &&
            bus.assignedRouteId != null &&
            bus.assignedRouteId!.isNotEmpty) {
          route = await auth.fetchAssignedRoute(bus.assignedRouteId!);
        }
      } else {
        // Fallback for drivers
        final busesSnapshot = await FirebaseFirestore.instance
            .collection('buses')
            .where('assignedDriverId', isEqualTo: user.uid)
            .get();
        if (busesSnapshot.docs.isNotEmpty) {
          final busDoc = busesSnapshot.docs.first;
          bus = BusModel.fromMap(busDoc.data(), busDoc.id);
          if (bus.assignedRouteId != null && bus.assignedRouteId!.isNotEmpty) {
            route = await auth.fetchAssignedRoute(bus.assignedRouteId!);
          }
        }
      }

      setState(() {
        _user = user;
        _bus = bus;
        _route = route;
        _isLoading = false;
      });
      _loadLocalImage(user.uid);
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load profile data: $e';
        _isLoading = false;
      });
    }
  }

  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    final parts = name.trim().split(' ');
    if (parts.length > 1) {
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await AuthService().logout();
              if (!context.mounted) return;
              Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.login,
                (route) => false,
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return const ProfileSkeleton();
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: scheme.error),
              const SizedBox(height: 16),
              Text(_errorMessage!, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadProfileData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final isStudent =
        widget.compactStudentMode || _user!.role == UserRole.student;
    final isDriver = _user!.role == UserRole.driver;

    if (isStudent) {
      return _buildStudentProfileView(context);
    } else if (isDriver) {
      return _buildDriverProfileView(context, scheme, isDark);
    } else {
      return _buildParentProfileView(context, scheme, isDark);
    }
  }

  // ───────────────────────────────────────────────────────────────
  // Parent Profile View
  // ───────────────────────────────────────────────────────────────
  Widget _buildParentProfileView(
    BuildContext context,
    ColorScheme scheme,
    bool isDark,
  ) {
    return Scaffold(
      backgroundColor: scheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: isDark
                ? const Color(0xFF1A3A5C)
                : AppColors.parent.primary,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [const Color(0xFF0D253F), const Color(0xFF1A3A5C)]
                            : [
                                AppColors.parent.primary,
                                const Color(0xFF42A5F5),
                              ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: -50,
                    right: -50,
                    child: CircleAvatar(
                      radius: 100,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  Positioned(
                    bottom: -30,
                    left: -30,
                    child: CircleAvatar(
                      radius: 80,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        Hero(
                          tag: 'profile_avatar',
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 45,
                              backgroundColor: Colors.white,
                              backgroundImage: _localImageBytes != null
                                  ? MemoryImage(_localImageBytes!)
                                  : null,
                              child: _localImageBytes == null
                                  ? Text(
                                      _getInitials(_user!.name),
                                      style: TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.parent.primary,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _user!.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _user!.role?.name.toUpperCase() ?? 'PARENT',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionHeading(title: 'Personal Information'),
                  _ProfileCard(
                    children: [
                      _ProfileListTile(
                        icon: Icons.email_rounded,
                        title: 'Email',
                        subtitle: _user!.email,
                        iconColor: AppColors.parent.primary,
                      ),
                      const Divider(height: 1, indent: 56),
                      _ProfileListTile(
                        icon: Icons.phone_rounded,
                        title: 'Phone Number',
                        subtitle: _user!.phone.isNotEmpty
                            ? _user!.phone
                            : 'Not set',
                        iconColor: AppColors.success,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const _SectionHeading(title: 'Account Settings'),
                  _ProfileCard(
                    children: [
                      _ProfileListTile(
                        icon: Icons.edit_rounded,
                        title: 'Edit Profile',
                        subtitle: 'Update your personal details',
                        iconColor: AppColors.warning,
                        onTap: () =>
                            Navigator.pushNamed(
                              context,
                              AppRoutes.editProfile,
                            ).then((_) {
                              _loadProfileData(forceFetch: true);
                              if (widget.onProfileUpdated != null) {
                                widget.onProfileUpdated!();
                              }
                            }),
                        showTrailing: true,
                      ),
                      const Divider(height: 1, indent: 56),
                      _ProfileListTile(
                        icon: Icons.lock_rounded,
                        title: 'Change Password',
                        subtitle: 'Update your security credentials',
                        iconColor: const Color(0xFF7B2FBE),
                        onTap: () {},
                        showTrailing: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const _SectionHeading(title: 'Preferences'),
                  _ProfileCard(
                    children: [
                      _ProfileListTile(
                        icon: Icons.home_rounded,
                        title: 'Home Geofence',
                        subtitle: 'Block 13-D, Karachi',
                        iconColor: const Color(0xFF005F6B),
                        onTap: () {},
                        showTrailing: true,
                      ),
                      const Divider(height: 1, indent: 56),
                      _ProfileListTile(
                        icon: Icons.notifications_active_rounded,
                        title: 'Arrival Notifications',
                        subtitle: 'Manage alerts and sounds',
                        iconColor: const Color(0xFFFFB703),
                        onTap: () {},
                        showTrailing: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: () => _handleLogout(context),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text(
                        'Logout',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: scheme.error,
                        side: BorderSide(
                          color: scheme.error.withValues(alpha: 0.5),
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────
  // Driver Profile View
  // ───────────────────────────────────────────────────────────────
  Widget _buildDriverProfileView(
    BuildContext context,
    ColorScheme scheme,
    bool isDark,
  ) {
    return Scaffold(
      backgroundColor: scheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: isDark
                ? const Color(0xFF2C2C2C)
                : const Color(0xFF37474F),
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [const Color(0xFF1E1E1E), const Color(0xFF2C3E50)]
                            : [
                                const Color(0xFF37474F),
                                const Color(0xFF546E7A),
                              ],
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 20),
                        Hero(
                          tag: 'profile_avatar',
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 45,
                              backgroundColor: Colors.white,
                              backgroundImage: _localImageBytes != null
                                  ? MemoryImage(_localImageBytes!)
                                  : null,
                              child: _localImageBytes == null
                                  ? Text(
                                      _getInitials(_user!.name),
                                      style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF37474F),
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _user!.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'DRIVER',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionHeading(title: 'Personal Information'),
                  _ProfileCard(
                    children: [
                      _ProfileListTile(
                        icon: Icons.email_rounded,
                        title: 'Email',
                        subtitle: _user!.email,
                        iconColor: const Color(0xFF546E7A),
                      ),
                      const Divider(height: 1, indent: 56),
                      _ProfileListTile(
                        icon: Icons.phone_rounded,
                        title: 'Phone Number',
                        subtitle: _user!.phone.isNotEmpty
                            ? _user!.phone
                            : 'Not set',
                        iconColor: AppColors.success,
                      ),
                      const Divider(height: 1, indent: 56),
                      _ProfileListTile(
                        icon: Icons.badge_rounded,
                        title: 'License Number',
                        subtitle: _user!.licenseNumber ?? 'Not provided',
                        iconColor: AppColors.warning,
                      ),
                      const Divider(height: 1, indent: 56),
                      _ProfileListTile(
                        icon: Icons.work_history_rounded,
                        title: 'Experience',
                        subtitle: _user!.experienceYears != null
                            ? '${_user!.experienceYears} Years'
                            : 'Not provided',
                        iconColor: const Color(0xFF7B2FBE),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const _SectionHeading(title: 'Assigned Duty Details'),
                  _ProfileCard(
                    children: [
                      _ProfileListTile(
                        icon: Icons.directions_bus_filled_rounded,
                        title: 'Bus Assigned',
                        subtitle: _bus != null
                            ? '${_bus!.busNumber} (${_bus!.plateNumber})'
                            : 'No Bus Assigned',
                        iconColor: AppColors.parent.primary,
                      ),
                      const Divider(height: 1, indent: 56),
                      _ProfileListTile(
                        icon: Icons.route_rounded,
                        title: 'Assigned Route',
                        subtitle: _route != null
                            ? _route!.name
                            : 'No Route Assigned',
                        iconColor: AppColors.success,
                      ),
                      if (_route != null) ...[
                        const Divider(height: 1, indent: 56),
                        _ProfileListTile(
                          icon: Icons.navigation_rounded,
                          title: 'Route Coverage',
                          subtitle:
                              '${_route!.startPoint} ➔ ${_route!.endPoint}',
                          iconColor: AppColors.info,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (AuthService().currentUser != null &&
                      _user != null &&
                      AuthService().currentUser!.uid == _user!.uid) ...[
                    const _SectionHeading(title: 'Account Settings'),
                    _ProfileCard(
                      children: [
                        _ProfileListTile(
                          icon: Icons.edit_rounded,
                          title: 'Edit Profile',
                          subtitle:
                              'Update your professional & personal details',
                          iconColor: AppColors.warning,
                          onTap: () =>
                              Navigator.pushNamed(
                                context,
                                AppRoutes.editProfile,
                              ).then((_) {
                                _loadProfileData(forceFetch: true);
                                if (widget.onProfileUpdated != null) {
                                  widget.onProfileUpdated!();
                                }
                              }),
                          showTrailing: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed: () => _handleLogout(context),
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text(
                          'Logout',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: scheme.error,
                          side: BorderSide(
                            color: scheme.error.withValues(alpha: 0.5),
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────
  // Student Profile View
  // ───────────────────────────────────────────────────────────────
  Widget _buildStudentProfileView(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceSoft,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            automaticallyImplyLeading: false,
            backgroundColor: AppColors.primary,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.primary, Color(0xFF42A5F5)],
                      ),
                    ),
                  ),
                  Positioned(
                    top: -40,
                    right: -40,
                    child: CircleAvatar(
                      radius: 90,
                      backgroundColor: Colors.white.withValues(alpha: .08),
                    ),
                  ),
                  Positioned(
                    bottom: -20,
                    left: -20,
                    child: CircleAvatar(
                      radius: 70,
                      backgroundColor: Colors.white.withValues(alpha: .06),
                    ),
                  ),
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Stack(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: .2),
                                      blurRadius: 14,
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 44,
                                  backgroundColor: AppColors.primaryLight,
                                  backgroundImage: _localImageBytes != null
                                      ? MemoryImage(_localImageBytes!)
                                      : null,
                                  child: _localImageBytes == null
                                      ? Text(
                                          _getInitials(_user!.name),
                                          style: TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.primary,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: () =>
                                      _showStudentQrZoomDialog(context),
                                  child: Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 1.5,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.black26,
                                          blurRadius: 4,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.qr_code_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _user!.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _PillBadge(
                                text: 'Student',
                                color: Colors.white.withValues(alpha: .22),
                              ),
                              const SizedBox(width: 8),
                              _PillBadge(
                                text: _bus != null
                                    ? 'Bus ${_bus!.busNumber}'
                                    : 'No Bus',
                                color: Colors.white.withValues(alpha: .22),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            title: const Text(
              'My Profile',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Stats row
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 8,
                    ),
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
                    child: Row(
                      children: [
                        Expanded(
                          child: _StatItem(
                            icon: Icons.directions_bus_rounded,
                            label: 'Bus',
                            value: _bus != null ? _bus!.busNumber : 'None',
                            color: AppColors.primary,
                          ),
                        ),
                        const _StatDivider(),
                        Expanded(
                          child: _StatItem(
                            icon: Icons.school_rounded,
                            label: 'Grade',
                            value: '10th · B',
                            color: const Color(0xFF7B2FBE),
                          ),
                        ),
                        const _StatDivider(),
                        Expanded(
                          child: _StatItem(
                            icon: Icons.route_rounded,
                            label: 'Route',
                            value: _route != null ? _route!.name : 'None',
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Bus info section
                  _profileSectionLabel('ASSIGNED BUS'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: const Border(
                        left: BorderSide(color: AppColors.primary, width: 4),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0A000000),
                          blurRadius: 12,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                _route != null ? _route!.name : 'No Route',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                            const Spacer(),
                            const Icon(
                              Icons.directions_bus_filled_rounded,
                              color: AppColors.secondary,
                              size: 26,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _route != null
                              ? '${_route!.startPoint} ➔ ${_route!.endPoint}'
                              : 'Route details unassigned',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Divider(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: _SmallProfileText(
                                label: 'Bus Number',
                                value: _bus != null
                                    ? _bus!.busNumber
                                    : 'Unassigned',
                              ),
                            ),
                            Expanded(
                              child: _SmallProfileText(
                                label: 'Plate Number',
                                value: _bus != null
                                    ? _bus!.plateNumber
                                    : 'Unassigned',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),



                  // Account details
                  _profileSectionLabel('ACCOUNT DETAILS'),
                  const SizedBox(height: 8),
                  _ProMenuCard(
                    children: [
                      _ProMenuTile(
                        icon: Icons.email_rounded,
                        title: 'Email',
                        value: _user!.email,
                        color: AppColors.primary,
                      ),
                      const Divider(height: 1, indent: 58),
                      _ProMenuTile(
                        icon: Icons.phone_rounded,
                        title: 'Phone',
                        value: _user!.phone.isNotEmpty
                            ? _user!.phone
                            : 'Not set',
                        color: AppColors.success,
                      ),
                      const Divider(height: 1, indent: 58),
                      _ProMenuTile(
                        icon: Icons.badge_rounded,
                        title: 'Student ID',
                        value: _user!.uid.substring(0, 8).toUpperCase(),
                        color: const Color(0xFF7B2FBE),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Settings
                  _profileSectionLabel('SETTINGS & PREFERENCES'),
                  const SizedBox(height: 8),
                  _ProMenuCard(
                    children: [
                      _ProMenuTile(
                        icon: Icons.edit_rounded,
                        title: 'Edit Profile',
                        subtitle: 'Update name, phone, pickup location',
                        color: AppColors.warning,
                        tappable: true,
                        onTap: () =>
                            Navigator.pushNamed(
                              context,
                              AppRoutes.editProfile,
                            ).then((_) {
                              _loadProfileData(forceFetch: true);
                              if (widget.onProfileUpdated != null) {
                                widget.onProfileUpdated!();
                              }
                            }),
                      ),
                      const Divider(height: 1, indent: 58),
                      _ProMenuTile(
                        icon: Icons.notifications_rounded,
                        title: 'Notification Settings',
                        subtitle: 'Manage bus & arrival alerts',
                        color: AppColors.primary,
                        tappable: true,
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes.notificationSettings,
                        ),
                      ),
                      const Divider(height: 1, indent: 58),
                      _ProMenuTile(
                        icon: Icons.settings_rounded,
                        title: 'App Settings',
                        subtitle: 'Theme, language, map preferences',
                        color: const Color(0xFF3949AB),
                        tappable: true,
                        onTap: () =>
                            Navigator.pushNamed(context, AppRoutes.appSettings),
                      ),
                      const Divider(height: 1, indent: 58),
                      _ProMenuTile(
                        icon: Icons.help_rounded,
                        title: 'Help & Support',
                        subtitle: 'FAQs, contact & legal info',
                        color: AppColors.info,
                        tappable: true,
                        onTap: () =>
                            Navigator.pushNamed(context, AppRoutes.helpSupport),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Logout
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: () => _handleLogout(context),
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text(
                        'Logout',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: BorderSide(
                          color: AppColors.danger.withValues(alpha: .4),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }



  void _showStudentQrZoomDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .25),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: AppColors.primaryLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.qr_code_2_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _user!.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Student Link QR Code',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(height: 24),
                const Text(
                  'Scan this QR code from your parent\'s "My Children" tab to instantly link your profiles.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.grey.shade100, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .04),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: 200,
                    height: 200,
                    child: QrImageView(
                      data: _user!.email,
                      version: QrVersions.auto,
                      size: 200.0,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F6F8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _user!.email,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _profileSectionLabel(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _ProfileListTile extends StatelessWidget {
  const _ProfileListTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    this.onTap,
    this.showTrailing = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final VoidCallback? onTap;
  final bool showTrailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (showTrailing)
                Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillBadge extends StatelessWidget {
  const _PillBadge({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 48, color: const Color(0xFFE5E7EB));
  }
}

class _ProMenuCard extends StatelessWidget {
  const _ProMenuCard({required this.children});
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

class _ProMenuTile extends StatelessWidget {
  const _ProMenuTile({
    required this.icon,
    required this.title,
    required this.color,
    this.subtitle,
    this.value,
    this.tappable = false,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? value;
  final Color color;
  final bool tappable;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  if (value != null)
                    Text(
                      value!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                ],
              ),
            ),
            if (tappable)
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

class _SmallProfileText extends StatelessWidget {
  const _SmallProfileText({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
