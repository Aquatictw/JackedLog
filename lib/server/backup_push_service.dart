import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../database/database.dart';
import '../main.dart';

class BackupPushService {
  static Future<void> pushBackup(String serverUrl, String apiKey) async {
    try {
      // Checkpoint WAL to ensure all changes are in the main database file
      await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');

      // Read the SQLite database file
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'jackedlog.sqlite'));
      final bytes = await file.readAsBytes();

      // Send via dart:io HttpClient
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 30);
      try {
        final uri = Uri.parse('$serverUrl/api/backup');
        final request = await client.postUrl(uri);
        request.headers.set('Authorization', 'Bearer $apiKey');
        request.headers.set('Content-Type', 'application/octet-stream');
        request.headers.set('Content-Length', bytes.length.toString());
        request.add(bytes);
        final response = await request.close();
        final statusCode = response.statusCode;
        final responseBody = await response.transform(utf8.decoder).join();
        if (statusCode == 401 || statusCode == 403) {
          throw Exception('Authentication failed. Check your API key.');
        }
        if (statusCode != 200 && statusCode != 201) {
          throw Exception('Server returned status $statusCode: $responseBody');
        }
      } finally {
        client.close();
      }

      // Success: update settings with timestamp and status
      await db.settings.update().write(
            SettingsCompanion(
              lastPushTime: Value(DateTime.now()),
              lastPushStatus: const Value('success'),
            ),
          );
    } catch (e) {
      // Failure: update settings with failed status and time, then rethrow
      await db.settings.update().write(
            SettingsCompanion(
              lastPushStatus: const Value('failed'),
              lastPushTime: Value(DateTime.now()),
            ),
          );
      rethrow;
    }
  }
}
