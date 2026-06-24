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

  // Simplified proximity for natural human-like speech
  String get proximity {
    double area = width * height;
    if (area > 0.40) return "very close";
    if (area > 0.15) return "nearby";
    return "a bit further away";
  }

  // Priority Manager (stair > door > person > furniture)
  int get priority {
    final l = label.toLowerCase();
    if (l == 'stair') return 0;
    if (l == 'door') return 1;
    if (l == 'person') return 2;
    return 3;
  }

  double get area => width * height;
}
