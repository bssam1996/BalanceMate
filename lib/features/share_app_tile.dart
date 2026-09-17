import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

// Keep the listing ID aligned with android/app/build.gradle.kts.
const balanceMateAndroidPackageId = 'com.bplusplus.balancemate';
const balanceMatePlayStoreUrl =
    'https://play.google.com/store/apps/details?id=$balanceMateAndroidPackageId';

class ShareAppTile extends StatefulWidget {
  const ShareAppTile({super.key});

  @override
  State<ShareAppTile> createState() => _ShareAppTileState();
}

class _ShareAppTileState extends State<ShareAppTile> {
  var _sharing = false;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: const Icon(Icons.share_outlined),
    title: const Text('Share app'),
    subtitle: const Text('Send the Google Play link to friends'),
    trailing: const Icon(Icons.chevron_right),
    enabled: !_sharing,
    onTap: _sharing ? null : _share,
  );

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          subject: 'BalanceMate',
          text: 'Get BalanceMate on Google Play:\n$balanceMatePlayStoreUrl',
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not share the app. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }
}

class RateAppTile extends StatefulWidget {
  const RateAppTile({super.key});

  @override
  State<RateAppTile> createState() => _RateAppTileState();
}

class _RateAppTileState extends State<RateAppTile> {
  var _opening = false;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: const Icon(Icons.star_outline_rounded),
    title: const Text('Rate me'),
    subtitle: const Text('Rate and review BalanceMate on Google Play'),
    trailing: const Icon(Icons.open_in_new_rounded),
    enabled: !_opening,
    onTap: _opening ? null : _openListing,
  );

  Future<void> _openListing() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        try {
          if (await launchUrl(
            Uri.parse('market://details?id=$balanceMateAndroidPackageId'),
            mode: LaunchMode.externalApplication,
          )) {
            return;
          }
        } catch (_) {
          // Devices without Google Play can still open the web listing.
        }
      }
      final opened = await launchUrl(
        Uri.parse(balanceMatePlayStoreUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!opened && mounted) _showError();
    } catch (_) {
      if (mounted) _showError();
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  void _showError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not open Google Play. Please try again.'),
      ),
    );
  }
}
