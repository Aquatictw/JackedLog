import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/database.dart';
import 'activity_list_page.dart';
import 'activity_presentation.dart';
import 'activity_widgets.dart';
import 'cardio_trends.dart';

enum _TrendMetric { distance, minutes, sessions, pace }

class CardioProgressPage extends StatefulWidget {
  const CardioProgressPage(
      {required this.database, required this.unit, this.name, super.key,});
  final AppDatabase database;
  final String unit;
  final String? name;

  @override
  State<CardioProgressPage> createState() => _CardioProgressPageState();
}

class _CardioProgressPageState extends State<CardioProgressPage> {
  String? _sport;
  String? _environment;
  String? _basis;
  int _weeks = 12;
  _TrendMetric _metric = _TrendMetric.distance;
  late Stream<List<CardioWeek>> _stream = _query();

  CardioTrendFilter get _filter => CardioTrendFilter(
        sport: _sport,
        environment: _environment,
        timeBasis: _basis,
        name: widget.name,
      );

  Stream<List<CardioWeek>> _query() => CardioTrends(widget.database)
      .weekly(
        through: DateTime.now(),
        weeks: _weeks,
        filter: _filter,
      )
      .watch();

  void _change(VoidCallback update) => setState(() {
        update();
        _stream = _query();
      });

  Widget _filterField(String label, String? value, List<String> values,
          ValueChanged<String?> change,) =>
      DropdownButtonFormField<String>(
        initialValue: value ?? 'all',
        isExpanded: true,
        decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),),),
        items: [
          const DropdownMenuItem(value: 'all', child: Text('All')),
          for (final v in values)
            DropdownMenuItem(value: v, child: Text(activityLabel(v))),
        ],
        onChanged: (v) => _change(() => change(v == 'all' ? null : v)),
      );

  double? _sum(Iterable<double?> values) {
    final known = values.nonNulls.toList();
    if (known.isEmpty) return null;
    final total = known.fold<double>(0, (a, b) => a + b);
    return total.isFinite ? total : null;
  }

  String _pace(double? secondsPerKm) {
    if (secondsPerKm == null || !secondsPerKm.isFinite || secondsPerKm <= 0)
      return '—';
    final seconds = secondsPerKm * cardioUnitMeters(widget.unit) / 1000;
    if (_sport == 'cycle')
      return '${(3600 / seconds).toStringAsFixed(1)} ${cardioDisplayUnit(widget.unit)}/h';
    final rounded = seconds.round();
    return '${rounded ~/ 60}:${(rounded % 60).toString().padLeft(2, '0')} min/${cardioDisplayUnit(widget.unit)}';
  }

  double? _value(CardioWeek week) => switch (_metric) {
        _TrendMetric.distance => week.distanceMeters == null
            ? null
            : week.distanceMeters! / cardioUnitMeters(widget.unit),
        _TrendMetric.minutes =>
          week.durationSeconds == null ? null : week.durationSeconds! / 60,
        _TrendMetric.sessions => week.sessions.toDouble(),
        _TrendMetric.pace => week.secondsPerKm,
      };

  String _formatted(CardioWeek week) {
    final value = _value(week);
    if (_metric == _TrendMetric.pace) return _pace(value);
    if (value == null) return 'Not recorded';
    return switch (_metric) {
      _TrendMetric.distance =>
        '${value.toStringAsFixed(1)} ${cardioDisplayUnit(widget.unit)}',
      _TrendMetric.minutes => '${value.toStringAsFixed(0)} min',
      _TrendMetric.sessions => '${week.sessions} sessions',
      _TrendMetric.pace => _pace(value),
    };
  }

  Widget _stat(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),),
        ],
      );

  Widget _results(List<CardioWeek> weeks) {
    final meters = _sum(weeks.map((w) => w.distanceMeters));
    final seconds = _sum(weeks.map((w) => w.durationSeconds));
    final pairedMeters = _sum(weeks.map((w) => w.pairedMeters));
    final pairedSeconds = _sum(weeks.map((w) => w.pairedSeconds));
    final weighted =
        pairedMeters != null && pairedMeters > 0 && pairedSeconds != null
            ? pairedSeconds / pairedMeters * 1000
            : null;
    final sessions = weeks.fold<int>(0, (total, w) => total + w.sessions);
    final recordingDates =
        weeks.fold<int>(0, (total, w) => total + w.recordingDateSessions);
    final maximum = weeks.map(_value).nonNulls.fold<double>(0, max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ActivitySection(
          title: 'Last $_weeks weeks · selected activities',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 28,
                runSpacing: 20,
                children: [
                  _stat(
                      'Distance',
                      meters == null
                          ? '—'
                          : '${(meters / cardioUnitMeters(widget.unit)).toStringAsFixed(1)} ${cardioDisplayUnit(widget.unit)}',),
                  _stat(
                      'Cardio time',
                      seconds == null
                          ? '—'
                          : '${(seconds / 60).toStringAsFixed(0)} min',),
                  _stat('Sessions', '$sessions'),
                  _stat('Active weeks', '${weeks.length} / $_weeks'),
                ],
              ),
              const Divider(height: 32),
              _stat(_sport == 'cycle' ? 'Average speed' : 'Weighted pace',
                  _pace(weighted),),
              const SizedBox(height: 8),
              Text(
                _filter.supportsPace
                    ? 'Uses total paired time and distance. Entries missing either measurement contribute to volume only.'
                    : 'Choose one sport, environment and known time basis to compare pace.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        if (recordingDates > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Text(
              '$recordingDates sessions use their recording date in UTC because the original start or time zone is unknown. Other sessions use their source-local start date.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        const Text(
            'Warm-up and recovery cardio are included. Strength rest is excluded.',),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final metric in _TrendMetric.values)
              ChoiceChip(
                label: Text(
                  switch (metric) {
                    _TrendMetric.distance => 'Distance',
                    _TrendMetric.minutes => 'Minutes',
                    _TrendMetric.sessions => 'Sessions',
                    _TrendMetric.pace => _sport == 'cycle' ? 'Speed' : 'Pace',
                  },
                ),
                selected: _metric == metric,
                onSelected: (_) => setState(() => _metric = metric),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Weeks with recorded sessions are shown below.'),
        const SizedBox(height: 12),
        if (weeks.isEmpty)
          const ActivitySection(
              title: 'Weekly trend',
              child: Text(
                  'No activities match these filters. Try All, or log a cardio activity.',),),
        for (final week in weeks.reversed)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                Row(children: [
                  Expanded(
                      child: Text(
                          'Week of ${DateFormat.MMMd().format(week.start)}',),),
                  Text(_formatted(week)),
                ],),
                const SizedBox(height: 8),
                if (_metric != _TrendMetric.pace)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: maximum > 0
                          ? ((_value(week) ?? 0) / maximum).clamp(0, 1)
                          : 0,
                      minHeight: 8,
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                  ),
              ],
            ),
          ),
        TextButton.icon(
          icon: const Icon(Icons.list_alt),
          label: const Text('View and classify activities'),
          onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                  builder: (_) => ActivityListPage(
                      database: widget.database,
                      unit: widget.unit,
                      name: widget.name,),),),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.name ?? 'Cardio progress')),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ActivitySection(
              title: 'Compare like sessions',
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: _filterField(
                              'Sport',
                              _sport,
                              ['run', 'walk', 'cycle', 'other'],
                              (v) => _sport = v,),),
                      const SizedBox(width: 12),
                      Expanded(
                          child: _filterField(
                              'Environment',
                              _environment,
                              ['outdoor', 'indoor', 'unspecified'],
                              (v) => _environment = v,),),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _filterField(
                      'Time basis',
                      _basis,
                      ['elapsed', 'timer', 'moving', 'unspecified'],
                      (v) => _basis = v,),
                  const SizedBox(height: 16),
                  Wrap(spacing: 8, children: [
                    for (final weeks in [12, 26, 52])
                      ChoiceChip(
                          label: Text('$weeks weeks'),
                          selected: _weeks == weeks,
                          onSelected: (_) => _change(() => _weeks = weeks),),
                  ],),
                ],
              ),
            ),
            StreamBuilder<List<CardioWeek>>(
              stream: _stream,
              builder: (context, snapshot) {
                if (snapshot.hasError)
                  return const Text(
                      'Unable to load cardio progress. Try changing the filters.',);
                if (!snapshot.hasData ||
                    snapshot.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());
                return _results(snapshot.data!);
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      );
}
