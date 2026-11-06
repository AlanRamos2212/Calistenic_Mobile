import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class FrameScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final Future<void> Function()? onRefresh;

  const FrameScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    Widget scrollView = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverAppBar(
          leadingWidth: 52,
          leading: Padding(
            padding: const EdgeInsets.only(left: 14, top: 8, bottom: 8),
            child: Image.asset(
              'assets/images/logo1.png',
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.bolt, color: AppColors.blue),
            ),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          floating: true,
          backgroundColor: AppColors.bg,
          actions: actions,
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          sliver: SliverToBoxAdapter(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: child,
            ),
          ),
        ),
      ],
    );

    if (onRefresh != null) {
      scrollView = RefreshIndicator(
        onRefresh: onRefresh!,
        color: AppColors.blue,
        backgroundColor: AppColors.card,
        child: scrollView,
      );
    }

    // Material: pushed routes (MaterialPageRoute) wrap pages in a Material, but
    // tabs inside a Scaffold need the color anyway; providing it here gives
    // TextField/InkWell a valid Material ancestor and the intended background.
    return Material(
      color: AppColors.bg,
      child: SafeArea(child: scrollView),
    );
  }
}
