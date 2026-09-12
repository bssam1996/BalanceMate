import 'package:flutter/material.dart';

/// Browser builds cannot retain a device file path after the picker closes.
const supportsLocalImageFiles = false;

bool localImageExists(String path) => false;

class LocalImage extends StatelessWidget {
  const LocalImage({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
    this.onUnavailable,
  });

  final String path;
  final BoxFit fit;
  final VoidCallback? onUnavailable;

  @override
  Widget build(BuildContext context) => const _MissingLocalImage();
}

class _MissingLocalImage extends StatelessWidget {
  const _MissingLocalImage();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0x12061653),
    child: Center(child: Icon(Icons.image_not_supported_outlined)),
  );
}
