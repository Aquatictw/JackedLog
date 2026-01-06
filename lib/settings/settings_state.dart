import 'dart:async';

import 'package:drift/drift.dart';
import 'package:jackedlog/database/database.dart';
import 'package:jackedlog/main.dart';
import 'package:flutter/material.dart';

class SettingsState extends ChangeNotifier {
  late Setting value;
  StreamSubscription? subscription;

  SettingsState(Setting setting) {
    value = setting;
    init();
  }

  @override
  dispose() {
    super.dispose();
    subscription?.cancel();
  }

  Future<void> init() async {
    subscription =
        (db.settings.select()..limit(1)).watchSingle().listen((event) {
      value = event;
      notifyListeners();
    });
  }
}
