import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import '../theme/liquid_glass_theme.dart';
import '../services/suggestions_service.dart';
import '../services/semantic_router_service.dart';
import '../services/pipeline_executor.dart';
import '../services/notification_service.dart';
import '../services/llm_service.dart';
import 'relight_editor_controller.dart';
import 'dart:async';
import '../models/chat_message.dart';

enum EditorTool {
  crop("assets/icons/transform.svg", "Transform"),
  relight("assets/icons/relight.svg", "Relight"),
  reframe("assets/icons/reframe.svg", "Reframe"),
  chat("assets/icons/star.svg", "Chat");

  final String iconPath;
  final String label;

  const EditorTool(this.iconPath, this.label);
}

class EditorBottomBar extends StatefulWidget {
  final Map<EditorTool, VoidCallback?> toolCallbacks;
  final List<EditorTool> tools;
  final EditorTool? selectedTool;
  final List<String>? detectedTags;
  final Set<String>? dismissedSuggestions;
  final Function(String)? onSuggestionSelected;

  const EditorBottomBar({
    super.key,
    required this.toolCallbacks,
    this.tools = EditorTool.values,
    this.selectedTool,
    this.detectedTags,
    this.dismissedSuggestions,
    this.onSuggestionSelected,
    this.relightController,
    required this.notificationService,
  });

  final RelightEditorController? relightController;
  final NotificationService notificationService;

  @override
  State<EditorBottomBar> createState() => _EditorBottomBarState();
}

class _EditorBottomBarState extends State<EditorBottomBar> {
  bool _isMoving = false;
  bool _isDragging = false;
  double _dragX = 0.0;
  int _lastHoverIndex = -1;

  late List<GlobalKey> _keys;
  final GlobalKey _stackKey = GlobalKey();

  double _x = -4;
  double _width = 0;

  final LlmService _llmService = LlmService();
  late final SuggestionsService _suggestionsService = SuggestionsService(
    _llmService,
  );
  List<String> _currentSuggestions = [];
  bool _isLoadingSuggestions = false;
  final TextEditingController _chatController = TextEditingController();
  final SemanticRouterService _semanticRouterService = SemanticRouterService();
  final PipelineExecutor _pipelineExecutor = PipelineExecutor();

  Timer? _actionTimer;
  bool _isActionPending = false;
  int _countdownSeconds = 0;
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();

  Future<void> _loadSuggestions() async {
    if (_isLoadingSuggestions) return;
    _isLoadingSuggestions = true;
    if (mounted) setState(() {});

    final suggestions = await _suggestionsService.generateSuggestions(
      widget.detectedTags,
    );

    if (mounted) {
      setState(() {
        if (widget.dismissedSuggestions != null) {
          _currentSuggestions = suggestions
              .where((s) => !widget.dismissedSuggestions!.contains(s))
              .toList();
        } else {
          _currentSuggestions = suggestions;
        }
        _isLoadingSuggestions = false;
      });
    }
  }

  @override
  void didUpdateWidget(EditorBottomBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.detectedTags != oldWidget.detectedTags ||
        widget.dismissedSuggestions != oldWidget.dismissedSuggestions) {
      _loadSuggestions();
    }
    if (oldWidget.selectedTool != widget.selectedTool) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateHighlight());
    }
    if (_currentSuggestions.isEmpty && widget.selectedTool == EditorTool.chat) {
      _loadSuggestions();
    }
  }

  @override
  void initState() {
    super.initState();
    _keys = List.generate(widget.tools.length, (_) => GlobalKey());
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateHighlight());
    _loadSuggestions();
    _chatController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _chatController.dispose();
    _actionTimer?.cancel();
    _semanticRouterService.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  int _getHoverIndex(double dragX) {
    final stackBox = _stackKey.currentContext!.findRenderObject() as RenderBox;

    for (int i = 0; i < _keys.length; i++) {
      final ctx = _keys[i].currentContext;
      if (ctx == null) continue;

      final box = ctx.findRenderObject() as RenderBox;
      final pos = box.localToGlobal(Offset.zero, ancestor: stackBox);

      double left = pos.dx;
      double right = pos.dx + box.size.width;

      if (dragX + (_width / 2) >= left && dragX + (_width / 2) <= right) {
        return i;
      }
    }

    return -1;
  }

  int _getNearestButtonIndex(double dragX) {
    final stackBox = _stackKey.currentContext!.findRenderObject() as RenderBox;

    double minDistance = double.infinity;
    int bestIndex = 0;

    for (int i = 0; i < _keys.length; i++) {
      final ctx = _keys[i].currentContext;
      if (ctx == null) continue;

      final box = ctx.findRenderObject() as RenderBox;
      final pos = box.localToGlobal(Offset.zero, ancestor: stackBox);

      double center = pos.dx + (box.size.width / 2);

      double distance = (center - dragX - (_width / 2)).abs();

      if (distance < minDistance) {
        minDistance = distance;
        bestIndex = i;
      }
    }

    return bestIndex;
  }

  void _updateHighlight() {
    if (widget.selectedTool == null) return;

    final index = widget.tools.indexOf(widget.selectedTool!);
    if (index == -1) return;

    final key = _keys[index];
    final ctx = key.currentContext;
    if (ctx == null) return;

    final box = ctx.findRenderObject() as RenderBox;

    final stackBox = _stackKey.currentContext!.findRenderObject() as RenderBox;

    final pos = box.localToGlobal(
      Offset.zero + const Offset(14, 0),
      ancestor: stackBox,
    );

    setState(() {
      _isMoving = true;
      _x = pos.dx - 18;
      _width = box.size.width + 8;
    });

    Future.delayed(const Duration(milliseconds: 260), () {
      if (!mounted) return;
      setState(() {
        _isMoving = false;
      });
    });
  }

  void _select(int index) {
    widget.toolCallbacks[widget.tools[index]]?.call();
    HapticFeedback.lightImpact();
  }

  Widget _buildChatInterface() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0, left: 20, right: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_messages.isNotEmpty)
            Container(
              height: 200,
              margin: const EdgeInsets.only(bottom: 12),
              child: ShaderMask(
                shaderCallback: (Rect bounds) {
                  return LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black,
                      Colors.black,
                    ],
                    stops: const [0.0, 0.1, 0.4, 1.0],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.dstIn,
                child: ListView.separated(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.only(top: 20, bottom: 8),
                  itemCount: _messages.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final message = _messages[_messages.length - 1 - index];
                    return Align(
                      alignment: message.isUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: LiquidGlassLayer(
                        settings: const LiquidGlassSettings(
                          thickness: 20,
                          blur: 15,
                          glassColor: LiquidGlassTheme.glassDark,
                        ),
                        child: LiquidGlass(
                          shape: LiquidRoundedSuperellipse(borderRadius: 20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.7,
                            ),
                            decoration: BoxDecoration(
                              color: message.isUser
                                  ? Colors.black.withValues(alpha: 0.5)
                                  : Colors.black.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(20),
                                topRight: const Radius.circular(20),
                                bottomLeft: message.isUser
                                    ? const Radius.circular(20)
                                    : const Radius.circular(4),
                                bottomRight: message.isUser
                                    ? const Radius.circular(4)
                                    : const Radius.circular(20),
                              ),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              message.text,
                              style: GoogleFonts.roboto(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          if (_isLoadingSuggestions)
            SizedBox(
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                itemCount: 3,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  return LiquidGlassLayer(
                    settings: const LiquidGlassSettings(
                      thickness: 20,
                      blur: 10,
                      glassColor: LiquidGlassTheme.glassDark,
                    ),
                    child: LiquidGlass(
                      shape: LiquidRoundedSuperellipse(borderRadius: 16),
                      child: Container(
                        width: 120, // Fixed width for skeleton
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                            width: 0.5,
                          ),
                        ),
                        child: Center(
                          child: Container(
                            height: 10,
                            width: 80,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            )
          else if (_currentSuggestions.isNotEmpty)
            SizedBox(
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                itemCount: _currentSuggestions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () {
                      _chatController.text = _currentSuggestions[index];
                    },
                    child: LiquidGlassLayer(
                      settings: const LiquidGlassSettings(
                        thickness: 20,
                        blur: 10,
                        glassColor: LiquidGlassTheme.glassDark,
                      ),
                      child: LiquidGlass(
                        shape: LiquidRoundedSuperellipse(borderRadius: 16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            _currentSuggestions[index],
                            style: GoogleFonts.roboto(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              LiquidGlassLayer(
                settings: const LiquidGlassSettings(
                  thickness: 25,
                  blur: 20,
                  glassColor: LiquidGlassTheme.glassDark,
                  lightIntensity: 0.15,
                  saturation: 1,
                ),
                child: LiquidGlass(
                  shape: LiquidRoundedSuperellipse(borderRadius: 50),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(
                        color: Colors.grey.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      CupertinoIcons.mic,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: LiquidGlassLayer(
                  settings: const LiquidGlassSettings(
                    thickness: 25,
                    blur: 20,
                    glassColor: LiquidGlassTheme.glassDark,
                    lightIntensity: 0.15,
                    saturation: 1,
                  ),
                  child: LiquidGlass(
                    shape: LiquidRoundedSuperellipse(borderRadius: 50),
                    child: Container(
                      height: 52,
                      padding: const EdgeInsets.only(left: 20, right: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(
                          color: Colors.grey.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.centerLeft,
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _chatController,
                              style: GoogleFonts.roboto(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                              decoration: InputDecoration(
                                hintText: "Type Prompt",
                                hintStyle: GoogleFonts.roboto(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  fontSize: 16,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          if (true)
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: GestureDetector(
                                onTap: () {
                                  if (_isActionPending) return;
                                  HapticFeedback.mediumImpact();
                                  _handleChatSubmit();
                                },
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: LiquidGlassTheme.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.2,
                                      ),
                                      width: 1.0,
                                    ),
                                  ),
                                  child: const Icon(
                                    CupertinoIcons.arrow_up,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleChatSubmit() async {
    final prompt = _chatController.text.trim();
    if (prompt.isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: prompt, isUser: true));
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    _chatController.clear();
    FocusScope.of(context).unfocus();
    // Show analyzing state
    widget.notificationService.show(
      'Analyzing prompt...',
      type: NotificationType.info,
      child: const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      ),
      duration: Duration.zero, // Keep until replaced
    );

    try {
      final command = await _semanticRouterService.generateCommand(prompt);
      final actionStr = command['action'] as String?;
      final rawOutput = command['raw_output'] as String? ?? 'No output';
      final error = command['error'] as String?;

      if (error != null) {
        debugPrint(error);
      }
      
      // setState(() {
      //   _messages.add(ChatMessage(text: message, isUser: false));
      // });
      
      debugPrint('DEBUG: Action determined: $actionStr');
      debugPrint('DEBUG: Raw output: $rawOutput');

      await Future.delayed(const Duration(seconds: 2));

      EditorAction action;
      if (actionStr == 'relight') {
        action = EditorAction.relight;
      } else if (actionStr == 'reframe') {
        action = EditorAction.reframe;
      } else {
        action = EditorAction.diffusion;
      }

      if (action == EditorAction.diffusion) {
        if (mounted) {
          widget.notificationService.show(
            'Sending to Diffusion Model...',
            type: NotificationType.info,
          );
          // setState(() {
          //   _messages.add(ChatMessage(
          //     text: "Sending to Diffusion Model...",
          //     isUser: false,
          //   ));
          // });
        }
        return;
      }

      if (!mounted) return;

      setState(() {
        _isActionPending = true;
        _countdownSeconds = 3;
      });

      final actionName = action == EditorAction.relight ? 'Relight' : 'Reframe';

      widget.notificationService.show(
        'Starting $actionName in $_countdownSeconds...',
        type: NotificationType.info,
        child: TextButton(
          onPressed: () {
            _actionTimer?.cancel();
            widget.notificationService.dismiss();
            setState(() => _isActionPending = false);
          },
          child: const Text('CANCEL', style: TextStyle(color: Colors.amber)),
        ),
        duration: const Duration(seconds: 4),
      );

      // setState(() {
      //   _messages.add(ChatMessage(
      //     text: "Starting $actionName in $_countdownSeconds seconds...",
      //     isUser: false,
      //   ));
      // });

      _actionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _countdownSeconds--;
        });

        if (_countdownSeconds <= 0) {
          timer.cancel();
          setState(() => _isActionPending = false);

          if (action == EditorAction.relight) {
            widget.toolCallbacks[EditorTool.relight]?.call();
            Future.delayed(const Duration(milliseconds: 500), () {
              if (widget.relightController != null) {
                _pipelineExecutor.execute(command, widget.relightController!);
              }
            });
          } else if (action == EditorAction.reframe) {
            widget.toolCallbacks[EditorTool.reframe]?.call();
          }
        }
      });
    } catch (e) {
      debugPrint('Error routing prompt: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error analyzing prompt: $e')),
        );
        // setState(() {
        //   _messages.add(ChatMessage(
        //     text: "Error: $e",
        //     isUser: false,
        //   ));
        // });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(LiquidGlassTheme.spacingXSmall),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.selectedTool == EditorTool.chat) _buildChatInterface(),

            Center(
              child: LiquidGlassLayer(
                settings: const LiquidGlassSettings(
                  thickness: 25,
                  blur: 20,
                  glassColor: LiquidGlassTheme.glassDark,
                  lightIntensity: 0.15,
                  saturation: 1,
                ),
                child: Stack(
                  key: _stackKey,
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 0,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(
                          color: Colors.grey.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          widget.tools.length,
                          (index) => _ToolButton(
                            key: _keys[index],
                            iconPath: widget.tools[index].iconPath,
                            label: widget.tools[index].label,
                            isSelected:
                                widget.selectedTool == widget.tools[index],
                            onTap: () => _select(index),
                          ),
                        ),
                      ),
                    ),

                    if (widget.selectedTool != null)
                      AnimatedPositioned(
                        duration: _isDragging
                            ? Duration.zero
                            : const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        left: _isDragging ? _dragX : _x,
                        top: _isMoving ? 0 : 8,
                        height: _isMoving ? 72 : 58,
                        width: _width,
                        child: GestureDetector(
                          onHorizontalDragStart: (_) {
                            setState(() {
                              _isDragging = true;
                              _dragX = _x;
                            });
                          },
                          onHorizontalDragUpdate: (details) {
                            setState(() {
                              _dragX +=
                                  details.delta.dx *
                                  (1 / (1 + (_dragX - _x).abs() / 1000));
                            });

                            int hoverIndex = _getHoverIndex(_dragX);

                            if (hoverIndex != -1 &&
                                hoverIndex != _lastHoverIndex) {
                              _lastHoverIndex = hoverIndex;
                              HapticFeedback.selectionClick();
                            }
                          },

                          onHorizontalDragEnd: (_) {
                            _isDragging = false;
                            int nearestIndex = _getNearestButtonIndex(_dragX);
                            setState(() {
                              _lastHoverIndex = -1;
                            });
                            _select(nearestIndex);
                          },

                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                            child: LiquidStretch(
                              stretch: _isMoving ? 3.0 : 1.2,
                              child: LiquidGlass(
                                shape: LiquidRoundedSuperellipse(
                                  borderRadius: 50,
                                ),
                                child: GlassGlow(
                                  glowRadius: _isMoving ? 2 : 1.4,
                                  glowColor: Colors.white.withValues(
                                    alpha: 0.12,
                                  ),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.08,
                                      ),
                                      borderRadius: BorderRadius.circular(50),
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.15,
                                        ),
                                        width: 0.4,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final String iconPath;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToolButton({
    super.key,
    required this.iconPath,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String displayIconPath = isSelected
        ? iconPath.replaceAll('.svg', '_selected.svg')
        : iconPath;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22.5, vertical: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              displayIconPath,
              width: 26,
              height: 26,
              colorFilter: ColorFilter.mode(
                isSelected
                    ? LiquidGlassTheme.bottomBarPrimaryColor
                    : Colors.white,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.roboto(
                color: isSelected
                    ? LiquidGlassTheme.bottomBarPrimaryColor
                    : Colors.white,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
