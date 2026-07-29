import 'package:flutter/material.dart';

import 'package:synca_app/src/core/theme/app_colors.dart';
import 'package:synca_app/src/modules/role/member/ui/widget/status_chip.dart';
import 'package:synca_app/src/modules/role/member/view_model/task_filter.dart';

/// The row of filter chips above the claimed task list.
///
/// Shaped like [StatusChip] on purpose — same pill, same radius, same weight,
/// and each one tinted with that status's own colour from
/// [StatusChip.colourFor]. A member should be able to see that the blue chip up
/// here selects the blue chips down there, without being told.
///
/// The difference between the two is what selection does. A status chip always
/// draws its colour at 12% and never changes; a filter chip is either off — the
/// same quiet 12% tint — or on, filled solid with white text. That is a big
/// enough jump to read at a glance on a phone, and it means the selected chip
/// never relies on colour alone: it is the filled one.
class TaskFilterChips extends StatelessWidget {
  const TaskFilterChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final TaskFilter selected;
  final ValueChanged<TaskFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        // Horizontal, because five chips do not fit across a narrow phone and
        // wrapping them onto a second line would push the list itself down.
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: TaskFilter.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = TaskFilter.values[index];

          return _FilterChip(
            filter: filter,
            isSelected: filter == selected,
            // Tapping the chip already selected is not ignored — the ViewModel
            // skips the notify when nothing changed, so a guard here would be a
            // rule with no purpose.
            onTap: () => onSelected(filter),
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.filter,
    required this.isSelected,
    required this.onTap,
  });

  final TaskFilter filter;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // "All" has no status of its own, so it borrows navy — the app's primary,
    // and the right weight for the option that means "no filter at all".
    final status = filter.status;
    final colour = status == null
        ? AppColors.navy
        : StatusChip.colourFor(status);

    // Material rather than a plain Container: an ink splash is painted onto the
    // nearest Material *behind* a widget, so a coloured Container over an
    // InkWell would hide its own ripple.
    return Material(
      color: isSelected ? colour : colour.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Center(
            child: Text(
              filter.label,
              style: TextStyle(
                color: isSelected ? Colors.white : colour,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
