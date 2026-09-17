import 'input_limits.dart';

/// Editable, session-only data. Incomplete rows must never be persisted as items.
class BillImportDraft {
  BillImportDraft({
    required this.id,
    required this.sourceRecord,
    required this.name,
    required this.quantityText,
    required this.priceText,
    this.sourceText = '',
    this.structureError,
    Set<String>? participantIds,
  }) : participantIds = participantIds ?? <String>{};

  final String id;
  final int sourceRecord;
  final String sourceText;
  String name, quantityText, priceText;
  String? structureError;
  final Set<String> participantIds;

  int? get quantity => parseBillImportQuantity(quantityText);
  int? get amountMinor => parseBillImportPrice(priceText);
  int? get totalMinor {
    final count = quantity;
    final price = amountMinor;
    if (count == null || price == null) return null;
    return count * price;
  }

  String? get nameError => name.trim().isEmpty
      ? 'Enter an item name.'
      : name.trim().length > InputLimits.itemName
      ? 'Use at most ${InputLimits.itemName} characters.'
      : name.contains('\n') || name.contains('\r')
      ? 'Keep the item name on one line.'
      : null;

  String? get quantityError => quantity == null
      ? 'Enter a whole number from 1 to ${InputLimits.maxBillItemQuantity}.'
      : null;

  String? get priceError => amountMinor == null
      ? 'Enter a positive unit price, for example 12.50 (up to 999999999.99).'
      : totalMinor != null && totalMinor! > InputLimits.maxAmountMinor
      ? 'The item total is too large. Reduce price or quantity.'
      : null;

  bool get isValid =>
      structureError == null &&
      nameError == null &&
      quantityError == null &&
      priceError == null;

  String? get error =>
      structureError ?? nameError ?? quantityError ?? priceError;

  bool matches(String otherName, int otherQuantity, int otherPrice) =>
      name.trim() == otherName.trim() &&
      quantity == otherQuantity &&
      amountMinor == otherPrice;
}

int? parseBillImportQuantity(String text) {
  final value = text.trim();
  if (!RegExp(r'^[0-9]+$').hasMatch(value)) return null;
  final count = int.tryParse(value);
  return count != null && count >= 1 && count <= InputLimits.maxBillItemQuantity
      ? count
      : null;
}

/// Decimal conversion stays exact on Dart VM and web; no floating-point parse.
int? parseBillImportPrice(String text) {
  final match = RegExp(
    r'^([0-9]+)(?:\.([0-9]{1,2}))?$',
  ).firstMatch(text.trim());
  if (match == null) return null;
  final whole = int.tryParse(match[1]!);
  if (whole == null || whole > InputLimits.maxAmountMinor ~/ 100) return null;
  final fraction = int.parse((match[2] ?? '').padRight(2, '0'));
  final minor = whole * 100 + fraction;
  return minor > 0 && minor <= InputLimits.maxAmountMinor ? minor : null;
}

/// Two independent rows, preserving quantity and total, with fresh assignments.
List<BillImportDraft> splitBillImportDraft(BillImportDraft row, int first) {
  if (!row.isValid || first < 1 || first >= row.quantity!) {
    throw ArgumentError(
      'Split quantities must be positive and preserve the total.',
    );
  }
  return [
    for (final (index, count) in [first, row.quantity! - first].indexed)
      BillImportDraft(
        id: '${row.id}/$index',
        sourceRecord: row.sourceRecord,
        sourceText: row.sourceText,
        name: row.name,
        quantityText: '$count',
        priceText: row.priceText,
      ),
  ];
}

class BillImportResult {
  const BillImportResult({this.rows = const [], this.error});
  final List<BillImportDraft> rows;
  final String? error;
}

/// A bounded three-field CSV dialect with newline/semicolon record separators.
BillImportResult parseBillItems(String input) {
  if (input.length > InputLimits.maxBillImportCharacters) {
    return const BillImportResult(
      error:
          'This list is too long. Paste at most 32,768 characters; nothing was imported.',
    );
  }
  var text = input.replaceFirst(RegExp(r'^\uFEFF'), '').trim();
  text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  if (text.startsWith('```')) {
    final fence = RegExp(
      r'^```(?:csv|text)?\n([\s\S]*?)\n```$',
    ).firstMatch(text);
    if (fence == null) {
      return const BillImportResult(
        error:
            'Paste only the item list, without explanation, tables, or extra code blocks.',
      );
    }
    text = fence[1]!.trim();
  }
  if (text.contains('```')) {
    return const BillImportResult(
      error: 'Paste one item list without extra code blocks.',
    );
  }
  if (text.isEmpty) {
    return const BillImportResult(
      error: 'No items found. Paste an item list or add items manually.',
    );
  }

  final rows = <BillImportDraft>[];
  var fields = <String>[];
  var field = StringBuffer();
  var quoted = false;
  var closedQuote = false;
  var recordStart = 0;
  var record = 0;
  var firstRecord = true;

  BillImportResult syntaxError(String message) => BillImportResult(
    error:
        'Row ${record + 1}: $message Fix the original text and review again.',
  );

  for (var i = 0; i <= text.length; i++) {
    final end = i == text.length;
    final char = end ? '\n' : text[i];
    if (quoted) {
      if (end || char == '\n') {
        return syntaxError('Close quotes on the same line as the item.');
      }
      if (char == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = false;
          closedQuote = true;
        }
      } else {
        field.write(char);
      }
      continue;
    }
    if (char == ',' || char == ';' || char == '\n') {
      fields.add(field.toString().trim());
      field = StringBuffer();
      closedQuote = false;
      if (char == ',') continue;
      final raw = text.substring(recordStart, i).trim();
      recordStart = i + 1;
      if (raw.isNotEmpty) {
        if (firstRecord &&
            fields.join(',') == 'item,quantity,unit_price' &&
            fields.length == 3) {
          firstRecord = false;
          fields = [];
          continue;
        }
        firstRecord = false;
        record++;
        if (record > InputLimits.maxBillItems) {
          return const BillImportResult(
            error:
                'A list can contain up to 100 items. Shorten the original text; nothing was imported.',
          );
        }
        rows.add(
          BillImportDraft(
            id: 'row-$record',
            sourceRecord: record,
            sourceText: raw,
            name: fields.first,
            quantityText: fields.length > 1 ? fields[1] : '',
            priceText: fields.length > 2 ? fields[2] : '',
            structureError: fields.length == 3
                ? null
                : 'Expected item, quantity, and unit price. Quote names containing commas. Edit this row or fix the original text.',
          ),
        );
      }
      fields = [];
    } else if (char == '"') {
      if (field.toString().trim().isNotEmpty || closedQuote) {
        return syntaxError(
          'Put quotes around the entire field and double any quotes inside it.',
        );
      }
      field = StringBuffer();
      quoted = true;
    } else {
      if (closedQuote && char.trim().isNotEmpty) {
        return syntaxError(
          'Only a comma or record separator can follow a quoted field.',
        );
      }
      field.write(char);
    }
  }
  return rows.isEmpty
      ? const BillImportResult(
          error: 'No items found. Paste an item list or add items manually.',
        )
      : BillImportResult(rows: rows);
}
