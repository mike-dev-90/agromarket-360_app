import 'package:flutter/material.dart';

const agroGreen = Color(0xFF2E7D32);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: agroGreen);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    appBarTheme: AppBarTheme(backgroundColor: scheme.primary, foregroundColor: scheme.onPrimary),
    inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
    ),
  );
}
