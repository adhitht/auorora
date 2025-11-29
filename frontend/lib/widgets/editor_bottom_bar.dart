import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import '../theme/liquid_glass_theme.dart';

enum EditorTool {
  crop(CupertinoIcons.crop, "Crop"),
  relight(CupertinoIcons.light_min, "Relight"),
  reframe(CupertinoIcons.perspective, "Reframe"),
  filters(CupertinoIcons.paintbrush, "Filters");

  final IconData icon;
  final String label;

  const EditorTool(this.icon, this.label);
}

class EditorBottomBar extends StatefulWidget {
  final Map<EditorTool, VoidCallback?> toolCallbacks;
  final List<EditorTool> tools;
  final EditorTool? selectedTool;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final VoidCallback? onHistory;
  final bool canUndo;
  final bool canRedo;

  const EditorBottomBar({
    super.key,
    required this.toolCallbacks,
    this.tools = EditorTool.values,
    this.selectedTool,
    this.onUndo,
    this.onRedo,
    this.onHistory,
    this.canUndo = false,
    this.canRedo = false,
  });

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

  @override
  void initState() {
    super.initState();
    _keys = List.generate(widget.tools.length, (_) => GlobalKey());
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateHighlight());
  }

  @override
  void didUpdateWidget(EditorBottomBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedTool != widget.selectedTool) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateHighlight());
    }
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(LiquidGlassTheme.spacingXSmall),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Undo/Redo/History Controls - Only visible when no tool is selected
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: widget.selectedTool == null ? 1.0 : 0.0,
              child: IgnorePointer(
                ignoring: widget.selectedTool != null,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
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
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
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
                          children: [
                            IconButton(
                              onPressed: widget.canUndo ? widget.onUndo : null,
                              icon: Icon(
                                CupertinoIcons.arrow_uturn_left,
                                size: 20,
                                color: widget.canUndo
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                            IconButton(
                              onPressed: widget.canRedo ? widget.onRedo : null,
                              icon: Icon(
                                CupertinoIcons.arrow_uturn_right,
                                size: 20,
                                color: widget.canRedo
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                            IconButton(
                              onPressed: widget.onHistory,
                              icon: const Icon(
                                CupertinoIcons.clock,
                                size: 20,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

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
                            icon: widget.tools[index].icon,
                            label: widget.tools[index].label,
                            isSelected: widget.selectedTool == widget.tools[index],
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

                            if (hoverIndex != -1 && hoverIndex != _lastHoverIndex) {
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
                                shape: LiquidRoundedSuperellipse(borderRadius: 50),
                                child: GlassGlow(
                                  glowRadius: _isMoving ? 2 : 1.4,
                                  glowColor: Colors.white.withValues(alpha: 0.12),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(50),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.15),
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
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ToolButton({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22.5, vertical: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 26,
              color: isSelected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.roboto(
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.6),
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

