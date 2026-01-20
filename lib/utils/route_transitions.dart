import 'package:flutter/material.dart';

/// Fast page route with minimal transition duration for snappy navigation
class FastPageRoute<T> extends MaterialPageRoute<T> {
  FastPageRoute({
    required super.builder,
    super.settings,
    super.maintainState,
    super.fullscreenDialog,
  });

  @override
  Duration get transitionDuration => const Duration(milliseconds: 150);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 100);
}

/// Slide transition route for smooth horizontal sliding
class SlideRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final Duration duration;
  final SlideDirection direction;

  SlideRoute({
    required this.page,
    this.duration = const Duration(milliseconds: 200),
    this.direction = SlideDirection.right,
    super.settings,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: duration,
          reverseTransitionDuration: const Duration(milliseconds: 150),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final begin = direction == SlideDirection.right
                ? const Offset(1.0, 0.0)
                : direction == SlideDirection.left
                    ? const Offset(-1.0, 0.0)
                    : direction == SlideDirection.up
                        ? const Offset(0.0, 1.0)
                        : const Offset(0.0, -1.0);
            const end = Offset.zero;
            final curve = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );
            return SlideTransition(
              position: Tween<Offset>(begin: begin, end: end).animate(curve),
              child: child,
            );
          },
        );
}

enum SlideDirection { left, right, up, down }

/// Fade transition route for smooth fading
class FadeRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final Duration duration;

  FadeRoute({
    required this.page,
    this.duration = const Duration(milliseconds: 200),
    super.settings,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: duration,
          reverseTransitionDuration: const Duration(milliseconds: 150),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
              child: child,
            );
          },
        );
}

/// Combined slide and fade for premium feel
class SlideAndFadeRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final Duration duration;

  SlideAndFadeRoute({
    required this.page,
    this.duration = const Duration(milliseconds: 200),
    super.settings,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionDuration: duration,
          reverseTransitionDuration: const Duration(milliseconds: 150),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curve = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.05, 0.0),
                end: Offset.zero,
              ).animate(curve),
              child: FadeTransition(
                opacity: curve,
                child: child,
              ),
            );
          },
        );
}

/// Extension for easy navigation with fast routes
extension FastNavigator on NavigatorState {
  Future<T?> pushFast<T extends Object?>(Widget page, {RouteSettings? settings}) {
    return push<T>(FastPageRoute<T>(
      builder: (_) => page,
      settings: settings,
    ));
  }

  Future<T?> pushSlide<T extends Object?>(
    Widget page, {
    RouteSettings? settings,
    SlideDirection direction = SlideDirection.right,
    Duration duration = const Duration(milliseconds: 200),
  }) {
    return push<T>(SlideRoute<T>(
      page: page,
      settings: settings,
      direction: direction,
      duration: duration,
    ));
  }

  Future<T?> pushFade<T extends Object?>(
    Widget page, {
    RouteSettings? settings,
    Duration duration = const Duration(milliseconds: 200),
  }) {
    return push<T>(FadeRoute<T>(
      page: page,
      settings: settings,
      duration: duration,
    ));
  }
}
