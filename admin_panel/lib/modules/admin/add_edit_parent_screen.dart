import '../../core/widgets/app_screen.dart';
import '../../core/services/parent_service.dart';
import '../../core/services/student_service.dart';
import '../../core/models/user_model.dart';
import '../../core/utils/snackbar_utils.dart';
import '../../app/theme/app_colors.dart';
import 'package:flutter/material.dart';

class AddEditParentScreen extends StatefulWidget {
  const AddEditParentScreen({super.key});

  @override
  State<AddEditParentScreen> createState() => _AddEditParentScreenState();
}

class _AddEditParentScreenState extends State<AddEditParentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _parentService = ParentService();
  final _studentService = StudentService();

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  String _status = 'active';
  String? _parentId;
  bool _isInit = false;

  List<UserModel> _allStudents = [];
  final List<String> _selectedChildrenUids = [];
  String _searchQuery = '';

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
        _parentId = args['id'];
        _nameCtrl.text = args['name'] ?? '';
        _emailCtrl.text = args['email'] ?? '';
        _phoneCtrl.text = args['phone'] ?? '';
        
        final status = args['status'];
        if (status != null && status.toString().isNotEmpty) _status = status;
        
        final children = args['childrenUids'];
        if (children != null) {
          _selectedChildrenUids.addAll(List<String>.from(children));
        }
      }
      _isInit = true;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final students = await _studentService.fetchAllStudents();
      if (mounted) {
        setState(() {
          _allStudents = students;
          _loadingData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingData = false);
        SnackbarUtils.showCustomSnackbar(context, 'Failed to fetch students: $e', isError: true);
      }
    }
  }

  Future<void> _saveParent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    try {
      await _parentService.saveParent(
        id: _parentId,
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        status: _status,
        childrenUids: _selectedChildrenUids,
      );

      if (!mounted) return;
      SnackbarUtils.showCustomSnackbar(
        context,
        'Success! ${_nameCtrl.text} has been saved successfully.',
        isError: false,
      );
      Navigator.maybePop(context);
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showCustomSnackbar(context, 'Failed to save parent: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _deleteParent() async {
    if (_parentId == null) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Parent?'),
        content: Text('Are you sure you want to permanently delete parent "${_nameCtrl.text}"? This will not delete their linked children.'),
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
      await _parentService.deleteParent(_parentId!);
      if (!mounted) return;
      SnackbarUtils.showCustomSnackbar(context, 'Parent deleted successfully.', isError: false);
      Navigator.maybePop(context);
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showCustomSnackbar(context, 'Failed to delete parent: $e', isError: true);
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
        title: 'Add / Edit Parent',
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

    final filteredStudents = _allStudents.where((student) {
      final query = _searchQuery.toLowerCase();
      return student.name.toLowerCase().contains(query) ||
          student.email.toLowerCase().contains(query) ||
          (student.grade != null && student.grade!.toLowerCase().contains(query));
    }).toList();

    return AppScreen(
      title: _parentId != null ? 'Edit Parent' : 'Register New Parent',
      subtitle: _parentId != null ? 'Update parent credentials and linked students.' : 'Add parent details and select their school students.',
      actions: _parentId != null
          ? [
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                tooltip: 'Delete Parent',
                onPressed: _submitting ? null : _deleteParent,
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
                        colors: [AppColors.parent.gradientStart, AppColors.parent.gradientEnd],
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
                        const Icon(Icons.family_restroom_rounded, color: Colors.white, size: 40),
                        const SizedBox(height: 12),
                        const Text(
                          'Parent Registration',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _parentId != null
                              ? 'Update the details for this parent profile.'
                              : 'Fill out the details below to add a new parent to the tracker system.',
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
                          const _FormLabel(label: 'Parent Full Name', icon: Icons.person_rounded),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _nameCtrl,
                            decoration: _inputDecoration(scheme, hint: 'e.g. Sarah Khan'),
                            validator: (val) => val == null || val.isEmpty ? 'Required field' : null,
                          ),
                          const SizedBox(height: 24),

                          const _FormLabel(label: 'Email Address', icon: Icons.email_rounded),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: _inputDecoration(scheme, hint: 'e.g. sarah.khan@example.com'),
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
                          const SizedBox(height: 24),

                          // Children multi-select area
                          const _FormLabel(label: 'Link Children (Students)', icon: Icons.school_rounded),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHighest.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: scheme.outlineVariant),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: [
                                // Student Search Bar
                                TextField(
                                  decoration: InputDecoration(
                                    hintText: 'Search student by name or grade...',
                                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: BorderSide(color: scheme.outlineVariant),
                                    ),
                                    filled: true,
                                    fillColor: scheme.surface,
                                  ),
                                  onChanged: (val) => setState(() => _searchQuery = val),
                                ),
                                const SizedBox(height: 12),
                                
                                // Selected count badge
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Students found: ${filteredStudents.length}',
                                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.parent.primary.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        'Selected: ${_selectedChildrenUids.length}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.parent.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 20),

                                // Scrollable Checklist
                                Container(
                                  constraints: const BoxConstraints(maxHeight: 220),
                                  child: filteredStudents.isEmpty
                                      ? Center(
                                          child: Padding(
                                            padding: const EdgeInsets.all(24.0),
                                            child: Text(
                                              'No students match search criteria.',
                                              style: TextStyle(fontStyle: FontStyle.italic, color: scheme.onSurfaceVariant),
                                            ),
                                          ),
                                        )
                                      : ListView.builder(
                                          shrinkWrap: true,
                                          itemCount: filteredStudents.length,
                                          itemBuilder: (context, index) {
                                            final student = filteredStudents[index];
                                            final isChecked = _selectedChildrenUids.contains(student.uid);
                                            return CheckboxListTile(
                                              value: isChecked,
                                              title: Text(
                                                student.name,
                                                style: const TextStyle(fontWeight: FontWeight.bold),
                                              ),
                                              subtitle: Text(
                                                'Grade: ${student.grade ?? "N/A"} · Section: ${student.section ?? "N/A"}',
                                                style: const TextStyle(fontSize: 12),
                                              ),
                                              activeColor: AppColors.parent.primary,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              onChanged: (bool? val) {
                                                setState(() {
                                                  if (val == true) {
                                                    _selectedChildrenUids.add(student.uid);
                                                  } else {
                                                    _selectedChildrenUids.remove(student.uid);
                                                  }
                                                });
                                              },
                                            );
                                          },
                                        ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 32),

                          // Action button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: FilledButton.icon(
                              onPressed: _submitting ? null : _saveParent,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.parent.primary,
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
                                _submitting ? 'Saving Profile...' : 'Save Parent Details',
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
