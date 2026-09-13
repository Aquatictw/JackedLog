import 'package:flutter/material.dart';

// Activity routes are presented above the home navigation.
double activityBottomClearance(BuildContext context) =>
    MediaQuery.paddingOf(context).bottom + 24;

String activityLabel(String value) =>
    const {
      'run': 'Run',
      'walk': 'Walk',
      'cycle': 'Ride',
      'other': 'Other / unclassified',
      'outdoor': 'Outdoors',
      'indoor': 'Indoors',
      'unspecified': 'Not specified',
      'elapsed': 'Total time',
      'timer': 'Timer time',
      'moving': 'Moving time',
      'manual': 'Manually logged',
      'legacy': 'Workout log',
    }[value] ??
    value;

class ActivitySection extends StatelessWidget {
  const ActivitySection({required this.title, required this.child, super.key});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 10),
              child: Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Theme.of(context)
                      .colorScheme
                      .outlineVariant
                      .withValues(alpha: .45),
                ),
              ),
              child: child,
            ),
          ],
        ),
      );
}
