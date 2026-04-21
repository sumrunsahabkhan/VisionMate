import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class DetectedObject {
  final String label;
  final double confidence;
  final double x, y, width, height; // normalized 0-1

  DetectedObject({
    required this.label,
    required this.confidence,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  // Object screen par kahan hai
  String get position {
    if (x < 0.33) return "on your left";
    if (x > 0.66) return "on your right";
    return "ahead of you";
  }

  // Distance estimate (box size se)
  String get distance {
    double area = width * height;
    if (area > 0.4) return "very close";
    if (area > 0.15) return "a few steps away";
    return "far away";
  }
}

class ObjectDetectionService {
  static const List<String> _labels = [
    'bed', 'chair', 'cupboard', 'door',
    'person', 'sofa', 'stair', 'table'
  ];

  static const double _confidenceThreshold = 0.50;
  static const double _iouThreshold = 0.45;
  static const int _inputSize = 320;

  Interpreter? _interpreter;
  bool _isLoaded = false;

  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        'assets/models/best_float32.tflite',
      );
      _isLoaded = true;
    } catch (e) {
      print("Error loading model: $e");
    }
  }

  Future<List<DetectedObject>> detect(img.Image cameraFrame) async {
    if (!_isLoaded || _interpreter == null) return [];

    // 1. Resize to 320x320
    final resized = img.copyResize(
      cameraFrame,
      width: _inputSize,
      height: _inputSize,
    );

    // 2. Normalize pixels 0-255 → 0.0-1.0
    // YOLOv8 expects [1, 320, 320, 3]
    var input = Float32List(_inputSize * _inputSize * 3);
    var buffer = input.buffer;
    int pixelIndex = 0;
    for (int y = 0; y < _inputSize; y++) {
      for (int x = 0; x < _inputSize; x++) {
        final pixel = resized.getPixel(x, y);
        input[pixelIndex++] = pixel.r / 255.0;
        input[pixelIndex++] = pixel.g / 255.0;
        input[pixelIndex++] = pixel.b / 255.0;
      }
    }
    
    final inputShape = [1, _inputSize, _inputSize, 3];
    final inputBuffer = input.reshape(inputShape);

    // 3. Output buffer: [1, 12, 2100]
    final output = List.generate(
      1, (_) => List.generate(
        12, (_) => List.filled(2100, 0.0),
      ),
    );

    // 4. Run inference
    _interpreter!.run(inputBuffer, output);

    // 5. Parse YOLOv8 output
    return _parseOutput(output[0], cameraFrame.width, cameraFrame.height);
  }

  List<DetectedObject> _parseOutput(
    List<List<double>> output,
    int origW,
    int origH,
  ) {
    List<DetectedObject> results = [];

    // YOLOv8 output: [12, 2100] 
    // First 4 rows = cx, cy, w, h
    // Next 8 rows = class scores

    for (int i = 0; i < 2100; i++) {
      double cx = output[0][i];
      double cy = output[1][i];
      double w  = output[2][i];
      double h  = output[3][i];

      // Best class
      int bestClass = 0;
      double bestScore = 0.0;
      for (int c = 0; c < 8; c++) {
        double score = output[4 + c][i];
        if (score > bestScore) {
          bestScore = score;
          bestClass = c;
        }
      }

      if (bestScore < _confidenceThreshold) continue;

      // Normalize to 0-1
      results.add(DetectedObject(
        label: _labels[bestClass],
        confidence: bestScore,
        x: (cx - w / 2) / _inputSize,
        y: (cy - h / 2) / _inputSize,
        width: w / _inputSize,
        height: h / _inputSize,
      ));
    }

    // NMS — duplicate boxes hatao
    return _nms(results);
  }

  List<DetectedObject> _nms(List<DetectedObject> boxes) {
    boxes.sort((a, b) => b.confidence.compareTo(a.confidence));
    List<DetectedObject> kept = [];

    for (var box in boxes) {
      bool suppress = false;
      for (var keptBox in kept) {
        if (_iou(box, keptBox) > _iouThreshold) {
          suppress = true;
          break;
        }
      }
      if (!suppress) kept.add(box);
    }
    return kept;
  }

  double _iou(DetectedObject a, DetectedObject b) {
    double ax2 = a.x + a.width,  ay2 = a.y + a.height;
    double bx2 = b.x + b.width,  by2 = b.y + b.height;
    double ix1 = a.x > b.x ? a.x : b.x;
    double iy1 = a.y > b.y ? a.y : b.y;
    double ix2 = ax2 < bx2 ? ax2 : bx2;
    double iy2 = ay2 < by2 ? ay2 : by2;
    if (ix2 < ix1 || iy2 < iy1) return 0.0;
    double inter = (ix2 - ix1) * (iy2 - iy1);
    double aArea = a.width * a.height;
    double bArea = b.width * b.height;
    return inter / (aArea + bArea - inter);
  }

  void dispose() => _interpreter?.close();
}
