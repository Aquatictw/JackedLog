import 'dart:math';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/database.dart';
import '../workouts/workout_detail_page.dart';
import 'activity_presentation.dart';
import 'activity_widgets.dart';
import 'cardio_activity_store.dart';

class ActivityDetailPage extends StatelessWidget {
  const ActivityDetailPage({
    required this.database,
    required this.id,
    required this.unit,
    super.key,
  });
  final AppDatabase database;
  final String id;
  final String unit;

  Widget _measurementTile(
    BuildContext context,
    String label,
    String value,
    String unit,
  ) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(
            value == '—' ? 'Not recorded' : unit,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      );

  @override
  Widget build(BuildContext context) => StreamBuilder<CardioActivity?>(
        stream: (database.select(database.cardioActivities)
              ..where((a) => a.id.equals(id)))
            .watchSingleOrNull(),
        builder: (context, snapshot) {
          final activity = snapshot.data;
          return Scaffold(
            appBar: AppBar(title: Text(activity?.name ?? 'Cardio activity')),
            body: snapshot.hasError
                ? const Center(child: Text('Unable to load activity'))
                : snapshot.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator())
                    : activity == null
                        ? const Center(
                            child: Text('Activity no longer available'),
                          )
                        : ListView(
                            padding: EdgeInsets.fromLTRB(
                              24,
                              24,
                              24,
                              activityBottomClearance(context),
                            ),
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Chip(
                                    avatar: const Icon(
                                      Icons.directions_run,
                                      size: 18,
                                    ),
                                    label: Text(activityLabel(activity.sport)),
                                  ),
                                  Chip(
                                    label: Text(
                                      activityLabel(activity.environment),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              ActivitySection(
                                title: 'Session',
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: _measurementTile(
                                            context,
                                            'Distance',
                                            activity.distanceMeters == null
                                                ? '—'
                                                : (activity.distanceMeters! /
                                                        cardioUnitMeters(
                                                          unit,
                                                        ))
                                                    .toStringAsFixed(
                                                    2,
                                                  ),
                                            cardioDisplayUnit(unit),
                                          ),
                                        ),
                                        Expanded(
                                          child: _measurementTile(
                                            context,
                                            'Duration',
                                            activity.durationSeconds == null
                                                ? '—'
                                                : (activity.durationSeconds! /
                                                        60)
                                                    .toStringAsFixed(
                                                    1,
                                                  ),
                                            'min',
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 32),
                                    Text(
                                      activityPace(activity, unit),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      activityLabel(
                                        activity.durationBasis,
                                      ),
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              ActivitySection(
                                title: 'Details',
                                child: Column(
                                  children: [
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(
                                        Icons.calendar_today_outlined,
                                      ),
                                      title: Text(
                                        DateFormat.yMMMd().add_jm().format(
                                              activityDisplayDate(activity),
                                            ),
                                      ),
                                      subtitle: Text(
                                        activityDateLabel(activity),
                                      ),
                                    ),
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: const Icon(Icons.edit_note),
                                      title: Text(
                                        activityLabel(activity.source),
                                      ),
                                      subtitle: const Text('Source'),
                                    ),
                                  ],
                                ),
                              ),
                              if (activity.notes?.isNotEmpty ?? false)
                                ActivitySection(
                                  title: 'Notes',
                                  child: Text(activity.notes!),
                                ),
                              if (activity.workoutId != null)
                                TextButton(
                                  onPressed: () async {
                                    final workout = await (database
                                            .select(database.workouts)
                                          ..where(
                                            (w) => w.id
                                                .equals(activity.workoutId!),
                                          ))
                                        .getSingleOrNull();
                                    if (context.mounted && workout != null) {
                                      await Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) => WorkoutDetailPage(
                                            workout: workout,
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  child: const Text(
                                    'Open containing workout',
                                  ),
                                ),
                              if (activity.source == 'manual' ||
                                  activity.source == 'legacy')
                                FilledButton.tonal(
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => ActivityEditorPage(
                                        database: database,
                                        unit: unit,
                                        activity: activity,
                                      ),
                                    ),
                                  ),
                                  child: const Text('Edit activity'),
                                ),
                              TextButton(
                                onPressed: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text(
                                        'Delete activity?',
                                      ),
                                      content: Text(
                                        activity.legacyGymSetId == null
                                            ? 'This removes the recorded activity.'
                                            : 'This also removes the corresponding cardio bout from its workout.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(
                                            context,
                                            false,
                                          ),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(
                                            context,
                                            true,
                                          ),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed != true) return;
                                  try {
                                    await CardioActivityStore(database)
                                        .delete(id);
                                    if (context.mounted) Navigator.pop(context);
                                  } catch (_) {
                                    if (context.mounted)
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Unable to delete activity. Please retry.',
                                          ),
                                        ),
                                      );
                                  }
                                },
                                child: const Text('Delete activity'),
                              ),
                            ],
                          ),
          );
        },
      );
}

class ActivityEditorPage extends StatefulWidget {
  const ActivityEditorPage({
    required this.database,
    required this.unit,
    this.activity,
    super.key,
  });
  final AppDatabase database;
  final String unit;
  final CardioActivity? activity;

  @override
  State<ActivityEditorPage> createState() => _ActivityEditorPageState();
}

class _ActivityEditorPageState extends State<ActivityEditorPage> {
  final _form = GlobalKey<FormState>();
  late final _name =
      TextEditingController(text: widget.activity?.name ?? 'Run');
  late final _distance = TextEditingController(
    text: _number(
      widget.activity?.distanceMeters,
      cardioUnitMeters(widget.unit),
    ),
  );
  late final _duration = TextEditingController(
    text: _number(widget.activity?.durationSeconds, 60),
  );
  late final _notes = TextEditingController(text: widget.activity?.notes);
  late String _sport = widget.activity?.sport ?? 'run';
  late String _environment = widget.activity?.environment ?? 'outdoor';
  late String _basis = widget.activity?.durationBasis ?? 'elapsed';
  late DateTime _date = widget.activity?.startedAt ??
      widget.activity?.recordedAt ??
      DateTime.now();
  bool _saving = false;
  bool _dateChanged = false;
  String? _error;

  String _number(double? value, double factor) =>
      value == null ? '' : (value / factor).toString();

  @override
  void dispose() {
    for (final controller in [_name, _distance, _duration, _notes]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _measurement(String? input) {
    if (input == null || input.trim().isEmpty) return null;
    final value = double.tryParse(input);
    return value == null || !value.isFinite || value < 0
        ? 'Enter a non-negative number or leave blank'
        : null;
  }

  Future<void> _save() async {
    if (_saving) return;
    // ListView can dispose off-screen form fields; validate their controllers too.
    final invalid = _name.text.trim().isEmpty ||
        _measurement(_distance.text) != null ||
        _measurement(_duration.text) != null;
    final visibleFieldsValid = _form.currentState!.validate();
    if (invalid || !visibleFieldsValid) {
      setState(() => _error =
          'Enter a name and valid non-negative measurements, or leave unknown measurements blank.',);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final previous = widget.activity;
      final distance = double.tryParse(_distance.text.trim());
      final duration = double.tryParse(_duration.text.trim());
      final activity = previous ??
          CardioActivity(
            id: 'manual:${List.generate(16, (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0')).join()}',
            name: _name.text.trim(),
            sport: _sport,
            environment: _environment,
            recordedAt: DateTime.now(),
            startedAt: _date,
            startUtcOffsetMinutes: _date.timeZoneOffset.inMinutes,
            durationBasis: _basis,
            warmup: false,
            source: 'manual',
          );
      await CardioActivityStore(widget.database).save(
        activity.copyWith(
          name: _name.text.trim(), sport: _sport, environment: _environment,
          // A legacy completion timestamp remains a recording timestamp.
          recordedAt: previous?.startedAt == null && previous != null
              ? _date
              : activity.recordedAt,
          startedAt: drift.Value(
            previous != null && previous.startedAt == null ? null : _date,
          ),
          startUtcOffsetMinutes: drift.Value(
            activity.startedAt == null
                ? null
                : _dateChanged
                    ? _date.timeZoneOffset.inMinutes
                    : activity.startUtcOffsetMinutes,
          ),
          endedAt: drift.Value(
            previous?.endedAt == null
                ? null
                : previous!.endedAt!.add(_date.difference(previous.startedAt!)),
          ),
          distanceMeters: drift.Value(
            previous != null &&
                    _distance.text ==
                        _number(
                          previous.distanceMeters,
                          cardioUnitMeters(widget.unit),
                        )
                ? previous.distanceMeters
                : distance == null
                    ? null
                    : distance * cardioUnitMeters(widget.unit),
          ),
          durationSeconds: drift.Value(
            previous != null &&
                    _duration.text == _number(previous.durationSeconds, 60)
                ? previous.durationSeconds
                : duration == null
                    ? null
                    : duration * 60,
          ),
          durationBasis: _basis,
          notes: drift.Value(
            _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          ),
        ),
      );
      if (!mounted) return;
      if (previous == null) {
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => ActivityDetailPage(
              database: widget.database,
              id: activity.id,
              unit: widget.unit,
            ),
          ),
        );
      } else {
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted)
        setState(() {
          _error = 'Unable to save. Check the measurements and activity dates.';
          _saving = false;
        });
    }
  }

  Widget _choice(
    String label,
    String value,
    List<String> choices,
    ValueChanged<String> changed,
  ) =>
      DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        items: {...choices, value}
            .map(
              (v) => DropdownMenuItem(value: v, child: Text(activityLabel(v))),
            )
            .toList(),
        onChanged: _saving ? null : (v) => setState(() => changed(v!)),
      );

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_date),
    );
    if (time != null && mounted) {
      _dateChanged = true;
      setState(
        () => _date =
            DateTime(date.year, date.month, date.day, time.hour, time.minute),
      );
    }
  }

  InputDecoration _input(String label, {String? suffix}) => InputDecoration(
        labelText: label,
        suffixText: suffix,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.activity == null ? 'Log cardio' : 'Edit cardio'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save'),
          ),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            activityBottomClearance(context),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Text(
                'Every session counts.',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            ActivitySection(
              title: 'Activity',
              child: Column(
                children: [
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    decoration: _input('Name'),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Enter a name' : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _choice(
                          'Sport',
                          _sport,
                          ['run', 'walk', 'cycle', 'other'],
                          (v) => _sport = v,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _choice(
                          'Environment',
                          _environment,
                          ['outdoor', 'indoor', 'unspecified'],
                          (v) => _environment = v,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ActivitySection(
              title: 'Distance & time',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    key: const ValueKey('activity-distance'),
                    controller: _distance,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.next,
                    decoration: _input(
                      'Distance (${cardioDisplayUnit(widget.unit)})',
                    ),
                    validator: _measurement,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('activity-duration'),
                    controller: _duration,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.next,
                    decoration: _input('Duration (minutes)'),
                    validator: _measurement,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Leave a measurement blank if unknown. For 5 min 30 sec, enter 5.5 minutes.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),
                  _choice(
                    'Time includes',
                    _basis,
                    ['elapsed', 'timer', 'moving', 'unspecified'],
                    (v) => _basis = v,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    switch (_basis) {
                      'elapsed' => 'The full session, including pauses.',
                      'timer' =>
                        'Only time while the activity timer was running.',
                      'moving' => 'Only time spent moving.',
                      _ =>
                        'Pace stays unavailable until the time basis is known.',
                    },
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                  if (widget.activity?.legacyGymSetId != null)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Text(
                        'Blank legacy measurements keep the original value.',
                      ),
                    ),
                ],
              ),
            ),
            ActivitySection(
              title: 'When',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.calendar_today_outlined,
                  color: colors.primary,
                ),
                title: Text(
                  DateFormat.yMMMd().add_jm().format(_date.toLocal()),
                ),
                subtitle: Text(
                  widget.activity != null && widget.activity!.startedAt == null
                      ? 'Recording date'
                      : 'Start date',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _saving ? null : _pickDate,
              ),
            ),
            ActivitySection(
              title: 'Notes',
              child: TextFormField(
                controller: _notes,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'How did it feel? (optional)',
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(_error!, style: TextStyle(color: colors.error)),
              ),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
              icon: Icon(_saving ? Icons.hourglass_top : Icons.check),
              label: Text(_saving ? 'Saving…' : 'Save activity'),
            ),
          ],
        ),
      ),
    );
  }
}
