import 'dart:async';
import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../services/task_action_service.dart';
import '../../tasks/models/task_model.dart';
import '../../tasks/ui/stats_screen.dart';
import '../../tasks/ui/widgets/habit_heatmap_widget.dart';
import '../services/ambient_audio_service.dart';
import '../services/focus_stats_service.dart';

/// Intervals for the Pomodoro state machine.
enum PomodoroMode {
  focus(
    label: 'Deep Focus',
    defaultSeconds: 25 * 60,
    color: Color(0xFF7C4DFF),
    icon: Icons.local_fire_department_rounded,
  ),
  shortBreak(
    label: 'Short Break',
    defaultSeconds: 5 * 60,
    color: Color(0xFF00BFA5),
    icon: Icons.coffee_rounded,
  ),
  longBreak(
    label: 'Long Break',
    defaultSeconds: 15 * 60,
    color: Color(0xFF29B6F6),
    icon: Icons.beach_access_rounded,
  );

  final String label;
  final int defaultSeconds;
  final Color color;
  final IconData icon;

  const PomodoroMode({
    required this.label,
    required this.defaultSeconds,
    required this.color,
    required this.icon,
  });
}

/// Pomodoro Deep Focus Screen featuring circular countdown, ambient audio loops,
/// ticking sound, task linking, and habit stats.
class PomodoroScreen extends StatefulWidget {
  final Task? initialTask;

  const PomodoroScreen({super.key, this.initialTask});

  @override
  State<PomodoroScreen> createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen>
    with TickerProviderStateMixin {
  final AmbientAudioService _audioService = AmbientAudioService();
  late final ConfettiController _confettiController;

  late PomodoroMode _currentMode;
  late int _totalDurationSeconds;
  late int _remainingSeconds;

  Timer? _timer;
  bool _isRunning = false;
  int _completedSessionsInRound = 0; // 0..4
  Task? _selectedTask;

  // Custom durations per mode
  int _customFocusMinutes = 25;
  int _customShortBreakMinutes = 5;
  final int _customLongBreakMinutes = 15;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _currentMode = PomodoroMode.focus;
    _totalDurationSeconds = _customFocusMinutes * 60;
    _remainingSeconds = _totalDurationSeconds;
    _selectedTask = widget.initialTask;

    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.98, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _audioService.init();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _confettiController.dispose();
    _audioService.stopAll();
    super.dispose();
  }

  void _startTimer() {
    if (_isRunning) return;

    setState(() {
      _isRunning = true;
    });

    _audioService.resumeAll();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _timer?.cancel();
        _onIntervalCompleted();
      }
    });
  }

  void _pauseTimer() {
    if (!_isRunning) return;

    _timer?.cancel();
    setState(() {
      _isRunning = false;
    });

    _audioService.pauseAll();
  }

  void _resetTimer() {
    _timer?.cancel();
    _audioService.pauseAll();
    setState(() {
      _isRunning = false;
      _remainingSeconds = _totalDurationSeconds;
    });
  }

  void _switchMode(PomodoroMode mode, {bool startImmediately = false}) {
    _timer?.cancel();
    _audioService.pauseAll();

    int duration;
    switch (mode) {
      case PomodoroMode.focus:
        duration = _customFocusMinutes * 60;
        break;
      case PomodoroMode.shortBreak:
        duration = _customShortBreakMinutes * 60;
        break;
      case PomodoroMode.longBreak:
        duration = _customLongBreakMinutes * 60;
        break;
    }

    setState(() {
      _currentMode = mode;
      _totalDurationSeconds = duration;
      _remainingSeconds = duration;
      _isRunning = false;
    });

    if (startImmediately) {
      _startTimer();
    }
  }

  Future<void> _onIntervalCompleted() async {
    _audioService.playCompletionChime();
    HapticFeedback.heavyImpact();

    if (_currentMode == PomodoroMode.focus) {
      final sessionMinutes = _totalDurationSeconds ~/ 60;
      await FocusStatsService.recordCompletedSession(minutes: sessionMinutes);
      _completedSessionsInRound++;
      _confettiController.play();

      if (!mounted) return;
      _showSessionCompletionDialog(sessionMinutes);
    } else {
      if (!mounted) return;
      _showBreakCompletionDialog();
    }
  }

  void _showSessionCompletionDialog(int minutes) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        final isLongBreakDue = _completedSessionsInRound >= 4;
        final nextMode = isLongBreakDue
            ? PomodoroMode.longBreak
            : PomodoroMode.shortBreak;

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Text('🎉 Great Focus!'),
              const Spacer(),
              Text('+$minutes m',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  )),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You just finished a $minutes-minute deep work session. Daily streak: ${FocusStatsService.dailyStreak} days 🔥',
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 16),
              if (_selectedTask != null && !_selectedTask!.isCompleted) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.task_alt, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedTask!.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          await TaskActionService.setTaskCompletion(
                            _selectedTask!,
                            true,
                          );
                          if (mounted) setState(() {});
                          if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                        },
                        child: const Text('Mark Done'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                isLongBreakDue
                    ? '4 sessions complete! Take a relaxing 15m Long Break.'
                    : 'Time for a quick 5m recharge.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                _switchMode(PomodoroMode.focus);
              },
              child: const Text('Stay in Focus'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                if (isLongBreakDue) {
                  _completedSessionsInRound = 0;
                }
                _switchMode(nextMode, startImmediately: true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: nextMode.color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(isLongBreakDue ? 'Start Long Break' : 'Start Break'),
            ),
          ],
        );
      },
    );
  }

  void _showBreakCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('⚡ Break Finished!'),
          content: const Text(
            'Ready to dive back into your next high-impact focus session?',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                _resetTimer();
              },
              child: const Text('Rest a bit more'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                _switchMode(PomodoroMode.focus, startImmediately: true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: PomodoroMode.focus.color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Start Focus (25m)'),
            ),
          ],
        );
      },
    );
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _showDurationPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Timer Durations',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Focus Duration',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: [15, 25, 45, 50, 60].map((mins) {
                      final isSelected = _customFocusMinutes == mins;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: ChoiceChip(
                            label: Text('$mins m', style: const TextStyle(fontSize: 12)),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setModalState(() => _customFocusMinutes = mins);
                                setState(() {
                                  _customFocusMinutes = mins;
                                  if (_currentMode == PomodoroMode.focus && !_isRunning) {
                                    _totalDurationSeconds = mins * 60;
                                    _remainingSeconds = _totalDurationSeconds;
                                  }
                                });
                              }
                            },
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text('Short Break Duration',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(
                    children: [3, 5, 10].map((mins) {
                      final isSelected = _customShortBreakMinutes == mins;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Text('$mins m', style: const TextStyle(fontSize: 12)),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setModalState(() => _customShortBreakMinutes = mins);
                                setState(() {
                                  _customShortBreakMinutes = mins;
                                  if (_currentMode == PomodoroMode.shortBreak && !_isRunning) {
                                    _totalDurationSeconds = mins * 60;
                                    _remainingSeconds = _totalDurationSeconds;
                                  }
                                });
                              }
                            },
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(sheetCtx),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showTaskSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return ValueListenableBuilder(
          valueListenable: Hive.box<Task>('tasks').listenable(),
          builder: (context, Box<Task> box, _) {
            final activeTasks = box.values
                .where((t) => !t.isCompleted)
                .toList();

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Link Task to Focus Session',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_selectedTask != null)
                    ListTile(
                      leading: const Icon(Icons.clear_all, color: Colors.redAccent),
                      title: const Text('Unlink current task'),
                      onTap: () {
                        setState(() => _selectedTask = null);
                        Navigator.pop(sheetCtx);
                      },
                    ),
                  if (activeTasks.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No pending tasks. You can still focus without linking.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: activeTasks.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final task = activeTasks[index];
                          final isSelected = _selectedTask?.key == task.key;

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              isSelected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey,
                            ),
                            title: Text(
                              task.title,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            subtitle: task.category?.isNotEmpty == true
                                ? Text(task.category!)
                                : null,
                            onTap: () {
                              setState(() => _selectedTask = task);
                              Navigator.pop(sheetCtx);
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final modeColor = _currentMode.color;

    final progress = _totalDurationSeconds > 0
        ? (_totalDurationSeconds - _remainingSeconds) / _totalDurationSeconds
        : 0.0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Pomodoro Focus',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Custom Durations',
            icon: const Icon(Icons.tune_rounded),
            onPressed: _showDurationPicker,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          // Confetti particle overlay on session complete
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                Color(0xFF7C4DFF),
                Color(0xFF00BFA5),
                Color(0xFFFFD54F),
                Color(0xFFFF4081),
              ],
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                children: [
                  // ── Mode Switcher Pills ──────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: isDark ? Colors.white12 : Colors.black12,
                      ),
                    ),
                    child: Row(
                      children: PomodoroMode.values.map((mode) {
                        final isSelected = _currentMode == mode;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              _switchMode(mode);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 240),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isSelected ? mode.color : Colors.transparent,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: mode.color.withValues(alpha: 0.35),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    mode.icon,
                                    size: 16,
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark ? Colors.white60 : Colors.black54),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    mode == PomodoroMode.focus
                                        ? 'Focus'
                                        : (mode == PomodoroMode.shortBreak
                                            ? 'Short'
                                            : 'Long'),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? Colors.white
                                          : (isDark ? Colors.white70 : Colors.black87),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Linked Task Card ──────────────────────────────────────
                  GestureDetector(
                    onTap: _showTaskSelector,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _selectedTask != null
                              ? modeColor.withValues(alpha: 0.4)
                              : (isDark ? Colors.white12 : Colors.black12),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: modeColor.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _selectedTask != null
                                  ? Icons.checklist_rounded
                                  : Icons.add_task_rounded,
                              size: 18,
                              color: modeColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedTask != null
                                      ? 'Working on'
                                      : 'No task linked',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _selectedTask?.title ?? 'Tap to select a task...',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _selectedTask != null
                                        ? (_selectedTask!.isCompleted
                                            ? Colors.grey
                                            : (isDark ? Colors.white : Colors.black87))
                                        : Colors.grey.shade500,
                                    decoration: _selectedTask?.isCompleted == true
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Circular Animated Countdown Timer ────────────────────
                  ScaleTransition(
                    scale: _isRunning ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
                    child: SizedBox(
                      width: 250,
                      height: 250,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Background & Progress Arc Painter
                          CustomPaint(
                            size: const Size(250, 250),
                            painter: _PomodoroRingPainter(
                              progress: progress,
                              primaryColor: modeColor,
                              backgroundColor: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.06),
                              glowColor: modeColor.withValues(alpha: 0.35),
                              isDark: isDark,
                            ),
                          ),

                          // Inner Content: Time, State, Interval Dots
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _currentMode.label.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                  color: modeColor,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _formatTime(_remainingSeconds),
                                style: TextStyle(
                                  fontSize: 52,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1.0,
                                  color: isDark ? Colors.white : Colors.black87,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                              const SizedBox(height: 8),
                              // 4-session round beads indicator
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(4, (i) {
                                  final isDone = i < _completedSessionsInRound;
                                  return Container(
                                    width: 8,
                                    height: 8,
                                    margin: const EdgeInsets.symmetric(horizontal: 3),
                                    decoration: BoxDecoration(
                                      color: isDone
                                          ? modeColor
                                          : (isDark ? Colors.white24 : Colors.black12),
                                      shape: BoxShape.circle,
                                    ),
                                  );
                                }),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Primary Controls (Play/Pause, Reset, Skip) ────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Reset Button
                      IconButton.filledTonal(
                        tooltip: 'Reset',
                        icon: const Icon(Icons.refresh_rounded, size: 22),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          _resetTimer();
                        },
                        style: IconButton.styleFrom(
                          padding: const EdgeInsets.all(14),
                        ),
                      ),
                      const SizedBox(width: 20),

                      // Start / Pause Floating Action Button
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          if (_isRunning) {
                            _pauseTimer();
                          } else {
                            _startTimer();
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: modeColor,
                            boxShadow: [
                              BoxShadow(
                                color: modeColor.withValues(alpha: 0.4),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Icon(
                            _isRunning
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 38,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),

                      // Skip to Next Interval Button
                      IconButton.filledTonal(
                        tooltip: 'Skip Interval',
                        icon: const Icon(Icons.skip_next_rounded, size: 22),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          final nextMode = _currentMode == PomodoroMode.focus
                              ? (_completedSessionsInRound >= 3
                                  ? PomodoroMode.longBreak
                                  : PomodoroMode.shortBreak)
                              : PomodoroMode.focus;
                          _switchMode(nextMode);
                        },
                        style: IconButton.styleFrom(
                          padding: const EdgeInsets.all(14),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // ── Ambient Audio Selector & Sound Loops ─────────────────
                  _buildAmbientAudioSection(isDark, primary),

                  const SizedBox(height: 24),

                  // ── Daily Focus Habit Stats Card ──────────────────────────
                  _buildDailyFocusHabitCard(isDark, primary),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmbientAudioSection(bool isDark, Color primary) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.headphones_rounded, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Ambient Audio & Focus Loops',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              // Ticking toggle
              ValueListenableBuilder<bool>(
                valueListenable: _audioService.tickingNotifier,
                builder: (context, ticking, _) {
                  return InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _audioService.setTickingEnabled(!ticking);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: ticking
                            ? primary.withValues(alpha: 0.15)
                            : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: ticking ? primary : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 14,
                            color: ticking ? primary : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Tick',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: ticking ? primary : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Horizontal sound loops list
          ValueListenableBuilder<AmbientSound>(
            valueListenable: _audioService.activeSoundNotifier,
            builder: (context, activeSound, _) {
              return SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: AmbientSound.values.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final sound = AmbientSound.values[index];
                    final isSelected = activeSound == sound;

                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _audioService.setAmbientSound(sound);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 110,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? primary.withValues(alpha: 0.15)
                              : (isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF7F7FA)),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? primary
                                : (isDark ? Colors.white12 : Colors.black12),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(sound.icon, style: const TextStyle(fontSize: 16)),
                                const Spacer(),
                                if (isSelected)
                                  Icon(Icons.volume_up_rounded, size: 14, color: primary),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              sound.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                color: isSelected ? primary : (isDark ? Colors.white : Colors.black87),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          // Volume Slider
          ValueListenableBuilder<double>(
            valueListenable: _audioService.volumeNotifier,
            builder: (context, volume, _) {
              return Row(
                children: [
                  Icon(
                    volume == 0 ? Icons.volume_mute_rounded : Icons.volume_down_rounded,
                    size: 18,
                    color: Colors.grey,
                  ),
                  Expanded(
                    child: Slider(
                      value: volume,
                      min: 0.0,
                      max: 1.0,
                      activeColor: primary,
                      onChanged: (val) => _audioService.setVolume(val),
                    ),
                  ),
                  const Icon(Icons.volume_up_rounded, size: 18, color: Colors.grey),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDailyFocusHabitCard(bool isDark, Color primary) {
    final todayMinutes = FocusStatsService.todayFocusMinutes;
    final todaySessions = FocusStatsService.todayCompletedSessions;
    final streak = FocusStatsService.dailyStreak;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.black12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_graph_rounded, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Focus Habits & Daily Stats',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Text(
                      '$streak day streak',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildStatMiniTile(
                  label: "Today's Focus",
                  value: '$todayMinutes m',
                  icon: Icons.timer_outlined,
                  color: primary,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatMiniTile(
                  label: 'Completed',
                  value: '$todaySessions sessions',
                  icon: Icons.check_circle_outline_rounded,
                  color: const Color(0xFF00BFA5),
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          HabitHeatmapWidget(
            onStreakTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StatsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatMiniTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white60 : Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for glowing circular countdown ring
class _PomodoroRingPainter extends CustomPainter {
  final double progress; // 0.0 (start) to 1.0 (finish)
  final Color primaryColor;
  final Color backgroundColor;
  final Color glowColor;
  final bool isDark;

  _PomodoroRingPainter({
    required this.progress,
    required this.primaryColor,
    required this.backgroundColor,
    required this.glowColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 14;

    // Background track ring
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10.0
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    if (progress <= 0.0) return;

    // Outer glow for progress arc
    final glowPaint = Paint()
      ..color = glowColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
      ..strokeCap = StrokeCap.round;

    const startAngle = -pi / 2;
    final sweepAngle = 2 * pi * progress.clamp(0.0, 1.0);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      glowPaint,
    );

    // Main vibrant progress arc
    final progressPaint = Paint()
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + 2 * pi,
        colors: [
          primaryColor.withValues(alpha: 0.7),
          primaryColor,
        ],
        stops: const [0.0, 1.0],
        transform: GradientRotation(startAngle),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11.0
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );

    // Indicator head circle at current position
    final headAngle = startAngle + sweepAngle;
    final headX = center.dx + radius * cos(headAngle);
    final headY = center.dy + radius * sin(headAngle);

    final headPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(headX, headY), 5.5, headPaint);
  }

  @override
  bool shouldRepaint(covariant _PomodoroRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.primaryColor != primaryColor;
  }
}
