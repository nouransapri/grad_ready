import 'package:flutter/material.dart';

/// When [error] is non-null, shows [errorBuilder](error); otherwise [child].
class ErrorBoundary extends StatelessWidget {
  const ErrorBoundary({
    super.key,
    required this.child,
    required this.errorBuilder,
    this.error,
  });

  final Widget child;
  final Widget Function(Object error) errorBuilder;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    final e = error;
    if (e != null) return errorBuilder(e);
    return child;
  }
}
