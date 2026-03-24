import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import 'graphql/client.dart';
import 'theme/gleisner_tokens.dart';
import 'router.dart';

class GleisnerApp extends ConsumerWidget {
  const GleisnerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final clientNotifier = ref.watch(graphqlClientNotifierProvider);

    // Urbanist for display/headings, Plus Jakarta Sans for body
    final textTheme = GoogleFonts.plusJakartaSansTextTheme(
      ThemeData.dark().textTheme,
    );
    final displayTextTheme = GoogleFonts.urbanistTextTheme(
      ThemeData.dark().textTheme,
    );

    return GraphQLProvider(
      client: clientNotifier,
      child: MaterialApp.router(
        title: 'Gleisner',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: colorSeed,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          textTheme: textTheme.copyWith(
            displayLarge: displayTextTheme.displayLarge,
            displayMedium: displayTextTheme.displayMedium,
            displaySmall: displayTextTheme.displaySmall,
            headlineLarge: displayTextTheme.headlineLarge,
            headlineMedium: displayTextTheme.headlineMedium,
            headlineSmall: displayTextTheme.headlineSmall,
            titleLarge: displayTextTheme.titleLarge,
          ),
        ),
        routerConfig: router,
      ),
    );
  }
}
