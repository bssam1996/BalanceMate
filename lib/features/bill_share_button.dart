import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../core/platform/local_image.dart';
import '../core/split_bill.dart';

class BillShareButton extends StatefulWidget {
  const BillShareButton({super.key, required this.bill});

  final SplitBill bill;

  @override
  State<BillShareButton> createState() => _BillShareButtonState();
}

class _BillShareButtonState extends State<BillShareButton> {
  var _sharing = false;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Share bill',
    onPressed: _sharing ? null : _share,
    icon: const Icon(Icons.ios_share_rounded),
  );

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    final bill = widget.bill;
    final photoPath = bill.photoPath;
    try {
      var withPhoto = false;
      if (photoPath != null &&
          supportsLocalImageFiles &&
          localImageExists(photoPath)) {
        var choiceMade = false;
        final choice = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            void choose(bool? includePhoto) {
              if (choiceMade) return;
              choiceMade = true;
              Navigator.pop(dialogContext, includePhoto);
            }

            return AlertDialog(
              title: const Text('Share bill'),
              content: const Text(
                'Include the receipt photo with the bill breakdown?',
              ),
              actions: [
                TextButton(
                  onPressed: () => choose(null),
                  child: const Text('Cancel'),
                ),
                OutlinedButton(
                  onPressed: () => choose(false),
                  child: const Text('Without photo'),
                ),
                FilledButton.icon(
                  onPressed: () => choose(true),
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('With photo'),
                ),
              ],
            );
          },
        );
        if (!mounted || choice == null) return;
        withPhoto = choice;
      }

      // A picker/cache file may disappear while the choice dialog is open.
      if (withPhoto && !localImageExists(photoPath!)) {
        _showError(
          'The receipt photo is no longer available. Share again to send the bill without it.',
        );
        return;
      }
      final box = context.findRenderObject() as RenderBox?;
      await SharePlus.instance.share(
        ShareParams(
          text: billText(bill),
          subject: bill.title,
          files: withPhoto ? [XFile(photoPath!)] : null,
          sharePositionOrigin: box == null
              ? null
              : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      if (mounted) {
        _showError('Could not share the bill. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
