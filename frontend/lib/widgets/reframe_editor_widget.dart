import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:aurora/widgets/glass_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/liquid_glass_theme.dart';
import 'liquid_slider.dart';
import '../services/segmentation_service.dart';
import '../services/pose_detection_service.dart';
import '../services/pose_changing_service.dart';
import '../models/pose_landmark.dart';
import 'pose_visualization_overlay.dart';
import 'segmented_cutout_view.dart';
import 'segmentation_feedback_overlay.dart';
import 'loading_indicator.dart';
import '../services/inpainting_service.dart';
import '../services/rainnet_harmonization_service.dart';

enum ReframeMode { initial, segmenting, segmented, moving, posing }

class ReframeEditorWidget extends StatefulWidget {
  final File imageFile;
  final SegmentationService segmentationService; // Add parameter
  final VoidCallback onCancel;
  final Function(File reframedFile) onApply;
  final Function(String message, bool isSuccess)? onShowMessage;
  final Function(Widget Function() builder)? onControlPanelReady;

  const ReframeEditorWidget({
    super.key,
    required this.imageFile,
    required this.segmentationService, // Add required parameter
    required this.onCancel,
    required this.onApply,
    this.onShowMessage,
    this.onControlPanelReady,
  });

  @override
  State<ReframeEditorWidget> createState() => ReframeEditorWidgetState();
}

class ReframeEditorWidgetState extends State<ReframeEditorWidget> {
  bool _isProcessing = false;
  bool _isPoseDetecting = false;
  bool _isSegmentationRunning = false;
  Size? _imageSize;

  ReframeMode _mode = ReframeMode.initial;

  PoseDetectionResult? _poseResult;
  CutoutResult? _cutoutResult;
  Offset _cutoutPosition = Offset.zero;
  double _lastScale = 1.0;

  final PoseDetectionService _poseService = PoseDetectionService();
  final InpaintingService _inpaintingService = InpaintingService();
  final RainnetHarmonizationService _harmonizationService =
      RainnetHarmonizationService();
  final PoseChangingService _poseChangingService = PoseChangingService();

  bool _isPoseServiceInitialized = false;

  bool _isMagicMoveEnabled = true;
  Uint8List? _cleanBackgroundBytes;

  ui.Image? _feedbackMaskImage;
  Key _feedbackKey = UniqueKey();

  // Pose Settings
  double _poseStrength = 0.6;
  double _poseConditioning = 1.0;
  double _poseSteps = 30.0; // Using double for slider compatibility

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _loadImageSize();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onControlPanelReady?.call(buildReframeOptionsBar);
    });
  }

  Future<void> _initializeServices() async {
    // Delay initialization to allow screen to load first
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    try {
      await _poseService.initialize();
      if (mounted) {
        setState(() {
          _isPoseServiceInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Failed to initialize pose service: $e');
    }

    // Segmentation initialization handled by parent

    try {
      await _inpaintingService.initialize();
    } catch (e) {
      debugPrint('Failed to initialize inpainting service: $e');
    }

    try {
      await _harmonizationService.initialize();
    } catch (e) {
      debugPrint('Failed to initialize harmonization service: $e');
    }
  }

  Future<void> _loadImageSize() async {
    final ImageProvider provider = FileImage(widget.imageFile);
    final ImageStream stream = provider.resolve(ImageConfiguration.empty);

    final completer = Completer<void>();

    final listener = ImageStreamListener(
      (ImageInfo info, bool synchronousCall) {
        if (mounted) {
          setState(() {
            _imageSize = Size(
              info.image.width.toDouble(),
              info.image.height.toDouble(),
            );
          });
        }
        completer.complete();
      },
      onError: (dynamic exception, StackTrace? stackTrace) {
        debugPrint('Failed to load image size: $exception');
        completer.complete();
      },
    );

    stream.addListener(listener);
    await completer.future;
    stream.removeListener(listener);
  }

  @override
  void dispose() {
    _poseService.dispose();
    _inpaintingService.dispose();
    _harmonizationService.dispose();
    _poseChangingService.shutdown();
    super.dispose();
  }

  Future<void> _detectPose() async {
    if (_isPoseDetecting || !_isPoseServiceInitialized) return;

    setState(() {
      _isPoseDetecting = true;
    });

    try {
      final result = await _poseService.detectPose(widget.imageFile);

      if (mounted) {
        setState(() {
          _poseResult = result;
          _isPoseDetecting = false;
        });

        if (result == null) {
          widget.onShowMessage?.call('No pose detected in image', false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPoseDetecting = false;
        });
        widget.onShowMessage?.call('Failed to detect pose: $e', false);
      }
    }
  }

  Future<ui.Image> _createMaskImage(Uint8List mask, int width, int height) {
    final completer = Completer<ui.Image>();
    final pixels = Uint8List(width * height * 4);
    for (int i = 0; i < width * height; i++) {
      final val = mask[i];
      pixels[i * 4] = 255;
      pixels[i * 4 + 1] = 255;
      pixels[i * 4 + 2] = 255;
      pixels[i * 4 + 3] = val;
    }
    ui.decodeImageFromPixels(
      pixels,
      width,
      height,
      ui.PixelFormat.rgba8888,
      (image) => completer.complete(image),
    );
    return completer.future;
  }

  Future<void> _handleSegmentationTrigger(double x, double y) async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      if (!widget.segmentationService.isEncoded) {
        await widget.segmentationService.encodeImage(widget.imageFile);
      }

      if (mounted &&
          widget.segmentationService.originalWidth > 0 &&
          widget.segmentationService.originalHeight > 0) {
        setState(() {
          _imageSize = Size(
            widget.segmentationService.originalWidth.toDouble(),
            widget.segmentationService.originalHeight.toDouble(),
          );
        });
      }

      final maskResult = await widget.segmentationService.getMaskForPoint(x, y);

      if (maskResult != null) {
        final feedbackImage = await _createMaskImage(
          maskResult.mask,
          maskResult.width,
          maskResult.height,
        );

        if (mounted) {
          setState(() {
            _feedbackMaskImage = feedbackImage;
            _feedbackKey = UniqueKey();
            _mode = ReframeMode.segmented;
            _cutoutResult = null;
            _cleanBackgroundBytes = null;
          });
          widget.onControlPanelReady?.call(buildReframeOptionsBar);
        }
      } else {
        if (mounted) {
          widget.onShowMessage?.call(
            'No object found at this location.',
            false,
          );
        }
      }
    } catch (e) {
      if (mounted) widget.onShowMessage?.call('Selection failed: $e', false);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _enterMoveMode() async {
    if (_mode == ReframeMode.moving) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      if (_cutoutResult == null) {
        final cutout = await widget.segmentationService.createCutout(
          widget.imageFile,
        );
        if (mounted) {
          setState(() {
            _cutoutResult = cutout;
            _cutoutPosition = Offset.zero;
          });
        }
      }

      if (_isMagicMoveEnabled && _cleanBackgroundBytes == null) {
        final segments = await widget.segmentationService.getAllSegments();
        if (segments.isNotEmpty) {
          final inpaintedBytes = await _inpaintingService.inpaint(
            widget.imageFile,
            segments.first,
          );

          if (mounted && inpaintedBytes != null) {
            setState(() {
              _cleanBackgroundBytes = inpaintedBytes;
            });
          }
        }
      }

      if (mounted) {
        setState(() {
          _mode = ReframeMode.moving;
          _isProcessing = false;
        });
        widget.onControlPanelReady?.call(buildReframeOptionsBar);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        widget.onShowMessage?.call('Failed to enter move mode: $e', false);
      }
    }
  }

  Future<void> _enterPoseMode() async {
    if (_mode == ReframeMode.posing) return;

    setState(() {
      _mode = ReframeMode.posing;
    });
    widget.onControlPanelReady?.call(buildReframeOptionsBar);

    if (_poseResult == null) {
      await _detectPose();
    }
  }

  Uint8List _serializePoseData(
    PoseDetectionResult result,
    int width,
    int height,
  ) {
    const types = [
      PoseLandmarkType.rightWrist,
      PoseLandmarkType.rightElbow,
      PoseLandmarkType.leftWrist,
      PoseLandmarkType.leftElbow,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.leftHip,
    ];

    final List<dynamic> jsonMap = [];

    for (final type in types) {
      final landmark = result.getLandmark(type);
      if (landmark != null) {
        jsonMap.add([landmark.x * width, landmark.y * height]);
      }
    }

    debugPrint("POSE CHANGINE JSON: " + json.encode(jsonMap));

    return utf8.encode(json.encode(jsonMap));
  }

  Future<void> _applyReframe() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final dir = await getTemporaryDirectory();
      final newFile = File(
        '${dir.path}/reframe_${DateTime.now().millisecondsSinceEpoch}.png',
      );

      if (_mode == ReframeMode.posing && _poseResult != null) {
        final imageBytes = await widget.imageFile.readAsBytes();
        final image = img.decodeImage(imageBytes);
        if (image == null) {
          throw Exception("Failed to decode image for pose change.");
        }
        final width = image.width;
        final height = image.height;
        final skeletonBytes = _serializePoseData(_poseResult!, width, height);

        final resultBytes = await _poseChangingService.changePose(
          imageBytes,
          skeletonBytes,
          numSteps: _poseSteps.round(),
          controlnetConditioning: _poseConditioning,
          strength: _poseStrength,
        );

        if (resultBytes != null) {
          await newFile.writeAsBytes(resultBytes);
          if (mounted) {
            widget.onApply(newFile);
          }
        } else {
          throw Exception("Pose service returned null image.");
        }
        return;
      }

      // local cutout?
      if (_cutoutResult != null && _mode == ReframeMode.moving) {
        img.Image? image;

        if (_cleanBackgroundBytes != null && _isMagicMoveEnabled) {
          image = img.decodeImage(_cleanBackgroundBytes!);
        } else {
          final bytes = await widget.imageFile.readAsBytes();
          image = img.decodeImage(bytes);
        }

        if (image != null) {
          if (_cleanBackgroundBytes == null || !_isMagicMoveEnabled) {
            image = img.bakeOrientation(image);
          }
          final cutoutImage = img.decodeImage(_cutoutResult!.imageBytes);

          if (cutoutImage != null) {
            final double offsetX = _cutoutPosition.dx / _lastScale;
            final double offsetY = _cutoutPosition.dy / _lastScale;

            final int targetX = (_cutoutResult!.x + offsetX).round();
            final int targetY = (_cutoutResult!.y + offsetY).round();

            img.compositeImage(
              image,
              cutoutImage,
              dstX: targetX,
              dstY: targetY,
            );

            // ---- HARMONIZATION ----
            // Create a mask for the cutout at the new position
            final fullMask = img.Image(
              width: image.width,
              height: image.height,
            );
            // Fill with black (0)
            img.fill(fullMask, color: img.ColorRgb8(0, 0, 0));

            // Draw the cutout shape (white) onto the mask
            // We can use the alpha channel of cutoutImage to determine the mask
            for (int y = 0; y < cutoutImage.height; y++) {
              for (int x = 0; x < cutoutImage.width; x++) {
                final pixel = cutoutImage.getPixel(x, y);
                if (pixel.a > 0) {
                  final dx = targetX + x;
                  final dy = targetY + y;
                  if (dx >= 0 &&
                      dx < fullMask.width &&
                      dy >= 0 &&
                      dy < fullMask.height) {
                    fullMask.setPixelRgb(dx, dy, 255, 255, 255);
                  }
                }
              }
            }

            final harmonizedBytes = await _harmonizationService.harmonize(
              image,
              fullMask,
            );

            if (harmonizedBytes != null) {
              final harmonizedImg = img.decodeImage(harmonizedBytes);
              if (harmonizedImg != null) {
                // Blend harmonized object back into the composite image
                // We use the mask to select pixels from harmonizedImg
                for (int y = 0; y < image.height; y++) {
                  for (int x = 0; x < image.width; x++) {
                    final m = fullMask.getPixel(x, y).r;
                    if (m > 128) {
                      // If mask is white (object)
                      final hPx = harmonizedImg.getPixel(x, y);
                      image.setPixel(x, y, hPx);
                    }
                  }
                }
              }
            }
            // -----------------------

            // Encode and save
            await newFile.writeAsBytes(img.encodePng(image));

            if (mounted) {
              widget.onApply(newFile);
            }
            return;
          }
        }
      }

      await widget.imageFile.copy(newFile.path);

      if (mounted) {
        widget.onApply(newFile);
      }
    } catch (e) {
      if (mounted) {
        widget.onShowMessage?.call('Failed to reframe image: $e', false);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _handleLandmarkMove(int index, Offset newPosition) {
    if (_poseResult == null) return;

    setState(() {
      final landmarks = List<PoseLandmark>.from(_poseResult!.landmarks);
      landmarks[index] = landmarks[index].copyWith(
        x: newPosition.dx,
        y: newPosition.dy,
      );

      _poseResult = PoseDetectionResult(
        id: _poseResult!.id,
        landmarks: landmarks,
        confidence: _poseResult!.confidence,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildReframeWidget(),

        if (_isProcessing || _isSegmentationRunning || _isPoseDetecting)
          Positioned.fill(
            child: ClipRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  color: Colors.black.withOpacity(0.3),
                  child: const Center(child: LoadingIndicator(size: 60)),
                ),
              ),
            ),
          ),

        // Instruction overlay for segmentation
        if (_mode == ReframeMode.segmenting && !_isProcessing)
          Positioned(
            top: 100,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Tap on a subject to select',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildReframeWidget() {
    if (_imageSize == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Hero(
        tag: 'photo-editing',
        child: Center(
          child: AspectRatio(
            aspectRatio: _imageSize!.width / _imageSize!.height,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double scale = constraints.maxWidth / _imageSize!.width;
                if (_lastScale != scale) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _lastScale = scale;
                      });
                    }
                  });
                }

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    GestureDetector(
                      onTapUp: (details) {
                        if (_mode == ReframeMode.segmenting) {
                          final localPos = details.localPosition;

                          final double relativeX =
                              localPos.dx / constraints.maxWidth;
                          final double relativeY =
                              localPos.dy / constraints.maxHeight;

                          final double originalX =
                              relativeX * _imageSize!.width;
                          final double originalY =
                              relativeY * _imageSize!.height;

                          HapticFeedback.mediumImpact();
                          _handleSegmentationTrigger(originalX, originalY);
                        }
                      },
                      child:
                          _mode == ReframeMode.moving &&
                              _cleanBackgroundBytes != null &&
                              _isMagicMoveEnabled
                          ? Image.memory(
                              _cleanBackgroundBytes!,
                              fit: BoxFit.fill,
                            )
                          : Image.file(widget.imageFile, fit: BoxFit.fill),
                    ),

                    // Segmentation Feedback
                    if (_feedbackMaskImage != null &&
                        (_mode == ReframeMode.segmented ||
                            _mode == ReframeMode.moving ||
                            _mode == ReframeMode.posing))
                      IgnorePointer(
                        child: SegmentationFeedbackOverlay(
                          key: _feedbackKey,
                          maskImage: _feedbackMaskImage!,
                          imageSize: constraints.biggest,
                        ),
                      ),

                    // Pose Visualization
                    if (_mode == ReframeMode.posing && _poseResult != null)
                      PoseVisualizationOverlay(
                        poseResult: _poseResult,
                        imageSize: constraints.biggest,
                        showConnections: true,
                        onLandmarkMoved: _handleLandmarkMove,
                      ),

                    // Segmentation cutout (Move Mode)
                    if (_mode == ReframeMode.moving && _cutoutResult != null)
                      Positioned(
                        left: (_cutoutResult!.x * scale) + _cutoutPosition.dx,
                        top: (_cutoutResult!.y * scale) + _cutoutPosition.dy,
                        width: _cutoutResult!.width * scale,
                        height: _cutoutResult!.height * scale,
                        child: GestureDetector(
                          onPanUpdate: (details) {
                            setState(() {
                              _cutoutPosition += details.delta;
                            });
                          },
                          child: SegmentedCutoutView(
                            imageBytes: _cutoutResult!.imageBytes,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget buildReframeOptionsBar() {
    return LiquidGlassLayer(
      settings: const LiquidGlassSettings(
        thickness: 25,
        blur: 20,
        glassColor: LiquidGlassTheme.glassDark,
        lightIntensity: 0.15,
        saturation: 1,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_mode == ReframeMode.posing) ...[
              _buildSliderRow("Steps", _poseSteps, 1, 50, (v) {
                setState(() => _poseSteps = v);
                widget.onControlPanelReady?.call(buildReframeOptionsBar);
              }, isInt: true),
              const SizedBox(height: 8),
              _buildSliderRow("Control", _poseConditioning, 0, 2, (v) {
                setState(() => _poseConditioning = v);
                widget.onControlPanelReady?.call(buildReframeOptionsBar);
              }),
              const SizedBox(height: 8),
              _buildSliderRow("Strength", _poseStrength, 0, 1, (v) {
                setState(() => _poseStrength = v);
                widget.onControlPanelReady?.call(buildReframeOptionsBar);
              }),
              const SizedBox(height: 16),
              Container(height: 1, color: Colors.white.withOpacity(0.1)),
              const SizedBox(height: 12),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left Button: Segmentation / Reset
                GlassButton(
                  onTap: () {
                    setState(() {
                      _mode = ReframeMode.segmenting;
                      _poseResult = null;
                      _cutoutResult = null;
                      _cleanBackgroundBytes = null;
                      _feedbackMaskImage = null;
                    });
                    widget.onControlPanelReady?.call(buildReframeOptionsBar);
                  },
                  width: 48,
                  height: 48,
                  borderRadius: 24,
                  child: SvgPicture.asset(
                    'assets/icons/select_object.svg',
                    width: 20,
                    height: 20,
                    colorFilter: ColorFilter.mode(
                      _mode == ReframeMode.initial ||
                              _mode == ReframeMode.segmenting
                          ? LiquidGlassTheme.primary
                          : Colors.white,
                      BlendMode.srcIn,
                    ),
                  ),
                ),

                // Center Pill: Move & Pose Toggle
                if (_mode != ReframeMode.initial &&
                    _mode != ReframeMode.segmenting)
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Move Button (Reframing)
                        _buildPillButton(
                          iconPath: 'assets/icons/move.svg',
                          isActive: _mode == ReframeMode.moving,
                          onTap: _enterMoveMode,
                        ),

                        const SizedBox(width: 4),

                        // Pose Button (Pose Detection)
                        _buildPillButton(
                          iconPath: 'assets/icons/pose_correction.svg',
                          isActive: _mode == ReframeMode.posing,
                          onTap: _enterPoseMode,
                        ),
                      ],
                    ),
                  )
                else
                  // Placeholder to keep layout balanced
                  const SizedBox(width: 48),

                // Right Button: Apply
                GlassButton(
                  onTap: _applyReframe,
                  width: 48,
                  height: 48,
                  borderRadius: 24,
                  child: SvgPicture.asset(
                    'assets/icons/tick.svg',
                    width: 20,
                    height: 20,
                    colorFilter: const ColorFilter.mode(
                      Colors.white,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderRow(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    bool isInt = false,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: SizedBox(
            height: 20, // Compact height
            child: LiquidSlider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 30,
          child: Text(
            isInt ? value.round().toString() : value.toStringAsFixed(1),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Widget _buildPillButton({
    required String iconPath,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isActive ? Colors.white.withOpacity(0.1) : Colors.transparent,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: SvgPicture.asset(
          iconPath,
          width: 18,
          height: 18,
          colorFilter: ColorFilter.mode(
            isActive ? Colors.white : Colors.white.withOpacity(0.5),
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }
}
