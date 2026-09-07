import 'package:flutter/material.dart';

/// docs/06_MOBILE_SPEC.md §Layout `core/theme.dart`:
/// Material 3, seed #1565C0, IMD severity colours, dark mode.
class AppTheme {
  AppTheme._();

  static const Color seed = Color(0xFF1565C0);

  // IMD warning colours (docs/02 §Shared objects).
  static const Color yellow = Color(0xFFF5C518);
  static const Color orange = Color(0xFFF28C28);
  static const Color red = Color(0xFFD32F2F);
  static const Color green = Color(0xFF2E7D32);

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: scheme.surfaceContainerLow,
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }

  /// `Warning.severity` (yellow|orange|red) → colour. docs/04 §Objects.
  static Color warningSeverityColor(String? severity) {
    switch (severity) {
      case 'red':
        return red;
      case 'orange':
        return orange;
      case 'yellow':
        return yellow;
      default:
        return green;
    }
  }

  /// `Card.severity` (info|advisory|watch|warning|severe) → accent colour for the card
  /// shell's left bar. docs/02 §Card anatomy maps urgency bands onto these five names.
  static Color cardSeverityColor(String? severity, ColorScheme scheme) {
    switch (severity) {
      case 'severe':
        return red;
      case 'warning':
        return orange;
      case 'watch':
        return yellow;
      case 'advisory':
        return scheme.tertiary;
      case 'info':
      default:
        return scheme.primary;
    }
  }

  /// CPCB AQI band colours (docs/02 card 7 — Good…Severe).
  static Color aqiColor(num? aqi) {
    final v = (aqi ?? 0).toDouble();
    if (v <= 50) return const Color(0xFF2E7D32); // Good
    if (v <= 100) return const Color(0xFF9CCC65); // Satisfactory
    if (v <= 200) return const Color(0xFFF5C518); // Moderate
    if (v <= 300) return const Color(0xFFF28C28); // Poor
    if (v <= 400) return const Color(0xFFD32F2F); // Very Poor
    return const Color(0xFF7B1FA2); // Severe
  }
}
