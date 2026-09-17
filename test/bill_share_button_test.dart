import 'dart:async';
import 'dart:io';

import 'package:balancemate/core/split_bill.dart';
import 'package:balancemate/features/bill_share_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('dev.fluttercommunity.plus/share');
final _shareButton = find.byWidgetPredicate(
  (widget) => widget is IconButton && widget.tooltip == 'Share bill',
);

SplitBill _bill({String? photoPath}) => SplitBill(
  id: 'bill',
  title: 'Dinner',
  currencyCode: 'GBP',
  participants: const [BillParticipant(id: 'a', name: 'Alex')],
  items: const [
    BillItem(
      id: 'item',
      name: 'Soup',
      amountMinor: 1250,
      quantity: 2,
      participantIds: ['a'],
    ),
  ],
  payerId: 'a',
  billDate: DateTime(2026),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  photoPath: photoPath,
);

File _receipt() {
  final directory = Directory.systemTemp.createTempSync('balancemate-share-');
  final photo = File(
    'assets/icon/icon.png',
  ).copySync('${directory.path}/receipt.png');
  addTearDown(() {
    if (photo.existsSync()) photo.deleteSync();
    directory.deleteSync();
  });
  return photo;
}

Future<void> _pump(WidgetTester tester, SplitBill bill) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        appBar: AppBar(actions: [BillShareButton(bill: bill)]),
      ),
    ),
  );
}

Future<void> _openShare(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Share bill'));
  await tester.pumpAndSettle();
}

void main() {
  final calls = <Map<Object?, Object?>>[];
  var fail = false;
  Completer<String>? pending;

  setUp(() {
    calls.clear();
    fail = false;
    pending = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          expectSync(call.method, 'share');
          calls.add(Map<Object?, Object?>.from(call.arguments as Map));
          if (fail) throw PlatformException(code: 'unavailable');
          return pending != null ? pending!.future : 'test.target';
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null),
  );

  testWidgets('without an attached photo shares the current text immediately', (
    tester,
  ) async {
    final bill = _bill();
    await _pump(tester, bill);
    await _openShare(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(calls.single['text'], billText(bill));
    expect(calls.single['subject'], 'Dinner');
    expect(calls.single.containsKey('paths'), isFalse);
    expect(calls.single['originWidth'], greaterThan(0));
    expect(calls.single['originHeight'], greaterThan(0));
  });

  for (final withPhoto in [true, false]) {
    testWidgets(
      'photo choice shares ${withPhoto ? 'image and text' : 'text only'}',
      (tester) async {
        final photo = _receipt();
        final bill = _bill(photoPath: photo.path);
        await _pump(tester, bill);
        await _openShare(tester);
        expect(calls, isEmpty);
        expect(find.text('With photo'), findsOneWidget);
        expect(find.text('Without photo'), findsOneWidget);
        await tester.tap(find.text(withPhoto ? 'With photo' : 'Without photo'));
        await tester.pumpAndSettle();
        expect(calls, hasLength(1));
        expect(calls.single['text'], billText(bill));
        expect(calls.single['subject'], bill.title);
        if (withPhoto) {
          expect(calls.single['paths'], [photo.path]);
          expect(calls.single['mimeTypes'], ['image/png']);
        } else {
          expect(calls.single.containsKey('paths'), isFalse);
        }
        expect(photo.existsSync(), isTrue);
      },
    );
  }

  testWidgets('cancelling or dismissing the choice shares nothing', (
    tester,
  ) async {
    final photo = _receipt();
    await _pump(tester, _bill(photoPath: photo.path));
    await _openShare(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
    await _openShare(tester);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
    expect(tester.widget<IconButton>(_shareButton).onPressed, isNotNull);
  });

  testWidgets('a missing attachment keeps direct text sharing available', (
    tester,
  ) async {
    final photo = _receipt();
    photo.deleteSync();
    await _pump(tester, _bill(photoPath: photo.path));
    await _openShare(tester);
    expect(find.byType(AlertDialog), findsNothing);
    expect(calls.single.containsKey('paths'), isFalse);
  });

  testWidgets('photo removed during the choice can be retried as text', (
    tester,
  ) async {
    final photo = _receipt();
    await _pump(tester, _bill(photoPath: photo.path));
    await _openShare(tester);
    photo.deleteSync();
    await tester.tap(find.text('With photo'));
    await tester.pumpAndSettle();
    expect(calls, isEmpty);
    expect(
      find.textContaining('The receipt photo is no longer available.'),
      findsOneWidget,
    );
    await _openShare(tester);
    expect(calls.single.containsKey('paths'), isFalse);
  });

  testWidgets('a failed share can be retried without the photo', (
    tester,
  ) async {
    final photo = _receipt();
    await _pump(tester, _bill(photoPath: photo.path));
    fail = true;
    await _openShare(tester);
    await tester.tap(find.text('With photo'));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not share the bill. Please try again.'),
      findsOneWidget,
    );
    fail = false;
    await _openShare(tester);
    await tester.tap(find.text('Without photo'));
    await tester.pumpAndSettle();
    expect(calls, hasLength(2));
    expect(calls.last.containsKey('paths'), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('repeat taps open one choice and submit one share', (
    tester,
  ) async {
    final photo = _receipt();
    await _pump(tester, _bill(photoPath: photo.path));
    final open = tester.widget<IconButton>(_shareButton).onPressed!;
    open();
    open();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    pending = Completer<String>();
    final choose = tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'With photo'))
        .onPressed!;
    choose();
    choose();
    await tester.pumpAndSettle();
    expect(
      find.text('Could not share the bill. Please try again.'),
      findsNothing,
    );
    expect(
      find.textContaining('The receipt photo is no longer available.'),
      findsNothing,
    );
    expect(calls, hasLength(1));
    expect(tester.widget<IconButton>(_shareButton).onPressed, isNull);
    pending!.complete('test.target');
    await tester.pumpAndSettle();
    expect(tester.widget<IconButton>(_shareButton).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });
}
