import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers.dart';
import '../app/theme.dart';
import '../core/formatters.dart';
import '../core/ledger_calculator.dart';
import '../core/models.dart';
import '../core/platform/exporter.dart';
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
        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => editTransaction(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Add entry'),
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

class Activity extends ConsumerWidget {
  const Activity({super.key});
  @override
  Widget build(BuildContext c, WidgetRef r) {
    final s = r.watch(ledgerProvider);
    final ts = [...s.transactions]
      ..sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
    final n = {for (final p in s.people) p.id: p.name};
    return Frame(
      title: 'Activity',
      child: ts.isEmpty
          ? Empty(
              on: () => editTransaction(c, r),
              title: 'Your ledger is ready',
            )
          : ListView(
              children: [
                for (final t in ts)
                  Card(
                    child: Tile(
                      t: t,
                      name: n[t.personId] ?? 'Unknown person',
                      on: () => editTransaction(c, r, t: t),
                    ),
                  ),
              ],
            ),
    );
  }
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
                  title: const Text('Export your ledger'),
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
          for (final e in balancesFor(ts).entries) ...[
            HeroBalance(code: e.key, balance: e.value),
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
              ? BalanceMateColors.cobalt
              : Theme.of(c).colorScheme.error,
        ),
      ),
    );
  }
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
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phone,
              decoration: const InputDecoration(
                labelText: 'Phone (optional)',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: email,
              decoration: const InputDecoration(
                labelText: 'Email (optional)',
                prefixIcon: Icon(Icons.mail_outline),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: note,
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
              TextField(
                controller: note,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
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
                  if (minor == null) return;
                  await r
                      .read(ledgerProvider.notifier)
                      .saveTransaction(
                        existing: t,
                        personId: person,
                        kind: kind,
                        amountMinor: minor,
                        currencyCode: currency,
                        transactionDate: t?.transactionDate ?? DateTime.now(),
                        dueDate: t?.dueDate,
                        note: note.text,
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
  return x > 0 ? x : null;
}
