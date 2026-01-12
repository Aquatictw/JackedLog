import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'main.dart';

class DeleteDatabaseButton extends StatelessWidget {

  const DeleteDatabaseButton({
    required this.ctx, super.key,
  });
  final BuildContext ctx;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Confirm Delete'),
              content: const Text(
                'Are you sure you want to delete your database? This action is not reversible and will destroy all your data.',
              ),
              actions: <Widget>[
                TextButton.icon(
                  label: const Text('Cancel'),
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
                TextButton.icon(
                  label: const Text('Delete'),
                  icon: const Icon(Icons.delete),
                  onPressed: () async {
                    final dbFolder = await getApplicationDocumentsDirectory();
                    final file = File(
                      p.join(dbFolder.path, 'jackedlog.sqlite'),
                    );
                    await db.close();
                    await db.executor.close();
                    await file.delete();
                    if (defaultTargetPlatform == TargetPlatform.iOS ||
                        defaultTargetPlatform == TargetPlatform.android)
                      SystemNavigator.pop();
                    else
                      exit(0);
                  },
                ),
              ],
            );
          },
        );
      },
      icon: const Icon(Icons.delete),
      label: const Text('Delete database'),
    );
  }
}
