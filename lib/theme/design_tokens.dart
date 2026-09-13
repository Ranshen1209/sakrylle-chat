import 'package:flutter/material.dart';

class AppShadows {
  static List<BoxShadow> soft = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ];
}

/// Shared desktop popover wash. Alpha is unchanged from the previous
/// per-popover literals (`surface` @ 0.28 dark / 0.56 light).
class AppOverlayColors {
  static const double desktopPopoverAlphaDark = 0.28;
  static const double desktopPopoverAlphaLight = 0.56;

  static Color desktopPopoverSurface(ColorScheme cs) {
    final isDark = cs.brightness == Brightness.dark;
    return cs.surface.withValues(
      alpha: isDark ? desktopPopoverAlphaDark : desktopPopoverAlphaLight,
    );
  }
}

class AppRadii {
  static const double capsule = 28; // 既有，保留
  static const double sm = 12; // 按钮/输入框
  static const double md = 16; // 卡片/模态
  static const double full = 999; // 徽章/开关/头像
}

class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20; // 既有，保留
  static const double xl = 32; // 新增
}

class SakrylleColors {
  static const Color monetPurple = Color(0xFF9181BD); // primary-500
  static const Color monetPurpleDark = Color(0xFF7B6AAB); // primary-600
  static const Color primary700 = Color(
    0xFF5E4F86,
  ); // primary-700; contrast vs white = 7.15:1 ≥ 4.5 (WCAG AA)
  static const Color sakura = Color(0xFFEC6A9C); // accent
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF9181BD);
}
