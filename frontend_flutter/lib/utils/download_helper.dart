import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void downloadFileFromUrl(String url, String filename) {
  if (kIsWeb) {
    try {
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..style.display = 'none';
      html.document.body?.children.add(anchor);
      anchor.click();
      anchor.remove();
    } catch (e) {
      html.window.open(url, '_blank');
    }
  }
}

class PickedAudio {
  final String name;
  final Uint8List bytes;
  PickedAudio({required this.name, required this.bytes});
}

Future<PickedAudio?> pickAudioFileWeb() {
  final completer = Completer<PickedAudio?>();
  if (kIsWeb) {
    try {
      final uploadInput = html.FileUploadInputElement()..accept = 'audio/*';
      uploadInput.click();
      uploadInput.onChange.listen((e) {
        final files = uploadInput.files;
        if (files != null && files.isNotEmpty) {
          final file = files[0];
          final reader = html.FileReader();
          reader.readAsArrayBuffer(file);
          reader.onLoadEnd.listen((e) {
            final bytes = reader.result as Uint8List;
            completer.complete(PickedAudio(name: file.name, bytes: bytes));
          });
        } else {
          completer.complete(null);
        }
      });
    } catch (e) {
      completer.complete(null);
    }
  } else {
    completer.complete(null);
  }
  return completer.future;
}
