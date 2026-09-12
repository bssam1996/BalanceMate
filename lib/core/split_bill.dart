class BillParticipant {
  const BillParticipant({required this.id, required this.name});
  final String id;
  final String name;
  Map<String, dynamic> toJson() => {'id': id, 'name': name};
  factory BillParticipant.fromJson(Map<String, dynamic> json) =>
      BillParticipant(id: json['id'] as String, name: json['name'] as String);
}

class BillItem {
  const BillItem({
    required this.id,
    required this.name,
    required this.amountMinor,
    required this.participantIds,
  });
  final String id;
  final String name;
  final int amountMinor;
  final List<String> participantIds;
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'amountMinor': amountMinor,
    'participantIds': participantIds,
  };
  factory BillItem.fromJson(Map<String, dynamic> json) => BillItem(
    id: json['id'] as String,
    name: json['name'] as String,
    amountMinor: json['amountMinor'] as int,
    participantIds: List<String>.from(json['participantIds'] as List),
  );
}

enum ServiceChargeTiming { beforeVat, afterVat }

class SplitBill {
  const SplitBill({
    required this.id,
    required this.title,
    required this.currencyCode,
    required this.participants,
    required this.items,
    required this.payerId,
    required this.billDate,
    required this.createdAt,
    required this.updatedAt,
    this.tipMinor = 0,
    this.tipParticipantIds = const [],
    this.vatPercent = 0,
    this.servicePercent = 0,
    this.serviceTiming = ServiceChargeTiming.beforeVat,
    this.note,
    this.photoPath,
  });
  final String id, title, currencyCode, payerId;
  final List<BillParticipant> participants;
  final List<BillItem> items;
  final int tipMinor;
  final List<String> tipParticipantIds;
  final double vatPercent, servicePercent;
  final ServiceChargeTiming serviceTiming;
  final String? note;

  /// A device-only path. It is never synchronized or included in backups.
  final String? photoPath;

  /// The date on which the bill was incurred, separate from when it was saved.
  final DateTime billDate, createdAt, updatedAt;
  SplitBill copyWith({
    String? title,
    String? currencyCode,
    List<BillParticipant>? participants,
    List<BillItem>? items,
    String? payerId,
    DateTime? billDate,
    int? tipMinor,
    List<String>? tipParticipantIds,
    double? vatPercent,
    double? servicePercent,
    ServiceChargeTiming? serviceTiming,
    String? note,
    String? photoPath,
    DateTime? updatedAt,
    bool clearPhoto = false,
  }) => SplitBill(
    id: id,
    title: title ?? this.title,
    currencyCode: currencyCode ?? this.currencyCode,
    participants: participants ?? this.participants,
    items: items ?? this.items,
    payerId: payerId ?? this.payerId,
    billDate: billDate ?? this.billDate,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    tipMinor: tipMinor ?? this.tipMinor,
    tipParticipantIds: tipParticipantIds ?? this.tipParticipantIds,
    vatPercent: vatPercent ?? this.vatPercent,
    servicePercent: servicePercent ?? this.servicePercent,
    serviceTiming: serviceTiming ?? this.serviceTiming,
    note: note ?? this.note,
    photoPath: clearPhoto ? null : photoPath ?? this.photoPath,
  );
  Map<String, dynamic> toJson({bool includeLocalPhoto = true}) => {
    'id': id,
    'title': title,
    'currencyCode': currencyCode,
    'participants': participants.map((e) => e.toJson()).toList(),
    'items': items.map((e) => e.toJson()).toList(),
    'payerId': payerId,
    'billDate': billDate.toIso8601String(),
    'tipMinor': tipMinor,
    'tipParticipantIds': tipParticipantIds,
    'vatPercent': vatPercent,
    'servicePercent': servicePercent,
    'serviceTiming': serviceTiming.name,
    'note': note,
    if (includeLocalPhoto) 'photoPath': photoPath,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
  factory SplitBill.fromJson(Map<String, dynamic> json) => SplitBill(
    id: json['id'] as String,
    title: json['title'] as String,
    currencyCode: json['currencyCode'] as String,
    participants: (json['participants'] as List)
        .map((e) => BillParticipant.fromJson(e as Map<String, dynamic>))
        .toList(),
    items: (json['items'] as List)
        .map((e) => BillItem.fromJson(e as Map<String, dynamic>))
        .toList(),
    payerId: json['payerId'] as String,
    // Bills saved before bill dates were introduced use their creation date.
    billDate: DateTime.parse(
      json['billDate'] as String? ?? json['createdAt'] as String,
    ),
    tipMinor: json['tipMinor'] as int? ?? 0,
    tipParticipantIds: List<String>.from(
      json['tipParticipantIds'] as List? ?? [],
    ),
    vatPercent: (json['vatPercent'] as num? ?? 0).toDouble(),
    servicePercent: (json['servicePercent'] as num? ?? 0).toDouble(),
    serviceTiming: ServiceChargeTiming.values.byName(
      json['serviceTiming'] as String? ?? 'beforeVat',
    ),
    note: json['note'] as String?,
    photoPath: json['photoPath'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );
}

class BillBreakdown {
  const BillBreakdown({
    required this.subtotal,
    required this.service,
    required this.vat,
    required this.tip,
    required this.shares,
    required this.itemShares,
    required this.serviceShares,
    required this.vatShares,
    required this.tipShares,
  });
  final int subtotal, service, vat, tip;
  final Map<String, int> shares;
  final Map<String, int> itemShares, serviceShares, vatShares, tipShares;
  int get total => subtotal + service + vat + tip;
}

BillBreakdown calculateBill(SplitBill bill) {
  Map<String, int> blank() => {
    for (final participant in bill.participants) participant.id: 0,
  };
  final itemShares = blank();
  final serviceShares = blank();
  final vatShares = blank();
  final tipShares = blank();

  void giveEvenly(Map<String, int> target, int amount, Iterable<String> ids) {
    final recipients = ids.where(target.containsKey).toSet().toList();
    if (recipients.isEmpty || amount == 0) return;
    final each = amount ~/ recipients.length;
    for (final id in recipients) {
      target[id] = target[id]! + each;
    }
    target[bill.payerId] =
        (target[bill.payerId] ?? 0) + amount - each * recipients.length;
  }

  void giveProportionally(
    Map<String, int> target,
    int amount,
    Map<String, int> weights,
  ) {
    final totalWeight = weights.values.fold<int>(
      0,
      (sum, value) => sum + value,
    );
    if (totalWeight == 0 || amount == 0) return;
    var allocated = 0;
    for (final participant in bill.participants) {
      final share = amount * (weights[participant.id] ?? 0) ~/ totalWeight;
      target[participant.id] = target[participant.id]! + share;
      allocated += share;
    }
    target[bill.payerId] = (target[bill.payerId] ?? 0) + amount - allocated;
  }

  var subtotal = 0;
  for (final item in bill.items.where((item) => item.amountMinor > 0)) {
    subtotal += item.amountMinor;
    giveEvenly(itemShares, item.amountMinor, item.participantIds);
  }
  final vatOnSubtotal = (subtotal * bill.vatPercent / 100).round();
  final serviceBase = bill.serviceTiming == ServiceChargeTiming.beforeVat
      ? subtotal
      : subtotal + vatOnSubtotal;
  final service = (serviceBase * bill.servicePercent / 100).round();
  final vat = bill.serviceTiming == ServiceChargeTiming.beforeVat
      ? ((subtotal + service) * bill.vatPercent / 100).round()
      : vatOnSubtotal;
  if (bill.serviceTiming == ServiceChargeTiming.beforeVat) {
    giveProportionally(serviceShares, service, itemShares);
    final vatWeights = blank();
    for (final participant in bill.participants) {
      vatWeights[participant.id] =
          itemShares[participant.id]! + serviceShares[participant.id]!;
    }
    giveProportionally(vatShares, vat, vatWeights);
  } else {
    giveProportionally(vatShares, vat, itemShares);
    final serviceWeights = blank();
    for (final participant in bill.participants) {
      serviceWeights[participant.id] =
          itemShares[participant.id]! + vatShares[participant.id]!;
    }
    giveProportionally(serviceShares, service, serviceWeights);
  }
  final tipIds = bill.tipParticipantIds.isEmpty
      ? bill.participants.map((e) => e.id)
      : bill.tipParticipantIds;
  giveEvenly(tipShares, bill.tipMinor, tipIds);
  final shares = blank();
  for (final participant in bill.participants) {
    final id = participant.id;
    shares[id] =
        itemShares[id]! + serviceShares[id]! + vatShares[id]! + tipShares[id]!;
  }
  return BillBreakdown(
    subtotal: subtotal,
    service: service,
    vat: vat,
    tip: bill.tipMinor,
    shares: shares,
    itemShares: itemShares,
    serviceShares: serviceShares,
    vatShares: vatShares,
    tipShares: tipShares,
  );
}

String billText(SplitBill bill) {
  final breakdown = calculateBill(bill);
  final names = {
    for (final participant in bill.participants)
      participant.id: participant.name,
  };
  String amount(int minor) =>
      '${(minor / 100).toStringAsFixed(2)} ${bill.currencyCode}';
  final lines = <String>[
    bill.title,
    'Total ${amount(breakdown.total)}',
    'Paid by ${names[bill.payerId] ?? 'Unknown'}',
    '',
    'Bill details',
    'Items: ${amount(breakdown.subtotal)}',
    if (breakdown.service > 0) 'Service: ${amount(breakdown.service)}',
    if (breakdown.vat > 0) 'VAT: ${amount(breakdown.vat)}',
    if (breakdown.tip > 0) 'Tip: ${amount(breakdown.tip)}',
    '',
    'What each person owes',
  ];
  for (final participant in bill.participants) {
    final items = bill.items
        .where((item) => item.participantIds.contains(participant.id))
        .map((item) => item.name)
        .join(', ');
    lines.add(
      '${participant.name}: ${amount(breakdown.shares[participant.id] ?? 0)}'
      '${items.isEmpty ? '' : ' — $items'}',
    );
  }
  if (bill.note?.isNotEmpty ?? false) lines.add('\nNote: ${bill.note}');
  return lines.join('\n');
}
