import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
        ),
        routerConfig: router,
      ),
    );
  }
}
