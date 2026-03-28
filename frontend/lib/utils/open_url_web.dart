import 'package:web/web.dart' as web;

/// Web implementation: opens URL in a new browser tab.
void openUrlImpl(String url) {
  web.window.open(url, '_blank');
}
