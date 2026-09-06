import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../app/theme.dart';
import '../core/formatters.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  String _currency = 'GBP';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(36),
                      gradient: const LinearGradient(
                        colors: [
                          BalanceMateColors.navy,
                          BalanceMateColors.cobalt,
                          BalanceMateColors.aqua,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: BalanceMateColors.cobalt.withValues(
                            alpha: .28,
                          ),
                          blurRadius: 32,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/icon/icon.png',
                      height: 180,
                      semanticLabel: 'BalanceMate',
                    ),
                  ),
                  const SizedBox(height: 34),
                  Text(
                    'Keep the balance\nbeautifully clear.',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      height: 1.04,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'A private place to remember what you owe and what is owed to you — even when life gets busy.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Your default currency',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _currency,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.currency_exchange_rounded),
                    ),
                    items: currencies.keys
                        .map(
                          (code) => DropdownMenuItem(
                            value: code,
                            child: Text(currencyLabel(code)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _currency = value!),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'You can use another currency for any transaction. BalanceMate will never convert your amounts.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 30),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text(
                      'Start keeping track',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    onPressed: () => ref
                        .read(ledgerProvider.notifier)
                        .finishOnboarding(_currency),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Stored only on this device for now.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
