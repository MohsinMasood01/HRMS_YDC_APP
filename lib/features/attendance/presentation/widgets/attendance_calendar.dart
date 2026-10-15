import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:table_calendar/table_calendar.dart';

// ignore_for_file: todo

import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/attendance_status_service.dart'
    as status_service;
import '../../domain/entities/attendance_record.dart';

/// Calendar widget for displaying attendance with color coding
class AttendanceCalendar extends StatelessWidget {
  const AttendanceCalendar({
    super.key,
    required this.records,
    required this.selectedDate,
    required this.onDateSelected,
    this.joiningDate,
    this.onPageChanged,
  });

  final List<AttendanceRecord> records;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final DateTime? joiningDate;
  final ValueChanged<DateTime>? onPageChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final today = DateTime.now();
    final todayNormalized = DateTime(today.year, today.month, today.day);
    final firstValidDate = joiningDate != null
        ? DateTime(joiningDate!.year, joiningDate!.month, joiningDate!.day)
        : DateTime(2020, 1, 1);
    final lastValidDate = todayNormalized;

    // Create a map of dates to attendance records
    // Use normalized dates (year, month, day only) as keys
    final recordsMap = <String, AttendanceRecord>{};
    for (final record in records) {
      final dateKey =
          '${record.date.year}-${record.date.month}-${record.date.day}';
      final recordDateNormalized = DateTime(
        record.date.year,
        record.date.month,
        record.date.day,
      );
      if (recordDateNormalized.isAfter(lastValidDate) ||
          recordDateNormalized.isBefore(firstValidDate)) {
        continue;
      }
      recordsMap[dateKey] = record;
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
      ),
      child: TableCalendar<AttendanceRecord>(
        firstDay: firstValidDate,
        lastDay: lastValidDate,
        focusedDay: selectedDate,
        selectedDayPredicate: (day) => isSameDay(selectedDate, day),
        enabledDayPredicate: (day) {
          final dayNormalized = DateTime(day.year, day.month, day.day);
          if (dayNormalized.isAfter(todayNormalized)) return false;
          if (joiningDate != null) {
            final joiningNormalized = DateTime(
              joiningDate!.year,
              joiningDate!.month,
              joiningDate!.day,
            );
            if (dayNormalized.isBefore(joiningNormalized)) return false;
          }
          return true;
        },
        onDaySelected: (selectedDay, focusedDay) {
          final dayNormalized = DateTime(
            selectedDay.year,
            selectedDay.month,
            selectedDay.day,
          );
          if (dayNormalized.isAfter(todayNormalized)) return;
          if (joiningDate != null) {
            final joiningNormalized = DateTime(
              joiningDate!.year,
              joiningDate!.month,
              joiningDate!.day,
            );
            if (dayNormalized.isBefore(joiningNormalized)) return;
          }
          onDateSelected(selectedDay);
        },
        onPageChanged: onPageChanged,
        calendarFormat: CalendarFormat.month,
        startingDayOfWeek: StartingDayOfWeek.monday,
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          weekendTextStyle: TextStyle(
            color: isDark ? Colors.white54 : AppColors.textSecondary,
          ),
          defaultTextStyle: TextStyle(
            color: isDark ? Colors.white : AppColors.textPrimary,
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
          ),
          selectedTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
          ),
          todayTextStyle: TextStyle(
            color: isDark ? AppColors.secondary : theme.primaryColor,
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
          ),
          disabledTextStyle: TextStyle(
            color: isDark
                ? Colors.white.withValues(alpha: 0.2)
                : Colors.grey.shade300,
            fontSize: 14.sp,
          ),
          selectedDecoration: BoxDecoration(
            color: isDark ? AppColors.secondary : theme.primaryColor,
            shape: BoxShape.circle,
          ),
          todayDecoration: BoxDecoration(
            color: (isDark ? AppColors.secondary : theme.primaryColor)
                .withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark ? AppColors.secondary : theme.primaryColor,
              width: 2,
            ),
          ),
          disabledDecoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.shade100,
            shape: BoxShape.circle,
          ),
          markerDecoration: const BoxDecoration(shape: BoxShape.circle),
        ),
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
          leftChevronIcon: Icon(
            Icons.chevron_left_rounded,
            color: isDark ? Colors.white : AppColors.textPrimary,
            size: 24.sp,
          ),
          rightChevronIcon: Icon(
            Icons.chevron_right_rounded,
            color: isDark ? Colors.white : AppColors.textPrimary,
            size: 24.sp,
          ),
        ),
        eventLoader: (day) {
          final dayNormalized = DateTime(day.year, day.month, day.day);
          if (dayNormalized.isAfter(todayNormalized)) {
            return <AttendanceRecord>[];
          }
          if (joiningDate != null) {
            final joiningNormalized = DateTime(
              joiningDate!.year,
              joiningDate!.month,
              joiningDate!.day,
            );
            if (dayNormalized.isBefore(joiningNormalized)) {
              return <AttendanceRecord>[];
            }
          }
          final dateKey = '${day.year}-${day.month}-${day.day}';
          final record = recordsMap[dateKey];
          return record != null ? [record] : <AttendanceRecord>[];
        },
        calendarBuilders: CalendarBuilders<AttendanceRecord>(
          defaultBuilder: (context, date, events) {
            final eventList = _getEventList(events);
            return _buildDateCell(context, date, eventList, isDark, theme);
          },
          todayBuilder: (context, date, events) {
            final eventList = _getEventList(events);
            return _buildDateCell(
              context,
              date,
              eventList,
              isDark,
              theme,
              isToday: true,
            );
          },
          selectedBuilder: (context, date, events) {
            final eventList = _getEventList(events);
            return _buildDateCell(
              context,
              date,
              eventList,
              isDark,
              theme,
              isSelected: true,
            );
          },
          markerBuilder: (context, date, events) {
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildDateCell(
    BuildContext context,
    DateTime date,
    List<AttendanceRecord> events,
    bool isDark,
    ThemeData theme, {
    bool isToday = false,
    bool isSelected = false,
  }) {
    final record = events.isNotEmpty ? events.first : null;
    final status = record != null ? _getAttendanceStatus(record) : null;

    // Determine color based on attendance
    Color backgroundColor;
    Color textColor = isDark ? Colors.white : AppColors.textPrimary;
    String? statusSymbol;

    if (status != null) {
      backgroundColor = Color(
        status_service.AttendanceStatusService.getStatusColor(status),
      );
      statusSymbol = status_service.AttendanceStatusService.getStatusIcon(
        status,
      );
    } else {
      backgroundColor = Colors.transparent;
    }

    if (isSelected) {
      backgroundColor = isDark ? AppColors.secondary : theme.primaryColor;
      textColor = Colors.white;
    } else if (isToday) {
      backgroundColor = (isDark ? AppColors.secondary : theme.primaryColor)
          .withValues(alpha: 0.2);
      textColor = isDark ? AppColors.secondary : theme.primaryColor;
    }

    return Container(
      width: 44.w,
      height: 44.w,
      margin: EdgeInsets.all(2.w),
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: isToday && !isSelected
            ? Border.all(
                color: isDark ? AppColors.secondary : theme.primaryColor,
                width: 2,
              )
            : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (statusSymbol != null)
            Positioned(
              top: 4.h,
              child: Text(
                statusSymbol,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          Text(
            '${date.day}',
            style: TextStyle(
              color: textColor,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Safely extract event list from the events parameter
  List<AttendanceRecord> _getEventList(dynamic events) {
    if (events == null) return <AttendanceRecord>[];
    if (events is List<AttendanceRecord>) return events;
    if (events is List) {
      return events.whereType<AttendanceRecord>().toList();
    }
    return <AttendanceRecord>[];
  }

  status_service.AttendanceDayStatus _getAttendanceStatus(
    AttendanceRecord record,
  ) {
    // Check if absent
    if (record.isAbsent) {
      return status_service.AttendanceDayStatus.absent;
    }

    // Calculate status based on check-in time
    // Convert Duration to DateTime for comparison
    final checkInDateTime = DateTime(
      record.date.year,
      record.date.month,
      record.date.day,
    ).add(record.timeIn);

    return status_service.AttendanceStatusService.calculateStatus(
      checkInTime: checkInDateTime,
      isAbsent: record.isAbsent,
      isLeave: false, // TODO: Add leave check from record
    );
  }
}
