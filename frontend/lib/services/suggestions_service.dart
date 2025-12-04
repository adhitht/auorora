import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'llm_service.dart';

class SuggestionsService {
  final LlmService _llmService;

  SuggestionsService(this._llmService);

  // Keep loadSuggestions for compatibility if needed, or remove if fully dynamic.
  // For now, we'll just make it a no-op or keep it if we want hybrid.
  Future<void> loadSuggestions() async {}

  Future<List<String>> generateSuggestions(List<String>? tags) async {
    final tagsString = (tags == null || tags.isEmpty) ? "generic image" : tags.join(', ');
    
    final systemPrompt = 
      "You are a smart photo editor assistant for an app with these features: "
      "1. Relight: Add lights (spot/directional) with color and position. "
      "2. Reframe: Crop to aspect ratios (1:1, 16:9) or for purposes (passport, social). "
      "3. Pose Correction: Fix head/body pose. "
      "Based on the detected tags, suggest 3 distinct, actionable commands. "
      "RULES: "
      "- If 'person', 'face', 'man', 'woman' are NOT in tags, DO NOT suggest passport photos or pose correction. "
      "- If 'no_human' is in tags, NEVER suggest human-related edits. "
      "- For landscapes/objects, focus on lighting (e.g. 'Add sunset light') and framing. "
      "Output ONLY a valid JSON list of strings. "
      "Example: [\"Add red light to the right\", \"Crop to 1:1 square\", \"Add cinematic lighting\"]";

    try {
      final response = await _llmService.generateResponse(
        "Tags: $tagsString", 
        systemPrompt: systemPrompt
      );
      
      debugPrint('SuggestionsService: LLM Response: $response');
      
      final List<dynamic> jsonList = jsonDecode(response);
      return jsonList.map((e) => e.toString()).toList();
    } catch (e) {
      debugPrint('Error generating suggestions: $e');
      // Fallback suggestions
      return ["Relight the scene", "Crop the image", "Add cinematic lighting"];
    }
  }

  // Deprecated synchronous method, kept for compatibility during refactor
  List<String> getSuggestionsForTags(List<String>? tags) {
    return [];
  }
}
