import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/assignment.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/assignment_viewmodel.dart';
import '../admin_web_shell.dart';
import '../web_widgets.dart';
import 'web_assignment_form.dart';
import 'web_schedules_page.dart' show caregiverColor, shiftLabel;

/// Every caregiver ↔ client assignment in one table.
class WebAssignmentsPage extends StatefulWidget {
  const WebAssignmentsPage({super.key});

  @override
  State<WebAssignmentsPage> createState() => _WebAssignmentsPageState();
}

class _WebAssignmentsPageState extends State<WebAssignmentsPage> {
  final _vm = AssignmentViewModel();
  String _query = '';
  int _filter = 0; // 0 current, 1 ended, 2 all

  @override
  void initState() {
    super.initState();
    _vm.addListener(_rebuild);
    _loadAll();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _vm.removeListener(_rebuild);
    _vm.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await _vm.loadAssignments();
    while (mounted && _vm.hasMore) {
      final before = _vm.assignments.length;
      await _vm.loadMore();
      if (_vm.assignments.length == before) break;
    }
  }

  bool _ended(Assignment a) {
    if (a.endDate == null) return false;
    final today = DateUtils.dateOnly(DateTime.now());
    return DateUtils.dateOnly(a.endDate!).isBefore(today);
  }

  List<Assignment> get _visible {
    final q = _query.trim().toLowerCase();
    final list = _vm.assignments.where((a) {
      if (_filter == 0 && _ended(a)) return false;
      if (_filter == 1 && !_ended(a)) return false;
      if (q.isEmpty) return true;
      return a.clientName.toLowerCase().contains(q) ||
          a.caregiverName.toLowerCase().contains(q);
    }).toList()
      ..sort((a, b) {
        final c = a.clientName.toLowerCase().compareTo(b.clientName.toLowerCase());
        return c != 0
            ? c
            : a.caregiverName.toLowerCase().compareTo(b.caregiverName.toLowerCase());
      });
    return list;
  }

  Future<void> _create() async {
    if (await showWebAssignmentForm(context)) await _loadAll();
  }

  Future<void> _edit(Assignment a) async {
    if (await showWebAssignmentForm(context, assignment: a)) await _loadAll();
  }

  Future<void> _delete(Assignment a) async {
    final ok = await webConfirm(
      context,
      title: 'Remove ${a.caregiverName} from ${a.clientName}?',
      message:
          'This deletes the whole recurring assignment.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!ok) return;
    final success = await _vm.deleteAssignment(a.id);
    if (mounted) {
      webToast(context, success ? 'Assignment removed' : 'Could not remove assignment',
          error: !success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = _vm.assignments;
    final ended = all.where(_ended).length;
    final rows = _visible;
    return WebPageScaffold(
      onRefresh: _loadAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WebPageHeader(
            title: 'Assignments',
            subtitle: '${all.length - ended} current · $ended ended',
            actions: [
              if (enabledWebSections.contains(WebSection.schedules))
                OutlinedButton.icon(
                  onPressed: () =>
                      WebNavigator.of(context, WebSection.schedules),
                  icon: const Icon(Icons.calendar_month_outlined, size: 18),
                  label: const Text('Open calendar'),
                ),
              FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('New assignment'),
              ),
            ],
          ),
          WebToolbar(

            leading: [

              WebFilterTabs(
                labels: [
                  'Current (${all.length - ended})',
                  'Ended ($ended)',
                  'All (${all.length})',
                ],
                selected: _filter,
                onChanged: (i) => setState(() => _filter = i),
              ),

            ],

            trailing: WebSearchField(
                hint: 'Search client or caregiver…',
                onChanged: (v) => setState(() => _query = v),
              ),

          ),
          const SizedBox(height: 16),
          if (_vm.isLoading && all.isEmpty)
            const WebCard(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            WebTable(
              headers: const ['Client', 'Caregiver', 'Days', 'Shift', 'Dates', ''],
              flex: const [3, 3, 3, 2, 3, 1],
              onRowTap: (i) => _edit(rows[i]),
              empty: const WebEmptyState(
                icon: Icons.assignment_outlined,
                message: 'No assignments here',
              ),
              rows: [
                for (final a in rows)
                  [
                    Row(
                      children: [
                        WebAvatar(
                            name: a.clientName,
                            photoUrl: a.clientPhotoUrl,
                            size: 30),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(a.clientName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: caregiverColor(a.caregiverId),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(a.caregiverName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14)),
                        ),
                      ],
                    ),
                    Text(a.schedule.split('|').first.trim(),
                        style: const TextStyle(fontSize: 13)),
                    Text(shiftLabel(a), style: const TextStyle(fontSize: 13)),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            a.startDate == null
                                ? '—'
                                : '${DateFormat('MMM d, yyyy').format(a.startDate!)} – ${a.endDate == null ? '…' : DateFormat('MMM d, yyyy').format(a.endDate!)}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        if (_ended(a)) ...[
                          const SizedBox(width: 8),
                          const WebStatusBadge(
                              label: 'Ended', color: AppTheme.textSecondary),
                        ],
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: PopupMenuButton<String>(
                        icon: const Icon(Icons.more_horiz,
                            color: AppTheme.textSecondary),
                        onSelected: (v) => v == 'edit' ? _edit(a) : _delete(a),
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit schedule')),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('Remove assignment',
                                style: TextStyle(color: AppTheme.errorColor)),
                          ),
                        ],
                      ),
                    ),
                  ],
              ],
            ),
        ],
      ),
    );
  }
}
