import 'dart:convert';

import 'package:flutter/material.dart';

import 'split_bill.dart';

enum TransactionKind {
  lent,
  borrowed,
  repaymentReceived,
  repaymentMade,
  adjustment,
}

enum AdjustmentDirection { owedToMe, iOwe }

class Person {
  const Person({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.phone,
    this.email,
    this.note,
    this.isArchived = false,
  });

  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? note;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  Person copyWith({
    String? name,
    String? phone,
    String? email,
    String? note,
    bool? isArchived,
    DateTime? updatedAt,
    bool clearPhone = false,
    bool clearEmail = false,
    bool clearNote = false,
  }) => Person(
    id: id,
    name: name ?? this.name,
    phone: clearPhone ? null : phone ?? this.phone,
    email: clearEmail ? null : email ?? this.email,
    note: clearNote ? null : note ?? this.note,
    isArchived: isArchived ?? this.isArchived,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'email': email,
    'note': note,
    'isArchived': isArchived,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Person.fromJson(Map<String, dynamic> json) => Person(
    id: json['id'] as String,
    name: json['name'] as String,
    phone: json['phone'] as String?,
    email: json['email'] as String?,
    note: json['note'] as String?,
    isArchived: json['isArchived'] as bool? ?? false,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );
}

class LedgerTransaction {
  const LedgerTransaction({
    required this.id,
    required this.personId,
    required this.kind,
    required this.amountMinor,
    required this.currencyCode,
    required this.transactionDate,
    required this.createdAt,
    required this.updatedAt,
    this.dueDate,
    this.note,
    this.photoPath,
    this.adjustmentDirection,
  });

  final String id;
  final String personId;
  final TransactionKind kind;
  final int amountMinor;
  final String currencyCode;
  final DateTime transactionDate;
  final DateTime? dueDate;
  final String? note;

  /// A device-only path. It is deliberately excluded from cloud and backups.
  final String? photoPath;
  final AdjustmentDirection? adjustmentDirection;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Positive means the counterparty owes the user; negative means the user owes them.
  int get balanceEffectMinor {
    switch (kind) {
      case TransactionKind.lent:
      case TransactionKind.repaymentMade:
        return amountMinor;
      case TransactionKind.borrowed:
      case TransactionKind.repaymentReceived:
        return -amountMinor;
      case TransactionKind.adjustment:
        return adjustmentDirection == AdjustmentDirection.owedToMe
            ? amountMinor
            : -amountMinor;
    }
  }

  LedgerTransaction copyWith({
    String? personId,
    TransactionKind? kind,
    int? amountMinor,
    String? currencyCode,
    DateTime? transactionDate,
    DateTime? dueDate,
    String? note,
    String? photoPath,
    AdjustmentDirection? adjustmentDirection,
    DateTime? updatedAt,
    bool clearDueDate = false,
    bool clearNote = false,
    bool clearPhoto = false,
  }) => LedgerTransaction(
    id: id,
    personId: personId ?? this.personId,
    kind: kind ?? this.kind,
    amountMinor: amountMinor ?? this.amountMinor,
    currencyCode: currencyCode ?? this.currencyCode,
    transactionDate: transactionDate ?? this.transactionDate,
    dueDate: clearDueDate ? null : dueDate ?? this.dueDate,
    note: clearNote ? null : note ?? this.note,
    photoPath: clearPhoto ? null : photoPath ?? this.photoPath,
    adjustmentDirection: adjustmentDirection ?? this.adjustmentDirection,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson({bool includeLocalPhoto = true}) => {
    'id': id,
    'personId': personId,
    'kind': kind.name,
    'amountMinor': amountMinor,
    'currencyCode': currencyCode,
    'transactionDate': transactionDate.toIso8601String(),
    'dueDate': dueDate?.toIso8601String(),
    'note': note,
    if (includeLocalPhoto) 'photoPath': photoPath,
    'adjustmentDirection': adjustmentDirection?.name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory LedgerTransaction.fromJson(Map<String, dynamic> json) =>
      LedgerTransaction(
        id: json['id'] as String,
        personId: json['personId'] as String,
        kind: TransactionKind.values.byName(json['kind'] as String),
        amountMinor: json['amountMinor'] as int,
        currencyCode: json['currencyCode'] as String,
        transactionDate: DateTime.parse(json['transactionDate'] as String),
        dueDate: json['dueDate'] == null
            ? null
            : DateTime.parse(json['dueDate'] as String),
        note: json['note'] as String?,
        photoPath: json['photoPath'] as String?,
        adjustmentDirection: json['adjustmentDirection'] == null
            ? null
            : AdjustmentDirection.values.byName(
                json['adjustmentDirection'] as String,
              ),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}

class AppSettings {
  const AppSettings({
    this.defaultCurrencyCode = 'GBP',
    this.themeMode = ThemeMode.system,
    this.hasCompletedOnboarding = false,
    this.schemaVersion = 1,
  });

  final String defaultCurrencyCode;
  final ThemeMode themeMode;
  final bool hasCompletedOnboarding;
  final int schemaVersion;

  AppSettings copyWith({
    String? defaultCurrencyCode,
    ThemeMode? themeMode,
    bool? hasCompletedOnboarding,
  }) => AppSettings(
    defaultCurrencyCode: defaultCurrencyCode ?? this.defaultCurrencyCode,
    themeMode: themeMode ?? this.themeMode,
    hasCompletedOnboarding:
        hasCompletedOnboarding ?? this.hasCompletedOnboarding,
    schemaVersion: schemaVersion,
  );

  Map<String, dynamic> toJson() => {
    'defaultCurrencyCode': defaultCurrencyCode,
    'themeMode': themeMode.name,
    'hasCompletedOnboarding': hasCompletedOnboarding,
    'schemaVersion': schemaVersion,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    defaultCurrencyCode: json['defaultCurrencyCode'] as String? ?? 'GBP',
    themeMode: ThemeMode.values.firstWhere(
      (mode) => mode.name == json['themeMode'],
      orElse: () => ThemeMode.system,
    ),
    hasCompletedOnboarding: json['hasCompletedOnboarding'] as bool? ?? false,
    schemaVersion: json['schemaVersion'] as int? ?? 1,
  );
}

class LedgerSnapshot {
  const LedgerSnapshot({
    required this.people,
    required this.transactions,
    this.bills = const [],
    required this.settings,
    this.recoveryMessage,
  });

  factory LedgerSnapshot.empty() => const LedgerSnapshot(
    people: [],
    transactions: [],
    settings: AppSettings(),
  );

  /// Restores a complete, user-created BalanceMate JSON backup.
  factory LedgerSnapshot.fromExportJson(String source) {
    final raw = jsonDecode(source);
    if (raw is! Map<String, dynamic>) {
      throw const FormatException('The backup must contain a JSON object.');
    }
    if (raw['schemaVersion'] != 1) {
      throw const FormatException('This backup uses an unsupported format.');
    }

    List<T> records<T>(String key, T Function(Map<String, dynamic>) fromJson) {
      final values = raw[key];
      if (values is! List) {
        throw FormatException('The backup is missing $key.');
      }
      return values.map((value) {
        if (value is! Map) throw FormatException('A $key record is invalid.');
        return fromJson(Map<String, dynamic>.from(value));
      }).toList();
    }

    final settings = raw['settings'];
    if (settings is! Map) {
      throw const FormatException('The backup is missing settings.');
    }
    return LedgerSnapshot(
      people: records('people', Person.fromJson),
      transactions: records('transactions', LedgerTransaction.fromJson),
      bills: records('bills', SplitBill.fromJson),
      settings: AppSettings.fromJson(Map<String, dynamic>.from(settings)),
    );
  }

  final List<Person> people;
  final List<LedgerTransaction> transactions;
  final List<SplitBill> bills;
  final AppSettings settings;
  final String? recoveryMessage;

  LedgerSnapshot copyWith({
    List<Person>? people,
    List<LedgerTransaction>? transactions,
    List<SplitBill>? bills,
    AppSettings? settings,
    String? recoveryMessage,
  }) => LedgerSnapshot(
    people: people ?? this.people,
    transactions: transactions ?? this.transactions,
    bills: bills ?? this.bills,
    settings: settings ?? this.settings,
    recoveryMessage: recoveryMessage,
  );

  String toExportJson() => const JsonEncoder.withIndent('  ').convert({
    'schemaVersion': 1,
    'exportedAt': DateTime.now().toIso8601String(),
    'people': people.map((person) => person.toJson()).toList(),
    'transactions': transactions
        .map((transaction) => transaction.toJson(includeLocalPhoto: false))
        .toList(),
    'bills': bills
        .map((bill) => bill.toJson(includeLocalPhoto: false))
        .toList(),
    'settings': settings.toJson(),
  });
}
