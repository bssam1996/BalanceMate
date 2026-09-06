import 'dart:html' as html;

Future<void> exportJson(String content, String filename) async {
  final url = html.Url.createObjectUrlFromBlob(
    html.Blob([content], 'application/json'),
  );
  html.AnchorElement(href: url)
    ..download = filename
    ..click();
  html.Url.revokeObjectUrl(url);
}
