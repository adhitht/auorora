import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../theme/liquid_glass_theme.dart';
import '../services/image_processing_service.dart';
import '../services/edit_history_manager.dart';
import '../services/siglip_service.dart';
import '../services/segmentation_service.dart';
import '../models/edit_history.dart';
import '../widgets/editor_top_bar.dart';
import '../widgets/editor_bottom_bar.dart';
import '../widgets/crop_editor_widget.dart';
import '../widgets/relight_editor_widget.dart';
import '../widgets/relight_editor_controller.dart';
import '../widgets/reframe_editor_widget.dart';
import '../widgets/history_viewer_dialog.dart';
import '../widgets/privacy_notice_dialog.dart';
import '../widgets/notification_bar.dart';
import '../services/notification_service.dart';

class EditorScreen extends StatefulWidget {
  final File photoFile;

  const EditorScreen({super.key, required this.photoFile});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen>
    with TickerProviderStateMixin {
  bool _isLoading = false;
  bool _hasError = false;
  bool _isProcessing = false;

  File? _currentPhotoFile;
  bool _isCropMode = false;
  bool _isRelightMode = false;
  bool _isReframeMode = false;
  bool _isChatMode = false;

  Widget Function()? _relightControlPanelBuilder;
  Widget Function()? _cropControlPanelBuilder;
  Widget Function()? _reframeControlPanelBuilder;


  final ImageProcessingService _imageService = ImageProcessingService();
  final SigLipService _sigLipService = SigLipService();
  final SegmentationService _segmentationService = SegmentationService();
  final NotificationService _notificationService = NotificationService(); // Initialize NotificationService
  late final EditHistoryManager _historyManager;
  final RelightEditorController _relightController = RelightEditorController();

  @override
  void initState() {
    super.initState();
    _currentPhotoFile = widget.photoFile;

    _initializeServices();

    _historyManager = EditHistoryManager(maxHistorySize: 50);

    _historyManager.addEntry(
      EditHistoryEntry(
        imageFile: widget.photoFile,
        type: EditType.initial,
        metadata: {
          'filename': widget.photoFile.path.split('/').last,
          'size': widget.photoFile.lengthSync(),
        },
      ),
    );

    _historyManager.addListener(_onHistoryChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) {
        _showPrivacyNotice();
      }
    });
  }

  Future<void> _showPrivacyNotice() async {
    final shouldProceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PrivacyNoticeDialog(),
    );

    if (shouldProceed != true) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _initializeServices() async {
    try {
      await _segmentationService.initialize();
      await _segmentationService.encodeImage(widget.photoFile);
    } catch (e) {
      debugPrint('Error initializing segmentation service: $e');
    }

    // Pre-initialize SigLip with a delay to avoid stutter when opening chat
    // This moves the heavy model loading to the background
    Future.delayed(const Duration(seconds: 3), () async {
      if (!mounted) return;
      try {
        await _sigLipService.loadModel();
        await _sigLipService.loadTags();
      } catch (e) {
        debugPrint('Error pre-initializing SigLip service: $e');
      }
    });
  }

  @override
  void dispose() {
    _historyManager.removeListener(_onHistoryChanged);
    _historyManager.dispose();
    _sigLipService.dispose();
    _segmentationService.dispose();
    _notificationService.dispose(); // Dispose NotificationService
    _relightController.dispose();
    super.dispose();
  }

  void _onHistoryChanged() {
    setState(() {}); // Rebuild to update undo/redo button states
  }

  void _navigateBack() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
  }

  void _handleUndo() {
    if (!_historyManager.canUndo) return;

    HapticFeedback.mediumImpact();
    final entry = _historyManager.undo();

    if (entry != null) {
      setState(() {
        _currentPhotoFile = entry.imageFile;
        _exitCropMode();
        _exitRelightMode();
        _exitReframeMode();
        _exitChatMode();
      });

      _notificationService.show(
        'Undone: ${entry.type.displayName}',
        type: NotificationType.info,
      );
    }
  }

  void _handleRedo() {
    if (!_historyManager.canRedo) return;

    HapticFeedback.mediumImpact();
    final entry = _historyManager.redo();

    if (entry != null) {
      setState(() {
        _currentPhotoFile = entry.imageFile;
        _exitCropMode();
        _exitRelightMode();
        _exitReframeMode();
        _exitChatMode();
      });

      _notificationService.show(
        'Redone: ${entry.type.displayName}',
        type: NotificationType.info,
      );
    }
  }

  void _showHistoryViewer() {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => HistoryViewerDialog(
        historyManager: _historyManager,
        onJumpTo: (index) {
          final entry = _historyManager.jumpTo(index);
          if (entry != null) {
            setState(() {
              _currentPhotoFile = entry.imageFile;
              _exitCropMode();
              _exitRelightMode();
              _exitReframeMode();
              _exitChatMode();
            });
          }
        },
      ),
    );
  }

  void _enterCropMode() {
    if (_currentPhotoFile == null) return;
    setState(() {
      _isCropMode = true;
      _isRelightMode = false;
      _isReframeMode = false;
      _isChatMode = false;
    });
  }

  void _enterRelightMode() {
    if (_currentPhotoFile == null) return;
    setState(() {
      _isRelightMode = true;
      _isCropMode = false;
      _isReframeMode = false;
      _isChatMode = false;
    });
  }

  void _enterReframeMode() {
    if (_currentPhotoFile == null) return;
    setState(() {
      _isReframeMode = true;
      _isCropMode = false;
      _isRelightMode = false;
      _isChatMode = false;
    });
  }

  List<String> _detectedTags = [];
  String? _lastTaggedPath;
  final Set<String> _dismissedSuggestions = {};

  Future<void> _enterChatMode() async {
    if (_currentPhotoFile == null) return;
    
    setState(() {
      _isChatMode = true;
      _isCropMode = false;
      _isRelightMode = false;
      _isReframeMode = false;
    });

    // If we already have tags for this image, don't re-run immediately
    // If image changed, we might want to re-run in background
    if (_lastTaggedPath == _currentPhotoFile!.path && _detectedTags.isNotEmpty) {
      return;
    }

    try {
      final imageBytes = await _currentPhotoFile!.readAsBytes();
      final embedding = await _sigLipService.embed(imageBytes);
      await _sigLipService.loadTags();
      final matches = _sigLipService.findBestMatches(embedding, topK: 20);
      
      if (mounted) {
        setState(() {
          _detectedTags = matches.map((e) => e.key).toList();
          _lastTaggedPath = _currentPhotoFile!.path;
          // Only clear dismissed suggestions if it's a completely new image context
          // For edits (same file path usually, but content changed), we might want to keep them?
          // Actually, if content changed significantly, maybe suggestions should reset.
          // For now, let's keep dismissed suggestions to avoid annoyance.
        });
      }
    } catch (e) {
      debugPrint("SigLip error: $e");
    }
  }



  void _onSuggestionSelected(String suggestion) {
    setState(() {
      _dismissedSuggestions.add(suggestion);
    });
  }

  void _handleToolSelection(EditorTool tool) {
    // Check if clicking the same tool - toggle it off
    if (tool == EditorTool.crop && _isCropMode) {
      _exitCropMode();
      return;
    }
    if (tool == EditorTool.relight && _isRelightMode) {
      _exitRelightMode();
      return;
    }
    if (tool == EditorTool.reframe && _isReframeMode) {
      _exitReframeMode();
      return;
    }
    if (tool == EditorTool.chat && _isChatMode) {
      _exitChatMode();
      return;
    }

    // Exit other modes
    if (tool != EditorTool.crop && _isCropMode) _exitCropMode();
    if (tool != EditorTool.relight && _isRelightMode) _exitRelightMode();
    if (tool != EditorTool.reframe && _isReframeMode) _exitReframeMode();
    if (tool != EditorTool.chat && _isChatMode) _exitChatMode();

    switch (tool) {
      case EditorTool.crop:
        _enterCropMode();
        break;
      case EditorTool.relight:
        _enterRelightMode();
        break;
      case EditorTool.reframe:
        _enterReframeMode();
        break;
      case EditorTool.chat:
        _enterChatMode();
        break;
    }
  }

  void _exitCropMode() {
    setState(() {
      _isCropMode = false;
      _cropControlPanelBuilder = null;
    });
  }

  void _exitRelightMode() {
    setState(() {
      _isRelightMode = false;
      _relightControlPanelBuilder = null;
    });
  }

  void _exitReframeMode() {
    setState(() {
      _isReframeMode = false;
      _reframeControlPanelBuilder = null;
    });
  }

  void _exitChatMode() {
    setState(() {
      _isChatMode = false;
    });
  }

  void _onCropApplied(File croppedFile) {
    // Add to history with metadata
    _historyManager.addEntry(
      EditHistoryEntry(
        imageFile: croppedFile,
        type: EditType.crop,
        metadata: {
          'filename': croppedFile.path.split('/').last,
          'size': croppedFile.lengthSync(),
        },
      ),
    );

    setState(() {
      _currentPhotoFile = croppedFile;
      _isCropMode = false;
      _isProcessing = false;
      // _detectedTags = []; // Keep tags
    });
    _notificationService.show(
      'Crop applied',
      type: NotificationType.success,
    );
  }

  void _onRelightApplied(File relitFile, Map<String, dynamic> adjustments) {
    // Add to history with metadata including adjustment values
    _historyManager.addEntry(
      EditHistoryEntry(
        imageFile: relitFile,
        type: EditType.relight,
        metadata: {
          'filename': relitFile.path.split('/').last,
          'size': relitFile.lengthSync(),
          'exposure': adjustments['exposure'],
          'contrast': adjustments['contrast'],
          'highlights': adjustments['highlights'],
          'shadows': adjustments['shadows'],
          'saturation': adjustments['saturation'],
          'temperature': adjustments['temperature'],
        },
      ),
    );

    setState(() {
      _currentPhotoFile = relitFile;
      _isRelightMode = false;
      _isProcessing = false;
      // _detectedTags = []; // Keep tags
    });
    _notificationService.show(
      'Adjustments applied',
      type: NotificationType.success,
    );
  }

  void _onReframeApplied(File reframedFile) {
    // Add to history with metadata
    _historyManager.addEntry(
      EditHistoryEntry(
        imageFile: reframedFile,
        type: EditType.reframe,
        metadata: {
          'filename': reframedFile.path.split('/').last,
          'size': reframedFile.lengthSync(),
        },
      ),
    );

    setState(() {
      _currentPhotoFile = reframedFile;
      _isReframeMode = false;
      _isProcessing = false;
      // _detectedTags = []; // Keep tags
    });
    _notificationService.show(
      'Reframe applied',
      type: NotificationType.success,
    );
  }

  Future<void> _savePhoto() async {
    if (_isProcessing || _currentPhotoFile == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final bytes = await _currentPhotoFile!.readAsBytes();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'edited_photo_$timestamp.jpg';

      final savedFile = await _imageService.saveImage(bytes, fileName);

      if (mounted) {
        setState(() => _isProcessing = false);
        _notificationService.show(
          'Photo saved successfully to ${savedFile.path}',
          type: NotificationType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _notificationService.show(
          'Failed to save photo: ${e.toString()}',
          type: NotificationType.error,
        );
      }
    }
  }

  Future<void> _handleShare() async {
    if (_isProcessing || _currentPhotoFile == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final xFile = XFile(_currentPhotoFile!.path);
      await Share.shareXFiles([xFile], text: 'Edited with Apex Editor');
    } catch (e) {
      if (mounted) {
        debugPrint('Failed to share photo: ${e.toString()}');
        _notificationService.show(
          'Failed to share photo: ${e.toString()}',
          type: NotificationType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LiquidGlassTheme.background,
      body: Stack(
        children: [
          Column(
            children: [
              // Top app bar (keep existing API)
              EditorTopBar(
                onBackTap: _navigateBack,
                onSaveTap: _savePhoto,
                onShareTap: _handleShare,
                isSaving: _isProcessing,
                onUndo: _handleUndo,
                onRedo: _handleRedo,
                onHistory: _showHistoryViewer,
                canUndo: _historyManager.canUndo,
                canRedo: _historyManager.canRedo,
              ),



              Expanded(child: _buildPhotoArea()),

              const SizedBox(height: 100),
            ],
          ),

          // Crop controls panel (slides up from behind bottom bar)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            left: 12,
            right: 12,
            bottom: _isCropMode && _cropControlPanelBuilder != null ? 88 : -200,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _isCropMode && _cropControlPanelBuilder != null
                  ? 1.0
                  : 0.0,
              child: _cropControlPanelBuilder != null
                  ? _cropControlPanelBuilder!()
                  : const SizedBox.shrink(),
            ),
          ),

          // Relight controls panel (slides up from behind bottom bar)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            left: 12,
            right: 12,
            bottom: _isRelightMode && _relightControlPanelBuilder != null
                ? 88
                : -200,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _isRelightMode && _relightControlPanelBuilder != null
                  ? 1.0
                  : 0.0,
              child: _relightControlPanelBuilder != null
                  ? _relightControlPanelBuilder!()
                  : const SizedBox.shrink(),
            ),
          ),

          // Reframe controls panel (slides up from behind bottom bar)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            left: 12,
            right: 12,
            bottom: _isReframeMode && _reframeControlPanelBuilder != null
                ? 88
                : -200,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _isReframeMode && _reframeControlPanelBuilder != null
                  ? 1.0
                  : 0.0,
              child: _reframeControlPanelBuilder != null
                  ? _reframeControlPanelBuilder!()
                  : const SizedBox.shrink(),
            ),
          ),



          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: EditorBottomBar(
              selectedTool: _isCropMode
                  ? EditorTool.crop
                  : _isRelightMode
                      ? EditorTool.relight
                      : _isReframeMode
                          ? EditorTool.reframe
                          : _isChatMode
                              ? EditorTool.chat
                              : null,
              detectedTags: _detectedTags,
              dismissedSuggestions: _dismissedSuggestions,
              onSuggestionSelected: _onSuggestionSelected,
              toolCallbacks: <EditorTool, VoidCallback?>{
                EditorTool.crop: () => _handleToolSelection(EditorTool.crop),
                EditorTool.relight: () =>
                    _handleToolSelection(EditorTool.relight),
                EditorTool.reframe: () =>
                    _handleToolSelection(EditorTool.reframe),
                EditorTool.chat: () =>
                    _handleToolSelection(EditorTool.chat),
              },
              relightController: _relightController,
              notificationService: _notificationService,
            ),
          ),

          if (_isProcessing)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.45),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: LiquidGlassTheme.primary,
                  ),
                ),
              ),
            ),
          // Notification Bar Overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 66.0),
                child: NotificationBar(service: _notificationService),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoArea() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: LiquidGlassTheme.primary),
            const SizedBox(height: LiquidGlassTheme.spacingMedium),
            Text(
              'Loading photo...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: LiquidGlassTheme.error.withValues(alpha: 0.7),
            ),
            const SizedBox(height: LiquidGlassTheme.spacingMedium),
            Text(
              'Failed to load photo',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: LiquidGlassTheme.spacingMedium),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _hasError = false;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: LiquidGlassTheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_currentPhotoFile == null) {
      return const Center(
        child: CircularProgressIndicator(color: LiquidGlassTheme.primary),
      );
    }

    return Center(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeInOut),
            ),
            child: child,
          );
        },
        child: _isCropMode
            ? CropEditorWidget(
                key: const ValueKey('crop-mode'),
                imageFile: _currentPhotoFile!,
                onCancel: _exitCropMode,
                onApply: _onCropApplied,
                onControlPanelReady: (builder) {
                  setState(() {
                    _cropControlPanelBuilder = builder;
                  });
                },
                onShowMessage: (message, isSuccess) {
                  _notificationService.show(
                    message,
                    type: isSuccess
                        ? NotificationType.success
                        : NotificationType.error,
                  );
                },
              )
            : _isRelightMode
            ? AnimatedPadding(
                padding: EdgeInsets.only(bottom: 240.0),
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                child: RelightEditorWidget(
                  key: const ValueKey('relight-mode'),
                  imageFile: _currentPhotoFile!,
                  segmentationService: _segmentationService, // Pass service
                  onCancel: _exitRelightMode,
                  onApply: _onRelightApplied,
                  onControlPanelReady: (builder) {
                    setState(() {
                      _relightControlPanelBuilder = builder;
                    });
                  },
                  onShowMessage: (message, isSuccess) {
                    if (!mounted) return;
                    try {
                    _notificationService.show(
                      message,
                      type: isSuccess
                          ? NotificationType.success
                          : NotificationType.error,
                    );
                    } catch (_) {}
                  },
                  controller: _relightController,
                ),
              )
            : _isReframeMode
            ? ReframeEditorWidget(
                key: const ValueKey('reframe-mode'),
                imageFile: _currentPhotoFile!,
                segmentationService: _segmentationService, // Pass service
                onCancel: _exitReframeMode,
                onApply: _onReframeApplied,
                onControlPanelReady: (builder) {
                  setState(() {
                    _reframeControlPanelBuilder = builder;
                  });
                },
                onShowMessage: (message, isSuccess) {
                  if (!mounted) return;
                  try {
                    _notificationService.show(
                      message,
                      type: isSuccess
                          ? NotificationType.success
                          : NotificationType.error,
                    );
                  } catch (_) {}
                },
              )
            : Hero(
                tag: 'photo-editing',
                child: Image.file(
                  _currentPhotoFile!,
                  key: ValueKey('normal-mode-${_currentPhotoFile!.path}'),
                  fit: BoxFit.contain,
                ),
              ),
      ),
    );
  }
}
