import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'data/ledger_repository.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final preferences = await SharedPreferences.getInstance();
  final repository = SharedPreferencesLedgerRepository(preferences);
  final initialLedger = await repository.load();
  runApp(
    ProviderScope(
      overrides: [
        ledgerRepositoryProvider.overrideWithValue(repository),
        initialLedgerProvider.overrideWithValue(initialLedger),
      ],
      child: const BalanceMateApp(),
    ),
  );
}
