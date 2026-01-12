import 'package:flutter/material.dart';

import '../delete_records_button.dart';
import '../export_data.dart';

class FailedMigrationsPage extends StatelessWidget {

  const FailedMigrationsPage({required this.error, super.key});
  final Object error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title: const Text('Failed migrations'),
          leading: const Icon(Icons.error),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const ListTile(
                title: Text(
                  'Something went wrong when creating/upgrading your database. Usually this can be fixed by deleting & re-creating your records.',
                ),
              ),
              SizedBox(
                height: 300,
                child: SingleChildScrollView(
                  child: ListTile(
                    title: const Text('Error message:'),
                    subtitle: Text(error.toString()),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const ExportData(),
              DeleteDatabaseButton(ctx: context),
            ],
          ),
        ),
      ),
    );
  }
}
