import '../../core/widgets/app_screen.dart';
import '../../core/services/assignment_service.dart';
import '../../core/models/bus_model.dart';
import '../../core/models/user_model.dart';
import '../../core/models/route_model.dart';
import '../../core/utils/snackbar_utils.dart';
import '../../app/theme/app_colors.dart';
import 'package:flutter/material.dart';

class AssignBusScreen extends StatefulWidget {
  const AssignBusScreen({super.key});

  @override
  State<AssignBusScreen> createState() => _AssignBusScreenState();
}

class _AssignBusScreenState extends State<AssignBusScreen> {
  final AssignmentService _assignmentService = AssignmentService();

  List<BusModel> _buses = [];
  List<UserModel> _drivers = [];
  List<RouteModel> _routes = [];

  String? _selectedBusId;
  String? _selectedDriverId;
  String? _selectedRouteId;

  bool _loadingData = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final buses = await _assignmentService.fetchBuses();
      final drivers = await _assignmentService.fetchDrivers();
      final routes = await _assignmentService.fetchRoutes();

      if (mounted) {
        setState(() {
          _buses = buses;
          _drivers = drivers;
          _routes = routes;
          _loadingData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingData = false);
        SnackbarUtils.showCustomSnackbar(
          context,
          'Error loading data: ${e.toString()}',
          isError: true,
        );
      }
    }
  }

  Future<void> _submitAssignment() async {
    if (_selectedBusId == null || _selectedDriverId == null || _selectedRouteId == null) {
      SnackbarUtils.showCustomSnackbar(
        context,
        'Please complete all selections to assign the bus.',
        isError: true,
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await _assignmentService.assignBus(
        busId: _selectedBusId!,
        driverId: _selectedDriverId!,
        routeId: _selectedRouteId!,
      );

      final selectedBus = _buses.firstWhere((b) => b.id == _selectedBusId);
      final selectedDriver = _drivers.firstWhere((d) => d.uid == _selectedDriverId);

      if (!mounted) return;
      SnackbarUtils.showCustomSnackbar(
        context,
        'Assignment Successful: Bus ${selectedBus.busNumber} linked to ${selectedDriver.name}!',
        isError: false,
      );
      
      Navigator.maybePop(context);
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showCustomSnackbar(
          context,
          'Failed to assign: ${e.toString()}',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _buildSummaryCard(ColorScheme scheme) {
    if (_selectedBusId == null && _selectedDriverId == null && _selectedRouteId == null) {
      return const SizedBox.shrink();
    }

    final selectedBus = _selectedBusId != null ? _buses.firstWhere((b) => b.id == _selectedBusId) : null;
    final selectedDriver = _selectedDriverId != null ? _drivers.firstWhere((d) => d.uid == _selectedDriverId) : null;
    final selectedRoute = _selectedRouteId != null ? _routes.firstWhere((r) => r.id == _selectedRouteId) : null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: scheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Assignment Preview',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: scheme.primary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (selectedDriver != null && selectedBus != null && selectedRoute != null)
            Text.rich(
              TextSpan(
                style: TextStyle(color: scheme.onSurface, fontSize: 15, height: 1.5),
                children: [
                  TextSpan(text: selectedDriver.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const TextSpan(text: ' will be driving '),
                  TextSpan(text: '${selectedBus.busNumber} (${selectedBus.plateNumber})', style: const TextStyle(fontWeight: FontWeight.w900)),
                  const TextSpan(text: ' on the '),
                  TextSpan(text: selectedRoute.name, style: const TextStyle(fontWeight: FontWeight.w900)),
                  const TextSpan(text: ' route.'),
                ],
              ),
            )
          else
            Text(
              'Complete the form above to see the final assignment preview.',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: scheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_loadingData) {
      return const AppScreen(
        title: 'Assign Bus',
        subtitle: 'Map a bus to a driver and route for active tracking.',
        children: [
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: CircularProgressIndicator(),
            ),
          ),
        ],
      );
    }

    return AppScreen(
      title: 'Link Fleet Resources',
      subtitle: 'Assign buses to drivers and set their active routes.',
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              children: [
                // Header Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [scheme.primary, scheme.tertiary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.assignment_turned_in_rounded, color: Colors.white, size: 40),
                      const SizedBox(height: 12),
                      const Text(
                        'New Assignment',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'This will instantly activate live tracking for this route.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                // Form Card
                Card(
                  margin: EdgeInsets.zero,
                  elevation: 8,
                  shadowColor: scheme.shadow.withValues(alpha: 0.1),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Bus selection
                        const _FormLabel(label: 'Select Vehicle (Bus)', icon: Icons.directions_bus_rounded),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedBusId,
                          hint: const Text('Choose a bus'),
                          decoration: _inputDecoration(scheme),
                          items: _buses.map((bus) {
                            return DropdownMenuItem<String>(
                              value: bus.id,
                              child: Text('${bus.busNumber} (${bus.plateNumber})'),
                            );
                          }).toList(),
                          onChanged: (value) => setState(() => _selectedBusId = value),
                        ),
                        const SizedBox(height: 24),

                        // Driver selection
                        const _FormLabel(label: 'Select Driver', icon: Icons.badge_rounded),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedDriverId,
                          hint: const Text('Assign a verified driver'),
                          decoration: _inputDecoration(scheme),
                          items: _drivers.map((driver) {
                            return DropdownMenuItem<String>(
                              value: driver.uid,
                              child: Text('${driver.name} (${driver.email})'),
                            );
                          }).toList(),
                          onChanged: (value) => setState(() => _selectedDriverId = value),
                        ),
                        const SizedBox(height: 24),

                        // Route selection
                        const _FormLabel(label: 'Select Route', icon: Icons.alt_route_rounded),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedRouteId,
                          hint: const Text('Assign transit path'),
                          decoration: _inputDecoration(scheme),
                          items: _routes.map((route) {
                            return DropdownMenuItem<String>(
                              value: route.id,
                              child: Text('${route.name} (${route.startPoint} - ${route.endPoint})'),
                            );
                          }).toList(),
                          onChanged: (value) => setState(() => _selectedRouteId = value),
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // Dynamic Summary Preview
                        _buildSummaryCard(scheme),
                        
                        const SizedBox(height: 32),

                        // Action button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: FilledButton.icon(
                            onPressed: _submitting ? null : _submitAssignment,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.admin.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            icon: _submitting
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 3,
                                    ),
                                  )
                                : const Icon(Icons.check_circle_rounded, size: 24),
                            label: Text(
                              _submitting ? 'Processing Assignment...' : 'Confirm Assignment',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(ColorScheme scheme) {
    return InputDecoration(
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outlineVariant, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outlineVariant, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    );
  }
}

class _FormLabel extends StatelessWidget {
  const _FormLabel({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: scheme.primary),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: scheme.onSurface,
          ),
        ),
      ],
    );
  }
}
