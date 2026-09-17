import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../core/models.dart';
import '../core/input_limits.dart';
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
    String? newId,
    required String name,
    String? phone,
    String? email,
    String? note,
  }) async {
    _validatePerson(name: name, phone: phone, email: email, note: note);
    final now = DateTime.now();
    final person = existing == null
        ? Person(
            id: newId ?? _uuid.v4(),
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
    String? newId,
    required String personId,
    required TransactionKind kind,
    required int amountMinor,
    required String currencyCode,
    required DateTime transactionDate,
    DateTime? dueDate,
    String? note,
    String? photoPath,
    AdjustmentDirection? adjustmentDirection,
  }) async {
    _validateTransaction(
      amountMinor: amountMinor,
      transactionDate: transactionDate,
      dueDate: dueDate,
      note: note,
      photoPath: photoPath,
    );
    final now = DateTime.now();
    final transaction = existing == null
        ? LedgerTransaction(
            id: newId ?? _uuid.v4(),
            personId: personId,
            kind: kind,
            amountMinor: amountMinor,
            currencyCode: currencyCode,
            transactionDate: transactionDate,
            dueDate: dueDate,
            note: _clean(note),
            photoPath: _clean(photoPath),
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
            photoPath: _clean(photoPath),
            adjustmentDirection: adjustmentDirection,
            updatedAt: now,
            clearDueDate: dueDate == null,
            clearNote: _clean(note) == null,
            clearPhoto: _clean(photoPath) == null,
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
    String? newId,
    required String title,
    required String currencyCode,
    required List<BillParticipant> participants,
    required List<BillItem> items,
    required String payerId,
    required DateTime billDate,
    int tipMinor = 0,
    List<String> tipParticipantIds = const [],
    double vatPercent = 0,
    double servicePercent = 0,
    ServiceChargeTiming serviceTiming = ServiceChargeTiming.beforeVat,
    String? note,
    String? photoPath,
  }) async {
    _validateBill(
      title: title,
      participants: participants,
      items: items,
      payerId: payerId,
      billDate: billDate,
      tipMinor: tipMinor,
      tipParticipantIds: tipParticipantIds,
      vatPercent: vatPercent,
      servicePercent: servicePercent,
      note: note,
      photoPath: photoPath,
    );
    final now = DateTime.now();
    final bill = existing == null
        ? SplitBill(
            id: newId ?? _uuid.v4(),
            title: title.trim().isEmpty ? 'Untitled bill' : title.trim(),
            currencyCode: currencyCode,
            participants: participants,
            items: items,
            payerId: payerId,
            billDate: billDate,
            tipMinor: tipMinor,
            tipParticipantIds: tipParticipantIds,
            vatPercent: vatPercent,
            servicePercent: servicePercent,
            serviceTiming: serviceTiming,
            note: _clean(note),
            photoPath: _clean(photoPath),
            createdAt: now,
            updatedAt: now,
          )
        : existing.copyWith(
            title: title.trim().isEmpty ? 'Untitled bill' : title.trim(),
            currencyCode: currencyCode,
            participants: participants,
            items: items,
            payerId: payerId,
            billDate: billDate,
            tipMinor: tipMinor,
            tipParticipantIds: tipParticipantIds,
            vatPercent: vatPercent,
            servicePercent: servicePercent,
            serviceTiming: serviceTiming,
            note: _clean(note),
            photoPath: _clean(photoPath),
            updatedAt: now,
            clearPhoto: _clean(photoPath) == null,
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

  /// Replaces the local ledger with a checked backup, then syncs it if signed in.
  Future<void> restoreBackup(LedgerSnapshot backup) async {
    _validateSnapshot(backup);
    state = backup.copyWith(recoveryMessage: null);
    await _repository.save(state);
    await CloudSyncService.instance.replaceLedger(state);
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
      if (existing == null || item.updatedAt.isAfter(existing.updatedAt)) {
        transactions[item.id] =
            item.photoPath == null && existing?.photoPath != null
            ? item.copyWith(photoPath: existing!.photoPath)
            : item;
      }
    }
    final bills = {for (final item in state.bills) item.id: item};
    for (final item in cloud.bills) {
      final existing = bills[item.id];
      if (existing == null || item.updatedAt.isAfter(existing.updatedAt)) {
        bills[item.id] = item.photoPath == null && existing?.photoPath != null
            ? item.copyWith(photoPath: existing!.photoPath)
            : item;
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

  void _validatePerson({
    required String name,
    String? phone,
    String? email,
    String? note,
  }) {
    if (name.trim().isEmpty || name.trim().length > InputLimits.name) {
      throw ArgumentError.value(
        name,
        'name',
        'must be 1 to ${InputLimits.name} characters',
      );
    }
    _checkLength(phone, InputLimits.phone, 'phone');
    _checkLength(email, InputLimits.email, 'email');
    _checkLength(note, InputLimits.note, 'note');
  }

  void _validateTransaction({
    required int amountMinor,
    required DateTime transactionDate,
    required DateTime? dueDate,
    String? note,
    String? photoPath,
  }) {
    if (amountMinor <= 0 || amountMinor > InputLimits.maxAmountMinor) {
      throw ArgumentError.value(
        amountMinor,
        'amountMinor',
        'is outside the supported range',
      );
    }
    _checkDate(transactionDate, 'transactionDate');
    if (dueDate != null) {
      _checkDate(dueDate, 'dueDate');
      if (_day(dueDate).isBefore(_day(transactionDate))) {
        throw ArgumentError.value(
          dueDate,
          'dueDate',
          'cannot be before the transaction date',
        );
      }
    }
    _checkLength(note, InputLimits.note, 'note');
    _checkLength(photoPath, 1024, 'photoPath');
  }

  void _validateBill({
    required String title,
    required List<BillParticipant> participants,
    required List<BillItem> items,
    required String payerId,
    required DateTime billDate,
    required int tipMinor,
    required List<String> tipParticipantIds,
    required double vatPercent,
    required double servicePercent,
    String? note,
    String? photoPath,
  }) {
    _checkLength(title, InputLimits.billTitle, 'title');
    _checkDate(billDate, 'billDate');
    if (participants.isEmpty ||
        participants.length > InputLimits.maxBillParticipants) {
      throw ArgumentError.value(
        participants,
        'participants',
        'must contain 1 to ${InputLimits.maxBillParticipants} people',
      );
    }
    if (items.length > InputLimits.maxBillItems) {
      throw ArgumentError.value(
        items,
        'items',
        'cannot exceed ${InputLimits.maxBillItems} items',
      );
    }
    final ids = participants.map((person) => person.id).toSet();
    if (ids.length != participants.length || !ids.contains(payerId)) {
      throw ArgumentError(
        'Each participant must be unique and the payer must be a participant.',
      );
    }
    for (final person in participants) {
      if (person.name.trim().isEmpty ||
          person.name.trim().length > InputLimits.name) {
        throw ArgumentError.value(
          person.name,
          'participant.name',
          'must be 1 to ${InputLimits.name} characters',
        );
      }
    }
    for (final item in items) {
      if (item.name.trim().isEmpty ||
          item.name.trim().length > InputLimits.itemName ||
          item.amountMinor <= 0 ||
          item.amountMinor > InputLimits.maxAmountMinor ||
          item.quantity < 1 ||
          item.quantity > InputLimits.maxBillItemQuantity ||
          item.totalMinor > InputLimits.maxAmountMinor ||
          item.participantIds.isEmpty ||
          item.participantIds.any((id) => !ids.contains(id))) {
        throw ArgumentError(
          'Each item needs a valid name, unit price, quantity, total, and at least one participant.',
        );
      }
    }
    if (items.map((item) => item.id).toSet().length != items.length ||
        tipParticipantIds.any((id) => !ids.contains(id))) {
      throw ArgumentError(
        'Items must be unique and tip recipients must be participants.',
      );
    }
    if (tipMinor < 0 ||
        tipMinor > InputLimits.maxAmountMinor ||
        !vatPercent.isFinite ||
        !servicePercent.isFinite ||
        vatPercent < 0 ||
        vatPercent > InputLimits.maxPercent ||
        servicePercent < 0 ||
        servicePercent > InputLimits.maxPercent) {
      throw ArgumentError(
        'Amounts and percentages are outside the supported range.',
      );
    }
    _checkLength(note, InputLimits.note, 'note');
    _checkLength(photoPath, 1024, 'photoPath');
  }

  void _checkLength(String? value, int maximum, String field) {
    if ((value?.trim().length ?? 0) > maximum) {
      throw ArgumentError.value(
        value,
        field,
        'cannot exceed $maximum characters',
      );
    }
  }

  void _checkDate(DateTime value, String field) {
    if (value.year < 1900 || value.year > 2100) {
      throw ArgumentError.value(value, field, 'must be between 1900 and 2100');
    }
  }

  DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

  void _validateSnapshot(LedgerSnapshot snapshot) {
    final personIds = <String>{};
    for (final person in snapshot.people) {
      if (person.id.isEmpty || !personIds.add(person.id)) {
        throw const FormatException(
          'People in the backup must have unique IDs.',
        );
      }
      _validatePerson(
        name: person.name,
        phone: person.phone,
        email: person.email,
        note: person.note,
      );
    }
    final transactionIds = <String>{};
    for (final transaction in snapshot.transactions) {
      if (transaction.id.isEmpty ||
          !transactionIds.add(transaction.id) ||
          !personIds.contains(transaction.personId)) {
        throw const FormatException('A transaction in the backup is invalid.');
      }
      _validateTransaction(
        amountMinor: transaction.amountMinor,
        transactionDate: transaction.transactionDate,
        dueDate: transaction.dueDate,
        note: transaction.note,
        photoPath: transaction.photoPath,
      );
    }
    final billIds = <String>{};
    for (final bill in snapshot.bills) {
      if (bill.id.isEmpty || !billIds.add(bill.id)) {
        throw const FormatException('A bill in the backup is invalid.');
      }
      _validateBill(
        title: bill.title,
        participants: bill.participants,
        items: bill.items,
        payerId: bill.payerId,
        billDate: bill.billDate,
        tipMinor: bill.tipMinor,
        tipParticipantIds: bill.tipParticipantIds,
        vatPercent: bill.vatPercent,
        servicePercent: bill.servicePercent,
        note: bill.note,
        photoPath: bill.photoPath,
      );
    }
  }
}
