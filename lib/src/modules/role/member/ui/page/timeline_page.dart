import 'package:flutter/material.dart';

import 'package:synca_app/src/core/theme/app_colors.dart';
import 'package:synca_app/src/core/utils/relative_time.dart';
import 'package:synca_app/src/modules/common/auth/model/entity/app_user.dart';
import 'package:synca_app/src/modules/role/member/ui/page/task_detail_page.dart';
import 'package:synca_app/src/modules/role/member/ui/widget/empty_state.dart';
import 'package:synca_app/src/modules/role/member/ui/widget/error_state.dart';
import 'package:synca_app/src/modules/role/member/view_model/my_tasks_view_model.dart';
import 'package:synca_app/src/modules/role/member/view_model/timeline_entry.dart';
import 'package:synca_app/src/modules/role/member/view_model/timeline_section.dart';
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

    // Flattened to one list of rows — headers and entries together — rather
    // than a Column of Columns, so ListView.builder still only builds what is
    // on screen. The headers scroll with the content; they are not pinned.
    final rows = _buildRows(TimelineSection.group(_viewModel.entries));

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: rows.length,
      itemBuilder: (context, index) => switch (rows[index]) {
        _HeaderRow(:final label) => _DateHeader(label: label),
        _EntryRow(:final entry, :final isLastInSection) => _TimelineTile(
          entry: entry,
          isLastInSection: isLastInSection,
          // Null makes the tile inert — no ripple, no tap. See
          // TimelineViewModel.ownsTask for when that happens.
          onTap: _viewModel.ownsTask(entry.taskId)
              ? () => _openTask(entry.taskId)
              : null,
        ),
      },
    );
  }

  List<_TimelineRow> _buildRows(List<TimelineSection> sections) {
    final rows = <_TimelineRow>[];

    for (final section in sections) {
      rows.add(_HeaderRow(section.header));

      for (var i = 0; i < section.entries.length; i++) {
        rows.add(
          _EntryRow(
            section.entries[i],
            // The rail's connecting line stops at the last dot of each day, so
            // a date header reads as a deliberate break in the track rather
            // than the line being cut off mid-run.
            isLastInSection: i == section.entries.length - 1,
          ),
        );
      }
    }

    return rows;
  }

  /// Opens the task behind an entry, on the same page the Tasks tab pushes.
  void _openTask(String taskId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _TimelineTaskDetailRoute(user: widget.user, taskId: taskId),
      ),
    );
  }
}

/// A row in the flattened list: either a date header or an entry.
///
/// `sealed`, so the `switch` that renders them is exhaustive — add a third kind
/// of row and the builder stops compiling until it is handled.
sealed class _TimelineRow {
  const _TimelineRow();
}

final class _HeaderRow extends _TimelineRow {
  const _HeaderRow(this.label);
  final String label;
}

final class _EntryRow extends _TimelineRow {
  const _EntryRow(this.entry, {required this.isLastInSection});
  final TimelineEntry entry;
  final bool isLastInSection;
}

/// Hosts [TaskDetailPage] with a ViewModel of its own.
///
/// [TaskDetailPage] needs a [MyTasksViewModel] — it reads the task live from
/// one, and its actions write through it — but the Timeline tab holds a
/// [TimelineViewModel] instead. This route creates one for its own lifetime and
/// disposes it on the way out.
///
/// The cost is a second ChangeNotifier on the same query while the page is
/// open. It is small: `streamTasksForUser` is the identical query the Tasks tab
/// already watches, and Firestore shares one underlying listener between
/// identical queries, so this adds no reads.
///
/// The tidier alternative is to hoist the single `MyTasksViewModel` up to
/// `MemberDashboard` and hand it to both tabs. That is the better shape, and it
/// was not done here to keep this change away from the Tasks tab, which is
/// verified and working.
class _TimelineTaskDetailRoute extends StatefulWidget {
  const _TimelineTaskDetailRoute({required this.user, required this.taskId});

  final AppUser user;
  final String taskId;

  @override
  State<_TimelineTaskDetailRoute> createState() =>
      _TimelineTaskDetailRouteState();
}

class _TimelineTaskDetailRouteState extends State<_TimelineTaskDetailRoute> {
  late final MyTasksViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = MyTasksViewModel(user: widget.user);
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TaskDetailPage(viewModel: _viewModel, taskId: widget.taskId);
  }
}

/// The small uppercase day label above each run of entries.
class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Left inset matches the rail's width plus its gap, so headers line up
      // with the cards rather than with the dots.
      padding: const EdgeInsets.fromLTRB(44, 12, 0, 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          // Tracking, because uppercase text set solid at 11px reads as a
          // smudge rather than a word.
          letterSpacing: 0.8,
          color: AppColors.charcoal.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}

/// One row: the rail on the left, the event on the right.
class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.entry,
    required this.isLastInSection,
    this.onTap,
  });

  final TimelineEntry entry;

  /// The last entry under its date header. Controls whether the rail's
  /// connecting line continues below this dot.
  final bool isLastInSection;

  /// Null when the task behind this entry is no longer the member's, which
  /// removes the ripple as well as the tap.
  final VoidCallback? onTap;

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
              if (!isLastInSection)
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
              padding: EdgeInsets.only(bottom: isLastInSection ? 0 : 16),
              // Material + InkWell rather than a coloured Container, because an
              // ink splash is painted onto the nearest Material *behind* the
              // widget — a white Container over an InkWell hides its own ripple.
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // What happened, and when — on one line, with the time
                        // pushed to the far edge. The event names the row; the
                        // time is a detail you look up only once the row has
                        // your attention, so it is smaller, greyer and out of
                        // the reading path.
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                entry.type.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colour,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              // Just the clock. The date header above already
                              // says which day this was, so "2 hours ago" beside
                              // a "Today" heading was saying it twice.
                              RelativeTime.clock(entry.timestamp),
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.charcoal.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),

                        // Which task — now the heaviest thing in the row. It is
                        // what someone scans for, and what the tap acts on.
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                entry.taskTitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.navy,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  height: 1.3,
                                ),
                              ),
                            ),
                            // Only where there is somewhere to go. Quiet enough
                            // not to compete with the title it sits beside.
                            if (onTap != null) ...[
                              const SizedBox(width: 8),
                              Icon(
                                Icons.chevron_right,
                                size: 18,
                                color: AppColors.charcoal.withValues(alpha: 0.3),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
