import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme.dart';
import '../core/bill_items_import.dart';
import '../core/bill_items_prompt.dart';
import '../core/formatters.dart';
import '../core/input_limits.dart';
import '../core/split_bill.dart';

/// All changes stay on this route until the user explicitly adds the batch.
class BillItemsImportPage extends StatefulWidget {
  const BillItemsImportPage({
    super.key,
    required this.currencyCode,
    required this.participants,
    required this.existingItems,
  });

  final String currencyCode;
  final List<BillParticipant> participants;
  final List<BillItem> existingItems;

  @override
  State<BillItemsImportPage> createState() => _BillItemsImportPageState();
}

class _BillItemsImportPageState extends State<BillItemsImportPage> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  List<BillImportDraft> _rows = [];
  String? _parseError;
  String? _parsedText;
  var _step = 0;
  var _current = 0;
  var _nextId = 0;
  var _submitting = false;
  var _reviewing = false;

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  int get _subtotal =>
      _rows.fold(0, (sum, row) => sum + (row.isValid ? row.totalMinor! : 0));
  int get _remaining => InputLimits.maxBillItems - widget.existingItems.length;
  int get _invalid => _rows.where((row) => !row.isValid).length;
  bool get _reviewValid =>
      _rows.isNotEmpty && _invalid == 0 && _rows.length <= _remaining;
  bool _assigned(BillImportDraft row) =>
      row.participantIds.isNotEmpty &&
      row.participantIds.every(
        (id) => widget.participants.any((person) => person.id == id),
      );
  int get _assignedCount => _rows.where(_assigned).length;

  String _money(int minor) => widget.currencyCode == 'JPY'
      ? 'JPY ${minor ~/ 100}.${(minor % 100).toString().padLeft(2, '0')}'
      : formatMoney(minor, widget.currencyCode);

  void _go(int step) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _step = step);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _copyPrompt() async {
    try {
      await Clipboard.setData(
        ClipboardData(text: buildBillItemsPrompt(widget.currencyCode)),
      );
      if (mounted) {
        _message('Prompt copied. Attach your receipt in your preferred AI.');
      }
    } catch (_) {
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Copy the prompt manually'),
            content: SingleChildScrollView(
              child: SelectableText(buildBillItemsPrompt(widget.currencyCode)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _paste() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (!mounted) return;
      if (data?.text == null || data!.text!.trim().isEmpty) {
        _message('Your clipboard has no text. Copy the item list first.');
        return;
      }
      if (data.text!.length > InputLimits.maxBillImportCharacters) {
        setState(
          () => _parseError =
              'This list is too long. Paste at most 32,768 characters; your current text was kept.',
        );
        return;
      }
      setState(() {
        _text.text = data.text!;
        _parseError = null;
      });
    } catch (_) {
      if (mounted) {
        _message(
          'Clipboard access is unavailable. Paste directly into the text field.',
        );
      }
    }
  }

  Future<void> _review() async {
    if (_reviewing) return;
    setState(() => _reviewing = true);
    try {
      if (_rows.isNotEmpty && _text.text == _parsedText) {
        _go(1);
        return;
      }
      final result = parseBillItems(_text.text);
      if (result.error != null) {
        setState(() => _parseError = result.error);
        return;
      }
      if (_rows.isNotEmpty) {
        final replace = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Review the new list?'),
            content: const Text(
              'This replaces your reviewed rows and clears their people selections. Your existing bill items stay as they are.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep current review'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Use new list'),
              ),
            ],
          ),
        );
        if (!mounted || replace != true) return;
      }
      setState(() {
        _rows = result.rows;
        _parsedText = _text.text;
        _parseError = null;
        _current = 0;
      });
      _go(1);
    } finally {
      if (mounted) setState(() => _reviewing = false);
    }
  }

  Future<void> _editRow(BillImportDraft? row) async {
    final edited = await showModalBottomSheet<BillImportDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ImportRowEditor(
        row: row,
        newId: 'added-${_nextId++}',
        currencyCode: widget.currencyCode,
      ),
    );
    if (!mounted || edited == null) return;
    setState(() {
      if (row == null) {
        _rows.add(edited);
      } else {
        final index = _rows.indexWhere((entry) => entry.id == row.id);
        if (index >= 0) _rows[index] = edited;
      }
    });
  }

  Future<void> _split(BillImportDraft row) async {
    if (_rows.length >= _remaining) {
      _message(
        'Splitting needs one more item slot. A bill can contain up to 100 items.',
      );
      return;
    }
    final first = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _SplitQuantitySheet(row: row),
    );
    if (!mounted || first == null) return;
    setState(() {
      final index = _rows.indexOf(row);
      _rows.replaceRange(index, index + 1, splitBillImportDraft(row, first));
      _current = index;
    });
    _message('Quantity split. Choose people for each part.');
  }

  void _commit() {
    if (_submitting || !_reviewValid || _assignedCount != _rows.length) return;
    setState(() => _submitting = true);
    Navigator.pop(context, _rows);
  }

  bool _duplicate(BillImportDraft row) =>
      row.isValid &&
      (widget.existingItems.any(
            (item) => row.matches(item.name, item.quantity, item.amountMinor),
          ) ||
          _rows.any(
            (other) =>
                other.id != row.id &&
                other.isValid &&
                row.matches(other.name, other.quantity!, other.amountMinor!),
          ));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_submitting) _go(_step - 1);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(
            onPressed: () =>
                _step == 0 ? Navigator.pop(context) : _go(_step - 1),
          ),
          title: const Text('Paste items'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel import'),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  Row(
                    children: [
                      for (var i = 0; i < 3; i++) ...[
                        if (i > 0)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(
                              Icons.chevron_right,
                              size: 16,
                              color: scheme.outline,
                            ),
                          ),
                        Expanded(
                          child: Semantics(
                            selected: _step == i || (_step == 3 && i == 2),
                            child: Column(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: _step >= i
                                        ? scheme.primary
                                        : scheme.outlineVariant,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  ['1  Paste', '2  Review', '3  Assign'][i],
                                  style: TextStyle(
                                    fontWeight: _step >= i
                                        ? FontWeight.w800
                                        : FontWeight.w400,
                                    color: _step >= i
                                        ? scheme.primary
                                        : scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (_step == 0) ..._pasteContent(),
                  if (_step == 1) ..._reviewContent(),
                  if (_step == 2) ..._assignmentContent(),
                  if (_step == 3) ..._summaryContent(),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: _footer(),
        ),
      ),
    );
  }

  Widget _heading(String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );

  List<Widget> _pasteContent() => [
    _heading(
      'One paste. Every order.',
      'Bring your whole item list, then choose who shared what.',
    ),
    Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [BalanceMateColors.navy, BalanceMateColors.cobalt],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.auto_awesome_outlined,
            color: BalanceMateColors.gold,
            size: 30,
          ),
          const SizedBox(height: 14),
          const Text(
            'Have a receipt photo?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Copy the prompt. Attach your photo in your preferred AI. Bring its response back here.',
            style: TextStyle(color: Colors.white, height: 1.5),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: BalanceMateColors.navy,
            ),
            onPressed: _copyPrompt,
            icon: const Icon(Icons.copy_outlined, size: 18),
            label: const Text('Copy AI prompt'),
          ),
        ],
      ),
    ),
    const SizedBox(height: 22),
    Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      children: [
        Text(
          'Your item list · ${widget.currencyCode}',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        TextButton.icon(
          onPressed: _paste,
          icon: const Icon(Icons.content_paste, size: 18),
          label: const Text('Paste from clipboard'),
        ),
      ],
    ),
    const SizedBox(height: 8),
    TextField(
      key: const ValueKey('bill-import-text'),
      controller: _text,
      minLines: 6,
      maxLines: 12,
      maxLength: InputLimits.maxBillImportCharacters,
      maxLengthEnforcement: MaxLengthEnforcement.none,
      keyboardType: TextInputType.multiline,
      textDirection: TextDirection.ltr,
      onChanged: (_) => setState(() => _parseError = null),
      decoration: InputDecoration(
        labelText: 'Paste or type items',
        alignLabelWithHint: true,
        hintText: billItemsExample,
        errorText: _parseError,
        errorMaxLines: 6,
      ),
    ),
    const SizedBox(height: 8),
    _notice(
      Icons.info_outline,
      'Item, quantity, unit price. One item per line, or use semicolons between items. Use a decimal point for prices and quotes around names containing commas.',
    ),
    const SizedBox(height: 12),
    Text(
      'Pasted text is processed on this device. Uploading a photo to another service is your choice.',
      style: Theme.of(context).textTheme.bodySmall,
    ),
    if (_rows.isNotEmpty) ...[
      const SizedBox(height: 12),
      TextButton(
        onPressed: () => _go(1),
        child: const Text('Return to current review'),
      ),
    ],
  ];

  List<Widget> _reviewContent() => [
    _heading(
      'A quick check before the split',
      'Check each price against your receipt. Tap a row to make a correction.',
    ),
    _totals(),
    const SizedBox(height: 16),
    if (_rows.length > _remaining) ...[
      _notice(
        Icons.error_outline,
        'This bill has ${widget.existingItems.length} items. Remove ${_rows.length - _remaining} imported rows to stay within ${InputLimits.maxBillItems} items.',
        error: true,
      ),
      const SizedBox(height: 12),
    ],
    if (_invalid > 0) ...[
      _notice(
        Icons.edit_outlined,
        '$_invalid ${_invalid == 1 ? 'row needs' : 'rows need'} a correction. All rows are kept until you edit or remove them.',
        error: true,
      ),
      const SizedBox(height: 12),
    ],
    for (final row in _rows) ...[_reviewCard(row), const SizedBox(height: 10)],
    if (_rows.isEmpty)
      _notice(
        Icons.restaurant_menu,
        'No items remain. Add a missing item or return to your original text.',
      ),
    Wrap(
      spacing: 8,
      children: [
        TextButton.icon(
          onPressed: _rows.length < _remaining ? () => _editRow(null) : null,
          icon: const Icon(Icons.add),
          label: const Text('Add missing item'),
        ),
        TextButton.icon(
          onPressed: () => _go(0),
          icon: const Icon(Icons.subject),
          label: const Text('Original text'),
        ),
      ],
    ),
    const SizedBox(height: 12),
    _notice(
      Icons.receipt_long_outlined,
      'Handle service, VAT, and tip in Extras after importing. If item prices already include VAT, adding it again would count it twice.',
    ),
  ];

  Widget _reviewCard(BillImportDraft row) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: row.isValid
              ? scheme.outlineVariant.withValues(alpha: .5)
              : scheme.error,
        ),
      ),
      child: InkWell(
        onTap: () => _editRow(row),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      row.sourceRecord == 0
                          ? 'Added item'
                          : 'Row ${row.sourceRecord}',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                  IconButton(
                    tooltip:
                        'Edit ${row.name.isEmpty ? 'row ${row.sourceRecord}' : row.name}',
                    onPressed: () => _editRow(row),
                    icon: const Icon(Icons.edit_outlined, size: 20),
                  ),
                  IconButton(
                    tooltip:
                        'Remove ${row.name.isEmpty ? 'row ${row.sourceRecord}' : row.name}',
                    onPressed: () => setState(() => _rows.remove(row)),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
              Text(
                row.name.trim().isEmpty ? 'Unnamed item' : row.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              if (row.isValid)
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text('${row.quantity} × ${_money(row.amountMinor!)} each'),
                    Text(
                      _money(row.totalMinor!),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: scheme.primary,
                      ),
                    ),
                  ],
                )
              else
                Text(row.error!, style: TextStyle(color: scheme.error)),
              if (row.structureError != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Original: ${row.sourceText}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (_duplicate(row)) ...[
                const SizedBox(height: 8),
                const Text(
                  'Possible duplicate · kept for you to check',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _assignmentContent() {
    final row = _rows[_current];
    final scheme = Theme.of(context).colorScheme;
    return [
      _heading(
        'Who shared this?',
        '$_assignedCount of ${_rows.length} items assigned. You choose the people for every item.',
      ),
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(
          value: _assignedCount / _rows.length,
          minHeight: 6,
        ),
      ),
      const SizedBox(height: 20),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Item ${_current + 1} of ${_rows.length}',
                style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                row.name,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${row.quantity} × ${_money(row.amountMinor!)} each',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 6),
              Text(
                _money(row.totalMinor!),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (row.quantity! > 1)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => _split(row),
                    icon: const Icon(Icons.call_split),
                    label: const Text('Split quantity'),
                  ),
                ),
              const Divider(height: 28),
              const Text(
                'The total is split equally between the selected people.',
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() {
                    row.participantIds.clear();
                    row.participantIds.addAll(
                      widget.participants.map((person) => person.id),
                    );
                  }),
                  child: const Text('Everyone'),
                ),
              ),
              for (final person in widget.participants)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(person.name),
                  value: row.participantIds.contains(person.id),
                  onChanged: (value) => setState(() {
                    value == true
                        ? row.participantIds.add(person.id)
                        : row.participantIds.remove(person.id);
                  }),
                ),
              if (row.participantIds.isEmpty)
                Text(
                  'Select at least one person to continue.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 22),
      const Text(
        'Jump to an item',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (index, item) in _rows.indexed)
            Tooltip(
              message:
                  '${item.name}: ${_assigned(item) ? 'assigned' : 'needs people'}',
              child: ChoiceChip(
                label: Text('${index + 1}'),
                avatar: _assigned(item)
                    ? const Icon(Icons.check_circle_outline, size: 18)
                    : null,
                selected: index == _current,
                onSelected: (_) => setState(() => _current = index),
              ),
            ),
        ],
      ),
      const SizedBox(height: 12),
      TextButton(
        onPressed: () => _go(1),
        child: const Text('Back to item review'),
      ),
    ];
  }

  List<Widget> _summaryContent() => [
    _heading(
      'Ready for the bill',
      'Every item has its people. Give the list one last look.',
    ),
    _totals(),
    const SizedBox(height: 20),
    for (final (index, row) in _rows.indexed) ...[
      Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 8,
          ),
          leading: Icon(
            Icons.check_circle,
            color: Theme.of(context).colorScheme.primary,
          ),
          title: Text(
            row.name,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(
            '${row.quantity} × ${_money(row.amountMinor!)} = ${_money(row.totalMinor!)}\n${widget.participants.where((p) => row.participantIds.contains(p.id)).map((p) => p.name).join(', ')}',
          ),
          isThreeLine: true,
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            _current = index;
            _go(2);
          },
        ),
      ),
      const SizedBox(height: 8),
    ],
    const SizedBox(height: 12),
    _notice(
      Icons.checklist_outlined,
      'These items will be added to your editor. Use Save split bill when you are ready to save everything.',
    ),
  ];

  Widget _totals() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(20),
    ),
    child: DefaultTextStyle.merge(
      style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_rows.length} ${_rows.length == 1 ? 'item' : 'items'} · ${widget.currencyCode}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            _money(_subtotal),
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
          ),
          Text(
            _invalid == 0
                ? 'Imported subtotal'
                : 'Valid rows only · $_invalid still to correct',
          ),
          if (widget.existingItems.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Bill subtotal after adding: ${_money(_subtotal + widget.existingItems.fold<int>(0, (sum, item) => sum + item.totalMinor))}${_invalid > 0 ? ' (incomplete)' : ''}',
            ),
          ],
        ],
      ),
    ),
  );

  Widget _notice(IconData icon, String text, {bool error = false}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: error ? scheme.errorContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: error ? scheme.onErrorContainer : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: error
                    ? scheme.onErrorContainer
                    : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    VoidCallback? action;
    String label;
    switch (_step) {
      case 0:
        label = 'Review items';
        action = _text.text.trim().isNotEmpty && !_reviewing ? _review : null;
      case 1:
        label = 'Assign people';
        action = _reviewValid
            ? () {
                if (widget.participants.isEmpty) {
                  _message(
                    'Add people in the bill editor before assigning items.',
                  );
                  return;
                }
                _current = 0;
                _go(2);
              }
            : null;
      case 2:
        label = _assignedCount == _rows.length ? 'Review summary' : 'Next item';
        action = _assigned(_rows[_current])
            ? () {
                if (_assignedCount == _rows.length) {
                  _go(3);
                } else {
                  setState(() {
                    _current = _rows.indexWhere(
                      (row) => !_assigned(row),
                      _current + 1,
                    );
                    if (_current < 0) {
                      _current = _rows.indexWhere((row) => !_assigned(row));
                    }
                  });
                  if (_scroll.hasClients) _scroll.jumpTo(0);
                }
              }
            : null;
      default:
        label =
            'Add ${_rows.length} ${_rows.length == 1 ? 'item' : 'items'} to bill';
        action = !_submitting && _reviewValid && _assignedCount == _rows.length
            ? _commit
            : null;
    }
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                  onPressed: action,
                  icon: Icon(_step == 3 ? Icons.add_task : Icons.arrow_forward),
                  label: Text(label, textAlign: TextAlign.center),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ImportRowEditor extends StatefulWidget {
  const _ImportRowEditor({
    required this.row,
    required this.newId,
    required this.currencyCode,
  });
  final BillImportDraft? row;
  final String newId, currencyCode;

  @override
  State<_ImportRowEditor> createState() => _ImportRowEditorState();
}

class _ImportRowEditorState extends State<_ImportRowEditor> {
  late final _name = TextEditingController(text: widget.row?.name);
  late final _quantity = TextEditingController(
    text: widget.row?.quantityText ?? '1',
  );
  late final _price = TextEditingController(text: widget.row?.priceText);
  var _submitting = false;

  BillImportDraft get _draft => BillImportDraft(
    id: widget.row?.id ?? widget.newId,
    sourceRecord: widget.row?.sourceRecord ?? 0,
    sourceText: widget.row?.sourceText ?? '',
    name: _name.text.trim(),
    quantityText: _quantity.text.trim(),
    priceText: _price.text.trim(),
    participantIds: {...?widget.row?.participantIds},
  );

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.row == null ? 'Add missing item' : 'Edit imported item',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (widget.row?.structureError != null) ...[
                const SizedBox(height: 12),
                Text('Original: ${widget.row!.sourceText}'),
                const Text(
                  'Correct the three fields below to repair this row.',
                ),
              ],
              const SizedBox(height: 20),
              TextField(
                controller: _name,
                maxLength: InputLimits.itemName,
                maxLengthEnforcement: MaxLengthEnforcement.none,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Item name',
                  errorText: draft.nameError,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _quantity,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Quantity',
                  errorText: draft.quantityError,
                  errorMaxLines: 3,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Unit price',
                  suffixText: widget.currencyCode,
                  errorText: draft.priceError,
                  errorMaxLines: 3,
                ),
              ),
              const SizedBox(height: 16),
              if (draft.isValid)
                Text(
                  'Line total: ${draft.totalMinor! ~/ 100}.${(draft.totalMinor! % 100).toString().padLeft(2, '0')} ${widget.currencyCode}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: draft.isValid && !_submitting
                    ? () {
                        if (_submitting) return;
                        setState(() => _submitting = true);
                        Navigator.pop(context, _draft);
                      }
                    : null,
                child: const Text('Keep changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SplitQuantitySheet extends StatefulWidget {
  const _SplitQuantitySheet({required this.row});
  final BillImportDraft row;
  @override
  State<_SplitQuantitySheet> createState() => _SplitQuantitySheetState();
}

class _SplitQuantitySheetState extends State<_SplitQuantitySheet> {
  final _quantity = TextEditingController(text: '1');
  var _submitting = false;

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final first = parseBillImportQuantity(_quantity.text);
    final valid = first != null && first < widget.row.quantity!;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Split quantity',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Text('${widget.row.quantity} × ${widget.row.name}'),
              const SizedBox(height: 8),
              const Text(
                'Make two rows at the same unit price, then choose people for each part. The total stays the same.',
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _quantity,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Quantity in first part',
                  errorText: valid
                      ? null
                      : 'Enter 1 to ${widget.row.quantity! - 1}.',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                valid
                    ? 'First part: $first   ·   Second part: ${widget.row.quantity! - first}'
                    : 'Both parts need at least one unit.',
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: valid && !_submitting
                    ? () {
                        if (_submitting) return;
                        setState(() => _submitting = true);
                        Navigator.pop(context, first);
                      }
                    : null,
                child: const Text('Create two rows'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
