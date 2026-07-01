import 'package:shelf/shelf.dart';

const _cookieName = 'jackedlog_key';

String? _cookieKey(Request request) {
  final header = request.headers['cookie'];
  if (header == null) return null;
  for (final part in header.split(';')) {
    final pair = part.trim();
    final eq = pair.indexOf('=');
    if (eq <= 0) continue;
    if (pair.substring(0, eq) == _cookieName) {
      return Uri.decodeComponent(pair.substring(eq + 1));
    }
  }
  return null;
}

String _setCookieHeader(String apiKey) =>
    '$_cookieName=${Uri.encodeComponent(apiKey)}; Path=/; HttpOnly; '
    'SameSite=Strict; Max-Age=31536000';

bool _isBrowserPage(String path) =>
    path == 'manage' || path == 'login' || path.startsWith('dashboard');

String _loginPage({bool failed = false, String from = '/dashboard'}) {
  final error =
      failed ? '<p class="error">Invalid API key. Try again.</p>' : '';
  return '''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta name="referrer" content="no-referrer">
<title>Sign in - JackedLog</title>
<style>
  :root { color-scheme: dark; }
  * { box-sizing: border-box; }
  body {
    margin: 0;
    min-height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
    font-family: "Inter", -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    background: radial-gradient(1200px 800px at 70% -10%, rgba(139,92,246,0.16), transparent 60%), #090b10;
    color: #f3f6fb;
  }
  .card {
    width: min(92vw, 380px);
    padding: 2.2rem 2rem;
    border-radius: 16px;
    border: 1px solid rgba(148,163,184,0.16);
    background: rgba(23,29,39,0.85);
    box-shadow: 0 24px 70px rgba(0,0,0,0.45);
    backdrop-filter: blur(12px);
  }
  .logo {
    font-size: 1.5rem;
    font-weight: 800;
    letter-spacing: -0.02em;
    background: linear-gradient(120deg, #a78bfa, #22d3ee);
    -webkit-background-clip: text;
    background-clip: text;
    color: transparent;
    margin-bottom: 0.3rem;
  }
  .sub { color: #97a3b6; font-size: 0.85rem; margin-bottom: 1.6rem; }
  label { display: block; font-size: 0.78rem; font-weight: 600; color: #97a3b6; margin-bottom: 0.4rem; }
  input[type=password] {
    width: 100%;
    height: 44px;
    padding: 0 0.85rem;
    border-radius: 10px;
    border: 1px solid rgba(148,163,184,0.22);
    background: #11151d;
    color: inherit;
    font: inherit;
    outline: none;
  }
  input[type=password]:focus { border-color: #8b5cf6; box-shadow: 0 0 0 3px rgba(139,92,246,0.25); }
  button {
    width: 100%;
    height: 44px;
    margin-top: 1rem;
    border: 0;
    border-radius: 10px;
    background: linear-gradient(120deg, #8b5cf6, #7c3aed);
    color: #fff;
    font: inherit;
    font-weight: 700;
    cursor: pointer;
  }
  button:hover { filter: brightness(1.1); }
  .error { color: #f87171; font-size: 0.82rem; }
</style>
</head>
<body>
<form class="card" method="POST" action="/login">
  <div class="logo">JackedLog</div>
  <div class="sub">Enter your API key to open the dashboard.</div>
  $error
  <input type="hidden" name="from" value="${_escapeAttr(from)}">
  <label for="key">API key</label>
  <input id="key" type="password" name="key" autocomplete="current-password" autofocus required>
  <button type="submit">Sign in</button>
</form>
</body>
</html>''';
}

String _escapeAttr(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('"', '&quot;');

/// Only allow same-site relative redirect targets.
String _safeFrom(String? from) {
  if (from == null || !from.startsWith('/') || from.startsWith('//')) {
    return '/dashboard';
  }
  return from;
}

Middleware authMiddleware(String apiKey) {
  return (Handler innerHandler) {
    return (Request request) async {
      final path = request.url.path;

      // Health check is public
      if (path == 'api/health') {
        return innerHandler(request);
      }

      // Login page: GET shows the form, POST sets the auth cookie.
      if (path == 'login') {
        final from = _safeFrom(request.url.queryParameters['from']);
        if (request.method == 'POST') {
          final body = await request.readAsString();
          final form = Uri.splitQueryString(body);
          final target = _safeFrom(form['from']);
          if (form['key'] == apiKey) {
            return Response.found(target,
                headers: {'set-cookie': _setCookieHeader(apiKey)});
          }
          return Response.ok(_loginPage(failed: true, from: target),
              headers: {'content-type': 'text/html'});
        }
        return Response.ok(_loginPage(from: from),
            headers: {'content-type': 'text/html'});
      }

      // Legacy `?key=` links (e.g. opened from the app): if the key is valid,
      // set the cookie and redirect to the same URL without the key so it
      // never sticks around in history, logs, or referrers.
      final queryKey = request.url.queryParameters['key'];
      if (queryKey != null && _isBrowserPage(path)) {
        if (queryKey != apiKey) {
          return Response.found('/login?from=${Uri.encodeComponent('/$path')}');
        }
        final cleaned = Map<String, String>.from(request.url.queryParameters)
          ..remove('key');
        final target = Uri(
            path: '/$path', queryParameters: cleaned.isEmpty ? null : cleaned);
        return Response.found('$target',
            headers: {'set-cookie': _setCookieHeader(apiKey)});
      }

      // Cookie auth (browser pages and same-origin fetch() API calls).
      if (_cookieKey(request) == apiKey) {
        return innerHandler(request);
      }

      // Bearer token auth (app / scripts).
      final authHeader = request.headers['authorization'];
      if (authHeader != null && authHeader.startsWith('Bearer ')) {
        if (authHeader.substring(7) == apiKey) {
          return innerHandler(request);
        }
        return Response.forbidden(
          '{"error": "Invalid API key"}',
          headers: {'content-type': 'application/json'},
        );
      }

      // Unauthenticated browser page: send to login instead of raw JSON.
      if (_isBrowserPage(path)) {
        final target = request.url.query.isEmpty
            ? '/$path'
            : '/$path?${request.url.query}';
        return Response.found('/login?from=${Uri.encodeComponent(target)}');
      }

      return Response(401,
          body: '{"error": "Missing authorization"}',
          headers: {'content-type': 'application/json'});
    };
  };
}
