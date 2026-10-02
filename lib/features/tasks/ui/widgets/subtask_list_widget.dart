import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/task_model.dart';

/// Interactive Subtask & Checklist Progress Widget
///
/// Provides inline adding, drag-to-reorder, checking, deleting,
/// dynamic completion ratio calculations, and animated progress visualization.
class SubtaskListWidget extends StatefulWidget {
  final List<SubTask> subtasks;
  final ValueChanged<List<SubTask>>? onChanged;
  final Function(SubTask subtask, bool isCompleted, bool allCompleted)? onSubtaskToggled;
  final VoidCallback? onAutoCompleted;
  final Color? primaryColor;
  final bool showProgressBar;
  final bool isEditable;
  final String addHintText;

  const SubtaskListWidget({
    super.key,
    required this.subtasks,
    this.onChanged,
    this.onSubtaskToggled,
    this.onAutoCompleted,
    this.primaryColor,
    this.showProgressBar = true,
    this.isEditable = true,
    this.addHintText = 'Add subtask...',
  });

  @override
  State<SubtaskListWidget> createState() => _SubtaskListWidgetState();
}

class _SubtaskListWidgetState extends State<SubtaskListWidget> {
  final TextEditingController _addController = TextEditingController();
  final FocusNode _addFocusNode = FocusNode();

  @override
  void dispose() {
    _addController.dispose();
    _addFocusNode.dispose();
    super.dispose();
  }

  void _addSubtask() {
    final title = _addController.text.trim();
    if (title.isEmpty) return;

    final newSubtask = SubTask(
      title: title,
      isCompleted: false,
    );

    setState(() {
      widget.subtasks.add(newSubtask);
    });

    _addController.clear();
    widget.onChanged?.call(widget.subtasks);
    HapticFeedback.selectionClick();
  }

  void _removeSubtask(int index) {
    if (index < 0 || index >= widget.subtasks.length) return;

    setState(() {
      widget.subtasks.removeAt(index);
    });

    widget.onChanged?.call(widget.subtasks);
    HapticFeedback.selectionClick();
  }

  void _toggleSubtask(int index, bool? value) {
    if (index < 0 || index >= widget.subtasks.length) return;
    final isDone = value ?? false;

    setState(() {
      widget.subtasks[index].isCompleted = isDone;
    });

    final allCompleted = widget.subtasks.isNotEmpty &&
        widget.subtasks.every((s) => s.isCompleted);

    HapticFeedback.selectionClick();

    if (allCompleted) {
      HapticFeedback.heavyImpact();
      widget.onAutoCompleted?.call();
    }

    widget.onChanged?.call(widget.subtasks);
    widget.onSubtaskToggled?.call(widget.subtasks[index], isDone, allCompleted);
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = widget.subtasks.removeAt(oldIndex);
      widget.subtasks.insert(newIndex, item);
    });

    widget.onChanged?.call(widget.subtasks);
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = widget.primaryColor ?? theme.colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;

    final total = widget.subtasks.length;
    final completed = widget.subtasks.where((s) => s.isCompleted).length;
    final double ratio = total == 0 ? 0.0 : completed / total;
    final int percentage = (ratio * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showProgressBar && total > 0) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Subtasks Progress',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                      ),
                    ),
                    Text(
                      '$completed/$total ($percentage%)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: ratio == 1.0 ? const Color(0xFF10B981) : primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    height: 6,
                    color: primary.withValues(alpha: isDark ? 0.18 : 0.1),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            width: constraints.maxWidth * ratio,
                            decoration: BoxDecoration(
                              color: ratio == 1.0 ? const Color(0xFF10B981) : primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        if (widget.subtasks.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Text(
              'No subtasks added yet.',
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
              ),
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.subtasks.length,
            // ignore: deprecated_member_use
            onReorder: _onReorder,
            itemBuilder: (context, index) {
              final subtask = widget.subtasks[index];
              return Container(
                key: ValueKey('subtask-${subtask.hashCode}-$index'),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.grey.shade900.withValues(alpha: 0.5)
                      : Colors.grey.shade100.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black12,
                    width: 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    if (widget.isEditable)
                      ReorderableDragStartListener(
                        index: index,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8.0, right: 4.0),
                          child: Icon(
                            Icons.drag_handle_rounded,
                            size: 18,
                            color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 8),
                    Transform.scale(
                      scale: 0.9,
                      child: Checkbox(
                        value: subtask.isCompleted,
                        activeColor: const Color(0xFF10B981),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        onChanged: (val) => _toggleSubtask(index, val),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        subtask.title,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: subtask.isCompleted
                              ? FontWeight.normal
                              : FontWeight.w500,
                          decoration: subtask.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: subtask.isCompleted
                              ? (isDark ? Colors.grey.shade500 : Colors.grey.shade400)
                              : (isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                    ),
                    if (subtask.minutes > 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: primary.withValues(alpha: isDark ? 0.2 : 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${subtask.minutes}m',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (widget.isEditable)
                      IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                        ),
                        color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                        onPressed: () => _removeSubtask(index),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Delete subtask',
                      )
                    else
                      const SizedBox(width: 8),
                  ],
                ),
              );
            },
          ),
        if (widget.isEditable) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _addController,
                  focusNode: _addFocusNode,
                  textInputAction: TextInputAction.done,
                  style: const TextStyle(fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: widget.addHintText,
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade400,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? Colors.grey.shade900.withValues(alpha: 0.6)
                        : Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _addSubtask(),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: primary,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _addSubtask,
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
