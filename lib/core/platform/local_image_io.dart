import 'dart:io';

import 'package:flutter/material.dart';

const supportsLocalImageFiles = true;

bool localImageExists(String path) => File(path).existsSync();

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
  Widget build(BuildContext context) {
    if (!localImageExists(path)) return _unavailable();
    return Image.file(
      File(path),
      fit: fit,
      errorBuilder: (_, _, _) => _unavailable(),
    );
  }

  Widget _unavailable() {
    WidgetsBinding.instance.addPostFrameCallback((_) => onUnavailable?.call());
    return const ColoredBox(
      color: Color(0x12061653),
      child: Center(child: Icon(Icons.image_not_supported_outlined)),
    );
  }
}
