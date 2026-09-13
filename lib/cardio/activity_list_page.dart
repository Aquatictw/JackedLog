import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../database/database.dart';
import 'activity_detail_page.dart';
import 'activity_presentation.dart';
import 'activity_widgets.dart';

/// A bounded drill-down for a workout or a chart's aggregate day.
class ActivityListPage extends StatefulWidget {
  const ActivityListPage({
    required this.database,
    required this.unit,
    this.workoutId,
    this.name,
    this.day,
    super.key,
  });
  final AppDatabase database;
  final String unit;
  final int? workoutId;
  final String? name;
  final DateTime? day;

  @override
  State<ActivityListPage> createState() => _ActivityListPageState();
}

class _ActivityListPageState extends State<ActivityListPage> {
  int _offset = 0;
  late Stream<List<CardioActivity>> _stream = _query();

  Stream<List<CardioActivity>> _query() {
    final query = widget.database.select(widget.database.cardioActivities)
      ..orderBy([
        (a) => drift.OrderingTerm.desc(a.recordedAt),
        (a) => drift.OrderingTerm.desc(a.id),
      ])
      ..limit(51, offset: _offset);
    if (widget.workoutId != null)
      query.where((a) => a.workoutId.equals(widget.workoutId!));
    if (widget.name != null) query.where((a) => a.name.equals(widget.name!));
    if (widget.day != null) {
      final day = widget.day!.toLocal();
      final start = DateTime(day.year, day.month, day.day);
      final end = DateTime(day.year, day.month, day.day + 1);
      query.where(
        (a) =>
            a.recordedAt.isBiggerOrEqualValue(start) &
            a.recordedAt.isSmallerThanValue(end),
      );
    }
    return query.watch();
  }

  void _page(int offset) => setState(() {
        _offset = offset;
        _stream = _query();
      });

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Recorded cardio')),
        body: StreamBuilder<List<CardioActivity>>(
          stream: _stream,
          builder: (context, snapshot) {
            if (snapshot.hasError)
              return const Center(child: Text('Unable to load activities'));
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            final activities = snapshot.data!;
            return ListView(
              padding:
                  EdgeInsets.only(bottom: activityBottomClearance(context)),
              children: [
                if (activities.isEmpty)
                  const ListTile(title: Text('No recorded cardio activities')),
                for (final activity in activities.take(50))
                  ListTile(
                    key: ValueKey(activity.id),
                    title: Text(activity.name),
                    subtitle: Text(
                      '${activitySummary(activity, widget.unit)}\n${DateFormat.yMMMd().format(activity.recordedAt.toLocal())} · ${activity.source}',
                    ),
                    isThreeLine: true,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => ActivityDetailPage(
                          database: widget.database,
                          id: activity.id,
                          unit: widget.unit,
                        ),
                      ),
                    ),
                  ),
                if (_offset > 0)
                  TextButton(
                    onPressed: () => _page(_offset - 50),
                    child: const Text('Previous page'),
                  ),
                if (activities.length > 50)
                  TextButton(
                    onPressed: () => _page(_offset + 50),
                    child: const Text('Next page'),
                  ),
              ],
            );
          },
        ),
      );
}
