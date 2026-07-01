import '../../core/widgets/app_screen.dart';
import '../../core/services/student_service.dart';
import '../../core/services/parent_service.dart';
import '../../core/services/assignment_service.dart';
import '../../core/services/school_service.dart';
import '../../core/models/user_model.dart';
import '../../core/models/bus_model.dart';
import '../../core/providers/admin_provider.dart';
import '../../core/utils/snackbar_utils.dart';
import '../../app/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AddEditStudentScreen extends StatefulWidget {
  const AddEditStudentScreen({super.key});

  @override
  State<AddEditStudentScreen> createState() => _AddEditStudentScreenState();
}

class _AddEditStudentScreenState extends State<AddEditStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _studentService = StudentService();
  final _parentService = ParentService();
  final _assignmentService = AssignmentService();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _gradeCtrl = TextEditingController();
  final _sectionCtrl = TextEditingController();

  String _status = 'active';
  String? _selectedBusId;
  String? _selectedParentUid;
  String? _studentId;
  String? _schoolId;
  bool _isInit = false;

  List<BusModel> _buses = [];
  List<UserModel> _parents = [];
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
        _studentId = args['id'];
        _nameCtrl.text = args['name'] ?? '';
        _emailCtrl.text = args['email'] ?? '';
        _phoneCtrl.text = args['phone'] ?? '';
        _gradeCtrl.text = args['grade'] ?? '';
        _sectionCtrl.text = args['section'] ?? '';
        
        final status = args['status'];
        if (status != null && status.toString().isNotEmpty) _status = status;
        
        final busId = args['assignedBusId'];
        if (busId != null && busId.toString().isNotEmpty) _selectedBusId = busId;

        final parentUid = args['parentUid'];
        if (parentUid != null && parentUid.toString().isNotEmpty) _selectedParentUid = parentUid;

        // Pick up schoolId from args (passed when SchoolAdmin creates a new student)
        final argSchoolId = args['schoolId'];
        if (argSchoolId != null && argSchoolId.toString().isNotEmpty) {
          _schoolId = argSchoolId;
        }
      }
      // If schoolId not set via args, try from provider (for SchoolAdmin)
      final provider = context.read<AdminProvider>();
      if (_schoolId == null && provider.isSchoolAdmin && provider.schoolId != null) {
        _schoolId = provider.schoolId;
      }
      _isInit = true;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _gradeCtrl.dispose();
    _sectionCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final provider = context.read<AdminProvider>();
      List<BusModel> buses;

      // SchoolAdmin: only show buses assigned to their school
      if (provider.isSchoolAdmin && _schoolId != null) {
        buses = await SchoolService().fetchBusesForSchool(_schoolId!);
      } else {
        buses = await _assignmentService.fetchBuses();
      }

      final parents = await _parentService.fetchAllParents();

      if (mounted) {
        setState(() {
          _buses = buses;
          _parents = parents;
          
          if (_selectedBusId != null && _selectedBusId!.isNotEmpty) {
            final exists = _buses.any((bus) => bus.id == _selectedBusId);
            if (!exists) {
              _selectedBusId = null;
            }
          }
          
          if (_selectedParentUid != null && _selectedParentUid!.isNotEmpty) {
            final exists = _parents.any((parent) => parent.uid == _selectedParentUid);
            if (!exists) {
              _selectedParentUid = null;
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

  Future<void> _saveStudent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    try {
      await _studentService.saveStudent(
        id: _studentId,
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        grade: _gradeCtrl.text.trim(),
        section: _sectionCtrl.text.trim(),
        assignedBusId: _selectedBusId,
        status: _status,
        parentUid: _selectedParentUid,
        schoolId: _schoolId,
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
        SnackbarUtils.showCustomSnackbar(context, 'Failed to save student: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _deleteStudent() async {
    if (_studentId == null) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Student?'),
        content: Text('Are you sure you want to permanently delete student "${_nameCtrl.text}"? This will also unlink them from their parent.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _submitting = true);
    try {
      await _studentService.deleteStudent(_studentId!);
      if (!mounted) return;
      SnackbarUtils.showCustomSnackbar(context, 'Student deleted successfully.', isError: false);
      Navigator.maybePop(context);
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showCustomSnackbar(context, 'Failed to delete student: $e', isError: true);
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
        title: 'Add / Edit Student',
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
      title: _studentId != null ? 'Edit Student' : 'Register New Student',
      subtitle: _studentId != null ? 'Update student details and assignments.' : 'Add student details, select parent, and assign school bus route.',
      actions: _studentId != null
          ? [
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                tooltip: 'Delete Student',
                onPressed: _submitting ? null : _deleteStudent,
              ),
            ]
          : null,
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
                        colors: [AppColors.student.gradientStart, AppColors.student.gradientEnd],
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
                        const Icon(Icons.school_rounded, color: Colors.white, size: 40),
                        const SizedBox(height: 12),
                        const Text(
                          'Student Registration',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _studentId != null 
                              ? 'Update the details for this student profile.' 
                              : 'Fill out the details below to add a student to the transit portal.',
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
                            decoration: _inputDecoration(scheme, hint: 'e.g. Alex Johnson'),
                            validator: (val) => val == null || val.isEmpty ? 'Required field' : null,
                          ),
                          const SizedBox(height: 24),

                          const _FormLabel(label: 'Email Address', icon: Icons.email_rounded),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: _inputDecoration(scheme, hint: 'e.g. student@school.edu'),
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
                                    const _FormLabel(label: 'Grade / Class', icon: Icons.class_rounded),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _gradeCtrl,
                                      decoration: _inputDecoration(scheme, hint: 'e.g. Grade 10'),
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
                                    const _FormLabel(label: 'Section', icon: Icons.view_headline_rounded),
                                    const SizedBox(height: 8),
                                    TextFormField(
                                      controller: _sectionCtrl,
                                      decoration: _inputDecoration(scheme, hint: 'e.g. B'),
                                      validator: (val) => val == null || val.isEmpty ? 'Required field' : null,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Dynamic Parent Dropdown
                          const _FormLabel(label: 'Contact Parent', icon: Icons.family_restroom_rounded),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedParentUid,
                            hint: const Text('Link parent account...'),
                            decoration: _inputDecoration(scheme, hint: ''),
                            items: [
                              const DropdownMenuItem<String>(
                                value: '',
                                child: Text('No Parent / Unassigned'),
                              ),
                              ..._parents.map((parent) {
                                return DropdownMenuItem<String>(
                                  value: parent.uid,
                                  child: Text('${parent.name} (${parent.email})'),
                                );
                              }).toList()
                            ],
                            onChanged: (val) => setState(() => _selectedParentUid = (val == '' ? null : val)),
                          ),
                          const SizedBox(height: 24),

                          // Dynamic Bus Dropdown
                          const _FormLabel(label: 'Assign Bus', icon: Icons.directions_bus_rounded),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedBusId,
                            hint: const Text('Assign route bus...'),
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
                          const _FormLabel(label: 'Status', icon: Icons.toggle_on_rounded),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _status,
                            decoration: _inputDecoration(scheme, hint: ''),
                            items: const [
                              DropdownMenuItem(value: 'active', child: Text('Active')),
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
                              onPressed: _submitting ? null : _saveStudent,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.student.primary,
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
                                _submitting ? 'Saving Student...' : 'Save Student',
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
