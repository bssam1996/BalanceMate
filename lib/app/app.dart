import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/home_shell.dart';
import '../features/onboarding_page.dart';
import 'providers.dart';
import 'theme.dart';

class BalanceMateApp extends ConsumerWidget {
  const BalanceMateApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledger = ref.watch(ledgerProvider);
    return MaterialApp(
      title: 'BalanceMate',
      debugShowCheckedModeBanner: false,
      theme: balanceMateTheme(Brightness.light),
      darkTheme: balanceMateTheme(Brightness.dark),
      themeMode: ledger.settings.themeMode,
      home: ledger.settings.hasCompletedOnboarding
          ? const HomeShell()
          : const OnboardingPage(),
    );
  }
}
