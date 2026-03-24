import 'package:flutter/material.dart';

import '../../theme/gleisner_tokens.dart';

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colorSurface0,
      appBar: AppBar(
        backgroundColor: colorSurface0,
        title: const Text(
          'Discover',
          style: TextStyle(color: colorTextPrimary),
        ),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.explore_outlined,
              size: 48,
              color: colorInteractiveMuted,
            ),
            SizedBox(height: spaceLg),
            Text(
              'Coming soon',
              style: TextStyle(color: colorTextMuted, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
