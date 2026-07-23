import 'package:flutter/material.dart';

class PetfyPanelColors {
  const PetfyPanelColors({
    required this.background,
    required this.menuBackground,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.text,
    required this.subtleText,
    required this.icon,
    required this.pathText,
    required this.dismissBackground,
    required this.dismissIcon,
    required this.infoBackground,
    required this.infoBorder,
    required this.infoIcon,
    required this.danger,
    required this.isDark,
  });

  factory PetfyPanelColors.fromDarkMode(bool dark) {
    if (dark) {
      return const PetfyPanelColors(
        background: Color(0xF20F172A),
        menuBackground: Color(0xFF111827),
        surface: Color(0xFF1E293B),
        surfaceMuted: Color(0xFF172033),
        border: Color(0xFF334155),
        text: Color(0xFFE5E7EB),
        subtleText: Color(0xFF94A3B8),
        icon: Color(0xFFCBD5E1),
        pathText: Color(0xFF94A3B8),
        dismissBackground: Color(0xFF263244),
        dismissIcon: Color(0xFFE5E7EB),
        infoBackground: Color(0xFF172554),
        infoBorder: Color(0xFF1D4ED8),
        infoIcon: Color(0xFF93C5FD),
        danger: Color(0xFFFCA5A5),
        isDark: true,
      );
    }

    return PetfyPanelColors(
      background: Colors.white.withValues(alpha: 0.96),
      menuBackground: Colors.white,
      surface: const Color(0xFFF8FAFC),
      surfaceMuted: const Color(0xFFF1F5F9),
      border: const Color(0xFFE2E8F0),
      text: const Color(0xFF111827),
      subtleText: const Color(0xFF64748B),
      icon: const Color(0xFF475569),
      pathText: const Color(0xFF64748B),
      dismissBackground: const Color(0xFFE2E8F0),
      dismissIcon: const Color(0xFF334155),
      infoBackground: const Color(0xFFEFF6FF),
      infoBorder: const Color(0xFFDBEAFE),
      infoIcon: const Color(0xFF2563EB),
      danger: const Color(0xFFB91C1C),
      isDark: false,
    );
  }

  final Color background;
  final Color menuBackground;
  final Color surface;
  final Color surfaceMuted;
  final Color border;
  final Color text;
  final Color subtleText;
  final Color icon;
  final Color pathText;
  final Color dismissBackground;
  final Color dismissIcon;
  final Color infoBackground;
  final Color infoBorder;
  final Color infoIcon;
  final Color danger;
  final bool isDark;
}
