import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../app/providers.dart';
import '../app/theme.dart';
import '../core/formatters.dart';
import '../core/input_limits.dart';
import '../core/platform/local_image.dart';
import '../core/split_bill.dart';
import 'home_shell.dart' show Frame;

class SplitBillsPage extends ConsumerWidget {
  const SplitBillsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bills = [...ref.watch(ledgerProvider).bills]
      ..sort((a, b) => b.billDate.compareTo(a.billDate));
    return Frame(
      title: 'Split bills',
      action: IconButton.filledTonal(
        tooltip: 'Add bill',
        icon: const Icon(Icons.add),
        onPressed: () => openBillEditor(context),
      ),
      child: bills.isEmpty
          ? _BillsEmpty(onAdd: () => openBillEditor(context))
          : ListView.separated(
              itemCount: bills.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, index) => _BillCard(bill: bills[index]),
            ),
    );
  }
}

class _BillsEmpty extends StatelessWidget {
  const _BillsEmpty({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Center(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/icon/icon.png', height: 74),
            const SizedBox(height: 14),
            Text(
              'Make the maths disappear',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add a restaurant bill, choose who shared each item, and send everyone a clear breakdown.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Create a bill'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _BillCard extends StatelessWidget {
  const _BillCard({required this.bill});
  final SplitBill bill;

  @override
  Widget build(BuildContext context) {
    final breakdown = calculateBill(bill);
    final payer = bill.participants
        .where((person) => person.id == bill.payerId)
        .map((person) => person.name)
        .firstOrNull;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => BillDetailPage(billId: bill.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: BalanceMateColors.gold.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.restaurant_rounded,
                  color: BalanceMateColors.gold,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bill.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${bill.participants.length} people · Paid by ${payer ?? 'Unknown'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatMoney(breakdown.total, bill.currencyCode),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    formatDate(bill.billDate),
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ),
              const SizedBox(width: 2),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class BillDetailPage extends ConsumerWidget {
  const BillDetailPage({super.key, required this.billId});
  final String billId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bill = ref
        .watch(ledgerProvider)
        .bills
        .where((item) => item.id == billId)
        .firstOrNull;
    if (bill == null) {
      return const Scaffold(body: Center(child: Text('Bill unavailable')));
    }
    final breakdown = calculateBill(bill);
    final payer = bill.participants
        .where((person) => person.id == bill.payerId)
        .map((person) => person.name)
        .firstOrNull;
    return Scaffold(
      appBar: AppBar(
        title: Text(bill.title),
        actions: [
          IconButton(
            tooltip: 'Share bill',
            onPressed: () => SharePlus.instance.share(
              ShareParams(text: billText(bill), subject: bill.title),
            ),
            icon: const Icon(Icons.ios_share_rounded),
          ),
          IconButton(
            tooltip: 'Edit bill',
            onPressed: () => openBillEditor(context, bill: bill),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Delete bill',
            onPressed: () => _delete(context, ref, bill),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _TotalHero(bill: bill, breakdown: breakdown, payer: payer),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 16),
              const SizedBox(width: 8),
              Text('Bill date: ${formatDate(bill.billDate)}'),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'Everyone’s share',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          for (final person in bill.participants) ...[
            _PersonShare(bill: bill, person: person, breakdown: breakdown),
            const SizedBox(height: 10),
          ],
          if (bill.note?.isNotEmpty ?? false) ...[
            const SizedBox(height: 12),
            Text('Note', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(bill.note!),
          ],
          if (bill.photoPath != null &&
              supportsLocalImageFiles &&
              localImageExists(bill.photoPath!)) ...[
            const SizedBox(height: 18),
            Text(
              'Receipt photo',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _showBillPhoto(context, bill.photoPath!),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  height: 190,
                  width: double.infinity,
                  child: LocalImage(path: bill.photoPath!),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    SplitBill bill,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this bill?'),
        content: const Text(
          'The saved bill and its breakdown will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(ledgerProvider.notifier).deleteBill(bill.id);
      if (context.mounted) Navigator.pop(context);
    }
  }
}

class _TotalHero extends StatelessWidget {
  const _TotalHero({required this.bill, required this.breakdown, this.payer});
  final SplitBill bill;
  final BillBreakdown breakdown;
  final String? payer;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      gradient: const LinearGradient(
        colors: [BalanceMateColors.navy, BalanceMateColors.cobalt],
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Total bill',
          style: TextStyle(color: Colors.white.withValues(alpha: .72)),
        ),
        Text(
          formatMoney(breakdown.total, bill.currencyCode),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Paid by ${payer ?? 'Unknown'}',
          style: const TextStyle(color: Colors.white),
        ),
        const Divider(height: 28, color: Colors.white24),
        Wrap(
          spacing: 18,
          runSpacing: 8,
          children: [
            _Charge('Items', breakdown.subtotal, bill.currencyCode),
            if (breakdown.service > 0)
              _Charge('Service', breakdown.service, bill.currencyCode),
            if (breakdown.vat > 0)
              _Charge('VAT', breakdown.vat, bill.currencyCode),
            if (breakdown.tip > 0)
              _Charge('Tip', breakdown.tip, bill.currencyCode),
          ],
        ),
      ],
    ),
  );
}

class _Charge extends StatelessWidget {
  const _Charge(this.label, this.amount, this.currency);
  final String label, currency;
  final int amount;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Colors.white70)),
      Text(
        formatMoney(amount, currency),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}

class _PersonShare extends StatelessWidget {
  const _PersonShare({
    required this.bill,
    required this.person,
    required this.breakdown,
  });
  final SplitBill bill;
  final BillParticipant person;
  final BillBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    final items = bill.items
        .where((item) => item.participantIds.contains(person.id))
        .toList();
    final isPayer = person.id == bill.payerId;
    final total = breakdown.shares[person.id] ?? 0;
    final itemAmount = breakdown.itemShares[person.id] ?? 0;
    final service = breakdown.serviceShares[person.id] ?? 0;
    final vat = breakdown.vatShares[person.id] ?? 0;
    final tip = breakdown.tipShares[person.id] ?? 0;
    final charges = service + vat;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Text(person.name.characters.first.toUpperCase()),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    person.name,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                Text(
                  formatMoney(total, bill.currencyCode),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
            if (isPayer) ...[const SizedBox(height: 8), const _PayerChip()],
            if (items.isNotEmpty) ...[
              const SizedBox(height: 14),
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.restaurant_menu_outlined, size: 16),
                      const SizedBox(width: 6),
                      Expanded(child: Text(item.name)),
                      Text(
                        '${formatMoney(item.amountMinor, bill.currencyCode)}'
                        '${item.participantIds.length > 1 ? ' ÷ ${item.participantIds.length}' : ''}',
                      ),
                    ],
                  ),
                ),
            ],
            const Divider(height: 24),
            Text(
              'Items ${formatMoney(itemAmount, bill.currencyCode)}'
              '${charges == 0 ? '' : ' · charges ${formatMoney(charges, bill.currencyCode)}'}'
              '${tip == 0 ? '' : ' · tip ${formatMoney(tip, bill.currencyCode)}'}',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _PayerChip extends StatelessWidget {
  const _PayerChip();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(99),
      color: BalanceMateColors.aqua.withValues(alpha: .18),
    ),
    child: const Text(
      'Paid the bill',
      style: TextStyle(fontWeight: FontWeight.w700),
    ),
  );
}

Future<void> openBillEditor(BuildContext context, {SplitBill? bill}) =>
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BillEditorPage(bill: bill)),
    );

class BillEditorPage extends ConsumerStatefulWidget {
  const BillEditorPage({super.key, this.bill});
  final SplitBill? bill;
  @override
  ConsumerState<BillEditorPage> createState() => _BillEditorPageState();
}

class _BillEditorPageState extends ConsumerState<BillEditorPage> {
  final _uuid = const Uuid();
  late final String _newBillId = _uuid.v4();
  late final TextEditingController _title;
  late final TextEditingController _tip;
  late final TextEditingController _vat;
  late final TextEditingController _service;
  late final TextEditingController _note;
  late final TextEditingController _newPersonName;
  late List<BillParticipant> _participants;
  late List<BillItem> _items;
  late String _currency;
  late String _payerId;
  late Set<String> _tipPeople;
  late ServiceChargeTiming _serviceTiming;
  late DateTime _billDate;
  String? _photoPath;
  var _isAddingPerson = false;
  var _isSaving = false;

  @override
  void initState() {
    super.initState();
    final bill = widget.bill;
    final now = _uuid.v4();
    _participants =
        bill?.participants ?? [BillParticipant(id: now, name: 'Me')];
    _items = bill?.items ?? [];
    _payerId = bill?.payerId ?? _participants.first.id;
    _currency =
        bill?.currencyCode ??
        ref.read(ledgerProvider).settings.defaultCurrencyCode;
    _tipPeople = {
      ...(bill?.tipParticipantIds ?? _participants.map((item) => item.id)),
    };
    _serviceTiming = bill?.serviceTiming ?? ServiceChargeTiming.beforeVat;
    _billDate = _dateOnly(bill?.billDate ?? DateTime.now());
    _photoPath = bill?.photoPath;
    if (!supportsLocalImageFiles ||
        _photoPath == null ||
        !localImageExists(_photoPath!)) {
      _photoPath = null;
    }
    _title = TextEditingController(text: bill?.title);
    _tip = TextEditingController(text: _displayMinor(bill?.tipMinor ?? 0));
    _vat = TextEditingController(text: _displayPercent(bill?.vatPercent ?? 0));
    _service = TextEditingController(
      text: _displayPercent(bill?.servicePercent ?? 0),
    );
    _note = TextEditingController(text: bill?.note);
    _newPersonName = TextEditingController();
  }

  @override
  void dispose() {
    _title.dispose();
    _tip.dispose();
    _vat.dispose();
    _service.dispose();
    _note.dispose();
    _newPersonName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.bill == null ? 'New split bill' : 'Edit split bill'),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : _save,
          child: Text(_isSaving ? 'Saving…' : 'Save'),
        ),
      ],
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            'Keep it flexible',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          const Text(
            'Start with names and items; service, VAT, and tip can be filled in later.',
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _title,
            textInputAction: TextInputAction.next,
            maxLength: InputLimits.billTitle,
            decoration: const InputDecoration(
              labelText: 'Bill name (optional)',
              prefixIcon: Icon(Icons.receipt_outlined),
            ),
          ),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today_outlined),
            title: const Text('Bill date'),
            subtitle: Text(formatDate(_billDate)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _billDate,
                firstDate: DateTime(1900),
                lastDate: DateTime(2100),
              );
              if (picked != null && mounted) {
                setState(() => _billDate = _dateOnly(picked));
              }
            },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _currency,
            decoration: const InputDecoration(
              labelText: 'Currency',
              prefixIcon: Icon(Icons.currency_exchange),
            ),
            items: currencies.keys
                .map(
                  (code) => DropdownMenuItem(
                    value: code,
                    child: Text(currencyLabel(code)),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _currency = value!),
          ),
          const SizedBox(height: 24),
          _SectionHeader(
            title: 'People',
            action: 'Add name',
            onTap: () => setState(() => _isAddingPerson = true),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                for (final person in _participants) _personTile(person),
                if (_isAddingPerson) _newPersonComposer(),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _SectionHeader(title: 'Items', action: 'Add item', onTap: _addItem),
          const SizedBox(height: 8),
          if (_items.isEmpty)
            _HintCard('No items yet. Add what was ordered and who shared it.')
          else
            Card(
              child: Column(
                children: [for (final item in _items) _itemTile(item)],
              ),
            ),
          const SizedBox(height: 24),
          Text(
            'Extras',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _tip,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [LengthLimitingTextInputFormatter(12)],
            decoration: const InputDecoration(
              labelText: 'Tip amount',
              prefixIcon: Icon(Icons.volunteer_activism_outlined),
            ),
          ),
          const SizedBox(height: 8),
          _PersonPicker(
            title: 'Split tip between',
            people: _participants,
            selected: _tipPeople,
            onChanged: (selected) => setState(() => _tipPeople = selected),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _service,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [LengthLimitingTextInputFormatter(6)],
                  decoration: const InputDecoration(labelText: 'Service %'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _vat,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [LengthLimitingTextInputFormatter(6)],
                  decoration: const InputDecoration(labelText: 'VAT %'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SegmentedButton<ServiceChargeTiming>(
            segments: const [
              ButtonSegment(
                value: ServiceChargeTiming.beforeVat,
                label: Text('Service before VAT'),
              ),
              ButtonSegment(
                value: ServiceChargeTiming.afterVat,
                label: Text('Service after VAT'),
              ),
            ],
            selected: {_serviceTiming},
            onSelectionChanged: (value) =>
                setState(() => _serviceTiming = value.first),
          ),
          const SizedBox(height: 20),
          Text(
            'Who paid?',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _payerId,
            items: _participants
                .map(
                  (person) => DropdownMenuItem(
                    value: person.id,
                    child: Text(person.name),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _payerId = value!),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _note,
            minLines: 2,
            maxLines: 4,
            maxLength: InputLimits.note,
            decoration: const InputDecoration(labelText: 'Note (optional)'),
          ),
          const SizedBox(height: 14),
          if (supportsLocalImageFiles)
            _BillPhotoAttachment(
              photoPath: _photoPath,
              onAdd: () async {
                final picked = await _pickBillPhoto(context);
                if (picked != null && mounted) {
                  setState(() => _photoPath = picked);
                }
              },
              onRemove: () => setState(() => _photoPath = null),
              onUnavailable: () => setState(() => _photoPath = null),
            )
          else
            const _BillPhotoUnavailable(),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: const Icon(Icons.check),
            label: Text(_isSaving ? 'Saving…' : 'Save split bill'),
          ),
        ],
      ),
    ),
  );

  Widget _personTile(BillParticipant person) => ListTile(
    leading: CircleAvatar(
      child: Text(person.name.characters.first.toUpperCase()),
    ),
    title: Text(person.name),
    subtitle: person.id == _payerId ? const Text('Pays the bill') : null,
    trailing: _participants.length == 1
        ? null
        : IconButton(
            tooltip: 'Remove ${person.name}',
            onPressed: () => setState(() {
              _participants = _participants
                  .where((item) => item.id != person.id)
                  .toList();
              _items = _items
                  .map(
                    (item) => BillItem(
                      id: item.id,
                      name: item.name,
                      amountMinor: item.amountMinor,
                      participantIds: item.participantIds
                          .where((id) => id != person.id)
                          .toList(),
                    ),
                  )
                  .toList();
              _tipPeople.remove(person.id);
              if (_payerId == person.id) _payerId = _participants.first.id;
            }),
            icon: const Icon(Icons.close),
          ),
  );

  Widget _itemTile(BillItem item) => ListTile(
    onTap: () => _addItem(existing: item),
    leading: const Icon(Icons.restaurant_menu_outlined),
    title: Text(item.name),
    subtitle: Text(
      '${formatMoney(item.amountMinor, _currency)} · ${_namesFor(item.participantIds)}',
    ),
    trailing: IconButton(
      tooltip: 'Remove ${item.name}',
      icon: const Icon(Icons.delete_outline),
      onPressed: () => setState(
        () => _items = _items.where((entry) => entry.id != item.id).toList(),
      ),
    ),
  );

  Widget _newPersonComposer() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 12, 12),
    child: Row(
      children: [
        Expanded(
          child: TextField(
            controller: _newPersonName,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            maxLength: InputLimits.name,
            onSubmitted: (_) => _commitNewPerson(),
            decoration: const InputDecoration(
              hintText: 'Add a name',
              isDense: true,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Add name',
          onPressed: _commitNewPerson,
          icon: const Icon(Icons.check),
        ),
        IconButton(
          tooltip: 'Cancel',
          onPressed: () => setState(() {
            _newPersonName.clear();
            _isAddingPerson = false;
          }),
          icon: const Icon(Icons.close),
        ),
      ],
    ),
  );

  void _commitNewPerson() {
    final name = _newPersonName.text.trim();
    if (name.isEmpty) return;
    if (_participants.length >= InputLimits.maxBillParticipants) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A bill can include up to 50 people.')),
      );
      return;
    }
    setState(() {
      final person = BillParticipant(id: _uuid.v4(), name: name);
      _participants = [..._participants, person];
      _tipPeople.add(person.id);
      _newPersonName.clear();
      _isAddingPerson = false;
    });
  }

  Future<void> _addItem({BillItem? existing}) async {
    if (existing == null && _items.length >= InputLimits.maxBillItems) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A bill can contain up to 100 items.')),
      );
      return;
    }
    final draft = await showModalBottomSheet<_ItemDraft>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          _ItemEditorSheet(existing: existing, participants: _participants),
    );
    if (draft != null && mounted) {
      setState(() {
        final item = BillItem(
          id: existing?.id ?? _uuid.v4(),
          name: draft.name,
          amountMinor: draft.amountMinor,
          participantIds: draft.participantIds,
        );
        _items = [..._items.where((entry) => entry.id != item.id), item];
      });
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;
    final tip = _tip.text.trim().isEmpty ? 0 : _minorAllowZero(_tip.text);
    final vat = _percent(_vat.text);
    final service = _percent(_service.text);
    if (tip == null ||
        vat == null ||
        service == null ||
        _participants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Check the amount and percentage fields.'),
        ),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      await ref
          .read(ledgerProvider.notifier)
          .saveBill(
            existing: widget.bill,
            newId: _newBillId,
            title: _title.text,
            currencyCode: _currency,
            participants: _participants,
            items: _items,
            payerId: _payerId,
            billDate: _billDate,
            tipMinor: tip,
            tipParticipantIds: _tipPeople.toList(),
            vatPercent: vat,
            servicePercent: service,
            serviceTiming: _serviceTiming,
            note: _note.text,
            photoPath: _photoPath,
          );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save the bill. Please try again.'),
        ),
      );
    }
  }

  String _namesFor(List<String> ids) => _participants
      .where((person) => ids.contains(person.id))
      .map((person) => person.name)
      .join(', ');
}

class _BillPhotoAttachment extends StatelessWidget {
  const _BillPhotoAttachment({
    required this.photoPath,
    required this.onAdd,
    required this.onRemove,
    required this.onUnavailable,
  });
  final String? photoPath;
  final Future<void> Function() onAdd;
  final VoidCallback onRemove;
  final VoidCallback onUnavailable;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Receipt photo',
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 4),
      const Text(
        'Stored on this device only. It is not uploaded, synced, or included in backups.',
      ),
      const SizedBox(height: 10),
      if (photoPath == null)
        OutlinedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: const Text('Choose a photo'),
        )
      else ...[
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showBillPhoto(context, photoPath!),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 160,
              width: double.infinity,
              child: LocalImage(path: photoPath!, onUnavailable: onUnavailable),
            ),
          ),
        ),
        Row(
          children: [
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.swap_horiz_rounded),
              label: const Text('Change'),
            ),
            TextButton.icon(
              onPressed: onRemove,
              icon: const Icon(Icons.remove_circle_outline),
              label: const Text('Remove'),
            ),
          ],
        ),
      ],
    ],
  );
}

class _BillPhotoUnavailable extends StatelessWidget {
  const _BillPhotoUnavailable();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: BalanceMateColors.aqua.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Text(
      'Receipt photos are available in the installed app. Browser file locations cannot be stored safely.',
    ),
  );
}

Future<String?> _pickBillPhoto(BuildContext context) async {
  final file = await FilePicker.pickFile(type: FileType.image);
  if (file == null) return null;
  final path = file.path;
  if (path == null || !localImageExists(path)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('That photo could not be accessed locally.'),
        ),
      );
    }
    return null;
  }
  return path;
}

Future<void> _showBillPhoto(BuildContext context, String path) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 560,
        height: 620,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                minScale: .8,
                maxScale: 4,
                child: LocalImage(path: path, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filledTonal(
                tooltip: 'Close photo',
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ItemDraft {
  const _ItemDraft({
    required this.name,
    required this.amountMinor,
    required this.participantIds,
  });
  final String name;
  final int amountMinor;
  final List<String> participantIds;
}

class _ItemEditorSheet extends StatefulWidget {
  const _ItemEditorSheet({required this.existing, required this.participants});
  final BillItem? existing;
  final List<BillParticipant> participants;

  @override
  State<_ItemEditorSheet> createState() => _ItemEditorSheetState();
}

class _ItemEditorSheetState extends State<_ItemEditorSheet> {
  late final TextEditingController _name;
  late final TextEditingController _amount;
  late Set<String> _people;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?.name);
    _amount = TextEditingController(
      text: widget.existing == null
          ? ''
          : _displayMinor(widget.existing!.amountMinor),
    );
    _people = {...(widget.existing?.participantIds ?? const <String>[])}
        .where((id) => widget.participants.any((person) => person.id == id))
        .toSet();
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
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
            widget.existing == null ? 'Add item' : 'Edit item',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            autofocus: true,
            textInputAction: TextInputAction.next,
            maxLength: InputLimits.itemName,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'What was ordered?'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [LengthLimitingTextInputFormatter(12)],
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Price'),
          ),
          const SizedBox(height: 16),
          const Text(
            'Who shares this item?',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          for (final person in widget.participants)
            CheckboxListTile(
              value: _people.contains(person.id),
              title: Text(person.name),
              onChanged: (checked) => setState(() {
                checked == true
                    ? _people.add(person.id)
                    : _people.remove(person.id);
              }),
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _canSubmit ? _submit : null,
            child: const Text('Save item'),
          ),
        ],
      ),
    ),
  );

  bool get _canSubmit =>
      _name.text.trim().isNotEmpty &&
      _minor(_amount.text) != null &&
      _people.isNotEmpty;

  void _submit() {
    final amount = _minor(_amount.text);
    final name = _name.text.trim();
    if (name.isEmpty || amount == null || _people.isEmpty) return;
    Navigator.pop(
      context,
      _ItemDraft(
        name: name,
        amountMinor: amount,
        participantIds: _people.toList(),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.action,
    required this.onTap,
  });
  final String title, action;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
      ),
      TextButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.add, size: 18),
        label: Text(action),
      ),
    ],
  );
}

class _HintCard extends StatelessWidget {
  const _HintCard(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(padding: const EdgeInsets.all(18), child: Text(text)),
  );
}

class _PersonPicker extends StatelessWidget {
  const _PersonPicker({
    required this.title,
    required this.people,
    required this.selected,
    required this.onChanged,
  });
  final String title;
  final List<BillParticipant> people;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final person in people)
                FilterChip(
                  label: Text(person.name),
                  selected: selected.contains(person.id),
                  onSelected: (value) {
                    final next = {...selected};
                    value ? next.add(person.id) : next.remove(person.id);
                    onChanged(next);
                  },
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

int? _minor(String value) {
  final result = _minorAllowZero(value);
  return result != null && result > 0 ? result : null;
}

int? _minorAllowZero(String value) {
  final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(value.trim());
  if (match == null) return null;
  final result =
      int.parse(match.group(1)!) * 100 +
      int.parse((match.group(2) ?? '').padRight(2, '0'));
  return result <= InputLimits.maxAmountMinor ? result : null;
}

double? _percent(String value) {
  if (value.trim().isEmpty) return 0;
  final parsed = double.tryParse(value.trim());
  return parsed == null ||
          !parsed.isFinite ||
          parsed < 0 ||
          parsed > InputLimits.maxPercent
      ? null
      : parsed;
}

String _displayMinor(int amount) =>
    amount == 0 ? '' : (amount / 100).toStringAsFixed(2);
String _displayPercent(double value) => value == 0 ? '' : value.toString();

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
