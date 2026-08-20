import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Mosaic Player — original premium visual identity.
///
/// Fresh language: layered glass cards, soft aurora gradients, large visual
/// media and micro-interactions. Deliberately distinct from any existing
/// media player branding.
class AppTheme {
  AppTheme._();

  // ─── Deep palette (dark mode) ─────────────────────────────────────────
  static const Color deep = Color(0xFF080A12);
  static const Color surface = Color(0xFF10131F);
  static const Color surfaceRaised = Color(0xFF161A2B);
  static const Color line = Color(0x1AFFFFFF);

  // ─── Light palette ────────────────────────────────────────────────────
  static const Color lightDeep = Color(0xFFF6F7FB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightLine = Color(0x140A0F1E);

  // ─── Text ─────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFFF2F3FF);
  static const Color textSecondary = Color(0xFF9AA0B8);
  static const Color textLightPrimary = Color(0xFF141A2E);
  static const Color textLightSecondary = Color(0xFF5C6484);

  /// The active accent (aurora violet by default).
  static Color accent = const Color(0xFF8B7CFF);

  /// Accent presets the user can pick from.
  static const List<Color> accentPresets = [
    Color(0xFF8B7CFF), // Aurora
    Color(0xFFFF7A59), // Ember
    Color(0xFF38BDF8), // Ocean
    Color(0xFF2DD4BF), // Mint
    Color(0xFFF472B6), // Rose
  ];

  static const List<String> accentNames =
      ['Aurora', 'Ember', 'Ocean', 'Mint', 'Rose'];

  static Color get accentSoft => accent.withValues(alpha: 0.16);
  static Color get accentGlow => accent.withValues(alpha: 0.35);

  /// Signature aurora gradient — the app's visual hallmark.
  static LinearGradient get auroraGradient => LinearGradient(
        colors: [accent, const Color(0xFF4CC9F0), const Color(0xFFFFB199)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  /// A calmer 2-stop variant for buttons.
  static LinearGradient get pillGradient => LinearGradient(
        colors: [accent, const Color(0xFF6D5CFF)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      );

  /// A deterministic per-title gradient used for generated artwork.
  static LinearGradient artworkGradient(String seed, {int variant = 0}) {
    final palette = [
      [const Color(0xFF7C6CFF), const Color(0xFF4CC9F0)],
      [const Color(0xFFFF7A59), const Color(0xFFF472B6)],
      [const Color(0xFF2DD4BF), const Color(0xFF38BDF8)],
      [const Color(0xFFF472B6), const Color(0xFF8B5CF6)],
      [const Color(0xFFFACC15), const Color(0xFFFF7A59)],
      [const Color(0xFF34D399), const Color(0xFF38BDF8)],
    ];
    var h = 0;
    for (final c in seed.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    final pair = palette[(h + variant) % palette.length];
    return LinearGradient(
        colors: pair, begin: Alignment.topLeft, end: Alignment.bottomRight);
  }

  // ─── Glass / layered card styling ─────────────────────────────────────
  static bool _isDarkGlobal = true;

  static BoxDecoration glass(
      {double radius = 20, Color? tint, Color? borderColor}) {
    final dark = _isDarkGlobal;
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [
          (tint ?? Colors.white).withValues(alpha: dark ? 0.06 : 0.55),
          (tint ?? Colors.white).withValues(alpha: dark ? 0.03 : 0.35),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: borderColor ??
            (dark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05)),
      ),
    );
  }

  /// A prominent raised card with the aurora glow used for hero sections.
  static BoxDecoration heroCard({double radius = 24}) => BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.92),
            const Color(0xFF4CC9F0).withValues(alpha: 0.86),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      );

  // ─── Mood colors ───────────────────────────────────────────────────────
  static const Map<String, Color> moodColors = {
    'happy': Color(0xFFFFD700),
    'sad': Color(0xFF4A90D9),
    'focus': Color(0xFF00D4AA),
    'chill': Color(0xFF9B59B6),
    'workout': Color(0xFFFF4757),
  };

  static ThemeData buildTheme({required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;
    _isDarkGlobal = isDark;
    final bg = isDark ? deep : lightDeep;
    final surfaceColor = isDark ? surface : lightSurface;
    final primaryText = isDark ? textPrimary : textLightPrimary;

    final scheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
      surface: surfaceColor,
    );

    final baseText =
        isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: bg,
      colorScheme: scheme.copyWith(
        primary: accent,
        secondary: const Color(0xFF4CC9F0),
        tertiary: const Color(0xFFFFB199),
        onPrimary: Colors.white,
      ),
      textTheme: GoogleFonts.soraTextTheme(baseText).apply(
        bodyColor: primaryText,
        displayColor: primaryText,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.sora(
          color: primaryText,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: primaryText),
      ),
    );
  }
}

/// Shared UI formatting helpers.
class AppThemeHelpers {
  AppThemeHelpers._();

  /// Formats a [Duration] as `mm:ss`, or `h:mm:ss` when it exceeds an hour.
  static String formatDuration(Duration d) {
    final total = d.inSeconds;
    final hours = total ~/ 3600;
    final minutes = (total % 3600) ~/ 60;
    final seconds = total % 60;
    if (hours > 0) {
      return '$hours:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
