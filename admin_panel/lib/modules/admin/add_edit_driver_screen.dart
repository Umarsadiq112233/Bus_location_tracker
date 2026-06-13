import '../../core/widgets/app_screen.dart';
import '../../core/services/driver_service.dart';
import '../../core/services/assignment_service.dart';
import '../../core/models/bus_model.dart';
import '../../core/utils/snackbar_utils.dart';
import '../../app/theme/app_colors.dart';
import 'package:flutter/material.dart';

class AddEditDriverScreen extends StatefulWidget {
  const AddEditDriverScreen({super.key});

  @override
  State<AddEditDriverScreen> createState() => _AddEditDriverScreenState();
}

class _AddEditDriverScreenState extends State<AddEditDriverScreen> {
  final _formKey = GlobalKey<FormState>();
  final _driverService = DriverService();
  final _assignmentService = AssignmentService();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _licenseCtrl = TextEditingController();
  final _experienceCtrl = TextEditingController();

  String _status = 'active';
  String? _selectedBusId;
  String? _driverId;
  bool _isInit = false;

  List<BusModel> _buses = [];
  bool _loadingData = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        _driverId = args['id'];
        _nameCtrl.text = args['name'] ?? '';
        _emailCtrl.text = args['email'] ?? '';
        _phoneCtrl.text = args['phone'] ?? '';
        _licenseCtrl.text = args['licenseNumber'] ?? '';
        
        final exp = args['experienceYears'];
        if (exp != null) _experienceCtrl.text = exp.toString();
        
        final status = args['status'];
        if (status != null && status.toString().isNotEmpty) _status = status;
        
        final busId = args['assignedBusId'];
        if (busId != null && busId.toString().isNotEmpty) _selectedBusId = busId;
      }
      _isInit = true;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _licenseCtrl.dispose();
    _experienceCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final buses = await _assignmentService.fetchBuses();

      if (mounted) {
        setState(() {
          _buses = buses;
          
          if (_selectedBusId != null && _selectedBusId!.isNotEmpty) {
            final exists = _buses.any((bus) => bus.id == _selectedBusId);
            if (!exists) {
              _selectedBusId = null;
            }
          }
          
          _loadingData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingData = false);
        SnackbarUtils.showCustomSnackbar(context, 'Failed to fetch buses: $e', isError: true);
      }
    }
  }

  Future<void> _saveDriver() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    try {
      await _driverService.saveDriver(
        id: _driverId,
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        licenseNumber: _licenseCtrl.text.trim(),
        experienceYears: int.tryParse(_experienceCtrl.text.trim()) ?? 0,
        status: _status,
        assignedBusId: _selectedBusId,
      );

      if (!mounted) return;
      SnackbarUtils.showCustomSnackbar(
        context,
        'Success! ${_nameCtrl.text} has been registered successfully.',
        isError: false,
      );
      Navigator.maybePop(context);
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showCustomSnackbar(context, 'Failed to save driver: $e', isError: true);
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
        title: 'Add / Edit Driver',
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

    return AppScreen(
      title: _driverId != null ? 'Edit Driver' : 'Register New Driver',
      subtitle: _driverId != null ? 'Update driver details and assignments.' : 'Add driver details, verify license, and assign a bus.',
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
                        const Icon(Icons.badge_rounded, color: Colors.white, size: 40),
                        const SizedBox(height: 12),
                        const Text(
                          'Driver Registration',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _driverId != null 
                              ? 'Update the details for this driver below.' 
                              : 'Fill out the details below to add a new driver to your fleet.',
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
                          const _FormLabel(label: 'Full Name', icon: Icons.person_rounded),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _nameCtrl,
                            decoration: _inputDecoration(scheme, hint: 'e.g. Ahmed Raza'),
                            validator: (val) => val == null || val.isEmpty ? 'Required field' : null,
                          ),
                          const SizedBox(height: 24),

                          const _FormLabel(label: 'Email Address', icon: Icons.email_rounded),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: _inputDecoration(scheme, hint: 'e.g. driver@school.com'),
                            validator: (val) {
                              if (val == null || val.isEmpty) return 'Required field';
                              if (!val.contains('@')) return 'Enter a valid email address';
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          const _FormLabel(label: 'Phone Number', icon: Icons.phone_rounded),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: _inputDecoration(scheme, hint: 'e.g. 0300-1234567'),
                            validator: (val) => val == null || val.isEmpty ? 'Required field' : null,
                          ),
                          const SizedBox(height: 24),

                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const _FormLabel(label: 'License Number', icon: Icons.card_membership_rounded),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _licenseCtrl,
                                      decoration: _inputDecoration(scheme, hint: 'e.g. AB-12345'),
                                      validator: (val) => val == null || val.isEmpty ? 'Required field' : null,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const _FormLabel(label: 'Experience (Years)', icon: Icons.work_history_rounded),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _experienceCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: _inputDecoration(scheme, hint: 'e.g. 5'),
                                      validator: (val) {
                                        if (val == null || val.isEmpty) return 'Required field';
                                        if (int.tryParse(val) == null) return 'Must be a number';
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Dynamic Bus Dropdown
                          const _FormLabel(label: 'Assign Bus (Optional)', icon: Icons.directions_bus_rounded),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _selectedBusId,
                            hint: const Text('Select a bus...'),
                            decoration: _inputDecoration(scheme, hint: ''),
                            items: [
                              const DropdownMenuItem<String>(
                                value: '',
                                child: Text('No Bus / Unassigned'),
                              ),
                              ..._buses.map((bus) {
                                return DropdownMenuItem<String>(
                                  value: bus.id,
                                  child: Text('${bus.busNumber} (${bus.plateNumber})'),
                                );
                              }).toList()
                            ],
                            onChanged: (val) => setState(() => _selectedBusId = (val == '' ? null : val)),
                          ),
                          const SizedBox(height: 24),

                          // Status Dropdown
                          const _FormLabel(label: 'Initial Status', icon: Icons.toggle_on_rounded),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _status,
                            decoration: _inputDecoration(scheme, hint: ''),
                            items: const [
                              DropdownMenuItem(value: 'active', child: Text('Active / Working')),
                              DropdownMenuItem(value: 'on_leave', child: Text('On Leave')),
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
                              onPressed: _submitting ? null : _saveDriver,
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
                                _submitting ? 'Saving Driver...' : 'Save Driver',
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
