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
  testWidgets(
    'bulk import appends once and survives failed save retry and reopening',
    (tester) async {
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
            id: 'existing',
            name: 'Starter',
            amountMinor: 500,
            participantIds: ['a'],
          ),
        ],
        payerId: 'a',
        billDate: DateTime(2026),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      final repository = await _pumpApp(
        tester,
        home: BillEditorPage(bill: bill),
      );
      expect(find.text('Add item'), findsOneWidget);
      expect(find.text('Paste items'), findsOneWidget);
      await tester.tap(find.text('Paste items'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('bill-import-text')),
        'Soup,2,12.50',
      );
      await tester.pump();
      await tester.tap(find.text('Review items'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Assign people'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Everyone'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Review summary'));
      await tester.pumpAndSettle();
      expect(repository.snapshots, isEmpty);
      final commit = tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Add 1 item to bill'),
          )
          .onPressed!;
      commit();
      commit();
      await tester.pumpAndSettle();
      expect(repository.snapshots, isEmpty);
      await tester.tap(find.text('Save'));
      await tester.pump();
      final saved = repository.snapshots.single.bills.single;
      expect(saved.items, hasLength(2));
      expect(saved.items.first.id, 'existing');
      expect(saved.items.last.quantity, 2);
      expect(saved.items.last.participantIds, ['a', 'b']);
      expect(calculateBill(saved).itemShares, {'a': 1750, 'b': 1250});
      repository.fail();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(
        repository.snapshots.last.bills.single.items.map((item) => item.id),
        saved.items.map((item) => item.id),
      );
      repository.fail();
      await tester.pumpAndSettle();
      final restored = SplitBill.fromJson(saved.toJson());
      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpApp(tester, home: BillEditorPage(bill: restored));
      await tester.tap(find.text('Soup'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(_field('Quantity')).controller!.text,
        '2',
      );
      expect(
        tester.widget<TextField>(_field('Unit price')).controller!.text,
        '12.50',
      );
      expect(
        tester
            .widget<CheckboxListTile>(
              find.widgetWithText(CheckboxListTile, 'Alex'),
            )
            .value,
        isTrue,
      );
      expect(
        tester
            .widget<CheckboxListTile>(
              find.widgetWithText(CheckboxListTile, 'Jamie'),
            )
            .value,
        isTrue,
      );
    },
  );

  for (final shared in [false, true]) {
    testWidgets(
      'item quantity previews, edits and saves (${shared ? 'shared' : 'solo'})',
      (tester) async {
        final bill = SplitBill(
          id: 'bill',
          title: 'Dinner',
          currencyCode: 'GBP',
          participants: const [
            BillParticipant(id: 'a', name: 'Alex'),
            BillParticipant(id: 'b', name: 'Jamie'),
          ],
          items: const [],
          payerId: 'a',
          billDate: DateTime(2026),
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );
        final repository = await _pumpApp(
          tester,
          home: BillEditorPage(bill: bill),
        );
        await tester.tap(find.text('Add item'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(_field('Quantity')).controller!.text,
          '1',
        );
        await tester.enterText(_field('What was ordered?'), 'Soup');
        await tester.enterText(_field('Unit price'), '12.50');
        await tester.pump();
        expect(find.text('Total: ${formatMoney(1250, 'GBP')}'), findsOneWidget);
        await tester.enterText(_field('Quantity'), '2');
        await tester.pump();
        expect(find.text('Total: ${formatMoney(2500, 'GBP')}'), findsOneWidget);
        await tester.tap(find.widgetWithText(CheckboxListTile, 'Alex'));
        if (shared) {
          await tester.tap(find.widgetWithText(CheckboxListTile, 'Jamie'));
        }
        await tester.pump();
        final save = tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save item'),
            )
            .onPressed!;
        save();
        save();
        await tester.pumpAndSettle();
        expect(find.byType(BillEditorPage), findsOneWidget);
        await tester.tap(find.text('Soup'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(_field('Quantity')).controller!.text,
          '2',
        );
        expect(
          tester.widget<TextField>(_field('Unit price')).controller!.text,
          '12.50',
        );
        await tester.enterText(_field('Quantity'), '3');
        await tester.pump();
        expect(find.text('Total: ${formatMoney(3750, 'GBP')}'), findsOneWidget);
        await tester.tap(find.text('Save item'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save'));
        await tester.pump();
        final saved = repository.snapshots.single.bills.single;
        expect(saved.items.single.quantity, 3);
        expect(saved.items.single.amountMinor, 1250);
        expect(
          calculateBill(saved).itemShares,
          shared ? {'a': 1875, 'b': 1875} : {'a': 3750, 'b': 0},
        );
        repository.fail();
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Remove Jamie'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save'));
        await tester.pump();
        expect(repository.snapshots.last.bills.single.items.single.quantity, 3);
        repository.fail();
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets('item rejects invalid quantities and excessive totals', (
    tester,
  ) async {
    await _pumpApp(tester);
    await tester.tap(find.text('Bill'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add item'));
    await tester.pumpAndSettle();
    await tester.enterText(_field('What was ordered?'), 'Soup');
    await tester.enterText(_field('Unit price'), '10');
    await tester.pump();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Me'));
    final save = find.widgetWithText(FilledButton, 'Save item');
    for (final quantity in ['', '0', '-1', '1.5']) {
      await tester.enterText(_field('Quantity'), quantity);
      await tester.pump();
      expect(tester.widget<FilledButton>(save).onPressed, isNull);
      expect(find.text('Total: —'), findsOneWidget);
    }
    await tester.enterText(_field('Quantity'), '2');
    await tester.pump();
    await tester.enterText(_field('Unit price'), '999999999.99');
    await tester.pump();
    expect(tester.widget<FilledButton>(save).onPressed, isNull);
    expect(find.textContaining('The item total exceeds'), findsOneWidget);
    await tester.enterText(_field('Unit price'), '10');
    await tester.pump();
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);
  });

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
          quantity: 2,
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
    expect(find.text('Pizza × 2'), findsNWidgets(2));
    expect(find.text('${formatMoney(2400, 'GBP')} ÷ 2'), findsNWidgets(2));
  });
}
