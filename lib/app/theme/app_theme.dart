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
  });
  final Color shellBackground;
  final Color shellSurface;
  final Color glass;
  final Color glassStrong;
  final Color glassBorder;
  final Color mutedText;
  final Color inputBackground;

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
  }) => CarserviceTheme(
    shellBackground: shellBackground ?? this.shellBackground,
    shellSurface: shellSurface ?? this.shellSurface,
    glass: glass ?? this.glass,
    glassStrong: glassStrong ?? this.glassStrong,
    glassBorder: glassBorder ?? this.glassBorder,
    mutedText: mutedText ?? this.mutedText,
    inputBackground: inputBackground ?? this.inputBackground,
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
        backgroundColor: surface,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        shape: Border(bottom: BorderSide(color: border)),
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      textTheme: ThemeData(brightness: brightness).textTheme
          .apply(bodyColor: text, displayColor: text),
      cardTheme: CardThemeData(
        color: extension.glass,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.large),
          side: BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: extension.inputBackground,
        hintStyle: TextStyle(color: extension.mutedText),
        prefixIconColor: extension.mutedText,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: BorderSide(color: inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: BorderSide(color: scheme.primary),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          backgroundColor: scheme.primary,
          foregroundColor: AppColors.onAccent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
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
