import '../models/detected_object.dart';
import 'dart:math';

class NaturalSpeechGenerator {
  static String generateDetailed({
    required List<DetectedObject> objects,
    required String roomType,
  }) {
    if (objects.isEmpty) {
      return "The area ahead seems clear. I don't see any specific objects right now.";
    }

    final parts = <String>[];

    // Sort by area (larger/closer objects first) to establish context
    final processedIndices = <int>{};
    final sorted = List<DetectedObject>.from(objects)..sort((a, b) => b.area.compareTo(a.area));

    for (int i = 0; i < sorted.length; i++) {
      if (processedIndices.contains(i)) continue;
      final obj = sorted[i];
      final label = _cleanLabel(obj.label);

      // Relationship Detection (e.g., A on B)
      String? relationship;
      for (int j = 0; j < sorted.length; j++) {
        if (i == j) continue;
        final other = sorted[j];
        if (_isOnTopOf(obj, other)) {
          relationship = "$label on the ${_cleanLabel(other.label)}";
          processedIndices.add(j); 
          break;
        }
      }

      // Action Detection for Persons
      if (label == 'person') {
        final status = _getPersonStatus(obj, sorted);
        // Removed 'direction' for a more humanistic feel as requested
        parts.add("I see a person $status, ${obj.proximity}.");
      } 
      else if (relationship != null) {
        parts.add("There is a $relationship, ${obj.proximity}.");
      }
      else {
        // Grouping logic (e.g., multiple chairs)
        int count = 1;
        for (int k = i + 1; k < sorted.length; k++) {
          if (_cleanLabel(sorted[k].label) == label) {
            count++;
            processedIndices.add(k);
          }
        }
        
        if (count > 1) {
          parts.add("There are $count ${label}s, ${obj.proximity}.");
        } else {
          parts.add("I notice a $label, ${obj.proximity}.");
        }
      }
      
      processedIndices.add(i);
      if (parts.length >= 6) break; 
    }

    return parts.join(' ');
  }

  static String _cleanLabel(String label) {
    switch (label.toLowerCase()) {
      case 'cell phone': return 'smartphone';
      case 'potted plant': return 'plant';
      case 'dining table': return 'table';
      default: return label;
    }
  }

  static bool _isOnTopOf(DetectedObject a, DetectedObject b) {
    double aCenterX = a.x + (a.width / 2);
    bool horizontalOverlap = (aCenterX > b.x && aCenterX < (b.x + b.width));
    bool isAbove = (a.y + a.height) < (b.y + (b.height * 0.95)); 
    bool surfaceCheck = b.width > (a.width * 0.4);
    
    bool isSurface = ['table', 'desk', 'chair', 'bed', 'sofa', 'couch', 'sink', 'refrigerator', 'microwave'].contains(b.label.toLowerCase());
    
    return horizontalOverlap && isAbove && surfaceCheck && isSurface;
  }

  static String _getPersonStatus(DetectedObject person, List<DetectedObject> all) {
    for (var other in all) {
      if (['chair', 'couch', 'sofa', 'bed'].contains(other.label.toLowerCase())) {
        if (_isOnTopOf(person, other)) return "sitting";
      }
    }
    double ratio = person.height / person.width;
    if (ratio < 1.0) return "lying down";
    if (ratio > 1.8) return "standing";
    return "";
  }

  // Specialized search response - Removed direction for humanistic feedback
  static String generateSearchResponse(String target, List<DetectedObject> found) {
    if (found.isEmpty) {
      return "I'm sorry, I don't see any $target here right now.";
    }
    final obj = found.first;
    return "Yes, I found the $target, ${obj.proximity}.";
  }
}
