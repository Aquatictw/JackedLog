import 'package:shelf/shelf.dart';

import '../services/backup_service.dart';

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
</style>
</head>
<body>
<div class="container">
  <h1>JackedLog Backups</h1>
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
