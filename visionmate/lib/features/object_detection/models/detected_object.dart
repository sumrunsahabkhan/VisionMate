class DetectedObject {
  final String label;
  final double confidence;
  final double x, y, width, height;

  const DetectedObject({
    required this.label,
    required this.confidence,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  // Direction Logic based on the 0.35/0.65 ratio
  String get direction {
    double centerX = x + (width / 2);
    if (centerX < 0.35) return "on your left";
    if (centerX > 0.65) return "on your right";
    return "directly ahead";
  }

  // Distance Logic based on Bounding Box Area
  String get proximity {
    double area = width * height;
    if (area > 0.40) return "right in front of you";
    if (area > 0.15) return "a few steps away";
    return "at a distance";
  }

  // Priority Manager (stair > door > person > furniture)
  int get priority {
    final l = label.toLowerCase();
    if (l == 'stair') return 0;
    if (l == 'door') return 1;
    if (l == 'person') return 2;
    return 3; // bed, chair, cupboard, sofa, table
  }

  double get area => width * height;
}
