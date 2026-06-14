import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';

import '../version.dart';

/// Update endpoints.
///
/// The server tracks the `main` branch on GitHub: it reports the commit it is
/// running and whether newer commits have landed on `main`.
///
/// It runs as a static binary inside a `scratch` Docker image with no shell,
/// package manager or Docker access, so it cannot rebuild or restart itself.
/// "Applying" an update therefore means either delegating to a Watchtower
/// sidecar (if configured) or surfacing the host command to run.

/// How the server learns the commit it is currently running:
///   1. `JACKED_COMMIT` env var (recommended — bake `git rev-parse HEAD` in at
///      build time via your own compose/Dockerfile), or
///   2. a `<DATA_DIR>/.commit` file (written after a successful apply).
String? _currentCommit() {
  final env = Platform.environment['JACKED_COMMIT'];
  if (env != null && env.trim().isNotEmpty) return env.trim();

  final dataDir = Platform.environment['DATA_DIR'] ?? '/data';
  final file = File('$dataDir/.commit');
  if (file.existsSync()) {
    final value = file.readAsStringSync().trim();
    if (value.isNotEmpty) return value;
  }
  return null;
}

/// Check whether `main` has commits newer than the running one.
///
/// Returns JSON: {
///   currentCommit, latestCommit, latestMessage, latestDate,
///   behindBy, updateAvailable, compareUrl, error?
/// }
Future<Response> updateCheckHandler(Request request) async {
  final current = _currentCommit();
  try {
    final latest = await _fetchLatestMainCommit();
    if (latest == null) {
      return _json({
        'version': serverVersion,
        'currentCommit': current,
        'error': 'Could not read the latest commit on main from GitHub.',
        'updateAvailable': false,
      });
    }

    // No known current commit -> we can report latest but not a diff.
    if (current == null) {
      return _json({
        'version': serverVersion,
        'currentCommit': null,
        'latestCommit': latest.sha,
        'latestMessage': latest.message,
        'latestDate': latest.date,
        'behindBy': null,
        'updateAvailable': false,
        'error': 'Current commit unknown. Set the JACKED_COMMIT env var (to '
            'the deployed commit SHA) so the server can compare against main.',
      });
    }

    if (_sameCommit(current, latest.sha)) {
      return _json({
        'version': serverVersion,
        'currentCommit': current,
        'latestCommit': latest.sha,
        'latestMessage': latest.message,
        'latestDate': latest.date,
        'behindBy': 0,
        'updateAvailable': false,
      });
    }

    // How many commits is main ahead of the running commit?
    final behindBy = await _commitsBehindMain(current);
    return _json({
      'version': serverVersion,
      'currentCommit': current,
      'latestCommit': latest.sha,
      'latestMessage': latest.message,
      'latestDate': latest.date,
      'behindBy': behindBy,
      'updateAvailable': behindBy == null || behindBy > 0,
      'compareUrl':
          'https://github.com/$githubRepo/compare/$current...${latest.sha}',
    });
  } catch (e) {
    return _json({
      'version': serverVersion,
      'currentCommit': current,
      'updateAvailable': false,
      'error': 'Update check failed: $e',
    });
  }
}

/// Trigger an update if a Watchtower HTTP API is configured.
///
/// A `scratch` container can't rebuild itself, so the only safe one-click path
/// is to delegate to a Watchtower sidecar running with its HTTP API enabled.
/// Configure via env vars (set these in your own compose, not the bundled one):
///   WATCHTOWER_URL   e.g. http://watchtower:8080/v1/update
///   WATCHTOWER_TOKEN the token passed to Watchtower's --http-api-token
///
/// When unset, responds with the host command to run instead.
Future<Response> updateApplyHandler(Request request) async {
  final url = Platform.environment['WATCHTOWER_URL'];
  final token = Platform.environment['WATCHTOWER_TOKEN'];

  if (url == null || url.isEmpty || token == null || token.isEmpty) {
    return _json({
      'triggered': false,
      'message': 'This container cannot rebuild itself. Update from the host '
          'with:  git pull && docker compose up -d --build  '
          '(or configure a Watchtower HTTP API via WATCHTOWER_URL / '
          'WATCHTOWER_TOKEN for one-click updates).',
    });
  }

  try {
    final client = HttpClient();
    final req = await client.getUrl(Uri.parse(url));
    req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
    final resp = await req.close();
    await resp.drain<void>();
    client.close();

    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return _json({
        'triggered': true,
        'message': 'Watchtower update triggered. The container will be '
            'recreated shortly if a newer image is available.',
      });
    }
    return _json({
      'triggered': false,
      'message': 'Watchtower returned HTTP ${resp.statusCode}.',
    });
  } catch (e) {
    return _json({
      'triggered': false,
      'message': 'Failed to reach Watchtower: $e',
    });
  }
}

/// Latest commit on the `main` branch.
class _Commit {
  _Commit(this.sha, this.message, this.date);
  final String sha;
  final String message;
  final String date;
}

Future<_Commit?> _fetchLatestMainCommit() async {
  final body = await _githubGet('/repos/$githubRepo/commits/main');
  if (body == null) return null;
  final json = jsonDecode(body) as Map<String, dynamic>;
  final sha = json['sha'] as String?;
  if (sha == null) return null;
  final commit = json['commit'] as Map<String, dynamic>?;
  final message = (commit?['message'] as String?)?.split('\n').first ?? '';
  final date =
      (commit?['committer'] as Map<String, dynamic>?)?['date'] as String? ?? '';
  return _Commit(sha, message, date);
}

/// Number of commits `main` is ahead of [base], or null if it can't be read.
Future<int?> _commitsBehindMain(String base) async {
  final body = await _githubGet('/repos/$githubRepo/compare/$base...main');
  if (body == null) return null;
  final json = jsonDecode(body) as Map<String, dynamic>;
  return json['ahead_by'] as int?;
}

/// Perform a GET against the GitHub API. Returns the body or null on failure.
Future<String?> _githubGet(String path) async {
  final client = HttpClient();
  try {
    final req = await client.getUrl(Uri.parse('https://api.github.com$path'));
    // GitHub rejects requests without a User-Agent.
    req.headers.set(HttpHeaders.userAgentHeader, 'JackedLog-Server');
    req.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
    final resp = await req.close();
    if (resp.statusCode != 200) {
      await resp.drain<void>();
      return null;
    }
    return await resp.transform(utf8.decoder).join();
  } finally {
    client.close();
  }
}

/// Compare commit SHAs allowing for short/long forms.
bool _sameCommit(String a, String b) {
  if (a == b) return true;
  final min = a.length < b.length ? a.length : b.length;
  if (min < 7) return false;
  return a.substring(0, min) == b.substring(0, min);
}

Response _json(Map<String, dynamic> data) => Response.ok(
      jsonEncode(data),
      headers: {'content-type': 'application/json'},
    );
