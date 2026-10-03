import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ShimmerList extends StatefulWidget {
  final int itemCount;

  const ShimmerList({super.key, this.itemCount = 5});

  @override
  State<ShimmerList> createState() => _ShimmerListState();
}

class _ShimmerListState extends State<ShimmerList>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        widget.itemCount,
        (index) => Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, index < widget.itemCount - 1 ? 8 : 0),
          child: _ShimmerCard(animation: _controller),
        ),
      ),
    );
  }
}

class _ShimmerCard extends AnimatedWidget {
  final Animation<double> animation;

  const _ShimmerCard({required this.animation}) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    final value = animation.value;
    final begin = value * 2 - 1.4;
    final end = value * 2 - 0.4;

    final gradient = LinearGradient(
      colors: [
        Colors.grey[100]!,
        Colors.grey[300]!,
        Colors.grey[100]!,
      ],
      stops: const [0, 0.5, 1],
      begin: Alignment(begin, 0),
      end: Alignment(end, 0),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderLight, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: gradient,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  width: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: gradient,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 10,
                  width: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: gradient,
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 14,
            width: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: gradient,
            ),
          ),
        ],
      ),
    );
  }
}
