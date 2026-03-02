import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:eduverse/services/platform_settings_service.dart';

/// Wraps the app to track user activity and auto-sign out after
/// [sessionTimeoutMinutes] of inactivity (from platform settings).
class SessionTimeoutWrapper extends StatefulWidget {
  final Widget child;
  const SessionTimeoutWrapper({super.key, required this.child});

  @override
  State<SessionTimeoutWrapper> createState() => _SessionTimeoutWrapperState();
}

class _SessionTimeoutWrapperState extends State<SessionTimeoutWrapper>
    with WidgetsBindingObserver {
  Timer? _inactivityTimer;
  int _timeoutMinutes = 0; // 0 = disabled

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTimeout();
  }

  Future<void> _loadTimeout() async {
    try {
      await PlatformSettingsService.instance.ensureLoaded();
      _timeoutMinutes =
          PlatformSettingsService.instance.sessionTimeoutMinutes;
      _resetTimer();
    } catch (_) {}
  }

  void _resetTimer() {
    _inactivityTimer?.cancel();
    if (_timeoutMinutes <= 0) return;
    if (FirebaseAuth.instance.currentUser == null) return;

    _inactivityTimer = Timer(Duration(minutes: _timeoutMinutes), _onTimeout);
  }

  void _onTimeout() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseAuth.instance.signOut();

    // Navigate to sign-in screen
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Session expired due to inactivity. Please sign in again.'),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh timeout setting and reset timer when app resumes
      _loadTimeout();
    }
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _resetTimer(),
      onPointerMove: (_) => _resetTimer(),
      child: widget.child,
    );
  }
}
