import 'package:shelf/shelf.dart';

import '../services/backup_service.dart';
import '../version.dart';
import 'dashboard_pages.dart';

Response managePageHandler(
    Request request, BackupService backupService, String apiKey) {
  final backups = backupService.listBackups();
  final totalBytes = backupService.totalStorageBytes();
  final totalFormatted = _formatBytes(totalBytes);

  final rows = StringBuffer();
  for (final b in backups) {
    final date =
        '${b.date.year.toString().padLeft(4, '0')}-${b.date.month.toString().padLeft(2, '0')}-${b.date.day.toString().padLeft(2, '0')}';
    final size = _formatBytes(b.sizeBytes);
    final dbVersion = b.dbVersion?.toString() ?? '?';
    final status = b.isValid
        ? '<span class="badge good">Passed</span>'
        : '<span class="badge bad">Failed</span>';

    rows.writeln('''<tr>
  <td>$date</td>
  <td>$size</td>
  <td>$dbVersion</td>
  <td>$status</td>
  <td style="white-space:nowrap">
    <button class="btn" onclick="downloadBackup('${_escapeJsAttr(b.filename)}')">Download</button>
    <button class="btn danger" onclick="deleteBackup('${_escapeJsAttr(b.filename)}')">Delete</button>
  </td>
</tr>''');
  }

  final tableBody = backups.isEmpty
      ? '<tr><td colspan="5" style="text-align:center;color:var(--text-muted);padding:2rem">No backups yet</td></tr>'
      : rows.toString();

  final content = '''
<div class="panel" style="margin-bottom:1.25rem">
  <div class="panel-header" style="margin-bottom:0">
    <div>
      <h3 class="panel-title">Server</h3>
      <p class="panel-kicker">Version v$serverVersion &middot; Total backup storage: $totalFormatted</p>
    </div>
    <div style="display:flex;align-items:center;gap:0.65rem;flex-wrap:wrap">
      <span id="updateStatus" class="status-text"></span>
      <button class="btn" id="checkBtn" onclick="checkUpdate()">Check for updates</button>
      <button class="btn primary" id="applyBtn" onclick="applyUpdate()" style="display:none">Update now</button>
    </div>
  </div>
</div>
<div class="table-card">
  <h3 class="table-title">Backups</h3>
  <table class="data-table">
    <thead>
      <tr><th>Date</th><th>Size</th><th>DB Version</th><th>Status</th><th>Actions</th></tr>
    </thead>
    <tbody>
      $tableBody
    </tbody>
  </table>
</div>''';

  const extraScripts = '''
<script>
// Same-origin fetches carry the auth cookie; no key needed in the page.
function downloadBackup(filename) {
  fetch('/api/backup/' + encodeURIComponent(filename))
  .then(r => { if (!r.ok) throw new Error('Download failed'); return r.blob(); })
  .then(blob => {
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    a.remove();
    URL.revokeObjectURL(url);
  })
  .catch(e => alert(e.message));
}

function deleteBackup(filename) {
  if (!confirm('Delete ' + filename + '?')) return;
  fetch('/api/backup/' + encodeURIComponent(filename), { method: 'DELETE' })
  .then(r => { if (!r.ok) throw new Error('Delete failed'); location.reload(); })
  .catch(e => alert(e.message));
}

function setStatus(msg, cls) {
  const el = document.getElementById('updateStatus');
  el.textContent = msg;
  el.className = 'status-text ' + (cls || '');
}

function short(sha) { return sha ? sha.substring(0, 7) : '?'; }

function checkUpdate() {
  const btn = document.getElementById('checkBtn');
  btn.disabled = true;
  setStatus('Checking…', '');
  fetch('/api/update/check')
    .then(r => r.json())
    .then(d => {
      if (d.updateAvailable) {
        const n = (d.behindBy && d.behindBy > 0)
          ? d.behindBy + ' new commit' + (d.behindBy === 1 ? '' : 's')
          : 'New commits';
        setStatus(n + ' on main (latest ' + short(d.latestCommit) + ')', 'warn');
        document.getElementById('applyBtn').style.display = '';
      } else if (d.error) {
        setStatus(d.error, 'err');
      } else {
        setStatus('Up to date (' + short(d.currentCommit) + ')', 'ok');
      }
    })
    .catch(e => setStatus(e.message, 'err'))
    .finally(() => { btn.disabled = false; });
}

function applyUpdate() {
  if (!confirm('Trigger an update of the server container?')) return;
  const btn = document.getElementById('applyBtn');
  btn.disabled = true;
  setStatus('Requesting update…', '');
  fetch('/api/update/apply', { method: 'POST' })
    .then(r => r.json())
    .then(d => setStatus(d.message, d.triggered ? 'ok' : 'warn'))
    .catch(e => setStatus(e.message, 'err'))
    .finally(() => { btn.disabled = false; });
}
</script>''';

  final html = dashboardShell(
    title: 'Backups',
    activeNav: 'Backups',
    content: content,
    apiKey: apiKey,
    request: request,
    backupService: backupService,
    extraScripts: extraScripts,
  );

  return Response.ok(html, headers: {'content-type': 'text/html'});
}

String _escapeJsAttr(String s) => s
    .replaceAll('\\', '\\\\')
    .replaceAll("'", "\\'")
    .replaceAll('"', '&quot;')
    .replaceAll('<', '\\x3C');

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}
