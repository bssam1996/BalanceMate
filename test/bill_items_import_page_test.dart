import 'package:balancemate/app/theme.dart';
import 'package:balancemate/core/bill_items_import.dart';
import 'package:balancemate/core/split_bill.dart';
import 'package:balancemate/features/bill_items_import_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _people = [
  BillParticipant(id: 'a', name: 'Alex'),
  BillParticipant(id: 'b', name: 'Jamie'),
];
final _textField = find.byKey(const ValueKey('bill-import-text'));

Finder _field(String name) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == name,
);

Future<void> _tap(WidgetTester tester, String text) async {
  await tester.pump();
  final target = find.text(text);
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      250,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<ValueNotifier<List<BillImportDraft>?>> _pumpImport(
  WidgetTester tester, {
  List<BillItem> existing = const [],
  Size size = const Size(700, 1300),
  double textScale = 1,
  double keyboardHeight = 0,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final result = ValueNotifier<List<BillImportDraft>?>(null);
  await tester.pumpWidget(
    MaterialApp(
      theme: balanceMateTheme(Brightness.light),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          viewInsets: EdgeInsets.only(bottom: keyboardHeight),
        ),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              result.value = await Navigator.push<List<BillImportDraft>>(
                context,
                MaterialPageRoute(
                  builder: (_) => BillItemsImportPage(
                    currencyCode: 'GBP',
                    participants: _people,
                    existingItems: existing,
                  ),
                ),
              );
            },
            child: const Text('Import'),
          ),
        ),
      ),
    ),
  );
  await _tap(tester, 'Import');
  return result;
}

Future<void> _review(WidgetTester tester, String text) async {
  if (_textField.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      _textField,
      250,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.enterText(_textField, text);
  await _tap(tester, 'Review items');
}

void main() {
  testWidgets(
    'review action stays above the keyboard and text survives app switching',
    (tester) async {
      await _pumpImport(
        tester,
        size: const Size(390, 844),
        keyboardHeight: 300,
      );
      await tester.scrollUntilVisible(
        _textField,
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.enterText(_textField, 'Tea,1,2');
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(_textField).controller!.text, 'Tea,1,2');
      expect(
        tester
            .getBottomRight(find.widgetWithText(FilledButton, 'Review items'))
            .dy,
        lessThanOrEqualTo(544),
      );
      await _tap(tester, 'Review items');
      expect(find.text('Tea'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('correct, split, assign, navigate back, and commit once', (
    tester,
  ) async {
    final result = await _pumpImport(tester);
    await _review(tester, 'Burger,3,12.50\nTea,1,');
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Assign people'),
          )
          .onPressed,
      isNull,
    );
    await _tap(tester, 'Tea');
    await tester.enterText(_field('Unit price'), '2.25');
    await _tap(tester, 'Keep changes');
    await _tap(tester, 'Assign people');
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Next item'))
          .onPressed,
      isNull,
    );
    await _tap(tester, 'Split quantity');
    await tester.enterText(_field('Quantity in first part'), '2');
    await _tap(tester, 'Create two rows');
    expect(find.text('Item 1 of 3'), findsOneWidget);
    await _tap(tester, 'Alex');
    await _tap(tester, 'Next item');
    await _tap(tester, 'Jamie');
    await _tap(tester, 'Next item');
    await _tap(tester, 'Everyone');
    await _tap(tester, 'Review summary');
    expect(result.value, isNull);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(
      find.text('3 of 3 items assigned. You choose the people for every item.'),
      findsOneWidget,
    );
    await _tap(tester, 'Review summary');
    final commit = tester
        .widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Add 3 items to bill'),
        )
        .onPressed!;
    commit();
    commit();
    await tester.pumpAndSettle();
    expect(find.text('Import'), findsOneWidget);
    expect(result.value, hasLength(3));
    expect(result.value!.map((row) => row.quantity), [2, 1, 1]);
    expect(result.value!.map((row) => row.participantIds), [
      {'a'},
      {'b'},
      {'a', 'b'},
    ]);
    expect(
      result.value!.fold<int>(0, (sum, row) => sum + row.totalMinor!),
      3975,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancel discards draft and does not return a partial batch', (
    tester,
  ) async {
    final result = await _pumpImport(tester);
    await _review(tester, 'Tea,1,2');
    await _tap(tester, 'Assign people');
    await _tap(tester, 'Alex');
    await _tap(tester, 'Cancel import');
    expect(find.text('Import'), findsOneWidget);
    expect(result.value, isNull);
  });

  testWidgets(
    'reparse explains replacing edits and resets assignments only on confirmation',
    (tester) async {
      await _pumpImport(tester);
      await _review(tester, 'Tea,1,2');
      await _tap(tester, 'Assign people');
      await _tap(tester, 'Alex');
      await _tap(tester, 'Back to item review');
      await _tap(tester, 'Original text');
      await tester.enterText(_textField, 'Coffee,2,3');
      await _tap(tester, 'Review items');
      await _tap(tester, 'Keep current review');
      await _tap(tester, 'Return to current review');
      await _tap(tester, 'Assign people');
      expect(
        tester
            .widget<CheckboxListTile>(
              find.widgetWithText(CheckboxListTile, 'Alex'),
            )
            .value,
        isTrue,
      );
      await _tap(tester, 'Back to item review');
      await _tap(tester, 'Original text');
      await _tap(tester, 'Review items');
      await _tap(tester, 'Use new list');
      expect(find.text('Coffee'), findsOneWidget);
      await _tap(tester, 'Assign people');
      expect(
        tester
            .widget<CheckboxListTile>(
              find.widgetWithText(CheckboxListTile, 'Alex'),
            )
            .value,
        isFalse,
      );
    },
  );

  testWidgets(
    'enforces remaining capacity and allows explicit duplicate removal',
    (tester) async {
      await _pumpImport(
        tester,
        existing: [
          for (var i = 0; i < 99; i++)
            BillItem(
              id: '$i',
              name: 'Tea',
              amountMinor: 200,
              participantIds: const ['a'],
            ),
        ],
      );
      await _review(tester, 'Tea,1,2;Coffee,1,3');
      expect(
        find.text('Possible duplicate · kept for you to check'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Assign people'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('Remove Coffee'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Assign people'),
            )
            .onPressed,
        isNotNull,
      );
    },
  );

  testWidgets(
    'clipboard prompt and paste work; clipboard denial has a fallback',
    (tester) async {
      String? copied;
      var deny = false;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          if (call.method == 'Clipboard.getData') {
            if (deny) throw PlatformException(code: 'denied');
            return {'text': 'Tea,1,2'};
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await _pumpImport(tester);
      await _tap(tester, 'Copy AI prompt');
      expect(copied, contains('selected bill currency is GBP'));
      await _tap(tester, 'Paste from clipboard');
      expect(tester.widget<TextField>(_textField).controller!.text, 'Tea,1,2');
      deny = true;
      await _tap(tester, 'Paste from clipboard');
      expect(
        find.text(
          'Clipboard access is unavailable. Paste directly into the text field.',
        ),
        findsOneWidget,
      );
      expect(tester.widget<TextField>(_textField).controller!.text, 'Tea,1,2');
    },
  );

  testWidgets('narrow screen and large text can complete the import', (
    tester,
  ) async {
    await _pumpImport(tester, size: const Size(360, 800), textScale: 1.6);
    expect(tester.takeException(), isNull);
    await _review(tester, 'شاي بالنعناع,2,10.50');
    expect(tester.takeException(), isNull);
    await _tap(tester, 'Assign people');
    expect(tester.takeException(), isNull);
    await _tap(tester, 'Everyone');
    await _tap(tester, 'Review summary');
    expect(tester.takeException(), isNull);
    await _tap(tester, 'Add 1 item to bill');
    expect(tester.takeException(), isNull);
  });
}
