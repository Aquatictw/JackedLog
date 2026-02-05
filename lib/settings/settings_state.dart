import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';

import '../database/database.dart';
import '../main.dart';

class SettingsState extends ChangeNotifier {

  SettingsState(Setting setting) {
    value = setting;
    init();
  }
  late Setting value;
  StreamSubscription? subscription;

  @override
  void dispose() {
    super.dispose();
    subscription?.cancel();
  }

  Future<void> init() async {
    subscription =
        (db.settings.select()..limit(1)).watchSingleOrNull().listen((event) {
      if (event != null) {
        value = event;
        notifyListeners();
      }
      // If event is null, keep existing value (graceful degradation)
    });
  }
}
