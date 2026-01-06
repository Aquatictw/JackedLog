import 'package:jackedlog/delete_records_button.dart';
import 'package:jackedlog/export_data.dart';
import 'package:jackedlog/import_data.dart';
import 'package:jackedlog/import_hevy.dart';
import 'package:jackedlog/settings/settings_state.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

List<Widget> getDataSettings(
  String term,
  SettingsState settings,
  BuildContext context,
) {
  return [
    if ('export data'.contains(term.toLowerCase())) const ExportData(),
    if ('import data'.contains(term.toLowerCase())) ImportData(ctx: context),
    if ('import hevy'.contains(term.toLowerCase())) ImportHevy(ctx: context),
    if ('delete database'.contains(term.toLowerCase()))
      DeleteDatabaseButton(ctx: context),
  ];
}

class DataSettings extends StatelessWidget {
  const DataSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsState>();

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text("Data management"),
      ),
      body: ListView(
        children: getDataSettings('', settings, context),
      ),
    );
  }
}
