import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:eduverse/utils/app_theme.dart';
import 'package:eduverse/services/user_customization_service.dart';
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
            child: _buildCertificateByStyle(),
          ),
        ),
      ),
    );
  }

  Widget _buildCertificateByStyle() {
    final style = UserCustomizationService.instance.certificateStyle;
    switch (style) {
      case 'modern':
        return _buildModernCertificate();
      case 'elegant':
        return _buildElegantCertificate();
      case 'minimal':
        return _buildMinimalCertificate();
      case 'classic':
      default:
        return _buildClassicCertificate();
    }
  }

  // ──────────── CLASSIC TEMPLATE ────────────
  Widget _buildClassicCertificate() {
    return Container(
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
                  ..._buildCornerDecorations(),
                  Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        _buildLogoRow(),
                        const SizedBox(height: 24),
                        _buildTitle(),
                        const SizedBox(height: 32),
                        _buildDecoLine(),
                        const SizedBox(height: 32),
                        _buildCertifyText(),
                        const SizedBox(height: 16),
                        _buildStudentName(),
                        const SizedBox(height: 24),
                        _buildCourseCompleted(),
                        const SizedBox(height: 16),
                        _buildCourseBox(),
                        const SizedBox(height: 24),
                        _buildPerformanceBadge(),
                        const SizedBox(height: 32),
                        _buildDateRow(),
                        const SizedBox(height: 40),
                        _buildSignatureSection(),
                        const SizedBox(height: 24),
                        _buildCertificateId(),
                      ],
                    ),
                  ),
                ],
              ),
    );
  }

  // ──────────── MODERN TEMPLATE ────────────
  Widget _buildModernCertificate() {
    final perfColor = _getPerformanceColor();
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 600),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: perfColor.withOpacity(0.2),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top gradient bar
          Container(
            height: 8,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [perfColor, perfColor.withOpacity(0.5), AppTheme.primaryColor],
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 36),
            child: Column(
              children: [
                // Modern logo
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [perfColor, AppTheme.primaryColor]),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.school_rounded, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 20),
                Text('CERTIFICATE OF COMPLETION',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryColor,
                        letterSpacing: 3)),
                const SizedBox(height: 32),
                Text('Awarded to',
                    style: TextStyle(
                        fontSize: 14, color: Colors.grey.shade500, letterSpacing: 2)),
                const SizedBox(height: 12),
                Text(widget.studentName,
                    style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                        letterSpacing: 1)),
                const SizedBox(height: 8),
                Container(width: 80, height: 4, decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [perfColor, AppTheme.primaryColor]),
                    borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 24),
                Text('for successfully completing',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [perfColor.withOpacity(0.1), AppTheme.primaryColor.withOpacity(0.05)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: perfColor.withOpacity(0.2)),
                  ),
                  child: Text(widget.courseName,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor),
                      textAlign: TextAlign.center),
                ),
                const SizedBox(height: 24),
                _buildPerformanceBadge(),
                const SizedBox(height: 24),
                _buildDateRow(),
                const SizedBox(height: 36),
                _buildSignatureSection(),
                const SizedBox(height: 20),
                _buildCertificateId(),
              ],
            ),
          ),
          // Bottom gradient bar
          Container(
            height: 8,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.primaryColor, perfColor.withOpacity(0.5), perfColor],
              ),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────── ELEGANT TEMPLATE ────────────
  Widget _buildElegantCertificate() {
    final gold = const Color(0xFFD4AF37);
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 600),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF5),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: gold.withOpacity(0.4), width: 2),
        boxShadow: [
          BoxShadow(
            color: gold.withOpacity(0.15),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Ornate inner border
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: gold, width: 1.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                border: Border.all(color: gold.withOpacity(0.3), width: 0.5),
              ),
            ),
          ),
          ..._buildCornerDecorations(overrideColor: gold),
          Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              children: [
                // Ornate divider
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(width: 60, height: 1, color: gold.withOpacity(0.5)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.diamond, color: gold, size: 20),
                    ),
                    Container(width: 60, height: 1, color: gold.withOpacity(0.5)),
                  ],
                ),
                const SizedBox(height: 20),
                Text('Certificate',
                    style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w300,
                        color: gold,
                        letterSpacing: 6,
                        fontFamily: 'serif')),
                Text('OF COMPLETION',
                    style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        letterSpacing: 6)),
                const SizedBox(height: 28),
                Text('This certifies that',
                    style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey.shade600)),
                const SizedBox(height: 16),
                Text(widget.studentName,
                    style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2C1810),
                        fontFamily: 'serif')),
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 200,
                  height: 1,
                  color: gold,
                ),
                Text('has completed the course',
                    style: TextStyle(
                        fontSize: 14, color: Colors.grey.shade600)),
                const SizedBox(height: 14),
                Text(widget.courseName,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2C1810),
                        fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                // Elegant ribbon-style badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [gold.withOpacity(0.8), gold, gold.withOpacity(0.8)],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${_getPerformanceGrade()} · ${(widget.performance * 100).toInt()}%',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 1),
                  ),
                ),
                const SizedBox(height: 28),
                _buildDateRow(),
                const SizedBox(height: 36),
                _buildSignatureSection(),
                const SizedBox(height: 20),
                // Ornate bottom divider
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(width: 60, height: 1, color: gold.withOpacity(0.5)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.diamond, color: gold, size: 14),
                    ),
                    Container(width: 60, height: 1, color: gold.withOpacity(0.5)),
                  ],
                ),
                const SizedBox(height: 16),
                _buildCertificateId(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ──────────── MINIMAL TEMPLATE ────────────
  Widget _buildMinimalCertificate() {
    final perfColor = _getPerformanceColor();
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 600),
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.school_rounded, color: AppTheme.primaryColor, size: 28),
              const SizedBox(width: 10),
              const Text('eduVerse',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor)),
              const Spacer(),
              Text(_getPerformanceGrade(),
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: perfColor)),
            ],
          ),
          const SizedBox(height: 40),
          Text('Certificate of Completion',
              style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text(widget.studentName,
              style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  height: 1.1)),
          const SizedBox(height: 20),
          Container(width: 50, height: 3, color: perfColor),
          const SizedBox(height: 20),
          Text(widget.courseName,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          Text(
              'Completed on ${DateFormat('MMMM d, yyyy').format(widget.completionDate)}',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
          Text(
              'Score: ${(widget.performance * 100).toInt()}%',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
          const SizedBox(height: 48),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Anees',
                      style: TextStyle(
                          fontSize: 22,
                          fontFamily: 'cursive',
                          fontStyle: FontStyle.italic,
                          color: AppTheme.primaryColor)),
                  Container(width: 120, height: 1, color: Colors.grey.shade300),
                  const SizedBox(height: 4),
                  Text('Anees · Founder',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
              const Spacer(),
              Text(
                  'ID: EDU-${widget.completionDate.millisecondsSinceEpoch.toString().substring(0, 10)}',
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade400,
                      letterSpacing: 0.5)),
            ],
          ),
        ],
      ),
    );
  }

  // ──────────── Shared Components ────────────

  Widget _buildLogoRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.school_rounded, color: Colors.white, size: 32),
        ),
        const SizedBox(width: 12),
        const Text('eduVerse',
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
                letterSpacing: 1)),
      ],
    );
  }

  Widget _buildTitle() {
    return Column(
      children: [
        Text('CERTIFICATE',
            style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w300,
                color: _getPerformanceColor(),
                letterSpacing: 8)),
        const SizedBox(height: 4),
        Text('OF COMPLETION',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w300,
                color: Colors.grey.shade600,
                letterSpacing: 4)),
      ],
    );
  }

  Widget _buildDecoLine() {
    return Container(
      width: 100,
      height: 2,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.transparent, _getPerformanceColor(), Colors.transparent],
        ),
      ),
    );
  }

  Widget _buildCertifyText() {
    return Text('This is to certify that',
        style: TextStyle(
            fontSize: 16, color: Colors.grey.shade600, fontStyle: FontStyle.italic));
  }

  Widget _buildStudentName() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _getPerformanceColor(), width: 2),
        ),
      ),
      child: Text(widget.studentName,
          style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
              fontFamily: 'serif'),
          textAlign: TextAlign.center),
    );
  }

  Widget _buildCourseCompleted() {
    return Text('has successfully completed the course',
        style: TextStyle(fontSize: 16, color: Colors.grey.shade600));
  }

  Widget _buildCourseBox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: _getPerformanceColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _getPerformanceColor().withOpacity(0.3)),
      ),
      child: Text(widget.courseName,
          style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: _getPerformanceColor()),
          textAlign: TextAlign.center),
    );
  }

  Widget _buildPerformanceBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: _getPerformanceColor(),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(
            'Performance: ${_getPerformanceGrade()} (${(widget.performance * 100).toInt()}%)',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildDateRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade500),
        const SizedBox(width: 8),
        Text(
          'Completed on ${DateFormat('MMMM d, yyyy').format(widget.completionDate)}',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildSignatureSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
              child: Text('Anees',
                  style: TextStyle(
                      fontSize: 28,
                      fontFamily: 'cursive',
                      fontStyle: FontStyle.italic,
                      color: AppTheme.primaryColor)),
            ),
            Container(width: 150, height: 1, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text('Anees',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700)),
            Text('Founder & CEO',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          ],
        ),
      ],
    );
  }

  Widget _buildCertificateId() {
    return Text(
      'Certificate ID: EDU-${widget.completionDate.millisecondsSinceEpoch.toString().substring(0, 10)}',
      style: TextStyle(
          fontSize: 10, color: Colors.grey.shade400, letterSpacing: 1),
    );
  }

  List<Widget> _buildCornerDecorations({Color? overrideColor}) {
    final color = overrideColor ?? _getPerformanceColor();
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
