  import 'dart:async';
  import 'dart:io';
  import 'dart:ui' as ui;
  import 'dart:typed_data';

  import 'package:apex/widgets/glass_button.dart';
  import 'package:flutter/cupertino.dart';
  import 'package:flutter/material.dart';
  import 'package:flutter/services.dart';
  import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
  import 'package:path_provider/path_provider.dart';
  import 'package:image/image.dart' as img;

  import '../theme/liquid_glass_theme.dart';
  import '../services/segmentation_service.dart';
  import '../services/pose_detection_service.dart';
  import '../models/pose_landmark.dart';
  import 'pose_visualization_overlay.dart';
  import 'segmented_cutout_view.dart';
  import 'segmentation_feedback_overlay.dart';
  import 'loading_indicator.dart';
  import '../services/inpainting_service.dart';

  enum ReframeMode {
    initial,
    segmenting,
    segmented,
    moving,
    posing,
  }

  class ReframeEditorWidget extends StatefulWidget {
    final File imageFile;
    final VoidCallback onCancel;
    final Function(File reframedFile) onApply;
    final Function(String message, bool isSuccess)? onShowMessage;
    final Function(Widget Function() builder)? onControlPanelReady;

    const ReframeEditorWidget({
      super.key,
      required this.imageFile,
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
    final SegmentationService _segmentationService = SegmentationService();
    final InpaintingService _inpaintingService = InpaintingService();
    bool _isPoseServiceInitialized = false;
    
    bool _isMagicMoveEnabled = true;
    Uint8List? _cleanBackgroundBytes;
    
    ui.Image? _feedbackMaskImage;
    Key _feedbackKey = UniqueKey();

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

      try {
        await _segmentationService.initialize();
        if (mounted) {
          _segmentationService.encodeImage(widget.imageFile).catchError((e) {
            debugPrint('Background encoding failed: $e');
          });
        }
      } catch (e) {
        debugPrint('Failed to initialize segmentation service: $e');
      }

      try {
        await _inpaintingService.initialize();
      } catch (e) {
        debugPrint('Failed to initialize inpainting service: $e');
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
      _segmentationService.dispose();
      _inpaintingService.dispose();
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
        if (!_segmentationService.isEncoded) {
          await _segmentationService.encodeImage(widget.imageFile);
        }

        if (mounted &&
            _segmentationService.originalWidth > 0 &&
            _segmentationService.originalHeight > 0) {
          setState(() {
            _imageSize = Size(
              _segmentationService.originalWidth.toDouble(),
              _segmentationService.originalHeight.toDouble(),
            );
          });
        }

        final maskResult = await _segmentationService.getMaskForPoint(x, y);
        
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
          final cutout = await _segmentationService.createCutout(widget.imageFile);
          if (mounted) {
            setState(() {
              _cutoutResult = cutout;
              _cutoutPosition = Offset.zero;
            });
          }
        }

        if (_isMagicMoveEnabled && _cleanBackgroundBytes == null) {
          final segments = await _segmentationService.getAllSegments();
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
          setState(() {
            _isProcessing = false;
          });
          widget.onShowMessage?.call('Failed to reframe image: $e', false);
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
                    child: const Center(
                      child: LoadingIndicator(size: 60),
                    ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Tap on a subject to select',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
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
                            
                            final double relativeX = localPos.dx / constraints.maxWidth;
                            final double relativeY = localPos.dy / constraints.maxHeight;

                            final double originalX = relativeX * _imageSize!.width;
                            final double originalY = relativeY * _imageSize!.height;

                            HapticFeedback.mediumImpact();
                            _handleSegmentationTrigger(originalX, originalY);
                          }
                        },
                        child: _mode == ReframeMode.moving && 
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
                          (_mode == ReframeMode.segmented || _mode == ReframeMode.moving || _mode == ReframeMode.posing))
                        IgnorePointer(
                          child: SegmentationFeedbackOverlay(
                            key: _feedbackKey,
                            maskImage: _feedbackMaskImage!,
                            imageSize: constraints.biggest,
                          ),
                        ),

                      // Pose Visualization
                      if (_mode == ReframeMode.posing &&
                          _poseResult != null)
                        PoseVisualizationOverlay(
                          poseResult: _poseResult,
                          imageSize: constraints.biggest,
                          showConnections: true,
                          onLandmarkMoved: _handleLandmarkMove,
                        ),

                      // Segmentation cutout (Move Mode)
                      if (_mode == ReframeMode.moving &&
                          _cutoutResult != null)
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
        child: Row(
          children: [
            if (_mode == ReframeMode.initial || _mode == ReframeMode.segmenting)
              GlassButton(
                onTap: () {
                  setState(() {
                    _mode = _mode == ReframeMode.segmenting 
                        ? ReframeMode.initial 
                        : ReframeMode.segmenting;
                  });
                  widget.onControlPanelReady?.call(buildReframeOptionsBar);
                },
                child: 
                    Icon(
                      _mode == ReframeMode.segmenting
                          ? CupertinoIcons.person_crop_circle_fill
                          : CupertinoIcons.person_crop_circle,
                      color: _mode == ReframeMode.segmenting
                          ? LiquidGlassTheme.primary
                          : Colors.white,
                    ),
              ),

            if (_mode == ReframeMode.segmented || 
                _mode == ReframeMode.moving || 
                _mode == ReframeMode.posing) ...[
              GlassButton(
                onTap: _enterMoveMode,
                child: 
                    Icon(
                      CupertinoIcons.move,
                      color: _mode == ReframeMode.moving
                          ? LiquidGlassTheme.primary
                          : Colors.white,
                    ),
              ),
              const SizedBox(width: 12),
              GlassButton(
                onTap: _enterPoseMode,
                child:
                    Icon(
                      CupertinoIcons.person_crop_circle,
                      color: _mode == ReframeMode.posing
                          ? LiquidGlassTheme.primary
                          : Colors.white,
                    ),
                ),
            ],

            const Spacer(),

            GlassButton(onTap: _applyReframe, child: const Icon(Icons.check)),
          ],
        ),
      );
    }
  }
