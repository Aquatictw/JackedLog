import 'package:flexify/settings/settings_state.dart';
import 'package:flexify/timer/timer_progress_widgets.dart';
import 'package:flexify/timer/timer_state.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Quick access timer dialog that can be opened from anywhere
class TimerQuickAccessDialog extends StatefulWidget {
  const TimerQuickAccessDialog({super.key});

  @override
  State<TimerQuickAccessDialog> createState() => _TimerQuickAccessDialogState();
}

class _TimerQuickAccessDialogState extends State<TimerQuickAccessDialog> {
  Duration _selectedDuration = const Duration(minutes: 1);
  bool _isRunning = false;

  // Preset durations
  static const List<Duration> presets = [
    Duration(seconds: 30),
    Duration(minutes: 1),
    Duration(minutes: 2),
    Duration(minutes: 3),
    Duration(minutes: 5),
    Duration(minutes: 10),
  ];

  @override
  void initState() {
    super.initState();
    // Check if timer is already running
    final timerState = context.read<TimerState>();
    _isRunning = timerState.timer.getDuration() != Duration.zero;
  }

  void _startTimer() async {
    final settings = context.read<SettingsState>().value;
    final timerState = context.read<TimerState>();

    await timerState.startTimer(
      'Quick Timer',
      _selectedDuration,
      settings.alarmSound,
      settings.vibrate,
    );

    setState(() {
      _isRunning = true;
    });
  }

  void _stopTimer() async {
    final timerState = context.read<TimerState>();
    await timerState.stopTimer();

    setState(() {
      _isRunning = false;
    });
  }

  String _formatDuration(Duration duration) {
    if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final timerState = context.watch<TimerState>();

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.timer,
                    color: colorScheme.onPrimaryContainer,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    _isRunning ? 'Timer Running' : 'Start Timer',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            if (_isRunning) ...[
              // Timer progress indicator
              const SizedBox(
                height: 250,
                child: Center(
                  child: TimerCircularProgressIndicator(),
                ),
              ),
              const SizedBox(height: 24),

              // Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton.filled(
                    onPressed: () {
                      final settings = context.read<SettingsState>().value;
                      timerState.subtractSeconds(30, settings.alarmSound, settings.vibrate);
                    },
                    icon: const Icon(Icons.remove),
                    tooltip: '-30s',
                  ),
                  FilledButton.tonal(
                    onPressed: () {
                      final settings = context.read<SettingsState>().value;
                      timerState.addOneMinute(settings.alarmSound, settings.vibrate);
                    },
                    child: const Text('+1 min'),
                  ),
                  IconButton.filled(
                    onPressed: _stopTimer,
                    icon: const Icon(Icons.stop),
                    tooltip: 'Stop',
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.error,
                      foregroundColor: colorScheme.onError,
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Duration presets
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: presets.map((duration) {
                  final isSelected = _selectedDuration == duration;
                  return ChoiceChip(
                    label: Text(_formatDuration(duration)),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _selectedDuration = duration;
                        });
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Start button
              FilledButton.icon(
                onPressed: () {
                  _startTimer();
                },
                icon: const Icon(Icons.play_arrow),
                label: Text('Start ${_formatDuration(_selectedDuration)} Timer'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Close button
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Function to show the timer quick access dialog
Future<void> showTimerQuickAccess(BuildContext context) async {
  await showDialog(
    context: context,
    builder: (context) => const TimerQuickAccessDialog(),
  );
}
