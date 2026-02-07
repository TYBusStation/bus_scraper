import 'package:flutter/material.dart';

abstract class UiUtils {
  static final DateTime _firstSelectableDate = DateTime(2025, 6, 8);
  static final DateTime _lastSelectableDate =
      DateTime.now().add(const Duration(days: 7));

  static Future<void> selectDate({
    required BuildContext context,
    required DateTime initialDate,
    required void Function(DateTime newDate) onDateSelected,
    DateTime? firstDate,
    DateTime? lastDate,
  }) async {
    final DateTime effectiveFirstDate = firstDate ?? _firstSelectableDate;
    final DateTime effectiveLastDate = lastDate ?? _lastSelectableDate;

    final DateTime validInitialDate = initialDate.isAfter(effectiveLastDate)
        ? effectiveLastDate
        : (initialDate.isBefore(effectiveFirstDate)
            ? effectiveFirstDate
            : initialDate);

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: validInitialDate,
      firstDate: effectiveFirstDate,
      lastDate: effectiveLastDate,
      helpText: '選擇日期',
    );

    if (pickedDate != null && context.mounted) {
      onDateSelected(pickedDate);
    }
  }

  static Future<void> selectRangeDateTime({
    required BuildContext context,
    required bool isStart,
    required DateTimeRange currentRange,
    required bool pickTime,
    required Duration maxDuration,
    required void Function(DateTimeRange newRange) onDateTimeChanged,
  }) async {
    final DateTime initialPickerDate =
        isStart ? currentRange.start : currentRange.end;

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialPickerDate.isAfter(_lastSelectableDate)
          ? _lastSelectableDate
          : (initialPickerDate.isBefore(_firstSelectableDate)
              ? _firstSelectableDate
              : initialPickerDate),
      firstDate: _firstSelectableDate,
      lastDate: _lastSelectableDate,
      helpText: isStart ? '選擇開始日期' : '選擇結束日期',
    );

    if (pickedDate == null || !context.mounted) return;

    final DateTime newDateTime;

    if (pickTime) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialPickerDate),
        helpText: isStart ? '選擇開始時間' : '選擇結束時間',
      );

      if (pickedTime == null) return;

      newDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    } else {
      newDateTime = isStart
          ? DateTime(pickedDate.year, pickedDate.month, pickedDate.day)
          : DateTime(pickedDate.year, pickedDate.month, pickedDate.day, 23, 59,
              59, 999);
    }

    var newStart = currentRange.start;
    var newEnd = currentRange.end;

    if (isStart) {
      newStart = newDateTime;
      if (newStart.isAfter(newEnd)) {
        newEnd = newStart.add(const Duration(minutes: 1));
      }
      if (newEnd.difference(newStart) > maxDuration) {
        newEnd = newStart.add(maxDuration);
      }
      if (newEnd.isAfter(_lastSelectableDate)) {
        newEnd = _lastSelectableDate;
        if (newStart.isAfter(newEnd)) {
          newStart = newEnd.subtract(const Duration(minutes: 1));
        }
      }
    } else {
      newEnd = newDateTime;
      if (newEnd.isBefore(newStart)) {
        newStart = newEnd.subtract(const Duration(minutes: 1));
      }
      if (newEnd.difference(newStart) > maxDuration) {
        newStart = newEnd.subtract(maxDuration);
      }
      if (newStart.isBefore(_firstSelectableDate)) {
        newStart = _firstSelectableDate;
        if (newEnd.isBefore(newStart)) {
          newEnd = newStart.add(const Duration(minutes: 1));
        }
      }
    }

    onDateTimeChanged(DateTimeRange(start: newStart, end: newEnd));
  }
}
