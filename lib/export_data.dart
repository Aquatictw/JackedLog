import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'backup/workout_archive.dart';
import 'main.dart';
import 'utils.dart';

class ExportData extends StatelessWidget {
  const ExportData({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () {
        showModalBottomSheet(
          context: context,
          useRootNavigator: true,
          builder: (context) {
            return SafeArea(
              child: Wrap(
                children: <Widget>[
                  ListTile(
                    leading: const Icon(Icons.fitness_center),
                    title: const Text('Workouts'),
                    onTap: () async {
                      Navigator.pop(context);
                      if (!await requestNotificationPermission()) return;

                      final zipBytes = await WorkoutArchive(db).encode();
                      await FilePicker.platform.saveFile(
                        fileName: 'jackedlog_workouts.zip',
                        bytes: zipBytes,
                        type: FileType.custom,
                        allowedExtensions: ['zip'],
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.storage),
                    title: const Text('Database'),
                    onTap: () async {
                      Navigator.pop(context);

                      // Checkpoint WAL to ensure all changes are in the main database file
                      await db
                          .customStatement('PRAGMA wal_checkpoint(TRUNCATE)');

                      final dbFolder = await getApplicationDocumentsDirectory();
                      final file =
                          File(p.join(dbFolder.path, 'jackedlog.sqlite'));
                      final bytes = await file.readAsBytes();
                      await FilePicker.platform.saveFile(
                        fileName: 'jackedlog.sqlite',
                        bytes: bytes,
                        type: FileType.custom,
                        allowedExtensions: ['sqlite'],
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
      icon: const Icon(Icons.download),
      label: const Text('Export data'),
    );
  }
}
