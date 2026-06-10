// One-off: regenerate assets/app_icon.ico from assets/sakrylle_icon.png.
// Run: dart run tool/generate_ico.dart
import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final src = img.decodePng(File('assets/sakrylle_icon.png').readAsBytesSync());
  if (src == null) {
    stderr.writeln('Failed to decode assets/sakrylle_icon.png');
    exit(1);
  }
  final sizes = [256, 128, 64, 48, 32, 16];
  final images = [
    for (final s in sizes)
      img.copyResize(
        src,
        width: s,
        height: s,
        interpolation: img.Interpolation.average,
      ),
  ];
  final bytes = img.IcoEncoder().encodeImages(images);
  File('assets/app_icon.ico').writeAsBytesSync(bytes);
  stdout.writeln('Wrote assets/app_icon.ico (${bytes.length} bytes)');
}
