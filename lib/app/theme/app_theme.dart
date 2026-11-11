import 'package:flutter/material.dart';

/// Mirrors the web app's `.landing-ops` `--oc-*` token system
/// (`carservice.mn/app/globals.css`), which is what the live customer portal
/// (sidebar + page content alike) actually renders — see COWORK.md D-021.
/// Re-synced 2026-11-09 to the web's "Midnight + Alizarin" palette (navy
/// base, #e74c3c accent), replacing the earlier cyan accent (D-086).
abstract final class AppColors {
  static const darkBackground = Color(0xFF1E2B38); // --oc-carbon
  static const darkSurface = Color(0xFF2C3E50); // --oc-panel
  static const darkGlass = Color(0x0AFFFFFF); // --glass-bg
  static const darkGlassStrong = Color(0x12FFFFFF);
  static const darkBorder = Color(0xFF3B5167); // --oc-line
  static const darkInput = Color(0x0AFFFFFF); // --input-bg
  static const darkInputBorder = Color(0xFF3B5167); // --oc-line
  static const darkText = Color(0xFFECF0F1); // --oc-ink
  static const darkTextMuted = Color(0xFFBDC6C8); // --oc-muted
  static const lightBackground = Color(0xFFECF0F1); // --oc-carbon (light)
  static const lightSurface = Color(0xFFFFFFFF); // --oc-panel (light)
  static const lightGlass = Color(0xBFFFFFFF); // --glass-bg (light)
  static const lightGlassStrong = Color(0xE6FFFFFF);
  static const lightBorder = Color(0xFFD5DCDF); // --oc-line (light)
  static const lightInput = Color(0xFFFFFFFF);
  static const lightInputBorder = Color(0xFFD5DCDF); // --oc-line (light)
  static const lightText = Color(0xFF2C3E50); // --oc-ink (light)
  static const lightTextMuted = Color(0xFF5F6B6D); // --oc-muted (light)
  static const accent = Color(0xFFE74C3C); // --oc-accent
  static const accentHover = Color(0xFFF1948A); // --oc-accent-hi
  static const accentLightText = Color(0xFFC0392B); // --oc-accent (light)
  static const onAccent = Color(0xFFFFFFFF); // --oc-on-accent
  static const blue = Color(0xFF5DADE2); // --oc-b6
  static const purple = Color(0xFFBB8FCE); // --oc-b3 (POSTPONED badge)
  static const green = Color(0xFF58D68D); // --oc-ok
  static const red = Color(0xFFFF6467); // web status red (red-400)
  // Neutral grey for inactive map pins (closed branches).
  static const neutral = Color(0xFF95A5A6); // --oc-muted3
  static const warning = Color(0xFFF7C948); // --oc-warn

  // Light-mode text variants. The status colors above are tuned for the dark
  // shell; as text on a white or tinted-white surface they fall to ~1.6–3:1.
  // Use [readable] rather than picking these by hand.
  static const greenLightText = Color(0xFF1E8449); // --oc-ok (light)
  static const warningLightText = Color(0xFF9A6700); // --oc-warn (light)
  static const blueLightText = Color(0xFF2471A3); // --oc-b6 (light)
  static const purpleLightText = Color(0xFF7D3C98); // --oc-b3 (light)
  static const redLightText = Color(0xFFC10007); // red-700

  /// The text/icon color for a status [color] on the current [brightness]:
  /// unchanged in dark mode, a darker readable variant in light mode.
  static Color readable(Color color, Brightness brightness) {
    if (brightness == Brightness.dark) return color;
    if (color == accent) return accentLightText;
    if (color == green) return greenLightText;
    if (color == warning) return warningLightText;
    if (color == blue) return blueLightText;
    if (color == purple) return purpleLightText;
    if (color == red) return redLightText;
    return color;
  }
}

/// Corner radii on the web's scale: `rounded-lg` 8 for compact controls,
/// `rounded-[10px]` for panels/inputs/buttons, `rounded-xl` 12 for cards,
/// `rounded-2xl` 16 for sheets and dialogs.
abstract final class AppRadii {
  static const small = 8.0;
  static const medium = 10.0;
  static const large = 12.0;
  static const extraLarge = 16.0;
  static const pill = 999.0;

  // Customer-app design (2026-11 canvas): controls 14, cards 16, hero 20.
  static const control = 14.0;
  static const card = 16.0;
  static const hero = 20.0;
}

/// Typeface families bundled in `assets/fonts/`. Geist has no tugrik glyph;
/// the platform font fills it in automatically.
abstract final class AppFonts {
  static const sans = 'Geist';
  static const mono = 'GeistMono';
}

@immutable
class CarserviceTheme extends ThemeExtension<CarserviceTheme> {
  const CarserviceTheme({
    required this.shellBackground,
    required this.shellSurface,
    required this.glass,
    required this.glassStrong,
    required this.glassBorder,
    required this.mutedText,
    required this.inputBackground,
    required this.card,
    required this.cardBorder,
    required this.ink,
    required this.hero,
    required this.onHero,
    required this.onHeroMuted,
    required this.inverse,
    required this.onInverse,
    required this.successSoft,
    required this.warningSoft,
    required this.accentSoft,
    required this.link,
  });
  final Color shellBackground;
  final Color shellSurface;
  final Color glass;
  final Color glassStrong;
  final Color glassBorder;
  final Color mutedText;
  final Color inputBackground;

  /// Raised white (light) / panel (dark) card with a 1px [cardBorder].
  final Color card;
  final Color cardBorder;

  /// Primary text: navy on light, near-white on dark.
  final Color ink;

  /// The navy "my car" / status hero card and its text colors.
  final Color hero;
  final Color onHero;
  final Color onHeroMuted;

  /// Selected chip / active nav pill fill and its content color.
  final Color inverse;
  final Color onInverse;

  /// Tinted badge backgrounds (pair with [AppColors.readable] text).
  final Color successSoft;
  final Color warningSoft;
  final Color accentSoft;

  /// Inline text links.
  final Color link;

  static CarserviceTheme of(BuildContext context) =>
      Theme.of(context).extension<CarserviceTheme>()!;

  @override
  CarserviceTheme copyWith({
    Color? shellBackground,
    Color? shellSurface,
    Color? glass,
    Color? glassStrong,
    Color? glassBorder,
    Color? mutedText,
    Color? inputBackground,
    Color? card,
    Color? cardBorder,
    Color? ink,
    Color? hero,
    Color? onHero,
    Color? onHeroMuted,
    Color? inverse,
    Color? onInverse,
    Color? successSoft,
    Color? warningSoft,
    Color? accentSoft,
    Color? link,
  }) => CarserviceTheme(
    shellBackground: shellBackground ?? this.shellBackground,
    shellSurface: shellSurface ?? this.shellSurface,
    glass: glass ?? this.glass,
    glassStrong: glassStrong ?? this.glassStrong,
    glassBorder: glassBorder ?? this.glassBorder,
    mutedText: mutedText ?? this.mutedText,
    inputBackground: inputBackground ?? this.inputBackground,
    card: card ?? this.card,
    cardBorder: cardBorder ?? this.cardBorder,
    ink: ink ?? this.ink,
    hero: hero ?? this.hero,
    onHero: onHero ?? this.onHero,
    onHeroMuted: onHeroMuted ?? this.onHeroMuted,
    inverse: inverse ?? this.inverse,
    onInverse: onInverse ?? this.onInverse,
    successSoft: successSoft ?? this.successSoft,
    warningSoft: warningSoft ?? this.warningSoft,
    accentSoft: accentSoft ?? this.accentSoft,
    link: link ?? this.link,
  );

  @override
  CarserviceTheme lerp(CarserviceTheme? other, double t) {
    if (other == null) return this;
    return CarserviceTheme(
      shellBackground: Color.lerp(shellBackground, other.shellBackground, t)!,
      shellSurface: Color.lerp(shellSurface, other.shellSurface, t)!,
      glass: Color.lerp(glass, other.glass, t)!,
      glassStrong: Color.lerp(glassStrong, other.glassStrong, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      inputBackground: Color.lerp(inputBackground, other.inputBackground, t)!,
      card: Color.lerp(card, other.card, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      hero: Color.lerp(hero, other.hero, t)!,
      onHero: Color.lerp(onHero, other.onHero, t)!,
      onHeroMuted: Color.lerp(onHeroMuted, other.onHeroMuted, t)!,
      inverse: Color.lerp(inverse, other.inverse, t)!,
      onInverse: Color.lerp(onInverse, other.onInverse, t)!,
      successSoft: Color.lerp(successSoft, other.successSoft, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      link: Color.lerp(link, other.link, t)!,
    );
  }
}

/// A consistent, subtle push transition for every route on every platform: the
/// incoming page slides up a few pixels while easing from 98% to full size.
///
/// Deliberately transform-only — NO opacity fade. Pages here paint the glass
/// `GlassSurface` (a `BackdropFilter`); fading a subtree that contains a
/// backdrop filter isolates it in an opacity layer, which disables the blur for
/// the duration of the fade and then snaps it back on completion — a visible
/// flicker of the blurred background. Slides and scales are transform layers,
/// so the glass keeps compositing correctly throughout.
class _FadeSlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const _FadeSlidePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return child;
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.025),
        end: Offset.zero,
      ).animate(curved),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
        child: child,
      ),
    );
  }
}

abstract final class AppTheme {
  static ThemeData get light => _theme(Brightness.light);
  static ThemeData get dark => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final background = dark
        ? AppColors.darkBackground
        : AppColors.lightBackground;
    final surface = dark ? AppColors.darkSurface : AppColors.lightSurface;
    final text = dark ? AppColors.darkText : AppColors.lightText;
    final border = dark ? AppColors.darkBorder : AppColors.lightBorder;
    final inputBorder = dark
        ? AppColors.darkInputBorder
        : AppColors.lightInputBorder;
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.control),
    );
    final extension = CarserviceTheme(
      shellBackground: background,
      shellSurface: surface,
      glass: dark ? AppColors.darkGlass : AppColors.lightGlass,
      glassStrong: dark
          ? AppColors.darkGlassStrong
          : AppColors.lightGlassStrong,
      glassBorder: border,
      mutedText: dark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
      inputBackground: dark ? AppColors.darkInput : AppColors.lightInput,
      card: surface,
      cardBorder: border,
      ink: text,
      hero: dark ? const Color(0xFF17222D) : const Color(0xFF2C3E50),
      onHero: const Color(0xFFECF0F1),
      onHeroMuted: const Color(0xFFA9B4B6),
      inverse: dark ? const Color(0xFFECF0F1) : const Color(0xFF2C3E50),
      onInverse: dark ? const Color(0xFF2C3E50) : const Color(0xFFFFFFFF),
      successSoft: dark ? const Color(0x2958D68D) : const Color(0xFFE3F2E9),
      warningSoft: dark ? const Color(0x29F7C948) : const Color(0xFFFCF3D9),
      accentSoft: dark ? const Color(0x33E74C3C) : const Color(0xFFFBEAE8),
      link: dark ? AppColors.accentHover : const Color(0xFFB03A2E),
    );
    final base = ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: brightness,
      surface: background,
    );
    final scheme = base.copyWith(
      // Light mode: the web's light `--oc-accent` (#c0392b) is used for text,
      // icons, selection and filled buttons (~5.4:1 on white).
      primary: dark ? AppColors.accent : AppColors.accentLightText,
      onPrimary: AppColors.onAccent,
      primaryContainer: dark
          ? const Color(0x33E74C3C) // --filter-active-bg (dark)
          : const Color(0xFFFADBD8), // accent-100
      onPrimaryContainer: dark
          ? AppColors.accentHover
          : AppColors.accentLightText,
      secondary: AppColors.blue,
      onSecondary: Colors.white,
      tertiary: AppColors.green,
      error: AppColors.red,
      surface: background,
      onSurface: text,
      onSurfaceVariant: extension.mutedText,
      outline: inputBorder,
      outlineVariant: border,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _FadeSlidePageTransitionsBuilder(),
          TargetPlatform.iOS: _FadeSlidePageTransitionsBuilder(),
          TargetPlatform.macOS: _FadeSlidePageTransitionsBuilder(),
          TargetPlatform.windows: _FadeSlidePageTransitionsBuilder(),
          TargetPlatform.linux: _FadeSlidePageTransitionsBuilder(),
        },
      ),
      extensions: [extension],
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: background,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: AppFonts.sans,
          color: text,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
      fontFamily: AppFonts.sans,
      textTheme: ThemeData(brightness: brightness, fontFamily: AppFonts.sans)
          .textTheme
          .apply(bodyColor: text, displayColor: text),
      cardTheme: CardThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? extension.inputBackground : surface,
        hintStyle: TextStyle(color: extension.mutedText),
        prefixIconColor: extension.mutedText,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: BorderSide(color: inputBorder),
        ),
        // Design: a 2px ink outline on the focused field.
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
          borderSide: BorderSide(color: text, width: 2),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 54),
          backgroundColor: scheme.primary,
          foregroundColor: AppColors.onAccent,
          shape: controlShape,
          textStyle: const TextStyle(
            fontFamily: AppFonts.sans,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 54),
          foregroundColor: text,
          side: BorderSide(color: border),
          backgroundColor: dark ? null : surface,
          shape: controlShape,
          textStyle: const TextStyle(
            fontFamily: AppFonts.sans,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: extension.link,
          textStyle: const TextStyle(
            fontFamily: AppFonts.sans,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: extension.inverse,
        checkmarkColor: extension.onInverse,
        side: BorderSide(color: border),
        shape: const StadiumBorder(),
        labelStyle: TextStyle(
          fontFamily: AppFonts.sans,
          fontSize: 13,
          color: text,
        ),
        secondaryLabelStyle: TextStyle(
          fontFamily: AppFonts.sans,
          fontSize: 13,
          color: extension.onInverse,
        ),
        showCheckmark: false,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: const Color(0xFFA9B4B6),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: extension.mutedText,
          minimumSize: const Size(48, 48),
        ),
      ),
      dividerColor: border,
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
      ),
    );
  }
}
