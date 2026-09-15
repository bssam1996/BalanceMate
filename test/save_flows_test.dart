import 'dart:async';

import 'package:balancemate/app/providers.dart';
import 'package:balancemate/core/formatters.dart';
import 'package:balancemate/core/ledger_calculator.dart';
import 'package:balancemate/core/models.dart';
import 'package:balancemate/core/split_bill.dart';
import 'package:balancemate/data/ledger_repository.dart';
import 'package:balancemate/features/home_shell.dart';
import 'package:balancemate/features/split_bills_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _person = Person(
  id: 'person',
  name: 'Alex',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

class _PendingRepository implements LedgerRepository {
  final snapshots = <LedgerSnapshot>[];
  final pending = <Completer<void>>[];

  @override
  Future<void> save(LedgerSnapshot snapshot) {
    snapshots.add(snapshot);
    final completer = Completer<void>();
    pending.add(completer);
    return completer.future;
  }

  void fail() => pending.last.completeError(StateError('Storage unavailable'));

  @override
  Future<LedgerSnapshot> load() async => LedgerSnapshot.empty();

  @override
  Future<void> clear() async {}
}

Future<_PendingRepository> _pumpApp(
  WidgetTester tester, {
  Widget? home,
  List<SplitBill> bills = const [],
}) async {
  await tester.binding.setSurfaceSize(const Size(1000, 2200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final repository = _PendingRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ledgerRepositoryProvider.overrideWithValue(repository),
        initialLedgerProvider.overrideWithValue(
          LedgerSnapshot.empty().copyWith(people: [_person], bills: bills),
        ),
      ],
      child: MaterialApp(
        home:
            home ??
            Consumer(
              builder: (context, ref, _) => Scaffold(
                body: Column(
                  children: [
                    TextButton(
                      onPressed: () => openBillEditor(context),
                      child: const Text('Bill'),
                    ),
                    TextButton(
                      onPressed: () => editTransaction(context, ref),
                      child: const Text('Entry'),
                    ),
                    TextButton(
                      onPressed: () => editPerson(context, ref),
                      child: const Text('Person'),
                    ),
                    TextButton(
                      onPressed: () => settlePersonBalance(
                        context,
                        ref,
                        person: _person,
                        currencyCode: 'GBP',
                        balance: const CurrencyBalance(owedToMe: 1200, iOwe: 0),
                      ),
                      child: const Text('Settlement'),
                    ),
                  ],
                ),
              ),
            ),
      ),
    ),
  );
  return repository;
}

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

void main() {
  testWidgets('bill saves blank charges as zero and guards both save buttons', (
    tester,
  ) async {
    final repository = await _pumpApp(tester);
    await tester.tap(find.text('Bill'));
    await tester.pumpAndSettle();

    final topSave = tester
        .widget<TextButton>(find.widgetWithText(TextButton, 'Save'))
        .onPressed!;
    final bottomSave = tester
        .widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Save split bill'),
        )
        .onPressed!;
    // Exercise callbacks before the disabled buttons have had a frame to build.
    topSave();
    bottomSave();
    topSave();
    await tester.pump();

    expect(repository.snapshots, hasLength(1));
    final bill = repository.snapshots.single.bills.single;
    expect(bill.tipMinor, 0);
    expect(bill.servicePercent, 0);
    expect(bill.vatPercent, 0);
    expect(find.text('Saving…'), findsNWidgets(2));
    for (final button in tester.widgetList<ButtonStyleButton>(
      find.byWidgetPredicate(
        (widget) => widget is ButtonStyleButton && !widget.enabled,
      ),
    )) {
      expect(button.onPressed, isNull);
    }

    repository.fail();
    await tester.pumpAndSettle();
    expect(
      find.text('Could not save the bill. Please try again.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(repository.snapshots, hasLength(2));
    expect(repository.snapshots.last.bills.single.id, bill.id);
    repository.fail();
    await tester.pumpAndSettle();
  });

  testWidgets('invalid bill charges still prevent saving', (tester) async {
    final repository = await _pumpApp(tester);
    await tester.tap(find.text('Bill'));
    await tester.pumpAndSettle();
    for (final label in ['Tip amount', 'Service %', 'VAT %']) {
      await tester.enterText(_field(label), '-1');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(repository.snapshots, isEmpty);
      await tester.enterText(_field(label), '');
    }
  });

  for (final flow in [
    ('Entry', 'Save entry', 'Amount', '12'),
    ('Person', 'Save person', 'Name', 'Jamie'),
    ('Settlement', 'Record payment', 'Amount', '12'),
  ]) {
    testWidgets('${flow.$1} disables saving and retries without duplicates', (
      tester,
    ) async {
      final repository = await _pumpApp(tester);
      await tester.tap(find.text(flow.$1));
      await tester.pumpAndSettle();
      await tester.enterText(_field(flow.$3), flow.$4);
      final saveFinder = find.widgetWithText(FilledButton, flow.$2);
      final save = tester.widget<FilledButton>(saveFinder).onPressed!;
      save();
      save();
      await tester.pump();

      expect(repository.snapshots, hasLength(1));
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Saving…'))
            .onPressed,
        isNull,
      );
      final first = repository.snapshots.single;
      repository.fail();
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(saveFinder).onPressed, isNotNull);

      await tester.tap(saveFinder);
      await tester.pump();
      expect(repository.snapshots, hasLength(2));
      final retry = repository.snapshots.last;
      if (flow.$1 == 'Person') {
        expect(
          retry.people.map((person) => person.id),
          first.people.map((person) => person.id),
        );
      } else {
        expect(retry.transactions.single.id, first.transactions.single.id);
      }
      repository.fail();
      await tester.pumpAndSettle();
    });
  }

  testWidgets('summary shows a divisor only for shared items', (tester) async {
    final bill = SplitBill(
      id: 'bill',
      title: 'Dinner',
      currencyCode: 'GBP',
      participants: const [
        BillParticipant(id: 'a', name: 'Alex'),
        BillParticipant(id: 'b', name: 'Jamie'),
      ],
      items: const [
        BillItem(
          id: 'solo',
          name: 'Soup',
          amountMinor: 500,
          participantIds: ['a'],
        ),
        BillItem(
          id: 'shared',
          name: 'Pizza',
          amountMinor: 1200,
          participantIds: ['a', 'b'],
        ),
      ],
      payerId: 'a',
      billDate: DateTime(2026),
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    await _pumpApp(
      tester,
      home: const BillDetailPage(billId: 'bill'),
      bills: [bill],
    );
    await tester.pumpAndSettle();
    expect(find.text(formatMoney(500, 'GBP')), findsOneWidget);
    expect(find.textContaining('÷ 1'), findsNothing);
    expect(find.text('${formatMoney(1200, 'GBP')} ÷ 2'), findsNWidgets(2));
  });
}
