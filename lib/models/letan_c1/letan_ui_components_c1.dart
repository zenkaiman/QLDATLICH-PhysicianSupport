import 'package:flutter/material.dart';
import 'letan_design_system_c1.dart';

/// WIDGET HIỆU ỨNG SKELETON SHIMMER TẢI DỮ LIỆU
class SkeletonItemC1 extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonItemC1({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 12,
  });

  @override
  State<SkeletonItemC1> createState() => _SkeletonItemC1State();
}

class _SkeletonItemC1State extends State<SkeletonItemC1> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.8).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0).withValues(alpha: _animation.value),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}

/// SKELETON LIST DÀNH CHO LỊCH HẸN VÀ BỆNH NHÂN
class SkeletonLichHenListC1 extends StatelessWidget {
  const SkeletonLichHenListC1({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppDesignSystemC1.borderRadMedium,
            border: Border.all(color: AppDesignSystemC1.border),
          ),
          child: const Row(
            children: [
              SkeletonItemC1(width: 44, height: 44, borderRadius: 14),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonItemC1(width: 140, height: 16),
                    SizedBox(height: 8),
                    SkeletonItemC1(width: 180, height: 12),
                    SizedBox(height: 6),
                    SkeletonItemC1(width: 100, height: 12),
                  ],
                ),
              ),
              SkeletonItemC1(width: 65, height: 26, borderRadius: 8),
            ],
          ),
        );
      },
    );
  }
}

/// EMPTY STATE ĐẸP MẮT THEO CHUẨN M3
class EmptyStateWidgetC1 extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final VoidCallback? onRetry;

  const EmptyStateWidgetC1({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.event_busy_outlined,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppDesignSystemC1.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: AppDesignSystemC1.primary),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                color: AppDesignSystemC1.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppDesignSystemC1.textSecondary,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 18),
              FilledButton.tonal(
                onPressed: () {
                  AppDesignSystemC1.hapticLight();
                  onRetry!();
                },
                child: const Text('Thử Lại'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
