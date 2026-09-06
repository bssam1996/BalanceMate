import 'models.dart';

class CurrencyBalance {
  const CurrencyBalance({required this.owedToMe, required this.iOwe});

  final int owedToMe;
  final int iOwe;
  int get net => owedToMe - iOwe;
}

Map<String, CurrencyBalance> balancesFor(
  Iterable<LedgerTransaction> transactions,
) {
  final effects = <String, int>{};
  for (final transaction in transactions) {
    effects.update(
      transaction.currencyCode,
      (value) => value + transaction.balanceEffectMinor,
      ifAbsent: () => transaction.balanceEffectMinor,
    );
  }
  return {
    for (final entry in effects.entries)
      entry.key: CurrencyBalance(
        owedToMe: entry.value > 0 ? entry.value : 0,
        iOwe: entry.value < 0 ? -entry.value : 0,
      ),
  };
}

Map<String, CurrencyBalance> balancesForPerson(
  String personId,
  Iterable<LedgerTransaction> transactions,
) => balancesFor(
  transactions.where((transaction) => transaction.personId == personId),
);

bool isOverdue(LedgerTransaction transaction, DateTime now) =>
    transaction.dueDate != null &&
    DateTime(
      transaction.dueDate!.year,
      transaction.dueDate!.month,
      transaction.dueDate!.day,
    ).isBefore(DateTime(now.year, now.month, now.day));
