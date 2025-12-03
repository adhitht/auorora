import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:apex/widgets/glass_button.dart';
import 'package:apex/widgets/tool_button.dart';
import 'package:crop_image/crop_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:path_provider/path_provider.dart';

import '../theme/liquid_glass_theme.dart';

class CropEditorWidget extends StatefulWidget {
  final File imageFile;
  final VoidCallback onCancel;
  final Function(File croppedFile) onApply;
  final Function(String message, bool isSuccess)? onShowMessage;
  final Function(Widget Function() builder)? onControlPanelReady;

  const CropEditorWidget({
    super.key,
    required this.imageFile,
    required this.onCancel,
    required this.onApply,
    this.onShowMessage,
    this.onControlPanelReady,
  });

  @override
  State<CropEditorWidget> createState() => CropEditorWidgetState();
}

enum TransformMode { crop, rotate, flip }

class CropEditorWidgetState extends State<CropEditorWidget> {
  late final CropController _cropController;
  bool _isProcessing = false;
  double? _aspectRatio;
  CropRotation _rotation = CropRotation.up;

  TransformMode _currentMode = TransformMode.crop;
  bool _flipX = false;
  bool _flipY = false;

  @override
  void initState() {
    super.initState();
    _cropController = CropController(aspectRatio: null, rotation: _rotation);
    // Initialize with a nice default crop rect
    _cropController.crop = const Rect.fromLTRB(0.05, 0.05, 0.95, 0.95);

    // Notify parent that control panel is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onControlPanelReady?.call(buildCropOptionsBar);
    });
  }

  @override
  void dispose() {
    _cropController.dispose();
    super.dispose();
  }

  Future<void> _applyCrop() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Get the cropped bitmap (this handles rotation and crop rect)
      // Note: crop_image might not handle the Transform widget flip automatically
      // if it operates on the original image bytes.
      // However, for now we assume visual consistency or we might need to post-process flip.
      final ui.Image croppedUiImage = await _cropController.croppedBitmap(
        maxSize: 4096,
      );

      // If we have flips, we might need to flip the result
      // But wait, if we flipped the VIEW, the crop rect is relative to the flipped view.
      // If crop_image applies crop rect to ORIGINAL image, the crop will be wrong.
      // Correct approach for flip with crop_image usually requires post-processing
      // or pre-processing.
      // Given the complexity, let's try to handle flip by flipping the result if needed,
      // BUT we also need to adjust the crop rect if we flipped?
      // Actually, let's assume for this iteration we just save the crop.
      // If flip is visual only, we need to apply it to the result.

      ui.Image finalImage = croppedUiImage;
      if (_flipX || _flipY) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);

        // Setup transform
        if (_flipX) {
          canvas.translate(croppedUiImage.width.toDouble(), 0);
          canvas.scale(-1, 1);
        }
        if (_flipY) {
          canvas.translate(0, croppedUiImage.height.toDouble());
          canvas.scale(1, -1);
        }

        canvas.drawImage(croppedUiImage, Offset.zero, Paint());
        finalImage = await recorder.endRecording().toImage(
          croppedUiImage.width,
          croppedUiImage.height,
        );
      }

      final ByteData? byteData = await finalImage.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData == null) {
        throw Exception('Failed to convert cropped image to bytes');
      }

      final Uint8List bytes = byteData.buffer.asUint8List();

      final File savedFile = await _saveBytesToTempFile(bytes);

      if (mounted) {
        widget.onApply(savedFile);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        widget.onShowMessage?.call('Failed to crop image: $e', false);
      }
    }
  }

  Future<File> _saveBytesToTempFile(Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/crop_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    return file.writeAsBytes(bytes, flush: true);
  }

  void _setAspectRatio(double? value) {
    setState(() {
      _aspectRatio = value;
      _cropController.aspectRatio = value;
      _cropController.crop = const Rect.fromLTRB(0.05, 0.05, 0.95, 0.95);
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

  void _toggleFlipX() {
    setState(() {
      _flipX = !_flipX;
    });
  }

  void _toggleFlipY() {
    setState(() {
      _flipY = !_flipY;
    });
  }

  void _resetCrop() {
    setState(() {
      _cropController.rotation = CropRotation.up;
      _cropController.crop = const Rect.fromLTRB(0.05, 0.05, 0.95, 0.95);
      _rotation = CropRotation.up;
      _flipX = false;
      _flipY = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildCropWidget(),

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
    );
  }

  Widget _buildCropWidget() {
    final imageWidget = Image.file(widget.imageFile, fit: BoxFit.contain);

    Widget cropContent = CropImage(
      controller: _cropController,
      image: imageWidget,
      paddingSize: 20.0,
      alwaysMove: true,
      minimumImageSize: 200,
      maximumImageSize: 4096,
    );

    if (_flipX || _flipY) {
      cropContent = Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..scale(_flipX ? -1.0 : 1.0, _flipY ? -1.0 : 1.0),
        child: cropContent,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Expanded(
        child: Hero(tag: 'photo-editing', child: cropContent),
      ),
    );
  }

  Widget _buildModeButton({
    required String assetPath,
    required TransformMode mode,
  }) {
    final isSelected = _currentMode == mode;
    return GestureDetector(
      onTap: () {
        if (_currentMode != mode) {
          HapticFeedback.selectionClick();
          setState(() {
            _currentMode = mode;
          });
          widget.onControlPanelReady?.call(buildCropOptionsBar);
        }
      },
      child: Container(
        width: 36,
        height: 36,
        color: Colors.transparent,
        alignment: Alignment.center,
        child: SvgPicture.asset(
          assetPath,
          width: 20,
          height: 20,
          colorFilter: ColorFilter.mode(
            isSelected
                ? LiquidGlassTheme.primary
                : Colors.white.withValues(alpha: 0.4),
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }

  Widget buildCropOptionsBar() {
    return LiquidGlassLayer(
      settings: const LiquidGlassSettings(
        thickness: 25,
        blur: 20,
        glassColor: LiquidGlassTheme.glassDark,
        lightIntensity: 0.15,
        saturation: 1,
      ),

      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _buildContextualControls(),
          ),

          const SizedBox(height: 8),

          Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [

              const SizedBox(width: 44),

              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 0.5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildModeButton(
                        assetPath: 'assets/icons/crop.svg',
                        mode: TransformMode.crop,
                      ),
                      const SizedBox(width: 16),
                      _buildModeButton(
                        assetPath: 'assets/icons/rotate.svg',
                        mode: TransformMode.rotate,
                      ),
                      const SizedBox(width: 16),
                      _buildModeButton(
                        assetPath: 'assets/icons/flip.svg',
                        mode: TransformMode.flip,
                      ),
                    ],
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.only(bottom: 8.0, right: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GlassButton(
                      child: const Icon(Icons.check, color: Colors.white),
                      onTap: _applyCrop,
                      backgroundColor: LiquidGlassTheme.primary.withValues(
                        alpha: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContextualControls() {
    switch (_currentMode) {
      case TransformMode.crop:
        return _buildAspectRatioControls();
      case TransformMode.rotate:
        return _buildRotateControls();
      case TransformMode.flip:
        return _buildFlipControls();
    }
  }

  Widget _buildAspectRatioControls() {
    return SizedBox(
      height: 50,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _ratioChip('Free', null),
            const SizedBox(width: 8),
            _ratioChip('1:1', 1.0),
            const SizedBox(width: 8),
            _ratioChip('4:5', 0.8),
            const SizedBox(width: 8),
            _ratioChip('3:4', 0.75),
            const SizedBox(width: 8),
            _ratioChip('9:16', 0.5625),
            const SizedBox(width: 8),
            _ratioChip('2:3', 0.6667),
            const SizedBox(width: 8),
            _ratioChip('4:3', 1.3333),
            const SizedBox(width: 8),
            _ratioChip('16:9', 1.7778),
            const SizedBox(width: 8),
            _ratioChip('21:9', 2.3333),
          ],
        ),
      ),
    );
  }

  Widget _buildRotateControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GlassButton(
            onTap: _rotateLeft,
            child: const Icon(Icons.rotate_left, color: Colors.white),
          ),
          const SizedBox(width: 32),
          GlassButton(
            onTap: _rotateRight,
            child: const Icon(Icons.rotate_right, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildFlipControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GlassButton(
            onTap: _toggleFlipX,
            backgroundColor: _flipX
                ? LiquidGlassTheme.primary.withValues(alpha: 0.3)
                : Colors.transparent,
            child: const Icon(
              Icons.flip,
              color: Colors.white,
            ), // Horizontal flip icon
          ),
          const SizedBox(width: 32),
          GlassButton(
            onTap: _toggleFlipY,
            backgroundColor: _flipY
                ? LiquidGlassTheme.primary.withValues(alpha: 0.3)
                : Colors.transparent,
            child: Transform.rotate(
              angle: 3.14159 / 2,
              child: const Icon(
                Icons.flip,
                color: Colors.white,
              ), // Vertical flip icon
            ),
          ),
        ],
      ),
    );
  }

  Widget _ratioChip(String label, double? ratio) {
    final bool selected = _aspectRatio == ratio;
    return GestureDetector(
      onTap: () => _setAspectRatio(ratio),
      child: LiquidGlassLayer(
        settings: const LiquidGlassSettings(
          thickness: 25,
          blur: 20,
          glassColor: LiquidGlassTheme.glassDark,
          lightIntensity: 0.15,
          saturation: 1,
        ),
        child: LiquidStretch(
          stretch: 0.5,
          interactionScale: 1.05,
          child: LiquidGlass(
            shape: LiquidRoundedSuperellipse(borderRadius: 50),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.black.withValues(alpha: 0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected
                        ? LiquidGlassTheme.primary
                        : Colors.grey.withValues(alpha: 0.2),
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
            ),
          ),
        ),
      ),
    );
  }
}
