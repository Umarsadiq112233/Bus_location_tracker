import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../core/widgets/app_screen.dart';
import '../../core/services/school_service.dart';
import '../../core/providers/admin_provider.dart';
import '../../core/utils/snackbar_utils.dart';
import '../../app/theme/app_colors.dart';

class AddEditSchoolScreen extends StatefulWidget {
  const AddEditSchoolScreen({super.key});

  @override
  State<AddEditSchoolScreen> createState() => _AddEditSchoolScreenState();
}

class _AddEditSchoolScreenState extends State<AddEditSchoolScreen> {
  final _formKey = GlobalKey<FormState>();
  final _schoolService = SchoolService();

  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  // SchoolAdmin creation fields
  final _adminNameCtrl = TextEditingController();
  final _adminEmailCtrl = TextEditingController();
  final _adminPhoneCtrl = TextEditingController();
  final _adminPasswordCtrl = TextEditingController();

  String _status = 'active';
  String? _schoolId;
  bool _isInit = false;
  bool _submitting = false;
  bool _creatingAdmin = false;

  // Bus assignment
  List<String> _selectedBusIds = [];
  List<Map<String, dynamic>> _allBuses = [];
  bool _loadingBuses = true;

  // Existing school admin info
  Map<String, dynamic>? _existingSchoolAdmin;
  bool _loadingAdmin = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        _schoolId = args['id'];
        _nameCtrl.text = args['name'] ?? '';
        _addressCtrl.text = args['address'] ?? '';
        _phoneCtrl.text = args['phone'] ?? '';
        _emailCtrl.text = args['email'] ?? '';
        _status = args['status'] ?? 'active';
        _selectedBusIds =
            List<String>.from(args['assignedBusIds'] as List<dynamic>? ?? []);

        // Load existing school admin
        if (_schoolId != null) {
          _loadExistingAdmin();
        }
      }
      _isInit = true;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadBuses();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _adminNameCtrl.dispose();
    _adminEmailCtrl.dispose();
    _adminPhoneCtrl.dispose();
    _adminPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBuses() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('buses').get();
      if (mounted) {
        setState(() {
          _allBuses = snapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();
          _loadingBuses = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingBuses = false);
    }
  }

  Future<void> _loadExistingAdmin() async {
    if (_schoolId == null) return;
    setState(() => _loadingAdmin = true);
    try {
      final admin = await _schoolService.fetchSchoolAdmin(_schoolId!);
      if (mounted) {
        setState(() {
          _existingSchoolAdmin = admin;
          _loadingAdmin = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingAdmin = false);
    }
  }

  Future<void> _saveSchool() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    try {
      final savedId = await _schoolService.saveSchool(
        id: _schoolId,
        name: _nameCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        status: _status,
        assignedBusIds: _selectedBusIds,
      );

      if (!mounted) return;

      // If it was a new school, save the ID for potential admin creation
      _schoolId ??= savedId;

      SnackbarUtils.showCustomSnackbar(
        context,
        'School "${_nameCtrl.text}" saved successfully!',
        isError: false,
      );
      Navigator.maybePop(context);
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showCustomSnackbar(
            context, 'Failed to save school: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _createSchoolAdmin() async {
    final adminName = _adminNameCtrl.text.trim();
    final adminEmail = _adminEmailCtrl.text.trim();
    final adminPhone = _adminPhoneCtrl.text.trim();
    final adminPassword = _adminPasswordCtrl.text.trim();

    if (adminName.isEmpty ||
        adminEmail.isEmpty ||
        adminPassword.isEmpty ||
        adminPhone.isEmpty) {
      SnackbarUtils.showCustomSnackbar(
        context,
        'Please fill all SchoolAdmin fields',
        isError: true,
      );
      return;
    }

    if (adminPassword.length < 6) {
      SnackbarUtils.showCustomSnackbar(
        context,
        'Password must be at least 6 characters',
        isError: true,
      );
      return;
    }

    // First save the school if not saved yet
    if (_schoolId == null) {
      if (!_formKey.currentState!.validate()) return;
      try {
        _schoolId = await _schoolService.saveSchool(
          name: _nameCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          status: _status,
          assignedBusIds: _selectedBusIds,
        );
      } catch (e) {
        if (mounted) {
          SnackbarUtils.showCustomSnackbar(
              context, 'Failed to save school first: $e', isError: true);
        }
        return;
      }
    }

    setState(() => _creatingAdmin = true);

    try {
      final provider = context.read<AdminProvider>();
      final proAdminEmail = provider.proAdminEmail;
      final proAdminPassword = provider.proAdminPassword;

      // Step 1: Create the new SchoolAdmin Firebase Auth account
      final newUserCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: adminEmail,
        password: adminPassword,
      );

      final newUid = newUserCredential.user!.uid;

      // Step 2: Create Firestore user doc for SchoolAdmin
      await _schoolService.createSchoolAdminDoc(
        uid: newUid,
        name: adminName,
        email: adminEmail,
        phone: adminPhone,
        schoolId: _schoolId!,
      );

      // Step 3: Re-auth back to ProAdmin
      if (proAdminEmail != null && proAdminPassword != null) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: proAdminEmail,
          password: proAdminPassword,
        );
      }

      if (!mounted) return;

      // Reload existing admin info
      await _loadExistingAdmin();

      // Clear the form fields
      _adminNameCtrl.clear();
      _adminEmailCtrl.clear();
      _adminPhoneCtrl.clear();
      _adminPasswordCtrl.clear();

      SnackbarUtils.showCustomSnackbar(
        context,
        'SchoolAdmin "$adminName" created successfully!',
        isError: false,
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String msg = 'Failed to create SchoolAdmin';
        if (e.code == 'email-already-in-use') {
          msg = 'This email is already registered';
        } else if (e.code == 'weak-password') {
          msg = 'Password is too weak';
        } else if (e.code == 'invalid-email') {
          msg = 'Invalid email address';
        }
        SnackbarUtils.showCustomSnackbar(context, msg, isError: true);

        // Re-auth back to ProAdmin even on failure
        final provider = context.read<AdminProvider>();
        if (provider.proAdminEmail != null &&
            provider.proAdminPassword != null) {
          try {
            await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: provider.proAdminEmail!,
              password: provider.proAdminPassword!,
            );
          } catch (_) {}
        }
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showCustomSnackbar(
            context, 'Error creating SchoolAdmin: $e', isError: true);

        // Re-auth back to ProAdmin even on failure
        final provider = context.read<AdminProvider>();
        if (provider.proAdminEmail != null &&
            provider.proAdminPassword != null) {
          try {
            await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: provider.proAdminEmail!,
              password: provider.proAdminPassword!,
            );
          } catch (_) {}
        }
      }
    } finally {
      if (mounted) setState(() => _creatingAdmin = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isEdit = _schoolId != null;

    return AppScreen(
      title: isEdit ? 'Edit School' : 'Register New School',
      subtitle: isEdit
          ? 'Update school details, assign buses, and manage admin account.'
          : 'Add a new school to the system and assign buses.',
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
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
                        colors: [
                          const Color(0xFF00897B),
                          scheme.primary,
                        ],
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
                        const Icon(Icons.school_rounded,
                            color: Colors.white, size: 40),
                        const SizedBox(height: 12),
                        Text(
                          isEdit ? 'School Details' : 'School Information',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isEdit
                              ? 'Update the details for this school.'
                              : 'Fill out the details below to register a new school.',
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
                          _FormLabel(
                              label: 'School Name',
                              icon: Icons.business_rounded),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _nameCtrl,
                            decoration: _inputDecoration(scheme,
                                hint: 'e.g. City Grammar School'),
                            validator: (val) =>
                                val == null || val.isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 24),

                          _FormLabel(
                              label: 'Address',
                              icon: Icons.location_on_rounded),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _addressCtrl,
                            decoration: _inputDecoration(scheme,
                                hint: 'e.g. 123 Main St, Karachi'),
                            validator: (val) =>
                                val == null || val.isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 24),

                          _FormLabel(
                              label: 'Phone', icon: Icons.phone_rounded),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: _inputDecoration(scheme,
                                hint: 'e.g. +92 300 1234567'),
                            validator: (val) =>
                                val == null || val.isEmpty ? 'Required' : null,
                          ),
                          const SizedBox(height: 24),

                          _FormLabel(
                              label: 'Email', icon: Icons.email_rounded),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: _inputDecoration(scheme,
                                hint: 'e.g. info@school.edu'),
                            validator: (val) {
                              if (val == null || val.isEmpty) {
                                return 'Required';
                              }
                              if (!val.contains('@')) {
                                return 'Enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          // Status Dropdown
                          _FormLabel(
                              label: 'Status', icon: Icons.toggle_on_rounded),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _status,
                            decoration: _inputDecoration(scheme, hint: ''),
                            items: const [
                              DropdownMenuItem(
                                  value: 'active',
                                  child: Text('Active')),
                              DropdownMenuItem(
                                  value: 'inactive',
                                  child: Text('Inactive')),
                            ],
                            onChanged: (val) =>
                                setState(() => _status = val ?? 'active'),
                          ),
                          const SizedBox(height: 24),

                          // Bus Assignment Section
                          _FormLabel(
                              label: 'Assign Buses',
                              icon: Icons.directions_bus_rounded),
                          const SizedBox(height: 8),
                          if (_loadingBuses)
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                  child: CircularProgressIndicator()),
                            )
                          else
                            _buildBusSelector(scheme),
                          const SizedBox(height: 32),

                          // Save Button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: FilledButton.icon(
                              onPressed: _submitting ? null : _saveSchool,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF00897B),
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
                                          strokeWidth: 3),
                                    )
                                  : const Icon(Icons.check_circle_rounded,
                                      size: 24),
                              label: Text(
                                _submitting
                                    ? 'Saving...'
                                    : (isEdit
                                        ? 'Update School'
                                        : 'Register School'),
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

                  const SizedBox(height: 32),

                  // SchoolAdmin Section
                  _buildSchoolAdminSection(scheme),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBusSelector(ColorScheme scheme) {
    if (_allBuses.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: const Text(
          'No buses available. Add buses first from the Buses section.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              '${_selectedBusIds.length} bus${_selectedBusIds.length == 1 ? '' : 'es'} selected',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
          ),
          const Divider(height: 1),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 250),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _allBuses.length,
              itemBuilder: (context, index) {
                final bus = _allBuses[index];
                final busId = bus['id'] as String;
                final busNumber = bus['busNumber'] ?? 'Unknown';
                final plateNumber = bus['plateNumber'] ?? '';
                final isSelected = _selectedBusIds.contains(busId);

                return CheckboxListTile(
                  value: isSelected,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedBusIds.add(busId);
                      } else {
                        _selectedBusIds.remove(busId);
                      }
                    });
                  },
                  title: Text(
                    busNumber,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  subtitle: Text(plateNumber,
                      style: const TextStyle(fontSize: 12)),
                  dense: true,
                  activeColor: scheme.primary,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchoolAdminSection(ColorScheme scheme) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF512DA8),
                  AppColors.admin.primary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.admin_panel_settings_rounded,
                    color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'School Admin Account',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Each school gets exactly 1 admin account',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Show existing admin info
                if (_loadingAdmin)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_existingSchoolAdmin != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color:
                            const Color(0xFF4CAF50).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: Color(0xFF4CAF50), size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Admin Account Active',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_existingSchoolAdmin!['name']} · ${_existingSchoolAdmin!['email']}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'This school already has an admin account. Each school can only have one.',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ] else ...[
                  // Create new admin form
                  if (_schoolId == null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline_rounded,
                              color: Colors.orange, size: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Save the school first, then you can create the admin account.',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    _FormLabel(
                        label: 'Admin Full Name',
                        icon: Icons.person_rounded),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _adminNameCtrl,
                      decoration:
                          _inputDecoration(scheme, hint: 'e.g. Ahmed Khan'),
                    ),
                    const SizedBox(height: 16),

                    _FormLabel(
                        label: 'Admin Email',
                        icon: Icons.email_rounded),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _adminEmailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _inputDecoration(scheme,
                          hint: 'e.g. admin@school.edu'),
                    ),
                    const SizedBox(height: 16),

                    _FormLabel(
                        label: 'Admin Phone',
                        icon: Icons.phone_rounded),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _adminPhoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: _inputDecoration(scheme,
                          hint: 'e.g. +92 300 1234567'),
                    ),
                    const SizedBox(height: 16),

                    _FormLabel(
                        label: 'Admin Password',
                        icon: Icons.lock_rounded),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _adminPasswordCtrl,
                      obscureText: true,
                      decoration: _inputDecoration(scheme,
                          hint: 'Min 6 characters'),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed:
                            _creatingAdmin ? null : _createSchoolAdmin,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF512DA8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: _creatingAdmin
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(
                                Icons.person_add_rounded, size: 20),
                        label: Text(
                          _creatingAdmin
                              ? 'Creating Admin...'
                              : 'Create School Admin',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(ColorScheme scheme,
      {required String hint}) {
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
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
