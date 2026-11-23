import 'package:flutter/material.dart';

import '../../../models/letan_c1/letan_design_system_c1.dart';

/// Thanh 2 nút điều khiển dưới đáy theo Figma: "Không duyệt hết" & "Duyệt hết (X)"
class CskhBulkActionBarC1 extends StatelessWidget {
  final int totalCount;
  final VoidCallback onRejectAll;
  final VoidCallback onApproveAll;

  const CskhBulkActionBarC1({
    super.key,
    required this.totalCount,
    required this.onRejectAll,
    required this.onApproveAll,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppDesignSystemC1.laCheDoToi;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppDesignSystemC1.darkSurface : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppDesignSystemC1.darkBorder : const Color(0xFFF1F5F9),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: AppDesignSystemC1.scale(context, 46),
              child: ElevatedButton.icon(
                onPressed: onRejectAll,
                icon: Icon(Icons.close_rounded, size: AppDesignSystemC1.scale(context, 18)),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Không duyệt hết',
                    style: TextStyle(
                      fontSize: AppDesignSystemC1.scale(context, 13.5),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2),
                  foregroundColor: const Color(0xFFDC2626),
                  side: const BorderSide(color: Color(0xFFF87171)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ),
          ),
          SizedBox(width: AppDesignSystemC1.scale(context, 10)),
          Expanded(
            child: SizedBox(
              height: AppDesignSystemC1.scale(context, 46),
              child: ElevatedButton.icon(
                onPressed: onApproveAll,
                icon: Icon(Icons.check_rounded, size: AppDesignSystemC1.scale(context, 18)),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Duyệt hết ($totalCount)',
                    style: TextStyle(
                      fontSize: AppDesignSystemC1.scale(context, 13.5),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
