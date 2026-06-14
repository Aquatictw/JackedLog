import 'package:shelf/shelf.dart';

import '../services/backup_service.dart';
import '../version.dart';

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
        ? '<span style="color:#4caf50">Passed</span>'
        : '<span style="color:#ef5350">Failed</span>';

    rows.writeln('''<tr>
  <td>$date</td>
  <td>$size</td>
  <td>$dbVersion</td>
  <td>$status</td>
  <td>
    <button class="btn dl" onclick="downloadBackup('${b.filename}')">Download</button>
    <button class="btn del" onclick="deleteBackup('${b.filename}')">Delete</button>
  </td>
</tr>''');
  }

  final tableBody = backups.isEmpty
      ? '<tr><td colspan="5" style="text-align:center;color:#888;padding:2rem">No backups yet</td></tr>'
      : rows.toString();

  final html = '''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>JackedLog Backup Management</title>
<style>
  *, *::before, *::after { box-sizing: border-box; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
    background: #121212;
    color: #e0e0e0;
    margin: 0;
    padding: 1rem;
  }
  .container { max-width: 800px; margin: 0 auto; }
  h1 { font-size: 1.4rem; margin-bottom: 0.25rem; }
  .storage { color: #888; font-size: 0.9rem; margin-bottom: 1.5rem; }
  table { width: 100%; border-collapse: collapse; font-size: 0.9rem; }
  th { text-align: left; padding: 0.6rem 0.5rem; border-bottom: 2px solid #333; color: #aaa; font-weight: 600; }
  td { padding: 0.6rem 0.5rem; border-bottom: 1px solid #222; }
  tr:nth-child(even) td { background: #1a1a1a; }
  .btn {
    border: none; padding: 0.3rem 0.7rem; border-radius: 4px;
    cursor: pointer; font-size: 0.8rem; font-weight: 500;
  }
  .btn.dl { background: #1e88e5; color: #fff; }
  .btn.dl:hover { background: #1565c0; }
  .btn.del { background: #c62828; color: #fff; margin-left: 0.3rem; }
  .btn.del:hover { background: #b71c1c; }
  .update-panel {
    border: 1px solid #333; border-radius: 8px; padding: 1rem;
    margin-bottom: 1.5rem; background: #1a1a1a;
    display: flex; align-items: center; gap: 0.75rem; flex-wrap: wrap;
  }
  .update-panel .ver { font-size: 0.9rem; color: #aaa; }
  .update-panel .ver strong { color: #e0e0e0; }
  .btn.upd { background: #2e7d32; color: #fff; }
  .btn.upd:hover { background: #1b5e20; }
  .btn:disabled { opacity: 0.6; cursor: default; }
  #updateStatus { font-size: 0.85rem; margin-left: auto; }
  #updateStatus.ok { color: #4caf50; }
  #updateStatus.warn { color: #ffb74d; }
  #updateStatus.err { color: #ef5350; }
</style>
</head>
<body>
<div class="container">
  <h1>JackedLog Backups</h1>
  <div class="update-panel">
    <div class="ver">Server version: <strong>v$serverVersion</strong></div>
    <button class="btn upd" id="checkBtn" onclick="checkUpdate()">Check for updates</button>
    <button class="btn upd" id="applyBtn" onclick="applyUpdate()" style="display:none">Update now</button>
    <span id="updateStatus"></span>
  </div>
  <div class="storage">Total storage: $totalFormatted</div>
  <table>
    <thead>
      <tr><th>Date</th><th>Size</th><th>DB Version</th><th>Status</th><th>Actions</th></tr>
    </thead>
    <tbody>
      $tableBody
    </tbody>
  </table>
</div>
<script>
const KEY = new URLSearchParams(window.location.search).get('key') || '';

function downloadBackup(filename) {
  fetch('/api/backup/' + filename, {
    headers: { 'Authorization': 'Bearer ' + KEY }
  })
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
  fetch('/api/backup/' + filename, {
    method: 'DELETE',
    headers: { 'Authorization': 'Bearer ' + KEY }
  })
  .then(r => { if (!r.ok) throw new Error('Delete failed'); location.reload(); })
  .catch(e => alert(e.message));
}

function setStatus(msg, cls) {
  const el = document.getElementById('updateStatus');
  el.textContent = msg;
  el.className = cls || '';
}

function short(sha) { return sha ? sha.substring(0, 7) : '?'; }

function checkUpdate() {
  const btn = document.getElementById('checkBtn');
  btn.disabled = true;
  setStatus('Checking…', '');
  fetch('/api/update/check', { headers: { 'Authorization': 'Bearer ' + KEY } })
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
  fetch('/api/update/apply', {
    method: 'POST',
    headers: { 'Authorization': 'Bearer ' + KEY }
  })
    .then(r => r.json())
    .then(d => setStatus(d.message, d.triggered ? 'ok' : 'warn'))
    .catch(e => setStatus(e.message, 'err'))
    .finally(() => { btn.disabled = false; });
}
</script>
</body>
</html>''';

  return Response.ok(html, headers: {'content-type': 'text/html'});
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}
