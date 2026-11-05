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

    return SafeArea(child: scrollView);
  }
}
