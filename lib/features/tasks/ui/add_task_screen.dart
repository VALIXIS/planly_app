import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../../../services/notification_service.dart';
import '../models/task_model.dart';

class AddTaskScreen extends StatefulWidget {
  final Task? task;

  const AddTaskScreen({super.key, this.task});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  TimeOfDay? reminderTime;
  static const Duration _minimumReminderDelay = Duration(seconds: 5);
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _reminderMinutesController =
      TextEditingController();
  final TextEditingController _customIntervalController =
      TextEditingController();

  DateTime selectedDate = DateTime.now();
  TimeOfDay selectedTime = TimeOfDay.now();

  bool enableReminder = true;
  bool _isSaving = false;
  bool _showValidationErrors = false;

  String selectedCategory = 'Personal';
  String selectedPriority = 'Medium';

  String repeatType = 'None';
  final Set<int> repeatWeekdays = <int>{};
  bool skipMissedRecurrences = true;

  // Removed reminderTime; only using remind before
  int? reminderMinutesBefore;

  final List<String> categories = ['Work', 'Personal', 'Shopping', 'Others'];
  final List<String> priorities = ['High', 'Medium', 'Low'];
  final List<String> repeatOptions = [
    'None',
    'Daily',
    'Weekly',
    'Monthly',
    'Certain days',
    'Custom interval',
  ];
  final List<int> quickReminderOffsets = [5, 10, 30, 60];

  static const List<Map<String, dynamic>> weekDays = [
    {'label': 'Mon', 'value': 1},
    {'label': 'Tue', 'value': 2},
    {'label': 'Wed', 'value': 3},
    {'label': 'Thu', 'value': 4},
    {'label': 'Fri', 'value': 5},
    {'label': 'Sat', 'value': 6},
    {'label': 'Sun', 'value': 7},
  ];

  @override
  void initState() {
    super.initState();

    final defaultDue = DateTime.now().add(const Duration(minutes: 15));
    selectedDate = DateTime(defaultDue.year, defaultDue.month, defaultDue.day);
    selectedTime = TimeOfDay(
      hour: defaultDue.hour,
      minute: defaultDue.minute,
    );

    if (widget.task != null) {
      final task = widget.task!;
      _controller.text = task.title;
      selectedCategory = task.category ?? 'Personal';
      _descController.text = task.description ?? '';
      selectedPriority = task.priority;

      if (task.dueDate != null) {
        selectedDate = task.dueDate!;
        selectedTime = TimeOfDay.fromDateTime(task.dueDate!);
      }

      reminderMinutesBefore = task.reminderMinutesBefore;
      reminderTime = task.reminderTime != null
          ? TimeOfDay.fromDateTime(task.reminderTime!)
          : null;
      enableReminder = task.reminderEnabled;
      skipMissedRecurrences = task.skipMissedRecurrences;

      if (reminderMinutesBefore != null && reminderMinutesBefore! > 0) {
        _reminderMinutesController.text = reminderMinutesBefore.toString();
      }

      _applyRecurrenceRule(task.recurrenceRule);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _descController.dispose();
    _reminderMinutesController.dispose();
    _customIntervalController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  DateTime _dateOnly(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, dateTime.day);
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  DateTime _nextWeekendDate(DateTime from) {
    var candidate = _dateOnly(from);
    while (candidate.weekday != DateTime.saturday) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }

  void _applyQuickDate(DateTime date) {
    setState(() {
      selectedDate = _dateOnly(date);
    });
  }

  void _setReminderMinutes(int? minutes) {
    final text = minutes?.toString() ?? '';

    setState(() {
      reminderMinutesBefore = minutes;
      _reminderMinutesController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    });
  }

  void _handleReminderMinutesChanged(String value) {
    setState(() {
      reminderMinutesBefore = int.tryParse(value.trim());
    });
  }

  String? _validateTitle(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Task title is required';
    }

    if (value.trim().length < 2) {
      return 'Title is too short';
    }

    return null;
  }

  String? _validateReminderMinutes(String? value) {
    if (!enableReminder) return null;

    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return null;

    final parsed = int.tryParse(raw);
    if (parsed == null) {
      return 'Enter a valid number';
    }

    if (parsed <= 0) {
      return 'Minutes must be greater than 0';
    }

    if (parsed > 10080) {
      return 'Use 10080 minutes or less';
    }

    return null;
  }

  void _applyRecurrenceRule(String? rule) {
    if (rule == null || rule.isEmpty) {
      repeatType = 'None';
      repeatWeekdays.clear();
      _customIntervalController.clear();
      return;
    }

    final normalized = rule.toLowerCase();

    if (normalized == 'daily') {
      repeatType = 'Daily';
      repeatWeekdays.clear();
      _customIntervalController.clear();
      return;
    }

    if (normalized == 'weekly') {
      repeatType = 'Weekly';
      repeatWeekdays.clear();
      _customIntervalController.clear();
      return;
    }

    if (normalized == 'monthly') {
      repeatType = 'Monthly';
      repeatWeekdays.clear();
      _customIntervalController.clear();
      return;
    }

    if (normalized.startsWith('days:')) {
      repeatType = 'Certain days';
      final rawDays = normalized.substring(5).split(',');
      repeatWeekdays
        ..clear()
        ..addAll(
          rawDays
              .map((d) => int.tryParse(d.trim()))
              .whereType<int>()
              .where((d) => d >= 1 && d <= 7),
        );
      _customIntervalController.clear();
      return;
    }

    if (normalized.startsWith('interval:')) {
      repeatType = 'Custom interval';
      repeatWeekdays.clear();
      _customIntervalController.text = normalized.substring(9).trim();
      return;
    }

    repeatType = 'None';
    repeatWeekdays.clear();
    _customIntervalController.clear();
  }

  String? _buildRecurrenceRule() {
    if (repeatType == 'Daily') return 'daily';
    if (repeatType == 'Weekly') return 'weekly';
    if (repeatType == 'Monthly') return 'monthly';

    if (repeatType == 'Certain days' && repeatWeekdays.isNotEmpty) {
      final sorted = repeatWeekdays.toList()..sort();
      return 'days:${sorted.join(',')}';
    }

    if (repeatType == 'Custom interval') {
      final interval = int.tryParse(_customIntervalController.text.trim());
      if (interval != null && interval > 0) {
        return 'interval:$interval';
      }
    }

    return null;
  }

  String? _validateCustomInterval() {
    if (repeatType != 'Custom interval') return null;

    final raw = _customIntervalController.text.trim();
    final parsed = int.tryParse(raw);
    if (parsed == null || parsed <= 0) {
      return 'Enter valid days for custom interval';
    }

    if (parsed > 365) {
      return 'Custom interval must be 365 days or less';
    }

    return null;
  }

  DateTime get combinedDateTime => DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );

  // Removed _buildReminderTimeValue; reminder will use scheduled date/time only

  DateTime? _buildReminderScheduleTime() {
    if (!enableReminder) return null;
    final now = DateTime.now();
    final earliestReminderTime = now.add(_minimumReminderDelay);
    DateTime target = combinedDateTime;
    if (reminderMinutesBefore != null && reminderMinutesBefore! > 0) {
      target = target.subtract(Duration(minutes: reminderMinutesBefore!));
    }
    if (target.isBefore(earliestReminderTime)) {
      return earliestReminderTime;
    }
    return target;
  }

  Future<void> pickDate() async {
    final nowDate = _dateOnly(DateTime.now());
    final initialDate = selectedDate.isBefore(nowDate) ? nowDate : selectedDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: nowDate,
      lastDate: DateTime(2035),
    );

    if (picked != null) {
      setState(() => selectedDate = picked);
    }
  }

  Future<void> pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: selectedTime,
    );

    if (picked != null) {
      setState(() => selectedTime = picked);
    }
  }

  Future<void> saveTask() async {
    if (_isSaving) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _showValidationErrors = true;
    });

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final title = _controller.text.trim();

    if (repeatType == 'Certain days' && repeatWeekdays.isEmpty) {
      _showMessage('Select at least one repeat day');
      return;
    }

    final customIntervalError = _validateCustomInterval();
    if (customIntervalError != null) {
      _showMessage(customIntervalError);
      return;
    }

    final reminderAt = enableReminder ? _buildReminderScheduleTime() : null;
    if (enableReminder && reminderAt == null) {
      _showMessage(
        'Reminder is in the past. Pick a future reminder or disable reminders.',
      );
      return;
    }

    final notifService = NotificationService();
    final box = Hive.box<Task>('tasks');
    final recurrenceRule = _buildRecurrenceRule();

    setState(() {
      _isSaving = true;
    });

    try {
      if (widget.task != null) {
        final task = widget.task!;
        await notifService.cancelNotification(task.key as int);

        task.title = title;
        task.category = selectedCategory;
        task.dueDate = combinedDateTime;
        task.description = _descController.text.trim();
        task.priority = selectedPriority;
        task.recurrenceRule = recurrenceRule;
        task.skipMissedRecurrences = skipMissedRecurrences;
        task.reminderEnabled = enableReminder;
        task.reminderTime = null;
        task.reminderMinutesBefore = enableReminder ? reminderMinutesBefore : null;
        await task.save();

        if (enableReminder && reminderAt != null) {
          await notifService.scheduleNotification(
            id: task.key as int,
            title: task.title,
            body: task.description?.isNotEmpty == true
                ? task.description!
                : 'Your task is due now!',
            scheduledTime: reminderAt,
          );
        }

        if (mounted) Navigator.pop(context);
        return;
      }

      final newTask = Task(
        title: title,
        category: selectedCategory,
        dueDate: combinedDateTime,
        isCompleted: false,
        description: _descController.text.trim(),
        priority: selectedPriority,
        recurrenceRule: recurrenceRule,
        skipMissedRecurrences: skipMissedRecurrences,
        reminderEnabled: enableReminder,
        reminderTime: null,
        reminderMinutesBefore: enableReminder ? reminderMinutesBefore : null,
      );

      final key = await box.add(newTask);

      if (enableReminder && reminderAt != null) {
        await notifService.scheduleNotification(
          id: key,
          title: title,
          body: _descController.text.trim().isNotEmpty
              ? _descController.text.trim()
              : 'Your task is due now!',
          scheduledTime: reminderAt,
        );
      }

      if (mounted) Navigator.pop(context);
    } catch (e, stack) {
      debugPrint('Task save error: \n$e\n$stack');
      _showMessage('Could not save task. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.task != null;
    final theme = Theme.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final nowDate = _dateOnly(DateTime.now());
    final tomorrowDate = nowDate.add(const Duration(days: 1));
    final weekendDate = _nextWeekendDate(nowDate);
    final dueLabel = DateFormat('EEE, dd MMM yyyy - hh:mm a').format(
      combinedDateTime,
    );

    final reminderPreview = _buildReminderScheduleTime();
    final reminderPreviewText = !enableReminder
        ? 'Reminder is turned off for this task.'
        : reminderPreview != null &&
            reminderPreview.difference(DateTime.now()) <=
                const Duration(seconds: 10)
            ? 'Reminder time already passed, so Planly will remind right after you save.'
            : 'Will remind on ${DateFormat('EEE, dd MMM - hh:mm a').format(reminderPreview!)}';

    final fieldFill = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF2A2A2A)
        : Colors.white;

    InputDecoration fieldDecoration({String? hint, Widget? prefix}) {
      return InputDecoration(
        hintText: hint,
        prefixIcon: prefix,
        filled: true,
        fillColor: fieldFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Task' : 'Add Task'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                child: Form(
                  key: _formKey,
                  autovalidateMode: _showValidationErrors
                      ? AutovalidateMode.onUserInteraction
                      : AutovalidateMode.disabled,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              colorScheme.primary.withValues(alpha: 0.16),
                              colorScheme.tertiary.withValues(alpha: 0.12),
                            ],
                          ),
                          border: Border.all(
                            color: colorScheme.primary.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEditing
                                  ? 'Refine your task details'
                                  : 'Plan your next task',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Due: $dueLabel',
                              style: theme.textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              enableReminder
                                  ? 'Reminder is enabled'
                                  : 'Reminder is currently off',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _SectionCard(
                        title: 'Task Details',
                        icon: Icons.edit_note,
                        fillColor: fieldFill,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _controller,
                              textInputAction: TextInputAction.next,
                              validator: _validateTitle,
                              decoration: fieldDecoration(
                                hint: 'Enter task title',
                                prefix: const Icon(Icons.task_alt),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _descController,
                              maxLines: 3,
                              decoration: fieldDecoration(
                                hint: 'Add description (optional)',
                                prefix: const Icon(Icons.notes),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SectionCard(
                        title: 'Schedule',
                        icon: Icons.event,
                        fillColor: fieldFill,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _InfoTile(
                                    icon: Icons.calendar_today,
                                    label: DateFormat('dd MMM yyyy').format(
                                      selectedDate,
                                    ),
                                    onTap: pickDate,
                                    fillColor: colorScheme.surface.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _InfoTile(
                                    icon: Icons.access_time,
                                    label: selectedTime.format(context),
                                    onTap: pickTime,
                                    fillColor: colorScheme.surface.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Quick Date',
                              style: theme.textTheme.labelLarge,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ChoiceChip(
                                  label: const Text('Today'),
                                  selected: _isSameDate(selectedDate, nowDate),
                                  onSelected: (_) => _applyQuickDate(nowDate),
                                ),
                                ChoiceChip(
                                  label: const Text('Tomorrow'),
                                  selected: _isSameDate(
                                    selectedDate,
                                    tomorrowDate,
                                  ),
                                  onSelected: (_) =>
                                      _applyQuickDate(tomorrowDate),
                                ),
                                ChoiceChip(
                                  label: const Text('This Weekend'),
                                  selected: _isSameDate(selectedDate, weekendDate),
                                  onSelected: (_) => _applyQuickDate(weekendDate),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text('Repeat', style: theme.textTheme.labelLarge),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: repeatOptions.map((option) {
                                return ChoiceChip(
                                  label: Text(option),
                                  selected: repeatType == option,
                                  onSelected: (_) {
                                    setState(() {
                                      repeatType = option;
                                      if (repeatType != 'Certain days') {
                                        repeatWeekdays.clear();
                                      }
                                      if (repeatType != 'Custom interval') {
                                        _customIntervalController.clear();
                                      }
                                      if (repeatType == 'None') {
                                        skipMissedRecurrences = true;
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                            if (repeatType == 'Certain days') ...[
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: weekDays.map((day) {
                                  final int dayValue = day['value'] as int;
                                  final bool selected =
                                      repeatWeekdays.contains(dayValue);
                                  return FilterChip(
                                    label: Text(day['label'] as String),
                                    selected: selected,
                                    onSelected: (isSelected) {
                                      setState(() {
                                        if (isSelected) {
                                          repeatWeekdays.add(dayValue);
                                        } else {
                                          repeatWeekdays.remove(dayValue);
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            ],
                            if (repeatType == 'Custom interval') ...[
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _customIntervalController,
                                keyboardType: TextInputType.number,
                                decoration: fieldDecoration(
                                  hint: 'Repeat every N days',
                                  prefix: const Icon(Icons.repeat_on_outlined),
                                ),
                              ),
                            ],
                            if (repeatType != 'None') ...[
                              const SizedBox(height: 12),
                              SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Skip missed repeat days'),
                                subtitle: Text(
                                  'When enabled, recurring tasks jump to the next future slot.',
                                  style: theme.textTheme.bodySmall,
                                ),
                                value: skipMissedRecurrences,
                                onChanged: (value) {
                                  setState(() {
                                    skipMissedRecurrences = value;
                                  });
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SectionCard(
                        title: 'Reminder',
                        icon: Icons.notifications_active_outlined,
                        fillColor: fieldFill,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Enable reminder',
                                  style: theme.textTheme.labelLarge,
                                ),
                                Switch.adaptive(
                                  value: enableReminder,
                                  activeThumbColor: colorScheme.primary,
                                  onChanged: (val) {
                                    setState(() {
                                      enableReminder = val;
                                      if (!enableReminder) {
                                        reminderTime = null;
                                        reminderMinutesBefore = null;
                                        _reminderMinutesController.clear();
                                      }
                                    });
                                  },
                                ),
                              ],
                            ),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child: enableReminder
                                  ? Column(
                                      key: const ValueKey<String>('reminderOn'),
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const SizedBox(height: 8),
                                        TextFormField(
                                          controller: _reminderMinutesController,
                                          keyboardType: TextInputType.number,
                                          validator: _validateReminderMinutes,
                                          decoration: fieldDecoration(
                                            hint: 'Remind before (minutes)',
                                            prefix: const Icon(
                                              Icons.timer_outlined,
                                            ),
                                          ),
                                          onChanged: _handleReminderMinutesChanged,
                                        ),
                                        const SizedBox(height: 10),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: quickReminderOffsets
                                              .map((offset) => ChoiceChip(
                                                    label: Text('${offset}m'),
                                                    selected:
                                                        reminderMinutesBefore ==
                                                            offset,
                                                    onSelected: (_) =>
                                                        _setReminderMinutes(offset),
                                                  ))
                                              .toList(),
                                        ),
                                        const SizedBox(height: 10),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: colorScheme.primary
                                                .withValues(alpha: 0.08),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.info_outline,
                                                size: 18,
                                                color: colorScheme.primary,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  reminderPreviewText,
                                                  style: theme.textTheme.bodySmall,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SectionCard(
                        title: 'Category and Priority',
                        icon: Icons.tune,
                        fillColor: fieldFill,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Category', style: theme.textTheme.labelLarge),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<String>(
                              initialValue: selectedCategory,
                              decoration: fieldDecoration(
                                hint: 'Category',
                                prefix: const Icon(Icons.category_outlined),
                              ),
                              items: categories
                                  .map(
                                    (cat) => DropdownMenuItem<String>(
                                      value: cat,
                                      child: Text(cat),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => selectedCategory = val);
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            Text('Priority', style: theme.textTheme.labelLarge),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: priorities.map((priority) {
                                return ChoiceChip(
                                  label: Text(priority),
                                  selected: selectedPriority == priority,
                                  onSelected: (_) {
                                    setState(() {
                                      selectedPriority = priority;
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            border: Border(
              top: BorderSide(
                color: colorScheme.outline.withValues(alpha: 0.15),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Due: $dueLabel',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : saveTask,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSaving
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  colorScheme.onPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text('Saving...'),
                          ],
                        )
                      : Text(
                          isEditing ? 'Update Task' : 'Save Task',
                          style: const TextStyle(fontWeight: FontWeight.w700),
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

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Color fillColor;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    required this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color fillColor;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: fillColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label, style: const TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
