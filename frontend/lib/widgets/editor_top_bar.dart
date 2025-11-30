import 'package:apex/theme/liquid_glass_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

class EditorTopBar extends StatefulWidget {
  final VoidCallback onBackTap;
  final VoidCallback onSaveTap;
  final VoidCallback? onShareTap;
  final bool isSaving;

  const EditorTopBar({
    super.key,
    required this.onBackTap,
    required this.onSaveTap,
    this.onShareTap,
    this.isSaving = false,
  });

  @override
  State<EditorTopBar> createState() => _EditorTopBarState();
}

class _EditorTopBarState extends State<EditorTopBar> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  void _showMenu() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideMenu() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Transparent dismiss layer
          Positioned.fill(
            child: GestureDetector(
              onTap: _hideMenu,
              behavior: HitTestBehavior.translucent,
              child: Container(color: Colors.transparent),
            ),
          ),
          // Menu
          Positioned(
            width: 200,
            child: CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: const Offset(-158, 50),
              child: _AnimatedMenu(
                onDownload: () {
                  _hideMenu();
                  widget.onSaveTap();
                },
                onShare: () {
                  _hideMenu();
                  widget.onShareTap?.call();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _GlassBtn(
              onTap: widget.onBackTap,
              child: const Icon(
                CupertinoIcons.back,
                size: 20,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            if (widget.isSaving)
              _GlassBtn(
                onTap: () {},
                child: const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              )
            else
              CompositedTransformTarget(
                link: _layerLink,
                child: _GlassBtn(
                  onTap: _showMenu,
                  child: const Icon(
                    CupertinoIcons.ellipsis,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedMenu extends StatefulWidget {
  final VoidCallback onDownload;
  final VoidCallback onShare;

  const _AnimatedMenu({
    required this.onDownload,
    required this.onShare,
  });

  @override
  State<_AnimatedMenu> createState() => _AnimatedMenuState();
}

class _AnimatedMenuState extends State<_AnimatedMenu>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _widthAnimation;
  late Animation<double> _heightAnimation;
  late Animation<double> _radiusAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    final curvedAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );

    _widthAnimation = Tween<double>(begin: 42.0, end: 200.0).animate(
      curvedAnimation,
    );

    _heightAnimation = Tween<double>(begin: 42.0, end: 110.0).animate(
      curvedAnimation,
    );

    _radiusAnimation = Tween<double>(begin: 21.0, end: 16.0).animate(
      curvedAnimation,
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Align(
          alignment: Alignment.topRight,
          child: SizedBox(
            width: _widthAnimation.value,
            height: _heightAnimation.value,
            child: Material(
              color: Colors.transparent,
              child: LiquidGlassLayer(
                settings: const LiquidGlassSettings(
                  thickness: 25,
                  blur: 40,
                  glassColor: LiquidGlassTheme.glassDark,
                  lightIntensity: 0.15,
                  saturation: 1,
                ),
                child: LiquidGlass(
                  shape: LiquidRoundedSuperellipse(
                    borderRadius: _radiusAnimation.value,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1E).withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(_radiusAnimation.value),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                        width: 0.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Opacity(
                      opacity: _opacityAnimation.value,
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _MenuItem(
                              icon: CupertinoIcons.arrow_down_to_line,
                              label: 'Download',
                              onTap: widget.onDownload,
                            ),
                            Divider(
                              height: 1,
                              thickness: 0.5,
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                            _MenuItem(
                              icon: CupertinoIcons.share,
                              label: 'Share',
                              onTap: widget.onShare,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassBtn extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _GlassBtn({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
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
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: Colors.grey.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                alignment: Alignment.center,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
