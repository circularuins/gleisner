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
import 'utils/keyboard_height_observer.dart';

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
        // Two layers, both gated:
        //   - KeyboardHeightObserver (outer) provides a cross-checked
        //     soft-keyboard height via `KeyboardHeight.of(context)`. Active
        //     for all screens.
        //   - KeyboardDebugOverlay (inner) draws a diagnostics panel on top
        //     of every screen, but only when the URL has `?debug=keyboard`.
        //     Pass-through otherwise (no behavior change for normal users).
        // Inner placement lets the overlay itself read KeyboardHeight if we
        // later extend it to display that value too.
        builder: (context, child) => KeyboardHeightObserver(
          child: KeyboardDebugOverlay(child: child ?? const SizedBox.shrink()),
        ),
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
