import 'dart:ui';
import 'package:flutter/material.dart';

/// Shows a dialog with a blurred background effect.
///
/// This function wraps [showGeneralDialog] and adds a [BackdropFilter] with
/// a blur effect behind the dialog content.
Future<T?> showBlurDialog<T>({
  required BuildContext context,
  required Widget Function(BuildContext) builder,
  bool barrierDismissible = true,
  Color barrierColor = const Color(0x80000000),
  double blurAmount = 5.0,
  Duration transitionDuration = const Duration(milliseconds: 200),
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: transitionDuration,
    pageBuilder: (context, animation, secondaryAnimation) {
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
        child: Container(
          color: barrierColor,
          child: Center(
            child: builder(context),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
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
