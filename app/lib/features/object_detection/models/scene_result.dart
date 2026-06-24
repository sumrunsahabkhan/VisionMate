import 'detected_object.dart';

class SceneResult {
  final List<DetectedObject> objects;
  final String roomType;
  final String speech;
  final bool hasStairs;

  SceneResult({
    required this.objects,
    required this.roomType,
    required this.speech,
    this.hasStairs = false,
  });
}
