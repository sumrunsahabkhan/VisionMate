class SmartRoomDetector {
  static String detectRoom(List<String> objects, List<String> labels) {
    final all = [...objects, ...labels].map((o) => o.toLowerCase()).toList();

    final scores = {
      'kitchen': 0,
      'bedroom': 0,
      'tv lounge': 0,
      'drawing room': 0,
      'office': 0,
      'bathroom': 0,
      'dining area': 0,
    };

    // Kitchen - High confidence objects
    if (_has(all, ['refrigerator', 'fridge', 'microwave', 'oven', 'sink', 'toaster'])) {
      scores['kitchen'] = scores['kitchen']! + 20; // Increased weight
    }
    // Kitchen - Utensils and small items (Very common in Pakistani kitchens on counters)
    if (_has(all, ['bottle', 'cup', 'fork', 'knife', 'spoon', 'bowl'])) {
      scores['kitchen'] = scores['kitchen']! + 10;
    }

    // Bedroom
    if (_has(all, ['bed', 'pillow', 'blanket', 'mattress'])) {
      scores['bedroom'] = scores['bedroom']! + 20;
    }

    // Office
    if (_has(all, ['laptop', 'computer', 'monitor', 'keyboard', 'mouse'])) {
       scores['office'] = scores['office']! + 20;
    }

    // TV Lounge
    if (_has(all, ['television', 'tv'])) {
      scores['tv lounge'] = scores['tv lounge']! + 20;
    }
    if (_has(all, ['couch', 'sofa', 'remote'])) {
      scores['tv lounge'] = scores['tv lounge']! + 10;
    }

    // Drawing Room
    if (_has(all, ['couch', 'sofa', 'vase']) && !_has(all, ['tv', 'television'])) {
      scores['drawing room'] = scores['drawing room']! + 15;
    }

    // Dining Area
    if (_has(all, ['dining table'])) {
      scores['dining area'] = scores['dining area']! + 20;
    }

    // Bathroom
    if (_has(all, ['toilet', 'shower', 'faucet', 'washbasin', 'toothbrush'])) {
      scores['bathroom'] = scores['bathroom']! + 20;
    }

    // Tie-breaking Logic
    // If kitchen items are detected, it's very likely a kitchen even if a chair is present
    if (scores['kitchen']! >= 10) {
      scores['tv lounge'] = 0;
      scores['drawing room'] = 0;
      scores['bedroom'] = 0;
    }

    final detected = scores.entries
        .where((e) => e.value >= 10)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return detected.isEmpty ? '' : detected.first.key;
  }

  static bool _has(List<String> all, List<String> targets) {
    return targets.any((t) => all.any((a) => a.contains(t)));
  }
}
