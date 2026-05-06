import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Use HTML5 history API (clean URL paths) instead of Flutter Web's
  // default hash strategy. Without this, https://gleisner.app/@username
  // opens at GoRouter's initialLocation (/splash) because hash routing
  // doesn't read the URL path portion — shared public-timeline links
  // would land on /login. usePathUrlStrategy is a no-op on non-Web
  // platforms so this stays safe if we ever target iOS/Android.
  usePathUrlStrategy();
  await initHiveForFlutter();
  runApp(const ProviderScope(child: GleisnerApp()));
}
