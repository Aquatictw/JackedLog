import 'package:flutter/material.dart';
import 'package:jackedlog/widgets/morphing_nav_icon.dart';

/// Unified segmented pill navigation bar with morphing icons
class SegmentedPillNav extends StatefulWidget {
  final List<String> tabs;
  final int currentIndex;
  final Function(int) onTap;
  final Function(BuildContext, String)? onLongPress;

  const SegmentedPillNav({
    super.key,
    required this.tabs,
    required this.currentIndex,
    required this.onTap,
    this.onLongPress,
  });

  @override
  State<SegmentedPillNav> createState() => _SegmentedPillNavState();
}

class _SegmentedPillNavState extends State<SegmentedPillNav>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<double> _slideAnimation;
  int _previousIndex = 0;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeInOutCubic,
      ),
    );
    _previousIndex = widget.currentIndex;
  }

  @override
  void didUpdateWidget(SegmentedPillNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _previousIndex = oldWidget.currentIndex;
      _slideController.reset();
      _slideController.forward();
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  String _getRiveAssetForTab(String tab) {
    switch (tab) {
      case 'HistoryPage':
        return 'assets/animations/nav_history.riv';
      case 'PlansPage':
        return 'assets/animations/nav_plans.riv';
      case 'GraphsPage':
        return 'assets/animations/nav_graphs.riv';
      case 'NotesPage':
        return 'assets/animations/nav_notes.riv';
      case 'SettingsPage':
        return 'assets/animations/nav_settings.riv';
      default:
        return '';
    }
  }

  IconData _getFallbackIconForTab(String tab) {
    switch (tab) {
      case 'HistoryPage':
        return Icons.history_rounded;
      case 'PlansPage':
        return Icons.calendar_today_rounded;
      case 'GraphsPage':
        return Icons.insights_rounded;
      case 'NotesPage':
        return Icons.note_rounded;
      case 'SettingsPage':
        return Icons.settings_rounded;
      default:
        return Icons.error_rounded;
    }
  }

  String _getLabelForTab(String tab) {
    switch (tab) {
      case 'HistoryPage':
        return 'History';
      case 'PlansPage':
        return 'Plans';
      case 'GraphsPage':
        return 'Graphs';
      case 'NotesPage':
        return 'Notes';
      case 'SettingsPage':
        return 'Settings';
      default:
        return 'Error';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = 20.0;
    final pillPadding = 8.0;
    final tabWidth = (screenWidth - (horizontalPadding * 2) - (pillPadding * 2)) /
        widget.tabs.length;

    return Container(
      color: Colors.transparent,
      child: Padding(
        padding: EdgeInsets.only(
          left: horizontalPadding,
          right: horizontalPadding,
          top: 8,
          bottom: 16,
        ),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: color.surfaceContainerLow,
            borderRadius: BorderRadius.circular(36),
            border: Border.all(
              color: color.outlineVariant.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          padding: EdgeInsets.all(pillPadding),
          child: Stack(
            children: [
              // Sliding background indicator
              AnimatedBuilder(
                animation: _slideAnimation,
                builder: (context, child) {
                  double startX = _previousIndex * tabWidth;
                  double endX = widget.currentIndex * tabWidth;
                  double currentX =
                      startX + (endX - startX) * _slideAnimation.value;

                  return Positioned(
                    left: currentX,
                    child: Container(
                      width: tabWidth,
                      height: 56,
                      decoration: BoxDecoration(
                        color: color.primary,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: color.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              // Tab items
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: widget.tabs.asMap().entries.map((entry) {
                  int index = entry.key;
                  String tab = entry.value;
                  bool isSelected = index == widget.currentIndex;

                  return Expanded(
                    child: GestureDetector(
                      key: Key(tab),
                      onTap: () => widget.onTap(index),
                      onLongPress: widget.onLongPress != null
                          ? () => widget.onLongPress!(context, tab)
                          : null,
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            MorphingNavIcon(
                              animationAsset: _getRiveAssetForTab(tab),
                              fallbackIcon: _getFallbackIconForTab(tab),
                              isSelected: isSelected,
                              color: isSelected
                                  ? color.onPrimary
                                  : color.onSurface,
                              size: 24,
                            ),
                            const SizedBox(height: 4),
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall!
                                  .copyWith(
                                    color: isSelected
                                        ? color.onPrimary
                                        : color.onSurface.withValues(alpha: 0.7),
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                              child: Text(
                                _getLabelForTab(tab),
                                maxLines: 1,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
