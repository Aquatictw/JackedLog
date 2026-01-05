import 'package:drift/drift.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flexify/database/database.dart';
import 'package:flexify/graph/cardio_data.dart';
import 'package:flexify/graph/flex_line.dart';
import 'package:flexify/main.dart';
import 'package:flexify/settings/settings_state.dart';
import 'package:flexify/widgets/artistic_color_picker.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

List<Widget> getAppearanceSettings(
  BuildContext context,
  String term,
  SettingsState settings,
) {
  return [
    if ('theme'.contains(term.toLowerCase()))
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: DropdownButtonFormField<ThemeMode>(
          initialValue: ThemeMode.values
              .byName(settings.value.themeMode.replaceFirst('ThemeMode.', '')),
          decoration: const InputDecoration(
            labelStyle: TextStyle(),
            labelText: 'Theme',
          ),
          items: const [
            DropdownMenuItem(
              value: ThemeMode.system,
              child: Text("System"),
            ),
            DropdownMenuItem(
              value: ThemeMode.dark,
              child: Text("Dark"),
            ),
            DropdownMenuItem(
              value: ThemeMode.light,
              child: Text("Light"),
            ),
          ],
          onChanged: (value) => db.settings.update().write(
                SettingsCompanion(
                  themeMode: Value(value.toString()),
                ),
              ),
        ),
      ),
    if ('system color scheme'.contains(term.toLowerCase()))
      Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Tooltip(
          message: 'Use the primary color of your device for the app',
          child: ListTile(
            title: const Text('System color scheme'),
            leading: settings.value.systemColors
                ? const Icon(Icons.color_lens)
                : const Icon(Icons.color_lens_outlined),
            onTap: () => db.settings.update().write(
                  SettingsCompanion(
                    systemColors: Value(!settings.value.systemColors),
                  ),
                ),
            trailing: Switch(
              value: settings.value.systemColors,
              onChanged: (value) => db.settings.update().write(
                    SettingsCompanion(
                      systemColors: Value(value),
                    ),
                  ),
            ),
          ),
        ),
      ),
    if ('custom color'.contains(term.toLowerCase()) ||
        'app color'.contains(term.toLowerCase()))
      Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Tooltip(
          message: 'Choose a custom color for your app theme',
          child: ListTile(
            title: const Text('Custom app color'),
            subtitle: Text(
              settings.value.systemColors
                  ? 'Disabled (using system colors)'
                  : 'Tap to customize',
              style: TextStyle(
                color: settings.value.systemColors
                    ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)
                    : null,
              ),
            ),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Color(settings.value.customColorSeed),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(settings.value.customColorSeed).withValues(alpha: 0.4),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const Icon(Icons.palette, color: Colors.white, size: 20),
            ),
            enabled: !settings.value.systemColors,
            onTap: settings.value.systemColors
                ? null
                : () async {
                    final color = await showDialog<Color>(
                      context: context,
                      builder: (context) => ArtisticColorPicker(
                        initialColor: Color(settings.value.customColorSeed),
                        onColorChanged: (color) {},
                      ),
                    );
                    if (color != null) {
                      await db.settings.update().write(
                        SettingsCompanion(
                          customColorSeed: Value(color.value),
                        ),
                      );
                    }
                  },
            trailing: settings.value.systemColors
                ? null
                : Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
          ),
        ),
      ),
    if ('show images'.contains(term.toLowerCase()))
      Tooltip(
        message: 'Pick/display images on the history page',
        child: ListTile(
          title: const Text('Show images'),
          leading: settings.value.showImages
              ? const Icon(Icons.image)
              : const Icon(Icons.image_outlined),
          onTap: () => db.settings.update().write(
                SettingsCompanion(
                  showImages: Value(!settings.value.showImages),
                ),
              ),
          trailing: Switch(
            value: settings.value.showImages,
            onChanged: (value) => db.settings.update().write(
                  SettingsCompanion(
                    showImages: Value(value),
                  ),
                ),
          ),
        ),
      ),
  ];
}

class AppearanceSettings extends StatelessWidget {
  const AppearanceSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsState>();

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text("Appearance"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: ListView(
          children: getAppearanceSettings(context, '', settings),
        ),
      ),
    );
  }
}
