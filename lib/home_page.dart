import 'package:drift/drift.dart' hide Column;
import 'package:jackedlog/bottom_nav.dart';
import 'package:jackedlog/database/database.dart';
import 'package:jackedlog/graph/graphs_page.dart';
import 'package:jackedlog/main.dart';
import 'package:jackedlog/notes/notes_page.dart';
import 'package:jackedlog/plan/plans_page.dart';
import 'package:jackedlog/sets/history_page.dart';
import 'package:jackedlog/settings/settings_page.dart';
import 'package:jackedlog/settings/settings_state.dart';
import 'package:jackedlog/timer/rest_timer_bar.dart';
import 'package:jackedlog/utils.dart';
import 'package:jackedlog/workouts/active_workout_bar.dart';
import 'package:jackedlog/workouts/workout_state.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late TabController controller;

  @override
  void initState() {
    super.initState();

    final setting = context.read<SettingsState>().value.tabs;
    final tabs = setting.split(',');
    controller = TabController(length: tabs.length, vsync: this);

    // Register TabController with WorkoutState for cross-tab navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final plansIndex = tabs.indexOf('PlansPage');
      context.read<WorkoutState>().setTabController(controller, plansIndex);
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void hideTab(BuildContext context, String tab) {
    final state = context.read<SettingsState>();
    final old = state.value.tabs;
    var tabs = state.value.tabs.split(',');

    if (tabs.length == 1) return toast("Can't hide everything!");
    tabs.remove(tab);
    db.settings.update().write(
          SettingsCompanion(
            tabs: Value(tabs.join(',')),
          ),
        );
    toast(
      'Hid $tab',
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () {
          db.settings.update().write(
                SettingsCompanion(
                  tabs: Value(old),
                ),
              );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final setting = context
        .select<SettingsState, String>((settings) => settings.value.tabs);
    final tabs = setting.split(',');
    final scrollableTabs = context.select<SettingsState, bool>(
      (settings) => settings.value.scrollableTabs,
    );

    if (tabs.length != controller.length) {
      controller.dispose();
      controller = TabController(length: tabs.length, vsync: this);
      if (controller.index >= tabs.length) controller.index = tabs.length - 1;
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      extendBodyBehindAppBar: true,
      extendBody: true,
      body: SafeArea(
        child: Stack(
          children: [
            TabBarView(
              controller: controller,
              physics: scrollableTabs
                  ? const AlwaysScrollableScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              children: tabs.map((tab) {
                if (tab == 'HistoryPage')
                  return HistoryPage(tabController: controller);
                else if (tab == 'PlansPage')
                  return PlansPage(
                    tabController: controller,
                  );
                else if (tab == 'GraphsPage')
                  return GraphsPage(tabController: controller);
                else if (tab == 'NotesPage')
                  return const NotesPage();
                else if (tab == 'SettingsPage')
                  return const SettingsPage();
                else
                  return ErrorWidget("Couldn't build tab content.");
              }).toList(),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const RestTimerBar(),
                  const ActiveWorkoutBar(),
                  ValueListenableBuilder(
                    valueListenable: controller.animation!,
                    builder: (context, value, child) {
                      return BottomNav(
                        tabs: tabs,
                        currentIndex: value.round(),
                        onTap: (index) {
                          controller.animateTo(index);
                        },
                        onLongPress: hideTab,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
