import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/models.dart';
import '../core/split_bill.dart';

abstract class LedgerRepository {
  Future<LedgerSnapshot> load();
  Future<void> save(LedgerSnapshot snapshot);
  Future<void> clear();
}

class SharedPreferencesLedgerRepository implements LedgerRepository {
  SharedPreferencesLedgerRepository(this._preferences);

  static const _peopleKey = 'balancemate.people.v1';
  static const _transactionsKey = 'balancemate.transactions.v1';
  static const _settingsKey = 'balancemate.settings.v1';
  static const _billsKey = 'balancemate.bills.v1';
  final SharedPreferences _preferences;

  @override
  Future<LedgerSnapshot> load() async {
    var skipped = 0;
    List<T> decodeList<T>(String key, T Function(Map<String, dynamic>) parse) {
      final raw = _preferences.getString(key);
      if (raw == null) return [];
      try {
        final values = jsonDecode(raw) as List<dynamic>;
        return values
            .whereType<Map<String, dynamic>>()
            .map((value) {
              try {
                return parse(value);
              } catch (_) {
                skipped++;
                return null;
              }
            })
            .whereType<T>()
            .toList();
      } catch (_) {
        skipped++;
        return [];
      }
    }

    AppSettings settings = const AppSettings();
    final rawSettings = _preferences.getString(_settingsKey);
    if (rawSettings != null) {
      try {
        settings = AppSettings.fromJson(
          jsonDecode(rawSettings) as Map<String, dynamic>,
        );
      } catch (_) {
        skipped++;
      }
    }
    return LedgerSnapshot(
      people: decodeList(_peopleKey, Person.fromJson),
      transactions: decodeList(_transactionsKey, LedgerTransaction.fromJson),
      bills: decodeList(_billsKey, SplitBill.fromJson),
      settings: settings,
      recoveryMessage: skipped == 0
          ? null
          : '$skipped damaged record${skipped == 1 ? '' : 's'} could not be loaded.',
    );
  }

  @override
  Future<void> save(LedgerSnapshot snapshot) async {
    await _preferences.setString(
      _peopleKey,
      jsonEncode(snapshot.people.map((item) => item.toJson()).toList()),
    );
    await _preferences.setString(
      _transactionsKey,
      jsonEncode(snapshot.transactions.map((item) => item.toJson()).toList()),
    );
    await _preferences.setString(
      _billsKey,
      jsonEncode(snapshot.bills.map((item) => item.toJson()).toList()),
    );
    await _preferences.setString(
      _settingsKey,
      jsonEncode(snapshot.settings.toJson()),
    );
  }

  @override
  Future<void> clear() async {
    await _preferences.remove(_peopleKey);
    await _preferences.remove(_transactionsKey);
    await _preferences.remove(_billsKey);
    await _preferences.remove(_settingsKey);
  }
}
