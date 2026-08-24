import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/pending_upload.dart';
import '../providers/connectivity_provider.dart';
import '../providers/offline_provider.dart';
import '../services/sync_service.dart';
import '../services/screen_prefetch.dart';
import '../utils/constants.dart';
import '../widgets/state_views.dart';
import '../utils/formatters.dart';

/// Everything sitting on this phone that the server has not got.
///
/// The question this screen exists to answer is the last one in the brief and
/// the only one with teeth: *if data went up and failed, how do we know?*
///
/// A count of "pending" cannot answer it, because two completely different
/// things hide inside that word. A record waiting for a network is fine and
/// needs nobody. A record the server LOOKED AT AND REFUSED is not fine: the
/// upload machinery will never move it, no amount of waiting helps, and if
/// nobody reads it, the work behind it -- an expense someone paid for, a sale
/// whose goods have already left the shop -- is simply gone. So the three
/// states are drawn as three different things, and the refused ones are
/// hoisted to the top of the screen under their own heading rather than being
/// sorted in by date with everything else.
class PendingUploadsScreen extends StatefulWidget {
  const PendingUploadsScreen({super.key});

  @override
  State<PendingUploadsScreen> createState() => _PendingUploadsScreenState();
}

class _PendingUploadsScreenState extends State<PendingUploadsScreen> {
  List<PendingUpload> _items = const [];
  bool _loading = true;

  /// True from the moment the button is tapped until the run's result has been
  /// shown. Separate from OfflineProvider.isSyncing on purpose: a background
  /// sweep also sets that flag, and the button must not look pressed because
  /// the five-minute timer happened to fire. This one is what stops a double
  /// tap starting a second run and what keeps the spinner honest.
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final offline = context.read<OfflineProvider>();
    final items = await offline.loadPendingUploads();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  // -------------------------------------------------------------------------
  // Sync now
  // -------------------------------------------------------------------------

  Future<void> _syncNow() async {
    if (_syncing) return;

    final offline = context.read<OfflineProvider>();
    setState(() => _syncing = true);

    final SyncRunReport report;
    try {
      report = await offline.triggerSync();
    } finally {
      if (mounted) setState(() => _syncing = false);
    }

    await _load();
    if (!mounted) return;

    final message = _describeRun(report);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message.text),
          backgroundColor: message.colour,
          duration: const Duration(seconds: 5),
        ),
      );
  }

  /// What a run actually did, said plainly.
  ///
  /// Never a bare "Success". A run that uploads three records and has a fourth
  /// refused has not succeeded from the point of view of the person who made
  /// the fourth one, and a green tick over that is exactly how a rejection
  /// gets buried.
  static ({String text, Color colour}) _describeRun(SyncRunReport report) {
    if (report.alreadyRunning) {
      return (
        text: 'An upload is already running. Nothing was started twice.',
        colour: AppColors.info,
      );
    }
    if (report.noNetwork) {
      return (
        text: 'No connection, so nothing was sent. Everything is still saved '
            'on this phone.',
        colour: AppColors.warning,
      );
    }

    final parts = <String>[];
    if (report.uploaded > 0) parts.add('${report.uploaded} uploaded');
    if (report.rejected > 0) parts.add('${report.rejected} refused');

    if (report.serverUnreachable) {
      final prefix = parts.isEmpty ? '' : '${parts.join(', ')}. ';
      return (
        text: '${prefix}The server stopped answering. '
            '${report.stillWaiting} still waiting - it will keep trying.',
        colour: AppColors.warning,
      );
    }

    if (parts.isEmpty) {
      return (
        text: report.stillWaiting == 0
            ? 'Nothing was waiting. Everything is already on the server.'
            : '${report.stillWaiting} still waiting.',
        colour: report.stillWaiting == 0 ? AppColors.success : AppColors.info,
      );
    }

    final tail = report.stillWaiting > 0
        ? ' ${report.stillWaiting} still waiting.'
        : '';
    return (
      text: '${parts.join(', ')}.$tail',
      // Any refusal at all colours the whole message, because that is the part
      // somebody has to act on.
      colour: report.rejected > 0 ? AppColors.error : AppColors.success,
    );
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final rejected =
        _items.where((i) => i.state == UploadState.rejected).toList();
    final rest =
        _items.where((i) => i.state != UploadState.rejected).toList();
    final tally = PendingUploadTally.of(_items);

    return Scaffold(
      backgroundColor: AppColors.ground(context),
      appBar: AppBar(
        title: const Text('Not yet uploaded'),
        backgroundColor:
            AppColors.isDark(context) ? AppColors.darkCard : AppColors.primary,
        foregroundColor:
            AppColors.isDark(context) ? AppColors.darkText : Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _ConnectionCard(tally: tally),
                  const SizedBox(height: 16),
                  _syncButton(),
                  const SizedBox(height: 24),
                  if (rejected.isNotEmpty) ...[
                    _RejectedHeader(count: rejected.length),
                    const SizedBox(height: 8),
                    for (final item in rejected)
                      _UploadRow(item: item, onTap: () => _openDetail(item)),
                    const SizedBox(height: 24),
                  ],
                  _SectionLabel(
                    rejected.isEmpty
                        ? 'Waiting to upload'
                        : 'Everything else waiting',
                  ),
                  const SizedBox(height: 8),
                  if (rest.isEmpty)
                    _EmptyNote(
                      rejected.isEmpty
                          ? 'Nothing is waiting. Everything you have recorded '
                              'on this phone is on the server.'
                          : 'Nothing else is waiting.',
                    )
                  else
                    for (final item in rest)
                      _UploadRow(item: item, onTap: () => _openDetail(item)),
                ],
              ),
            ),
    );
  }

  Widget _syncButton() {
    return Consumer2<ConnectivityProvider, OfflineProvider>(
      builder: (context, connectivity, offline, _) {
        final noNetwork = connectivity.isOffline;
        // A background sweep counts as busy too -- the button would do nothing
        // but queue behind it, and a button that does nothing is worse than a
        // disabled one that says why.
        final busy = _syncing || offline.isSyncing;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: (noNetwork || busy) ? null : _syncNow,
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : const Icon(Icons.cloud_upload_outlined),
              label: Text(busy ? 'Uploading...' : 'Sync now'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              noNetwork
                  // Says why it is disabled instead of leaving a dead button.
                  ? 'There is no connection, so there is nothing to press. '
                      'Everything is saved here and goes up by itself.'
                  : busy
                      ? 'Uploading. Pressing again will not start a second '
                          'upload.'
                      : 'This also happens by itself. Pressing it is safe - '
                          'nothing can be uploaded twice.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.muted(context),
              ),
            ),
            const SizedBox(height: 20),
            const _DownloadedDataCard(),
          ],
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // One record, in full
  // -------------------------------------------------------------------------

  Future<void> _openDetail(PendingUpload item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.raised(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _UploadDetailSheet(
        item: item,
        onRetry: () => _retry(item),
        onDiscard: () => _discard(item),
        onAcknowledge: () => _acknowledge(item),
        onCopy: () => _copy(item),
      ),
    );
    await _load();
  }

  Future<void> _acknowledge(PendingUpload item) async {
    await context.read<OfflineProvider>().acknowledgeRejection(item);
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '${item.kind} marked as seen. It is still here and still not '
            'uploaded.',
          ),
          backgroundColor: AppColors.info,
        ),
      );
  }

  Future<void> _copy(PendingUpload item) async {
    await Clipboard.setData(ClipboardData(text: _plainText(item)));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Details copied. Paste them anywhere to re-enter or '
              'send them on.'),
          backgroundColor: AppColors.info,
        ),
      );
  }

  /// The record as text somebody can paste into a message or re-key from.
  ///
  /// The point of this button is the case where the answer is "type it in
  /// again by hand" -- so it has to carry everything needed to do that,
  /// including the reference (request id) that lets an admin check server-side
  /// whether the first attempt landed after all.
  static String _plainText(PendingUpload item) {
    final lines = <String>[
      item.kind,
      if (item.detail != null) item.detail!,
      if (item.amount != null)
        'Amount: ${Formatters.formatCurrency(item.amount!)}',
      if (item.createdAt != null) 'Created: ${_fullTime(item.createdAt!)}',
      'Status: ${_stateWord(item.state)}',
      if (item.reason != null) 'Server said: ${item.reason}',
      if (item.requestId != null) 'Reference: ${item.requestId}',
    ];
    return lines.join('\n');
  }

  Future<void> _retry(PendingUpload item) async {
    final offline = context.read<OfflineProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final after = await offline.retryRejected(item);
    if (!mounted) return;
    navigator.pop();

    final String text;
    final Color colour;
    if (after == null) {
      text = '${item.kind} uploaded. It is on the server now.';
      colour = AppColors.success;
    } else if (after.state == UploadState.rejected) {
      text = 'The server refused it again: ${after.reason ?? 'no reason given'}';
      colour = AppColors.error;
    } else {
      text = '${item.kind} is back in the queue and will keep trying.';
      colour = AppColors.info;
    }

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          backgroundColor: colour,
          duration: const Duration(seconds: 5),
        ),
      );
  }

  /// Throwing away a refused record, deliberately and by name.
  ///
  /// Two things this must never be: silent, or automatic. The confirmation
  /// spells out what is being given up -- the kind, the amount, when it was
  /// made -- because "Discard 1 item?" is not something anybody can answer
  /// responsibly.
  Future<void> _discard(PendingUpload item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.raised(dialogContext),
        title: const Text('Stop trying to upload this?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are giving up on:',
              style: TextStyle(color: AppColors.muted(dialogContext)),
            ),
            const SizedBox(height: 8),
            Text(
              _describeItem(item),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.ink(dialogContext),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'It will never be uploaded, and the server will never have it. '
              'It stays readable on this phone, so copy the details first if '
              'anyone might ask about it.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.muted(dialogContext),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep it'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Give up on it'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final offline = context.read<OfflineProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final done = await offline.discardRejected(item);
    if (!mounted) return;
    navigator.pop();

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(done
              ? '${item.kind} will not be uploaded. It is still readable on '
                  'this phone.'
              : 'Nothing changed - that record is no longer refused.'),
          backgroundColor: done ? AppColors.warning : AppColors.info,
        ),
      );
  }

  static String _describeItem(PendingUpload item) {
    final bits = <String>[
      item.kind,
      if (item.detail != null) item.detail!,
      if (item.amount != null) Formatters.formatCurrency(item.amount!),
      if (item.createdAt != null) _fullTime(item.createdAt!),
    ];
    return bits.join('  -  ');
  }
}

// ===========================================================================
// Shared bits
// ===========================================================================

String _stateWord(UploadState state) {
  switch (state) {
    case UploadState.waiting:
      return 'Waiting';
    case UploadState.trying:
      return 'Trying';
    case UploadState.rejected:
      return 'Rejected';
  }
}

Color _stateColour(UploadState state) {
  switch (state) {
    case UploadState.waiting:
      return AppColors.info;
    case UploadState.trying:
      return AppColors.warning;
    case UploadState.rejected:
      return AppColors.error;
  }
}

IconData _stateIcon(UploadState state) {
  switch (state) {
    case UploadState.waiting:
      return Icons.schedule;
    case UploadState.trying:
      return Icons.sync_problem;
    case UploadState.rejected:
      return Icons.report_problem;
  }
}

String _fullTime(DateTime time) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(time.day)}/${two(time.month)}/${time.year} '
      '${two(time.hour)}:${two(time.minute)}';
}

/// Where the connection stands and how much is owed, above everything else.
class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({required this.tally});

  final PendingUploadTally tally;

  @override
  Widget build(BuildContext context) {
    return Consumer2<ConnectivityProvider, OfflineProvider>(
      builder: (context, connectivity, offline, _) {
        final noNetwork = connectivity.isOffline;
        final noServer = !noNetwork && !offline.serverReachable;

        final String title;
        final IconData icon;
        final Color colour;
        if (noNetwork) {
          title = 'No connection';
          icon = Icons.cloud_off;
          colour = AppColors.warning;
        } else if (noServer) {
          // Worth its own wording: the phone's own icons say everything is
          // fine, so a person has no other way to find out.
          title = 'Connected, but the server is not answering';
          icon = Icons.cloud_off;
          colour = AppColors.warning;
        } else {
          title = 'Connected';
          icon = Icons.cloud_done;
          colour = AppColors.success;
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.hairline(context)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: colour, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.ink(context),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Wrap, not Row: three counts plus their words do not fit on a
              // narrow phone, and this list has overflowed before.
              Wrap(
                spacing: 20,
                runSpacing: 12,
                children: [
                  _TallyBlock(
                    count: tally.waiting,
                    label: 'Waiting',
                    colour: _stateColour(UploadState.waiting),
                  ),
                  _TallyBlock(
                    count: tally.trying,
                    label: 'Trying',
                    colour: _stateColour(UploadState.trying),
                  ),
                  _TallyBlock(
                    count: tally.rejected,
                    label: 'Rejected',
                    colour: _stateColour(UploadState.rejected),
                  ),
                ],
              ),
              if (tally.isEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  'Nothing is owed to the server.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.muted(context),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _TallyBlock extends StatelessWidget {
  const _TallyBlock({
    required this.count,
    required this.label,
    required this.colour,
  });

  final int count;
  final String label;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    // A zero is deliberately greyed rather than hidden: the three states are
    // only readable as a set if all three are always present.
    final shown = count > 0 ? colour : AppColors.faded(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: shown,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppColors.muted(context)),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        color: AppColors.muted(context),
      ),
    );
  }
}

/// The heading over the refused records. Deliberately loud.
class _RejectedHeader extends StatelessWidget {
  const _RejectedHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.report_problem, color: AppColors.error, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count == 1
                      ? '1 record will never upload on its own'
                      : '$count records will never upload on their own',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.error,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'The server looked at these and refused them. Retrying '
                  'changes nothing by itself. Open one to read why and decide '
                  'what to do.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.ink(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.sunken(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 13, color: AppColors.muted(context)),
      ),
    );
  }
}

/// One unsent record.
class _UploadRow extends StatelessWidget {
  const _UploadRow({required this.item, required this.onTap});

  final PendingUpload item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rejected = item.state == UploadState.rejected;
    final colour = _stateColour(item.state);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: rejected
                    ? AppColors.error.withValues(alpha: 0.6)
                    : AppColors.hairline(context),
                // A refused row is thicker as well as redder, so it still
                // reads as different for anyone who cannot rely on colour.
                width: rejected ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(_stateIcon(item.state), size: 18, color: colour),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.kind,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink(context),
                            ),
                          ),
                          if (item.detail != null)
                            Text(
                              item.detail!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.muted(context),
                              ),
                            ),
                          if (item.createdAt != null)
                            Text(
                              _fullTime(item.createdAt!),
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.muted(context),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (item.amount != null) ...[
                      const SizedBox(width: 8),
                      // Constrained and ellipsised: an unbounded amount beside
                      // a long description is how this row overflows.
                      Flexible(
                        child: Text(
                          Formatters.formatCurrency(item.amount!),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.ink(context),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _StateChip(state: item.state),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _rowNote(item),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: rejected
                              ? AppColors.error
                              : AppColors.muted(context),
                          fontWeight:
                              rejected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The one line under the chip. For a refused record this is the server's
  /// own words -- never a paraphrase, because the words are what tells whoever
  /// has to fix it what to fix.
  static String _rowNote(PendingUpload item) {
    switch (item.state) {
      case UploadState.waiting:
        return 'Saved here. Goes up by itself.';
      case UploadState.trying:
        final attempts = item.attempts == 1
            ? '1 attempt'
            : '${item.attempts} attempts';
        final reason = item.reason;
        return reason == null || reason.isEmpty
            ? 'Will try again ($attempts).'
            : '$reason ($attempts)';
      case UploadState.rejected:
        final reason = item.reason;
        return reason == null || reason.isEmpty
            ? 'The server refused this and gave no reason.'
            : reason;
    }
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip({required this.state});

  final UploadState state;

  @override
  Widget build(BuildContext context) {
    final colour = _stateColour(state);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colour.withValues(alpha: 0.5)),
      ),
      child: Text(
        _stateWord(state),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: colour,
        ),
      ),
    );
  }
}

/// One record in full, and -- for a refused one -- what can be done about it.
class _UploadDetailSheet extends StatelessWidget {
  const _UploadDetailSheet({
    required this.item,
    required this.onRetry,
    required this.onDiscard,
    required this.onAcknowledge,
    required this.onCopy,
  });

  final PendingUpload item;
  final Future<void> Function() onRetry;
  final Future<void> Function() onDiscard;
  final Future<void> Function() onAcknowledge;
  final Future<void> Function() onCopy;

  @override
  Widget build(BuildContext context) {
    final rejected = item.state == UploadState.rejected;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_stateIcon(item.state),
                    color: _stateColour(item.state), size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.kind,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.ink(context),
                    ),
                  ),
                ),
                _StateChip(state: item.state),
              ],
            ),
            const SizedBox(height: 16),
            if (item.detail != null)
              _DetailLine(label: 'What', value: item.detail!),
            if (item.amount != null)
              _DetailLine(
                label: 'Amount',
                value: Formatters.formatCurrency(item.amount!),
              ),
            if (item.createdAt != null)
              _DetailLine(label: 'Created', value: _fullTime(item.createdAt!)),
            if (item.attempts > 0)
              _DetailLine(label: 'Attempts', value: '${item.attempts}'),
            if (item.requestId != null)
              _DetailLine(label: 'Reference', value: item.requestId!),

            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: rejected
                    ? AppColors.error.withValues(alpha: 0.10)
                    : AppColors.sunken(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _headline(item.state),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: rejected
                          ? AppColors.error
                          : AppColors.ink(context),
                    ),
                  ),
                  if (item.reason != null && item.reason!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'The server said:',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.muted(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    // The server's own words, verbatim. A friendlier rewrite
                    // here would strip out the very detail that says what to
                    // fix.
                    Text(
                      item.reason!,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.ink(context),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 20),
            if (rejected) ...[
              _SheetButton(
                icon: Icons.refresh,
                label: 'Try again now',
                hint: 'Safe: it cannot be uploaded twice.',
                onPressed: onRetry,
              ),
              const SizedBox(height: 8),
              _SheetButton(
                icon: Icons.copy_all_outlined,
                label: 'Copy the details',
                hint: 'To re-enter it by hand or send it to someone.',
                onPressed: onCopy,
              ),
              if (!item.acknowledged) ...[
                const SizedBox(height: 8),
                _SheetButton(
                  icon: Icons.visibility_outlined,
                  label: 'I have seen this',
                  hint: 'Stops the warning. The record stays here, unsent.',
                  onPressed: onAcknowledge,
                ),
              ],
              const SizedBox(height: 8),
              _SheetButton(
                icon: Icons.delete_outline,
                label: 'Give up on it',
                hint: 'Asks you to confirm first, and names what is lost.',
                danger: true,
                onPressed: onDiscard,
              ),
            ] else
              Text(
                'There is nothing to do. This uploads on its own.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.muted(context),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  static String _headline(UploadState state) {
    switch (state) {
      case UploadState.waiting:
        return 'Waiting for a connection. Nothing is wrong.';
      case UploadState.trying:
        return 'The server could not take it yet. It will be tried again.';
      case UploadState.rejected:
        return 'The server refused this. It will NEVER upload on its own.';
    }
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.muted(context),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13, color: AppColors.ink(context)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.icon,
    required this.label,
    required this.hint,
    required this.onPressed,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final String hint;
  final Future<void> Function() onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colour = danger ? AppColors.error : AppColors.brandPrimary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onPressed(),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colour.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: colour),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colour,
                      ),
                    ),
                    Text(
                      hint,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.muted(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the app has already pulled DOWN, as opposed to what is waiting to go up.
///
/// The rest of this screen answers "is my work safe" -- the queue, the
/// failures, the retry. This answers the other half of the same worry: "will
/// there be anything on this phone when I lose signal." They belong together,
/// because a seller checking one is usually about to leave.
///
/// It lists what came down by name. "Last downloaded 2 hours ago" on its own
/// still leaves somebody guessing whether the screen they need was included --
/// which is the question they actually have.
class _DownloadedDataCard extends StatefulWidget {
  const _DownloadedDataCard();

  @override
  State<_DownloadedDataCard> createState() => _DownloadedDataCardState();
}

class _DownloadedDataCardState extends State<_DownloadedDataCard> {
  PrefetchReport? _report;
  DateTime? _lastAt;
  bool _busy = false;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final offline = context.read<OfflineProvider>();
    final at = await offline.lastPrefetchAt();
    final report = await offline.lastPrefetchReport();
    if (mounted) {
      setState(() {
        _lastAt = at;
        _report = report;
      });
    }
  }

  Future<void> _downloadNow() async {
    setState(() => _busy = true);
    // force: the whole point of pressing it is to override the three-hour pace.
    final report =
        await context.read<OfflineProvider>().prefetchScreens(force: true);
    await _refresh();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (report.didRun && report.loaded > 0) _expanded = true;
    });

    final message = !report.didRun
        ? 'Cannot download right now: ${report.skippedBecause}'
        : report.loaded == 0
            ? 'Nothing could be downloaded. The server did not answer.'
            : report.failed == 0
                ? 'Downloaded. These screens will open without a connection.'
                : 'Downloaded ${report.loaded}. ${report.failed} could not be '
                    'fetched and will be retried.';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final offline = context.watch<OfflineProvider>();
    final noNetwork = !offline.isOnline;
    final report = _report;
    final entries = report?.entries ?? const <PrefetchEntry>[];
    // The provider is the source of truth, not local state: a warm started by
    // signing in has to show here too, not only one this button began.
    final running = offline.isPrefetching || _busy;
    final percent = (offline.prefetchProgress * 100).round();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.raised(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_download_outlined,
                  size: 18, color: AppColors.muted(context)),
              const SizedBox(width: 8),
              // Expanded, not bare: the title has to wrap on a 320px phone
              // rather than push the row off the screen.
              Expanded(
                child: Text(
                  'Data saved on this phone',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _lastAt == null
                // Not an error: it just has not happened yet on this device.
                ? 'Not downloaded yet. This happens by itself when you sign in '
                    'with a connection. You can also start it below.'
                : 'Last downloaded ${describeCacheAge(_lastAt!)}.',
            style: TextStyle(fontSize: 12, color: AppColors.muted(context)),
          ),
          if (entries.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '${report!.loaded} of ${entries.length} ready'
              '${report.failed > 0 ? ', ${report.failed} still missing' : ''}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: report.failed > 0
                    ? AppColors.warning
                    : AppColors.success,
              ),
            ),
            const SizedBox(height: 4),
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Text(
                      _expanded ? 'Hide the list' : 'See what was downloaded',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
            if (_expanded)
              // Failures first: a person opening this list is looking for what
              // is missing, not admiring what worked.
              ...([...entries]..sort((a, b) => a.ok == b.ok ? 0 : (a.ok ? 1 : -1)))
                  .map(
                (e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Icon(
                        e.ok ? Icons.check_circle_outline : Icons.error_outline,
                        size: 15,
                        color: e.ok ? AppColors.success : AppColors.warning,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          e.label,
                          style: TextStyle(
                            fontSize: 12,
                            color: e.ok
                                ? AppColors.muted(context)
                                : AppColors.ink(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
          const SizedBox(height: 12),
          // A bar with a percentage while it runs, because this can take a
          // minute on a bad connection and a spinner gives no idea whether to
          // keep waiting. The label names what is being fetched right now, so
          // the wait is legible rather than blank.
          if (running) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: offline.prefetchProgress,
                minHeight: 8,
                backgroundColor: AppColors.track(context),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  '$percent%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    offline.prefetchLabel ?? 'Starting...',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.muted(context),
                    ),
                  ),
                ),
                Text(
                  '${offline.prefetchDone}/${offline.prefetchTotal}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.muted(context),
                  ),
                ),
              ],
            ),
          ] else
            OutlinedButton.icon(
              onPressed: noNetwork ? null : _downloadNow,
              icon: const Icon(Icons.download_outlined, size: 18),
              label: const Text('Download now'),
            ),
          if (noNetwork) ...[
            const SizedBox(height: 6),
            Text(
              'Needs a connection. Whatever was downloaded before is still '
              'here and still works.',
              style: TextStyle(fontSize: 11, color: AppColors.muted(context)),
            ),
          ],
        ],
      ),
    );
  }
}
