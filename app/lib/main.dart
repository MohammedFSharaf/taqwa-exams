import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'firebase_options.dart';
import 'repo.dart';
import 'screens/gate.dart';
import 'screens/ui.dart';
import 'screens/widgets.dart';
import 'update_check.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: firebaseOptions);
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  await Repo.I.init();
  UpdateWatcher.I.start();
  NetWatcher.I.start();
  runApp(const TaqwaApp());
}

class TaqwaApp extends StatelessWidget {
  const TaqwaApp({super.key});

  static ThemeData _theme(Brightness b) {
    final dark = b == Brightness.dark;
    final surface = dark ? const Color(0xFF16222D) : Colors.white;
    final border = dark ? const Color(0xFF2A3B4A) : const Color(0xFFD5E0E8);
    final fg = dark ? const Color(0xFFE8F1F7) : brandNavy;
    return ThemeData(
      useMaterial3: true,
      brightness: b,
      fontFamily: 'Cairo',
      colorScheme: ColorScheme.fromSeed(
        seedColor: brandBlue,
        brightness: b,
        primary: dark ? const Color(0xFF4FB3E8) : brandGreen,
        secondary: goldButton,
        surface: surface,
      ),
      scaffoldBackgroundColor: dark ? const Color(0xFF0D161E) : pageBg,
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? const Color(0xFF111C26) : const Color(0xFFF3F9FD),
        foregroundColor: fg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: true,
        titleTextStyle: TextStyle(fontFamily: 'Cairo', color: fg, fontSize: 19, fontWeight: FontWeight.w800),
        shape: const Border(bottom: BorderSide(color: goldButton, width: 3)),
      ),
      cardTheme: CardTheme(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: dark ? 0 : 1.5,
        shadowColor: const Color(0x220A3C64),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? const Color(0xFF26394A) : brandNavy,
        contentTextStyle: const TextStyle(fontFamily: 'Cairo', color: Colors.white, fontSize: 14.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF1A2733) : Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: brandBlue, width: 1.6)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: UiPrefs.I,
      builder: (context, _) => MaterialApp(
        title: 'مركز التقوى',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        themeMode: UiPrefs.I.mode,
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          final sys = mq.textScaler.scale(1.0).clamp(0.85, 1.4);
          return MediaQuery(
            data: mq.copyWith(textScaler: TextScaler.linear(sys * UiPrefs.I.scale)),
            child: child ?? const SizedBox.shrink(),
          );
        },
        navigatorKey: appNavigatorKey,
        home: const GateScreen(),
      ),
    );
  }
}
