import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/format.dart';
import '../models/work_session.dart';
import '../theme/app_theme.dart';

/// Result of the log sheet — a new or edited block.
class LoggedBlock {
  const LoggedBlock({
    required this.start,
    required this.minutes,
    required this.category,
    this.note,
  });

  final DateTime start;
  final int minutes;
  final WorkCategory category;
  final String? note;
}

/// Sheet for adding a block by hand or editing an existing one.
class LogSessionSheet extends StatefulWidget {
  const LogSessionSheet({super.key, this.existing, required this.now});

  final WorkSession? existing;
  final DateTime now;

  static Future<LoggedBlock?> show(
    BuildContext context, {
    WorkSession? existing,
    required DateTime now,
  }) {
    return showModalBottomSheet<LoggedBlock>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => LogSessionSheet(existing: existing, now: now),
    );
  }

  @override
  State<LogSessionSheet> createState() => _LogSessionSheetState();
}

class _LogSessionSheetState extends State<LogSessionSheet> {
  static const _presets = [15, 25, 45, 60, 90, 120];

  late WorkCategory _category;
  late int _minutes;
  late TimeOfDay _startTime;
  late DateTime _day;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _category = existing?.category ?? WorkCategory.deepWork;
    _minutes = existing?.minutes ?? 25;
    final start = existing?.start ?? widget.now;
    _startTime = TimeOfDay(hour: start.hour, minute: start.minute);
    _day = DateTime(start.year, start.month, start.day);
    _note = TextEditingController(text: existing?.note ?? '');
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    final start = DateTime(
      _day.year,
      _day.month,
      _day.day,
      _startTime.hour,
      _startTime.minute,
    );
    Navigator.of(context).pop(
      LoggedBlock(
        start: start,
        minutes: _minutes,
        category: _category,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      ),
    );
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _startTime);
    if (picked != null) setState(() => _startTime = picked);
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: widget.now.subtract(const Duration(days: 365 * 3)),
      lastDate: widget.now,
    );
    if (picked != null) {
      setState(() => _day = DateTime(picked.year, picked.month, picked.day));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.existing != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEditing ? 'Edit Block' : 'Log a Block',
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),

            const SectionHeader('Duration'),
            Center(
              child: Text(
                Fmt.duration(_minutes),
                style: theme.textTheme.displayLarge?.copyWith(
                  color: AppColors.focusEnd,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Slider(
              value: _minutes.toDouble().clamp(5, 480),
              min: 5,
              max: 480,
              divisions: 95,
              activeColor: AppColors.focusEnd,
              inactiveColor: AppColors.surfaceElevated,
              onChanged: (value) {
                final rounded = (value / 5).round() * 5;
                if (rounded != _minutes) {
                  HapticFeedback.selectionClick();
                  setState(() => _minutes = rounded);
                }
              },
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                for (final preset in _presets)
                  _Chip(
                    label: Fmt.duration(preset),
                    selected: _minutes == preset,
                    onTap: () => setState(() => _minutes = preset),
                  ),
              ],
            ),

            const SizedBox(height: 24),
            const SectionHeader('Category'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in WorkCategory.values)
                  _Chip(
                    label: category.label,
                    icon: category.icon,
                    color: category.color,
                    selected: _category == category,
                    onTap: () => setState(() => _category = category),
                  ),
              ],
            ),

            const SizedBox(height: 24),
            const SectionHeader('When'),
            Row(
              children: [
                Expanded(
                  child: _PickerTile(
                    label: 'Date',
                    value: Fmt.relativeDay(
                      _day,
                      DateTime(widget.now.year, widget.now.month, widget.now.day),
                    ),
                    onTap: _pickDay,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PickerTile(
                    label: 'Start',
                    value: _startTime.format(context),
                    onTap: _pickTime,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            const SectionHeader('Note'),
            TextField(
              controller: _note,
              maxLength: 120,
              style: theme.textTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: 'What did you work on?',
                hintStyle: const TextStyle(color: AppColors.tertiaryLabel),
                counterText: '',
                filled: true,
                fillColor: AppColors.surfaceElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),

            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.focusStart,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  isEditing ? 'Save Changes' : 'Log ${Fmt.duration(_minutes)}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? AppColors.focusEnd;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.22)
              : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? accent : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: selected ? accent : AppColors.secondaryLabel),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.label : AppColors.secondaryLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      color: AppColors.surfaceElevated,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.label,
            ),
          ),
        ],
      ),
    );
  }
}
