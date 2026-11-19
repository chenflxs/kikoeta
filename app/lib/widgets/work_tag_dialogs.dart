import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data.dart';
import '../l10n/strings.dart';
import '../services/api_service.dart';
import '../services/app_log.dart';
import '../smooth_scroll.dart';
import '../theme.dart';

class AddWorkTagsDialog extends StatefulWidget {
  final Future<List<AdvancedFilterEntry>> Function() loadTags;
  final Set<int> attachedIds;
  final Set<String> attachedNames;
  final Future<void> Function(List<int>) onSubmit;

  const AddWorkTagsDialog({
    super.key,
    required this.loadTags,
    required this.attachedIds,
    required this.attachedNames,
    required this.onSubmit,
  });

  @override
  State<AddWorkTagsDialog> createState() => _AddWorkTagsDialogState();
}

class _AddWorkTagsDialogState extends State<AddWorkTagsDialog> {
  late Future<List<AdvancedFilterEntry>> _catalog;
  final _selected = <int>{};
  var _query = '';
  var _saving = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _catalog = widget.loadTags();
  }

  Future<void> _submit() async {
    if (_saving || _selected.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSubmit(_selected.toList());
      if (mounted) Navigator.pop(context);
    } catch (error, stack) {
      AppLog.recordError('Add work tags failed', error, stack);
      if (mounted) {
        setState(() {
          _error = error;
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final palette = Theme.of(context).brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.light;
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        backgroundColor: palette.surface,
        title: Text(l10n.workTagAdd),
        content: SizedBox(
          width: 420,
          height: 320,
          child: Column(
            children: [
              TextField(
                enabled: !_saving,
                onChanged: (text) =>
                    setState(() => _query = text.trim().toLowerCase()),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  labelText: l10n.search,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: FutureBuilder(
                  future: _catalog,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(l10n.workTagRequestFailed),
                            TextButton(
                              onPressed: () =>
                                  setState(() => _catalog = widget.loadTags()),
                              child: Text(l10n.retry),
                            ),
                          ],
                        ),
                      );
                    }
                    final rows = <({int id, String label})>[];
                    for (final tag
                        in snapshot.data ?? const <AdvancedFilterEntry>[]) {
                      final id = int.tryParse(tag.id);
                      if (id == null ||
                          id <= 0 ||
                          widget.attachedIds.contains(id) ||
                          widget.attachedNames.contains(tag.name)) {
                        continue;
                      }
                      final label = tag.label(locale);
                      if (label.toLowerCase().contains(_query) ||
                          tag.name.toLowerCase().contains(_query)) {
                        rows.add((id: id, label: label));
                      }
                    }
                    if (rows.isEmpty) {
                      return Center(child: Text(l10n.workTagNoMatches));
                    }
                    return SmoothListView.builder(
                      itemCount: rows.length,
                      itemBuilder: (context, index) {
                        final row = rows[index];
                        return CheckboxListTile(
                          key: ValueKey(row.id),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: _selected.contains(row.id),
                          title: Text(row.label),
                          onChanged: _saving
                              ? null
                              : (checked) => setState(() {
                                  checked == true
                                      ? _selected.add(row.id)
                                      : _selected.remove(row.id);
                                }),
                        );
                      },
                    );
                  },
                ),
              ),
              if (_error is WorkTagEmailRequired)
                const _WorkTagEmailNotice()
              else if (_error != null)
                Text(
                  l10n.workTagRequestFailed,
                  style: TextStyle(color: palette.red),
                ),
              if (_saving) const LinearProgressIndicator(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: _saving || _selected.isEmpty ? null : _submit,
            child: Text(
              _selected.isEmpty
                  ? l10n.confirm
                  : '${l10n.confirm} (${_selected.length})',
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkTagEmailNotice extends StatefulWidget {
  const _WorkTagEmailNotice();

  @override
  State<_WorkTagEmailNotice> createState() => _WorkTagEmailNoticeState();
}

class _WorkTagEmailNoticeState extends State<_WorkTagEmailNotice> {
  var _openFailed = false;

  Future<void> _openSettings() async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.https('asmr.one', '/settings'),
        mode: LaunchMode.externalApplication,
      );
    } catch (error, stack) {
      AppLog.recordError('Open asmr.one account settings failed', error, stack);
    }
    if (mounted) setState(() => _openFailed = !opened);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = Theme.of(context).brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.light;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            l10n.workTagBindEmail,
            style: TextStyle(color: palette.red),
          ),
        ),
        TextButton.icon(
          onPressed: _openSettings,
          icon: const Icon(Icons.open_in_new, size: 16),
          label: Text(l10n.workTagOpenAccountSettings),
        ),
        if (_openFailed) Text(l10n.settingsPageOpenRepoToast),
      ],
    );
  }
}

class GrayTagActionsDialog extends StatefulWidget {
  final String label;
  final VoidCallback? onBlacklist;
  final Future<WorkTagVote?> Function(int)? onVote;
  final WorkTagVote? votes;
  final bool needsSignIn;

  const GrayTagActionsDialog({
    super.key,
    required this.label,
    required this.onBlacklist,
    required this.onVote,
    required this.votes,
    required this.needsSignIn,
  });

  @override
  State<GrayTagActionsDialog> createState() => _GrayTagActionsDialogState();
}

class _GrayTagActionsDialogState extends State<GrayTagActionsDialog> {
  late WorkTagVote? _votes = widget.votes;
  var _saving = false;
  Object? _voteError;

  Future<void> _vote(int vote) async {
    final previous = _votes;
    final onVote = widget.onVote;
    if (_saving || previous == null || onVote == null) return;
    setState(() {
      _saving = true;
      _voteError = null;
    });
    try {
      final updated = await onVote(vote);
      if (mounted) {
        setState(() {
          _votes =
              updated ??
              (
                id: previous.id,
                myVote: vote,
                upvotes: _updateCount(
                  previous.upvotes,
                  1,
                  previous.myVote,
                  vote,
                ),
                downvotes: _updateCount(
                  previous.downvotes,
                  2,
                  previous.myVote,
                  vote,
                ),
              );
          _saving = false;
        });
      }
    } catch (error, stack) {
      AppLog.recordError('Work tag vote failed', error, stack);
      if (mounted) {
        setState(() {
          _voteError = error;
          _saving = false;
        });
      }
    }
  }

  int? _updateCount(int? count, int direction, int previous, int next) =>
      count == null
      ? null
      : math.max(
          0,
          count - (previous == direction ? 1 : 0) + (next == direction ? 1 : 0),
        );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final palette = theme.brightness == Brightness.dark
        ? AppColors.dark
        : AppColors.light;
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        backgroundColor: palette.surface,
        scrollable: true,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        constraints: const BoxConstraints(minWidth: 280, maxWidth: 440),
        titlePadding: const EdgeInsets.fromLTRB(24, 12, 12, 4),
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          color: palette.text,
          fontWeight: FontWeight.w600,
        ),
        title: Row(
          children: [
            Expanded(child: Text(widget.label)),
            IconButton(
              tooltip: l10n.close,
              onPressed: _saving ? null : () => Navigator.pop(context),
              icon: const Icon(Icons.close, size: 20),
            ),
          ],
        ),
        contentPadding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
        content: _saving
            ? const LinearProgressIndicator()
            : _voteError is WorkTagEmailRequired
            ? const _WorkTagEmailNotice()
            : _voteError != null
            ? Text(
                l10n.workTagRequestFailed,
                style: TextStyle(color: palette.red),
              )
            : widget.needsSignIn
            ? Text(l10n.workTagVoteSignIn, style: TextStyle(color: palette.dim))
            : null,
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actionsOverflowButtonSpacing: 4,
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: _saving || widget.onBlacklist == null
                ? null
                : () {
                    widget.onBlacklist!();
                    Navigator.pop(context);
                  },
            child: Text(
              widget.onBlacklist == null
                  ? l10n.workTagBlacklisted
                  : l10n.workTagBlacklist,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _voteButton(
                vote: 2,
                count: _votes?.downvotes,
                label: l10n.workTagDownvote,
                icon: Icons.thumb_down,
                color: Colors.red,
                palette: palette,
              ),
              const SizedBox(width: 4),
              _voteButton(
                vote: 1,
                count: _votes?.upvotes,
                label: l10n.workTagUpvote,
                icon: Icons.thumb_up,
                color: Colors.green,
                palette: palette,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _voteButton({
    required int vote,
    required int? count,
    required String label,
    required IconData icon,
    required Color color,
    required Palette palette,
  }) {
    final selected = _votes?.myVote == vote;
    final countText = count?.toString() ?? '—';
    return Semantics(
      label: label,
      value: countText,
      selected: selected,
      child: TextButton.icon(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 40),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          foregroundColor: palette.text,
          disabledForegroundColor: palette.dim,
          backgroundColor: selected ? color.withValues(alpha: .14) : null,
        ),
        onPressed: _saving || widget.onVote == null
            ? null
            : () => _vote(selected ? 0 : vote),
        icon: Icon(icon, size: 18, color: color),
        label: ExcludeSemantics(child: Text(countText)),
      ),
    );
  }
}
