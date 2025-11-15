import 'package:flutter/material.dart';
import '../models/edit_history.dart';
import '../services/edit_history_manager.dart';
import '../theme/liquid_glass_theme.dart';

class HistoryViewerDialog extends StatefulWidget {
  final EditHistoryManager historyManager;
  final Function(int index)? onJumpTo;

  const HistoryViewerDialog({
    super.key,
    required this.historyManager,
    this.onJumpTo,
  });

  @override
  State<HistoryViewerDialog> createState() => _HistoryViewerDialogState();
}

class _HistoryViewerDialogState extends State<HistoryViewerDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();

    widget.historyManager.addListener(_onHistoryChanged);
  }

  @override
  void dispose() {
    widget.historyManager.removeListener(_onHistoryChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onHistoryChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _close() {
    _controller.reverse().then((_) {
      if (mounted) {
        Navigator.pop(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final history = widget.historyManager.allHistory;
    final currentIndex = widget.historyManager.currentPosition;

    return GestureDetector(
      onTap: _close,
      child: Container(
        color: Colors.black.withValues(alpha: 0.5),
        child: SlideTransition(
          position: _slideAnimation,
          child: Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () {}, // Prevent closing when tapping inside
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 200,
                  height: MediaQuery.of(context).size.height,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.95),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 20,
                        offset: const Offset(-5, 0),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Compact Header
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 16,
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.history,
                                color: LiquidGlassTheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${history.length} edits',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: _close,
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ),

                        Divider(
                          color: Colors.white.withValues(alpha: 0.1),
                          height: 1,
                          thickness: 1,
                        ),

                        // History List
                        Expanded(
                          child: history.isEmpty
                              ? Center(
                                  child: Text(
                                    'No edits',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.5,
                                      ),
                                      fontSize: 12,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  itemCount: history.length,
                                  itemBuilder: (context, index) {
                                    final entry = history[index];
                                    final isCurrent = index == currentIndex;
                                    final isPast = index <= currentIndex;

                                    return _HistoryEntryTile(
                                      entry: entry,
                                      index: index,
                                      isCurrent: isCurrent,
                                      isPast: isPast,
                                      onTap: widget.onJumpTo != null
                                          ? () {
                                              widget.onJumpTo!(index);
                                            }
                                          : null,
                                    );
                                  },
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
      ),
    );
  }
}

class _HistoryEntryTile extends StatelessWidget {
  final EditHistoryEntry entry;
  final int index;
  final bool isCurrent;
  final bool isPast;
  final VoidCallback? onTap;

  const _HistoryEntryTile({
    required this.entry,
    required this.index,
    required this.isCurrent,
    required this.isPast,
    this.onTap,
  });

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      final hour = time.hour > 12
          ? time.hour - 12
          : (time.hour == 0 ? 12 : time.hour);
      final amPm = time.hour >= 12 ? 'PM' : 'AM';
      return '${time.month}/${time.day} ${hour}:${time.minute.toString().padLeft(2, '0')} $amPm';
    }
  }

  IconData _getIconForType(EditType type) {
    switch (type) {
      case EditType.crop:
        return Icons.crop;
      case EditType.relight:
        return Icons.wb_sunny;
      case EditType.reframe:
        return Icons.aspect_ratio;
      case EditType.filter:
        return Icons.filter;
      case EditType.rotate:
        return Icons.rotate_right;
      case EditType.flip:
        return Icons.flip;
      case EditType.initial:
        return Icons.image;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isCurrent
                ? LiquidGlassTheme.primary
                : Colors.white.withValues(alpha: 0.1),
            width: isCurrent ? 2 : 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(
                  entry.imageFile,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.white.withValues(alpha: 0.1),
                      child: const Icon(
                        Icons.broken_image,
                        color: Colors.white38,
                        size: 24,
                      ),
                    );
                  },
                ),

                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.all(6),
                    child: Row(
                      children: [
                        Icon(
                          _getIconForType(entry.type),
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                entry.type.displayName,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: isCurrent
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                _formatTime(entry.timestamp),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 9,
                                ),
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
