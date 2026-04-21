class SmartRoomDetector {
  static String detectRoom(List<String> objects, List<String> labels) {
    final all = [...objects, ...labels].map((o) => o.toLowerCase()).toList();

    final scores = {
      'kitchen': 0,
      'bedroom': 0,
      'living room': 0,
      'office': 0,
      'bathroom': 0,
    };

    // Kitchen - High priority items
    if (_has(all, ['refrigerator', 'fridge', 'stove', 'sink', 'kettle', 'microwave', 'oven'])) {
      scores['kitchen'] = scores['kitchen']! + 15;
    }
    if (_has(all, ['cupboard', 'cabinet', 'countertop', 'dish', 'gas stove', 'tap'])) {
      scores['kitchen'] = scores['kitchen']! + 5;
    }

    // Bedroom
    if (_has(all, ['bed', 'pillow', 'blanket', 'mattress'])) {
      scores['bedroom'] = scores['bedroom']! + 15;
    }
    if (_has(all, ['wardrobe', 'dresser'])) {
      scores['bedroom'] = scores['bedroom']! + 5;
    }

    // Office - Be careful with "desk" as it can be a kitchen counter
    if (_has(all, ['laptop', 'computer', 'monitor', 'keyboard'])) {
       scores['office'] = scores['office']! + 15;
    } else if (_has(all, ['desk'])) {
       // Only count desk if no kitchen items are present
       if (scores['kitchen']! == 0) {
         scores['office'] = scores['office']! + 5;
       }
    }

    // Living Room
    if (_has(all, ['sofa', 'couch', 'television', 'tv', 'coffee table'])) {
      scores['living room'] = scores['living room']! + 10;
    }

    // Bathroom
    if (_has(all, ['toilet', 'shower', 'bathtub', 'faucet', 'washbasin'])) {
      scores['bathroom'] = scores['bathroom']! + 15;
    }

    // Tie-breaking logic: Kitchen usually overrides Office if cupboards/fridge are present
    if (scores['kitchen']! > 0 && scores['office']! > 0) {
      scores['office'] = 0; 
    }

    final detected = scores.entries
        .where((e) => e.value >= 10) // Higher threshold for confidence
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return detected.isEmpty ? '' : detected.first.key;
  }

  static bool _has(List<String> all, List<String> targets) {
    return targets.any((t) => all.any((a) => a.contains(t)));
  }
}
