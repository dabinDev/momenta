import 'package:flutter/material.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.status,
  });

  final String status;

  @override
  Widget build(BuildContext context) {
    late final Color background;
    late final Color foreground;
    late final String label;

    switch (status) {
      case 'completed':
        background = const Color(0xFFDDEFE7);
        foreground = const Color(0xFF2D5E4F);
        label = '已完成';
      case 'failed':
        background = const Color(0xFFF5DFDA);
        foreground = const Color(0xFF9F4238);
        label = '失败';
      default:
        background = const Color(0xFFF4E8D3);
        foreground = const Color(0xFF91653B);
        label = '处理中';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}
