import 'dart:math';
import 'package:flutter/foundation.dart';
import 'mobile_bert_service.dart';

enum EditorAction {
  relight,
  reframe,
  diffusion,
  unknown,
}

class SemanticRouterService {
  final MobileBertService _mobileBertService = MobileBertService();
  
  // Anchor prompts to define the "center" of each intent
  static const String _relightAnchorText = "adjust lighting fix shadows change exposure brightness contrast relight image sun";
  static const String _reframeAnchorText = "change pose move person crop image resize scale rotate composition frame";
  
  List<double>? _relightAnchor;
  List<double>? _reframeAnchor;
  
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    await _mobileBertService.initialize();
    
    // Pre-compute anchor embeddings
    // In a real app, these could be averaged from multiple examples or pre-computed offline.
    // Here we compute them on startup.
    _relightAnchor = await _mobileBertService.getEmbedding(_relightAnchorText);
    _reframeAnchor = await _mobileBertService.getEmbedding(_reframeAnchorText);
    
    _isInitialized = true;
    debugPrint('SemanticRouterService: Initialized and anchors computed.');
  }

  Future<EditorAction> routePrompt(String prompt) async {
    if (!_isInitialized) await initialize();
    
    final promptEmbedding = await _mobileBertService.getEmbedding(prompt);
    
    final relightScore = _cosineSimilarity(promptEmbedding, _relightAnchor!);
    final reframeScore = _cosineSimilarity(promptEmbedding, _reframeAnchor!);
    
    debugPrint('Semantic Router Scores - Relight: $relightScore, Reframe: $reframeScore');
    
    // Threshold for matching
    // Cosine similarity is between -1 and 1.
    // For BERT embeddings, unrelated sentences might still have high similarity (e.g. 0.6-0.7).
    // We need to experiment, but let's pick the max and check if it's significant.
    
    const double threshold = 0.65; // Conservative threshold
    
    if (relightScore > reframeScore && relightScore > threshold) {
      return EditorAction.relight;
    } else if (reframeScore > relightScore && reframeScore > threshold) {
      return EditorAction.reframe;
    } else {
      // If neither is a strong match, assume it's a creative generation request
      return EditorAction.diffusion;
    }
  }

  double _cosineSimilarity(List<double> vecA, List<double> vecB) {
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    
    for (int i = 0; i < vecA.length; i++) {
      dotProduct += vecA[i] * vecB[i];
      normA += vecA[i] * vecA[i];
      normB += vecB[i] * vecB[i];
    }
    
    if (normA == 0 || normB == 0) return 0.0;
    
    return dotProduct / (sqrt(normA) * sqrt(normB));
  }
  
  void dispose() {
    _mobileBertService.dispose();
  }
}
