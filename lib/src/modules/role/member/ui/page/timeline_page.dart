import 'package:flutter/material.dart';

import 'package:synca_app/src/core/theme/app_colors.dart';
import 'package:synca_app/src/core/utils/relative_time.dart';
import 'package:synca_app/src/modules/common/auth/model/entity/app_user.dart';
import 'package:synca_app/src/modules/role/member/ui/widget/empty_state.dart';
import 'package:synca_app/src/modules/role/member/ui/widget/error_state.dart';
import 'package:synca_app/src/modules/role/member/view_model/timeline_entry.dart';
import 'package:synca_app/src/modules/role/member/view_model/timeline_view_model.dart';

/// The Timeline tab: what this member has done, newest first.
///
/// Reached two ways — the bottom nav, and the "View Timeline" link on the
/// contribution card. Both land here; neither needs to know the other exists,
/// because `MemberDashboard` owns the tab index and both routes go through it.
///
/// Like the Tasks page, this is a thin View: it renders whatever
/// [TimelineViewModel] reports and forwards nothing but a Retry.
class TimelinePage extends StatefulWidget {
  const TimelinePage({super.key, required this.user});

  final AppUser user;

  @override
  State<TimelinePage> createState() => _TimelinePageState();
}

class _TimelinePageState extends State<TimelinePage> {
  late final TimelineViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = TimelineViewModel(user: widget.user);
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) => _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.teal),
      );
    }

    if (_viewModel.errorMessage != null) {
      return ErrorState(
        title: 'Could not load your timeline',
        message: _viewModel.errorMessage!,
        onRetry: _viewModel.retry,
      );
    }

    if (_viewModel.isEmpty) {
      return const EmptyState(
        icon: Icons.timeline_outlined,
        title: 'No activity yet',
        message:
            'Claim a task and start working on it.\n'
            'Everything you do will show up here.',
      );
    }

    final entries = _viewModel.entries;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        return _TimelineTile(
          entry: entries[index],
          // The rail's connecting line is drawn by every tile except the last,
          // so the track stops at the final dot instead of trailing into space.
          isLast: index == entries.length - 1,
        );
      },
    );
  }
}

/// One row: the rail on the left, the event on the right.
class _TimelineTile extends StatelessWidget {
  const _TimelineTile({required this.entry, required this.isLast});

  final TimelineEntry entry;
  final bool isLast;

  /// Icon and colour per event type.
  ///
  /// Completion is teal — the accent colour used for success everywhere else in
  /// the app. Creation is the quietest, because it is the least interesting
  /// thing on the list.
  (IconData, Color) get _appearance => switch (entry.type) {
    TimelineEventType.taskCreated => (
      Icons.add_circle_outline,
      AppColors.charcoal,
    ),
    TimelineEventType.taskClaimed => (
      Icons.pan_tool_alt_outlined,
      AppColors.skyBlue,
    ),
    TimelineEventType.workStarted => (Icons.play_arrow, AppColors.skyBlue),
    TimelineEventType.readyForReview => (Icons.rate_review, AppColors.navy),
    TimelineEventType.proofUploaded => (Icons.attach_file, AppColors.navy),
    TimelineEventType.taskCompleted => (Icons.check_circle, AppColors.teal),
  };

  @override
  Widget build(BuildContext context) {
    // Destructuring a record into two variables in one line. The `_appearance`
    // getter returns `(IconData, Color)` — a record, Dart's lightweight way to
    // return two values without declaring a class for them.
    final (icon, colour) = _appearance;

    return IntrinsicHeight(
      // IntrinsicHeight lets the vertical rail stretch to match the card beside
      // it. Without it the Expanded line inside an unbounded Row has no height
      // to fill, and the track breaks between rows.
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---- the rail ----
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: colour.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 17, color: colour),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: AppColors.charcoal.withValues(alpha: 0.12),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),

          // ---- the event ----
          Expanded(
            child: Padding(
              // Bottom padding is the gap between rows; the rail's line runs
              // through it, which is what makes the track continuous.
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // What happened.
                    Text(
                      entry.type.label,
                      style: TextStyle(
                        color: colour,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),

                    // Which task.
                    Text(
                      entry.taskTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.navy,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // When.
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 12,
                          color: AppColors.charcoal.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          RelativeTime.past(entry.timestamp),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.charcoal.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          RelativeTime.clock(entry.timestamp),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.charcoal.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
