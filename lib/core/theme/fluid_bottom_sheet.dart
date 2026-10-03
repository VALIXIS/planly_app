import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Helper to show modal bottom sheets with custom spring curve transitions
/// (`Curves.easeOutBack`) and haptic tactile feedback.
Future<T?> showFluidModalBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color? backgroundColor,
  double? elevation,
  ShapeBorder? shape,
  Clip? clipBehavior,
  BoxConstraints? constraints,
  Color? barrierColor,
  bool isScrollControlled = false,
  bool useRootNavigator = false,
  bool isDismissible = true,
  bool enableDrag = true,
  bool? showDragHandle,
  bool useSafeArea = false,
  RouteSettings? routeSettings,
  AnimationController? transitionAnimationController,
  Offset? anchorPoint,
  bool triggerHaptic = true,
}) {
  if (triggerHaptic) {
    HapticFeedback.lightImpact();
  }

  return showModalBottomSheet<T>(
    context: context,
    builder: builder,
    backgroundColor: backgroundColor,
    elevation: elevation,
    shape: shape,
    clipBehavior: clipBehavior,
    constraints: constraints,
    barrierColor: barrierColor,
    isScrollControlled: isScrollControlled,
    useRootNavigator: useRootNavigator,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    showDragHandle: showDragHandle,
    useSafeArea: useSafeArea,
    routeSettings: routeSettings,
    transitionAnimationController: transitionAnimationController,
    anchorPoint: anchorPoint,
    sheetAnimationStyle: AnimationStyle(
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
      duration: const Duration(milliseconds: 380),
      reverseDuration: const Duration(milliseconds: 250),
    ),
  );
}
