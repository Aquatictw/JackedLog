import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';

import 'package:jackedlog_server/config.dart';
import 'package:jackedlog_server/middleware/auth.dart';
import 'package:jackedlog_server/middleware/cors.dart';
import 'package:jackedlog_server/api/health_api.dart';
import 'package:jackedlog_server/api/backup_api.dart';
import 'package:jackedlog_server/api/manage_page.dart';
import 'package:jackedlog_server/services/backup_service.dart';

void main() async {
  final config = ServerConfig.fromEnvironment();

  // Ensure data directory exists
  Directory(config.dataDir).createSync(recursive: true);

  // Initialize health API with server start time
  initHealthApi(config.startTime);

  // Initialize services
  final backupService = BackupService(config.dataDir);

  // Configure routes
  final router = Router();
  router.get('/api/health', healthHandler);
  router.post('/api/backup', (req) => uploadBackupHandler(req, backupService));
  router.get('/api/backups', (req) => listBackupsHandler(req, backupService));
  router.get('/api/backup/<filename>',
      (req, String filename) => downloadBackupHandler(req, filename, backupService));
  router.delete('/api/backup/<filename>',
      (req, String filename) => deleteBackupHandler(req, filename, backupService));
  router.get('/manage',
      (req) => managePageHandler(req, backupService, config.apiKey));

  // Build middleware pipeline
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsMiddleware())
      .addMiddleware(authMiddleware(config.apiKey))
      .addHandler(router.call);

  // Start server
  final server = await io.serve(handler, '0.0.0.0', config.port);
  print('JackedLog Server v1.0.0');
  print('Listening on port ${server.port}');
  print('Data directory: ${config.dataDir}');
}
