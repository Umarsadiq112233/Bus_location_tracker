import 'package:bus_location_tracker/core/models/user_model.dart';
import 'package:bus_location_tracker/core/services/auth_service.dart';
import 'package:bus_location_tracker/core/utils/snackbar_utils.dart';
import 'package:bus_location_tracker/shared/enums/user_role.dart';
import 'package:bus_location_tracker/modules/auth/auth_controller.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:bus_location_tracker/core/utils/profile_image_helper.dart';
import 'package:image_picker/image_picker.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _licenseController = TextEditingController();
  final _experienceController = TextEditingController();

  UserModel? _user;
  bool _fetchingProfile = true;
  String? _fetchError;
  bool _isLoading = false;
  bool _isOnboarding = false;
  UserRole? _onboardingRole;
  Uint8List? _localImageBytes;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      _isOnboarding = args['isOnboarding'] ?? false;
      _onboardingRole = args['role'] as UserRole?;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _licenseController.dispose();
    _experienceController.dispose();
    super.dispose();
  }

  Future<void> _loadLocalImage(String uid) async {
    final bytes = await ProfileImageHelper.getProfileImage(uid);
    if (mounted) {
      setState(() {
        _localImageBytes = bytes;
      });
    }
  }

  Future<void> _pickImage() async {
    if (_user == null) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                Navigator.pop(context);
                await _selectImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take Photo'),
              onTap: () async {
                Navigator.pop(context);
                await _selectImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _localImageBytes = bytes;
        });
        await ProfileImageHelper.saveProfileImage(_user!.uid, bytes);
        if (mounted) {
          SnackbarUtils.showCustomSnackbar(
            context,
            'Profile image updated locally!',
            isError: false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showCustomSnackbar(
          context,
          'Failed to pick image: $e',
          isError: true,
        );
      }
    }
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _fetchingProfile = true;
      _fetchError = null;
    });
    try {
      final auth = AuthService();
      final currentUser = auth.currentUser;
      if (currentUser == null) {
        setState(() {
          _fetchError = 'No user is logged in.';
          _fetchingProfile = false;
        });
        return;
      }
      final user = await auth.getUserData(currentUser.uid);
      if (user == null) {
        setState(() {
          _fetchError = 'Failed to load user profile data.';
          _fetchingProfile = false;
        });
        return;
      }

      setState(() {
        _user = user;
        _nameController.text = user.name;
        _phoneController.text = user.phone;
        _licenseController.text = user.licenseNumber ?? '';
        _experienceController.text = user.experienceYears?.toString() ?? '';
        _fetchingProfile = false;
      });
      _loadLocalImage(user.uid);
    } catch (e) {
      setState(() {
        _fetchError = 'Error fetching profile: $e';
        _fetchingProfile = false;
      });
    }
  }

  void _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final auth = AuthService();
        final uid = _user!.uid;
        final isDriver = (_user!.role ?? _onboardingRole) == UserRole.driver;
        final experience = int.tryParse(_experienceController.text.trim());

        final Map<String, dynamic> data = {
          'name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          if (isDriver) 'licenseNumber': _licenseController.text.trim(),
          if (isDriver) 'experienceYears': experience,
        };

        await auth.updateUserData(uid, data);

        if (!mounted) return;
        setState(() => _isLoading = false);

        SnackbarUtils.showCustomSnackbar(
          context,
          'Profile updated successfully',
          isError: false,
        );

        if (_isOnboarding) {
          final role = _user?.role ?? _onboardingRole ?? UserRole.parent;
          Navigator.pushNamedAndRemoveUntil(
            context,
            const AuthController().dashboardFor(role),
            (route) => false,
          );
        } else {
          Navigator.pop(context, true); // Return true to trigger refresh
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        SnackbarUtils.showCustomSnackbar(
          context,
          'Failed to update profile: $e',
          isError: true,
        );
      }
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_fetchingProfile) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Profile'), centerTitle: true),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_fetchError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Profile'), centerTitle: true),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: scheme.error),
              const SizedBox(height: 16),
              Text(_fetchError!, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadUserProfile,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final isDriver = (_user!.role ?? _onboardingRole) == UserRole.driver;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(
          _isOnboarding ? 'Complete Your Profile' : 'Edit Profile',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: scheme.surface,
        automaticallyImplyLeading: !_isOnboarding,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isOnboarding) ...[
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 12.0,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: scheme.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Please complete your details to proceed to the dashboard.',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: scheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                // Profile Image with Edit Badge
                Center(
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Stack(
                        children: [
                          Hero(
                            tag: 'profile_avatar',
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: scheme.primary,
                                  width: 2,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 55,
                                backgroundColor: scheme.primaryContainer,
                                backgroundImage: _localImageBytes != null
                                    ? MemoryImage(_localImageBytes!)
                                    : null,
                                child: _localImageBytes == null
                                    ? Text(
                                        _getInitials(_user!.name),
                                        style: TextStyle(
                                          fontSize: 36,
                                          fontWeight: FontWeight.w800,
                                          color: scheme.primary,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: scheme.surface,
                                  width: 3,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // Name Field
                _buildTextField(
                  controller: _nameController,
                  label: 'Full Name',
                  icon: Icons.person_outline_rounded,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Phone Field
                _buildTextField(
                  controller: _phoneController,
                  label: 'Phone Number',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your phone number';
                    }
                    if (value.trim().length < 6) {
                      return 'Enter a valid phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Driver License Field (Driver specific)
                if (isDriver) ...[
                  _buildTextField(
                    controller: _licenseController,
                    label: 'Driver License Number',
                    icon: Icons.badge_outlined,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'License number is required to drive/start trips';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Driver Experience Field (Driver specific)
                  _buildTextField(
                    controller: _experienceController,
                    label: 'Years of Experience',
                    icon: Icons.work_history_outlined,
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value != null && value.trim().isNotEmpty) {
                        final numVal = int.tryParse(value);
                        if (numVal == null || numVal < 0) {
                          return 'Enter a valid number of years';
                        }
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                ],

                // Read-only Email Field
                _buildTextField(
                  label: 'Email Address',
                  icon: Icons.email_outlined,
                  initialValue: _user!.email,
                  readOnly: true,
                ),
                const SizedBox(height: 40),

                // Save Button
                SizedBox(
                  height: 56,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _saveProfile,
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 3,
                            ),
                          )
                        : const Text(
                            'Save Changes',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    TextEditingController? controller,
    required String label,
    required IconData icon,
    String? initialValue,
    bool readOnly = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return TextFormField(
      controller: controller,
      initialValue: initialValue,
      readOnly: readOnly,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        color: readOnly ? scheme.onSurfaceVariant : scheme.onSurface,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontWeight: FontWeight.w500),
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: readOnly
            ? scheme.surfaceContainerHigh.withValues(alpha: 0.5)
            : scheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.error, width: 1),
        ),
      ),
    );
  }
}
