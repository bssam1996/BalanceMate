import 'package:share_plus/share_plus.dart';

Future<void> exportJson(String content, String filename) async {
  await SharePlus.instance.share(ShareParams(text: content, subject: filename));
}
