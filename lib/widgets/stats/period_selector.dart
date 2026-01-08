import 'package:flutter/material.dart';
import 'package:jackedlog/graph/overview_page.dart';

class PeriodSelector extends StatelessWidget {
  final OverviewPeriod selectedPeriod;
  final ValueChanged<OverviewPeriod> onPeriodChanged;

  const PeriodSelector({
    super.key,
    required this.selectedPeriod,
    required this.onPeriodChanged,
  });

  String _getPeriodLabel(OverviewPeriod p) {
    switch (p) {
      case OverviewPeriod.week:
        return '7D';
      case OverviewPeriod.month:
        return '1M';
      case OverviewPeriod.months3:
        return '3M';
      case OverviewPeriod.months6:
        return '6M';
      case OverviewPeriod.year:
        return '1Y';
      case OverviewPeriod.allTime:
        return 'All';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: OverviewPeriod.values.map((p) {
          final isSelected = selectedPeriod == p;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(_getPeriodLabel(p)),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  onPeriodChanged(p);
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}
