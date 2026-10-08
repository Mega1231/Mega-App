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
