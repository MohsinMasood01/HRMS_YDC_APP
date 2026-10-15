import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppCard extends StatelessWidget {
  AppCard({
    required this.child,
    super.key,
    EdgeInsets? padding,
    this.onTap,
  }) : padding = padding ?? EdgeInsets.all(16.w);

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Card(
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
    if (onTap != null) {
      return InkWell(onTap: onTap, child: card);
    }
    return card;
  }
}
