import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:eduverse/utils/app_theme.dart';
import 'package:intl/intl.dart';

class CertificateScreen extends StatefulWidget {
  final String studentName;
  final String courseName;
  final double performance; // 0.0 to 1.0
  final DateTime completionDate;

  const CertificateScreen({
    super.key,
    required this.studentName,
    required this.courseName,
    required this.performance,
    required this.completionDate,
  });

  @override
  State<CertificateScreen> createState() => _CertificateScreenState();
}

class _CertificateScreenState extends State<CertificateScreen> {
  final GlobalKey _certificateKey = GlobalKey();
  bool _isSaving = false;

  String _getPerformanceGrade() {
    final perf = widget.performance * 100;
    if (perf >= 90) return 'Excellent';
    if (perf >= 80) return 'Very Good';
    if (perf >= 70) return 'Good';
    if (perf >= 60) return 'Satisfactory';
    return 'Pass';
  }

  Color _getPerformanceColor() {
    final perf = widget.performance * 100;
    if (perf >= 90) return const Color(0xFFFFD700); // Gold
    if (perf >= 80) return const Color(0xFFC0C0C0); // Silver
    if (perf >= 70) return const Color(0xFFCD7F32); // Bronze
    return AppTheme.primaryColor;
  }

  Future<void> _saveCertificate() async {
    setState(() => _isSaving = true);

    try {
      // Get the render object
      RenderRepaintBoundary boundary =
          _certificateKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;

      // Capture the image
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData != null) {
        // For web, we'll just show a success message
        // In a production app, you'd use file_saver or similar package
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Certificate captured! In production, this would be saved.',
            ),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save certificate: $e')));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDarkMode(context);
    return Scaffold(
      backgroundColor: isDark ? Colors.transparent : Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Certificate'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: isDark ? AppTheme.darkPrimaryGradient : AppTheme.primaryGradient,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _isSaving ? null : _saveCertificate,
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download),
            tooltip: 'Save Certificate',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: RepaintBoundary(
            key: _certificateKey,
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 600),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Border decoration
                  Positioned.fill(
                    child: Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _getPerformanceColor(),
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  // Inner border
                  Positioned.fill(
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _getPerformanceColor().withOpacity(0.3),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Corner decorations
                  ..._buildCornerDecorations(),
                  // Main content
                  Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        // Logo and Title
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.school_rounded,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'eduVerse',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Certificate Title
                        Text(
                          'CERTIFICATE',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w300,
                            color: _getPerformanceColor(),
                            letterSpacing: 8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'OF COMPLETION',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w300,
                            color: Colors.grey.shade600,
                            letterSpacing: 4,
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Decorative line
                        Container(
                          width: 100,
                          height: 2,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.transparent,
                                _getPerformanceColor(),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        // This is to certify
                        Text(
                          'This is to certify that',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Student Name
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: _getPerformanceColor(),
                                width: 2,
                              ),
                            ),
                          ),
                          child: Text(
                            widget.studentName,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                              fontFamily: 'serif',
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Has successfully completed
                        Text(
                          'has successfully completed the course',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Course Name
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: _getPerformanceColor().withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _getPerformanceColor().withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            widget.courseName,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              color: _getPerformanceColor(),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Performance Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: _getPerformanceColor(),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star, color: Colors.white, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Performance: ${_getPerformanceGrade()} (${(widget.performance * 100).toInt()}%)',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Date
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 16,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Completed on ${DateFormat('MMMM d, yyyy').format(widget.completionDate)}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),
                        // Signature Section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Column(
                              children: [
                                // Signature
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    'Anees',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontFamily: 'cursive',
                                      fontStyle: FontStyle.italic,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                ),
                                // Line under signature
                                Container(
                                  width: 150,
                                  height: 1,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Anees',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                Text(
                                  'Founder & CEO',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Certificate ID
                        Text(
                          'Certificate ID: EDU-${widget.completionDate.millisecondsSinceEpoch.toString().substring(0, 10)}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade400,
                            letterSpacing: 1,
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
      ),
    );
  }

  List<Widget> _buildCornerDecorations() {
    final color = _getPerformanceColor();
    return [
      // Top left
      Positioned(top: 20, left: 20, child: _buildCorner(color, topLeft: true)),
      // Top right
      Positioned(
        top: 20,
        right: 20,
        child: _buildCorner(color, topRight: true),
      ),
      // Bottom left
      Positioned(
        bottom: 20,
        left: 20,
        child: _buildCorner(color, bottomLeft: true),
      ),
      // Bottom right
      Positioned(
        bottom: 20,
        right: 20,
        child: _buildCorner(color, bottomRight: true),
      ),
    ];
  }

  Widget _buildCorner(
    Color color, {
    bool topLeft = false,
    bool topRight = false,
    bool bottomLeft = false,
    bool bottomRight = false,
  }) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        border: Border(
          top: topLeft || topRight
              ? BorderSide(color: color, width: 3)
              : BorderSide.none,
          bottom: bottomLeft || bottomRight
              ? BorderSide(color: color, width: 3)
              : BorderSide.none,
          left: topLeft || bottomLeft
              ? BorderSide(color: color, width: 3)
              : BorderSide.none,
          right: topRight || bottomRight
              ? BorderSide(color: color, width: 3)
              : BorderSide.none,
        ),
      ),
    );
  }
}
