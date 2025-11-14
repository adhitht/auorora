import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/liquid_glass_theme.dart';
import '../services/image_processing_service.dart';
import '../widgets/editor_top_bar.dart';
import '../widgets/editor_bottom_bar.dart';
import '../widgets/crop_editor_widget.dart';

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

  final ImageProcessingService _imageService = ImageProcessingService();

  @override
  void initState() {
    super.initState();
    _currentPhotoFile = widget.photoFile;
  }

  void _navigateBack() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
  }

  void _enterCropMode() {
    if (_currentPhotoFile == null) return;
    setState(() {
      _isCropMode = true;
    });
  }

  void _exitCropMode() {
    setState(() {
      _isCropMode = false;
    });
  }

  void _onCropApplied(File croppedFile) {
    setState(() {
      _currentPhotoFile = croppedFile;
      _isCropMode = false;
      _isProcessing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Crop applied')),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Photo saved successfully to ${savedFile.path}')),
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
                isSaving: _isProcessing,
              ),

              Expanded(child: _buildPhotoArea()),

              const SizedBox(height: 100),
            ],
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: EditorBottomBar(
              toolCallbacks: <EditorTool, VoidCallback?>{
                EditorTool.crop: _enterCropMode,
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
        duration: const Duration(milliseconds: 200),
        child: _isCropMode
            ? CropEditorWidget(
                imageFile: _currentPhotoFile!,
                onCancel: _exitCropMode,
                onApply: _onCropApplied,
                onShowMessage: (message, isSuccess) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(message)),
                  );
                },
              )
            : Image.file(_currentPhotoFile!, fit: BoxFit.contain),
      ),
    );
  }
}
