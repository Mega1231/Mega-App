import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

/// Starts a browser download of [bytes]. Returns '' (there is no local path).
Future<String> saveGeneratedFile(Uint8List bytes, String fileName,
    {String mimeType = 'application/pdf'}) async {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName;
  web.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
  return '';
}

/// Opens [bytes] in a new browser tab (PDFs and photos open in the browser's
/// own viewer). Falls back to a download if the pop-up is blocked.
Future<void> openFileInBrowser(Uint8List bytes, String fileName,
    {required String mimeType}) async {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  final tab = web.window.open(url, '_blank');
  if (tab == null) {
    await saveGeneratedFile(bytes, fileName, mimeType: mimeType);
  }
  // Leave the URL alive long enough for the new tab to load it.
  Future.delayed(const Duration(minutes: 1), () => web.URL.revokeObjectURL(url));
}
