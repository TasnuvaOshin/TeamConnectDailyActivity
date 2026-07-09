import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/static_data.dart';
import '../models/profile.dart';
import '../models/task.dart';
import '../providers/auth_provider.dart';
import '../providers/data_providers.dart';
import '../theme.dart';

/// "Assign a task" dialog (§2.B Quick Assign):
/// Assign to (downline select) · Title · Description · Priority + Deadline.
/// Submit disabled until title + assignee are set.
Future<void> showQuickAssignDialog(
  BuildContext context,
  WidgetRef ref, {
  Profile? presetAssignee,
}) async {
  final assignable = presetAssignee != null
      ? <Profile>[presetAssignee]
      : await ref.read(assignableProvider.future);
  if (!context.mounted) return;
  if (assignable.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No one in your downline to assign to.')),
    );
    return;
  }

  final title = TextEditingController();
  final description = TextEditingController();
  String? assignee = presetAssignee?.id;
  String priority = 'medium';
  DateTime? deadline;
  bool saving = false;

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSt) {
        final canSubmit =
            assignee != null && title.text.trim().isNotEmpty && !saving;
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460, maxHeight: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.forestDeep, AppColors.forest],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Assign a task',
                          style: display(size: 18, color: Colors.white, weight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _FieldLabel('Assign to'),
                        DropdownButtonFormField<String>(
                          value: assignee,
                          isExpanded: true,
                          hint: const Text('Pick a team member'),
                          items: [
                            for (final p in assignable)
                              DropdownMenuItem(
                                value: p.id,
                                child: Text(
                                  'L${p.roleLevel} · ${p.fullName} — ${p.designation}',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                          ],
                          onChanged: presetAssignee != null
                              ? null
                              : (v) => setSt(() => assignee = v),
                        ),
                        const SizedBox(height: 12),
                        const _FieldLabel('Title'),
                        TextField(
                          controller: title,
                          onChanged: (_) => setSt(() {}),
                          decoration:
                              const InputDecoration(hintText: 'What needs doing?'),
                        ),
                        const SizedBox(height: 12),
                        const _FieldLabel('Description'),
                        TextField(
                          controller: description,
                          maxLines: 3,
                          decoration:
                              const InputDecoration(hintText: 'Optional details…'),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const _FieldLabel('Priority'),
                                  DropdownButtonFormField<String>(
                                    value: priority,
                                    items: const [
                                      DropdownMenuItem(
                                          value: 'low', child: Text('Low')),
                                      DropdownMenuItem(
                                          value: 'medium', child: Text('Medium')),
                                      DropdownMenuItem(
                                          value: 'high', child: Text('High')),
                                      DropdownMenuItem(
                                          value: 'urgent', child: Text('Urgent')),
                                    ],
                                    onChanged: (v) =>
                                        setSt(() => priority = v ?? 'medium'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const _FieldLabel('Deadline'),
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      final picked = await showDatePicker(
                                        context: ctx,
                                        firstDate: DateTime.now(),
                                        lastDate: DateTime.now()
                                            .add(const Duration(days: 365)),
                                        initialDate:
                                            deadline ?? DateTime.now(),
                                      );
                                      if (picked != null) {
                                        setSt(() => deadline = picked);
                                      }
                                    },
                                    icon: const Icon(Icons.event, size: 16),
                                    label: Text(
                                      deadline == null
                                          ? 'Pick date'
                                          : DateFormat('d MMM').format(deadline!),
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Footer
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel', style: TextStyle(color: AppColors.destructive)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: !canSubmit
                            ? null
                            : () async {
                                setSt(() => saving = true);
                                // STATIC: the third-party API cannot assign
                                // tasks to other users — this only updates the
                                // in-memory demo list for this session.
                                final level = ref.read(myLevelProvider);
                                final twin = staticProfileForLevel(level);
                                ref
                                    .read(delegatedTasksProvider.notifier)
                                    .add(TaskItem(
                                      id: 'local-${DateTime.now().millisecondsSinceEpoch}',
                                      title: title.text.trim(),
                                      description:
                                          description.text.trim().isEmpty
                                              ? null
                                              : description.text.trim(),
                                      status: 'todo',
                                      priority: priority,
                                      assignerId: twin.id,
                                      assigneeId: assignee!,
                                      dueDate: deadline,
                                      createdAt: DateTime.now(),
                                    ));
                                ref.invalidate(myDelegatedTasksProvider);
                                ref.invalidate(downlineOpenTasksProvider);
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Task assigned ✅ (demo — not synced)')),
                                  );
                                }
                              },
                        child: saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Assign task'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.mute,
          ),
        ),
      );
}
