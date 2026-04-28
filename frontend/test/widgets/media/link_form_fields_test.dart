import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gleisner_web/l10n/app_localizations.dart';
import 'package:gleisner_web/widgets/media/link_form_fields.dart';

Widget _wrap(Widget child) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: Form(child: child)),
);

class _Harness {
  _Harness() {
    urlController = TextEditingController();
    titleController = TextEditingController();
    captionController = TextEditingController();
    urlFocusNode = FocusNode();
    titleFocusNode = FocusNode();
    captionFocusNode = FocusNode();
  }

  late final TextEditingController urlController;
  late final TextEditingController titleController;
  late final TextEditingController captionController;
  late final FocusNode urlFocusNode;
  late final FocusNode titleFocusNode;
  late final FocusNode captionFocusNode;

  void dispose() {
    urlController.dispose();
    titleController.dispose();
    captionController.dispose();
    urlFocusNode.dispose();
    titleFocusNode.dispose();
    captionFocusNode.dispose();
  }

  Widget build({bool autofocusUrl = false}) {
    return LinkFormFields(
      urlController: urlController,
      titleController: titleController,
      captionController: captionController,
      urlFocusNode: urlFocusNode,
      titleFocusNode: titleFocusNode,
      captionFocusNode: captionFocusNode,
      autofocusUrl: autofocusUrl,
    );
  }
}

void main() {
  group('LinkFormFields URL validator', () {
    late GlobalKey<FormState> formKey;
    late _Harness h;

    setUp(() {
      formKey = GlobalKey<FormState>();
      h = _Harness();
    });

    tearDown(() => h.dispose());

    Future<String?> validateAfterTyping(
      WidgetTester tester,
      String input,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Form(key: formKey, child: h.build()),
          ),
        ),
      );
      // First TextFormField is the URL field (the form's first row).
      h.urlController.text = input;
      formKey.currentState!.validate();
      await tester.pump();
      // Pull the resolved error text from the rendered widget.
      final fieldState = tester.state<FormFieldState<String>>(
        find.byType(TextFormField).first,
      );
      return fieldState.errorText;
    }

    testWidgets('rejects empty input', (tester) async {
      final err = await validateAfterTyping(tester, '');
      expect(err, isNotNull);
    });

    testWidgets('rejects whitespace-only input', (tester) async {
      // create_post_screen used to accept this (`value.isEmpty` check) —
      // the shared widget locks in the strict trim-then-check behaviour.
      final err = await validateAfterTyping(tester, '   ');
      expect(err, isNotNull);
    });

    testWidgets('rejects non-http schemes (javascript:, ftp:, data:)', (
      tester,
    ) async {
      for (final bad in [
        // ignore: unnecessary_string_escapes — kept literal for readability
        'javascript:alert(1)',
        'ftp://example.com/file',
        'data:text/html,<script>alert(1)</script>',
        'mailto:foo@example.com',
      ]) {
        final err = await validateAfterTyping(tester, bad);
        expect(err, isNotNull, reason: '"$bad" should be rejected');
      }
    });

    testWidgets('rejects http(s) URIs without a host (https: alone)', (
      tester,
    ) async {
      // `Uri.tryParse('https:')` succeeds but `uri.host` is empty —
      // safeFetch would reject these server-side. Catching client-side
      // gives a friendlier inline error instead of waiting for fetchOgp.
      for (final bad in ['https:', 'http://', 'https:///path']) {
        final err = await validateAfterTyping(tester, bad);
        expect(err, isNotNull, reason: '"$bad" should be rejected');
      }
    });

    testWidgets('accepts valid http(s) URLs', (tester) async {
      for (final good in [
        'https://example.com',
        'https://example.com/path?q=1',
        'http://localhost:4000',
        'https://日本語.example/post',
      ]) {
        final err = await validateAfterTyping(tester, good);
        expect(err, isNull, reason: '"$good" should be accepted');
      }
    });

    testWidgets('trims surrounding whitespace before validating', (
      tester,
    ) async {
      // Edit screen always trimmed; create did not until the shared
      // widget. This test pins the post-extraction behaviour.
      final err = await validateAfterTyping(tester, '  https://example.com  ');
      expect(err, isNull);
    });
  });

  group('LinkFormFields autofocus', () {
    testWidgets('autofocusUrl: false leaves the URL field unfocused', (
      tester,
    ) async {
      final h = _Harness();
      addTearDown(h.dispose);

      await tester.pumpWidget(_wrap(h.build()));
      await tester.pumpAndSettle();

      expect(h.urlFocusNode.hasFocus, isFalse);
    });

    testWidgets(
      'autofocusUrl: true requests focus on the URL field after first frame',
      (tester) async {
        final h = _Harness();
        addTearDown(h.dispose);

        await tester.pumpWidget(_wrap(h.build(autofocusUrl: true)));
        await tester.pumpAndSettle();

        expect(h.urlFocusNode.hasFocus, isTrue);
      },
    );
  });

  group('LinkFormFields layout', () {
    testWidgets('renders three text fields (URL, title, caption)', (
      tester,
    ) async {
      final h = _Harness();
      addTearDown(h.dispose);

      await tester.pumpWidget(_wrap(h.build()));
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsNWidgets(3));
      expect(find.byIcon(Icons.link_rounded), findsOneWidget);
    });

    testWidgets('binds the URL controller to the URL field', (tester) async {
      final h = _Harness();
      addTearDown(h.dispose);

      await tester.pumpWidget(_wrap(h.build()));
      await tester.pumpAndSettle();

      // Confirm the controller wiring: typing into the first row updates
      // the URL controller (not title or caption).
      await tester.enterText(
        find.byType(TextFormField).first,
        'https://example.com',
      );
      expect(h.urlController.text, 'https://example.com');
      expect(h.titleController.text, isEmpty);
      expect(h.captionController.text, isEmpty);
    });
  });
}
