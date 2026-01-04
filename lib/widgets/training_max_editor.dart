import 'package:drift/drift.dart' hide Column;
import 'package:flexify/database/database.dart';
import 'package:flexify/main.dart';
import 'package:flexify/settings/settings_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// Dialog for editing all 5/3/1 Training Max values
class TrainingMaxEditor extends StatefulWidget {
  const TrainingMaxEditor({super.key});

  @override
  State<TrainingMaxEditor> createState() => _TrainingMaxEditorState();
}

class _TrainingMaxEditorState extends State<TrainingMaxEditor> {
  late TextEditingController _squatController;
  late TextEditingController _benchController;
  late TextEditingController _deadliftController;
  late TextEditingController _pressController;
  String _unit = 'kg';
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _squatController = TextEditingController();
    _benchController = TextEditingController();
    _deadliftController = TextEditingController();
    _pressController = TextEditingController();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = context.read<SettingsState>().value;
    _unit = settings.strengthUnit;

    final setting = await db.settings.select().getSingle();
    setState(() {
      _squatController.text =
          setting.fivethreeoneSquatTm?.toStringAsFixed(1) ?? '';
      _benchController.text =
          setting.fivethreeoneBenchTm?.toStringAsFixed(1) ?? '';
      _deadliftController.text =
          setting.fivethreeoneDeadliftTm?.toStringAsFixed(1) ?? '';
      _pressController.text =
          setting.fivethreeonePressTm?.toStringAsFixed(1) ?? '';
    });
  }

  Future<void> _saveAll() async {
    final squat = double.tryParse(_squatController.text);
    final bench = double.tryParse(_benchController.text);
    final deadlift = double.tryParse(_deadliftController.text);
    final press = double.tryParse(_pressController.text);

    await db.settings.update().write(
          SettingsCompanion(
            fivethreeoneSquatTm: Value(squat),
            fivethreeoneBenchTm: Value(bench),
            fivethreeoneDeadliftTm: Value(deadlift),
            fivethreeonePressTm: Value(press),
          ),
        );

    if (mounted) {
      HapticFeedback.mediumImpact();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Training Max values saved'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _markChanged() {
    if (!_hasChanges) {
      setState(() {
        _hasChanges = true;
      });
    }
  }

  @override
  void dispose() {
    _squatController.dispose();
    _benchController.dispose();
    _deadliftController.dispose();
    _pressController.dispose();
    super.dispose();
  }

  Widget _buildTmField({
    required String label,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: 'Enter Training Max',
            suffixText: _unit,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.monitor_weight_outlined),
          ),
          onChanged: (_) => _markChanged(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Row(
                children: [
                  Icon(Icons.edit_note, color: colorScheme.primary, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '5/3/1 Training Max',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onPrimaryContainer,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    color: colorScheme.onPrimaryContainer,
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTmField(
                      label: 'Squat',
                      controller: _squatController,
                    ),
                    const SizedBox(height: 20),
                    _buildTmField(
                      label: 'Bench Press',
                      controller: _benchController,
                    ),
                    const SizedBox(height: 20),
                    _buildTmField(
                      label: 'Deadlift',
                      controller: _deadliftController,
                    ),
                    const SizedBox(height: 20),
                    _buildTmField(
                      label: 'Overhead Press',
                      controller: _pressController,
                    ),
                  ],
                ),
              ),
            ),

            // Info Footer & Save Button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline,
                          size: 16, color: colorScheme.tertiary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'TM should be 90% of your true 1RM',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _saveAll,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Save All'),
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
