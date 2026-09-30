import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../models/task_model.dart';

/// 3D Parallax & Micro-Interactive Task Card
///
/// Features:
/// - 4x4 Perspective Transform (`Matrix4.identity()..setEntry(3, 2, 0.001)`)
/// - Dynamic 3D tilt tracking finger touch and drag positions
/// - Interactive specular sheen highlight following tilt
/// - Swipe Right to Complete with animated emerald gradient fill & celebratory confetti burst
/// - Swipe Left to Reschedule with animated indigo gradient fill
/// - Haptic feedback ticks during dragging and on threshold crossing
/// - Smooth spring physics on release
class TaskCard3D extends StatefulWidget {
  final Task task;
  final Color primary;
  final bool isDark;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<bool>? onToggleComplete;
  final VoidCallback? onComplete;
  final VoidCallback? onReschedule;
  final VoidCallback? onDelete;
  final bool enableTilt;
  final bool enableSwipe;

  const TaskCard3D({
    super.key,
    required this.task,
    required this.primary,
    required this.isDark,
    this.isSelected = false,
    this.isSelectionMode = false,
    this.onTap,
    this.onLongPress,
    this.onToggleComplete,
    this.onComplete,
    this.onReschedule,
    this.onDelete,
    this.enableTilt = true,
    this.enableSwipe = true,
  });

  @override
  State<TaskCard3D> createState() => _TaskCard3DState();
}

class _TaskCard3DState extends State<TaskCard3D>
    with TickerProviderStateMixin {
  // ─── 3D Tilt State ───
  double _tiltX = 0.0;
  double _tiltY = 0.0;
  double _normX = 0.0; // -1.0 to 1.0 (for specular sheen)
  double _normY = 0.0;
  bool _isPressed = false;
  late final AnimationController _tiltController;
  Animation<double>? _tiltAnimX;
  Animation<double>? _tiltAnimY;

  // ─── Horizontal Drag & Swipe State ───
  double _dragOffset = 0.0;
  bool _isDragging = false;
  bool _thresholdReached = false;
  int _lastHapticStep = 0;
  static const double _swipeThreshold = 88.0;

  late final AnimationController _springController;
  Animation<double>? _springAnimation;

  // ─── Celebratory Particles ───
  late final AnimationController _confettiAnimController;
  final List<_ConfettiParticle> _particles = [];
  final math.Random _random = math.Random();

  @override
  void initState() {
    super.initState();

    // Tilt reset controller
    _tiltController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..addListener(() {
        if (_tiltAnimX != null && _tiltAnimY != null) {
          setState(() {
            _tiltX = _tiltAnimX!.value;
            _tiltY = _tiltAnimY!.value;
            _normX = (_tiltY / 0.10).clamp(-1.0, 1.0);
            _normY = (-_tiltX / 0.08).clamp(-1.0, 1.0);
          });
        }
      });

    // Spring physics controller for horizontal gestures
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..addListener(() {
        if (_springAnimation != null) {
          setState(() {
            _dragOffset = _springAnimation!.value;
          });
        }
      });

    // Celebratory confetti particles controller
    _confettiAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..addListener(() {
        final progress = _confettiAnimController.value;
        for (final p in _particles) {
          p.update(progress);
        }
        setState(() {});
      });
  }

  @override
  void dispose() {
    _tiltController.dispose();
    _springController.dispose();
    _confettiAnimController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // 3D Parallax Tilt Logic
  // ─────────────────────────────────────────────
  void _updateTilt(Offset localPosition, Size size) {
    if (!widget.enableTilt || widget.isSelectionMode) return;
    final w = size.width > 0 ? size.width : 340.0;
    final h = size.height > 0 ? size.height : 80.0;

    final nx = ((localPosition.dx / w) - 0.5) * 2.0; // -1.0 to 1.0
    final ny = ((localPosition.dy / h) - 0.5) * 2.0;

    setState(() {
      _normX = nx.clamp(-1.0, 1.0);
      _normY = ny.clamp(-1.0, 1.0);
      // Subtle tilt: max ~5.5 deg on Y, ~4.5 deg on X
      _tiltY = (_normX * 0.09).clamp(-0.12, 0.12);
      _tiltX = (-_normY * 0.07).clamp(-0.10, 0.10);
    });
  }

  void _resetTiltWithSpring() {
    if (!widget.enableTilt) return;
    _tiltAnimX = Tween<double>(begin: _tiltX, end: 0.0).animate(
      CurvedAnimation(parent: _tiltController, curve: Curves.easeOutCubic),
    );
    _tiltAnimY = Tween<double>(begin: _tiltY, end: 0.0).animate(
      CurvedAnimation(parent: _tiltController, curve: Curves.easeOutCubic),
    );
    _tiltController.forward(from: 0.0);
  }

  // ─────────────────────────────────────────────
  // Horizontal Swipe & Spring Physics
  // ─────────────────────────────────────────────
  void _handleHorizontalDragStart(DragStartDetails details) {
    if (!widget.enableSwipe || widget.isSelectionMode) return;
    _springController.stop();
    _isDragging = true;
    _thresholdReached = false;
    _lastHapticStep = 0;
    HapticFeedback.selectionClick();
  }

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    if (!widget.enableSwipe || widget.isSelectionMode) return;

    final delta = details.primaryDelta ?? 0.0;
    // Add slight elastic resistance when dragged past 140px
    double newOffset = _dragOffset + delta;
    if (newOffset.abs() > 140) {
      final excess = newOffset.abs() - 140;
      final sign = newOffset.isNegative ? -1.0 : 1.0;
      newOffset = sign * (140 + excess * 0.45);
    }

    // Haptic feedback ticks during drag reordering / movement
    final int step = (newOffset / 30.0).floor();
    if (step != _lastHapticStep) {
      HapticFeedback.selectionClick();
      _lastHapticStep = step;
    }

    // Threshold haptic tick
    final bool reached = newOffset.abs() >= _swipeThreshold;
    if (reached && !_thresholdReached) {
      HapticFeedback.mediumImpact();
      _thresholdReached = true;
    } else if (!reached && _thresholdReached) {
      _thresholdReached = false;
    }

    setState(() {
      _dragOffset = newOffset;
    });
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    if (!widget.enableSwipe || widget.isSelectionMode) return;
    _isDragging = false;

    if (_dragOffset >= _swipeThreshold) {
      // 🚀 Swipe Right: Complete!
      _triggerCelebrationAndComplete();
    } else if (_dragOffset <= -_swipeThreshold) {
      // 📅 Swipe Left: Reschedule!
      _triggerReschedule();
    } else {
      // Release below threshold: smooth spring snap back
      _snapBackWithSpring();
    }
  }

  void _handleHorizontalDragCancel() {
    _isDragging = false;
    _snapBackWithSpring();
  }

  void _snapBackWithSpring({VoidCallback? onComplete}) {
    _springAnimation = Tween<double>(begin: _dragOffset, end: 0.0).animate(
      CurvedAnimation(
        parent: _springController,
        // Fluid spring physics curve
        curve: const SpringCurve(damping: 18.0, stiffness: 180.0),
      ),
    );
    _springController.forward(from: 0.0).then((_) {
      onComplete?.call();
    });
  }

  // ─────────────────────────────────────────────
  // Celebration Confetti & Complete Trigger
  // ─────────────────────────────────────────────
  void _triggerCelebrationAndComplete() {
    HapticFeedback.heavyImpact();
    _spawnParticles();
    _confettiAnimController.forward(from: 0.0);

    // Call external completion handler
    widget.onComplete?.call();

    // Spring card back smoothly after celebratory burst
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) {
        _snapBackWithSpring();
      }
    });
  }

  void _triggerReschedule() {
    HapticFeedback.mediumImpact();
    _snapBackWithSpring(onComplete: () {
      widget.onReschedule?.call();
    });
  }

  void _spawnParticles() {
    _particles.clear();
    const colors = [
      Color(0xFF10B981), // Emerald
      Color(0xFF34D399), // Mint
      Color(0xFFFBBF24), // Amber Gold
      Color(0xFF38BDF8), // Sky Blue
      Color(0xFFA855F7), // Purple
      Color(0xFFFB7185), // Rose
    ];

    // Spawn 36 celebratory micro-particles
    for (int i = 0; i < 36; i++) {
      final angle = _random.nextDouble() * 2 * math.pi;
      final speed = 120.0 + _random.nextDouble() * 280.0;
      final size = 4.0 + _random.nextDouble() * 5.0;
      final color = colors[_random.nextInt(colors.length)];
      final isCircle = _random.nextBool();

      _particles.add(
        _ConfettiParticle(
          origin: const Offset(40, 36),
          velocity: Offset(math.cos(angle) * speed, math.sin(angle) * speed),
          size: size,
          color: color,
          rotationSpeed: (_random.nextDouble() - 0.5) * 12.0,
          isCircle: isCircle,
        ),
      );
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'High':
        return const Color(0xFFEF4444);
      case 'Low':
        return const Color(0xFF3B82F6);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final primary = widget.primary;
    final isDark = widget.isDark;
    final isSelected = widget.isSelected;
    final isOverdue = task.dueDate != null &&
        !task.isCompleted &&
        task.dueDate!.isBefore(DateTime.now());

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardSize = Size(
          constraints.maxWidth,
          constraints.maxHeight > 0 && constraints.maxHeight != double.infinity
              ? constraints.maxHeight
              : 80.0,
        );

        // ─── 4x4 Matrix with 3D Perspective ───
        // Matrix entry (3, 2, 0.001) provides realistic camera focal depth
        final Matrix4 transform3D = Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..setTranslationRaw(_dragOffset, 0.0, 0.0)
          ..rotateX(_tiltX)
          ..rotateY(_tiltY + (_dragOffset / 380.0).clamp(-0.25, 0.25))
          ..rotateZ((-_dragOffset / 850.0).clamp(-0.05, 0.05));

        return Padding(
          padding: EdgeInsets.symmetric(
            vertical: task.isCompleted ? 2.5 : 4.0,
            horizontal: 2.0,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ─── 1. Background Swipe Actions (Green & Indigo Gradients) ───
              Positioned.fill(
                child: _buildSwipeActionBackground(),
              ),

              // ─── 2. Interactive 3D Card ───
              Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (event) {
                  _tiltController.stop();
                  _isPressed = true;
                  _updateTilt(event.localPosition, cardSize);
                },
                onPointerMove: (event) {
                  _updateTilt(event.localPosition, cardSize);
                },
                onPointerUp: (event) {
                  _isPressed = false;
                  _resetTiltWithSpring();
                },
                onPointerCancel: (event) {
                  _isPressed = false;
                  _resetTiltWithSpring();
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragStart: _handleHorizontalDragStart,
                  onHorizontalDragUpdate: _handleHorizontalDragUpdate,
                  onHorizontalDragEnd: _handleHorizontalDragEnd,
                  onHorizontalDragCancel: _handleHorizontalDragCancel,
                  onTap: widget.onTap,
                  onLongPress: widget.onLongPress,
                  child: Transform(
                    transform: transform3D,
                    alignment: Alignment.center,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: task.isCompleted ? 0.58 : 1.0,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: (_isPressed || _isDragging)
                                  ? primary.withValues(alpha: isDark ? 0.28 : 0.18)
                                  : Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                              blurRadius: (_isPressed || _isDragging) ? 18 : 8,
                              offset: Offset(
                                _tiltY * 18,
                                (_isPressed || _isDragging) ? 8 : 3,
                              ),
                              spreadRadius: (_isPressed || _isDragging) ? 1 : 0,
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          clipBehavior: Clip.antiAlias,
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDark
                                      ? primary.withValues(alpha: 0.22)
                                      : primary.withValues(alpha: 0.10))
                                  : (isDark
                                      ? const Color(0xFF1E222A)
                                      : Colors.white),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? primary.withValues(alpha: 0.6)
                                    : (isDark
                                        ? Colors.white.withValues(alpha: 0.08)
                                        : Colors.grey.withValues(alpha: 0.18)),
                                width: isSelected ? 1.8 : 1.0,
                              ),
                            ),
                            child: Stack(
                              children: [
                                // Priority accent stripe
                                Positioned(
                                  left: 0,
                                  top: 0,
                                  bottom: 0,
                                  width: 4.5,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: _getPriorityColor(task.priority),
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(16),
                                        bottomLeft: Radius.circular(16),
                                      ),
                                    ),
                                  ),
                                ),

                                // Specular 3D sheen light reflection
                                if (widget.enableTilt && !_isDragging)
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          gradient: RadialGradient(
                                            center: Alignment(
                                              _normX * 0.9,
                                              _normY * 0.9,
                                            ),
                                            radius: 1.1,
                                            colors: [
                                              Colors.white.withValues(
                                                alpha: isDark ? 0.09 : 0.16,
                                              ),
                                              Colors.white.withValues(
                                                alpha: 0.0,
                                              ),
                                            ],
                                            stops: const [0.0, 0.7],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                // Card Content
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    14,
                                    11,
                                    14,
                                    11,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      // Checkbox / Select icon
                                      _buildLeadingAction(primary),

                                      const SizedBox(width: 12),

                                      // Task details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // Title & Recurrence badge
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    task.title,
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      decoration:
                                                          task.isCompleted
                                                              ? TextDecoration
                                                                  .lineThrough
                                                              : null,
                                                      color: task.isCompleted
                                                          ? (isDark
                                                              ? Colors.white38
                                                              : Colors.black38)
                                                          : (isDark
                                                              ? Colors.white
                                                              : Colors.black87),
                                                    ),
                                                  ),
                                                ),
                                                if (task.recurrenceRule !=
                                                        null &&
                                                    task.recurrenceRule!
                                                        .isNotEmpty)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                      left: 6,
                                                    ),
                                                    child: Icon(
                                                      Icons.repeat_rounded,
                                                      size: 15,
                                                      color: primary.withValues(
                                                        alpha: 0.8,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),

                                            const SizedBox(height: 4),

                                            // Subtitle: Due Date, Category, Description
                                            _buildMetadataRow(
                                              isDark,
                                              isOverdue,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
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

              // ─── 3. Celebratory Particle Overlay ───
              if (_particles.isNotEmpty)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _ConfettiParticlePainter(
                        particles: _particles,
                        opacity:
                            (1.0 - _confettiAnimController.value).clamp(0.0, 1.0),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────
  // Background Swipe Fill Widget
  // ─────────────────────────────────────────────
  Widget _buildSwipeActionBackground() {
    if (_dragOffset.abs() < 1.0) {
      return const SizedBox.shrink();
    }

    final isSwipeRight = _dragOffset > 0;
    final progress = (_dragOffset.abs() / _swipeThreshold).clamp(0.0, 1.4);

    if (isSwipeRight) {
      // 🌿 Complete: Rich Emerald Gradient
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF047857), // Emerald 700
              Color(0xFF059669), // Emerald 600
              Color(0xFF10B981), // Emerald 500
              Color(0xFF34D399), // Emerald 400
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.scale(
              scale: (0.7 + progress * 0.45).clamp(0.7, 1.25),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Opacity(
              opacity: (progress * 1.2).clamp(0.0, 1.0),
              child: const Text(
                'Complete',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // 📅 Reschedule: Vibrant Indigo / Violet Gradient
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF8B5CF6), // Violet 500
              Color(0xFF6366F1), // Indigo 500
              Color(0xFF4F46E5), // Indigo 600
              Color(0xFF4338CA), // Indigo 700
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Opacity(
              opacity: (progress * 1.2).clamp(0.0, 1.0),
              child: const Text(
                'Reschedule',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Transform.scale(
              scale: (0.7 + progress * 0.45).clamp(0.7, 1.25),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.edit_calendar_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  // ─────────────────────────────────────────────
  // Leading Checkbox / Selection Toggle
  // ─────────────────────────────────────────────
  Widget _buildLeadingAction(Color primary) {
    if (widget.isSelectionMode) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: widget.isSelected ? primary : Colors.transparent,
          border: Border.all(
            color: widget.isSelected ? primary : Colors.grey.shade400,
            width: 1.8,
          ),
        ),
        child: widget.isSelected
            ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
            : null,
      );
    }

    final isCompleted = widget.task.isCompleted;
    return GestureDetector(
      key: const ValueKey('task_card_checkbox'),
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        if (!isCompleted) {
          _triggerCelebrationAndComplete();
        } else {
          widget.onToggleComplete?.call(false);
        }
      },
      child: AnimatedScale(
        scale: isCompleted ? 1.08 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            color: isCompleted ? primary : Colors.transparent,
            border: Border.all(
              color: isCompleted ? primary : Colors.grey.shade400,
              width: 1.8,
            ),
          ),
          child: isCompleted
              ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
              : null,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Subtitle / Metadata Row
  // ─────────────────────────────────────────────
  Widget _buildMetadataRow(bool isDark, bool isOverdue) {
    final date = widget.task.dueDate;
    final description = widget.task.description;
    final category = widget.task.category;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (date != null) ...[
              Icon(
                Icons.access_time_rounded,
                size: 12,
                color: isOverdue
                    ? const Color(0xFFEF4444)
                    : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
              ),
              const SizedBox(width: 4),
              Text(
                DateFormat('dd MMM · hh:mm a').format(date),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal,
                  color: isOverdue
                      ? const Color(0xFFEF4444)
                      : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (category != null && category.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 1.5,
                ),
                decoration: BoxDecoration(
                  color: widget.primary.withValues(alpha: isDark ? 0.16 : 0.08),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  category,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: widget.primary,
                  ),
                ),
              ),
          ],
        ),
        if (description != null && description.trim().isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            description.trim(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
            ),
          ),
        ],
        if (widget.task.subtasks != null && widget.task.subtasks!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.checklist_rounded,
                size: 11,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              const SizedBox(width: 3),
              Text(
                '${widget.task.subtasks!.where((s) => s.isCompleted).length}/${widget.task.subtasks!.length} subtasks',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
        if (widget.task.tags.isNotEmpty) ...[
          const SizedBox(height: 3),
          Wrap(
            spacing: 4,
            runSpacing: 2,
            children: widget.task.tags.map((tag) => Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 1,
              ),
              decoration: BoxDecoration(
                color: widget.primary.withValues(alpha: isDark ? 0.16 : 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '#$tag',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: widget.primary,
                ),
              ),
            )).toList(),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Spring Curve for Fluid Physics Simulation
// ─────────────────────────────────────────────────────────────────────────────
class SpringCurve extends Curve {
  final double damping;
  final double stiffness;

  const SpringCurve({this.damping = 20.0, this.stiffness = 200.0});

  @override
  double transformInternal(double t) {
    // Underdamped harmonic oscillator normalized for [0, 1]
    final double omega = math.sqrt(stiffness);
    final double zeta = damping / (2 * omega);
    final double omegaD = omega * math.sqrt(math.max(0.001, 1 - zeta * zeta));
    return 1 -
        math.exp(-zeta * omega * t) *
            (math.cos(omegaD * t) + (zeta / math.max(0.001, math.sqrt(1 - zeta * zeta))) * math.sin(omegaD * t));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Celebratory Micro-Particles Model & Painter
// ─────────────────────────────────────────────────────────────────────────────
class _ConfettiParticle {
  final Offset origin;
  final Offset velocity;
  final double size;
  final Color color;
  final double rotationSpeed;
  final bool isCircle;

  Offset position = Offset.zero;
  double rotation = 0.0;

  _ConfettiParticle({
    required this.origin,
    required this.velocity,
    required this.size,
    required this.color,
    required this.rotationSpeed,
    required this.isCircle,
  }) {
    position = origin;
  }

  void update(double progress) {
    // Physics: velocity with damping + gravity
    const double gravity = 480.0;
    final double t = progress;
    position = Offset(
      origin.dx + velocity.dx * t * 0.7,
      origin.dy + velocity.dy * t * 0.7 + 0.5 * gravity * t * t,
    );
    rotation = rotationSpeed * t * 2 * math.pi;
  }
}

class _ConfettiParticlePainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double opacity;

  _ConfettiParticlePainter({
    required this.particles,
    required this.opacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0.0) return;

    for (final p in particles) {
      final paint = Paint()
        ..color = p.color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(p.position.dx, p.position.dy);
      canvas.rotate(p.rotation);

      if (p.isCircle) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size * 1.4,
            height: p.size * 0.7,
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiParticlePainter oldDelegate) => true;
}
