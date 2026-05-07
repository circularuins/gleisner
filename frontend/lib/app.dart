import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import 'graphql/client.dart';
import 'l10n/l10n.dart';
import 'theme/gleisner_tokens.dart';
import 'router.dart';
import 'utils/keyboard_debug_overlay.dart';

// Cache theme data to avoid rebuilding on every frame.
final _darkTextTheme = ThemeData.dark().textTheme;
final _bodyTextTheme = GoogleFonts.plusJakartaSansTextTheme(_darkTextTheme);
final _displayTextTheme = GoogleFonts.urbanistTextTheme(_darkTextTheme);

final _gleisnerTheme = ThemeData(
  brightness: Brightness.dark,
  colorScheme: ColorScheme.fromSeed(
    seedColor: colorSeed,
    brightness: Brightness.dark,
  ),
  useMaterial3: true,
  textTheme: _bodyTextTheme.copyWith(
    displayLarge: _displayTextTheme.displayLarge,
    displayMedium: _displayTextTheme.displayMedium,
    displaySmall: _displayTextTheme.displaySmall,
    headlineLarge: _displayTextTheme.headlineLarge,
    headlineMedium: _displayTextTheme.headlineMedium,
    headlineSmall: _displayTextTheme.headlineSmall,
    titleLarge: _displayTextTheme.titleLarge,
  ),
);

class GleisnerApp extends ConsumerWidget {
  const GleisnerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final clientNotifier = ref.watch(graphqlClientNotifierProvider);

    return GraphQLProvider(
      client: clientNotifier,
      child: MaterialApp.router(
        title: 'Gleisner',
        debugShowCheckedModeBanner: false,
        theme: _gleisnerTheme,
        routerConfig: router,
        // Diagnostics overlay for the iPhone Safari soft-keyboard issue.
        // Active only when the URL contains `?debug=keyboard`. Pass-through
        // (single child) when the flag is absent. Remove together with
        // `keyboard_debug_overlay.dart` once the root cause is fixed.
        builder: (context, child) =>
            KeyboardDebugOverlay(child: child ?? const SizedBox.shrink()),
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          FlutterQuillLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        localeResolutionCallback: (locale, supportedLocales) {
          if (locale == null) return supportedLocales.first;
          for (final supported in supportedLocales) {
            if (supported.languageCode == locale.languageCode) return supported;
          }
          return supportedLocales.first; // fallback to English
        },
      ),
    );
  }
}
