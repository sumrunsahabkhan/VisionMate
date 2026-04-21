import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import '../models/detected_object.dart';
import '../models/scene_result.dart';
import 'natural_speech_generator.dart';
import 'smart_room_detector.dart';

class ObjectDetectorService {
  static const _modelPath = 'assets/models/yolov8n_float32.tflite';
  
  static const Map<int, String> _indoorLabels = {
    0: 'person', 15: 'cat', 16: 'dog', 24: 'backpack', 25: 'umbrella', 
    26: 'handbag', 27: 'tie', 28: 'suitcase', 39: 'bottle', 40: 'wine glass', 
    41: 'cup', 42: 'fork', 43: 'knife', 44: 'spoon', 45: 'bowl', 
    46: 'banana', 47: 'apple', 48: 'sandwich', 49: 'orange', 50: 'broccoli', 
    51: 'carrot', 52: 'hot dog', 53: 'pizza', 54: 'donut', 55: 'cake', 
    56: 'chair', 57: 'couch', 58: 'potted plant', 59: 'bed', 60: 'dining table', 
    61: 'toilet', 62: 'tv', 63: 'laptop', 64: 'mouse', 65: 'remote', 
    66: 'keyboard', 67: 'cell phone', 68: 'microwave', 69: 'oven', 70: 'toaster', 
    71: 'sink', 72: 'refrigerator', 73: 'book', 74: 'clock', 75: 'vase', 
    76: 'scissors', 77: 'teddy bear', 78: 'hair drier', 79: 'toothbrush'
  };

  Isolate? _isolate;
  final ReceivePort _receivePort = ReceivePort();
  SendPort? _sendPort;
  Completer<List<DetectedObject>>? _resultCompleter;
  StreamSubscription? _subscription;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    final modelData = await rootBundle.load(_modelPath);
    final modelBytes = modelData.buffer.asUint8List();

    final sendPortCompleter = Completer<SendPort>();
    _subscription = _receivePort.listen((message) {
      if (message is SendPort) {
        if (!sendPortCompleter.isCompleted) sendPortCompleter.complete(message);
      } else if (message is List<DetectedObject>) {
        _resultCompleter?.complete(message);
      }
    });

    _isolate = await Isolate.spawn(_inferenceIsolate, [_receivePort.sendPort, modelBytes]);
    _sendPort = await sendPortCompleter.future;
    _isInitialized = true;
  }

  Future<SceneResult> analyzeScene(XFile imageFile) async {
    if (!_isInitialized) await initialize();
    final bytes = await imageFile.readAsBytes();
    _resultCompleter = Completer<List<DetectedObject>>();
    _sendPort?.send(bytes);
    
    final detectedObjects = await _resultCompleter!.future;
    final roomType = SmartRoomDetector.detectRoom(detectedObjects.map((o) => o.label).toList(), []);
    final speech = NaturalSpeechGenerator.generateDetailed(objects: detectedObjects, roomType: roomType);

    return SceneResult(
      objects: detectedObjects,
      roomType: roomType,
      speech: speech,
      hasStairs: detectedObjects.any((o) => o.label.toLowerCase().contains('stair')),
    );
  }

  static void _inferenceIsolate(List<dynamic> args) async {
    final mainSendPort = args[0] as SendPort;
    final modelBytes = args[1] as Uint8List;
    final childReceivePort = ReceivePort();
    mainSendPort.send(childReceivePort.sendPort);

    final interpreter = Interpreter.fromBuffer(modelBytes, options: InterpreterOptions()..threads = 4);

    await for (final Uint8List bytes in childReceivePort) {
      try {
        final image = img.decodeImage(bytes);
        if (image == null) { mainSendPort.send(<DetectedObject>[]); continue; }

        const inputSize = 640;
        final resized = img.copyResize(image, width: inputSize, height: inputSize, interpolation: img.Interpolation.nearest);
        
        var input = Float32List(1 * inputSize * inputSize * 3);
        int pixelIndex = 0;
        for (var y = 0; y < inputSize; y++) {
          for (var x = 0; x < inputSize; x++) {
            final pixel = resized.getPixel(x, y);
            input[pixelIndex++] = pixel.r / 255.0;
            input[pixelIndex++] = pixel.g / 255.0;
            input[pixelIndex++] = pixel.b / 255.0;
          }
        }

        final output = List.generate(1, (_) => List.generate(84, (_) => List.filled(8400, 0.0)));
        interpreter.run(input.buffer.asFloat32List().reshape([1, inputSize, inputSize, 3]), output);

        final results = _parse(output[0], 0.35, 0.45);
        mainSendPort.send(results);
      } catch (e) { mainSendPort.send(<DetectedObject>[]); }
    }
  }

  static List<DetectedObject> _parse(List<List<double>> out, double confThr, double iouThr) {
    List<DetectedObject> raw = [];
    final indoorIndices = _indoorLabels.keys.toList();

    for (int i = 0; i < 8400; i++) {
      double bestScore = 0;
      int bestClass = -1;

      for (int cIdx in indoorIndices) {
        if (out[4 + cIdx][i] > bestScore) {
          bestScore = out[4 + cIdx][i];
          bestClass = cIdx;
        }
      }

      if (bestClass == -1 || bestScore < confThr) continue;

      double w = out[2][i];
      double h = out[3][i];
      raw.add(DetectedObject(
        label: _indoorLabels[bestClass]!,
        confidence: bestScore,
        x: (out[0][i] - w / 2) / 640,
        y: (out[1][i] - h / 2) / 640,
        width: w / 640,
        height: h / 640,
      ));
    }
    return _nms(raw, iouThr);
  }

  static List<DetectedObject> _nms(List<DetectedObject> boxes, double iouThr) {
    boxes.sort((a, b) => b.confidence.compareTo(a.confidence));
    final kept = <DetectedObject>[];
    for (var box in boxes) {
      if (!kept.any((k) => _iou(box, k) > iouThr)) kept.add(box);
    }
    return kept;
  }

  static double _iou(DetectedObject a, DetectedObject b) {
    double ax2 = a.x + a.width, ay2 = a.y + a.height;
    double bx2 = b.x + b.width, by2 = b.y + b.height;
    double ix1 = a.x > b.x ? a.x : b.x;
    double iy1 = a.y > b.y ? a.y : b.y;
    double ix2 = ax2 < bx2 ? ax2 : bx2;
    double iy2 = ay2 < by2 ? ay2 : by2;
    if (ix2 <= ix1 || iy2 <= iy1) return 0;
    double inter = (ix2 - ix1) * (iy2 - iy1);
    return inter / (a.width * a.height + b.width * b.height - inter);
  }

  void dispose() {
    _subscription?.cancel();
    _isolate?.kill();
    _receivePort.close();
  }
}
