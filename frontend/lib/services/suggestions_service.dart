import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class SuggestionsService {
  Map<String, List<String>> _suggestions = {};

  Future<void> loadSuggestions() async {
    if (_suggestions.isNotEmpty) return;
    
    try {
      final String response = await rootBundle.loadString('assets/suggestions.json');
      final data = json.decode(response);
      _suggestions = Map<String, List<String>>.from(
        data.map((key, value) => MapEntry(key, List<String>.from(value))),
      );
    } catch (e) {
      debugPrint('Error loading suggestions: $e');
    }
  }

  List<String> getSuggestionsForTags(List<String>? tags) {
    if (_suggestions.isEmpty) return [];

    if (tags == null || tags.isEmpty) {
      if (_suggestions.containsKey('human_present')) {
        return _suggestions['human_present']!;
      } else if (_suggestions.isNotEmpty) {
        return _suggestions.values.first;
      }
      return [];
    }

    Set<String> relevantKeys = {};
    final normalizedTags = tags.map((e) => e.toLowerCase()).toSet();

    if (normalizedTags.any((t) => ['person', 'man', 'woman', 'boy', 'girl', 'human', 'people'].contains(t))) {
      relevantKeys.add('human_present');
    } else {
      relevantKeys.add('no_human');
    }

    if (normalizedTags.any((t) => ['face', 'head', 'portrait', 'smile'].contains(t))) {
      relevantKeys.add('face_visible');
    } else {
      relevantKeys.add('face_not_visible');
    }
    
    if (normalizedTags.any((t) => ['outdoor', 'sky', 'nature', 'tree', 'grass', 'mountain', 'beach'].contains(t))) {
      relevantKeys.add('background_outdoor');
    }
    
    if (normalizedTags.any((t) => ['indoor', 'room', 'furniture', 'wall', 'window'].contains(t))) {
      relevantKeys.add('background_indoor');
    }

    List<String> newSuggestions = [];
    for (var key in relevantKeys) {
      if (_suggestions.containsKey(key)) {
        newSuggestions.addAll(_suggestions[key]!);
      }
    }
    
    if (newSuggestions.isEmpty) {
       if (_suggestions.containsKey('human_present')) {
        newSuggestions = _suggestions['human_present']!;
      }
    }

    return newSuggestions;
  }
}
