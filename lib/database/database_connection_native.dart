import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

LazyDatabase createNativeConnection() {
  return LazyDatabase(() async {
    final folder = await getApplicationDocumentsDirectory();
    final oldFile = File(p.join(folder.path, 'flexify.sqlite'));
    final newFile = File(p.join(folder.path, 'jackedlog.sqlite'));

    // Migration: Copy old database to new location if it exists
    try {
      if (await oldFile.exists() && !await newFile.exists()) {
        await oldFile.copy(newFile.path);
        // Verify copy succeeded
        if (await newFile.exists()) {
          final oldSize = await oldFile.length();
          final newSize = await newFile.length();
          if (oldSize == newSize) {
            debugPrint('Database migrated: flexify.sqlite → jackedlog.sqlite');
            // Keep old file as backup (don't delete)
          } else {
            debugPrint('Database migration warning: file sizes differ');
          }
        }
      }
    } catch (e) {
      debugPrint('Database migration error: $e');
      // Fall back to old file if new one doesn't exist
      if (!await newFile.exists() && await oldFile.exists()) {
        final file = oldFile;
        if (Platform.isAndroid) {
          await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
        }

        final cache = (await getTemporaryDirectory()).path;
        sqlite3.tempDirectory = cache;
        return NativeDatabase.createInBackground(
          file,
          logStatements: kDebugMode,
        );
      }
    }

    final file = newFile;

    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }

    final cache = (await getTemporaryDirectory()).path;
    sqlite3.tempDirectory = cache;
    return NativeDatabase.createInBackground(
      file,
      logStatements: kDebugMode,
    );
  });
}

LazyDatabase createWebConnection() {
  throw UnsupportedError('Web connection not supported on native platforms');
}
