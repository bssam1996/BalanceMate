import 'package:balancemate/core/bill_items_import.dart';
import 'package:balancemate/core/bill_items_prompt.dart';
import 'package:balancemate/core/input_limits.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prompt example has exact unit prices and subtotal', () {
    final prompt = buildBillItemsPrompt('EGP');
    expect(prompt, contains('selected bill currency is EGP'));
    final result = parseBillItems(
      prompt.split('(do not include these example items):\n').last,
    );
    expect(result.error, isNull);
    expect(result.rows.every((row) => row.isValid), isTrue);
    expect(result.rows.map((row) => row.totalMinor), [2500, 400, 675]);
    expect(result.rows.fold<int>(0, (sum, row) => sum + row.totalMinor!), 3575);
    expect(result.rows.every((row) => row.participantIds.isEmpty), isTrue);
  });

  test(
    'compact and multiline forms preserve Unicode and quoted delimiters',
    () {
      for (final separator in ['\n', '\r\n', ';']) {
        final result = parseBillItems(
          [
            '"Tea, mint",3,2.25',
            '"Chef\'s ""special""; large",1,9.5',
            'شاي بالنعناع,2,10',
          ].join(separator),
        );
        expect(result.error, isNull);
        expect(result.rows.every((row) => row.isValid), isTrue);
        expect(result.rows.map((row) => row.name), [
          'Tea, mint',
          'Chef\'s "special"; large',
          'شاي بالنعناع',
        ]);
        expect(result.rows.map((row) => row.amountMinor), [225, 950, 1000]);
        expect(result.rows.map((row) => row.sourceRecord), [1, 2, 3]);
      }
    },
  );

  test('accepts optional header, BOM, whitespace, blank lines and one fence', () {
    for (final fence in ['', 'csv', 'text']) {
      final result = parseBillItems(
        '\uFEFF```$fence\r\n item,quantity,unit_price\r\n\r\n "Tea, mint" , 2 , 1.05 ;\r\n```',
      );
      expect(result.error, isNull);
      expect(result.rows.single.name, 'Tea, mint');
      expect(result.rows.single.totalMinor, 210);
    }
  });

  test(
    'rejects broken quoting and misleading wrappers without partial rows',
    () {
      for (final input in [
        'Soup,1,2\n"Tea,1,3',
        'Soup,1,2\n"Tea\nmint",1,3',
        'Soup,1,2\n"Tea"oops,1,3',
        'Te"a,1,3',
        'Here is your list:\n```csv\nTea,1,2\n```',
        '```csv\nTea,1,2\n```\nExplanation',
        '```json\n[]\n```',
        '```\nTea,1,2\n```\n```\nSoup,1,3\n```',
      ]) {
        final result = parseBillItems(input);
        expect(result.error, isNotNull, reason: input);
        expect(result.rows, isEmpty, reason: input);
      }
    },
  );

  test(
    'unknown values and malformed nonempty rows remain available for correction',
    () {
      final result = parseBillItems(
        'Soup,1,2\nTea,,\n,1,4\nTea, mint,2,3\n,,,',
      );
      expect(result.error, isNull);
      expect(result.rows, hasLength(5));
      expect(result.rows.first.isValid, isTrue);
      expect(result.rows.skip(1).every((row) => !row.isValid), isTrue);
      expect(result.rows[1].quantityText, isEmpty);
      expect(result.rows[1].priceText, isEmpty);
      expect(result.rows[3].structureError, isNotNull);
      expect(result.rows[3].sourceText, 'Tea, mint,2,3');
    },
  );

  test('prices are exact, bounded and never guessed or rounded', () {
    for (final (source, expected) in [
      ('0.01', 1),
      ('1', 100),
      ('1.1', 110),
      ('1.01', 101),
      ('999999999.99', InputLimits.maxAmountMinor),
    ]) {
      expect(parseBillImportPrice(source), expected);
    }
    for (final input in [
      '',
      '0',
      '-1',
      '+1',
      '1e2',
      'NaN',
      'Infinity',
      '.5',
      '1.',
      '1.001',
      '1,20',
      '1,000',
      '£1',
      '١.٢٥',
      '1000000000',
      '9' * 200,
    ]) {
      expect(parseBillImportPrice(input), isNull, reason: input);
    }
    expect(parseBillItems('Item,2,999999999.99').rows.single.isValid, isFalse);
    expect(parseBillItems('Item,1,999999999.99').rows.single.isValid, isTrue);
  });

  test('validates quantities and names using existing model limits', () {
    for (final source in ['', '0', '-1', '1.5', '10000', '١', '9' * 100]) {
      expect(parseBillImportQuantity(source), isNull, reason: source);
    }
    expect(parseBillImportQuantity('9999'), 9999);
    expect(parseBillItems('${'x' * 80},1,1').rows.single.isValid, isTrue);
    expect(parseBillItems('${'x' * 81},1,1').rows.single.nameError, isNotNull);
  });

  test('bounds input and records without silently taking a subset', () {
    expect(
      parseBillItems('x' * (InputLimits.maxBillImportCharacters + 1)).error,
      isNotNull,
    );
    expect(
      parseBillItems(List.filled(100, 'Tea,1,1').join('\n')).rows,
      hasLength(100),
    );
    final excess = parseBillItems(List.filled(101, 'Tea,1,1').join(';'));
    expect(excess.error, isNotNull);
    expect(excess.rows, isEmpty);
    for (final empty in ['', '\n\n', 'item,quantity,unit_price', '; ;']) {
      expect(parseBillItems(empty).error, contains('No items found'));
    }
  });

  test('repeated rows keep independent identities and assignments', () {
    final rows = parseBillItems('Tea,1,1;Tea,1,1').rows;
    expect(rows, hasLength(2));
    expect(rows.first.id, isNot(rows.last.id));
    rows.first.participantIds.add('Alex');
    expect(rows.last.participantIds, isEmpty);
  });

  test(
    'splitting preserves totals, resets assignment and supports repeated splits',
    () {
      final row = parseBillItems('Burger,4,12.50').rows.single;
      row.participantIds.add('Alex');
      final parts = splitBillImportDraft(row, 1);
      expect(parts.map((part) => part.quantity), [1, 3]);
      expect(
        parts.fold<int>(0, (sum, part) => sum + part.totalMinor!),
        row.totalMinor,
      );
      expect(parts.every((part) => part.participantIds.isEmpty), isTrue);
      final splitAgain = [parts.first, ...splitBillImportDraft(parts.last, 2)];
      expect(splitAgain.map((part) => part.id).toSet(), hasLength(3));
      expect(splitAgain.map((part) => part.quantity), [1, 2, 1]);
      for (final count in [0, -1, 4, 5]) {
        expect(() => splitBillImportDraft(row, count), throwsArgumentError);
      }
    },
  );
}
