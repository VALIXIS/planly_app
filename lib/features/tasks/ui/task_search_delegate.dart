import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../models/tag_model.dart';
import '../models/task_model.dart';
import 'add_task_screen.dart';

enum SearchDateFilter { all, today, thisWeek, next7Days, overdue, custom }

class TaskSearchDelegate extends SearchDelegate<Task?> {
  Set<String> selectedTags = {};
  Set<String> selectedPriorities = {};
  SearchDateFilter dateFilter = SearchDateFilter.all;
  DateTimeRange? customDateRange;

  TaskSearchDelegate()
      : super(
          searchFieldLabel: 'Search title, notes, or #tags...',
          keyboardType: TextInputType.text,
        );

  void _resetFilters(StateSetter setState) {
    setState(() {
      query = '';
      selectedTags.clear();
      selectedPriorities.clear();
      dateFilter = SearchDateFilter.all;
      customDateRange = null;
    });
  }

  bool get _hasActiveFilters =>
      query.trim().isNotEmpty ||
      selectedTags.isNotEmpty ||
      selectedPriorities.isNotEmpty ||
      dateFilter != SearchDateFilter.all;

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear_rounded),
          tooltip: 'Clear query',
          onPressed: () {
            query = '';
            showSuggestions(context);
          },
        ),
      IconButton(
        icon: const Icon(Icons.tune_rounded),
        tooltip: 'Reset all filters',
        onPressed: () {
          query = '';
          selectedTags.clear();
          selectedPriorities.clear();
          dateFilter = SearchDateFilter.all;
          customDateRange = null;
          showSuggestions(context);
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      tooltip: 'Back',
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildFilteredListView(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildFilteredListView(context);
  }

  Widget _buildFilteredListView(BuildContext context) {
    final tasksBox = Hive.box<Task>('tasks');
    final tagsBox = Hive.box<TagModel>('tags');

    return StatefulBuilder(
      builder: (context, setState) {
        final allTasks = tasksBox.values.toList();
        final filteredTasks = _filterTasks(allTasks);

        return Column(
          children: [
            _buildFilterMatrixHeader(context, setState, tagsBox),
            _buildResultsCountBanner(context, filteredTasks.length, setState),
            Expanded(
              child: filteredTasks.isEmpty
                  ? _buildEmptyResultsState(context)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                      itemCount: filteredTasks.length,
                      itemBuilder: (context, index) {
                        final task = filteredTasks[index];
                        return _buildSearchTaskTile(context, task, setState);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  List<Task> _filterTasks(List<Task> tasks) {
    final cleanQuery = query.trim().toLowerCase();
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return tasks.where((task) {
      // 1. Text Search (Title & Description/Notes)
      if (cleanQuery.isNotEmpty) {
        final titleMatch = task.title.toLowerCase().contains(cleanQuery);
        final descMatch =
            task.description?.toLowerCase().contains(cleanQuery) ?? false;
        final tagMatch = task.tags.any(
          (tag) => '#${tag.toLowerCase()}'.contains(cleanQuery) ||
              tag.toLowerCase().contains(cleanQuery),
        );
        if (!titleMatch && !descMatch && !tagMatch) return false;
      }

      // 2. Tag Filter
      if (selectedTags.isNotEmpty) {
        final matchesAnyTag =
            selectedTags.any((selected) => task.tags.contains(selected));
        if (!matchesAnyTag) return false;
      }

      // 3. Priority Filter
      if (selectedPriorities.isNotEmpty) {
        if (!selectedPriorities.contains(task.priority)) return false;
      }

      // 4. Date Range Filter
      if (dateFilter != SearchDateFilter.all) {
        final due = task.dueDate;
        if (due == null && dateFilter != SearchDateFilter.custom) {
          return false;
        }

        switch (dateFilter) {
          case SearchDateFilter.today:
            if (due == null ||
                due.isBefore(todayStart) ||
                due.isAfter(todayEnd)) {
              return false;
            }
            break;
          case SearchDateFilter.thisWeek:
            final endOfWeek = todayStart.add(Duration(
              days: 7 - todayStart.weekday,
              hours: 23,
              minutes: 59,
              seconds: 59,
            ));
            if (due == null ||
                due.isBefore(todayStart) ||
                due.isAfter(endOfWeek)) {
              return false;
            }
            break;
          case SearchDateFilter.next7Days:
            final in7Days = todayEnd.add(const Duration(days: 7));
            if (due == null ||
                due.isBefore(todayStart) ||
                due.isAfter(in7Days)) {
              return false;
            }
            break;
          case SearchDateFilter.overdue:
            if (due == null || !due.isBefore(now) || task.isCompleted) {
              return false;
            }
            break;
          case SearchDateFilter.custom:
            if (customDateRange != null) {
              if (due == null) return false;
              final start = DateTime(
                customDateRange!.start.year,
                customDateRange!.start.month,
                customDateRange!.start.day,
              );
              final end = DateTime(
                customDateRange!.end.year,
                customDateRange!.end.month,
                customDateRange!.end.day,
                23,
                59,
                59,
              );
              if (due.isBefore(start) || due.isAfter(end)) return false;
            }
            break;
          case SearchDateFilter.all:
            break;
        }
      }

      return true;
    }).toList();
  }

  Widget _buildFilterMatrixHeader(
    BuildContext context,
    StateSetter setState,
    Box<TagModel> tagsBox,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outline.withValues(alpha: 0.12),
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Priorities row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Priority: ',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                ...['High', 'Medium', 'Low'].map((p) {
                  final isSelected = selectedPriorities.contains(p);
                  final chipColor = p == 'High'
                      ? Colors.red
                      : p == 'Medium'
                          ? Colors.orange
                          : Colors.blue;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(p),
                      selected: isSelected,
                      selectedColor: chipColor.withValues(alpha: 0.25),
                      checkmarkColor: chipColor,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                        color: isSelected ? chipColor : null,
                      ),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            selectedPriorities.add(p);
                          } else {
                            selectedPriorities.remove(p);
                          }
                        });
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // Tags row
          ValueListenableBuilder(
            valueListenable: tagsBox.listenable(),
            builder: (context, Box<TagModel> box, _) {
              final tags = box.values.toList();
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      'Tags: ',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    ...tags.map((tagObj) {
                      final tagName = tagObj.name;
                      final isSelected = selectedTags.contains(tagName);
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          avatar: const Icon(Icons.tag, size: 14),
                          label: Text('#$tagName'),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                selectedTags.add(tagName);
                              } else {
                                selectedTags.remove(tagName);
                              }
                            });
                          },
                        ),
                      );
                    }),
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 14),
                      label: const Text('Add Tag'),
                      onPressed: () => _showAddNewTagDialog(context, setState),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 4),

          // Date Filter Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Date: ',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                _dateChip(
                  context: context,
                  setState: setState,
                  label: 'All',
                  type: SearchDateFilter.all,
                ),
                _dateChip(
                  context: context,
                  setState: setState,
                  label: 'Today',
                  type: SearchDateFilter.today,
                ),
                _dateChip(
                  context: context,
                  setState: setState,
                  label: 'This Week',
                  type: SearchDateFilter.thisWeek,
                ),
                _dateChip(
                  context: context,
                  setState: setState,
                  label: 'Next 7 Days',
                  type: SearchDateFilter.next7Days,
                ),
                _dateChip(
                  context: context,
                  setState: setState,
                  label: 'Overdue',
                  type: SearchDateFilter.overdue,
                ),
                _customDateChip(context, setState),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateChip({
    required BuildContext context,
    required StateSetter setState,
    required String label,
    required SearchDateFilter type,
  }) {
    final isSelected = dateFilter == type;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            setState(() {
              dateFilter = type;
              customDateRange = null;
            });
          }
        },
      ),
    );
  }

  Widget _customDateChip(BuildContext context, StateSetter setState) {
    final isSelected = dateFilter == SearchDateFilter.custom;
    String label = 'Custom Range';
    if (customDateRange != null) {
      label =
          '${DateFormat('dd MMM').format(customDateRange!.start)} - ${DateFormat('dd MMM').format(customDateRange!.end)}';
    }

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        avatar: const Icon(Icons.date_range, size: 14),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: isSelected,
        onSelected: (selected) async {
          final range = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2020),
            lastDate: DateTime(2035),
            initialDateRange: customDateRange,
          );
          if (range != null) {
            setState(() {
              customDateRange = range;
              dateFilter = SearchDateFilter.custom;
            });
          }
        },
      ),
    );
  }

  Widget _buildResultsCountBanner(
    BuildContext context,
    int count,
    StateSetter setState,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: colorScheme.primary.withValues(alpha: 0.06),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.search, size: 16, color: colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                '$count task${count == 1 ? '' : 's'} found',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
            ],
          ),
          if (_hasActiveFilters)
            TextButton.icon(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => _resetFilters(setState),
              icon: const Icon(Icons.refresh, size: 14),
              label: const Text('Reset', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchTaskTile(
    BuildContext context,
    Task task,
    StateSetter setState,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final priorityColor = task.priority == 'High'
        ? Colors.red
        : task.priority == 'Medium'
            ? Colors.orange
            : Colors.blue;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddTaskScreen(task: task),
            ),
          );
          setState(() {});
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: task.isCompleted,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    onChanged: (val) async {
                      if (val != null) {
                        task.isCompleted = val;
                        await task.save();
                        setState(() {});
                      }
                    },
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            decoration: task.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            color: task.isCompleted
                                ? colorScheme.onSurface.withValues(alpha: 0.5)
                                : null,
                          ),
                        ),
                        if (task.description?.isNotEmpty == true) ...[
                          const SizedBox(height: 4),
                          Text(
                            task.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (task.dueDate != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.event, size: 12),
                                    const SizedBox(width: 4),
                                    Text(
                                      DateFormat('dd MMM, hh:mm a')
                                          .format(task.dueDate!),
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: priorityColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                task.priority,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: priorityColor,
                                ),
                              ),
                            ),
                            ...task.tags.map(
                              (tag) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '#$tag',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyResultsState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(
            'No matching tasks found',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Try adjusting your keywords, tag filters, or date range.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _showAddNewTagDialog(
    BuildContext context,
    StateSetter setState,
  ) async {
    final controller = TextEditingController();
    final tagBox = Hive.box<TagModel>('tags');

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create New Tag'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. #work or urgent',
            prefixText: '#',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final cleanName =
          result.replaceAll('#', '').trim().toLowerCase();
      if (cleanName.isNotEmpty) {
        final existing =
            tagBox.values.any((t) => t.name.toLowerCase() == cleanName);
        if (!existing) {
          await tagBox.add(TagModel(name: cleanName));
        }
        setState(() {
          selectedTags.add(cleanName);
        });
      }
    }
  }
}
