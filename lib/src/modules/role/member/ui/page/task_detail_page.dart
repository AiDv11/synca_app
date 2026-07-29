import 'package:flutter/material.dart';

import 'package:synca_app/src/core/services/task_service.dart';
import 'package:synca_app/src/core/theme/app_colors.dart';
import 'package:synca_app/src/core/utils/deadline_format.dart';
import 'package:synca_app/src/modules/role/member/model/proof_link.dart';
import 'package:synca_app/src/modules/role/member/ui/widget/status_chip.dart';
import 'package:synca_app/src/modules/role/member/ui/widget/task_actions.dart';
import 'package:synca_app/src/modules/role/member/view_model/my_tasks_view_model.dart';

/// Everything about one task, and the actions that change it.
///
/// A pushed route rather than a sheet: there is a full screen of content here,
/// and a description can run long. It also gives the member somewhere to *be* —
/// a back button and a title — instead of a panel that has to be dismissed
/// before they can read the rest of the list.
///
/// ## Why it takes an id and a ViewModel, not a Task
///
/// A [Task] handed in at push time is a photograph: it stops being true the
/// moment the task changes, and this page can sit open for minutes while the
/// member edits proof, changes status, or a leader reassigns the work from
/// another device. The page would keep showing the old values, and — worse —
/// the actions would act on a stale object.
///
/// So it holds the id and reads the task out of [MyTasksViewModel] on every
/// build. That ViewModel is already listening to `streamTasksForUser` for the
/// Tasks list, so this page is live for free: no second Firestore listener, no
/// second query billed, and the list and this page can never disagree because
/// they are rendering the same snapshot.
///
/// The ViewModel is owned by `MyTasksPage`, which stays mounted underneath this
/// route, so it outlives this page and must not be disposed here.
class TaskDetailPage extends StatelessWidget {
  const TaskDetailPage({
    super.key,
    required this.viewModel,
    required this.taskId,
  });

  final MyTasksViewModel viewModel;

  /// The task to show. Looked up on every build — see the class note.
  final String taskId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.light,
      appBar: AppBar(
        title: const Text('Task'),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        // Flutter 3 tints the app bar when content scrolls under it, which
        // muddies the navy. Zero keeps it flat and on-brand, as on the shell.
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: viewModel,
          builder: (context, _) {
            final task = viewModel.taskById(taskId);

            // Null means the task stopped being this member's while the page
            // was open — they released it, a leader reassigned it, or they left
            // the group. Not an error, and not something to crash on.
            if (task == null) return const _TaskGoneState();

            return _buildBody(context, task);
          },
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, Task task) {
    final isOverdue = DeadlineFormat.isOverdue(
      task.deadline,
      isDone: task.status.isDone,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                task.title,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  StatusChip(status: task.status),
                  if (isOverdue) ...[
                    const SizedBox(width: 8),
                    const _OverdueLabel(),
                  ],
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    isOverdue ? Icons.error_outline : Icons.schedule_outlined,
                    size: 16,
                    color: isOverdue ? AppColors.danger : AppColors.charcoal,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      // The same wording as the task card, from the same
                      // helper, so the two can never describe one deadline
                      // differently.
                      DeadlineFormat.relative(
                        task.deadline,
                        isDone: task.status.isDone,
                      ),
                      style: TextStyle(
                        fontSize: 13,
                        color: isOverdue
                            ? AppColors.danger
                            : AppColors.charcoal,
                        fontWeight: isOverdue
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  Text(
                    // The exact date alongside the countdown. On a list a
                    // countdown is enough; on the page you came to in order to
                    // plan, the date itself is worth having.
                    DeadlineFormat.dayAndMonth(task.deadline),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.charcoal,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionLabel('Description'),
              const SizedBox(height: 8),
              Text(
                task.description.trim().isEmpty
                    // Said plainly rather than left blank: an empty panel reads
                    // as something failing to load.
                    ? 'No description was added to this task.'
                    : task.description,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: task.description.trim().isEmpty
                      ? AppColors.charcoal.withValues(alpha: 0.6)
                      : AppColors.charcoal,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // `hasProof`, never a null check — removed proof is stored as an empty
        // string, and a null check would draw an empty link here.
        if (ProofLink.hasProof(task.proofUrl)) ...[
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionLabel('Proof of work'),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => openProofLink(context, task),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.attach_file,
                          size: 16,
                          color: AppColors.teal,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            ProofLink.displayLabel(task.proofUrl!),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.teal,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.open_in_new,
                          size: 14,
                          color: AppColors.teal,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        const SizedBox(height: 4),
        ..._buildActions(context, task),
      ],
    );
  }

  /// The three things a member can do from here.
  ///
  /// Every one of them hands off to `task_actions.dart`, which the Tasks list
  /// calls too. Nothing about opening a sheet, confirming, writing or reporting
  /// lives on this page.
  List<Widget> _buildActions(BuildContext context, Task task) {
    return [
      FilledButton.icon(
        onPressed: () =>
            openTaskSheet(context: context, viewModel: viewModel, task: task),
        icon: const Icon(Icons.checklist),
        label: const Text('Update status'),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.teal,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      // Only when there is a link to correct. Adding proof stays tied to
      // submitting work, through Ready for review or Completed — the same rule
      // the sheet itself follows.
      if (ProofLink.hasProof(task.proofUrl)) ...[
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => openTaskSheet(
            context: context,
            viewModel: viewModel,
            task: task,
            startOnProofEdit: true,
          ),
          icon: const Icon(Icons.link),
          label: const Text('Edit proof'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.teal,
            side: const BorderSide(color: AppColors.teal),
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],

      // Hidden once the work is done, matching the sheet: releasing resets the
      // status, so offering it here would be offering to erase a completion.
      if (!task.status.isDone) ...[
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => _release(context, task),
          icon: const Icon(Icons.undo),
          label: const Text('Release back to the group'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.danger,
            side: BorderSide(color: AppColors.danger.withValues(alpha: 0.4)),
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],

      const SizedBox(height: 24),
    ];
  }

  /// Releases, and leaves the page if it worked.
  ///
  /// Popping is the point: a released task is no longer the member's, so this
  /// page has nothing left to show. Without it they would be looking at
  /// [_TaskGoneState] wondering what went wrong, having just been told the
  /// release succeeded.
  Future<void> _release(BuildContext context, Task task) async {
    final released = await confirmAndRelease(
      context: context,
      viewModel: viewModel,
      task: task,
    );

    if (!context.mounted || !released) return;
    Navigator.of(context).pop();
  }
}

/// Shown when the task stops being the member's while the page is open.
class _TaskGoneState extends StatelessWidget {
  const _TaskGoneState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 48,
              color: AppColors.charcoal.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            const Text(
              'This task is no longer yours',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.navy,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'It was released or reassigned. Check the group list to see '
              'whether you can claim it again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.charcoal,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            // A way out that does not rely on spotting the back arrow, since
            // this state appears without the member asking for it.
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Back to my tasks'),
            ),
          ],
        ),
      ),
    );
  }
}

/// The white panel every section on this page sits in, matching the cards on
/// the Tasks and Profile tabs.
class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
  }
}

/// The small grey heading above a section's content.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 11, color: AppColors.charcoal),
    );
  }
}

/// The same red "Overdue" badge the task card shows.
///
/// Duplicated deliberately: the one on `TaskCard` is private to that file, and
/// making it public to share nine lines of padding would put a widget in the
/// module's API for the sake of it. If a third screen needs it, that is the
/// point to lift it into its own file.
class _OverdueLabel extends StatelessWidget {
  const _OverdueLabel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.danger,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'Overdue',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
