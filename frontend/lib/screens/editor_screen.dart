import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/liquid_glass_theme.dart';
import '../services/image_processing_service.dart';
import '../services/edit_history_manager.dart';
import '../models/edit_history.dart';
import '../widgets/editor_top_bar.dart';
import '../widgets/editor_bottom_bar.dart';
import '../widgets/crop_editor_widget.dart';
import '../widgets/relight_editor_widget.dart';
import '../widgets/reframe_editor_widget.dart';
import '../widgets/history_viewer_dialog.dart';

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

  Widget Function()? _relightControlPanelBuilder;
  Widget Function()? _cropControlPanelBuilder;
  Widget Function()? _reframeControlPanelBuilder;

  final ImageProcessingService _imageService = ImageProcessingService();
  late final EditHistoryManager _historyManager;

  @override
  void initState() {
    super.initState();
    _currentPhotoFile = widget.photoFile;

    // Initialize history manager
    _historyManager = EditHistoryManager(maxHistorySize: 50);

    // Add initial image to history
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

    // Listen to history changes
    _historyManager.addListener(_onHistoryChanged);
  }

  @override
  void dispose() {
    _historyManager.removeListener(_onHistoryChanged);
    _historyManager.dispose();
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
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Undone: ${entry.type.displayName}'),
          duration: const Duration(seconds: 1),
        ),
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
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Redone: ${entry.type.displayName}'),
          duration: const Duration(seconds: 1),
        ),
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
    });
  }

  void _enterRelightMode() {
    if (_currentPhotoFile == null) return;
    setState(() {
      _isRelightMode = true;
      _isCropMode = false;
      _isReframeMode = false;
    });
  }

  void _enterReframeMode() {
    if (_currentPhotoFile == null) return;
    setState(() {
      _isReframeMode = true;
      _isCropMode = false;
      _isRelightMode = false;
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

    // Exit other modes
    if (tool != EditorTool.crop && _isCropMode) {
      _exitCropMode();
    }
    if (tool != EditorTool.relight && _isRelightMode) {
      _exitRelightMode();
    }
    if (tool != EditorTool.reframe && _isReframeMode) {
      _exitReframeMode();
    }

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
      case EditorTool.filters:
        // TODO: Implement filters
        break;
    }
  }

  void _exitCropMode() {
    setState(() {
      _isCropMode = false;
      _cropControlPanelBuilder = null; // Clear builder when exiting
    });
  }

  void _exitRelightMode() {
    setState(() {
      _isRelightMode = false;
      _relightControlPanelBuilder = null; // Clear builder when exiting
    });
  }

  void _exitReframeMode() {
    setState(() {
      _isReframeMode = false;
      _reframeControlPanelBuilder = null; // Clear builder when exiting
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
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Crop applied')));
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
        },
      ),
    );

    setState(() {
      _currentPhotoFile = relitFile;
      _isRelightMode = false;
      _isProcessing = false;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Adjustments applied')));
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
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Reframe applied')));
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Photo saved successfully to ${savedFile.path}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save photo: ${e.toString()}')),
        );
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
                onUndoTap: _handleUndo,
                onRedoTap: _handleRedo,
                onHistoryTap: _showHistoryViewer,
                isSaving: _isProcessing,
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

          // Bottom bar (always visible, on top)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: EditorBottomBar(
              toolCallbacks: <EditorTool, VoidCallback?>{
                EditorTool.crop: () => _handleToolSelection(EditorTool.crop),
                EditorTool.relight: () =>
                    _handleToolSelection(EditorTool.relight),
                EditorTool.reframe: () =>
                    _handleToolSelection(EditorTool.reframe),
                EditorTool.filters: () =>
                    _handleToolSelection(EditorTool.filters),
              },
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
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(message)));
                },
              )
            : _isRelightMode
            ? RelightEditorWidget(
                key: const ValueKey('relight-mode'),
                imageFile: _currentPhotoFile!,
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
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(message)));
                  } catch (_) {}
                },
              )
            : _isReframeMode
            ? ReframeEditorWidget(
                key: const ValueKey('reframe-mode'),
                imageFile: _currentPhotoFile!,
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
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(message)));
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
