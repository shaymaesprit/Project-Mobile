import 'package:flutter/material.dart';

/// Palette StudyMate « Aurora » : indigo électrique, menthe et corail
/// sur des fonds doux. Toute l'app lit ses couleurs depuis ici.
abstract final class AppPalette {
  static const indigo = Color(0xFF5546FF);
  static const violet = Color(0xFF8B5CF6);
  static const pink = Color(0xFFEC4899);
  static const mint = Color(0xFF14C9A5);
  static const coral = Color(0xFFFF7A59);
  static const amber = Color(0xFFFFB020);
  static const sky = Color(0xFF38BDF8);

  // Clair
  static const lightBackground = Color(0xFFF5F6FB);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceAlt = Color(0xFFEEEFFA);
  static const lightOutline = Color(0xFFE4E5F1);
  static const lightInk = Color(0xFF14152B);
  static const lightMuted = Color(0xFF646785);

  // Sombre
  static const darkBackground = Color(0xFF0B0D1A);
  static const darkSurface = Color(0xFF151829);
  static const darkSurfaceAlt = Color(0xFF1E2238);
  static const darkOutline = Color(0xFF2A2F4A);
  static const darkInk = Color(0xFFECEDF7);
  static const darkMuted = Color(0xFF9EA2C0);

  /// Couleurs d'accent pour différencier les cours, notes, etc.
  static const accents = [indigo, mint, coral, violet, sky, amber, pink];

  static Color accentFor(String key) =>
      accents[key.codeUnits.fold<int>(0, (a, b) => a + b) % accents.length];
}

/// Dégradés de marque. Le dégradé du héros change selon le moment de la
/// journée : aube le matin, indigo l'après-midi, nuit le soir.
abstract final class AppGradients {
  static const brand = LinearGradient(
    colors: [AppPalette.indigo, AppPalette.violet, AppPalette.pink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient forHour(int hour) {
    if (hour >= 5 && hour < 12) {
      return const LinearGradient(
        colors: [Color(0xFFFF8A4C), Color(0xFFFF5E8A), AppPalette.violet],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
    }
    if (hour >= 12 && hour < 18) return brand;
    return const LinearGradient(
      colors: [Color(0xFF1E1B4B), Color(0xFF4338CA), AppPalette.violet],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
}

abstract final class AppTheme {
  static const radius = 22.0;

  static ThemeData get light => _build(
        Brightness.light,
        background: AppPalette.lightBackground,
        surface: AppPalette.lightSurface,
        surfaceAlt: AppPalette.lightSurfaceAlt,
        outline: AppPalette.lightOutline,
        ink: AppPalette.lightInk,
        muted: AppPalette.lightMuted,
      );

  static ThemeData get dark => _build(
        Brightness.dark,
        background: AppPalette.darkBackground,
        surface: AppPalette.darkSurface,
        surfaceAlt: AppPalette.darkSurfaceAlt,
        outline: AppPalette.darkOutline,
        ink: AppPalette.darkInk,
        muted: AppPalette.darkMuted,
      );

  static ThemeData _build(
    Brightness brightness, {
    required Color background,
    required Color surface,
    required Color surfaceAlt,
    required Color outline,
    required Color ink,
    required Color muted,
  }) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppPalette.indigo,
      brightness: brightness,
    ).copyWith(
      primary: isDark ? const Color(0xFF8F86FF) : AppPalette.indigo,
      onPrimary: Colors.white,
      primaryContainer:
          isDark ? const Color(0xFF2B2670) : const Color(0xFFE6E3FF),
      onPrimaryContainer:
          isDark ? const Color(0xFFE2DEFF) : const Color(0xFF1C1478),
      secondary: AppPalette.mint,
      onSecondary: const Color(0xFF00382E),
      secondaryContainer:
          isDark ? const Color(0xFF0F3B35) : const Color(0xFFD5F7EF),
      onSecondaryContainer:
          isDark ? const Color(0xFFB6F2E4) : const Color(0xFF00473B),
      tertiary: AppPalette.coral,
      onTertiary: Colors.white,
      tertiaryContainer:
          isDark ? const Color(0xFF4A2418) : const Color(0xFFFFE6DD),
      onTertiaryContainer:
          isDark ? const Color(0xFFFFD6C8) : const Color(0xFF6B2410),
      surface: surface,
      onSurface: ink,
      onSurfaceVariant: muted,
      surfaceContainerLowest: background,
      surfaceContainerLow: surface,
      surfaceContainer: surfaceAlt,
      surfaceContainerHigh: surfaceAlt,
      surfaceContainerHighest: surfaceAlt,
      outline: muted,
      outlineVariant: outline,
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: brightness,
    );
    final text = base.textTheme.apply(bodyColor: ink, displayColor: ink);
    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );
    final pill = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    );
    const buttonPadding = EdgeInsets.symmetric(horizontal: 22, vertical: 16);
    const buttonText = TextStyle(fontWeight: FontWeight.w700, fontSize: 15);

    return base.copyWith(
      scaffoldBackgroundColor: background,
      splashFactory: InkSparkle.splashFactory,
      textTheme: text.copyWith(
        headlineLarge: text.headlineLarge
            ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1),
        headlineMedium: text.headlineMedium
            ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.8),
        headlineSmall: text.headlineSmall
            ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        titleLarge: text.titleLarge
            ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: surface,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: rounded.copyWith(side: BorderSide(color: outline)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceAlt,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        prefixIconColor: muted,
        suffixIconColor: muted,
        labelStyle: TextStyle(color: muted),
        floatingLabelStyle:
            TextStyle(color: scheme.primary, fontWeight: FontWeight.w600),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: outline.withValues(alpha: 0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.error, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: buttonPadding,
          shape: pill,
          textStyle: buttonText,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: buttonPadding,
          shape: pill,
          textStyle: buttonText,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: buttonPadding,
          shape: pill,
          textStyle: buttonText,
          foregroundColor: ink,
          side: BorderSide(color: outline, width: 1.4),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: pill,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        highlightElevation: 6,
        shape: pill,
        extendedTextStyle: buttonText,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surface,
        selectedColor: scheme.primaryContainer,
        side: BorderSide(color: outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        labelStyle: TextStyle(color: ink, fontWeight: FontWeight.w600),
        showCheckmark: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        elevation: 0,
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        indicatorShape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color:
                states.contains(WidgetState.selected) ? scheme.primary : muted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color:
                states.contains(WidgetState.selected) ? scheme.primary : muted,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: surface,
        indicatorColor: scheme.primaryContainer,
        selectedIconTheme: IconThemeData(color: scheme.primary),
        unselectedIconTheme: IconThemeData(color: muted),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: muted,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: BorderSide(color: muted, width: 1.6),
      ),
      dividerTheme: DividerThemeData(color: outline, thickness: 1, space: 1),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: surfaceAlt,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? surfaceAlt : ink,
        contentTextStyle: TextStyle(color: isDark ? ink : Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: rounded,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      badgeTheme: const BadgeThemeData(backgroundColor: AppPalette.coral),
    );
  }
}
