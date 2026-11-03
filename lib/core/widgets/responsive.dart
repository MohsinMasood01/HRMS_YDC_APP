import 'package:flutter/widgets.dart';

/// Window-width breakpoints (logical px), following Material 3 window size
/// classes: compact < 600 (phones), medium 600-839 (small tablets, foldables,
/// phones in landscape), expanded >= 840 (tablets, Chromebooks).
abstract final class Breakpoints {
  static const double medium = 600;
  static const double expanded = 840;
}

/// Widest a column of page content may grow before it is centred, so cards
/// and text stay a comfortable width on tablets instead of spanning 2,500 px.
const double kMaxContentWidth = 840;

extension ResponsiveContext on BuildContext {
  double get windowWidth => MediaQuery.sizeOf(this).width;

  /// Medium or wider: tablets, foldables, phones in landscape.
  bool get isMediumUp => windowWidth >= Breakpoints.medium;

  /// Expanded: tablets in landscape, Chromebooks.
  bool get isExpanded => windowWidth >= Breakpoints.expanded;

  /// Columns for a grid of cards at the current width.
  int gridColumns({int compact = 1, int medium = 2, int expanded = 3}) =>
      isExpanded ? expanded : (isMediumUp ? medium : compact);
}

/// Centres [child] in a column at most [maxWidth] wide.
///
/// A no-op on phones. Uses padding rather than Center/Align so the child
/// still receives tight constraints and fills the full height, which keeps
/// scroll views, Expanded and Spacer behaving exactly as on a phone.
class ResponsiveBody extends StatelessWidget {
  const ResponsiveBody({
    super.key,
    required this.child,
    this.maxWidth = kMaxContentWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final extra = constraints.maxWidth - maxWidth;
        if (!constraints.hasBoundedWidth || extra <= 0) return child;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: extra / 2),
          child: child,
        );
      },
    );
  }
}
