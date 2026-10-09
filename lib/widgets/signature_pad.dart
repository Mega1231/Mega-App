import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Holds the strokes drawn on a [SignaturePad] and exports them as a PNG.
class SignatureController extends ChangeNotifier {
  final List<List<Offset>> _strokes = [];
  Size _size = Size.zero;

  bool get isEmpty => _strokes.every((s) => s.length < 2);

  void _start(Offset p) {
    _strokes.add([p]);
    notifyListeners();
  }

  void _extend(Offset p) {
    if (_strokes.isEmpty) return;
    _strokes.last.add(p);
    notifyListeners();
  }

  void clear() {
    _strokes.clear();
    notifyListeners();
  }

  /// Transparent PNG of the signature at [pixelRatio]x, or null when empty.
  Future<Uint8List?> toPng({double pixelRatio = 2}) async {
    if (isEmpty || _size.isEmpty) return null;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(pixelRatio);
    _paintStrokes(canvas, _strokes);
    final image = await recorder.endRecording().toImage(
      (_size.width * pixelRatio).round(),
      (_size.height * pixelRatio).round(),
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }
}

const _ink = Color(0xFF14285A);

void _paintStrokes(Canvas canvas, List<List<Offset>> strokes) {
  final paint = Paint()
    ..color = _ink
    ..strokeWidth = 2.6
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;
  for (final s in strokes) {
    if (s.length == 1) {
      canvas.drawCircle(s.first, 1.3, paint..style = PaintingStyle.fill);
      paint.style = PaintingStyle.stroke;
      continue;
    }
    final path = Path()..moveTo(s.first.dx, s.first.dy);
    for (int i = 1; i < s.length; i++) {
      // Midpoint smoothing keeps finger strokes from looking jagged.
      final mid = (s[i - 1] + s[i]) / 2;
      path.quadraticBezierTo(s[i - 1].dx, s[i - 1].dy, mid.dx, mid.dy);
    }
    path.lineTo(s.last.dx, s.last.dy);
    canvas.drawPath(path, paint);
  }
}

/// A box to sign in with a finger or mouse.
class SignaturePad extends StatelessWidget {
  final SignatureController controller;
  final double height;

  const SignaturePad({super.key, required this.controller, this.height = 170});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFB8C2D1)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LayoutBuilder(
              builder: (context, c) {
                controller._size = Size(c.maxWidth, c.maxHeight);
                // An eager pan recognizer wins the gesture arena at once, so
                // drawing never scrolls the page (a plain GestureDetector loses
                // vertical strokes to the surrounding scroll view on phones).
                return RawGestureDetector(
                  gestures: {
                    _EagerPanRecognizer:
                        GestureRecognizerFactoryWithHandlers<
                          _EagerPanRecognizer
                        >(_EagerPanRecognizer.new, (r) {
                          r.onDown = (d) => controller._start(d.localPosition);
                          r.onUpdate = (d) =>
                              controller._extend(d.localPosition);
                        }),
                  },
                  child: ListenableBuilder(
                    listenable: controller,
                    builder: (context, _) => CustomPaint(
                      size: Size(c.maxWidth, c.maxHeight),
                      painter: _SignaturePainter(controller._strokes),
                      child: controller.isEmpty
                          ? const Center(
                              child: Text(
                                'Sign here with your finger',
                                style: TextStyle(
                                  color: Color(0xFF9AA4B2),
                                  fontSize: 15,
                                ),
                              ),
                            )
                          : null,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: controller.clear,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Clear'),
          ),
        ),
      ],
    );
  }
}

class _EagerPanRecognizer extends PanGestureRecognizer {
  _EagerPanRecognizer() : super(supportedDevices: null);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  _SignaturePainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    // Signing line.
    canvas.drawLine(
      Offset(16, size.height - 30),
      Offset(size.width - 16, size.height - 30),
      Paint()
        ..color = const Color(0xFFDCE1E8)
        ..strokeWidth = 1,
    );
    _paintStrokes(canvas, strokes);
  }

  @override
  bool shouldRepaint(_SignaturePainter old) => true;
}
