import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_multipart/shelf_multipart.dart';

import '../services/backup_service.dart';

Response _jsonResponse(int statusCode, Object body) {
  return Response(statusCode,
      body: jsonEncode(body),
      headers: {'content-type': 'application/json'});
}

/// POST /api/backup - Upload a backup file
Future<Response> uploadBackupHandler(
    Request request, BackupService backupService) async {
  try {
    Stream<List<int>>? fileStream;

    // Check for multipart/form-data
    final formData = request.formData();
    if (formData != null) {
      await for (final field in formData.formData) {
        if (field.name == 'file' || field.filename != null) {
          fileStream = field.part;
          break;
        }
      }
    } else {
      // Non-multipart: always try to read raw body regardless of content-type
      fileStream = request.read();
    }

    print(
        'Upload attempt: content-type=${request.headers['content-type']}');

    if (fileStream == null) {
      return _jsonResponse(400, {'error': 'No file uploaded'});
    }

    final info = await backupService.storeBackup(fileStream);
    print('Backup stored: ${info.filename} (v${info.dbVersion})');
    return _jsonResponse(
        200, {'filename': info.filename, 'dbVersion': info.dbVersion});
  } on FormatException catch (e) {
    return _jsonResponse(400, {'error': e.message});
  } catch (e) {
    print('Error in uploadBackupHandler: $e');
    return _jsonResponse(500, {'error': 'Internal server error'});
  }
}

/// GET /api/backups - List all backups
Response listBackupsHandler(Request request, BackupService backupService) {
  try {
    final backups = backupService.listBackups();
    return _jsonResponse(200, backups.map((b) => b.toJson()).toList());
  } catch (e) {
    print('Error in listBackupsHandler: $e');
    return _jsonResponse(500, {'error': 'Internal server error'});
  }
}

/// GET /api/backup/<filename> - Download a backup file
Response downloadBackupHandler(
    Request request, String filename, BackupService backupService) {
  try {
    final file = backupService.getBackup(filename);
    if (file == null) {
      return _jsonResponse(404, {'error': 'Backup not found'});
    }

    return Response.ok(
      file.openRead(),
      headers: {
        'content-type': 'application/octet-stream',
        'content-disposition': 'attachment; filename="$filename"',
        'content-length': file.statSync().size.toString(),
      },
    );
  } catch (e) {
    print('Error in downloadBackupHandler: $e');
    return _jsonResponse(500, {'error': 'Internal server error'});
  }
}

/// DELETE /api/backup/<filename> - Delete a backup file
Response deleteBackupHandler(
    Request request, String filename, BackupService backupService) {
  try {
    final deleted = backupService.deleteBackup(filename);
    if (!deleted) {
      return _jsonResponse(404, {'error': 'Backup not found'});
    }

    return _jsonResponse(200, {'deleted': true});
  } catch (e) {
    print('Error in deleteBackupHandler: $e');
    return _jsonResponse(500, {'error': 'Internal server error'});
  }
}
