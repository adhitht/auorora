import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:apex/widgets/glass_button.dart';
import 'package:apex/widgets/tool_button.dart';
import 'package:crop_image/crop_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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

class CropEditorWidgetState extends State<CropEditorWidget> {
  late final CropController _cropController;
  bool _isProcessing = false;
  double? _aspectRatio;
  CropRotation _rotation = CropRotation.up;

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
      final ui.Image croppedUiImage = await _cropController.croppedBitmap(
        maxSize: 4096,
      );

      final ByteData? byteData = await croppedUiImage.toByteData(
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
    });
  }

//TODO: Integrate later
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

  void _resetCrop() {
    setState(() {
      _cropController.rotation = CropRotation.up;
      _cropController.crop = const Rect.fromLTRB(0.05, 0.05, 0.95, 0.95);
      _rotation = CropRotation.up;
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Expanded(
        child: Hero(
          tag: 'photo-editing',
          child: CropImage(
            controller: _cropController,
            image: imageWidget,
            paddingSize: 20.0,
            alwaysMove: true,
            minimumImageSize: 200,
            maximumImageSize: 4096,
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

      child: Row(
        children: [
          Expanded(
            child: LiquidStretch(
              stretch: 0.5,
              interactionScale: 1.05,
              child: LiquidGlass(
                shape: LiquidRoundedSuperellipse(borderRadius: 50),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          const SizedBox(width: 8),
                          _ratioChip('Free', null),
                          const SizedBox(width: 8),
                          _ratioChip('1:1', 1.0), // Square: 1.0
                          const SizedBox(width: 8),
                          _ratioChip(
                            '4:5',
                            0.8,
                          ), // Portrait: width/height = 4/5
                          const SizedBox(width: 8),
                          _ratioChip(
                            '3:4',
                            0.75,
                          ), // Portrait: width/height = 3/4
                          const SizedBox(width: 8),
                          _ratioChip(
                            '9:16',
                            0.5625,
                          ), // Portrait: width/height = 9/16
                          const SizedBox(width: 8),
                          _ratioChip(
                            '2:3',
                            0.6667,
                          ), // Portrait: width/height = 2/3
                          const SizedBox(width: 8),
                          _ratioChip(
                            '4:3',
                            1.3333,
                          ), // Landscape: width/height = 4/3
                          const SizedBox(width: 8),
                          _ratioChip(
                            '16:9',
                            1.7778,
                          ), // Landscape: width/height = 16/9
                          const SizedBox(width: 8),
                          _ratioChip(
                            '21:9',
                            2.3333,
                          ), // Ultrawide: width/height = 21/9
                          const SizedBox(width: 12),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          GlassButton(child: Icon(Icons.check), onTap: _applyCrop),
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
