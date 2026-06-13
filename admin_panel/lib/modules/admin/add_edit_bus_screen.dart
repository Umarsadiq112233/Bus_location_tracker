import '../../core/widgets/app_screen.dart';
import '../../core/services/bus_service.dart';
import '../../core/services/assignment_service.dart';
import '../../core/models/user_model.dart';
import '../../core/models/route_model.dart';
import '../../core/utils/snackbar_utils.dart';
import '../../app/theme/app_colors.dart';
import 'package:flutter/material.dart';

class AddEditBusScreen extends StatefulWidget {
  const AddEditBusScreen({super.key});

  @override
  State<AddEditBusScreen> createState() => _AddEditBusScreenState();
}

class _AddEditBusScreenState extends State<AddEditBusScreen> {
  final _formKey = GlobalKey<FormState>();
  final _busService = BusService();
  final _assignmentService = AssignmentService();

  final _busNumberCtrl = TextEditingController();
  final _plateNumberCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController();

  String _status = 'active';
  String? _selectedDriverId;
  String? _selectedRouteId;
  String? _busId;
  bool _isInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        _busId = args['id'];
        final data = args['data'] as Map<String, dynamic>;
        _busNumberCtrl.text = data['busNumber'] ?? '';
        _plateNumberCtrl.text = data['plateNumber'] ?? '';
        _capacityCtrl.text = data['capacity']?.toString() ?? '40';
        _status = data['status'] ?? 'active';
        _selectedDriverId = data['assignedDriverId'];
        _selectedRouteId = data['assignedRouteId'];
      }
      _isInit = true;
    }
  }

  List<UserModel> _drivers = [];
  List<RouteModel> _routes = [];

  bool _loadingData = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _busNumberCtrl.dispose();
    _plateNumberCtrl.dispose();
    _capacityCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final drivers = await _assignmentService.fetchDrivers();
      final routes = await _assignmentService.fetchRoutes();

      if (mounted) {
        setState(() {
          _drivers = drivers;
          _routes = routes;
          
          if (_selectedDriverId != null && _selectedDriverId!.isNotEmpty) {
            final exists = _drivers.any((driver) => driver.uid == _selectedDriverId);
            if (!exists) {
              _selectedDriverId = null;
            }
          }
          
          if (_selectedRouteId != null && _selectedRouteId!.isNotEmpty) {
            final exists = _routes.any((route) => route.id == _selectedRouteId);
            if (!exists) {
              _selectedRouteId = null;
            }
          }
          
          _loadingData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingData = false);
        SnackbarUtils.showCustomSnackbar(context, 'Failed to fetch dropdown data: $e', isError: true);
      }
    }
  }

  Future<void> _saveBus() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    try {
      await _busService.saveBus(
        id: _busId,
        busNumber: _busNumberCtrl.text.trim(),
        plateNumber: _plateNumberCtrl.text.trim(),
        capacity: int.tryParse(_capacityCtrl.text.trim()) ?? 40,
        status: _status,
        driverId: _selectedDriverId,
        routeId: _selectedRouteId,
      );

      if (!mounted) return;
      SnackbarUtils.showCustomSnackbar(
        context,
        'Success! ${_busNumberCtrl.text} has been registered and setup.',
        isError: false,
      );
      Navigator.maybePop(context);
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showCustomSnackbar(context, 'Failed to save bus: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_loadingData) {
      return const AppScreen(
        title: 'Add / Edit Bus',
        subtitle: 'Loading required data...',
        children: [
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: CircularProgressIndicator(),
            ),
          )
        ],
      );
    }

    final isEdit = _busId != null;

    return AppScreen(
      title: isEdit ? 'Edit Bus details' : 'Register New Bus',
      subtitle: isEdit ? 'Update vehicle details or assignment.' : 'Add vehicle details and dynamically assign drivers and routes.',
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  // Header Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [scheme.primary, scheme.secondary],
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
                        const Icon(Icons.directions_bus_rounded, color: Colors.white, size: 40),
                        const SizedBox(height: 12),
                        const Text(
                          'Vehicle Information',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isEdit ? 'Update the details for this bus.' : 'Fill out the details below to add a new bus to the fleet.',
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
                          const _FormLabel(label: 'Bus Number', icon: Icons.confirmation_number_rounded),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _busNumberCtrl,
                            decoration: _inputDecoration(scheme, hint: 'e.g. BLT-10'),
                            validator: (val) => val == null || val.isEmpty ? 'Required field' : null,
                          ),
                          const SizedBox(height: 24),

                          const _FormLabel(label: 'Plate Number', icon: Icons.pin_rounded),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _plateNumberCtrl,
                            decoration: _inputDecoration(scheme, hint: 'e.g. KHI-1020'),
                            validator: (val) => val == null || val.isEmpty ? 'Required field' : null,
                          ),
                          const SizedBox(height: 24),

                          const _FormLabel(label: 'Seating Capacity', icon: Icons.event_seat_rounded),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _capacityCtrl,
                            keyboardType: TextInputType.number,
                            decoration: _inputDecoration(scheme, hint: 'e.g. 40'),
                            validator: (val) {
                              if (val == null || val.isEmpty) return 'Required field';
                              if (int.tryParse(val) == null) return 'Must be a valid number';
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          // Dynamic Driver Dropdown
                          const _FormLabel(label: 'Assign Driver (Optional)', icon: Icons.badge_rounded),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _selectedDriverId,
                            hint: const Text('Select a driver...'),
                            decoration: _inputDecoration(scheme, hint: ''),
                            items: [
                              const DropdownMenuItem<String>(
                                value: '',
                                child: Text('No Driver / Unassigned'),
                              ),
                              ..._drivers.map((driver) {
                                return DropdownMenuItem<String>(
                                  value: driver.uid,
                                  child: Text('${driver.name} (${driver.email})'),
                                );
                              }).toList()
                            ],
                            onChanged: (val) => setState(() => _selectedDriverId = (val == '' ? null : val)),
                          ),
                          const SizedBox(height: 24),

                          // Dynamic Route Dropdown
                          const _FormLabel(label: 'Assign Route (Optional)', icon: Icons.alt_route_rounded),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _selectedRouteId,
                            hint: const Text('Select a route...'),
                            decoration: _inputDecoration(scheme, hint: ''),
                            items: [
                              const DropdownMenuItem<String>(
                                value: '',
                                child: Text('No Route / Unassigned'),
                              ),
                              ..._routes.map((route) {
                                return DropdownMenuItem<String>(
                                  value: route.id,
                                  child: Text('${route.name} (${route.startPoint} - ${route.endPoint})'),
                                );
                              }).toList()
                            ],
                            onChanged: (val) => setState(() => _selectedRouteId = (val == '' ? null : val)),
                          ),
                          const SizedBox(height: 24),

                          // Status Dropdown
                          const _FormLabel(label: 'Initial Status', icon: Icons.toggle_on_rounded),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _status,
                            decoration: _inputDecoration(scheme, hint: ''),
                            items: const [
                              DropdownMenuItem(value: 'active', child: Text('Active / In Service')),
                              DropdownMenuItem(value: 'maintenance', child: Text('Under Maintenance')),
                              DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                            ],
                            onChanged: (val) => setState(() => _status = val ?? 'active'),
                          ),
                          const SizedBox(height: 32),

                          // Action button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: FilledButton.icon(
                              onPressed: _submitting ? null : _saveBus,
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
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                                    )
                                  : const Icon(Icons.check_circle_rounded, size: 24),
                              label: Text(
                                _submitting ? 'Saving Bus...' : 'Save Bus',
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
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(ColorScheme scheme, {required String hint}) {
    return InputDecoration(
      hintText: hint.isNotEmpty ? hint : null,
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
