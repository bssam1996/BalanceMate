import 'package:balancemate/core/ledger_calculator.dart';
import 'package:balancemate/core/models.dart';
import 'package:balancemate/core/split_bill.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('item quantity survives JSON and old items default to one', () {
    const item = BillItem(
      id: 'meal',
      name: 'Meal',
      amountMinor: 1250,
      quantity: 2,
      participantIds: ['a', 'b'],
    );
    final restored = BillItem.fromJson(item.toJson());
    expect(restored.quantity, 2);
    expect(restored.amountMinor, 1250);
    expect(restored.totalMinor, 2500);
    final legacy = BillItem.fromJson({...item.toJson()}..remove('quantity'));
    expect(legacy.quantity, 1);
    expect(legacy.totalMinor, 1250);
  });

  test('quantities determine item shares and percentage charges', () {
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
          id: 'meal',
          name: 'Meal',
          amountMinor: 1000,
          quantity: 2,
          participantIds: ['a', 'b'],
        ),
      ],
      payerId: 'a',
      servicePercent: 10,
      vatPercent: 10,
      billDate: DateTime(2026),
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final result = calculateBill(bill);
    expect(result.subtotal, 2000);
    expect(result.service, 200);
    expect(result.vat, 220);
    expect(result.shares, {'a': 1210, 'b': 1210});
    expect(billText(bill), contains('Meal × 2'));

    final solo = calculateBill(
      bill.copyWith(
        items: const [
          BillItem(
            id: 'meal',
            name: 'Meal',
            amountMinor: 1000,
            quantity: 2,
            participantIds: ['a'],
          ),
        ],
      ),
    );
    expect(solo.shares, {'a': 2420, 'b': 0});
    final restored = LedgerSnapshot.fromExportJson(
      LedgerSnapshot.empty().copyWith(bills: [bill]).toExportJson(),
    );
    expect(restored.bills.single.items.single.quantity, 2);
    expect(calculateBill(restored.bills.single).total, 2420);
  });

  test('ledger effects calculate owed and owing balances', () {
    final now = DateTime(2026);
    LedgerTransaction tx(TransactionKind kind, int amount) => LedgerTransaction(
      id: kind.name,
      personId: 'p',
      kind: kind,
      amountMinor: amount,
      currencyCode: 'GBP',
      transactionDate: now,
      createdAt: now,
      updatedAt: now,
    );
    final balance = balancesFor([
      tx(TransactionKind.lent, 10000),
      tx(TransactionKind.repaymentReceived, 2500),
      tx(TransactionKind.borrowed, 5000),
    ])['GBP']!;
    expect(balance.owedToMe, 2500);
    expect(balance.iOwe, 0);
  });

  test('split bill reconciles rounded shares to the bill total', () {
    final now = DateTime(2026);
    final bill = SplitBill(
      id: 'bill',
      title: 'Dinner',
      currencyCode: 'EGP',
      payerId: 'a',
      billDate: now,
      participants: const [
        BillParticipant(id: 'a', name: 'Aya'),
        BillParticipant(id: 'b', name: 'Basma'),
        BillParticipant(id: 'c', name: 'Cairo'),
      ],
      items: const [
        BillItem(
          id: 'meal',
          name: 'Shared meal',
          amountMinor: 1001,
          participantIds: ['a', 'b', 'c'],
        ),
      ],
      tipMinor: 101,
      vatPercent: 10,
      servicePercent: 10,
      serviceTiming: ServiceChargeTiming.beforeVat,
      photoPath: 'C:/private/dinner-receipt.jpg',
      createdAt: now,
      updatedAt: now,
    );
    final result = calculateBill(bill);
    expect(result.total, 1312);
    expect(result.shares.values.reduce((a, b) => a + b), result.total);
    expect(result.shares['a'], greaterThanOrEqualTo(result.shares['b']!));
    final restored = SplitBill.fromJson(bill.toJson());
    expect(restored.title, 'Dinner');
    expect(restored.billDate, now);
    expect(restored.photoPath, 'C:/private/dinner-receipt.jpg');
    expect(bill.toJson(includeLocalPhoto: false), isNot(contains('photoPath')));

    final legacyJson = Map<String, dynamic>.from(bill.toJson())
      ..remove('billDate');
    expect(SplitBill.fromJson(legacyJson).billDate, now);
  });

  test('ledger backup export can be restored', () {
    final now = DateTime(2026, 9, 8);
    final snapshot = LedgerSnapshot(
      people: [
        Person(id: 'person', name: 'Aya', createdAt: now, updatedAt: now),
      ],
      transactions: const [],
      bills: const [],
      settings: const AppSettings(defaultCurrencyCode: 'EUR'),
    );

    final restored = LedgerSnapshot.fromExportJson(snapshot.toExportJson());
    expect(restored.people.single.name, 'Aya');
    expect(restored.settings.defaultCurrencyCode, 'EUR');
  });

  test('local photo paths are excluded from exports', () {
    final now = DateTime(2026, 9, 8);
    final transaction = LedgerTransaction(
      id: 'transaction',
      personId: 'person',
      kind: TransactionKind.lent,
      amountMinor: 1200,
      currencyCode: 'GBP',
      transactionDate: now,
      photoPath: 'C:/private/receipt.jpg',
      createdAt: now,
      updatedAt: now,
    );

    expect(transaction.toJson()['photoPath'], 'C:/private/receipt.jpg');
    expect(
      transaction.toJson(includeLocalPhoto: false),
      isNot(contains('photoPath')),
    );
  });
}
