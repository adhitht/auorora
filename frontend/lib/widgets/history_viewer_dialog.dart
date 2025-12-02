import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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
      begin: const Offset(0.0, -1.0),
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
            alignment: Alignment.topCenter,
            child: GestureDetector(
              onTap: () {}, // Prevent closing when tapping inside
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: double.infinity,
                  height: 340, // Fixed height for the dropdown
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 20,
                        offset: const Offset(0, 5),
                      ),
                    ],
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(24),
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                          child: Row(
                            children: [
                              const Text(
                                'History',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: _close,
                                icon: const Icon(
                                  CupertinoIcons.chevron_up,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // History List
                        Expanded(
                          child: history.isEmpty
                              ? Center(
                                  child: Text(
                                    'No edits yet',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.5,
                                      ),
                                      fontSize: 14,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
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
                        const SizedBox(height: 20),
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
        width: 140, // Fixed width for horizontal scrolling
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCurrent
                ? Colors.white
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
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

              // Gradient Overlay
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 80,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                ),
              ),

              // Text Content
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.type.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatTime(entry.timestamp),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              
              // Current Indicator (optional, maybe just border is enough)
              if (isCurrent)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
