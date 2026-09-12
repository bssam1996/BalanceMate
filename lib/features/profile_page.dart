import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../app/providers.dart';
import '../core/input_limits.dart';
import '../data/cloud_sync_service.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Your profile')),
    body: StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null)
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_sync_rounded, size: 64),
                  const SizedBox(height: 20),
                  Text(
                    'Back up your balances',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Sign in with Google to keep your profile and ledger available across your devices.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  GoogleSignInButton(
                    onPressed: () async {
                      try {
                        await CloudSyncService.instance.signInWithGoogle();
                        await ref.read(ledgerProvider.notifier).syncFromCloud();
                      } catch (error) {
                        if (context.mounted)
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Sign-in failed: $error')),
                          );
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, profileSnapshot) {
            final profile =
                profileSnapshot.data?.data() ?? const <String, dynamic>{};
            final displayName =
                profile['displayName'] as String? ??
                user.displayName ??
                'BalanceMate member';
            final email = profile['email'] as String? ?? user.email ?? '';
            final photoUrl = profile['photoUrl'] as String? ?? user.photoURL;
            final phone = profile['phone'] as String?;
            final note = profile['note'] as String?;
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 46,
                    backgroundImage: photoUrl == null
                        ? null
                        : NetworkImage(photoUrl),
                    child: photoUrl == null ? Text(displayName[0]) : null,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  displayName,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(email, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Personal information',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => showEditProfileSheet(
                                context,
                                displayName: displayName,
                                phone: phone,
                                note: note,
                              ),
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              label: const Text('Edit'),
                            ),
                          ],
                        ),
                        const Divider(),
                        _ProfileValue(
                          icon: Icons.phone_outlined,
                          label: 'Phone',
                          value: phone ?? 'Not added',
                        ),
                        const SizedBox(height: 14),
                        _ProfileValue(
                          icon: Icons.notes_rounded,
                          label: 'Personal note',
                          value: note ?? 'Not added',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                FilledButton.icon(
                  onPressed: () async {
                    await CloudSyncService.instance.upload(
                      ref.read(ledgerProvider),
                    );
                    if (context.mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Your ledger is backed up.'),
                        ),
                      );
                  },
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: const Text('Back up now'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => FirebaseAuth.instance.signOut(),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sign out'),
                ),
              ],
            );
          },
        );
      },
    ),
  );
}

class _ProfileValue extends StatelessWidget {
  const _ProfileValue({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 2),
            Text(value),
          ],
        ),
      ),
    ],
  );
}

Future<void> showEditProfileSheet(
  BuildContext context, {
  required String displayName,
  String? phone,
  String? note,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) =>
        EditProfileSheet(displayName: displayName, phone: phone, note: note),
  );
}

class EditProfileSheet extends StatefulWidget {
  const EditProfileSheet({
    super.key,
    required this.displayName,
    this.phone,
    this.note,
  });
  final String displayName;
  final String? phone;
  final String? note;
  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  late final nameController = TextEditingController(text: widget.displayName);
  late final phoneController = TextEditingController(text: widget.phone);
  late final noteController = TextEditingController(text: widget.note);

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      4,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Edit personal information',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'This information is stored privately in your BalanceMate profile.',
          ),
          const SizedBox(height: 22),
          TextField(
            controller: nameController,
            textCapitalization: TextCapitalization.words,
            maxLength: InputLimits.name,
            decoration: const InputDecoration(
              labelText: 'Name',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            maxLength: InputLimits.phone,
            decoration: const InputDecoration(
              labelText: 'Phone number (optional)',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: noteController,
            maxLines: 3,
            maxLength: InputLimits.note,
            decoration: const InputDecoration(
              labelText: 'Personal note (optional)',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              await CloudSyncService.instance.updatePersonalProfile(
                displayName: nameController.text,
                phone: phoneController.text,
                note: noteController.text,
              );
              if (mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.check_rounded),
            label: const Text('Save profile'),
          ),
        ],
      ),
    ),
  );
}

class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    width: double.infinity,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F1F1F),
        side: const BorderSide(color: Color(0xFF747775)),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset('assets/brand/google_g.svg', width: 18, height: 18),
          const SizedBox(width: 12),
          const Text('Sign in with Google'),
        ],
      ),
    ),
  );
}
