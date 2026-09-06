import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/models.dart';
import '../core/split_bill.dart';
import '../data/ledger_repository.dart';
import '../data/cloud_sync_service.dart';

final ledgerRepositoryProvider = Provider<LedgerRepository>((ref) {
  throw UnimplementedError(
    'Override ledgerRepositoryProvider at application startup.',
  );
});

final initialLedgerProvider = Provider<LedgerSnapshot>((ref) {
  throw UnimplementedError(
    'Override initialLedgerProvider at application startup.',
  );
});

final ledgerProvider = NotifierProvider<LedgerController, LedgerSnapshot>(
  LedgerController.new,
);

class LedgerController extends Notifier<LedgerSnapshot> {
  final _uuid = const Uuid();
  LedgerRepository get _repository => ref.read(ledgerRepositoryProvider);

  @override
  LedgerSnapshot build() => ref.read(initialLedgerProvider);

  Future<void> finishOnboarding(String currencyCode) => _replace(
    state.copyWith(
      settings: state.settings.copyWith(
        defaultCurrencyCode: currencyCode,
        hasCompletedOnboarding: true,
      ),
    ),
  );

  Future<void> updateTheme(ThemeMode themeMode) => _replace(
    state.copyWith(settings: state.settings.copyWith(themeMode: themeMode)),
  );

  Future<void> updateDefaultCurrency(String currencyCode) => _replace(
    state.copyWith(
      settings: state.settings.copyWith(defaultCurrencyCode: currencyCode),
    ),
  );

  Future<void> savePerson({
    Person? existing,
    required String name,
    String? phone,
    String? email,
    String? note,
  }) async {
    final now = DateTime.now();
    final person = existing == null
        ? Person(
            id: _uuid.v4(),
            name: name.trim(),
            phone: _clean(phone),
            email: _clean(email),
            note: _clean(note),
            createdAt: now,
            updatedAt: now,
          )
        : existing.copyWith(
            name: name.trim(),
            phone: _clean(phone),
            email: _clean(email),
            note: _clean(note),
            updatedAt: now,
            clearPhone: _clean(phone) == null,
            clearEmail: _clean(email) == null,
            clearNote: _clean(note) == null,
          );
    final people = [
      ...state.people.where((item) => item.id != person.id),
      person,
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    await _replace(state.copyWith(people: people));
  }

  Future<void> setPersonArchived(Person person, bool archived) => _replace(
    state.copyWith(
      people: state.people
          .map(
            (item) => item.id == person.id
                ? item.copyWith(isArchived: archived, updatedAt: DateTime.now())
                : item,
          )
          .toList(),
    ),
  );

  Future<void> saveTransaction({
    LedgerTransaction? existing,
    required String personId,
    required TransactionKind kind,
    required int amountMinor,
    required String currencyCode,
    required DateTime transactionDate,
    DateTime? dueDate,
    String? note,
    AdjustmentDirection? adjustmentDirection,
  }) async {
    final now = DateTime.now();
    final transaction = existing == null
        ? LedgerTransaction(
            id: _uuid.v4(),
            personId: personId,
            kind: kind,
            amountMinor: amountMinor,
            currencyCode: currencyCode,
            transactionDate: transactionDate,
            dueDate: dueDate,
            note: _clean(note),
            adjustmentDirection: adjustmentDirection,
            createdAt: now,
            updatedAt: now,
          )
        : existing.copyWith(
            personId: personId,
            kind: kind,
            amountMinor: amountMinor,
            currencyCode: currencyCode,
            transactionDate: transactionDate,
            dueDate: dueDate,
            note: _clean(note),
            adjustmentDirection: adjustmentDirection,
            updatedAt: now,
            clearDueDate: dueDate == null,
            clearNote: _clean(note) == null,
          );
    await _replace(
      state.copyWith(
        transactions: [
          ...state.transactions.where((item) => item.id != transaction.id),
          transaction,
        ],
      ),
    );
  }

  Future<void> deleteTransaction(String id) async {
    await _replace(
      state.copyWith(
        transactions: state.transactions
            .where((item) => item.id != id)
            .toList(),
      ),
    );
    await CloudSyncService.instance.deleteTransaction(id);
  }

  Future<void> restoreTransaction(LedgerTransaction transaction) => _replace(
    state.copyWith(transactions: [...state.transactions, transaction]),
  );

  Future<void> saveBill({
    SplitBill? existing,
    required String title,
    required String currencyCode,
    required List<BillParticipant> participants,
    required List<BillItem> items,
    required String payerId,
    int tipMinor = 0,
    List<String> tipParticipantIds = const [],
    double vatPercent = 0,
    double servicePercent = 0,
    ServiceChargeTiming serviceTiming = ServiceChargeTiming.beforeVat,
    String? note,
  }) async {
    final now = DateTime.now();
    final bill = existing == null
        ? SplitBill(
            id: _uuid.v4(),
            title: title.trim().isEmpty ? 'Untitled bill' : title.trim(),
            currencyCode: currencyCode,
            participants: participants,
            items: items,
            payerId: payerId,
            tipMinor: tipMinor,
            tipParticipantIds: tipParticipantIds,
            vatPercent: vatPercent,
            servicePercent: servicePercent,
            serviceTiming: serviceTiming,
            note: _clean(note),
            createdAt: now,
            updatedAt: now,
          )
        : existing.copyWith(
            title: title.trim().isEmpty ? 'Untitled bill' : title.trim(),
            currencyCode: currencyCode,
            participants: participants,
            items: items,
            payerId: payerId,
            tipMinor: tipMinor,
            tipParticipantIds: tipParticipantIds,
            vatPercent: vatPercent,
            servicePercent: servicePercent,
            serviceTiming: serviceTiming,
            note: _clean(note),
            updatedAt: now,
          );
    await _replace(
      state.copyWith(
        bills: [...state.bills.where((item) => item.id != bill.id), bill],
      ),
    );
  }

  Future<void> deleteBill(String id) async {
    await _replace(
      state.copyWith(
        bills: state.bills.where((item) => item.id != id).toList(),
      ),
    );
    await CloudSyncService.instance.deleteBill(id);
  }

  Future<void> clearAll() async {
    await CloudSyncService.instance.clearAllData();
    await _repository.clear();
    state = LedgerSnapshot.empty();
  }

  Future<void> syncFromCloud() async {
    final cloud = await CloudSyncService.instance.download();
    if (cloud == null) return;
    final people = {for (final item in state.people) item.id: item};
    for (final item in cloud.people) {
      final existing = people[item.id];
      if (existing == null || item.updatedAt.isAfter(existing.updatedAt))
        people[item.id] = item;
    }
    final transactions = {for (final item in state.transactions) item.id: item};
    for (final item in cloud.transactions) {
      final existing = transactions[item.id];
      if (existing == null || item.updatedAt.isAfter(existing.updatedAt))
        transactions[item.id] = item;
    }
    final bills = {for (final item in state.bills) item.id: item};
    for (final item in cloud.bills) {
      final existing = bills[item.id];
      if (existing == null || item.updatedAt.isAfter(existing.updatedAt)) {
        bills[item.id] = item;
      }
    }
    await _replace(
      state.copyWith(
        people: people.values.toList(),
        transactions: transactions.values.toList(),
        bills: bills.values.toList(),
      ),
    );
  }

  Future<void> _replace(LedgerSnapshot snapshot) async {
    state = snapshot.copyWith(recoveryMessage: state.recoveryMessage);
    await _repository.save(state);
    await CloudSyncService.instance.upload(state);
  }

  String? _clean(String? value) {
    final cleaned = value?.trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }
}
