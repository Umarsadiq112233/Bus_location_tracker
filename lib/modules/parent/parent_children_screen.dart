import 'package:bus_location_tracker/app/routes/app_routes.dart';
import 'package:bus_location_tracker/app/theme/app_colors.dart';
import 'package:bus_location_tracker/core/models/user_model.dart';
import 'package:bus_location_tracker/core/models/bus_model.dart';
import 'package:bus_location_tracker/core/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:bus_location_tracker/core/widgets/skeleton_loader.dart';

// ═══════════════════════════════════════════════════════════════
// Parent Children Screen — Professional Dynamic UI
// ═══════════════════════════════════════════════════════════════

class ParentChildrenScreen extends StatefulWidget {
  const ParentChildrenScreen({super.key});

  @override
  State<ParentChildrenScreen> createState() => _ParentChildrenScreenState();
}

class _ParentChildrenScreenState extends State<ParentChildrenScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  List<Animation<double>> _fades = [];
  List<Animation<Offset>> _slides = [];

  List<UserModel> _linkedChildren = [];
  bool _loadingChildren = true;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadChildren();
  }

  Future<void> _loadChildren() async {
    if (mounted) setState(() => _loadingChildren = true);
    try {
      final auth = AuthService();
      final currentUser = auth.currentUser;
      if (currentUser != null) {
        final parent = await auth.getUserData(currentUser.uid);
        if (parent != null &&
            parent.childrenUids != null &&
            parent.childrenUids!.isNotEmpty) {
          final children = await AuthService().fetchChildren(
            parent.childrenUids!,
          );

          if (mounted) {
            setState(() {
              _linkedChildren = children;
              _loadingChildren = false;
            });
            _initAnimations();
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('Error loading children: $e');
    }
    if (mounted) {
      setState(() {
        _linkedChildren = [];
        _loadingChildren = false;
      });
      _initAnimations();
    }
  }

  void _initAnimations() {
    _fades = List.generate(_linkedChildren.length + 1, (i) {
      final s = i * 0.15;
      return CurvedAnimation(
        parent: _animCtrl,
        curve: Interval(s, (s + 0.45).clamp(0, 1), curve: Curves.easeOut),
      );
    });
    _slides = List.generate(_linkedChildren.length + 1, (i) {
      final s = i * 0.15;
      return Tween<Offset>(
        begin: const Offset(0, 0.2),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _animCtrl,
          curve: Interval(
            s,
            (s + 0.45).clamp(0, 1),
            curve: Curves.easeOutCubic,
          ),
        ),
      );
    });
    _animCtrl.reset();
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _showAddChildDialog() {
    final emailCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool linking = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Link Your Child',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Enter your child\'s registered student email address to link them to your account.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Student Email',
                        hintText: 'student@example.com',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Email is required';
                        }
                        if (!value.contains('@')) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: linking ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: linking
                      ? null
                      : () async {
                          if (formKey.currentState!.validate()) {
                            setDialogState(() => linking = true);
                            try {
                              final email = emailCtrl.text.trim();

                              // Find student with this email
                              final studentModel = await AuthService()
                                  .fetchStudentByEmail(email);

                              if (studentModel == null) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'No student found with this email.',
                                      ),
                                      backgroundColor: AppColors.danger,
                                    ),
                                  );
                                }
                                setDialogState(() => linking = false);
                                return;
                              }

                              final studentId = studentModel.uid;

                              final auth = AuthService();
                              final currentUser = auth.currentUser;
                              if (currentUser != null) {
                                await auth.linkChild(
                                  currentUser.uid,
                                  studentId,
                                );

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Child linked successfully!',
                                      ),
                                      backgroundColor: AppColors.success,
                                    ),
                                  );
                                  Navigator.pop(context);
                                  _loadChildren();
                                }
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error linking child: $e'),
                                    backgroundColor: AppColors.danger,
                                  ),
                                );
                              }
                              setDialogState(() => linking = false);
                            }
                          }
                        },
                  child: linking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Link'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddChildOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Connect Your Child',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  'Choose a method to link your child\'s profile with your parent dashboard.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 4,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                title: const Text(
                  'Scan QR Code',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                subtitle: const Text(
                  'Scan the QR code shown on your child\'s profile screen',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  Navigator.pop(context);
                  final result = await Navigator.pushNamed(
                    context,
                    AppRoutes.parentQrScanner,
                  );
                  if (result == true) {
                    _loadChildren();
                  }
                },
              ),
              const Divider(height: 1, indent: 24, endIndent: 24),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 4,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.email_outlined,
                    color: AppColors.success,
                    size: 24,
                  ),
                ),
                title: const Text(
                  'Link via Student Email',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                subtitle: const Text(
                  'Type student\'s email address to search & connect',
                  style: TextStyle(fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(context);
                  _showAddChildDialog();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showQrCodeDialog(UserModel child) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                child.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${child.grade ?? "Grade N/A"} · Section ${child.section ?? "N/A"}',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: 200,
                height: 200,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200, width: 2),
                ),
                child: QrImageView(
                  data: child.email,
                  version: QrVersions.auto,
                  size: 200.0,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'UID: ${child.uid}',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textMuted,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
                label: const Text('Close'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.parent.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = [
      AppColors.success,
      AppColors.parent.primary,
      AppColors.secondary,
      AppColors.info,
    ];

    return Scaffold(
      backgroundColor: AppColors.surfaceSoft,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'My Children',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _showAddChildOptions,
            icon: const Icon(
              Icons.add_circle_outline_rounded,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadChildren,
        color: AppColors.parent.primary,
        child: _loadingChildren
            ? const ListSkeleton(itemCount: 3, cardHeight: 140, borderRadius: 20)
            : _linkedChildren.isEmpty
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.65,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.child_care_rounded,
                              size: 64,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No children linked yet',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Tap the "+" icon at the top right to link your child using their QR code or student email.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              onPressed: _showAddChildOptions,
                              icon: const Icon(Icons.add),
                              label: const Text('Link a Child'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.parent.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: _linkedChildren.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final child = _linkedChildren[index];
                  final color = colors[index % colors.length];
                  return FadeTransition(
                    opacity: _fades[index],
                    child: SlideTransition(
                      position: _slides[index],
                      child: _ChildCard(
                        child: child,
                        color: color,
                        onQrTap: () => _showQrCodeDialog(child),
                        onTap: () async {
                          final result = await Navigator.pushNamed(
                            context,
                            AppRoutes.childDetails,
                            arguments: child,
                          );
                          if (result == true) {
                            _loadChildren();
                          }
                        },
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _ChildCard extends StatelessWidget {
  const _ChildCard({
    required this.child,
    required this.color,
    required this.onQrTap,
    this.onTap,
  });

  final UserModel child;
  final Color color;
  final VoidCallback onQrTap;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final gradeText =
        '${child.grade ?? "Grade N/A"} · Section ${child.section ?? "N/A"}';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 14,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        child.name.isNotEmpty
                            ? child.name.substring(0, 1).toUpperCase()
                            : 'S',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          child.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          gradeText,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: onQrTap,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F6F8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.qr_code_rounded,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FutureBuilder<BusModel?>(
                          future:
                              child.assignedBusId != null &&
                                  child.assignedBusId!.isNotEmpty
                              ? AuthService().fetchAssignedBus(
                                  child.assignedBusId!,
                                )
                              : Future.value(null),
                          builder: (context, snapshot) {
                            final busNum =
                                snapshot.data?.busNumber ?? 'Not Assigned';
                            return Row(
                              children: [
                                Icon(
                                  Icons.directions_bus_rounded,
                                  size: 14,
                                  color: color,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Bus: $busNum',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              size: 14,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Pickup: ${child.pickupPoint ?? "Not Set"}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  FilledButton.icon(
                    onPressed:
                        child.assignedBusId != null &&
                            child.assignedBusId!.isNotEmpty
                        ? () => Navigator.pushNamed(
                            context,
                            AppRoutes.liveTracking,
                            arguments: {'busId': child.assignedBusId},
                          )
                        : null,
                    icon: const Icon(Icons.gps_fixed_rounded, size: 16),
                    label: const Text('Track'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.parent.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 0,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
