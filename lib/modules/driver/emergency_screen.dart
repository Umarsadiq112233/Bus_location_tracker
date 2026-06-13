import 'package:bus_location_tracker/app/theme/app_colors.dart';
import 'package:bus_location_tracker/core/constants/firebase_paths.dart';
import 'package:bus_location_tracker/core/models/bus_model.dart';
import 'package:bus_location_tracker/core/models/user_model.dart';
import 'package:bus_location_tracker/core/services/auth_service.dart';
import 'package:bus_location_tracker/core/services/location_service.dart';
import 'package:bus_location_tracker/core/utils/snackbar_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class EmergencyScreen extends StatefulWidget {
  final UserModel? driver;
  final BusModel? bus;

  const EmergencyScreen({
    super.key,
    this.driver,
    this.bus,
  });

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class EmergencyTypeItem {
  final String label;
  final IconData icon;
  final Color activeColor;

  const EmergencyTypeItem({
    required this.label,
    required this.icon,
    required this.activeColor,
  });
}

const List<EmergencyTypeItem> _emergencyTypes = [
  EmergencyTypeItem(
    label: 'Accident',
    icon: Icons.car_crash_rounded,
    activeColor: AppColors.danger,
  ),
  EmergencyTypeItem(
    label: 'Breakdown',
    icon: Icons.build_rounded,
    activeColor: Color(0xFFE65100),
  ),
  EmergencyTypeItem(
    label: 'Medical',
    icon: Icons.local_hospital_rounded,
    activeColor: Color(0xFF00796B),
  ),
  EmergencyTypeItem(
    label: 'Traffic Delay',
    icon: Icons.traffic_rounded,
    activeColor: Color(0xFFF57C00),
  ),
  EmergencyTypeItem(
    label: 'Other',
    icon: Icons.warning_rounded,
    activeColor: Color(0xFF616161),
  ),
];

class _EmergencyScreenState extends State<EmergencyScreen> {
  final _messageController = TextEditingController();
  String _selectedType = 'Accident';
  bool _isSending = false;

  UserModel? _driver;
  BusModel? _bus;
  bool _isLoadingDriver = false;
  bool _didInit = false;

  Position? _currentPosition;
  LocationAddress? _currentAddress;
  bool _isFetchingLocation = false;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInit) {
      _initDriverAndBus();
      _didInit = true;
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _initDriverAndBus() async {
    if (widget.driver != null) {
      setState(() {
        _driver = widget.driver;
        _bus = widget.bus;
      });
      return;
    }

    // Try fetching from route arguments
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      setState(() {
        _driver = args['driver'] as UserModel?;
        _bus = args['bus'] as BusModel?;
      });
    } else if (args is UserModel) {
      setState(() {
        _driver = args;
      });
    }

    if (_driver != null) return;

    // Fallback: query from AuthService
    if (mounted) {
      setState(() {
        _isLoadingDriver = true;
      });
    }

    try {
      final auth = AuthService();
      final currentUser = auth.currentUser;
      if (currentUser != null) {
        final driverData = await auth.getUserData(currentUser.uid);
        if (driverData != null) {
          BusModel? assignedBus;
          if (driverData.assignedBusId != null && driverData.assignedBusId!.isNotEmpty) {
            assignedBus = await auth.fetchAssignedBus(driverData.assignedBusId!);
          }
          if (mounted) {
            setState(() {
              _driver = driverData;
              _bus = assignedBus;
            });
          }
        }
      }
    } catch (_) {
      // Fail silently
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingDriver = false;
        });
      }
    }
  }

  Future<void> _fetchLocation() async {
    if (!mounted) return;
    setState(() {
      _isFetchingLocation = true;
      _locationError = null;
    });
    try {
      const locService = LocationService();
      final hasPermission = await locService.requestPermission();
      if (!hasPermission) {
        if (mounted) {
          setState(() {
            _locationError = 'Location permissions denied.';
            _isFetchingLocation = false;
          });
        }
        return;
      }
      final pos = await locService.currentPosition();
      if (pos != null) {
        if (mounted) {
          setState(() {
            _currentPosition = pos;
          });
        }
        // Fetch reverse geocoding address
        final address = await locService.reverseGeocode(pos);
        if (mounted) {
          setState(() {
            _currentAddress = address;
            _isFetchingLocation = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _locationError = 'Could not retrieve GPS coordinates.';
            _isFetchingLocation = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationError = 'Error: ${e.toString()}';
          _isFetchingLocation = false;
        });
      }
    }
  }

  Future<void> _sendSOSAlert() async {
    if (_isSending || _driver == null) return;
    setState(() {
      _isSending = true;
    });

    try {
      final docRef = FirebaseFirestore.instance
          .collection(FirebasePaths.emergencyAlerts)
          .doc();

      final data = {
        'id': docRef.id,
        'driverId': _driver!.uid,
        'driverName': _driver!.name,
        'driverPhone': _driver!.phone,
        'busId': _bus?.id ?? _driver!.assignedBusId ?? '',
        'busNumber': _bus?.busNumber ?? 'Unknown',
        'type': _selectedType,
        'message': _messageController.text.trim(),
        'latitude': _currentPosition?.latitude,
        'longitude': _currentPosition?.longitude,
        'address': _currentAddress?.displayName ?? '',
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      };

      await docRef.set(data);

      if (mounted) {
        SnackbarUtils.showCustomSnackbar(
          context,
          'SOS Alert successfully transmitted!',
          isError: false,
        );
        _messageController.clear();
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showCustomSnackbar(
          context,
          'Failed to send SOS: ${e.toString()}',
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _resolveAlert(String alertId) async {
    try {
      await FirebaseFirestore.instance
          .collection(FirebasePaths.emergencyAlerts)
          .doc(alertId)
          .update({'status': 'resolved'});

      if (mounted) {
        SnackbarUtils.showCustomSnackbar(
          context,
          'SOS Alert marked as resolved.',
          isError: false,
        );
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showCustomSnackbar(
          context,
          'Failed to resolve alert: ${e.toString()}',
          isError: true,
        );
      }
    }
  }

  String _formatDateTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year;
    return '$day/$month/$year $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (_driver == null && _isLoadingDriver) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text(
            'Emergency Alert Center',
            style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF111827)),
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: const Color(0xFFF8FAFC),
          automaticallyImplyLeading: true,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Emergency Alert Center',
          style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF111827)),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFFF8FAFC),
        automaticallyImplyLeading: true,
      ),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ARM status header card
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: SliverToBoxAdapter(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD32F2F), Color(0xFFC62828)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.security_rounded, color: Colors.white, size: 28),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'EMERGENCY CHANNEL ACTIVE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Triggering the SOS button will broadcast real-time location alerts directly to administrators & parent dashboards.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Pulsing SOS trigger section
            SliverPadding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PulsingSOSButton(
                        onTap: _sendSOSAlert,
                        isLoading: _isSending,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _isSending ? 'Transmitting Distress Signal...' : 'Press and hold to send SOS Alert',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _isSending ? AppColors.danger : AppColors.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Category select section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Text(
                  'SELECT EMERGENCY TYPE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurfaceVariant,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: SizedBox(
                height: 84,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _emergencyTypes.length,
                  itemBuilder: (context, index) {
                    final type = _emergencyTypes[index];
                    final isSelected = _selectedType == type.label;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedType = type.label;
                        });
                      },
                      child: Container(
                        width: 114,
                        margin: EdgeInsets.only(
                          left: index == 0 ? 16 : 8,
                          right: index == _emergencyTypes.length - 1 ? 16 : 0,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? type.activeColor.withValues(alpha: 0.12)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? type.activeColor : AppColors.outline,
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x04000000),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              type.icon,
                              color: isSelected ? type.activeColor : AppColors.textMuted,
                              size: 26,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              type.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? type.activeColor : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Message / description details field
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SITUATION DETAILS (OPTIONAL)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurfaceVariant,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x04000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _messageController,
                        maxLines: 3,
                        keyboardType: TextInputType.multiline,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Describe current status (e.g., flat tire, radiator issue, heavy gridlock)...',
                          hintStyle: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                          contentPadding: const EdgeInsets.all(16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AppColors.outline),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AppColors.outline),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // GPS location card
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.outline),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x04000000),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.my_location_rounded,
                                color: _currentPosition != null ? AppColors.success : AppColors.textMuted,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'GPS Dispatch Coordinates',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            onPressed: _isFetchingLocation ? null : _fetchLocation,
                            icon: _isFetchingLocation
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.refresh_rounded, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_isFetchingLocation) ...[
                        const ClipRRect(
                          borderRadius: BorderRadius.all(Radius.circular(2)),
                          child: LinearProgressIndicator(),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (_locationError != null)
                        Text(
                          _locationError!,
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      else if (_currentPosition != null) ...[
                        Row(
                          children: [
                            _buildCoordChip('LAT', _currentPosition!.latitude.toStringAsFixed(6)),
                            const SizedBox(width: 8),
                            _buildCoordChip('LNG', _currentPosition!.longitude.toStringAsFixed(6)),
                          ],
                        ),
                        if (_currentAddress != null) ...[
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.map_rounded, color: AppColors.textMuted, size: 14),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _currentAddress!.displayName,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ] else
                        const Text(
                          'Acquiring satellite coordinate lock...',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Recent alerts history list
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 28, 16, 8),
                child: Text(
                  'RECENT SOS HISTORY',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurfaceVariant,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              sliver: SliverToBoxAdapter(
                child: _driver == null
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection(FirebasePaths.emergencyAlerts)
                            .where('driverId', isEqualTo: _driver!.uid)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24.0),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }
                          if (snapshot.hasError) {
                            return Center(
                              child: Text(
                                'Error loading history: ${snapshot.error}',
                                style: const TextStyle(color: AppColors.danger, fontSize: 13),
                              ),
                            );
                          }

                          final docs = List.from(snapshot.data?.docs ?? []);
                          if (docs.isEmpty) {
                            return Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.outline),
                              ),
                              child: Column(
                                children: [
                                  Icon(Icons.history_rounded, size: 36, color: Colors.grey.shade300),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'No distress alerts transmitted recently',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          // Sort client-side to avoid Firestore composite index requirement
                          docs.sort((a, b) {
                            final aData = a.data() as Map<String, dynamic>;
                            final bData = b.data() as Map<String, dynamic>;
                            final aTime = (aData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                            final bTime = (bData['createdAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
                            return bTime.compareTo(aTime);
                          });

                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: docs.length,
                            itemBuilder: (context, index) {
                              final data = docs[index].data() as Map<String, dynamic>;
                              return _buildHistoryItem(data);
                            },
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoordChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.textMuted,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> alert) {
    final alertId = alert['id'] ?? '';
    final type = alert['type'] ?? 'Emergency';
    final message = alert['message'] ?? '';
    final status = alert['status'] ?? 'active';
    final lat = alert['latitude'];
    final lng = alert['longitude'];
    final address = alert['address'] ?? '';

    DateTime? createdAtDate;
    final createdAtVal = alert['createdAt'];
    if (createdAtVal is Timestamp) {
      createdAtDate = createdAtVal.toDate();
    }

    final isResolved = status == 'resolved';

    final typeItem = _emergencyTypes.firstWhere(
      (e) => e.label.toLowerCase() == type.toString().toLowerCase(),
      orElse: () => const EmergencyTypeItem(
        label: 'Emergency',
        icon: Icons.warning_rounded,
        activeColor: AppColors.danger,
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isResolved ? Colors.white : const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isResolved ? AppColors.outline : AppColors.danger.withValues(alpha: 0.3),
          width: isResolved ? 1 : 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isResolved
                        ? typeItem.activeColor.withValues(alpha: 0.1)
                        : AppColors.danger.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    typeItem.icon,
                    color: isResolved ? typeItem.activeColor : AppColors.danger,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: isResolved ? AppColors.textPrimary : AppColors.danger,
                        ),
                      ),
                      if (createdAtDate != null)
                        Text(
                          _formatDateTime(createdAtDate),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isResolved
                        ? AppColors.success.withValues(alpha: 0.12)
                        : AppColors.danger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isResolved ? AppColors.success : AppColors.danger,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isResolved ? 'Resolved' : 'Active',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: isResolved ? AppColors.success : AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            if (lat != null && lng != null) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_rounded, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      address.isNotEmpty
                          ? address
                          : 'Coordinates: ${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (!isResolved) ...[
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.outline),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _resolveAlert(alertId),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                  label: const Text(
                    'Mark as Resolved',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: AppColors.success, width: 1),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class PulsingSOSButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isLoading;

  const PulsingSOSButton({
    super.key,
    required this.onTap,
    required this.isLoading,
  });

  @override
  State<PulsingSOSButton> createState() => _PulsingSOSButtonState();
}

class _PulsingSOSButtonState extends State<PulsingSOSButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Pulse ripple 1
            if (!widget.isLoading)
              Container(
                width: 130 + (_pulseController.value * 60),
                height: 130 + (_pulseController.value * 60),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.withValues(alpha: 0.35 * (1 - _pulseController.value)),
                ),
              ),
            // Pulse ripple 2
            if (!widget.isLoading)
              Container(
                width: 130 + (((_pulseController.value + 0.5) % 1.0) * 60),
                height: 130 + (((_pulseController.value + 0.5) % 1.0) * 60),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.withValues(alpha: 0.2 * (1 - ((_pulseController.value + 0.5) % 1.0))),
                ),
              ),
            // Inner solid/glow button
            GestureDetector(
              onTap: widget.isLoading ? null : widget.onTap,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFD32F2F),
                      Color(0xFFFF5252),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.35),
                      blurRadius: 12,
                      spreadRadius: 1,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: widget.isLoading
                      ? const SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3.5,
                          ),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.bolt_rounded,
                              size: 36,
                              color: Colors.white,
                            ),
                            SizedBox(height: 2),
                            Text(
                              'SOS',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
