import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/app_state.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const OmigoApp(),
    ),
  );
}

class OmigoApp extends StatelessWidget {
  const OmigoApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);

    // ── Light Theme ──────────────────────────────────────────────────────────
    final lightTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.ink,
      scaffoldBackgroundColor: AppColors.surface,
      colorScheme: ColorScheme.light(
        primary: AppColors.ink,
        secondary: AppColors.brandGreen,
        surface: AppColors.canvas,
        surfaceContainerHighest: AppColors.surface,
        onPrimary: AppColors.canvas,
        onSecondary: AppColors.ink,
        outline: AppColors.hairline,
        error: AppColors.brandError,
      ),
      // ── Text ──
      textTheme: TextTheme(
        bodyLarge:  AppText.bodyMd.copyWith(color: AppColors.charcoal),
        bodyMedium: AppText.bodySm.copyWith(color: AppColors.charcoal),
        bodySmall:  AppText.caption.copyWith(color: AppColors.steel),
        titleLarge: AppText.heading4.copyWith(color: AppColors.ink),
        titleMedium: AppText.heading5.copyWith(color: AppColors.ink),
        labelSmall: AppText.microUppercase.copyWith(color: AppColors.steel),
      ),
      // ── Cards ──
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.hairline, width: 1),
        ),
        color: AppColors.canvas,
        margin: EdgeInsets.zero,
      ),
      // ── Inputs — {rounded.md} = 8px, focus 2px brandGreen ──
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.canvas,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.hairline, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.hairline, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.brandGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.brandError, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.brandError, width: 2),
        ),
        hintStyle: AppText.bodySm.copyWith(color: AppColors.stone),
        labelStyle: AppText.bodySm.copyWith(color: AppColors.charcoal),
        errorStyle: AppText.caption.copyWith(color: AppColors.brandError),
      ),
      // ── Elevated Buttons — black pill, {button-md} ──
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.ink,
          foregroundColor: AppColors.canvas,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          textStyle: AppText.buttonMd,
          minimumSize: const Size(0, 44),
        ),
      ),
      // ── Outlined Buttons — outlined pill, {button-secondary} ──
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          elevation: 0,
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.hairline, width: 1),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          textStyle: AppText.buttonMd,
          minimumSize: const Size(0, 44),
        ),
      ),
      // ── Text Buttons ──
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.ink,
          textStyle: AppText.bodySmMedium,
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      // ── AppBar ──
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.ink,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 16,
          color: AppColors.ink,
        ),
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      // ── Divider ──
      dividerTheme: const DividerThemeData(
        color: AppColors.hairline,
        thickness: 1,
        space: 1,
      ),
      // ── Switch ──
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(AppColors.brandGreen),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.brandGreen.withOpacity(0.4);
          }
          return AppColors.hairline;
        }),
      ),
      // ── Bottom Nav ──
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        elevation: 0,
        backgroundColor: AppColors.canvas,
        selectedItemColor: AppColors.brandGreen,
        unselectedItemColor: AppColors.steel,
        selectedLabelStyle: TextStyle(
          fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 11,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: 'Inter', fontWeight: FontWeight.w400, fontSize: 11,
        ),
        type: BottomNavigationBarType.fixed,
      ),
      // ── Snackbar ──
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: AppText.bodySm.copyWith(color: AppColors.canvas),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        behavior: SnackBarBehavior.floating,
      ),
    );

    // ── Dark Theme ───────────────────────────────────────────────────────────
    final darkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.onDark,
      scaffoldBackgroundColor: AppColors.canvasDark,
      colorScheme: ColorScheme.dark(
        primary: AppColors.onDark,
        secondary: AppColors.brandGreen,
        surface: AppColors.surfaceDark,
        surfaceContainerHighest: AppColors.surfaceCode,
        onPrimary: AppColors.ink,
        onSecondary: AppColors.ink,
        outline: AppColors.hairlineDark,
        error: AppColors.brandError,
      ),
      textTheme: TextTheme(
        bodyLarge:   AppText.bodyMd.copyWith(color: AppColors.onDark),
        bodyMedium:  AppText.bodySm.copyWith(color: AppColors.onDark.withOpacity(0.8)),
        bodySmall:   AppText.caption.copyWith(color: AppColors.stone),
        titleLarge:  AppText.heading4.copyWith(color: AppColors.onDark),
        titleMedium: AppText.heading5.copyWith(color: AppColors.onDark),
        labelSmall:  AppText.microUppercase.copyWith(color: AppColors.stone),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.hairlineDark, width: 1),
        ),
        color: AppColors.surfaceDark,
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceCode,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.hairlineDark, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.hairlineDark, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.brandGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.brandError, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.brandError, width: 2),
        ),
        hintStyle: AppText.bodySm.copyWith(color: AppColors.stone),
        labelStyle: AppText.bodySm.copyWith(color: AppColors.onDark.withOpacity(0.7)),
        errorStyle: AppText.caption.copyWith(color: AppColors.brandError),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.brandGreen,
          foregroundColor: AppColors.ink,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          textStyle: AppText.buttonMd,
          minimumSize: const Size(0, 44),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          elevation: 0,
          foregroundColor: AppColors.onDark,
          side: const BorderSide(color: AppColors.hairlineDark, width: 1),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          textStyle: AppText.buttonMd,
          minimumSize: const Size(0, 44),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.onDark,
          textStyle: AppText.bodySmMedium,
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.canvasDark,
        foregroundColor: AppColors.onDark,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 16,
          color: AppColors.onDark,
        ),
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.hairlineDark,
        thickness: 1,
        space: 1,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(AppColors.brandGreen),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.brandGreen.withOpacity(0.4);
          }
          return AppColors.hairlineDark;
        }),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        elevation: 0,
        backgroundColor: AppColors.canvasDark,
        selectedItemColor: AppColors.brandGreen,
        unselectedItemColor: AppColors.steel,
        selectedLabelStyle: TextStyle(
          fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 11,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily: 'Inter', fontWeight: FontWeight.w400, fontSize: 11,
        ),
        type: BottomNavigationBarType.fixed,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceDark,
        contentTextStyle: AppText.bodySm.copyWith(color: AppColors.onDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        behavior: SnackBarBehavior.floating,
      ),
    );

    return MaterialApp(
      title: 'Omigo',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: state.isDarkTheme ? ThemeMode.dark : ThemeMode.light,
      home: const SplashScreen(),
    );
  }
}
