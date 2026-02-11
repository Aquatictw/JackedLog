import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../database/database.dart';
import 'block_creation_dialog.dart';
import 'fivethreeone_state.dart';
import 'schemes.dart';

/// Full-page block overview with vertical timeline and week advancement
class BlockOverviewPage extends StatelessWidget {
  const BlockOverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<FiveThreeOneState>();
    final block = state.activeBlock;

    return Scaffold(
      appBar: AppBar(
        title: Text(block == null
            ? '5/3/1 Block'
            : '5/3/1 ${state.positionLabel}'),
      ),
      body: block == null ? _buildNoBlock(context) : _buildTimeline(context, state, block),
    );
  }

  Widget _buildNoBlock(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'No active block',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => const BlockCreationDialog(),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Start Block'),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(
      BuildContext context, FiveThreeOneState state, FiveThreeOneBlock block) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _TmCard(block: block),
          const SizedBox(height: 20),
          for (int i = 0; i < cycleNames.length; i++)
            _CycleEntry(
              cycleIndex: i,
              currentCycle: block.currentCycle,
              currentWeek: block.currentWeek,
              block: block,
            ),
          const SizedBox(height: 24),
          _CompleteWeekButton(block: block),
        ],
      ),
    );
  }
}

class _CycleEntry extends StatelessWidget {
  const _CycleEntry({
    required this.cycleIndex,
    required this.currentCycle,
    required this.currentWeek,
    required this.block,
  });

  final int cycleIndex;
  final int currentCycle;
  final int currentWeek;
  final FiveThreeOneBlock block;

  @override
  Widget build(BuildContext context) {
    final isCompleted = cycleIndex < currentCycle;
    final isCurrent = cycleIndex == currentCycle;
    final colorScheme = Theme.of(context).colorScheme;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left: vertical line + circle indicator
          SizedBox(
            width: 40,
            child: Column(
              children: [
                if (cycleIndex > 0)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isCompleted || isCurrent
                          ? colorScheme.primary
                          : colorScheme.outlineVariant,
                    ),
                  ),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted
                        ? colorScheme.primary
                        : isCurrent
                            ? colorScheme.primaryContainer
                            : colorScheme.surfaceContainerLow,
                    border: isCurrent
                        ? Border.all(color: colorScheme.primary, width: 2)
                        : null,
                  ),
                  child: isCompleted
                      ? Icon(Icons.check,
                          size: 14, color: colorScheme.onPrimary)
                      : null,
                ),
                if (cycleIndex < cycleNames.length - 1)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isCompleted
                          ? colorScheme.primary
                          : colorScheme.outlineVariant,
                    ),
                  ),
              ],
            ),
          ),
          // Right: cycle card
          Expanded(
            child: Card(
              color: isCurrent
                  ? colorScheme.primaryContainer
                  : isCompleted
                      ? colorScheme.surfaceContainerHighest
                      : colorScheme.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cycleNames[cycleIndex],
                      style: TextStyle(
                        fontWeight:
                            isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    Text(
                      getMainSchemeName(cycleIndex),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (isCurrent) ..._buildWeekIndicators(context),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildWeekIndicators(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final maxWeeks = cycleWeeks[cycleIndex];
    final widgets = <Widget>[const SizedBox(height: 8)];

    for (int w = 1; w <= maxWeeks; w++) {
      final isWeekCompleted = w < currentWeek;
      final isWeekCurrent = w == currentWeek;

      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isWeekCompleted
                      ? colorScheme.primary
                      : isWeekCurrent
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onPrimaryContainer.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Week $w',
                style: TextStyle(
                  fontWeight:
                      isWeekCurrent ? FontWeight.bold : FontWeight.normal,
                  color: isWeekCompleted
                      ? colorScheme.primary
                      : isWeekCurrent
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onPrimaryContainer.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return widgets;
  }

}

class _TmCard extends StatefulWidget {
  const _TmCard({required this.block});

  final FiveThreeOneBlock block;

  @override
  State<_TmCard> createState() => _TmCardState();
}

class _TmCardState extends State<_TmCard> {
  late TextEditingController _squatController;
  late TextEditingController _benchController;
  late TextEditingController _deadliftController;
  late TextEditingController _pressController;

  late FocusNode _squatFocus;
  late FocusNode _benchFocus;
  late FocusNode _deadliftFocus;
  late FocusNode _pressFocus;

  @override
  void initState() {
    super.initState();
    _squatController = TextEditingController(text: _formatTm(widget.block.squatTm));
    _benchController = TextEditingController(text: _formatTm(widget.block.benchTm));
    _deadliftController = TextEditingController(text: _formatTm(widget.block.deadliftTm));
    _pressController = TextEditingController(text: _formatTm(widget.block.pressTm));

    _squatFocus = FocusNode()..addListener(() => _onFocusLost(_squatFocus, 'squat', _squatController));
    _benchFocus = FocusNode()..addListener(() => _onFocusLost(_benchFocus, 'bench', _benchController));
    _deadliftFocus = FocusNode()..addListener(() => _onFocusLost(_deadliftFocus, 'deadlift', _deadliftController));
    _pressFocus = FocusNode()..addListener(() => _onFocusLost(_pressFocus, 'press', _pressController));
  }

  @override
  void didUpdateWidget(covariant _TmCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update controllers if block values changed externally (e.g. after TM bump)
    if (!_squatFocus.hasFocus) _squatController.text = _formatTm(widget.block.squatTm);
    if (!_benchFocus.hasFocus) _benchController.text = _formatTm(widget.block.benchTm);
    if (!_deadliftFocus.hasFocus) _deadliftController.text = _formatTm(widget.block.deadliftTm);
    if (!_pressFocus.hasFocus) _pressController.text = _formatTm(widget.block.pressTm);
  }

  String _formatTm(double value) {
    return value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);
  }

  void _onFocusLost(FocusNode node, String exercise, TextEditingController controller) {
    if (!node.hasFocus) {
      _saveTm(exercise, controller);
    }
  }

  void _saveTm(String exercise, TextEditingController controller) {
    final value = double.tryParse(controller.text);
    if (value != null && value > 0) {
      context.read<FiveThreeOneState>().updateTm(exercise: exercise, value: value);
    }
  }

  @override
  void dispose() {
    _squatController.dispose();
    _benchController.dispose();
    _deadliftController.dispose();
    _pressController.dispose();
    _squatFocus.dispose();
    _benchFocus.dispose();
    _deadliftFocus.dispose();
    _pressFocus.dispose();
    super.dispose();
  }

  Widget _buildTmField({
    required String label,
    required String exerciseKey,
    required TextEditingController controller,
    required FocusNode focusNode,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        labelText: label,
        suffixText: widget.block.unit,
        border: const OutlineInputBorder(),
      ),
      onSubmitted: (_) => _saveTm(exerciseKey, controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 2,
      color: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.monitor_weight_outlined,
                    size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Training Max',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    widget.block.unit,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildTmField(
                    label: 'Squat',
                    exerciseKey: 'squat',
                    controller: _squatController,
                    focusNode: _squatFocus,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTmField(
                    label: 'Bench',
                    exerciseKey: 'bench',
                    controller: _benchController,
                    focusNode: _benchFocus,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildTmField(
                    label: 'Deadlift',
                    exerciseKey: 'deadlift',
                    controller: _deadliftController,
                    focusNode: _deadliftFocus,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTmField(
                    label: 'OHP',
                    exerciseKey: 'press',
                    controller: _pressController,
                    focusNode: _pressFocus,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CompleteWeekButton extends StatelessWidget {
  const _CompleteWeekButton({required this.block});

  final FiveThreeOneBlock block;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<FiveThreeOneState>();

    if (state.isBlockComplete) {
      return const Center(
        child: Text(
          'Block Complete',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      );
    }

    return FilledButton.icon(
      onPressed: () async {
        final state = context.read<FiveThreeOneState>();
        if (state.needsTmBump) {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Bump Training Max?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      'Squat: ${block.squatTm} \u2192 ${(block.squatTm + 4.5).toStringAsFixed(1)} ${block.unit}'),
                  Text(
                      'Bench: ${block.benchTm} \u2192 ${(block.benchTm + 2.2).toStringAsFixed(1)} ${block.unit}'),
                  Text(
                      'Deadlift: ${block.deadliftTm} \u2192 ${(block.deadliftTm + 4.5).toStringAsFixed(1)} ${block.unit}'),
                  Text(
                      'OHP: ${block.pressTm} \u2192 ${(block.pressTm + 2.2).toStringAsFixed(1)} ${block.unit}'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Skip'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Bump TMs'),
                ),
              ],
            ),
          );
          if (confirmed == true) {
            await state.bumpTms();
          }
        }
        await state.advanceWeek();
      },
      icon: const Icon(Icons.arrow_forward),
      label: const Text('Complete Week'),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
      ),
    );
  }
}
