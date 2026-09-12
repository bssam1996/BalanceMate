import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../app/providers.dart';
import '../app/theme.dart';
import '../core/formatters.dart';
import '../core/ledger_calculator.dart';
import '../core/input_limits.dart';
import '../core/models.dart';
import '../core/platform/exporter.dart';
import '../core/platform/local_image.dart';
import 'profile_page.dart';
import 'split_bills_page.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});
  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int tab = 0;
  static const tabs = [
    (Icons.space_dashboard_rounded, 'Overview'),
    (Icons.people_alt_rounded, 'People'),
    (Icons.receipt_long_rounded, 'Activity'),
    (Icons.group_work_rounded, 'Split bills'),
    (Icons.tune_rounded, 'Settings'),
  ];
  @override
  Widget build(BuildContext context) {
    final pages = [
      const Dashboard(),
      const People(),
      const Activity(),
      const SplitBillsPage(),
      const Settings(),
    ];
    return LayoutBuilder(
      builder: (context, size) {
        final wide = size.maxWidth >= 840;
        final body = pages[tab];
        final primaryAction = switch (tab) {
          0 || 2 => (
            label: 'Add entry',
            icon: Icons.add,
            onPressed: () => editTransaction(context, ref),
          ),
          1 => (
            label: 'Add person',
            icon: Icons.person_add_alt_1,
            onPressed: () => editPerson(context, ref),
          ),
          3 => (
            label: 'Add bill',
            icon: Icons.receipt_long_outlined,
            onPressed: () => openBillEditor(context),
          ),
          _ => null,
        };
        return Scaffold(
          floatingActionButton: primaryAction == null
              ? null
              : FloatingActionButton.extended(
                  onPressed: primaryAction.onPressed,
                  icon: Icon(primaryAction.icon),
                  label: Text(primaryAction.label),
                ),
          floatingActionButtonLocation: wide
              ? FloatingActionButtonLocation.endFloat
              : FloatingActionButtonLocation.centerFloat,
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: tab,
                  onDestinationSelected: (v) => setState(() => tab = v),
                  destinations: [
                    for (final x in tabs)
                      NavigationDestination(icon: Icon(x.$1), label: x.$2),
                  ],
                ),
          body: wide
              ? SafeArea(
                  child: Row(
                    children: [
                      NavigationRail(
                        selectedIndex: tab,
                        onDestinationSelected: (v) => setState(() => tab = v),
                        labelType: NavigationRailLabelType.all,
                        leading: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Image.asset('assets/icon/icon.png', width: 52),
                        ),
                        destinations: [
                          for (final x in tabs)
                            NavigationRailDestination(
                              icon: Icon(x.$1),
                              label: Text(x.$2),
                            ),
                        ],
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: body),
                    ],
                  ),
                )
              : SafeArea(child: body),
        );
      },
    );
  }
}

class Frame extends StatelessWidget {
  const Frame({
    super.key,
    required this.title,
    required this.child,
    this.action,
  });
  final String title;
  final Widget child;
  final Widget? action;
  @override
  Widget build(BuildContext c) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(c).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (action != null) action!,
          ],
        ),
        const SizedBox(height: 18),
        Expanded(child: child),
      ],
    ),
  );
}

class Dashboard extends ConsumerWidget {
  const Dashboard({super.key});
  @override
  Widget build(BuildContext c, WidgetRef r) {
    final s = r.watch(ledgerProvider);
    final b = balancesFor(s.transactions);
    final n = {for (final p in s.people) p.id: p.name};
    final ts = [...s.transactions]
      ..sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
    return Frame(
      title: 'Your balance',
      action: IconButton.filledTonal(
        onPressed: () => editPerson(c, r),
        icon: const Icon(Icons.person_add_alt_1),
      ),
      child: ListView(
        children: [
          Text(
            'A clear view of every promise and repayment.',
            style: Theme.of(c).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          if (b.isEmpty)
            Empty(on: () => editPerson(c, r), title: 'Nothing to balance yet')
          else ...[
            for (final e in b.entries) ...[
              HeroBalance(code: e.key, balance: e.value),
              const SizedBox(height: 14),
            ],
            const Text(
              'Recent activity',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  for (final t in ts.take(5))
                    Tile(t: t, name: n[t.personId] ?? 'Unknown person'),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class HeroBalance extends StatelessWidget {
  const HeroBalance({super.key, required this.code, required this.balance});
  final String code;
  final CurrencyBalance balance;
  @override
  Widget build(BuildContext c) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      gradient: const LinearGradient(
        colors: [
          BalanceMateColors.navy,
          BalanceMateColors.cobalt,
          BalanceMateColors.aqua,
        ],
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          code,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          balance.net == 0
              ? 'All settled up'
              : balance.net > 0
              ? 'Net in your favour'
              : 'Net to repay',
          style: TextStyle(color: Colors.white.withValues(alpha: .75)),
        ),
        Text(
          formatMoney(balance.net.abs(), code),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _amount(
                'Owed to you',
                balance.owedToMe,
                code,
                BalanceMateColors.aqua,
              ),
            ),
            Expanded(
              child: _amount(
                'You owe',
                balance.iOwe,
                code,
                BalanceMateColors.gold,
              ),
            ),
          ],
        ),
      ],
    ),
  );
  Widget _amount(String l, int a, String c, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(l, style: const TextStyle(color: Colors.white70)),
      Text(
        formatMoney(a, c),
        style: TextStyle(color: color, fontWeight: FontWeight.w900),
      ),
    ],
  );
}

class People extends ConsumerStatefulWidget {
  const People({super.key});
  @override
  ConsumerState<People> createState() => _PeopleState();
}

class _PeopleState extends ConsumerState<People> {
  String q = '';
  bool archived = false;
  @override
  Widget build(BuildContext c) {
    final s = ref.watch(ledgerProvider);
    final people = s.people
        .where(
          (p) =>
              p.isArchived == archived &&
              p.name.toLowerCase().contains(q.toLowerCase()),
        )
        .toList();
    return Frame(
      title: 'People',
      action: IconButton.filledTonal(
        onPressed: () => editPerson(c, ref),
        icon: const Icon(Icons.person_add_alt_1),
      ),
      child: Column(
        children: [
          TextField(
            onChanged: (v) => setState(() => q = v),
            maxLength: 100,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search people',
            ),
          ),
          const SizedBox(height: 10),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Active')),
              ButtonSegment(value: true, label: Text('Archived')),
            ],
            selected: {archived},
            onSelectionChanged: (v) => setState(() => archived = v.first),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: people.isEmpty
                ? Empty(
                    on: archived ? null : () => editPerson(c, ref),
                    title: archived
                        ? 'No archived people'
                        : 'Your circle is empty',
                  )
                : ListView.separated(
                    itemCount: people.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (c, i) {
                      final p = people[i];
                      final b = balancesForPerson(p.id, s.transactions);
                      return Card(
                        child: ListTile(
                          onTap: () => detail(c, p.id),
                          leading: CircleAvatar(
                            child: Text(p.name[0].toUpperCase()),
                          ),
                          title: Text(
                            p.name,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            b.entries
                                .map(
                                  (e) =>
                                      '${e.value.net >= 0 ? 'Owes you' : 'You owe'} ${formatMoney(e.value.net.abs(), e.key)}',
                                )
                                .join(' · ')
                                .ifEmpty('All settled up'),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void detail(BuildContext c, String id) => Navigator.push(
    c,
    MaterialPageRoute(builder: (_) => PersonDetail(id: id)),
  );
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

enum _ActivityPeriod { all, last30Days, thisYear, custom }

class Activity extends ConsumerStatefulWidget {
  const Activity({super.key});

  @override
  ConsumerState<Activity> createState() => _ActivityState();
}

class _ActivityState extends ConsumerState<Activity> {
  String? _personId;
  TransactionKind? _kind;
  _ActivityPeriod _period = _ActivityPeriod.all;
  DateTime? _customStart;
  DateTime? _customEnd;

  @override
  Widget build(BuildContext c) {
    final s = ref.watch(ledgerProvider);
    final today = _dateOnly(DateTime.now());
    final ts = s.transactions.where((transaction) {
      final date = _dateOnly(transaction.transactionDate);
      final meetsPeriod = switch (_period) {
        _ActivityPeriod.all => true,
        _ActivityPeriod.last30Days => !date.isBefore(
          today.subtract(const Duration(days: 30)),
        ),
        _ActivityPeriod.thisYear => date.year == today.year,
        _ActivityPeriod.custom =>
          _customStart != null &&
              _customEnd != null &&
              !date.isBefore(_dateOnly(_customStart!)) &&
              !date.isAfter(_dateOnly(_customEnd!)),
      };
      return meetsPeriod &&
          (_personId == null || transaction.personId == _personId) &&
          (_kind == null || transaction.kind == _kind);
    }).toList()..sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
    final n = {for (final p in s.people) p.id: p.name};
    final hasFilters =
        _personId != null || _kind != null || _period != _ActivityPeriod.all;
    return Frame(
      title: 'Activity',
      action: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton.filledTonal(
            tooltip: 'Filter activity',
            onPressed: () => _showFilters(c, s),
            icon: const Icon(Icons.tune_rounded),
          ),
          if (hasFilters)
            Positioned(
              right: -1,
              top: -1,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: BalanceMateColors.gold,
                  shape: BoxShape.circle,
                  border: Border.all(color: Theme.of(c).colorScheme.surface),
                ),
              ),
            ),
        ],
      ),
      child: s.transactions.isEmpty
          ? Empty(
              on: () => editTransaction(c, ref),
              title: 'Your ledger is ready',
            )
          : ts.isEmpty
          ? _NoFilteredActivity(onClear: _clearFilters)
          : ListView(
              children: [
                if (hasFilters) ...[
                  _FilterSummary(label: _filterLabel(s)),
                  const SizedBox(height: 12),
                ],
                _ActivityReport(transactions: ts),
                const SizedBox(height: 18),
                Text(
                  'Transactions',
                  style: Theme.of(
                    c,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                for (final t in ts) ...[
                  Card(
                    child: Tile(
                      t: t,
                      name: n[t.personId] ?? 'Unknown person',
                      on: () => editTransaction(c, ref, t: t),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }

  String _filterLabel(LedgerSnapshot snapshot) {
    final parts = <String>[
      switch (_period) {
        _ActivityPeriod.all => 'All time',
        _ActivityPeriod.last30Days => 'Last 30 days',
        _ActivityPeriod.thisYear => 'This year',
        _ActivityPeriod.custom =>
          '${formatDate(_customStart!)} to ${formatDate(_customEnd!)}',
      },
      if (_personId != null)
        snapshot.people
                .where((person) => person.id == _personId)
                .map((person) => person.name)
                .firstOrNull ??
            'Selected person',
      if (_kind != null) label(_kind!),
    ];
    return parts.join(' · ');
  }

  void _clearFilters() => setState(() {
    _personId = null;
    _kind = null;
    _period = _ActivityPeriod.all;
    _customStart = null;
    _customEnd = null;
  });

  Future<void> _showFilters(
    BuildContext context,
    LedgerSnapshot snapshot,
  ) async {
    var nextPersonId = _personId;
    var nextKind = _kind;
    var nextPeriod = _period;
    var nextStart = _customStart;
    var nextEnd = _customEnd;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (_, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Filter activity',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text('Focus your report without changing your ledger.'),
              const SizedBox(height: 20),
              DropdownButtonFormField<_ActivityPeriod>(
                initialValue: nextPeriod,
                decoration: const InputDecoration(labelText: 'Time period'),
                items: const [
                  DropdownMenuItem(
                    value: _ActivityPeriod.all,
                    child: Text('All time'),
                  ),
                  DropdownMenuItem(
                    value: _ActivityPeriod.last30Days,
                    child: Text('Last 30 days'),
                  ),
                  DropdownMenuItem(
                    value: _ActivityPeriod.thisYear,
                    child: Text('This year'),
                  ),
                  DropdownMenuItem(
                    value: _ActivityPeriod.custom,
                    child: Text('Custom date range'),
                  ),
                ],
                onChanged: (value) => setSheetState(() {
                  nextPeriod = value!;
                  if (nextPeriod == _ActivityPeriod.custom) {
                    nextEnd ??= _dateOnly(DateTime.now());
                    nextStart ??= nextEnd!.subtract(const Duration(days: 30));
                  }
                }),
              ),
              if (nextPeriod == _ActivityPeriod.custom) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _DateFilterTile(
                        label: 'From',
                        date: nextStart!,
                        onPick: (date) => setSheetState(() => nextStart = date),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DateFilterTile(
                        label: 'To',
                        date: nextEnd!,
                        onPick: (date) => setSheetState(() => nextEnd = date),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: nextPersonId ?? '',
                decoration: const InputDecoration(labelText: 'Person'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Everyone')),
                  ...snapshot.people.map(
                    (person) => DropdownMenuItem(
                      value: person.id,
                      child: Text(person.name, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: (value) => setSheetState(
                  () => nextPersonId = value!.isEmpty ? null : value,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: nextKind?.name ?? '',
                decoration: const InputDecoration(labelText: 'Entry type'),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('All activity'),
                  ),
                  ...TransactionKind.values.map(
                    (kind) => DropdownMenuItem(
                      value: kind.name,
                      child: Text(label(kind)),
                    ),
                  ),
                ],
                onChanged: (value) => setSheetState(
                  () => nextKind = value!.isEmpty
                      ? null
                      : TransactionKind.values.byName(value),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  TextButton(
                    onPressed: () => setSheetState(() {
                      nextPersonId = null;
                      nextKind = null;
                      nextPeriod = _ActivityPeriod.all;
                      nextStart = null;
                      nextEnd = null;
                    }),
                    child: const Text('Reset'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: () {
                      if (nextPeriod == _ActivityPeriod.custom &&
                          nextEnd!.isBefore(nextStart!)) {
                        ScaffoldMessenger.of(sheetContext).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'The end date must be on or after the start date.',
                            ),
                          ),
                        );
                        return;
                      }
                      setState(() {
                        _personId = nextPersonId;
                        _kind = nextKind;
                        _period = nextPeriod;
                        _customStart = nextPeriod == _ActivityPeriod.custom
                            ? _dateOnly(nextStart!)
                            : null;
                        _customEnd = nextPeriod == _ActivityPeriod.custom
                            ? _dateOnly(nextEnd!)
                            : null;
                      });
                      Navigator.pop(sheetContext);
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Apply filters'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateFilterTile extends StatelessWidget {
  const _DateFilterTile({
    required this.label,
    required this.date,
    required this.onPick,
  });
  final String label;
  final DateTime date;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    style: OutlinedButton.styleFrom(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    ),
    onPressed: () async {
      final picked = await showDatePicker(
        context: context,
        initialDate: date,
        firstDate: DateTime(1900),
        lastDate: DateTime(2100),
      );
      if (picked != null) onPick(_dateOnly(picked));
    },
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 3),
        Text(formatDate(date)),
      ],
    ),
  );
}

class _ActivityReport extends StatelessWidget {
  const _ActivityReport({required this.transactions});
  final List<LedgerTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    final balances = balancesFor(transactions);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'At a glance',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        for (final entry in balances.entries) ...[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                colors: [BalanceMateColors.navy, BalanceMateColors.cobalt],
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.insights_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.value.net >= 0
                            ? 'Net change in your favour'
                            : 'Net change to repay',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      Text(
                        formatMoney(entry.value.net.abs(), entry.key),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${transactions.where((item) => item.currencyCode == entry.key).length} entries',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _FilterSummary extends StatelessWidget {
  const _FilterSummary({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: BalanceMateColors.aqua.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        const Icon(Icons.filter_alt_outlined, color: BalanceMateColors.cobalt),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    ),
  );
}

class _NoFilteredActivity extends StatelessWidget {
  const _NoFilteredActivity({required this.onClear});
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => SizedBox.expand(
    child: Card(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.filter_alt_off_outlined,
                size: 44,
                color: BalanceMateColors.cobalt,
              ),
              const SizedBox(height: 12),
              Text(
                'Nothing matches these filters',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text(
                'Try a wider date range or clear the filters.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: onClear,
                child: const Text('Clear filters'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class Settings extends ConsumerWidget {
  const Settings({super.key});
  @override
  Widget build(BuildContext c, WidgetRef r) {
    final s = r.watch(ledgerProvider);
    final ctl = r.read(ledgerProvider.notifier);
    return Frame(
      title: 'Settings',
      child: ListView(
        children: [
          const Text(
            'Account',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: const Text('Profile & cloud backup'),
              subtitle: const Text('Sign in with Google to sync your ledger'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                c,
                MaterialPageRoute(builder: (_) => const ProfilePage()),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Appearance',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          Card(
            child: Column(
              children: [
                for (final m in ThemeMode.values)
                  RadioListTile(
                    value: m,
                    groupValue: s.settings.themeMode,
                    onChanged: (v) => ctl.updateTheme(v!),
                    title: Text(
                      m.name == 'system'
                          ? 'Use device setting'
                          : m.name[0].toUpperCase() + m.name.substring(1),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Default currency',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField(
            initialValue: s.settings.defaultCurrencyCode,
            items: currencies.keys
                .map(
                  (code) => DropdownMenuItem(
                    value: code,
                    child: Text(currencyLabel(code)),
                  ),
                )
                .toList(),
            onChanged: (v) => ctl.updateDefaultCurrency(v!),
          ),
          const SizedBox(height: 20),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.ios_share),
                  title: const Text('Export backup'),
                  subtitle: const Text(
                    'Save a private JSON copy of your ledger',
                  ),
                  onTap: () async {
                    await exportJson(
                      s.toExportJson(),
                      'balancemate-export.json',
                    );
                    if (c.mounted)
                      ScaffoldMessenger.of(c).showSnackBar(
                        const SnackBar(content: Text('Your export is ready.')),
                      );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.restore_page_outlined),
                  title: const Text('Restore backup'),
                  subtitle: const Text(
                    'Replace this ledger from a JSON backup',
                  ),
                  onTap: () => _restoreBackup(c, r),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.delete_forever,
                    color: Theme.of(c).colorScheme.error,
                  ),
                  title: const Text('Clear all data'),
                  subtitle: const Text('Remove this device and cloud backup'),
                  onTap: () async {
                    final ok = await showDialog<bool>(
                      context: c,
                      builder: (x) => AlertDialog(
                        title: const Text('Clear all data?'),
                        content: const Text(
                          'This permanently removes your ledger and profile data from this device and, when signed in, from the cloud.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(x),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(x, true),
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) await ctl.clearAll();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _restoreBackup(BuildContext context, WidgetRef ref) async {
  try {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (picked.isEmpty) return;
    final file = picked.single;
    if (await file.length() > 5 * 1024 * 1024) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose a backup smaller than 5 MB.')),
        );
      }
      return;
    }
    final backup = LedgerSnapshot.fromExportJson(
      utf8.decode(await file.readAsBytes(), allowMalformed: false),
    );
    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.restore_page_outlined),
        title: const Text('Restore this backup?'),
        content: Text(
          '${backup.people.length} people, ${backup.transactions.length} entries, and ${backup.bills.length} split bills will replace the data currently on this device. This cannot be undone unless you export first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.restore),
            label: const Text('Restore backup'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(ledgerProvider.notifier).restoreBackup(backup);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup restored successfully.')),
      );
    }
  } on FormatException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not restore this backup: ${error.message}'),
        ),
      );
    }
  } on ArgumentError {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This backup contains invalid or unsupported records.'),
        ),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read that backup file.')),
      );
    }
  }
}

class PersonDetail extends ConsumerWidget {
  const PersonDetail({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext c, WidgetRef r) {
    final s = r.watch(ledgerProvider);
    final ps = s.people.where((p) => p.id == id).toList();
    if (ps.isEmpty)
      return const Scaffold(body: Center(child: Text('Person unavailable')));
    final p = ps.first;
    final ts = s.transactions.where((t) => t.personId == id).toList()
      ..sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
    final balances = balancesFor(ts);
    return Scaffold(
      appBar: AppBar(
        title: Text(p.name),
        actions: [
          IconButton(
            onPressed: () => editPerson(c, r, p: p),
            icon: const Icon(Icons.edit),
          ),
          PopupMenuButton(
            onSelected: (bool v) =>
                r.read(ledgerProvider.notifier).setPersonArchived(p, v),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: !p.isArchived,
                child: Text(p.isArchived ? 'Unarchive' : 'Archive'),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => editTransaction(c, r, personId: id),
        label: const Text('Add entry'),
        icon: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          for (final e in balances.entries) ...[
            HeroBalance(code: e.key, balance: e.value),
            if (e.value.net != 0) ...[
              const SizedBox(height: 8),
              _SettleUpButton(
                balance: e.value,
                currencyCode: e.key,
                onPressed: () => settlePersonBalance(
                  c,
                  r,
                  person: p,
                  currencyCode: e.key,
                  balance: e.value,
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],
          const Text(
            'Ledger',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          if (ts.isEmpty)
            Empty(
              on: () => editTransaction(c, r, personId: id),
              title: 'No entries yet',
            )
          else
            Card(
              child: Column(
                children: [
                  for (final t in ts)
                    Tile(
                      t: t,
                      name: p.name,
                      on: () => editTransaction(c, r, t: t),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SettleUpButton extends StatelessWidget {
  const _SettleUpButton({
    required this.balance,
    required this.currencyCode,
    required this.onPressed,
  });
  final CurrencyBalance balance;
  final String currencyCode;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theyOwe = balance.net > 0;
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 18),
        foregroundColor: Theme.of(context).colorScheme.primary,
        side: BorderSide(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: .65),
        ),
      ),
      onPressed: onPressed,
      icon: Icon(
        theyOwe
            ? Icons.payments_outlined
            : Icons.account_balance_wallet_outlined,
      ),
      label: Text(
        theyOwe
            ? 'Record payment of ${formatMoney(balance.net, currencyCode)}'
            : 'Record repayment of ${formatMoney(-balance.net, currencyCode)}',
      ),
    );
  }
}

Future<void> settlePersonBalance(
  BuildContext context,
  WidgetRef ref, {
  required Person person,
  required String currencyCode,
  required CurrencyBalance balance,
}) async {
  final amount = TextEditingController(
    text: (balance.net.abs() / 100).toStringAsFixed(2),
  );
  final note = TextEditingController(text: 'Settlement');
  var date = _dateOnly(DateTime.now());
  final theyOwe = balance.net > 0;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (_, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          MediaQuery.viewInsetsOf(sheetContext).bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                theyOwe ? 'Record a payment' : 'Record a repayment',
                style: Theme.of(sheetContext).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                theyOwe
                    ? '${person.name} owes you ${formatMoney(balance.net, currencyCode)}.'
                    : 'You owe ${person.name} ${formatMoney(-balance.net, currencyCode)}.',
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: BalanceMateColors.aqua.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome_rounded,
                      color: BalanceMateColors.cobalt,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'The full outstanding amount is filled in. Change it to record a partial payment.',
                        style: Theme.of(sheetContext).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [LengthLimitingTextInputFormatter(12)],
                decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixIcon: const Icon(Icons.payments_outlined),
                  suffixText: currencyCode,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('Payment date'),
                subtitle: Text(formatDate(date)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: sheetContext,
                    initialDate: date,
                    firstDate: DateTime(1900),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setSheetState(() => date = picked);
                },
              ),
              TextField(
                controller: note,
                maxLength: InputLimits.note,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(17),
                ),
                onPressed: () async {
                  final value = _minor(amount.text);
                  if (value == null) {
                    ScaffoldMessenger.of(sheetContext).showSnackBar(
                      const SnackBar(
                        content: Text('Enter a valid payment amount.'),
                      ),
                    );
                    return;
                  }
                  if (value > balance.net.abs()) {
                    ScaffoldMessenger.of(sheetContext).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'A settlement cannot exceed the outstanding balance.',
                        ),
                      ),
                    );
                    return;
                  }
                  await ref
                      .read(ledgerProvider.notifier)
                      .saveTransaction(
                        personId: person.id,
                        kind: theyOwe
                            ? TransactionKind.repaymentReceived
                            : TransactionKind.repaymentMade,
                        amountMinor: value,
                        currencyCode: currencyCode,
                        transactionDate: date,
                        note: note.text,
                      );
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Settlement recorded.')),
                    );
                  }
                },
                icon: const Icon(Icons.check_circle_outline),
                label: Text(theyOwe ? 'Record payment' : 'Record repayment'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  amount.dispose();
  note.dispose();
}

class Tile extends StatelessWidget {
  const Tile({super.key, required this.t, required this.name, this.on});
  final LedgerTransaction t;
  final String name;
  final VoidCallback? on;
  @override
  Widget build(BuildContext c) {
    final plus = t.balanceEffectMinor >= 0;
    return ListTile(
      onTap: on,
      leading: CircleAvatar(
        backgroundColor:
            (plus ? BalanceMateColors.aqua : BalanceMateColors.gold).withValues(
              alpha: .2,
            ),
        child: Icon(plus ? Icons.north_east : Icons.south_west),
      ),
      title: Text(
        label(t.kind),
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(
        '$name · ${formatDate(t.transactionDate)}${t.dueDate == null ? '' : ' · ${isOverdue(t, DateTime.now()) ? 'Overdue' : 'Due'} ${formatDate(t.dueDate!)}'}',
      ),
      trailing: Text(
        '${plus ? '+' : '−'}${formatMoney(t.amountMinor, t.currencyCode)}',
        style: TextStyle(
          fontWeight: FontWeight.w900,
          color: plus
              ? Theme.of(c).colorScheme.primary
              : Theme.of(c).colorScheme.error,
        ),
      ),
    );
  }
}

class _LocalPhotoAttachment extends StatelessWidget {
  const _LocalPhotoAttachment({
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
        'Photo attachment',
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
          onTap: () => showLocalPhotoViewer(context, photoPath!),
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

class _LocalPhotoUnavailable extends StatelessWidget {
  const _LocalPhotoUnavailable();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: BalanceMateColors.aqua.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Text(
      'Photo attachments are available in the installed app. Browser file locations cannot be stored safely.',
    ),
  );
}

Future<String?> _pickLocalPhoto(BuildContext context) async {
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

Future<void> showLocalPhotoViewer(BuildContext context, String path) async {
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

String label(TransactionKind k) => switch (k) {
  TransactionKind.lent => 'You lent money',
  TransactionKind.borrowed => 'You borrowed money',
  TransactionKind.repaymentReceived => 'Repayment received',
  TransactionKind.repaymentMade => 'Repayment made',
  TransactionKind.adjustment => 'Balance adjustment',
};

class Empty extends StatelessWidget {
  const Empty({super.key, required this.on, required this.title});
  final VoidCallback? on;
  final String title;
  @override
  Widget build(BuildContext c) => Card(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Image.asset('assets/icon/icon.png', height: 100),
          Text(
            title,
            style: Theme.of(
              c,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add a person and an entry whenever money changes hands.',
            textAlign: TextAlign.center,
          ),
          if (on != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: FilledButton(
                onPressed: on,
                child: const Text('Get started'),
              ),
            ),
        ],
      ),
    ),
  );
}

Future<void> editPerson(BuildContext c, WidgetRef r, {Person? p}) async {
  final name = TextEditingController(text: p?.name);
  final phone = TextEditingController(text: p?.phone);
  final email = TextEditingController(text: p?.email);
  final note = TextEditingController(text: p?.note);
  await showModalBottomSheet<void>(
    context: c,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (d) => Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        MediaQuery.viewInsetsOf(d).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              p == null ? 'Add a person' : 'Edit person',
              style: Theme.of(
                d,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text('Give every balance a familiar face.'),
            const SizedBox(height: 22),
            TextField(
              controller: name,
              autofocus: true,
              maxLength: InputLimits.name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phone,
              maxLength: InputLimits.phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone (optional)',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: email,
              maxLength: InputLimits.email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email (optional)',
                prefixIcon: Icon(Icons.mail_outline),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: note,
              maxLength: InputLimits.note,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Private note (optional)',
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              style: FilledButton.styleFrom(padding: const EdgeInsets.all(17)),
              onPressed: () async {
                if (name.text.trim().isEmpty) return;
                await r
                    .read(ledgerProvider.notifier)
                    .savePerson(
                      existing: p,
                      name: name.text,
                      phone: phone.text,
                      email: email.text,
                      note: note.text,
                    );
                if (d.mounted) Navigator.pop(d);
              },
              icon: const Icon(Icons.check),
              label: const Text('Save person'),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> editTransaction(
  BuildContext c,
  WidgetRef r, {
  String? personId,
  LedgerTransaction? t,
}) async {
  final s = r.read(ledgerProvider);
  if (s.people.isEmpty) {
    await editPerson(c, r);
    return;
  }
  var person = t?.personId ?? personId ?? s.people.first.id;
  var kind = t?.kind ?? TransactionKind.lent;
  var currency = t?.currencyCode ?? s.settings.defaultCurrencyCode;
  var transactionDate = _dateOnly(t?.transactionDate ?? DateTime.now());
  DateTime? dueDate = t?.dueDate == null ? null : _dateOnly(t!.dueDate!);
  var photoPath = t?.photoPath;
  if (!supportsLocalImageFiles ||
      photoPath == null ||
      !localImageExists(photoPath)) {
    photoPath = null;
  }
  final amount = TextEditingController(
    text: t == null ? '' : (t.amountMinor / 100).toStringAsFixed(2),
  );
  final note = TextEditingController(text: t?.note);
  await showModalBottomSheet<void>(
    context: c,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (d) => StatefulBuilder(
      builder: (d, set) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          MediaQuery.viewInsetsOf(d).bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t == null ? 'Record an entry' : 'Edit entry',
                style: Theme.of(d).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text('A small record now keeps things clear later.'),
              const SizedBox(height: 22),
              DropdownButtonFormField(
                initialValue: person,
                decoration: const InputDecoration(
                  labelText: 'Person',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                items: s.people
                    .map(
                      (p) => DropdownMenuItem(value: p.id, child: Text(p.name)),
                    )
                    .toList(),
                onChanged: (v) => set(() => person = v!),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField(
                initialValue: kind,
                decoration: const InputDecoration(
                  labelText: 'What happened?',
                  prefixIcon: Icon(Icons.swap_horiz),
                ),
                items: TransactionKind.values
                    .map(
                      (v) => DropdownMenuItem(value: v, child: Text(label(v))),
                    )
                    .toList(),
                onChanged: (v) => set(() => kind = v!),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [LengthLimitingTextInputFormatter(12)],
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField(
                initialValue: currency,
                decoration: const InputDecoration(
                  labelText: 'Currency',
                  prefixIcon: Icon(Icons.currency_exchange),
                ),
                items: currencies.keys
                    .map(
                      (v) => DropdownMenuItem(
                        value: v,
                        child: Text(currencyLabel(v)),
                      ),
                    )
                    .toList(),
                onChanged: (v) => set(() => currency = v!),
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_outlined),
                title: const Text('Transaction date'),
                subtitle: Text(formatDate(transactionDate)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: d,
                    initialDate: transactionDate,
                    firstDate: DateTime(1900),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) set(() => transactionDate = picked);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: const Text('Due date (optional)'),
                subtitle: Text(
                  dueDate == null ? 'No due date' : formatDate(dueDate!),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (dueDate != null)
                      IconButton(
                        tooltip: 'Clear due date',
                        onPressed: () => set(() => dueDate = null),
                        icon: const Icon(Icons.clear),
                      ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: d,
                    initialDate: dueDate ?? transactionDate,
                    firstDate: DateTime(1900),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) set(() => dueDate = picked);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: note,
                maxLength: InputLimits.note,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
              const SizedBox(height: 14),
              if (supportsLocalImageFiles)
                _LocalPhotoAttachment(
                  photoPath: photoPath,
                  onAdd: () async {
                    final selected = await _pickLocalPhoto(d);
                    if (selected != null) set(() => photoPath = selected);
                  },
                  onRemove: () => set(() => photoPath = null),
                  onUnavailable: () => set(() => photoPath = null),
                )
              else
                const _LocalPhotoUnavailable(),
              if (t != null) ...[
                const SizedBox(height: 22),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(d).colorScheme.error,
                  ),
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: d,
                      builder: (x) => AlertDialog(
                        title: const Text('Delete this entry?'),
                        content: const Text(
                          'This transaction will be permanently removed.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(x, false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(x, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await r
                          .read(ledgerProvider.notifier)
                          .deleteTransaction(t.id);
                      if (d.mounted) Navigator.pop(d);
                    }
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete transaction'),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(17),
                ),
                onPressed: () async {
                  final minor = _minor(amount.text);
                  if (minor == null || minor > InputLimits.maxAmountMinor) {
                    ScaffoldMessenger.of(d).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Enter a valid amount within the supported range.',
                        ),
                      ),
                    );
                    return;
                  }
                  if (dueDate != null && dueDate!.isBefore(transactionDate)) {
                    ScaffoldMessenger.of(d).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'The due date cannot be before the transaction date.',
                        ),
                      ),
                    );
                    return;
                  }
                  await r
                      .read(ledgerProvider.notifier)
                      .saveTransaction(
                        existing: t,
                        personId: person,
                        kind: kind,
                        amountMinor: minor,
                        currencyCode: currency,
                        transactionDate: transactionDate,
                        dueDate: dueDate,
                        note: note.text,
                        photoPath: photoPath,
                      );
                  if (d.mounted) Navigator.pop(d);
                },
                icon: const Icon(Icons.check),
                label: const Text('Save entry'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

int? _minor(String v) {
  final m = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(v.trim());
  if (m == null) return null;
  final x =
      int.parse(m.group(1)!) * 100 +
      int.parse((m.group(2) ?? '').padRight(2, '0'));
  return x > 0 && x <= InputLimits.maxAmountMinor ? x : null;
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
