import 'dart:async';
import 'package:bus_location_tracker/app/theme/app_colors.dart';
import 'package:bus_location_tracker/core/models/user_model.dart';
import 'package:bus_location_tracker/core/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ParentQrScannerScreen extends StatefulWidget {
  const ParentQrScannerScreen({super.key});

  @override
  State<ParentQrScannerScreen> createState() => _ParentQrScannerScreenState();
}

class _ParentQrScannerScreenState extends State<ParentQrScannerScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _laserController;
  late final Animation<double> _laserAnimation;

  late final MobileScannerController _scannerController;

  bool _isProcessing = false;
  bool _isSuccess = false;
  String? _successMessage;
  String? _errorMessage;

  UserModel? _selectedSimulatedChild;
  UserModel? _scannedStudent;
  bool _isLinkingChild = false;

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _laserController, curve: Curves.easeInOut),
    );

    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: [BarcodeFormat.qrCode],
    );
  }

  @override
  void dispose() {
    _laserController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _processScannedData(String scannedEmail, {UserModel? simulatedStudent}) async {
    if (_isProcessing || _isSuccess || _scannedStudent != null) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _selectedSimulatedChild = simulatedStudent;
    });

    try {
      final auth = AuthService();
      final currentUser = auth.currentUser;
      if (currentUser == null) {
        throw Exception('User session not found. Please log in again.');
      }

      // Add delay for mock simulation feedback
      if (simulatedStudent != null) {
        await Future.delayed(const Duration(milliseconds: 1000));
      }

      // 1. Fetch student corresponding to scanned email
      final student = await auth.fetchStudentByEmail(scannedEmail);
      if (student == null) {
        throw Exception('No student account found for: $scannedEmail');
      }

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _scannedStudent = student;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isSuccess = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
        _scannerController.start(); // Resume scanning
      }
    }
  }

  Future<void> _linkScannedChild() async {
    if (_scannedStudent == null || _isLinkingChild) return;

    setState(() {
      _isLinkingChild = true;
      _errorMessage = null;
    });

    try {
      final auth = AuthService();
      final currentUser = auth.currentUser;
      if (currentUser == null) {
        throw Exception('User session not found. Please log in again.');
      }

      // Link student UID to parent children list
      await auth.linkChild(currentUser.uid, _scannedStudent!.uid);

      if (mounted) {
        setState(() {
          _isLinkingChild = false;
          _isSuccess = true;
          _successMessage = '${_scannedStudent!.name} has been linked to your profile!';
          _scannedStudent = null;
        });

        // Auto-navigate back after success screen
        Timer(const Duration(milliseconds: 1850), () {
          if (mounted) {
            Navigator.pop(context, true);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLinkingChild = false;
          _isSuccess = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  void _showSimulationDrawer() async {
    final auth = AuthService();
    final currentUser = auth.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in first.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.75,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Simulate Scanner (Demo)',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.0),
                    child: Text(
                      'Select a registered student from the list below to simulate scanning their unique profile QR code.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const Divider(height: 24),
                  Expanded(
                    child: FutureBuilder<List<UserModel>>(
                      future: Future.wait([
                        auth.getUserData(currentUser.uid),
                        auth.fetchAllStudents(),
                      ]).then((results) {
                        final parent = results[0] as UserModel?;
                        final allStudents = results[1] as List<UserModel>;
                        final linkedUids = parent?.childrenUids ?? [];
                        // Filter out already linked children
                        return allStudents
                            .where((s) => !linkedUids.contains(s.uid))
                            .toList();
                      }),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Error loading students: ${snapshot.error}',
                              style: const TextStyle(color: AppColors.danger),
                            ),
                          );
                        }
                        final students = snapshot.data ?? [];
                        if (students.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.people_outline_rounded,
                                      size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No unlinked students found',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'All registered students are already connected to your account.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: students.length,
                          separatorBuilder: (c, i) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final student = students[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primaryLight,
                                foregroundColor: AppColors.primary,
                                child: Text(
                                  student.name.isNotEmpty
                                      ? student.name.substring(0, 1).toUpperCase()
                                      : 'S',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(
                                student.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              subtitle: Text(
                                '${student.grade ?? 'Grade N/A'} · ${student.email}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: const Icon(
                                Icons.qr_code_2_rounded,
                                color: AppColors.primary,
                              ),
                              onTap: () {
                                Navigator.pop(context); // Close sheet
                                _processScannedData(student.email, simulatedStudent: student); // Trigger simulation
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scanAreaSize = size.width * 0.7;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Physical Camera Viewfinder Background
          Positioned.fill(
            child: MobileScanner(
              controller: _scannerController,
              errorBuilder: (context, error) {
                return Container(
                  color: const Color(0xFF0F172A),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.videocam_off_rounded,
                              size: 64, color: Colors.grey.shade600),
                          const SizedBox(height: 16),
                          const Text(
                            'Camera Access Required',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Could not access the physical camera. Please verify permission settings. If you are using a simulator, use the simulation helper below.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              onDetect: (BarcodeCapture capture) {
                if (_isProcessing || _isSuccess || _scannedStudent != null) return;
                final barcodes = capture.barcodes;
                if (barcodes.isNotEmpty) {
                  final String? rawValue = barcodes.first.rawValue;
                  if (rawValue != null && rawValue.isNotEmpty) {
                    _scannerController.stop();
                    _processScannedData(rawValue);
                  }
                }
              },
            ),
          ),

          // 2. Custom Viewport Grid Overlay (Visual cut-out frame)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _laserAnimation,
              builder: (context, child) {
                return CustomPaint(
                  painter: _ScannerOverlayPainter(
                    scanAreaSize: scanAreaSize,
                    laserProgress: _laserAnimation.value,
                    isAnimating: !_isProcessing && !_isSuccess,
                  ),
                );
              },
            ),
          ),

          // 3. Central Overlay Message / Progress Status
          Center(
            child: SizedBox(
              width: scanAreaSize,
              height: scanAreaSize,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    // Decoding/Processing State
                    if (_isProcessing)
                      Container(
                        color: Colors.black.withValues(alpha: 0.7),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircularProgressIndicator(
                                color: AppColors.success,
                                strokeWidth: 3.5,
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Connecting student...',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              if (_selectedSimulatedChild != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  _selectedSimulatedChild!.name,
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                    // Success State
                    if (_isSuccess)
                      Container(
                        color: Colors.black.withValues(alpha: 0.75),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: const BoxDecoration(
                                  color: Colors.green,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check_rounded,
                                  size: 48,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Connected!',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  _successMessage ?? 'Linked successfully',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Failure State
                    if (_errorMessage != null)
                      Container(
                        color: Colors.black.withValues(alpha: 0.75),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: const BoxDecoration(
                                  color: AppColors.danger,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  size: 32,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Connection Failed',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _errorMessage = null;
                                    _selectedSimulatedChild = null;
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.black87,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text('Try Again'),
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

          // 4. Floating Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 54, 16, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black54, Colors.transparent],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.black38,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Scan to Link',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),

          // 5. Instruction text and simulation CTA at the bottom
          Positioned(
            bottom: 40,
            left: 24,
            right: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: const Text(
                    'Align the student QR code from the child\'s profile within the green borders to link instantly.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: (_isProcessing || _isSuccess) ? null : _showSimulationDrawer,
                    icon: const Icon(Icons.videogame_asset_outlined, size: 22),
                    label: const Text(
                      'Simulate Scanner (Demo)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.1,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                      shadowColor: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_scannedStudent != null)
            Positioned.fill(
              child: Container(
                color: Colors.black54, // Dim background
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 20,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.person_add_rounded,
                              color: AppColors.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Student Found',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      // Details
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                        child: Text(
                          _scannedStudent!.name.isNotEmpty
                              ? _scannedStudent!.name.substring(0, 1).toUpperCase()
                              : 'S',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _scannedStudent!.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _scannedStudent!.email,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_scannedStudent!.grade ?? "Grade N/A"} · Section ${_scannedStudent!.section ?? "N/A"}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _scannedStudent = null;
                                  _isProcessing = false;
                                });
                                _scannerController.start(); // Resume scanning
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: _isLinkingChild ? null : _linkScannedChild,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.success,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _isLinkingChild
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : const Text('Connect Child'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScannerOverlayPainter extends CustomPainter {
  _ScannerOverlayPainter({
    required this.scanAreaSize,
    required this.laserProgress,
    required this.isAnimating,
  });

  final double scanAreaSize;
  final double laserProgress;
  final bool isAnimating;

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.65)
      ..style = PaintingStyle.fill;

    final left = (size.width - scanAreaSize) / 2;
    final top = (size.height - scanAreaSize) / 2;
    final rect = Rect.fromLTWH(left, top, scanAreaSize, scanAreaSize);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(24));

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(rrect);

    canvas.drawPath(path, overlayPaint);

    final borderPaint = Paint()
      ..color = Colors.white30
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(rrect, borderPaint);

    final cornerPaint = Paint()
      ..color = const Color(0xFF10B981)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLength = 32.0;

    canvas.drawPath(
      Path()
        ..moveTo(left + cornerLength, top)
        ..quadraticBezierTo(left, top, left, top + cornerLength),
      cornerPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(left + scanAreaSize - cornerLength, top)
        ..quadraticBezierTo(
            left + scanAreaSize, top, left + scanAreaSize, top + cornerLength),
      cornerPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(left, top + scanAreaSize - cornerLength)
        ..quadraticBezierTo(left, top + scanAreaSize, left + cornerLength,
            top + scanAreaSize),
      cornerPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(left + scanAreaSize - cornerLength, top + scanAreaSize)
        ..quadraticBezierTo(left + scanAreaSize, top + scanAreaSize,
            left + scanAreaSize, top + scanAreaSize - cornerLength),
      cornerPaint,
    );

    if (isAnimating) {
      final laserY = top + (laserProgress * scanAreaSize);
      final laserPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            const Color(0xFF10B981).withValues(alpha: 0.05),
            const Color(0xFF06B6D4),
            const Color(0xFF10B981).withValues(alpha: 0.05),
          ],
        ).createShader(
            Rect.fromLTRB(left, laserY - 8, left + scanAreaSize, laserY + 8))
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke;

      canvas.drawLine(
        Offset(left + 12, laserY),
        Offset(left + scanAreaSize - 12, laserY),
        laserPaint,
      );

      final glowPaint = Paint()
        ..color = const Color(0xFF06B6D4).withValues(alpha: 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

      canvas.drawRect(
        Rect.fromLTRB(left + 16, laserY - 2, left + scanAreaSize - 16, laserY + 2),
        glowPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScannerOverlayPainter oldDelegate) {
    return oldDelegate.laserProgress != laserProgress ||
        oldDelegate.isAnimating != isAnimating;
  }
}
