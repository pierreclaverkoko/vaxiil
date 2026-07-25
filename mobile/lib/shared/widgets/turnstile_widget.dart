import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:vaxiil_mobile/core/constants/app_constants.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Cloudflare Turnstile challenge (managed widget) via an embedded WebView.
class TurnstileWidget extends StatefulWidget {
  const TurnstileWidget({
    required this.onToken,
    super.key,
    this.height = 72,
  });

  /// Called with the solved token, or null when expired/reset/error.
  final ValueChanged<String?> onToken;

  /// WebView height for the managed widget.
  final double height;

  @override
  State<TurnstileWidget> createState() => TurnstileWidgetState();
}

class TurnstileWidgetState extends State<TurnstileWidget> {
  late final WebViewController _controller;
  var _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel(
        'TurnstileChannel',
        onMessageReceived: (message) {
          final raw = message.message.trim();
          widget.onToken(raw.isEmpty ? null : raw);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _ready = true);
          },
        ),
      )
      ..loadHtmlString(
        _html(AppConstants.turnstileSiteKey),
        baseUrl: 'https://localhost',
      );
  }

  /// Clears the token and asks Turnstile to issue a new challenge.
  Future<void> reset() async {
    widget.onToken(null);
    if (!_ready) return;
    try {
      await _controller.runJavaScript(
        'if (window.turnstile && window.__vaxiilWidgetId) {'
        ' turnstile.reset(window.__vaxiilWidgetId); '
        '}',
      );
    } catch (_) {
      // Ignore reset failures (e.g. widget not rendered yet).
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // webview_flutter has limited Flutter-web support; show guidance.
      return SizedBox(
        height: widget.height,
        child: const Center(
          child: Text(
            'Turnstile requires a native build on this platform.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: WebViewWidget(controller: _controller),
    );
  }

  static String _html(String siteKey) {
    final escaped = siteKey.replaceAll("'", r"\'");
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <script src="https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit" async defer></script>
  <script>
    function onTurnstileLoad() {
      window.__vaxiilWidgetId = turnstile.render('#cf-turnstile', {
        sitekey: '$escaped',
        action: 'turnstile-spin-v2',
        callback: function (token) {
          TurnstileChannel.postMessage(token);
        },
        'expired-callback': function () {
          TurnstileChannel.postMessage('');
        },
        'error-callback': function () {
          TurnstileChannel.postMessage('');
        }
      });
    }
    window.addEventListener('load', function () {
      if (window.turnstile) {
        onTurnstileLoad();
      } else {
        var t = setInterval(function () {
          if (window.turnstile) {
            clearInterval(t);
            onTurnstileLoad();
          }
        }, 50);
      }
    });
  </script>
  <style>
    html, body { margin: 0; padding: 0; background: transparent; }
    #wrap { display: flex; justify-content: center; align-items: center; min-height: 65px; }
  </style>
</head>
<body>
  <div id="wrap">
    <div id="cf-turnstile" class="cf-turnstile" data-action="turnstile-spin-v2"></div>
  </div>
</body>
</html>
''';
  }
}
