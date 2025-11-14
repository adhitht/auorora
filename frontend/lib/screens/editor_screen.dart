// editor_screen.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crop_image/crop_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../theme/liquid_glass_theme.dart';
import '../services/image_processing_service.dart';
import '../widgets/editor_top_bar.dart';
import '../widgets/editor_bottom_bar.dart';

/// Editor screen for photo editing operations with inline cropping using crop_image.
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

  // Crop controller from crop_image
  final CropController _cropController = CropController();
  bool _isCropMode = false;

  // Aspect ratio selected (null = free)
  double? _aspectRatio;

  // Rotation state
  CropRotation _rotation = CropRotation.up;

  final ImageProcessingService _imageService = ImageProcessingService();

  @override
  void initState() {
    super.initState();
    _currentPhotoFile = widget.photoFile;
    // initialize default crop controller values if needed
    _cropController.aspectRatio = null;
    _cropController.rotation = _rotation;
  }

  @override
  void dispose() {
    _cropController.dispose();
    super.dispose();
  }

  void _navigateBack() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
  }

  void _enterCropMode() {
    if (_currentPhotoFile == null) return;
    setState(() {
      _isCropMode = true;
      // Reset aspect ratio to current selection (keep previous if any)
      _cropController.aspectRatio = _aspectRatio;
      _cropController.rotation = _rotation;
      // optionally reset crop rect to a nice default
      _cropController.crop = const Rect.fromLTRB(0.05, 0.05, 0.95, 0.95);
    });
  }

  Future<void> _applyCrop() async {
    if (!_isCropMode) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Get cropped ui.Image (bitmap) from controller
      final ui.Image? croppedUiImage = await _cropController.croppedBitmap(
        // you can specify maxSize (pixels) to constrain the result
        maxSize: 4096,
      );

      if (croppedUiImage == null) {
        throw Exception('Cropped image is null');
      }

      // Convert ui.Image to PNG bytes
      final ByteData? byteData = await croppedUiImage.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData == null)
        throw Exception('Failed to convert cropped image to bytes');

      final Uint8List bytes = byteData.buffer.asUint8List();

      // Save to a temporary file (or use your ImageProcessingService to persist)
      final File saved = await _saveBytesToTempFile(bytes);

      // Optionally, run any extra processing (compression, orientation correction) using ImageProcessingService
      final File finalSaved = saved;

      setState(() {
        _currentPhotoFile = finalSaved;
        _isCropMode = false;
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Crop applied'), duration: Duration(seconds: 3)),
      );
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to crop image:'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<File> _saveBytesToTempFile(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/crop_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    return file.writeAsBytes(bytes, flush: true);
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
            content: Text('Photo saved to Gallery'),
            duration: Duration(seconds: 3),
          ),
        );
        debugPrint('Photo saved at: ${savedFile.path}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save image:'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  void _setAspectRatio(double? value) {
    setState(() {
      _aspectRatio = value;
      _cropController.aspectRatio = value;
    });
  }

  void _rotateLeft() {
    _cropController.rotateLeft();
    setState(() {
      _rotation = _cropController.rotation;
    });
  }

  void _rotateRight() {
    _cropController.rotateRight();
    setState(() {
      _rotation = _cropController.rotation;
    });
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

              // Photo display area (expanded)
              Expanded(child: _buildPhotoArea()),

              // Space for bottom bar (we will overlay the crop options bar above the bottom bar)
              const SizedBox(height: 100),
            ],
          ),

          // Crop options bar (above bottom bar)
          if (_isCropMode) _buildCropOptionsBar(),

          // Bottom navigation bar (existing)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: EditorBottomBar(
              toolCallbacks: <EditorTool, VoidCallback?>{
                EditorTool.crop: _enterCropMode,
                // keep other tools null so they don't break; your EditorBottomBar implementation can handle missing callbacks
              },
            ),
          ),

          // Processing overlay
          if (_isProcessing)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.45),
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
                color: Colors.white.withOpacity(0.7),
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
              color: LiquidGlassTheme.error.withOpacity(0.7),
            ),
            const SizedBox(height: LiquidGlassTheme.spacingMedium),
            Text(
              'Failed to load photo',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
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

    // When not in crop mode, just display the image; when in crop mode, show CropImage widget
    return Center(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _isCropMode
            ? _buildCropWidget()
            : Image.file(_currentPhotoFile!, fit: BoxFit.contain),
      ),
    );
  }

  Widget _buildCropWidget() {
    // CropImage (from crop_image package) expects an Image widget.
    final imageWidget = Image.file(_currentPhotoFile!, fit: BoxFit.contain);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          color: Colors.black,
          child: Column(
            children: [
              // Controls row: rotate left/right + spacer
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _rotateLeft,
                      icon: const Icon(Icons.rotate_90_degrees_ccw_outlined),
                      color: Colors.white,
                      tooltip: 'Rotate left',
                    ),
                    IconButton(
                      onPressed: _rotateRight,
                      icon: const Icon(Icons.rotate_90_degrees_cw_outlined),
                      color: Colors.white,
                      tooltip: 'Rotate right',
                    ),
                    const Spacer(),
                    // quick reset button
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _cropController.rotation = CropRotation.up;
                          _cropController.crop = const Rect.fromLTRB(
                            0.05,
                            0.05,
                            0.95,
                            0.95,
                          );
                        });
                      },
                      icon: const Icon(Icons.refresh),
                      color: Colors.white70,
                      tooltip: 'Reset',
                    ),
                  ],
                ),
              ),

              // The crop area itself - expands to take remaining space
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return CropImage(
                      controller: _cropController,
                      image: imageWidget,
                      paddingSize: 20.0,
                      alwaysMove: true, // lets user pan image
                      minimumImageSize: 200,
                      maximumImageSize: 4096,
                      // optional: provide decoration and appearance with the package defaults
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCropOptionsBar() {
    // Positioned above bottom bar, glass-like look
    return Positioned(
      left: 12,
      right: 12,
      bottom: 72, // leaves space for bottom bar
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.26),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.35),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            _ratioChip('Free', null),
            const SizedBox(width: 8),
            _ratioChip('1:1', 1.0),
            const SizedBox(width: 8),
            _ratioChip('4:5', 4.0 / 5.0),
            const SizedBox(width: 8),
            _ratioChip('9:16', 9.0 / 16.0),
            const SizedBox(width: 8),
            _ratioChip('9:21', 9.0 / 21.0),
            const Spacer(),

            // Apply / Cancel buttons
            TextButton.icon(
              onPressed: _applyCrop,
              icon: const Icon(Icons.check, color: Colors.white),
              label: const Text('Apply', style: TextStyle(color: Colors.white)),
              style: TextButton.styleFrom(
                backgroundColor: LiquidGlassTheme.primary.withOpacity(0.15),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _isCropMode = false;
                });
              },
              icon: const Icon(Icons.close, color: Colors.white70),
              label: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white10,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ratioChip(String label, double? ratio) {
    final bool selected = _aspectRatio == ratio;
    return GestureDetector(
      onTap: () => _setAspectRatio(ratio),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? LiquidGlassTheme.primary.withOpacity(0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? LiquidGlassTheme.primary : Colors.white10,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? LiquidGlassTheme.primary : Colors.white,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
